#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local json = utility.require("dkjson")
local text_processing = utility.require("text_processing")
local timing = utility.require("timing")

-- TODO make utility have a function for getting/setting defaults where locking is only used to set defaults if they aren't present
-- TODO there should be a check function for a lock so a warning/error can be dumped?
local config = utility.get_config("no-lock")
if not config.models then
  config.models = {
    embedding = {
      model = "qwen3-embedding:0.6b",
      max_chunk_size = 32768,
    },
    initialized_sources = {},
  }
  utility.save_config()
end

local embeddings
local embeddings_file_path = "PRIVATE_DATA/memory/+embeddings.json"
if not utility.path_exists(embeddings_file_path) then
  os.execute("mkdir -p PRIVATE_DATA/memory")
  utility.save_data({
    files = {},
    vectors = {},
  }, embeddings_file_path)
end
embeddings = utility.load_data(embeddings_file_path)



local refresh_file_list = function(source_name, data_source)
  timing.mark("Assembling file list for " .. source_name .. ".")

  local full_path = "PRIVATE_DATA" .. utility.path_separator .. data_source.path
  if data_source.initialize_command and (not config.models.initialized_sources[data_source.path]) then
    -- NOTE this is where we'd want to check/obtain a lock on the config so we can safely run this
    os.execute("mkdir -p " .. full_path:enquote() .. " && cd " .. full_path:enquote() .. " && " .. data_source.initialize_command)
    config.models.initialized_sources[data_source.path] = true
    utility.save_config()
  end
  if data_source.refresh_command then
    os.execute("cd " .. full_path:enquote() .. " && " .. data_source.refresh_command)
  end

  local compiled_filters = {}
  if data_source.filters then
    for name, object in pairs(data_source.filters) do
      compiled_filters[name] = utility.enumerate(object)
    end
  end

  local file_list = {}
  utility.tree("PRIVATE_DATA" .. utility.path_separator .. data_source.path, compiled_filters, function(file_name)
    file_list[#file_list + 1] = file_name
  end)

  timing.mark("Finished assembling file list for " .. source_name .. ".")
  return file_list
end

-- returns nothing when too much text is sent
local generate_embeddings = function(text)
  if #text > config.models.embedding.max_chunk_size then
    return nil, "generate_embeddings() must only be passed appropriately-sized chunks!"
  end

  local result = utility.llm_prompt(text, config.models.embedding.model)
  return json.decode(result)
end

-- returns nothing for empty files
local process_file = function(data_source, file_name)
  local text = utility.read_file(file_name)

  if data_source.strip_frontmatter then
    text = text_processing.strip_frontmatter(text)
  end

  if #text == 0 then
    print(file_name .. "\n is empty and being skipped.")
    return
  end

  local chunk_size = config.models.embedding.max_chunk_size
  local half_chunk_size = math.floor(chunk_size / 2)
  local chunks = { text }

  while #text > chunk_size do
    local first_chunk = text:sub(1, chunk_size)
    local overlap_chunk = text:sub(half_chunk_size, chunk_size + half_chunk_size - 1)

    chunks[#chunks + 1] = first_chunk
    chunks[#chunks + 1] = overlap_chunk

    text = text:sub(chunk_size)
    if (#text > half_chunk_size) and (not (#text > chunk_size)) then
      -- last chunk would be skipped if we didn't handle this here
      chunks[#chunks + 1] = text
    end
  end

  local new_embeddings = {}
  for i = 1, #chunks do
    -- print("Embedding length:", #chunks[i])
    new_embeddings[i] = generate_embeddings(chunks[i]) or {}
  end

  if #new_embeddings[1] == 0 then
    -- print(file_name)
    -- print("Vector lengths:")
    -- for e = 1, #new_embeddings do
    --   print("", e, #new_embeddings[e])
    -- end
    if #new_embeddings == 1 then
      -- Ollama very rarely errors with:
      --   Error: do embedding request: Post "http://127.0.0.1:53441/v1/embeddings": EOF
      -- but it is inconsistent and re-running will eventually fix it. (See issue #7 if present.)
      print(file_name .. "\n encountered an embedding error and will be skipped this run only.")
      return
    end

    -- average all embeddings to make the core file embedding
    local count = #new_embeddings[2]
    for vector_index = 1, count do
      local total = 0
      for chunk = 2, #new_embeddings do
        total = total + new_embeddings[chunk][vector_index]
      end
      new_embeddings[1][vector_index] = total / count
    end
  end

  return chunks, new_embeddings
end

local refresh_sources = function()
  local tmp_file_path = "PRIVATE_DATA/.tmp.2b65c19b-0883-49ca-8247-b1fe7760f922"
  os.execute("mkdir -p PRIVATE_DATA/memory")

  local sources = utility.load_data("PRIVATE_DATA/sources.json")
  for source_name, data_source in pairs(sources) do
    local file_list = refresh_file_list(source_name, data_source)

    timing.mark("Generating embeddings for " .. source_name .. ".")
    for f = 1, #file_list do
      local file_name = file_list[f]
      local function loop()
        local sha512sum = utility.sha512sum(file_name)
        if embeddings.vectors[sha512sum] then
          -- add file reference if it was missing
          if not embeddings.files[file_name] then
            embeddings.files[file_name] = sha512sum
          end
          return
        end

        local file_chunks, file_embeddings = process_file(data_source, file_name)
        if not file_chunks then return end

        local file_sums = {}
        for i = 1, #file_chunks do
          local function loop()
            local text = file_chunks[i]
            local current_embedding = file_embeddings[i]

            utility.write_file(tmp_file_path, text)

            sha512sum = utility.sha512sum(tmp_file_path)
            file_sums[#file_sums + 1] = sha512sum
            if embeddings.vectors[sha512sum] then return end

            os.execute(utility.commands.move .. tmp_file_path:enquote() .. " " .. "PRIVATE_DATA/memory/" .. sha512sum)
            embeddings.vectors[sha512sum] = current_embedding
          end
          loop()
        end

        embeddings.files[file_name] = file_sums
      end
      loop()
      print("Finished " .. utility.leftpad(f, #tostring(#file_list), "0") .. "/" .. #file_list
        .. " (" .. utility.leftpad(math.floor(f / #file_list * 100), 3, "0")
        .. "%) ETA: " .. timing.estimate(f, #file_list))
    end

    timing.mark("Finished generating embeddings for " .. source_name .. ".")
  end

  utility.save_data(embeddings)
  if utility.path_exists(tmp_file_path) then
    os.execute("rm " .. tmp_file_path:enquote())
  end
end

refresh_sources()
timing.mark("Finished.")
print("")
timing.display()

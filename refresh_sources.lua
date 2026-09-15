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

local refresh_file_list = function(data_source)
  timing.mark("Assembling file list.")

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
  utility.tree(data_source.path, compiled_filters, function(file_name)
    file_list[#file_list + 1] = file_name
  end)

  timing.mark("Finished assembling file list.")
  return file_list
end

-- returns nothing when too much text is sent
local generate_embeddings = function(text)
  if #text > config.models.embedding.max_chunk_size then
    return nil, "generate_embeddings() must only be passed appropriately-sized chunks!"
  end

  local result = utility.llm_prompt(text, config.models.embedding.model)

  result = setmetatable({}, {
    __tojson = function() return result end,
  })

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
    local overlap_chunk = text:sub(half_chunk_size, chunk_size + half_chunk_size)

    chunks[#chunks + 1] = first_chunk
    chunks[#chunks + 1] = overlap_chunk

    text = text:sub(chunk_size)
    if #text > half_chunk_size and (not #text > chunk_size) then
      -- last chunk would be skipped if we didn't handle this here
      chunks[#chunks + 1] = text
    end
  end

  local embeddings = {}
  for i = 1, #chunks do
    embeddings[i] = generate_embeddings(chunks[i])
  end

  if embeddings[1] == nil then
    -- TODO average all other embeddings to this one
  end

  return chunks, embeddings
end

-- TODO somewhere near the top of this function chain needs to be the ability to recognize a file as unchanged and skip re-generating embeddings
--  this means running the same shasum command I will put below on that source file before trying to generate an embedding
--    something something merging new changes into the old data structure means we need to load that data structure first so we only replace modified chunks
local refresh_sources = function()
  local sources = utility.load_data("PRIVATE_DATA/sources.json")
  for _, data_source in pairs(sources) do
    local file_list = refresh_file_list(data_source)
    timing.mark("Generating embeddings.")
    for _, file_name in ipairs(file_list) do
      local chunks, embeddings = process_file(file_name)
      -- TODO decide how these will be stored
      local sum_file_path = "PRIVATE_DATA/.tmp.2b65c19b-0883-49ca-8247-b1fe7760f922"
      utility.write_file(sum_file_path, text)
      -- -p ensures compatibility across OSes, -t ensures it is read as text (some OSes default differently), -a 512 ensures it is a 512-bit SHA2 sum
      local sha512sum = utility.capture_safe("shasum -p -t -a 512 " .. sum_file_path)
      -- for chunks, save to a specific local tmp file to shasum, then mv that file based on the sum
      -- for embeddings, store sum = embedding ? (look at how generate_embeddings.lua worked)
    end
    timing.mark("Finished generating embeddings.")
  end
end

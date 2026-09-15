#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local json = utility.require("dkjson")
local text_processing = utility.require("text_processing")
local timing = utility.require("timing")

-- TODO make utility have a function for getting/setting defaults where locking is only used to set defaults if they aren't present
local config = utility.get_config("no-lock")
if not config.models then
  config.models = {
    embedding = {
      model = "qwen3-embedding:0.6b",
      max_chunk_size = 32768,
    }
  }
  utility.save_config()
end

-- TODO recognize uninitialized source and initialize it
--  this would need to be in the config
local refresh_file_list = function(data_source)
  timing.mark("Assembling file list.")

  os.execute("cd " .. ("PRIVATE_DATA" .. utility.path_separator .. data_source.path):enquote() .. " && " .. data_source.refresh_command)

  local compiled_filters = {}
  for name, object in pairs(data_source.filters) do
    compiled_filters[name] = utility.enumerate(object)
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
    for _, file_name in ipairs(file_list) do
      local chunks, embeddings = process_file(file_name)
      -- TODO decide how these will be stored
      -- for chunks, save to a specific local tmp file to shasum, then mv that file based on the sum
      -- for embeddings, store sum = embedding ? (look at how generate_embeddings.lua worked)
    end
  end
end

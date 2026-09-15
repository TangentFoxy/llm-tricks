#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

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

local refresht_file_list = function(data_source)
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

  return file_list
end

local generate_embeddings = function(text)
  if #text > config.models.embedding.max_chunk_size then
    return nil, "generate_embeddings() must only be passed appropriately-sized chunks!"
  end

  local result = utility.llm_prompt(text, config.models.embedding.model)

  -- skipping unnecessary decoding to an array and putting back into text for saving
  -- this would cause problems if we intended to use the results immediately
  return setmetatable({}, {
    __tojson = function() return result end,
  })
end

local process_file = function(file_name)
  local text = utility.read_file(file_name)
  if w
end

local to_be_named_generate_file_embeddings = function(text)
  if #text > config.models.embedding.max_chunk_size then
    -- TODO, split, process each chunk, return both a total and each chunk
  end
  -- return just the file and its embedding
end

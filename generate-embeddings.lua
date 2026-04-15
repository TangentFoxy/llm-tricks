#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local PATH = "vault-snapshot"
local whitelist = { md = true, }

local tree
tree = function(path, fn)
  utility.list(path or ".", function(path_name)
    if utility.is_file(path_name) then
      fn(path_name)
    else
      tree(path .. utility.path_separator .. path_name, fn)
    end
  end)
end

local embeddings = {}

local files_processed = 0
-- TODO estimate files by doing tree without processing, then process the files after
local total_file_count = 2201

tree(PATH, function(file_name)
  local path, name, extension = utility.split_path_components(file_name)
  if not extension then
    return
  end

  if not whitelist[extension] then
    files_processed = files_processed + 1
    return
  end

  local file_contents = utility.open(file_name, "r", function(file)
    return file:read("*all")
  end)

  local embedding_model = "nomic-embed-text"
  local output = utility.capture_safe("ollama run " .. embedding_model .. " " .. file_contents:enquote())
  output = output:sub(1, -2) -- strip extra newline from utility.capture_safe

  output = setmetatable({ vector = output }, {
    __tojson = function(self, state)
      return self.vector
    end
  })

  embeddings[file_name] = { vector = output }

  files_processed = files_processed + 1
  print("(estimate) Finished " .. files_processed .. "/" .. total_file_count .. " (" .. math.floor(files_processed/total_file_count * 100) .. "%)")
end)

local file = utility.open("dump.txt", "w", function(file)
  local final_output = json.encode(final_output, { indent = true })
  file:write(final_output)
  file:write("\n")
end)

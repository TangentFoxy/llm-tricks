#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local PATH = "notebook"
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

local file_list = {}
local embeddings = {}

tree(PATH, function(file_name)
  local path, name, extension = utility.split_path_components(file_name)
  if not extension then
    return
  end

  if not whitelist[extension] then
    return
  end

  file_list[#file_list + 1] = file_name
end)

for i = 1, #file_list do
  local file_name = file_list[i]

  -- TODO read and output to temp file, skipping YAML
  -- local file_contents = utility.open(file_name, "r", function(file)
  --   return file:read("*all")
  -- end)

  local embedding_model = "nomic-embed-text"
  local output = utility.capture_safe("cat " .. file_name:enquote() .. " | ollama run " .. embedding_model)
  output = output:sub(1, -2) -- strip extra newline from utility.capture_safe

  output = setmetatable({ vector = output }, {
    __tojson = function(self, state)
      return self.vector
    end
  })

  embeddings[file_name] = { vector = output }

  print("Finished " .. i .. "/" .. #file_list .. " (" .. math.floor(i / #file_list * 100) .. "%)")
end

local file = utility.open("dump.txt", "w", function(file)
  local output = json.encode(embeddings, { indent = true })
  file:write(output)
  file:write("\n")
end)

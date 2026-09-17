#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local search_path = arg[1]

local file_extensions = {}
utility.tree(search_path, function(file_path)
  local _, _, extension = utility.split_path_components(file_path)
  if extension then
    file_extensions[extension] = true
  end
end)

for extension in pairs(file_extensions) do
  print(extension)
end

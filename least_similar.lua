#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local similarities = utility.open("PRIVATE_DATA/similarities.json", "r", function(file)
  return json.decode(file:read("*all"))
end)

table.sort(similarities, function(a, b) return a.similarity < b.similarity end)

utility.open("PRIVATE_DATA/differences.json", "w", function(file)
  file:write(json.encode(similarities, { indent = true }))
end)

#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local file_name = arg[1]

print("---")
print(utility.capture_safe("shasum -p"))
print("---")

print("---")
print(utility.capture_safe("shasum -U -t -a 512 test.lua"))
print("---")

local prompt = [[Return JSON: category, tags (array), summary (short)]]
-- local prompt = [[Return YAML: category, tags (array), summary (short)]]

if prompt:sub(-1) ~= "\n" then
  prompt = prompt .. "\n\n"
end

local file_contents = utility.open(file_name, "r", function(file)
  return file:read("*all")
end)
prompt = prompt .. file_contents

-- output = output:sub(1, -2) -- strip extra newline from utility.capture_safe

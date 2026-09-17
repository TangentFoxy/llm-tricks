#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local file_name = arg[1]

print(utility.OS)

os.exit(0)

local prompt = [[Return JSON: category, tags (array), summary (short)]]
-- local prompt = [[Return YAML: category, tags (array), summary (short)]]

if prompt:sub(-1) ~= "\n" then
  prompt = prompt .. "\n\n"
end

local file_contents = utility.read_file(file_name)
prompt = prompt .. file_contents
-- print(utility.llm_prompt(prompt))

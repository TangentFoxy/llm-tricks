#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local prompt = [[You are organizing text files.

Return ONLY valid JSON with:
- title
- summary (short)
- tags (array)
- category

Do not return JSON wrapped in Markdown.

Text:
]]

local prompt = [[Classify and tag this document.
Return JSON: category, tags (array), summary (short)

]]

local prompt = [[Return JSON: category, tags (array), summary (short)

]]

local prompt = [[Return YAML: category, tags (array), summary (short)

]]

local file_contents = utility.open(arg[1], "r", function(file)
  return file:read("*all")
end)
prompt = prompt .. file_contents

-- local model = "dolphin-phi:2.7b"
local model = "gemma3:4b"

local output = utility.capture_safe("ollama run " .. model .. " --nowordwrap " .. prompt:enquote())

-- local output = utility.capture_safe("ollama run nomic-embed-text " .. file_contents:enquote())

print(output)

print('--- div ---')

--local a = output:find("\n")
--output = output:sub(a, -1)
--local b = output:find("\n"

local outtable = output:split("\n")
table.remove(outtable, 1)
table.remove(outtable, #outtable)
table.remove(outtable, #outtable)
print(table.concat(outtable, "\n"))

local file = utility.open("dump.txt", "w", function(file)
  file:write(output)
end)

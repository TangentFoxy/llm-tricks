#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local file_name = arg[1]



local function strip_markdown(text)
  local tab = text:split("\n")
  table.remove(tab, 1)    -- codeblock opening
  table.remove(tab, #tab) -- end of codeblock
  print(table.concat(tab, "\n"))
end



local prompt = [[Return JSON: category, tags (array), summary (short)]]
-- local prompt = [[Return YAML: category, tags (array), summary (short)]]

if prompt:sub(-1) ~= "\n" then
  prompt = prompt .. "\n\n"
end

local file_contents = utility.open(file_name, "r", function(file)
  return file:read("*all")
end)
prompt = prompt .. file_contents

local model = "gemma3:4b"
-- local output = utility.capture_safe("ollama run " .. model .. " --nowordwrap " .. prompt:enquote())

-- local embedding_model = "nomic-embed-text"
-- local output = utility.capture_safe("ollama run " .. embedding_model .. " " .. file_contents:enquote())

-- output = output:sub(1, -2) -- strip extra newline from utility.capture_safe

-- strip YAML frontmatter (if present)
--   can error, will return nil & error message
local function strip_frontmatter(text)
  local tab = text:split("\n")
  if tab[1] == "---" then
    table.remove(tab, 1)
    while true do
      local done = tab[1] == "---"
      table.remove(tab, 1)
      if done then
        return table.concat(tab, "\n")
      elseif #tab < 1 then
        return nil, "Invalid YAML frontmatter."
      end
    end
  end
  return text
end

-- print(output)

print(strip_frontmatter(file_contents))
-- print(strip_markdown(output))

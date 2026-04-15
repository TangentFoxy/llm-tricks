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

tree(".", function(path_name)
  print(path_name)
end)
os.exit()



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

local embedding_model = "nomic-embed-text"
local output = utility.capture_safe("ollama run " .. embedding_model .. " " .. file_contents:enquote())

output = output:sub(1, -2) -- strip extra newline from utility.capture_safe

print(output)

-- print(strip_markdown(output))

local embedding_metatable = {
  __tojson = function(self, state)
    return self.vector
  end
}

local output = {
  file_name = file_name,
  vector = setmetatable({ vector = output }, embedding_metatable),
}

print(json.encode(output, { indent = true }))

-- local file = utility.open("dump.txt", "w", function(file)
--   file:write(output)
-- end)

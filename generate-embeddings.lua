#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local PATH = "notebook"
local whitelist = { md = true, }

local embedding_model = "nomic-embed-text"
local maximum_file_size = 2048

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

local function leftpad(text, length)
  return string.rep("0", length - #(tostring(text))) .. text
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
  local function _run()
    local file_name = file_list[i]

    -- stripping YAML frontmatter before generating embeddings
    local file_contents = utility.open(file_name, "r", function(file)
      return file:read("*all")
    end)

    local tmp_file_contents, error_message = strip_frontmatter(file_contents)
    if tmp_file_contents == nil then
      print("ERROR: " .. file_name .. " " .. error_message)
      tmp_file_contents = file_contents
    end

    if #tmp_file_contents == 0 then
      print(file_name .. "\n is empty and will be skipped.")
      return
    end

    if #tmp_file_contents > maximum_file_size then
      print(file_name .. "\n is too long. Only the first " .. maximum_file_size .. " bytes will be scanned.")
      tmp_file_contents = tmp_file_contents:sub(1, maximum_file_size)
    end

    local tmp_file_name = utility.tmp_file_name()
    utility.open(tmp_file_name, "w", function(file)
      file:write(tmp_file_contents)
    end)

    local output = utility.capture_safe("cat " .. tmp_file_name:enquote() .. " | ollama run " .. embedding_model)
    os.execute("rm " .. tmp_file_name)
    output = output:sub(1, -2) -- strip extra newline from utility.capture_safe

    if #output == 0 then
      print("Warning: " .. file_name .. " did not have embeddings generated.")
      return
    end

    output = setmetatable({ vector = output }, {
      __tojson = function(self, state)
        return self.vector
      end
    })

    embeddings[file_name] = { vector = output }

    print("Finished " .. leftpad(i, #tostring(#file_list)) .. "/" .. #file_list .. " (" .. leftpad(math.floor(i / #file_list * 100), 3) .. "%)")
  end

  _run()
end

utility.open("embeddings.json", "w", function(file)
  local output = json.encode(embeddings, { indent = true })
  file:write(output)
  file:write("\n")
end)

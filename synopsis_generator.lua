#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local default_model = "gemma4:12b-mlx"
local minimum_bytes = 1000
local maximum_bytes = 40000

local read_all = function(file_name)
  return utility.open(file_name, "r", function(file)
    return file:read("*all")
  end)
end
local write_all = function(file_name, text)
  return utility.open(file_name, "w", function(file)
    file:write(text)
    file:write("\n")
  end)
end

local files
if utility.path_exists("PRIVATE_DATA/file_list.json") then
  files = json.decode(read_all("PRIVATE_DATA/file_list.json"))
else
  files = {}
end

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

local strip_reasoning = function(text, reasoning_lines)
  if not reasoning_lines then reasoning_lines = {} end
  local tab = text:split("\n")
  table.remove(tab, 1) -- remove "Thinking..."

  while true do
    local done = tab[1] == "...done thinking."
    local line = table.remove(tab, 1)
    if done then
      table.remove(tab, 1) -- remove newline after end of thinking
      return table.concat(tab, "\n")
    elseif #tab < 1 then
      return text -- no reasoning output
    else
      reasoning_lines[#reasoning_lines + 1] = line -- export thinking lines
    end
  end
end

local send_prompt = function(text, model)
  if type(text) == "table" then text = table.concat(text, "\n") end

  local tmp_file_name = utility.tmp_file_name()
  utility.open(tmp_file_name, "w", function(file)
    file:write(text)
  end)

  -- word wrap breaks the raw output badly, so I need to implement my own for terminal output somehow
  local output = utility.capture_safe("cat " .. tmp_file_name:enquote() .. " | ollama run " .. (model or default_model) .. " --nowordwrap")
  os.execute("ollama stop " .. (model or default_model)) -- NOTE this makes things slower, but more stable
  os.execute("rm " .. tmp_file_name)
  if not output then error("ollama failed to generate output") end
  output = output:sub(1, -2) -- strip extra newline from utility.capture_safe

  output = strip_reasoning(output)

  return output
end

local tree
tree = function(path, fn)
  utility.list(path or ".", function(path_name)
    local blacklist = {
      [".git"] = true,
      [".gitkeep"] = true,
      [".gitignore"] = true,
      [".DS_Store"] = true,
    }
    if blacklist[path_name] then return end
    if utility.is_file(path_name) then
      fn(path_name)
    else
      tree(path .. utility.path_separator .. path_name, fn)
    end
  end)
end

local get_file_size = function(file_name)
  local file = io.open(file_name, "rb")
  if file then
    local size = file:seek("end")
    file:close()
    return size
  end
end

local refresh_file_list = function()
  local blacklist = { -- I'm only blacklisting binary formats because funny results happen with really invalid texts
    "jpg", "mp4", "pdf", "png", "webp", "jpeg", "gif",
  } for _, name in ipairs(blacklist) do blacklist[name] = true end

  local new_files_list = {}
  tree("PRIVATE_DATA/notebook", function(file_name)
    local _, _, extension = utility.split_path_components(file_name)
    if not blacklist[extension] then
      new_files_list[#new_files_list + 1] = file_name
    end
  end)
  files = new_files_list
  write_all("PRIVATE_DATA/file_list.json", json.encode(new_files_list, { indent = true }))
end



if arg[1] == "refresh_file_list" then
  print("Refresing file list...")
  refresh_file_list()
end

print(#files .. " files to select from.")
if #files == 0 then
  print("Run \"./synopsis_generator.lua refresh_file_list\" first.")
  os.exit(1)
end

while true do
  print("Selecting a file...")
  local file_name = files[math.random(1, #files)]
  local file_size = get_file_size(file_name)
  if file_size > minimum_bytes and file_size <= maximum_bytes then
    local text = read_all(file_name)
    text = strip_frontmatter(text)
    if #text > minimum_bytes and #text <= maximum_bytes then
      print(file_name .. " chosen.")
      os.exit(0)
    end
  end
end

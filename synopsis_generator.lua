#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local json = utility.require("dkjson")
local prompts = utility.require("prompts")

local default_model = "gemma4:12b-mlx"
local minimum_bytes = 1000
local maximum_bytes = 40000

local files
if utility.path_exists("PRIVATE_DATA/file_list.json") then
  files = utility.load_data("PRIVATE_DATA/file_list.json")
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

-- strip Markdown formatting of a JSON block
--  just returns the string if it doesn't match
local function strip_markdown_codeblock(text)
  local tab = text:split("\n")
  if tab[1] == "```json" then
    table.remove(tab, 1)
    table.remove(tab, #tab)
    return table.concat(tab, "\n")
  else
    return text
  end
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

  local thinking = {}
  output = strip_reasoning(output, thinking)

  return output, thinking
end

local refresh_file_list = function()
  local blacklist = { -- I'm only blacklisting binary formats because funny results happen with really invalid texts
    "jpg", "mp4", "pdf", "png", "webp", "jpeg", "gif",
  } for _, name in ipairs(blacklist) do blacklist[name] = true end

  local new_files_list = {}
  utility.tree("PRIVATE_DATA/notebook", {
    blacklist = utility.enumerate{".git", ".gitignore", ".gitkeep", ".DS_Store"}
  }, function(file_name)
    local _, _, extension = utility.split_path_components(file_name)
    if not blacklist[extension] then
      new_files_list[#new_files_list + 1] = file_name
    end
  end)
  files = new_files_list
  utility.save_data(new_files_list, "PRIVATE_DATA/file_list.json")
end

local generate_and_score = function(file_name, text)
  print("Writing synopsis...")
  local synopsis = send_prompt(prompts.synopsis_prompt .. text)
  print(synopsis)
  print("Scoring synopsis...")
  local scoring, thinking = send_prompt(prompts.scoring_prompt .. synopsis)
  print(scoring)
  local scoring_decoded = json.decode(scoring) -- likely will not work because it consistently returns Markdown instead of JSON
  if not scoring_decoded then
    scoring_decoded = json.decode(strip_markdown_codeblock(scoring))
  end

  local object = {
    synopsis = synopsis,
    scoring = scoring_decoded or scoring, -- either the correct values or a string of output that isn't JSON
    thinking = thinking,
  }

  utility.save_data(object, "PRIVATE_DATA/synopses/" .. utility.uuid() .. ".json")
end



os.execute("mkdir -p PRIVATE_DATA/synopses")

if arg[1] == "refresh_file_list" then
  print("Refresing file list...")
  refresh_file_list()
end

if arg[1] == "repair_synopsis_exports" then
  local path = "PRIVATE_DATA/synopses"
  utility.list(path, function(path_name)
    path_name = path .. utility.path_separator .. path_name
    if path_name:find("%.json") then
      local object = utility.load_data(path_name)
      if type(object.scoring) == "table" then return end -- don't fuck with working pieces
      local decoded = json.decode(strip_markdown_codeblock(object.scoring))
      if decoded then
        object.scoring = decoded
        utility.save_data(object, path_name)
      end
    end
  end)
  os.exit(0)
end

if arg[1] == "export_ordered_list_of_prompts" then
  local path = "PRIVATE_DATA/synopses"
  local items = {}
  local item_order = {}
  utility.list(path, function(path_name)
    local full_path = path .. utility.path_separator .. path_name
    if path_name:find("%.json") then
      local object = utility.load_data(full_path)
      items[path_name] = object
      if type(object.scoring) == "table" then
        local s = object.scoring
        local total_score = s.conflict_potential + s.emotional_potential + s.character_potential + s.worldbuilding_potential + s.expansion_potential + s.overall_promise + s.memorability + s.originality + s.curiosity + s.hook
        item_order[#item_order + 1] = { path_name = path_name, total_score = total_score, }
      end
    end
  end)
  table.sort(item_order, function(A,B) return A.total_score > B.total_score end)
  -- for k,v in pairs(item_order) do print(v.path_name,v.total_score) end
  local output = {
    "---",
    "title: Ordered Synopses (" .. #item_order .. " items)",
    "author: [\"Gemma4:12b-mlx\", \"Tangent\", \"Ollama\"]",
    "publisher: Tangent",
    "---",
    "",
  }
  for _, v in pairs(item_order) do
    local item = items[v.path_name]
    local text = item.synopsis
    local tab = text:split("\n")
    for index, line in ipairs(tab) do
      if line:sub(1, 1) == "#" then
        tab[index] = "#" .. tab[index]
      end
    end
    -- output[#output + 1] = "# " .. v.path_name .. " (" .. v.total_score .. ")\n\n" .. item.synopsis .. "\n"
    output[#output + 1] = "# " .. v.path_name .. " (" .. v.total_score .. ")\n\n" .. table.concat(tab, "\n") .. "\n"
    output[#output + 1] = "## Scoring\n\n```json\n" .. json.encode(item.scoring, { indent = true, }) .. "\n```\n"
  end
  utility.write_file("PRIVATE_DATA/Ordered Synopses.md", table.concat(output, "\n"))
  os.execute("pandoc \"PRIVATE_DATA/Ordered Synopses.md\" -o \"PRIVATE_DATA/Ordered Synopses.epub\"")
  os.exit(0)
end

print(#files .. " files to select from.")
if #files == 0 then
  print("Run \"./synopsis_generator.lua refresh_file_list\" first.")
  os.exit(1)
end

while true do
  print("Selecting a file...")
  local file_name = files[math.random(1, #files)]
  local file_size = utility.file_size(file_name)
  if file_size > minimum_bytes and file_size <= maximum_bytes then
    local text = utility.read_file(file_name)
    text = strip_frontmatter(text)
    if #text > minimum_bytes and #text <= maximum_bytes then
      print(file_name .. " chosen.")
      generate_and_score(file_name, text) -- kind of the main function, innit?
      -- os.exit(0)
    end
  end
end

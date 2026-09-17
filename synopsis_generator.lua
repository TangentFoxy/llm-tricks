#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local json = utility.require("dkjson")
local prompts = utility.require("prompts")
local text_processing = utility.require("text_processing")

local config = utility.get_config_with_defaults{
  models = {
    synopsis_generator = {
      model = "gemma4:12b-mlx",
      minimum_bytes = 1000,
      maximum_bytes = 40000,
    },
  },
}

local memory_path = "PRIVATE_DATA" .. utility.path_separator .. "memory"
local embeddings_file_path = memory_path .. utility.path_separator .. "+embeddings.json"
local data_path = "PRIVATE_DATA" .. utility.path_separator .. "synopses"
local data_location = data_path .. utility.path_separator .. "+file_list.json"

local refresh_file_list = function()
  assert(utility.path_exists(embeddings_file_path), "Run \"./refresh_sources.lua\" to set up memory.")
  local embeddings = utility.load_data(embeddings_file_path)

  local minimum_bytes = config.models.synopsis_generator.minimum_bytes
  local maximum_bytes = config.models.synopsis_generator.maximum_bytes

  local file_list = {}
  for file_name, sha512sum_list in pairs(embeddings.files) do
    local file_size = utility.file_size(file_name)
    if file_size >= minimum_bytes and file_size <= maximum_bytes then
      local text = text_processing.strip_frontmatter(utility.read_file(file_name))
      if #text >= minimum_bytes and #text <= maximum_bytes then
        file_list[#file_list + 1] = { file_name = file_name, }
      end
    end
  end

  utility.save_data(file_list, data_location)
  return file_list
end

local generate_and_score = function(file_name, text)
  print("Writing synopsis...")
  local synopsis = utility.llm_prompt(prompts.synopsis_prompt .. text, config.models.synopsis_generator.model)
  print(synopsis)
  print("Scoring synopsis...")
  local scoring, thinking = utility.llm_prompt(prompts.scoring_prompt .. synopsis, config.models.synopsis_generator.model)
  print(scoring)
  local scoring_decoded = json.decode(scoring) -- likely will not work because it consistently returns Markdown instead of JSON
  if not scoring_decoded then
    scoring_decoded = json.decode(text_processing.strip_markdown_codeblock(scoring))
  end

  local object = {
    synopsis = synopsis,
    scoring = scoring_decoded or scoring, -- either the correct values or a string of output that isn't JSON
    thinking = thinking,
  }

  utility.save_data(object, data_path .. utility.path_separator .. utility.uuid() .. ".json")
end

local export_ordered_list_of_prompts = function()
  local items = {}
  local item_order = {}

  utility.list(data_path, function(path_name)
    local full_path = data_path .. utility.path_separator .. path_name
    if full_path == data_location then return end

    local object = utility.load_data(full_path)
    items[path_name] = object
    if type(object.scoring) == "table" then
      local mean_score, total_score = utility.mean(object.scoring)
      item_order[#item_order + 1] = { path_name = path_name, total_score = total_score, mean_score = mean_score, }
    end
  end)

  table.sort(item_order, function(A,B) return A.mean_score > B.mean_score end)

  local output = {
    "---",
    "title: Ordered Synopses (" .. #item_order .. " items)",
    "author: [\"" .. config.models.synopsis_generator.model .. "\", \"Tangent\", \"Ollama\"]",
    "publisher: \"synopsis_generator.lua\"",
    "---",
    "",
  }

  for _, v in pairs(item_order) do
    local item = items[v.path_name]
    local text = item.synopsis
    local tab = text:split("\n")

    for index, line in ipairs(tab) do
      -- ensure no output heading is an H1; make H6 bold text lines instead
      if line:sub(1, 7) == "###### " then
        tab[index] = "**" .. line:sub(8) .. "**"
      elseif line:sub(1, 1) == "#" then
        tab[index] = "#" .. line
      end
    end

    output[#output + 1] = "# " .. v.path_name .. " (" .. v.total_score .. ")\n\n" .. table.concat(tab, "\n") .. "\n"
    output[#output + 1] = "## Scoring\n\n```json\n" .. json.encode(item.scoring, { indent = true, }) .. "\n```\n"
  end

  utility.write_file("PRIVATE_DATA/Ordered Synopses.md", table.concat(output, "\n"), "\n")
  os.execute("pandoc \"PRIVATE_DATA/Ordered Synopses.md\" -o \"PRIVATE_DATA/Ordered Synopses.epub\"")
end



os.execute("mkdir -p " .. data_path:enquote())

local file_list
if utility.path_exists(data_location) then
  file_list = utility.load_data(data_location)
end

if arg[1] == "refresh_file_list" then
  print("Refresing file list...")
  file_list = refresh_file_list()
  os.exit(0)
elseif arg[1] == "export_ordered_list_of_prompts" then
  export_ordered_list_of_prompts()
  os.exit(0)
end

assert(file_list and (#file_list > 0), "Run \"./synopsis_generator.lua refresh_file_list\" first.")

print(#file_list .. " files to select from.")
while true do
  local file_name = file_list[math.random(1, #file_list)].file_name
  local text = utility.read_file(file_name)
  print(file_name .. " chosen.")
  generate_and_score(file_name, text)
end

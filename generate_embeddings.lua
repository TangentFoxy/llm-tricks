#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local text_processing = utility.require("text_processing")
local timing = utility.require("timing")
local json = utility.require("dkjson")

-- local embedding_model = "nomic-embed-text"
-- local maximum_file_size = 2048
local embedding_model = "qwen3-embedding:0.6b"
local maximum_file_size = 32768

local NOTEBOOK_PATH = "PRIVATE_DATA/notebook"
local blacklist = utility.enumerate{ ".git", } -- accelerate processing by ignoring .git directory
local extension_whitelist = utility.enumerate{ "md", }



local function leftpad(text, length)
  return string.rep("0", length - #(tostring(text))) .. text
end



local file_list = {}
local embeddings = {}

timing.mark("Assembling file list.")
utility.tree(NOTEBOOK_PATH, {
  blacklist = blacklist,
  extension_whitelist = extension_whitelist,
}, function(file_name)
  file_list[#file_list + 1] = file_name
end)

timing.mark("Generating embeddings.")
for i = 1, #file_list do
  local function _run()
    local file_name = file_list[i]

    -- stripping YAML frontmatter before generating embeddings
    local file_contents = utility.read_file(file_name)
    local tmp_file_contents = text_processing.strip_frontmatter(file_contents)
    if #tmp_file_contents == 0 then
      print(file_name .. "\n is empty and will be skipped.")
      return
    end

    if #tmp_file_contents > maximum_file_size then
      print(file_name .. "\n is too long. Only the first " .. maximum_file_size .. " bytes will be scanned.")
      tmp_file_contents = tmp_file_contents:sub(1, maximum_file_size)
    end

    local output = utility.llm_prompt(tmp_file_contents, embedding_model)

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

timing.mark("Outputting embeddings in JSON.")
utility.save_data(embeddings, "PRIVATE_DATA/embeddings.json")

timing.mark("Finished.")
print("")
timing.display()

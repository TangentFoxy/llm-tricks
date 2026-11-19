#!/usr/bin/env luajit

-- the idea behind this file was to put epubs in PRIVATE_DATA/<directory>
-- then use "refresh_command":"../../ebook_text_extraction.lua" to extract them
-- and whitelist only txt files to actually get them into memory

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"

local log = utility.require("log")

log{
  debug = false,
}

local tmp_location = "/Volumes/Treat/Applications/calibre.app"

utility.list(".", function(file_name)
  local _, name, extension = utility.split_path_components(file_name)
  log("debug", path, name, extension)
  if not extension then return end
  if not (extension == "epub") then return end

  name = name:sub(1, -(#extension + 2))
  local command = tmp_location .. "/Contents/MacOS/ebook-convert "
    .. file_name:enquote() .. " " .. (name .. ".txt"):enquote()

  log("debug", command)
  os.execute(command)
end)

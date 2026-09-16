local stored_messages = {}
local display_levels = {}
local enable_logging = true
local message_limit = math.huge

-- USAGE:
--   -- set arbitrary log levels to be printed immediately
--   log{ info = true, warning = true, ducksauce = true, }
--   -- send anything (except nil) to a log level
--   log("bacom", true, "text", 5, function() end, {})
--   -- print all messages saved at a particular log level
--   log("error")
--   -- toggle ALL logging on and off with a boolean
--   log(false) -- this deletes all stored messages
--   -- set a maximum number of stored messages per log level
--   log(50) -- warning: reaching large limits makes logging expensive
--   -- do anything to the stored messages (this example deletes them all)
--  log(function(messages) return {} end)

return function(options, ...)
  local options_type = type(options)

  if (options_type == "string") and enable_logging then
    if not stored_messages[options] then stored_messages[options] = {} end
    local message_table = stored_messages[options]

    -- turn log message into text
    local tab = {...}
    for i = 1, #tab do
      tab[i] = tostring(tab[i])
    end
    local current_message = table.concat(tab, "\t")

    if #current_message == 0 then
      -- print all stored_messages of specified level
      for i = 1, #message_table do
        print(message_table[i])
      end

    else
      -- store message (and print if in display_levels)
      message_table[#message_table + 1] = current_message
      if #message_table > message_limit then table.remove(message_table, 1) end
      if display_levels[options] then print(current_message) end
    end

  -- set display_levels
  elseif options_type == "table" then
    for k,v in pairs(options) do
      display_levels[k] = v
    end

  elseif options_type == "number" then
    message_limit = options
    for k,v in pairs(stored_messages) do
      while #v > message_limit do
        table.remove(v, 1)
      end
    end

  -- turn all logging off and delete stored messages; or turn it on
  elseif options_type == "boolean" then
    if options then
      enable_logging = true
    else
      enable_logging = false
      stored_messages = {}
    end

  -- arbitrary access :D
  elseif options_type == "function" then
    local result = options(stored_messages)
    if type(result) == "table" then stored_messages = result end
  end
end

math.randomseed(os.time())

local utility

if package.config:sub(1, 1) == "\\" then
  utility = {
    OS = "Windows",
    path_separator = "\\",
    temp_directory = "C:\\Windows\\Temp\\",
    commands = {
      recursive_remove = "rmdir /s /q ",
      list = "dir /w /b ",
      which = "where ",
      move = "move ",
      silence_output = " >nul 2>nul",
      silence_errors = " 2>nul",
    },
  }
else
  utility = {
    OS = "Linux",
    path_separator = "/",
    temp_directory = "/tmp/",
    commands = {
      recursive_remove = "rm -r ",
      list = "ls -1a ",
      which = "which ",
      move = "mv ",
      silence_output = " >/dev/null 2>/dev/null",
      silence_errors = " 2>/dev/null",
    },
  }
end

utility.version = "1.6.0-modified"
-- WARNING: This will return "./" if the original script is called locally instead of with an absolute path!
if arg[0] ~= nil then
  utility.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) -- inspired by discussion in https://stackoverflow.com/q/6380820
else
  utility.path = "./"
end



local function standard_library_addition(tab, name, func)
  if tab[name] then
    print("WARNING: " .. tab .. "." .. name .. " was defined by another library. lua-utility may encounter errors due to a differing implementation.")
  else
    tab[name] = func
  end
end



-- trim6 from Lua users wiki (best all-round pure Lua performance)
standard_library_addition(string, "trim", function(s)
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end)

standard_library_addition(string, "enquote", function(s)
  return "\"" .. s:gsub("\"", "\\\"") .. "\""
end)

standard_library_addition(string, "gsplit", function(s, delimiter)
  local function escape_special_characters(s)
    local special_characters = "[()%%.[^$%]*+%-?]"
    if s == nil then return end
    return (s:gsub(special_characters, "%%%1"))
  end

  delimiter = delimiter or ","
  if s:sub(-#delimiter) ~= delimiter then s = s .. delimiter end
  return s:gmatch("(.-)" .. escape_special_characters(delimiter))
end)

standard_library_addition(string, "split", function(s, delimiter)
  local result = {}
  for item in s:gsplit(delimiter) do
    result[#result + 1] = item
  end
  return result
end)

utility.leftpad = function(text, length, character)
  return string.rep(character or " ", length - #(tostring(text))) .. text
end



utility.require = function(...)
  -- if libraries adjacent to this one aren't already loadable, make sure they are!
  if not package.path:find(utility.path, 1, true) then
    package.path = utility.path .. "?.lua;" .. package.path
  end
  return require(...)
end

-- errors if specified program isn't in the path
local _required_program_cache = {}
utility.required_program = function(name)
  if _required_program_cache[name] then
    return true
  end
  if os.execute(utility.commands.which .. tostring(name) .. utility.commands.silence_output) == 0 then
    _required_program_cache[name] = true
  else
    error("\n\n" .. tostring(name) .. " must be installed and in the path\n")
  end
end



-- always uses outputting to a temporary file to guarantee safety
utility.capture_safe = function(command, get_status)
  local file_name = utility.tmp_file_name()
  command = command .. " > " .. file_name
  if get_status then
    command = command .. "\necho $? >> " .. file_name
  end
  os.execute(command)

  local file = io.open(file_name, "r")
  local output = file:read("*all")
  file:close()
  os.execute("rm " .. file_name)

  if get_status then
    local start, finish = output:find("\n.-\n$")
    return tonumber(output:sub(start + 1, finish - 1)), output:sub(1, start)
  end

  return output
end
-- WARNING DEPRECATED
utility.capture = function(...)
  print("WARNING: Use utility.capture_safe or utility.capture_unsafe. This function will be removed.")
  return utility.capture_safe(...)
end

-- can hang indefinitely; not always available
utility.capture_unsafe = function(command)
  if io.popen then
    local file = assert(io.popen(command, 'r'))
    local output = assert(file:read('*all'))
    file:close()
    return output
  else
    print("WARNING: io.popen not available, using a temporary file to receive output from:\n", command)
    return utility.capture_safe(command)
  end
end



-- modified from my fork of lume
utility.uuid = function()
  local fn = function(x)
    local r = math.random(16) - 1
    r = (x == "x") and (r + 1) or (r % 4) + 9
    return ("0123456789abcdef"):sub(r, r)
  end
  return (("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"):gsub("[xy]", fn))
end

utility.tmp_file_name = function()
  return utility.temp_directory .. utility.uuid()
end



-- while I could replace this with a better implementation, I'm used to how it works and I might break existing scripts
utility.make_safe_file_name = function(file_name)
  file_name = file_name:gsub("[%\"%:%\\%!%@%#%$%%%^%*%=%{%}%|%;%<%>%?%/]", "") -- everything except the &
  file_name = file_name:gsub(" %&", ",")   -- replacing & with a comma works for 99% of things
  file_name = file_name:gsub("%&", ",")    -- replacing & with a comma works for 99% of things
  file_name = file_name:gsub("[%s+]", " ") -- more than one space in succession should be a single space
  return file_name
end

utility.split_path_components = function(file_path)
  local path, name, extension = string.match(file_path, "(.-)([^\\/]-%.?([^%.\\/]*))$")
  if name == extension then
    extension = nil
  end
  return path, name, extension
end

-- wrapper around io.open to prevent leaving a file handle open accidentally
-- throws errors instead of returning them
--   usage: utility.open(file_name, mode, function(file_handle) --[[ your code ]] end)
--       or utility.open(file_name, mode)(function(file_handle) --[[ your code ]] end)
utility.open = function(file_name, mode, func)
  local file, err = io.open(file_name, mode)
  if not file then error(err) end
  if func then
    local success, result = pcall(function() return func(file) end)
    file:close()
    if not success then error(result) end
    return result
  else
    return function(fn)
      local success, result = pcall(function() return fn(file) end)
      file:close()
      if not success then
        error(result)
      end
      return result
    end
  end
end

-- run a function on each file name in a directory
--   example list items: utility.list(".", print)  OR  utility.list(".")(print)
utility.list = function(path, func)
  local command = utility.commands.list
  if path then
    command = command .. path:enquote()
  end

  local output = utility.capture_safe(command)

  local run = function(fn)
    for line in output:gmatch("[^\r\n]+") do -- thanks to https://stackoverflow.com/a/32847589
      if not ((line == ".") or (line == "..")) then
        fn(line)
      end
    end
  end

  if func then
    run(func)
  else
    return run
  end
end
-- WARNING DEPRECATED
utility.ls = function(...)
  print("WARNING: Use utility.list. This function will be removed.")
  return utility.list(...)
end

local tree
tree = function(path, options, fn)
  if type(options) == "function" then
    fn = options
    options = {}
  end

  utility.list(path or ".", function(path_name)
    if options.blacklist and options.blacklist[path_name] then return end
    if options.whitelist and (not options.whitelist[path_name]) then return end

    if utility.is_file(path_name) then
      if options.extension_blacklist or options.extension_whitelist then
        local _, _, extension = utility.split_path_components(path_name)
        if options.extension_blacklist and options.extension_blacklist[extension] then return end
        if options.extension_whitelist and (not options.extension_whitelist[extension]) then return end
      end

      fn(path_name)
    else
      tree(path .. utility.path_separator .. path_name, options, fn)
    end
  end)
end
utility.tree = function(path, options, fn)
  tree(path, options, function(path_name)
    if path_name:find(path) == 1 then
      fn(path_name)
    else
      fn(path .. utility.path_separator .. path_name)
    end
  end)
end

utility.read_file = function(file_name)
  return utility.open(file_name, "r", function(file)
    return file:read("*all")
  end)
end

utility.write_file = function(file_name, ...)
  local text = table.concat{...}
  return utility.open(file_name, "w", function(file)
    file:write(text)
    -- file:write("\n") -- I need to make sure /I/ handle this instead of trying to automate it
  end)
end

utility.path_exists = function(file_name)
  local file = io.open(file_name, "r")
  if file then file:close() return true else return false end
end
-- WARNING DEPRECATED
utility.file_exists = function(...)
  print("WARNING: Use utility.path_exists instead, or utility.is_file to check for a file existing.")
  return utility.path_exists(...)
end

utility.is_file = function(file_name)
  local file = io.open(file_name, "r")
  if file then
    file:close()
    file = io.open(file_name, "a")
    if file then
      file:close()
      return true
    end
  end
  return false
end

utility.file_size = function(file_path)
  return utility.open(file_path, "rb", function(file) return file:seek("end") end)
end

utility.sha512sum = function(file_path)
  local sha512sum
  if (utility.OS == "Linux") or (utility.OS == "macOS") then
    sha512sum = utility.capture_safe("shasum -U -a 512 " .. file_path:enquote())
  elseif utility.OS == "Windows" then
    error("utility.sha512sum() not implemented for Windows.")
  end
  return sha512sum:sub(1, 128)
end



utility.escape_quotes_and_escapes = function(input)
  -- the order of these commands is important and must be preserved
  input = input:gsub("\\", "\\\\")
  input = input:gsub("\"", "\\\"")
  return input
end



-- only use for brief loads/saves, as this will block until a lock can be established
-- returns a UUID that can be checked on release to make sure unforeseen errors did not occur
utility.get_lock = function(file_path)
  local lock_obtained, lock_uuid, lock_file_path = false, utility.uuid(), file_path .. ".lock"
  repeat
    if not utility.is_file(lock_file_path) then
      pcall(function()
        utility.open(lock_file_path, "w", function(file)
          file:write(lock_uuid)
        end)
        utility.open(lock_file_path, "r", function(file)
          if file:read("*all") == lock_uuid then
            lock_obtained = true
          end
        end)
      end)
    end
    if not lock_obtained then
      print("Trying to obtain file lock: " .. lock_file_path)
      os.execute("sleep 1")
    end
  until lock_obtained
  return lock_uuid
end

-- specifying lock_uuid is optional, to error if a conflict occurred despite the lock (should not be possible)
utility.release_lock = function(file_path, lock_uuid)
  local lock_file_path = file_path .. ".lock"
  if lock_uuid then
    utility.open(lock_file_path, "r", function(file)
      if not (file:read("*all") == lock_uuid) then
        error("\n\n Lock UUID changed while lock was obtained. Data loss may have occurred. \n\n")
      end
    end)
  end
  os.execute("rm " .. lock_file_path:enquote())
end



local config_path = utility.path .. "config.json"
local config, config_lock
utility.get_config = function(skip_lock)
  if not config then
    if utility.is_file(config_path) then
      if not skip_lock then
        config_lock = utility.get_lock(config_path)
      end
      utility.open(config_path, "r", function(config_file)
        local json = utility.require("dkjson")
        config = json.decode(config_file:read("*all"))
      end)
    else
      config = {}
    end
  end
  return config
end

utility.save_config = function()
  if config then
    if not config_lock then
      print("Warning: A config lock file was not established.")
    end
    utility.open(config_path, "w", function(config_file)
      local json = utility.require("dkjson")
      config_file:write(json.encode(config, { indent = true }))
    end)
    if config_lock then
      utility.release_lock(config_path, config_lock)
    end
  else
    error("utility config not loaded")
  end
end

utility.get_config_with_defaults = function(defaults)
  local config = utility.get_config()

  local loop, changes_made
  loop = function(config_level, default_level)
    for k,v in pairs(default_level) do
      if not config_level[k] then
        config_level[k] = v
        changes_made = true
      elseif type(v) == "table" then
        loop(config_level[k], v)
      end
    end
  end
  loop(config, defaults)

  if changes_made then
    utility.save_config()
  else
    utility.release_lock(config_path)
  end

  return config
end



local data_file_locations = {}
utility.load_data = function(file_path)
  local data = utility.open(file_path, "r", function(data_file)
    local json = utility.require("dkjson")
    return json.decode(data_file:read("*all"))
  end)
  data_file_locations[data] = file_path
  return data
end

utility.save_data = function(data, file_path)
  local keys, loop = {}
  loop = function(tab)
    if type(tab) == "table" then
      for k,v in pairs(tab) do
        if not (type(k) == "number") then
          keys[k] = true
        end
        loop(v)
      end
    end
  end
  loop(data)
  local order = {}
  for k in pairs(keys) do order[#order + 1] = k end
  table.sort(order)

  file_path = file_path or data_file_locations[data]
  assert(file_path, "The object must have been loaded by utility.load_data or you must pass a path as the second argument.")
  utility.open(file_path, "w", function(data_file)
    local json = utility.require("dkjson")
    data_file:write(json.encode(data, { indent = true, keyorder = order, }))
    data_file:write("\n")
  end)
end



utility.deepcopy = function(tab)
  local copy
  if type(tab) == "table" then
    copy = {}
    for key, value in next, tab, nil do
      copy[utility.deepcopy(key)] = utility.deepcopy(value)
    end
    setmetatable(copy, utility.deepcopy(getmetatable(tab)))
  else
    copy = tab
  end
  return copy
end

utility.enumerate = function(list)
  local result = {}
  for _, value in ipairs(list) do
    result[value] = { name = value }
  end
  return result
end

local _
_, utility.inspect = pcall(function() return utility.require("inspect") end)
if _ then
  utility.print_table = function(tab)
    print(utility.inspect(tab))
  end
else
  utility.inspect = nil
  -- much simpler (and worse) print_table as fallback
  utility.print_table = function(tab, depth)
    depth = depth or 0
    if type(tab) == "table" then
      for k, v in pairs(tab) do
        print(string.rep("  ", depth) .. tostring(k) .. ":")
        if type(v) == "table" then
          utility.print_table(v, depth + 1)
        else
          print(string.rep("  ", depth + 1) .. tostring(v))
        end
      end
    else
      print(string.rep("  ", depth) .. tostring(tab))
    end
  end
end

utility.list_reverse = function(tab)
  for i = 1, math.floor(#tab/2) do
    tab[i], tab[#tab-i+1] = tab[#tab-i+1], tab[i]
  end
end



-- a super common need I'm encountering is wanting content from a URL without side effects
utility.curl_read = function(download_url, curl_options)
  utility.required_program("curl")
  local tmp_file_name = utility.tmp_file_name()
  local command = "curl "
  if curl_options then
    command = command .. curl_options .. " "
  end
  os.execute(command .. download_url:enquote() .. " > " .. tmp_file_name)
  local file_contents
  utility.open(tmp_file_name, "r", function(file)
    file_contents = file:read("*all")
  end)
  return file_contents
end



utility.llm_prompt = function(text, model, stabilize)
  utility.required_program("ollama")

  -- if stabilize == nil then stabilize = true end -- I may switch this back to defaulting on
  if type(text) == "table" then text = table.concat(text, "\n") end

  local config = utility.get_config("read-only")
  model = model or (config.ollama and config.ollama.default_model) or "gemma4:12b-mlx"

  local tmp_file_name = utility.tmp_file_name()
  utility.open(tmp_file_name, "w", function(file)
    file:write(text)
  end)

  -- word wrap fucks up usability of output in other things badly
  local output = utility.capture_safe("cat " .. tmp_file_name:enquote() .. " | ollama run " .. model .. " --nowordwrap")
  -- in previous testing, this improved system stability at the cost of speed by ensuring memory was not overtaxed by repeated calls to an LLM
  if stabilize then os.execute("ollama stop " .. model) end

  os.execute("rm " .. tmp_file_name)
  assert(output, "ollama failed to generate output")

  local strip_reasoning = function(text)
    local reasoning_lines = {}
    local tab = text:split("\n")
    table.remove(tab, 1) -- remove "Thinking..."

    while true do
      local done = tab[1] == "...done thinking."
      local line = table.remove(tab, 1)
      if done then
        table.remove(tab, 1) -- remove blank line after reasoning
        return table.concat(tab, "\n"), table.concat(reasoning_lines, "\n")
      elseif #tab < 1 then
        return text -- can only be reached if theere was no reasoning output
      else
        reasoning_lines[#reasoning_lines + 1] = line
      end
    end
  end

  output = output:sub(1, -2) -- strip extra newline from utility.capture_safe
  return strip_reasoning(output) -- this returns the text AND reasoning
end



-- additionally returns total and count
utility.mean = function(object)
  local total, count = 0, 0
  for _, value in pairs(object) do
    total = total + value
    count = count + 1
  end
  return total / count, total, count
end

-- additionally returns total
utility.median = function(object)
  local tab = {}
  for _, value in pairs(object) do
    tab[#tab + 1] = value
  end
  table.sort(tab)
  return tab[math.floor(#tab / 2)], #tab
end



if (utility.OS == "Linux") and (utility.capture_safe("uname"):find("Darwin") == 1) then
  utility.OS = "macOS"
end

return utility

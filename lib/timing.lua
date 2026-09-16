local timing = {}

local function human_readable_time(delta)
  if delta >= 2*7*24*60*60 then -- if more than 2 weeks
    delta = tostring(math.floor(delta/(7*24*60*60))/10) .. " weeks"
  elseif delta >= 2*24*60*60 then -- if more than 2 days
    delta = tostring(math.floor(delta/(24*60*60))/10) .. " days"
  elseif delta >= 2*60*60 then -- if more than 2 hours
    delta = tostring(math.floor(delta/(60*60/10))/10) .. " hours"
  elseif delta >= 2*60 then -- if more then 2 minutes
    delta = tostring(math.floor(delta/(60/10))/10) .. " minutes"
  else
    delta = tostring(delta) .. " seconds"
  end
  return delta
end

timing.display = function(n)
  local function _display(n)
    local time = timing[n]
    local previous = timing[n - 1]

    local delta = human_readable_time(time.time - previous.time)

    print(delta, previous.label)
  end

  if n then
    _display(n)
  else
    print("All measured timings:")
    for i = 2, #timing do
      _display(i)
    end
  end
end

timing.mark = function(label)
  timing[#timing + 1] = { label = label, time = os.time(), }
  if #timing > 1 then
    timing.display(#timing)
  end
  print("", "", label)
end

timing.estimate = function(current_position, total_operations)
  local delta = os.time() - timing[#timing].time
  local estimate = delta * total_operations / current_position - delta
  return human_readable_time(estimate)
end

return timing

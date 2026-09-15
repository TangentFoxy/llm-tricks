local timing = {}

timing.display = function(n)
  local function _display(n)
    local time = timing[n]
    local previous = timing[n - 1]

    local delta = time.time - previous.time
    if delta >= 2*60*60 then -- if more than 2 hours
      delta = tostring(math.floor(delta/(60*60/10))/10) .. " hours"
    elseif delta >= 120 then -- if more then 2 minutes
      delta = tostring(math.floor(delta/(60/10))/10) .. " minutes"
    else
      delta = tostring(delta) .. " seconds"
    end

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
end

return timing

local text_processing = {}

-- strip YAML frontmatter (if present)
--   on error, will return nil & error message
text_processing.strip_frontmatter = function(text)
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
text_processing.strip_markdown_codeblock = function(text)
  local tab = text:split("\n")
  if tab[1] == "```json" then
    table.remove(tab, 1)
    table.remove(tab, #tab)
    return table.concat(tab, "\n")
  else
    return text
  end
end

return text_processing

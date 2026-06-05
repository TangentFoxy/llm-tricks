#!/usr/bin/env luajit

package.path = (arg[0]:match("@?(.*/)") or arg[0]:match("@?(.*\\)")) .. "lib" .. package.config:sub(1, 1) .. "?.lua;" .. package.path
local utility = require "utility"
local json = utility.require("dkjson")

local function normalizing_cosine_similarity(a, b)
  local dot, normalized_a, normalized_b = 0, 0, 0

  for i = 1, #a do
    dot = dot + a[i] * b[i]
    normalized_a = normalized_a + a[i] * a[i]
    normalized_b = normalized_b + b[i] * b[i]
  end

  normalized_a = math.sqrt(normalized_a)
  normalized_b = math.sqrt(normalized_b)

  if normalized_a == 0 or normalized_b == 0 then
    return 0
  end

  return dot / (normalized_a * normalized_b)
end

local function cosine_similarity(a, b)
  local dot = 0

  for i = 1, #a do
    dot = dot + a[i] * b[i]
  end

  return dot
end



local embeddings = utility.open("PRIVATE_DATA/embeddings.json", "r", function(file)
  return json.decode(file:read("*all"))
end)

local embeddings_list = {}
for file_name, tab in pairs(embeddings) do
  table.insert(embeddings_list, { file_name = file_name, vector = tab.vector, })
end

local total_comparisons = #embeddings_list * (#embeddings_list - 1) / 2
local comparisons_completed = 0

local relations_list = {}
for i = 1, #embeddings_list - 1 do
  for j = i + 1, #embeddings_list do
    local a, b = embeddings_list[i], embeddings_list[j]
    local similarity = cosine_similarity(a.vector, b.vector)

    table.insert(relations_list, { similarity = similarity, a = a.file_name, b = b.file_name, })

    comparisons_completed = comparisons_completed + 1
    print(comparisons_completed .. "/" .. total_comparisons)
  end
end

table.sort(relations_list, function(a, b) return a.similarity > b.similarity end)

utility.open("PRIVATE_DATA/similarities.json", "w", function(file)
  file:write(json.encode(relations_list, { indent = true }))
end)

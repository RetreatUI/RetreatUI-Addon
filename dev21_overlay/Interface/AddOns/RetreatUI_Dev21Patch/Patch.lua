local RUI = RetreatUI
if not RUI or type(RUI.GetHUDSpellDefinitions) ~= "function" then return end
if RUI._dev21VenomancerCleanupApplied then return end

local originalGetHUDSpellDefinitions = RUI.GetHUDSpellDefinitions

local function Normalize(value)
  if type(value) ~= "string" then return "" end
  return string.lower(value):gsub("[^%a%d]", "")
end

local MAIN_ORDER = {
  "Chitin Rush",
  "Expulsion",
  "Barbed Stinger",
  "Regrow Exoskeleton",
  "Harden",
  "Lifeblood",
  "Vile Sting",
  "Nullifying Toxin",
}

local MAIN_SET = {}
for index, name in ipairs(MAIN_ORDER) do
  MAIN_SET[Normalize(name)] = index
end

local BLOCKED_ACTIONS = {
  ["beetleform"] = true,
  ["spiderform"] = true,
  ["spiderlord"] = true,
  ["carapaceregeneration"] = true,
  ["exposedflesh"] = true,
}

local function CopyDefinition(definition)
  local copy = {}
  for key, value in pairs(definition or {}) do copy[key] = value end
  return copy
end

local function AddDefinitionsByName(target, definitions)
  for _, definition in ipairs(definitions or {}) do
    local key = Normalize(definition and (definition.name or definition.buff))
    if key ~= "" and not target[key] then
      target[key] = definition
    end
  end
end

function RUI:GetHUDSpellDefinitions(className, row)
  if Normalize(className) ~= "venomancer" then
    return originalGetHUDSpellDefinitions(self, className, row)
  end

  local core = originalGetHUDSpellDefinitions(self, className, "core") or {}
  local utility = originalGetHUDSpellDefinitions(self, className, "utility") or {}

  if row == "core" then
    local available = {}
    AddDefinitionsByName(available, core)
    AddDefinitionsByName(available, utility)

    local result = {}
    for index, name in ipairs(MAIN_ORDER) do
      local definition = available[Normalize(name)]
      if definition then
        local copy = CopyDefinition(definition)
        copy.hudRow = "core"
        copy.order = index * 10
        result[#result + 1] = copy
      end
    end
    return result
  end

  if row == "utility" then
    local result = {}
    for _, definition in ipairs(utility) do
      local key = Normalize(definition and (definition.name or definition.buff))
      if key ~= "" and not MAIN_SET[key] and not BLOCKED_ACTIONS[key] then
        result[#result + 1] = CopyDefinition(definition)
      end
    end
    table.sort(result, function(left, right)
      local a = tonumber(left.order) or 9999
      local b = tonumber(right.order) or 9999
      if a ~= b then return a < b end
      return tostring(left.name or left.buff or "") < tostring(right.name or right.buff or "")
    end)
    return result
  end

  return originalGetHUDSpellDefinitions(self, className, row)
end

RUI._dev21VenomancerCleanupApplied = true

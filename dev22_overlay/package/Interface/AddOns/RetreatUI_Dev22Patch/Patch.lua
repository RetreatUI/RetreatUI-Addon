local PATCH_VERSION = "1.0.2-dev.22"

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

local function Normalize(value)
  if type(value) ~= "string" then return "" end
  return string.lower(value):gsub("[^%a%d]", "")
end

local MAIN_INDEX = {}
for index, name in ipairs(MAIN_ORDER) do
  MAIN_INDEX[Normalize(name)] = index
end

local BLOCKED_ACTIONS = {
  beetleform = true,
  spiderform = true,
  spiderlord = true,
  carapaceregeneration = true,
  exposedflesh = true,
  venomtippoison = true,
  hivebreak = true,
  carapacecrash = true,
  clawstrike = true,
}

local VENOMANCER_MARKERS = {
  chitinrush = true,
  expulsion = true,
  barbedstinger = true,
  regrowexoskeleton = true,
  harden = true,
  lifeblood = true,
  vilesting = true,
  nullifyingtoxin = true,
  venomtippoison = true,
  hivebreak = true,
  carapacecrash = true,
  clawstrike = true,
  beetleform = true,
  spiderlord = true,
  carapaceregeneration = true,
  exposedflesh = true,
}

local function CopyDefinition(definition)
  local copy = {}
  for key, value in pairs(definition or {}) do copy[key] = value end
  return copy
end

local function DefinitionKey(definition)
  return Normalize(definition and (definition.name or definition.buff))
end

local function AddAvailable(target, definitions)
  for _, definition in ipairs(definitions or {}) do
    local key = DefinitionKey(definition)
    if key ~= "" then
      local current = target[key]
      if not current or (definition.hudRow and not current.hudRow) then
        target[key] = definition
      end
    end
  end
end

local function FrameBelongsToVenomancer(frame)
  local current = frame
  for _ = 1, 6 do
    if not current then break end
    local name = current.GetName and current:GetName()
    if name and string.find(Normalize(name), "venomancer", 1, true) then return true end
    current = current.GetParent and current:GetParent() or nil
  end
  return false
end

local function DefinitionsLookVenomancer(definitions)
  local matches = 0
  for _, definition in ipairs(definitions or {}) do
    if VENOMANCER_MARKERS[DefinitionKey(definition)] then
      matches = matches + 1
      if matches >= 2 then return true end
    end
  end
  return false
end

local function ApplyPatch()
  local RUI = _G.RetreatUI
  local W = RUI and RUI.HUDWidgets
  if not RUI or not W then return false end
  if type(RUI.GetHUDSpellDefinitions) ~= "function" then return false end
  if type(W.BuildSpellRow) ~= "function" then return false end
  if RUI._dev22VenomancerCleanupApplied then return true end

  local originalGetter = RUI.GetHUDSpellDefinitions
  local originalBuildSpellRow = W.BuildSpellRow

  local function CollectAvailable(incoming)
    local available = {}
    AddAvailable(available, incoming)
    AddAvailable(available, originalGetter(RUI, "Venomancer", "core") or {})
    AddAvailable(available, originalGetter(RUI, "Venomancer", "utility") or {})
    local database = RUI.spellDatabase and RUI.spellDatabase["Venomancer"]
    AddAvailable(available, database and database.spells or {})
    return available
  end

  local function BuildMain(incoming)
    local available = CollectAvailable(incoming)
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

  local function BuildUtility(incoming)
    local result = {}
    for _, definition in ipairs(incoming or {}) do
      local key = DefinitionKey(definition)
      if key ~= "" and not MAIN_INDEX[key] and not BLOCKED_ACTIONS[key] then
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

  function RUI:GetHUDSpellDefinitions(className, row)
    if Normalize(className) ~= "venomancer" then
      return originalGetter(self, className, row)
    end
    if row == "core" then
      return BuildMain(originalGetter(self, className, row) or {})
    end
    if row == "utility" then
      return BuildUtility(originalGetter(self, className, row) or {})
    end
    return originalGetter(self, className, row)
  end

  function W:BuildSpellRow(rowFrame, definitions, ...)
    if FrameBelongsToVenomancer(rowFrame) or DefinitionsLookVenomancer(definitions) then
      local iconSize = tonumber(select(1, ...)) or 0
      if iconSize >= 36 then
        definitions = BuildMain(definitions)
      else
        definitions = BuildUtility(definitions)
      end
    end
    return originalBuildSpellRow(self, rowFrame, definitions, ...)
  end

  RUI._dev22VenomancerCleanupApplied = true
  RUI.dev22PatchVersion = PATCH_VERSION

  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff72e519RetreatUI " .. PATCH_VERSION .. " Venomancer cleanup loaded.|r")
  end
  return true
end

if not ApplyPatch() then
  local loader = CreateFrame("Frame")
  loader:RegisterEvent("ADDON_LOADED")
  loader:RegisterEvent("PLAYER_LOGIN")
  loader:SetScript("OnEvent", function(self)
    if ApplyPatch() then
      self:UnregisterAllEvents()
      self:SetScript("OnEvent", nil)
    end
  end)
end

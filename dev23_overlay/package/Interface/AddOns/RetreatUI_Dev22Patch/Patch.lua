local PATCH_VERSION = "1.0.2-dev.23"

local function Normalize(value)
  if type(value) ~= "string" then return "" end
  return string.lower(value):gsub("[^%a%d]", "")
end

-- Only these action icons are removed from Venomancer's large/main row.
-- The existing dev.20 records, textures, preview state and learned callbacks are
-- deliberately left untouched.
local BLOCKED_MAIN = {
  venomtippoison = true,
  hivebreak = true,
  carapacecrash = true,
  clawstrike = true,

  -- Mechanic/form records must remain in their dedicated trackers.
  beetleform = true,
  spiderform = true,
  spiderlord = true,
  carapaceregeneration = true,
  exposedflesh = true,
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
  spiderform = true,
  spiderlord = true,
  carapaceregeneration = true,
  exposedflesh = true,
}

local function ForEachDefinitionName(definition, callback)
  if type(definition) ~= "table" then return end
  local fields = {
    definition.name,
    definition.buff,
    definition.spellName,
    definition.previewName,
    definition.label,
    definition.title,
    definition.key,
  }
  for _, value in ipairs(fields) do
    local key = Normalize(value)
    if key ~= "" and callback(key) then return true end
  end
  for _, value in ipairs(definition.aliases or {}) do
    local key = Normalize(value)
    if key ~= "" and callback(key) then return true end
  end
  return false
end

local function DefinitionMatches(definition, lookup)
  return ForEachDefinitionName(definition, function(key)
    return lookup[key] == true
  end) == true
end

local function FrameBelongsToVenomancer(frame)
  local current = frame
  for _ = 1, 8 do
    if not current then break end
    local name = current.GetName and current:GetName()
    if name and string.find(Normalize(name), "venomancer", 1, true) then
      return true
    end
    current = current.GetParent and current:GetParent() or nil
  end
  return false
end

local function DefinitionsLookVenomancer(definitions)
  local matches = 0
  for _, definition in ipairs(definitions or {}) do
    if DefinitionMatches(definition, VENOMANCER_MARKERS) then
      matches = matches + 1
      if matches >= 2 then return true end
    end
  end
  return false
end

local function IconIsShown(icon)
  if not icon then return false end
  if type(icon.IsShown) == "function" then return icon:IsShown() end
  return icon.shown ~= false
end

local function FilterMainRow(row, size, spacing)
  if not row then return 0, 0 end
  size = tonumber(size) or 38
  spacing = tonumber(spacing) or 1

  local kept = {}
  local removed = 0
  for _, icon in ipairs(row.icons or {}) do
    if IconIsShown(icon) and icon.definition then
      if DefinitionMatches(icon.definition, BLOCKED_MAIN) then
        if icon.Hide then icon:Hide() end
        removed = removed + 1
      else
        kept[#kept + 1] = icon
      end
    end
  end

  local count = #kept
  local total = count > 0 and (count * size + (count - 1) * spacing) or 0
  for index, icon in ipairs(kept) do
    if icon.ClearAllPoints then icon:ClearAllPoints() end
    if icon.SetPoint then
      icon:SetPoint("CENTER", row, "CENTER", -total / 2 + size / 2 + (index - 1) * (size + spacing), 0)
    end
    if icon.Show then icon:Show() end
  end
  return count, removed
end

local function ApplyPatch()
  local RUI = _G.RetreatUI
  local W = RUI and RUI.HUDWidgets
  if not RUI or not W or type(W.BuildSpellRow) ~= "function" then return false end
  if RUI._dev23VenomancerCleanupApplied then return true end

  local originalBuildSpellRow = W.BuildSpellRow

  function W:BuildSpellRow(row, definitions, size, spacing, ...)
    local results = {originalBuildSpellRow(self, row, definitions, size, spacing, ...)}

    -- The large row is the only row touched. We first let RetreatUI dev.20
    -- build it normally, then hide/recenter only the explicitly blocked icons.
    if (tonumber(size) or 0) >= 36
      and (FrameBelongsToVenomancer(row) or DefinitionsLookVenomancer(definitions)) then
      FilterMainRow(row, size, spacing)
    end

    return unpack(results)
  end

  RUI._dev23FilterVenomancerMainRow = FilterMainRow
  RUI._dev23VenomancerCleanupApplied = true
  RUI.dev23PatchVersion = PATCH_VERSION

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

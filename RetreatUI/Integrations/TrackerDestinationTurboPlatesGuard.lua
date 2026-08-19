local RUI = RetreatUI
if not RUI or RUI._trackerDestinationTurboGuardLoaded then return end

-- Older RetreatUI builds automatically whitelisted curated class debuffs in
-- TurboPlates. Destination-aware profiles must not inherit that behavior, or a
-- debuff can remain visible even after Nameplates is unchecked in Tracker Builder.
local LEGACY_PLAYER_DEBUFF_NAMES = {
  "Curse of Xoroth", "Torn Flesh", "Ritual Fire", "Bulwark of Xoroth",
  "Pestilence of Famine", "Pestilence of War", "Pestilence of Conquest",
}

local function DesiredNameplateDebuffs(className)
  local desired = {}
  if not RUI.GetTrackerDestinationEntries then return desired end
  for _, entry in ipairs(RUI:GetTrackerDestinationEntries(className, "nameplates", "debuff") or {}) do
    local spellID = tonumber(entry.auraID) or tonumber(entry.spellID)
    if spellID and spellID > 0 then desired[spellID] = true end
  end
  return desired
end

local function LegacyCandidateIDs(className)
  local result = {}
  local function Add(name, id)
    local spellID = tonumber(id)
    if not spellID and name and RUI.GetSpellID then
      local ok, resolved = pcall(RUI.GetSpellID, RUI, name)
      if ok then spellID = tonumber(resolved) end
    end
    if spellID and spellID > 0 then result[spellID] = true end
  end

  for _, name in ipairs(LEGACY_PLAYER_DEBUFF_NAMES) do Add(name, nil) end
  if RUI.GetTargetDebuffDefinitions then
    local ok, definitions = pcall(RUI.GetTargetDebuffDefinitions, RUI, className)
    if ok and type(definitions) == "table" then
      for _, definition in ipairs(definitions) do
        Add(definition.name, definition.id)
      end
    end
  end
  return result
end

function RUI:CleanLegacyTurboPlatesTrackerWhitelists(className)
  if type(TurboPlatesDB) ~= "table" then return false, "TurboPlates is not loaded" end
  TurboPlatesDB.auras = TurboPlatesDB.auras or {}
  TurboPlatesDB.auras.whitelist = TurboPlatesDB.auras.whitelist or {}

  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if type(className) ~= "string" or className == "" then return false, "class unavailable" end

  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.integrations = RetreatUIDB.integrations or {}
  RetreatUIDB.integrations.turboLegacyAutoWhitelistBackup = RetreatUIDB.integrations.turboLegacyAutoWhitelistBackup or {}
  local backup = RetreatUIDB.integrations.turboLegacyAutoWhitelistBackup
  local desired = DesiredNameplateDebuffs(className)
  local removed = 0

  for spellID in pairs(LegacyCandidateIDs(className)) do
    if not desired[spellID] and TurboPlatesDB.auras.whitelist[spellID] ~= nil then
      local key = tostring(spellID)
      if backup[key] == nil then backup[key] = TurboPlatesDB.auras.whitelist[spellID] end
      TurboPlatesDB.auras.whitelist[spellID] = nil
      removed = removed + 1
    end
  end

  return true, removed
end

-- If the legacy TurboPlates profile installer runs later, let it finish first,
-- then immediately remove its old auto-whitelist entries and re-apply only the
-- explicit Tracker Builder Nameplates destination.
local BaseApplyTurboPlatesRuntime = RUI.ApplyTurboPlatesRuntime
if type(BaseApplyTurboPlatesRuntime) == "function" then
  function RUI:ApplyTurboPlatesRuntime(...)
    local ok, message = BaseApplyTurboPlatesRuntime(self, ...)
    if ok then
      local className = self.GetDetectedClass and self:GetDetectedClass() or nil
      pcall(self.CleanLegacyTurboPlatesTrackerWhitelists, self, className)
      if self.ApplyTurboPlatesTrackerDestinations then
        pcall(self.ApplyTurboPlatesTrackerDestinations, self, className)
      end
    end
    return ok, message
  end
end

local className = RUI.GetDetectedClass and RUI:GetDetectedClass() or nil
if className then
  pcall(RUI.CleanLegacyTurboPlatesTrackerWhitelists, RUI, className)
  if RUI.ApplyTrackerDestinations then pcall(RUI.ApplyTrackerDestinations, RUI, className) end
end

RUI._trackerDestinationTurboGuardLoaded = true

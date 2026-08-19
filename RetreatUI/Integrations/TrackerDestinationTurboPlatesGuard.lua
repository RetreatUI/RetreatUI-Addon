local RUI = RetreatUI
if not RUI or RUI._trackerDestinationTurboGuardLoaded then return end

-- Older RetreatUI builds automatically whitelisted curated class debuffs in
-- TurboPlates. Destination-aware profiles must not inherit that behavior, or a
-- debuff can remain visible even after Nameplates is unchecked in Tracker Builder.
local LEGACY_PLAYER_DEBUFF_NAMES = {
  "Curse of Xoroth", "Torn Flesh", "Ritual Fire", "Bulwark of Xoroth",
  "Pestilence of Famine", "Pestilence of War", "Pestilence of Conquest",
}

local function HasTrackingType(entry, wanted)
  if type(entry) ~= "table" then return false end
  if type(entry.trackingTypes) == "table" then
    for _, value in ipairs(entry.trackingTypes) do
      if value == wanted then return true end
    end
  end
  return entry.trackingType == wanted
end

local function EntrySpellID(entry)
  if type(entry) ~= "table" then return nil end
  local spellID = tonumber(entry.auraID) or tonumber(entry.spellID)
  if not spellID and entry.auraName and RUI.GetSpellID then
    local ok, resolved = pcall(RUI.GetSpellID, RUI, entry.auraName)
    if ok then spellID = tonumber(resolved) end
  end
  if not spellID and entry.name and RUI.GetSpellID then
    local ok, resolved = pcall(RUI.GetSpellID, RUI, entry.name)
    if ok then spellID = tonumber(resolved) end
  end
  return spellID and spellID > 0 and spellID or nil
end

local function DesiredNameplateDebuffs(className)
  local desired = {}
  if not RUI.GetTrackerDestinationEntries then return desired end
  for _, entry in ipairs(RUI:GetTrackerDestinationEntries(className, "nameplates", "debuff") or {}) do
    local spellID = EntrySpellID(entry)
    if spellID then desired[spellID] = true end
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

-- TurboPlates documents blacklist entries as spells that are never shown and
-- whitelist entries as spells that bypass normal filters. For every selected
-- RetreatUI debuff tracker, make the destination checkbox authoritative:
-- Nameplates ON  -> whitelist it and remove any blacklist entry.
-- Nameplates OFF -> blacklist it and remove any whitelist entry.
-- Removing the tracker entirely restores the pre-RetreatUI TurboPlates state.
local function ApplyAuthoritativeTrackerDestinations(className)
  if type(TurboPlatesDB) ~= "table" then return false, "TurboPlates is not loaded" end
  TurboPlatesDB.auras = TurboPlatesDB.auras or {}
  TurboPlatesDB.auras.whitelist = TurboPlatesDB.auras.whitelist or {}
  TurboPlatesDB.auras.blacklist = TurboPlatesDB.auras.blacklist or {}

  className = className or (RUI.GetDetectedClass and RUI:GetDetectedClass())
  if type(className) ~= "string" or className == "" then return false, "class unavailable" end

  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.integrations = RetreatUIDB.integrations or {}
  RetreatUIDB.integrations.turboTrackerDestinationAuthority = RetreatUIDB.integrations.turboTrackerDestinationAuthority or {}
  local managed = RetreatUIDB.integrations.turboTrackerDestinationAuthority
  local selected = {}

  for _, entry in ipairs(RUI:GetSelectedTrackers(className) or {}) do
    if HasTrackingType(entry, "debuff") then
      local spellID = EntrySpellID(entry)
      if spellID then
        local enabled = RUI.TrackerUsesDestination and RUI:TrackerUsesDestination(entry, "nameplates") or false
        selected[spellID] = enabled and true or false
      end
    end
  end

  for key, record in pairs(managed) do
    local spellID = tonumber(record.spellID) or tonumber(key)
    if spellID and selected[spellID] == nil then
      if record.hadWhitelist then
        TurboPlatesDB.auras.whitelist[spellID] = record.originalWhitelist
      else
        TurboPlatesDB.auras.whitelist[spellID] = nil
      end
      if record.hadBlacklist then
        TurboPlatesDB.auras.blacklist[spellID] = record.originalBlacklist
      else
        TurboPlatesDB.auras.blacklist[spellID] = nil
      end
      managed[key] = nil
    end
  end

  for spellID, enabled in pairs(selected) do
    local key = tostring(spellID)
    if not managed[key] then
      managed[key] = {
        spellID = spellID,
        hadWhitelist = TurboPlatesDB.auras.whitelist[spellID] ~= nil,
        originalWhitelist = TurboPlatesDB.auras.whitelist[spellID],
        hadBlacklist = TurboPlatesDB.auras.blacklist[spellID] ~= nil,
        originalBlacklist = TurboPlatesDB.auras.blacklist[spellID],
      }
    end

    if enabled then
      TurboPlatesDB.auras.blacklist[spellID] = nil
      TurboPlatesDB.auras.whitelist[spellID] = true
    else
      TurboPlatesDB.auras.whitelist[spellID] = nil
      TurboPlatesDB.auras.blacklist[spellID] = true
    end
  end

  return true, "TurboPlates tracker destinations enforced"
end

local BaseApplyTurboPlatesTrackerDestinations = RUI.ApplyTurboPlatesTrackerDestinations
if type(BaseApplyTurboPlatesTrackerDestinations) == "function" then
  function RUI:ApplyTurboPlatesTrackerDestinations(className)
    local ok, message = BaseApplyTurboPlatesTrackerDestinations(self, className)
    local authorityOK, authorityMessage = ApplyAuthoritativeTrackerDestinations(className)
    if not ok then return ok, message end
    return authorityOK, authorityMessage or message
  end
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

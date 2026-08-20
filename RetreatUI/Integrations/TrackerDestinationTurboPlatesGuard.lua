local RUI = RetreatUI
if not RUI or RUI._trackerDestinationTurboGuardLoaded then return end

-- beta.45 migration guard. TurboPlates is profile-owned now; this file only
-- unwinds RetreatUI's older destination-management state and prevents the old
-- runtime helper from re-inserting legacy tracker whitelists.

local LEGACY_PLAYER_DEBUFF_NAMES = {
  "Curse of Xoroth", "Torn Flesh", "Ritual Fire", "Bulwark of Xoroth",
  "Pestilence of Famine", "Pestilence of War", "Pestilence of Conquest",
}

local function EnsureAuraTables()
  if type(TurboPlatesDB) ~= "table" then return nil end
  TurboPlatesDB.auras = TurboPlatesDB.auras or {}
  TurboPlatesDB.auras.whitelist = TurboPlatesDB.auras.whitelist or {}
  TurboPlatesDB.auras.blacklist = TurboPlatesDB.auras.blacklist or {}
  return TurboPlatesDB.auras
end

local function RestoreManagedRecord(auras, record, legacyShape)
  if type(record) ~= "table" then return end
  local spellID = tonumber(record.spellID)
  if not spellID then return end
  if legacyShape then
    if record.hadOriginal then auras.whitelist[spellID] = record.original
    else auras.whitelist[spellID] = nil end
    return
  end
  if record.hadWhitelist then auras.whitelist[spellID] = record.originalWhitelist
  else auras.whitelist[spellID] = nil end
  if record.hadBlacklist then auras.blacklist[spellID] = record.originalBlacklist
  else auras.blacklist[spellID] = nil end
end

function RUI:RetireLegacyTrackerDestinationState()
  local auras = EnsureAuraTables()
  if not auras then return false, "TurboPlates is not loaded" end
  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.integrations = RetreatUIDB.integrations or {}
  local integrations = RetreatUIDB.integrations
  local restored = 0

  for _, record in pairs(integrations.turboPlatesTrackerWhitelist or {}) do
    RestoreManagedRecord(auras, record, true); restored = restored + 1
  end
  integrations.turboPlatesTrackerWhitelist = {}

  for _, record in pairs(integrations.turboTrackerDestinationAuthority or {}) do
    RestoreManagedRecord(auras, record, false); restored = restored + 1
  end
  integrations.turboTrackerDestinationAuthority = {}
  integrations.turboDestinationRoutingRetired = true
  integrations.turboDestinationRoutingRetiredVersion = self.version
  return true, restored
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
  for _, name in ipairs(LEGACY_PLAYER_DEBUFF_NAMES) do Add(name) end
  if RUI.GetTargetDebuffDefinitions then
    local ok, definitions = pcall(RUI.GetTargetDebuffDefinitions, RUI, className)
    if ok and type(definitions) == "table" then
      for _, definition in ipairs(definitions) do Add(definition.name, definition.id) end
    end
  end
  return result
end

local BaseApplyTurboPlatesRuntime = RUI.ApplyTurboPlatesRuntime
if type(BaseApplyTurboPlatesRuntime) == "function" then
  function RUI:ApplyTurboPlatesRuntime(...)
    local auras = EnsureAuraTables()
    local className = self.GetDetectedClass and self:GetDetectedClass() or nil
    local before = {}
    if auras then
      for spellID in pairs(LegacyCandidateIDs(className)) do
        before[spellID] = {exists=auras.whitelist[spellID] ~= nil, value=auras.whitelist[spellID]}
      end
    end

    local ok, message = BaseApplyTurboPlatesRuntime(self, ...)
    auras = EnsureAuraTables()
    if ok and auras then
      for spellID, original in pairs(before) do
        if original.exists then auras.whitelist[spellID] = original.value
        else auras.whitelist[spellID] = nil end
      end
      pcall(self.RetireLegacyTrackerDestinationState, self)
    end
    return ok, message
  end
end

if type(TurboPlatesDB) == "table" then pcall(RUI.RetireLegacyTrackerDestinationState, RUI) end

RUI._trackerDestinationTurboGuardLoaded = true
RUI.trackerDestinationTurboGuardSchema = 2

local RUI = RetreatUI
if not RUI then return end

-- Build-aware HUD profiles ---------------------------------------------------
-- RetreatUI keeps one layout per detected class/build. The build detector uses
-- the active Character Advancement slot plus the learned class HUD records, so
-- switching talents/specs automatically swaps both the visible trackers and
-- the saved HUD layout without carrying stale spells across builds.

local PROFILE_VERSION = 4
local refreshFrame
local refreshSerial = 0
local buildStateSerial = 0
local profileUpgradeFromVersion

local function NormalizeClass(className)
  if type(RUI.NormalizeClassName) == "function" then
    return RUI:NormalizeClassName(className) or className
  end
  return className
end

local function HashText(text)
  local hash = 5381
  for index = 1, #text do
    hash = (hash * 33 + string.byte(text, index)) % 4294967291
  end
  return string.format("%08x", hash)
end

local function EnsureStore()
  local db = RUI:EnsureDB()
  db.hudProfiles = db.hudProfiles or {}
  if profileUpgradeFromVersion == nil then profileUpgradeFromVersion = tonumber(db.hudProfiles.version) or 0 end
  db.hudProfiles.version = PROFILE_VERSION
  db.hudProfiles.v2MigratedClasses = db.hudProfiles.v2MigratedClasses or {}
  db.hudProfiles.v4SizeRollback = db.hudProfiles.v4SizeRollback or {}
  db.hudProfiles.v4PyromancerAligned = db.hudProfiles.v4PyromancerAligned or {}
  db.hudProfiles.classes = db.hudProfiles.classes or {}
  db.hudProfiles.activeBuilds = db.hudProfiles.activeBuilds or {}
  db.hudProfiles.lastDetected = db.hudProfiles.lastDetected or {}
  return db.hudProfiles
end

local function CloneLayout(layout)
  return RUI:DeepCopy(layout or RUI.defaultLayout or RUI.layout or {})
end

local function MergeMissing(target, baseline)
  if type(target) ~= "table" or type(baseline) ~= "table" then return end
  for key, value in pairs(baseline) do
    if target[key] == nil then
      target[key] = CloneLayout(value)
    elseif type(target[key]) == "table" and type(value) == "table" then
      MergeMissing(target[key], value)
    end
  end
end

local SIZE_KEYS = {"core", "utility", "auraTrackers", "demonfire", "power", "targetDebuffs", "partyInterrupts"}

local function RollbackBeta10Sizing(profile)
  if type(profile) ~= "table" then return end
  for _, key in ipairs(SIZE_KEYS) do
    local entry = profile[key]
    if type(entry) == "table" then
      entry.width = nil
      entry.height = nil
      entry.dimensionOverride = nil
      entry.scale = 1
      if key == "partyInterrupts" then
        entry.x, entry.y = nil, nil
        entry.autoAnchor = true
      end
    end
  end
end

local function RepairPyromancerVerticalLayout(classStore, normalizedClass, store)
  local key = string.lower(tostring(normalizedClass or "")):gsub("[^%a%d]", "")
  if key ~= "pyromancer" or store.v4PyromancerAligned[normalizedClass] then return end
  local baseline = RUI.defaultLayout or RUI.layout or {}
  local function Repair(profile)
    if type(profile) ~= "table" then return end
    local coreY = profile.core and tonumber(profile.core.y)
    local utilityY = profile.utility and tonumber(profile.utility.y)
    if not ((coreY and coreY > -140) or (utilityY and utilityY > -180)) then return end
    for _, anchorKey in ipairs({"core", "utility", "auraTrackers", "demonfire", "power"}) do
      if type(profile[anchorKey]) == "table" and type(baseline[anchorKey]) == "table" then
        profile[anchorKey].y = baseline[anchorKey].y
      end
    end
  end
  Repair(classStore.default)
  for _, profile in pairs(classStore.builds or {}) do Repair(profile) end
  store.v4PyromancerAligned[normalizedClass] = true
end

local function EnsureClassStore(className)
  className = NormalizeClass(className or (RUI.GetDetectedClass and RUI:GetDetectedClass()) or "Unknown")
  local store = EnsureStore()
  local classStore = store.classes[className]
  if not classStore then
    classStore = {
      default = CloneLayout(RUI.defaultLayout or RUI.layout),
      builds = {},
    }
    store.classes[className] = classStore
  end
  classStore.default = classStore.default or CloneLayout(RUI.defaultLayout or RUI.layout)
  classStore.builds = classStore.builds or {}

  if not store.v4SizeRollback[className] then
    RollbackBeta10Sizing(classStore.default)
    for _, profile in pairs(classStore.builds) do RollbackBeta10Sizing(profile) end
    store.v4SizeRollback[className] = true
  end
  RepairPyromancerVerticalLayout(classStore, className, store)

  -- Merge recursively so new fields inside an existing anchor (for example
  -- HUD Editor scale) migrate into old profiles without changing positions.
  local baseline = RUI.defaultLayout or RUI.layout or {}
  MergeMissing(classStore.default, baseline)
  for _, profile in pairs(classStore.builds) do
    if type(profile) == "table" then MergeMissing(profile, classStore.default) end
  end
  return classStore, className, store
end

local function RecordKey(record)
  local advancementID = tonumber(record and (record.collectorEntryID or record.entryID or record.talentID))
  local spellID = tonumber(record and record.id)
  if advancementID then return "entry:" .. string.format("%010d", advancementID) end
  if spellID then return "spell:" .. string.format("%010d", spellID) end
  return "name:" .. string.lower(tostring(record and record.name or ""))
end

local function IsBuildRelevant(record)
  return type(record) == "table" and (
    record.talent == true or record.collectorEntryID or record.entryID or record.talentID
    or record.hudRow or record.auraTracker == true or record.targetDebuff == true
    or record.partyCooldown == true
  )
end

function RUI:InvalidateBuildState(reason)
  buildStateSerial = buildStateSerial + 1
  self._currentBuildState = nil
  if self.InvalidateAdvancementEntryCache then self:InvalidateAdvancementEntryCache(reason) end
end

function RUI:GetCurrentBuildState(force)
  local className = NormalizeClass((self.GetDetectedClass and self:GetDetectedClass()) or nil)
  if not className then return nil end
  if force then self:InvalidateBuildState("forced") end
  if self.ScanSpellbook then pcall(self.ScanSpellbook, self) end

  local activeSlot = self.GetActiveAdvancementSlot and self:GetActiveAdvancementSlot() or 1
  local spellbookSignature = self.spellbook and self.spellbook.signature or ""
  local cached = self._currentBuildState
  if cached and cached.serial == buildStateSerial and cached.className == className
    and cached.activeSlot == activeSlot and cached.spellbookSignature == spellbookSignature then
    return cached
  end

  local records = {}
  for _, record in ipairs(self:GetClassSpellRecords(className) or {}) do
    if IsBuildRelevant(record) then records[#records + 1] = record end
  end
  table.sort(records, function(left, right) return RecordKey(left) < RecordKey(right) end)

  local tokens = {"class=" .. tostring(className), "slot=" .. tostring(activeSlot)}
  local learnedRecords, learnedEntries = {}, {}
  local learnedCount = 0

  for _, record in ipairs(records) do
    local learned = self.IsSpellRecordLearned and self:IsSpellRecordLearned(record)
    if learned then
      learnedCount = learnedCount + 1
      local key = RecordKey(record)
      local runtimeID = self.GetSpellRecordRuntimeID and self:GetSpellRecordRuntimeID(record)
      learnedRecords[key] = runtimeID or record.id or record.name or true
      tokens[#tokens + 1] = key .. "=" .. tostring(runtimeID or record.id or record.name or "known")
      local entryID = tonumber(record.collectorEntryID or record.entryID or record.talentID)
      if entryID then
        learnedEntries[entryID] = true
        tokens[#tokens + 1] = "selected-entry=" .. tostring(entryID)
      end
    end
  end

  table.sort(tokens)
  local fingerprint = "b" .. HashText(table.concat(tokens, "|"))
  local state = {
    serial = buildStateSerial,
    className = className,
    activeSlot = activeSlot,
    spellbookSignature = spellbookSignature,
    fingerprint = fingerprint,
    learnedCount = learnedCount,
    learnedRecords = learnedRecords,
    learnedEntries = learnedEntries,
    tokens = tokens,
  }
  self._currentBuildState = state
  return state
end

function RUI:GetBuildFingerprint(className)
  className = NormalizeClass(className or (self.GetDetectedClass and self:GetDetectedClass()))
  local state = self:GetCurrentBuildState(false)
  if state and state.className == className then return state.fingerprint end
  return className and ("b" .. HashText("class=" .. tostring(className))) or "unknown"
end

function RUI:GetActiveHUDProfileKey(className)
  local _, normalizedClass, store = EnsureClassStore(className)
  local key = store.activeBuilds[normalizedClass]
  if not key or key == "" then
    key = self:GetBuildFingerprint(normalizedClass)
    store.activeBuilds[normalizedClass] = key
  end
  return key, normalizedClass
end

function RUI:GetActiveHUDProfile(className, create)
  local classStore, normalizedClass, store = EnsureClassStore(className)
  local key = store.activeBuilds[normalizedClass] or self:GetBuildFingerprint(normalizedClass)
  store.activeBuilds[normalizedClass] = key
  local profile = classStore.builds[key]
  if not profile and create ~= false then
    profile = CloneLayout(classStore.default)
    classStore.builds[key] = profile
  end
  if profile then MergeMissing(profile, classStore.default) end
  return profile or classStore.default, key, normalizedClass
end

function RUI:ApplyStoredHUDLayout(className, force)
  local profile, key, normalizedClass = self:GetActiveHUDProfile(className, true)
  if not profile then return false end
  if not force and self._activeHUDLayoutClass == normalizedClass and self._activeHUDLayoutKey == key then
    return true
  end

  self.layout = self.layout or {}
  self:ClearTable(self.layout)
  local copy = CloneLayout(profile)
  for name, value in pairs(copy) do self.layout[name] = value end
  self._activeHUDLayoutClass = normalizedClass
  self._activeHUDLayoutKey = key
  if self.ApplyHUDLayout then pcall(self.ApplyHUDLayout, self, false) end
  return true
end

function RUI:SaveCurrentHUDLayout(className)
  local classStore, normalizedClass, store = EnsureClassStore(className)
  local key = store.activeBuilds[normalizedClass] or self:GetBuildFingerprint(normalizedClass)
  store.activeBuilds[normalizedClass] = key
  classStore.builds[key] = CloneLayout(self.layout)
  MergeMissing(classStore.builds[key], classStore.default)
  return classStore.builds[key], key, normalizedClass
end

function RUI:ResetCurrentHUDLayout(anchorKey, className)
  local classStore, normalizedClass, store = EnsureClassStore(className)
  local key = store.activeBuilds[normalizedClass] or self:GetBuildFingerprint(normalizedClass)
  local profile = classStore.builds[key] or CloneLayout(classStore.default)
  if anchorKey and classStore.default[anchorKey] then
    profile[anchorKey] = CloneLayout(classStore.default[anchorKey])
  else
    profile = CloneLayout(classStore.default)
  end
  classStore.builds[key] = profile
  self._activeHUDLayoutKey = nil
  self:ApplyStoredHUDLayout(normalizedClass, true)
  return true
end

function RUI:RefreshBuildProfile(reason, force)
  if type(self.IsSupportedCharacter) == "function" and not self:IsSupportedCharacter() then return false end
  local className = self.GetDetectedClass and self:GetDetectedClass()
  if not className then return false end

  self:InvalidateBuildState(reason)
  local classStore, normalizedClass, store = EnsureClassStore(className)
  local state = self:GetCurrentBuildState(true)
  local fingerprint = state and state.fingerprint or self:GetBuildFingerprint(normalizedClass)
  local previous = store.activeBuilds[normalizedClass]
  store.lastDetected[normalizedClass] = {
    fingerprint = fingerprint,
    activeSlot = state and state.activeSlot or 1,
    learnedCount = state and state.learnedCount or 0,
    reason = tostring(reason or "refresh"),
    detectedAt = date and date("%Y-%m-%d %H:%M:%S") or tostring(time and time() or 0),
  }

  if previous ~= fingerprint or force then
    store.activeBuilds[normalizedClass] = fingerprint
    if not classStore.builds[fingerprint] then
      -- The v2 fingerprint contains stable record keys and advancement entries.
      -- Preserve the active v1 layout once during migration instead of making
      -- an existing user rebuild their HUD positions and scale from scratch.
      if profileUpgradeFromVersion < 2 and not store.v2MigratedClasses[normalizedClass]
        and previous and classStore.builds[previous] then
        classStore.builds[fingerprint] = CloneLayout(classStore.builds[previous])
        store.v2MigratedClasses[normalizedClass] = true
      else
        classStore.builds[fingerprint] = CloneLayout(classStore.default)
      end
    end
    MergeMissing(classStore.builds[fingerprint], classStore.default)
    self._activeHUDLayoutKey = nil
    self:ApplyStoredHUDLayout(normalizedClass, true)
    if self.activeModule and self.activeClass == normalizedClass and self.ApplyHUDLayout then
      pcall(self.ApplyHUDLayout, self, true)
    end
    return true, fingerprint, previous
  end
  self:ApplyStoredHUDLayout(normalizedClass, false)
  return false, fingerprint, previous
end

function RUI:ScheduleBuildProfileRefresh(reason)
  refreshSerial = refreshSerial + 1
  local serial = refreshSerial
  self:InvalidateBuildState(reason)
  for _, delay in ipairs({0.05, 0.35, 0.90, 1.80}) do
    self:After(delay, function()
      if serial ~= refreshSerial then return end
      self:RefreshBuildProfile(reason, delay == 1.80)
    end)
  end
end

function RUI:GetBuildProfileStatus()
  local className = self.GetDetectedClass and self:GetDetectedClass() or "Unknown"
  local profile, key, normalizedClass = self:GetActiveHUDProfile(className, true)
  local classStore = EnsureClassStore(normalizedClass)
  local count = 0
  for _ in pairs(classStore.builds or {}) do count = count + 1 end
  return normalizedClass, key, count, profile
end

local EVENTS = {
  PLAYER_LOGIN=true,
  PLAYER_ENTERING_WORLD=true,
  SPELLS_CHANGED=true,
  PLAYER_TALENT_UPDATE=true,
  CHARACTER_POINTS_CHANGED=true,
  ACTIVE_TALENT_GROUP_CHANGED=true,
  LEARNED_SPELL_IN_TAB=true,
  ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED=true,
  ASCENSION_KNOWN_ENTRIES_UPDATED=true,
}

refreshFrame = CreateFrame("Frame", "RetreatUIBuildProfileDriver")
for eventName in pairs(EVENTS) do pcall(refreshFrame.RegisterEvent, refreshFrame, eventName) end
refreshFrame:SetScript("OnEvent", function(_, event)
  RUI:ScheduleBuildProfileRefresh(event)
end)

RUI._buildProfilesLoaded = true

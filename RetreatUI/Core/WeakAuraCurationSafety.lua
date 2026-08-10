local RUI = RetreatUI
if not RUI then return end

-- Final curation guard for the WA renderer. The native CoA HUD only rendered
-- explicitly configured proc trackers and respected per-record runtime gates
-- (form/combat/custom show functions). Keep those semantics after the move to WA.

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function CurrentClass(self, className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if self.NormalizeClassName then className = self:NormalizeClassName(className) or className end
  return className
end

local function PlayerHasAura(name)
  if type(UnitBuff) ~= "function" or not name then return false end
  local wanted = Normalize(name)
  for index = 1, 40 do
    local auraName = UnitBuff("player", index)
    if not auraName then break end
    if Normalize(auraName) == wanted then return true end
  end
  return false
end

local function ActiveShapeName()
  if type(GetShapeshiftForm) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then return nil end
  local current = tonumber(GetShapeshiftForm()) or 0
  if current <= 0 then return nil end
  local _, name = GetShapeshiftFormInfo(current)
  return name
end

local function BloodmageCursed(self)
  if PlayerHasAura("Cursed Form") or PlayerHasAura("Blood Curse") or PlayerHasAura("Eternal Curse") then return true end
  local shape = Normalize(ActiveShapeName())
  if shape == "cursed form" or shape == "blood curse" or shape == "eternal curse" then return true end
  if self.IsSpellIDLearned then
    local ok, known = pcall(self.IsSpellIDLearned, self, 800157)
    if ok and known then return true end
  end
  return false
end

local function FormMatches(self, className, wanted)
  wanted = Normalize(wanted)
  if wanted == "" then return true end
  if className == "Bloodmage" then
    local cursed = BloodmageCursed(self)
    if wanted == "cursed form" then return cursed end
    if wanted == "mortal form" then return not cursed end
  end
  if Normalize(ActiveShapeName()) == wanted then return true end
  return PlayerHasAura(wanted)
end

local function RecordAllowed(self, className, record)
  if type(record) ~= "table" then return true end
  if record.hideInCombat == true then
    local inCombat = (type(UnitAffectingCombat) == "function" and UnitAffectingCombat("player"))
      or (type(InCombatLockdown) == "function" and InCombatLockdown())
    if inCombat then return false end
  end
  if record.requiresForm and not FormMatches(self, className, record.requiresForm) then return false end
  if type(record.show) == "function" then
    local ok, shown = pcall(record.show)
    if not ok or shown == false then return false end
  end
  return true
end

local originalRowStates = RUI.GetWeakAuraRowStates
if type(originalRowStates) == "function" then
  function RUI:GetWeakAuraRowStates(className, row)
    className = CurrentClass(self, className)
    local states = originalRowStates(self, className, row) or {}
    local records = self.GetCuratedWeakAuraDefinitions and self:GetCuratedWeakAuraDefinitions(className, row)
      or (self.GetHUDSpellDefinitions and self:GetHUDSpellDefinitions(className, row)) or {}
    local byName = {}
    for _, record in ipairs(records) do byName[Normalize(record.name)] = record end
    local result = {}
    for _, state in ipairs(states) do
      local record = byName[Normalize(state.name)]
      if not record or RecordAllowed(self, className, record) then
        result[#result + 1] = state
        state.index = #result
      end
    end
    return result
  end
end

-- The first WA bridge intentionally had a TBC-style broad <=60 second proc
-- fallback. CoA's native HUD did not: it only showed records explicitly marked
-- auraTracker=true. Remove the broad fallback so the migrated HUD tracks exactly
-- the same buffs/procs as the class database did before the renderer change.
local originalProcStates = RUI.GetWeakAuraProcStates
if type(originalProcStates) == "function" then
  function RUI:GetWeakAuraProcStates(className)
    className = CurrentClass(self, className)
    local states = originalProcStates(self, className) or {}
    local allowedNames, allowedIDs = {}, {}
    for _, record in ipairs(self:GetAuraTrackerDefinitions(className) or {}) do
      if not (self.IsClassStateAuraDefinition and self:IsClassStateAuraDefinition(className, record)) then
        for _, name in ipairs({record.name, record.buff, record.debuff}) do
          local key = Normalize(name)
          if key ~= "" then allowedNames[key] = true end
        end
        for _, alias in ipairs(record.aliases or {}) do
          local key = Normalize(alias)
          if key ~= "" then allowedNames[key] = true end
        end
        for _, id in ipairs({record.id, record.auraID, record.spellID}) do
          id = tonumber(id)
          if id then allowedIDs[id] = true end
        end
      end
    end

    local result = {}
    for _, state in ipairs(states) do
      if allowedNames[Normalize(state.name)] or (tonumber(state.spellID) and allowedIDs[tonumber(state.spellID)]) then
        result[#result + 1] = state
        state.index = #result
      end
    end
    return result
  end
end

RUI._weakAuraCurationSafetyLoaded = true
RUI._weakAuraCurationSafetyRevision = 1

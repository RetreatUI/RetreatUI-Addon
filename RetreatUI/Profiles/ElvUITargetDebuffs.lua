local RUI = RetreatUI
if not RUI then return end

local FILTER_NAME = "RetreatUI_SelectedDebuffs"

local function EnsureTargetDebuffs(profile)
  if type(profile) ~= "table" then return nil end
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  profile.unitframe.units.target = profile.unitframe.units.target or {}
  local target = profile.unitframe.units.target
  target.debuffs = target.debuffs or {}
  return target.debuffs
end

local function ConfigureTargetDebuffs(profile, enabled)
  local debuffs = EnsureTargetDebuffs(profile)
  if not debuffs then return false end

  if enabled then
    -- Selected-only target row. The dedicated RetreatUI whitelist is the entire
    -- filter chain so ordinary target auras never turn this into a generic row.
    debuffs.enable = true
    debuffs.priority = FILTER_NAME
    debuffs.minDuration = 0
    debuffs.maxDuration = 0
    debuffs.perrow = 4
    debuffs.numrows = 1
  else
    debuffs.enable = false
    debuffs.priority = ""
    debuffs.minDuration = 0
    debuffs.maxDuration = 0
    debuffs.perrow = 4
    debuffs.numrows = 1
  end
  return true
end

local function DisableTargetDebuffs(profile)
  return ConfigureTargetDebuffs(profile, false)
end

local function BuildSelectedSpellFilter(className)
  local spells = {}
  local count = 0
  if not RUI.GetTrackerDestinationEntries then return spells, count end

  for _, entry in ipairs(RUI:GetTrackerDestinationEntries(className, "targetFrame", "debuff") or {}) do
    local key = tonumber(entry.auraID) or tonumber(entry.spellID)
    if not key then
      local name = entry.auraName or entry.name
      if type(name) == "string" and name ~= "" then key = name end
    end
    if key ~= nil and spells[key] == nil then
      spells[key] = {
        enable = true,
        priority = 0,
        stackThreshold = 0,
      }
      count = count + 1
    end
  end
  return spells, count
end

local function ApplyGlobalFilter(spells)
  local applied = false

  if type(ElvDB) == "table" then
    ElvDB.global = ElvDB.global or {}
    ElvDB.global.unitframe = ElvDB.global.unitframe or {}
    ElvDB.global.unitframe.aurafilters = ElvDB.global.unitframe.aurafilters or {}
    ElvDB.global.unitframe.aurafilters[FILTER_NAME] = {
      type = "Whitelist",
      spells = spells,
    }
    applied = true
  end

  local E = ElvUI and unpack(ElvUI)
  if E then
    E.global = E.global or {}
    E.global.unitframe = E.global.unitframe or {}
    E.global.unitframe.aurafilters = E.global.unitframe.aurafilters or {}
    E.global.unitframe.aurafilters[FILTER_NAME] = {
      type = "Whitelist",
      spells = spells,
    }
    applied = true
  end

  return applied
end

local function CurrentElvUIProfileName(E)
  if not E then return nil end
  if E.data and type(E.data.GetCurrentProfile) == "function" then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok then return value end
  end
  return nil
end

local function RefreshUnitFrames()
  local E = ElvUI and unpack(ElvUI)
  if not E or type(E.GetModule) ~= "function" then return end
  local ok, UF = pcall(E.GetModule, E, "UnitFrames")
  if ok and UF and type(UF.Update_AllFrames) == "function" then
    pcall(UF.Update_AllFrames, UF)
  end
end

function RUI:ApplyElvUITargetDebuffDestinations(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if type(className) ~= "string" or className == "" then return false, "class unavailable" end

  local spells, count = BuildSelectedSpellFilter(className)
  ApplyGlobalFilter(spells)

  local enabled = count > 0
  ConfigureTargetDebuffs(self.ElvUIProfile, enabled)

  if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
    ConfigureTargetDebuffs(ElvDB.profiles.RetreatUI, enabled)
  end

  local E = ElvUI and unpack(ElvUI)
  if E and E.db then
    local currentProfile = CurrentElvUIProfileName(E)
    if currentProfile == nil or currentProfile == "RetreatUI" then
      ConfigureTargetDebuffs(E.db, enabled)
    end
  end

  RefreshUnitFrames()
  return true, count
end

-- Compatibility entry point retained for older callers. Target-frame debuffs
-- are no longer a generic Personal filter; they are driven by Tracker Builder
-- destinations and the dedicated selected-only whitelist above.
function RUI:ConfigureElvUITargetPersonalDebuffs(profile)
  if profile ~= nil then
    local className = self.GetDetectedClass and self:GetDetectedClass() or nil
    local _, count = BuildSelectedSpellFilter(className)
    return ConfigureTargetDebuffs(profile, count > 0)
  end
  return self:ApplyElvUITargetDebuffDestinations()
end

function RUI:DisableElvUITargetDebuffs(profile)
  return DisableTargetDebuffs(profile or self.ElvUIProfile)
end

-- Apply once after this module loads. TrackerDestinations also reapplies on
-- every Save/Remove/Profile Import, so the native ElvUI DB stays in sync.
pcall(RUI.ApplyElvUITargetDebuffDestinations, RUI)

RUI._elvUITargetDebuffsLoaded = true
RUI._elvUITargetDebuffsRevision = 3
RUI.elvUITargetDebuffFilterName = FILTER_NAME

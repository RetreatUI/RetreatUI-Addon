local RUI = RetreatUI
if not RUI then return end

-- beta.19: the visible CoA HUD is WeakAuras-owned. Keep expensive refresh work
-- behind RetreatUI-specific debounced events instead of waking every WeakAura
-- in the UI with synthetic UNIT_POWER_FREQUENT events or raw event storms.

local ROW_EVENT = "RETREATUI_ROW_REFRESH"
local PLAYER_AURA_EVENT = "RETREATUI_PLAYER_AURA_REFRESH"
local TARGET_AURA_EVENT = "RETREATUI_TARGET_AURA_REFRESH"
local RESOURCE_PULSE_EVENT = "RETREATUI_RESOURCE_PULSE"
local EXPLICIT_RESOURCE_EVENT = "RETREATUI_EXPLICIT_RESOURCE_REFRESH"

local function Now()
  return type(GetTime) == "function" and GetTime() or 0
end

local function CurrentClass()
  local className = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or RUI.activeClass
  if type(RUI.NormalizeClassName) == "function" then className = RUI:NormalizeClassName(className) or className end
  return tostring(className or "")
end

local function IsKnight()
  return CurrentClass() == "Knight of Xoroth"
end

local function Scan(eventName, unit)
  if RUI.weakAuraHUDMode ~= true then return end
  if not WeakAuras or type(WeakAuras.ScanEvents) ~= "function" then return end
  if unit then
    pcall(WeakAuras.ScanEvents, eventName, unit)
  else
    pcall(WeakAuras.ScanEvents, eventName)
  end
end

-------------------------------------------------------------------------------
-- Runtime state caches. WeakAuras may ask multiple RetreatUI displays for the
-- same expensive state during one refresh burst. Cache final snapshots until
-- the owning game state actually changes.
-------------------------------------------------------------------------------
local cache = {
  rows = {},
  proc = nil,
  state = {},
  target = {},
  explicit = {},
  nativeResource = {},
}

local function ClearRows()
  cache.rows = {}
end

local function ClearPlayerAura()
  ClearRows()
  cache.proc = nil
  cache.state = {}
  cache.explicit = {}
end

local function ClearTarget()
  cache.target = {}
end

local function ClearNativeResource()
  cache.nativeResource = {}
end

local function ClearAll()
  ClearPlayerAura()
  ClearTarget()
  ClearNativeResource()
end

local originalRowStates = RUI.GetWeakAuraRowStates
if type(originalRowStates) == "function" then
  function RUI:GetWeakAuraRowStates(className, row)
    local key = tostring(className or CurrentClass()) .. "\031" .. tostring(row or "")
    local value = cache.rows[key]
    if value ~= nil then return value end
    value = originalRowStates(self, className, row) or {}
    cache.rows[key] = value
    return value
  end
end

local originalProcStates = RUI.GetWeakAuraProcStates
if type(originalProcStates) == "function" then
  function RUI:GetWeakAuraProcStates(className)
    if cache.proc ~= nil then return cache.proc end
    cache.proc = originalProcStates(self, className) or {}
    return cache.proc
  end
end

local originalClassStates = RUI.GetWeakAuraClassStates
if type(originalClassStates) == "function" then
  function RUI:GetWeakAuraClassStates(className)
    local key = tostring(className or CurrentClass())
    local value = cache.state[key]
    if value ~= nil then return value end
    value = originalClassStates(self, className) or {}
    cache.state[key] = value
    return value
  end
end

local originalTargetStates = RUI.GetWeakAuraTargetStates
if type(originalTargetStates) == "function" then
  function RUI:GetWeakAuraTargetStates(className)
    local key = tostring(className or CurrentClass())
    local value = cache.target[key]
    if value ~= nil then return value end
    value = originalTargetStates(self, className) or {}
    cache.target[key] = value
    return value
  end
end

local originalExplicitResource = RUI.GetWeakAuraExplicitResourceState
if type(originalExplicitResource) == "function" then
  function RUI:GetWeakAuraExplicitResourceState(className, resourceKey)
    local key = tostring(className or CurrentClass()) .. "\031" .. tostring(resourceKey or "")
    local value = cache.explicit[key]
    if value ~= nil then return value end
    value = originalExplicitResource(self, className, resourceKey)
    cache.explicit[key] = value or false
    return value or nil
  end
end

local originalNativeResource = RUI.GetWeakAuraNativeResourceState
if type(originalNativeResource) == "function" then
  function RUI:GetWeakAuraNativeResourceState(className, forceDiscovery)
    if forceDiscovery == true then
      local value = originalNativeResource(self, className, true)
      cache.nativeResource = {}
      return value
    end
    local key = tostring(className or CurrentClass())
    local entry = cache.nativeResource[key]
    local now = Now()
    -- A very short cache is enough for Secondary Bar + Segments to share one
    -- Ascension frame/resource scan during the same WeakAuras dispatch.
    if entry and (now - entry.time) <= 0.04 then return entry.value or nil end
    local value = originalNativeResource(self, className, false)
    cache.nativeResource[key] = {time = now, value = value or false}
    return value
  end
end

-------------------------------------------------------------------------------
-- Patch newly built RetreatUI WeakAuras so raw high-frequency events are routed
-- through the coordinator below. beta.19 bumps the addon version, therefore an
-- existing beta.18 HUD is rebuilt once with these trigger definitions.
-------------------------------------------------------------------------------
local function RewriteEvents(events, remove, additions)
  local result, seen = {}, {}
  for eventName in tostring(events or ""):gmatch("%S+") do
    if not remove[eventName] and not seen[eventName] then
      result[#result + 1] = eventName
      seen[eventName] = true
    end
  end
  for _, eventName in ipairs(additions or {}) do
    if not seen[eventName] then
      result[#result + 1] = eventName
      seen[eventName] = true
    end
  end
  return table.concat(result, " ")
end

local function PatchUnitFilter(trigger, wantedUnit)
  if type(trigger) ~= "table" or type(trigger.custom) ~= "string" then return end
  local old = 'if unit and unit ~= "player" and unit ~= "target" then return false end'
  local new = string.format('if unit and unit ~= %q then return false end', wantedUnit)
  trigger.custom = trigger.custom:gsub(old, new, 1)
end

local function PatchDisplay(display)
  if type(display) ~= "table" or type(display.id) ~= "string" then return end
  local trigger = display.triggers and display.triggers[1] and display.triggers[1].trigger
  if type(trigger) ~= "table" then return end
  local id = display.id
  local remove, add, unit = {}, {}, "player"

  if id:find(" — Target — Active Debuffs", 1, true) then
    remove.UNIT_AURA = true
    add = {TARGET_AURA_EVENT}
    unit = "target"
  elseif id:find(" — Main — Abilities", 1, true) or id:find(" — Utility — Abilities", 1, true) then
    remove.UNIT_AURA = true
    remove.SPELL_UPDATE_COOLDOWN = true
    remove.SPELL_UPDATE_USABLE = true
    add = {ROW_EVENT}
  elseif id:find(" — State — Active States", 1, true) then
    remove.UNIT_AURA = true
    add = {PLAYER_AURA_EVENT}
  elseif id:find("RetreatUI - General — Buffs & Procs", 1, true) then
    remove.UNIT_AURA = true
    add = {PLAYER_AURA_EVENT}
  elseif id:find("RetreatUI - General — Trinkets", 1, true) then
    remove.UNIT_AURA = true
  elseif id:find(" — Resource — ", 1, true) then
    remove.UNIT_POWER_FREQUENT = true
    add[#add + 1] = RESOURCE_PULSE_EVENT
    if tostring(trigger.events or ""):find("UNIT_AURA", 1, true) then
      remove.UNIT_AURA = true
      add[#add + 1] = PLAYER_AURA_EVENT
    end
    if tostring(trigger.events or ""):find("COMBAT_LOG_EVENT_UNFILTERED", 1, true) then
      remove.COMBAT_LOG_EVENT_UNFILTERED = true
      add[#add + 1] = EXPLICIT_RESOURCE_EVENT
    end
  end

  trigger.events = RewriteEvents(trigger.events, remove, add)
  PatchUnitFilter(trigger, unit)
end

local originalBuildPackage = RUI.BuildWeakAuraHUDPackage
if type(originalBuildPackage) == "function" then
  function RUI:BuildWeakAuraHUDPackage(className)
    local packageData, err = originalBuildPackage(self, className)
    if type(packageData) ~= "table" then return packageData, err end
    for _, display in ipairs(packageData.displays or {}) do PatchDisplay(display) end
    packageData.performanceRevision = 19
    return packageData, err
  end
end

-------------------------------------------------------------------------------
-- Debounced event bridge. Raw UNIT_AURA/cooldown storms only dirty state here;
-- RetreatUI WeakAuras receive at most one refresh batch per short interval.
-------------------------------------------------------------------------------
local dirty = {row=false, player=false, target=false, explicit=false}
local elapsed = 0
local bridge = CreateFrame("Frame", "RetreatUIWeakAuraPerformanceBridge")
bridge:Hide()

local function Wake()
  elapsed = 0
  bridge:Show()
end

local function MarkRow()
  ClearRows()
  dirty.row = true
  Wake()
end

local function MarkPlayerAura()
  ClearPlayerAura()
  dirty.player = true
  dirty.row = true
  dirty.explicit = true
  Wake()
end

local function MarkTarget()
  ClearTarget()
  dirty.target = true
  Wake()
end

local function MarkExplicit()
  cache.explicit = {}
  dirty.explicit = true
  Wake()
end

local STRUCTURAL_EVENTS = {
  SPELLS_CHANGED=true,
  PLAYER_TALENT_UPDATE=true,
  CHARACTER_POINTS_CHANGED=true,
  ACTIVE_TALENT_GROUP_CHANGED=true,
  ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED=true,
  ASCENSION_KNOWN_ENTRIES_UPDATED=true,
}

for _, eventName in ipairs({
  "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UNIT_AURA",
  "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "PLAYER_EQUIPMENT_CHANGED",
  "UNIT_POWER", "UNIT_DISPLAYPOWER", "UNIT_MAXPOWER", "UNIT_POWER_BAR_SHOW", "UNIT_POWER_BAR_HIDE",
  "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
  "ACTIVE_TALENT_GROUP_CHANGED", "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED",
  "ASCENSION_KNOWN_ENTRIES_UPDATED",
}) do pcall(bridge.RegisterEvent, bridge, eventName) end

local function SyncImpCombatLog()
  local imp = _G.RetreatUIWeakAuraImpRuntime
  if imp and type(imp.UnregisterEvent) == "function" then
    pcall(imp.UnregisterEvent, imp, "COMBAT_LOG_EVENT_UNFILTERED")
    if IsKnight() and type(imp.RegisterEvent) == "function" then
      pcall(imp.RegisterEvent, imp, "COMBAT_LOG_EVENT_UNFILTERED")
    end
  end
  pcall(bridge.UnregisterEvent, bridge, "COMBAT_LOG_EVENT_UNFILTERED")
  if IsKnight() then pcall(bridge.RegisterEvent, bridge, "COMBAT_LOG_EVENT_UNFILTERED") end
end

bridge:SetScript("OnEvent", function(_, event, unit)
  if event == "UNIT_AURA" then
    if unit == "player" then MarkPlayerAura()
    elseif unit == "target" then MarkTarget() end
    return
  end
  if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" or event == "PLAYER_EQUIPMENT_CHANGED" then
    MarkRow()
    return
  end
  if event == "PLAYER_TARGET_CHANGED" then
    MarkTarget()
    return
  end
  if event == "UNIT_POWER" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_MAXPOWER"
    or event == "UNIT_POWER_BAR_SHOW" or event == "UNIT_POWER_BAR_HIDE" then
    if unit and unit ~= "player" then return end
    ClearNativeResource()
    return
  end
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if not IsKnight() or type(CombatLogGetCurrentEventInfo) ~= "function" then return end
    local _, subevent = CombatLogGetCurrentEventInfo()
    if subevent == "SPELL_SUMMON" or subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" or subevent == "SPELL_INSTAKILL" then
      MarkExplicit()
    end
    return
  end
  if event == "PLAYER_ENTERING_WORLD" or STRUCTURAL_EVENTS[event] then
    ClearAll()
    dirty.row, dirty.player, dirty.target, dirty.explicit = true, true, true, true
    SyncImpCombatLog()
    Wake()
  end
end)

bridge:SetScript("OnUpdate", function(self, delta)
  elapsed = elapsed + delta
  if elapsed < 0.08 then return end
  elapsed = 0
  self:Hide()

  local row, player, target, explicit = dirty.row, dirty.player, dirty.target, dirty.explicit
  dirty.row, dirty.player, dirty.target, dirty.explicit = false, false, false, false

  if player then Scan(PLAYER_AURA_EVENT, "player") end
  if row then Scan(ROW_EVENT, "player") end
  if target then Scan(TARGET_AURA_EVENT, "target") end
  if explicit then Scan(EXPLICIT_RESOURCE_EVENT, "player") end
end)

-------------------------------------------------------------------------------
-- Replace beta.18's global synthetic UNIT_POWER_FREQUENT pulse. Only RetreatUI
-- resource WeakAuras are woken, and only when the current class actually has a
-- native Ascension resource that needs polling.
-------------------------------------------------------------------------------
local pulseElapsed = 0
local pulse = CreateFrame("Frame", "RetreatUIWeakAuraResourcePulseBeta19")
pulse:Hide()
pulse:SetScript("OnUpdate", function(_, delta)
  pulseElapsed = pulseElapsed + delta
  if pulseElapsed < 0.20 then return end
  pulseElapsed = 0
  ClearNativeResource()
  Scan(RESOURCE_PULSE_EVENT, "player")
end)

local function NeedsResourcePulse()
  local className = CurrentClass()
  if className == "" or type(RUI.GetClassSpellDatabase) ~= "function" then return false end
  local database = RUI:GetClassSpellDatabase(className)
  return type(database) == "table" and type(database.nativeResource) == "table"
end

function RUI:StartWeakAuraHUDPulse()
  pulseElapsed = 0
  SyncImpCombatLog()
  if NeedsResourcePulse() then pulse:Show() else pulse:Hide() end
  return true
end

function RUI:StopWeakAuraHUDPulse()
  pulse:Hide()
  pulseElapsed = 0
  return true
end

-- The old imp tracker is created earlier in WeakAuraHUDRuntime.lua. Gate it now
-- rather than leaving a Knight-only COMBAT_LOG listener active on all 21 classes.
SyncImpCombatLog()

RUI._weakAuraPerformanceBeta19 = true
RUI._weakAuraPerformanceRevision = 19

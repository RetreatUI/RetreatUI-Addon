local RUI = RetreatUI
if not RUI then return end

-- Beta.17 performance safety.
--
-- RetreatUI_Classes intentionally ships every class module in one addon, which
-- means top-level helper drivers from unrelated classes also exist in memory.
-- Older helpers left OnUpdate/event polling active even while their class HUD
-- was not selected. Gate those legacy drivers here so only the current class
-- can consume periodic CPU, and Guardian's combat-log listener exists only
-- while Guardian is actually active.

local DRIVER_RULES = {
  {
    className = "Cultist",
    frameName = "RetreatUICultistWagoMechanicsDriver",
    events = {
      "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UNIT_AURA", "PLAYER_TOTEM_UPDATE",
      "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
    },
  },
  {
    className = "Tinker",
    frameName = "RetreatUITinkerHealerPetDriver",
    events = {
      "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UNIT_PET", "UNIT_POWER",
      "UNIT_MANA", "SPELL_UPDATE_COOLDOWN", "SPELLS_CHANGED",
    },
  },
  {
    className = "Guardian",
    frameName = "RetreatUIGuardianReminderDriver",
    events = {
      "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
      "UNIT_INVENTORY_CHANGED", "UNIT_AURA", "SPELLS_CHANGED",
      "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED",
    },
  },
  {
    className = "Guardian",
    frameName = "RetreatUIGuardianBannerTrackerDriver",
    events = {
      "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TOTEM_UPDATE", "UNIT_AURA",
      "UNIT_SPELLCAST_SUCCEEDED", "COMBAT_LOG_EVENT_UNFILTERED",
      "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
    },
  },
}

local function NormalizeClass(value)
  if type(RUI.NormalizeClassName) == "function" then
    value = RUI:NormalizeClassName(value) or value
  end
  return tostring(value or ""):gsub("[%s%p]", ""):lower()
end

local function CurrentClass()
  local value = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or RUI.activeClass
  return NormalizeClass(value)
end

local function ClassHUDEnabled()
  if type(RUI.IsInstallerModuleEnabled) == "function" then
    return RUI:IsInstallerModuleEnabled("classHUD") ~= false
  end
  return true
end

local function RegisterRuleEvents(frame, rule)
  if not frame or type(frame.RegisterEvent) ~= "function" then return end
  for _, eventName in ipairs(rule.events or {}) do
    pcall(frame.RegisterEvent, frame, eventName)
  end
end

local function DisableRule(frame)
  if not frame then return end
  if type(frame.Hide) == "function" then pcall(frame.Hide, frame) end
  if type(frame.UnregisterAllEvents) == "function" then pcall(frame.UnregisterAllEvents, frame) end
end

local function EnableRule(frame, rule)
  if not frame then return end
  if type(frame.UnregisterAllEvents) == "function" then pcall(frame.UnregisterAllEvents, frame) end
  RegisterRuleEvents(frame, rule)
  if type(frame.Show) == "function" then pcall(frame.Show, frame) end
end

function RUI:SyncClassPerformanceDrivers()
  local current = CurrentClass()
  local enabled = ClassHUDEnabled()
  local activeCount = 0

  for _, rule in ipairs(DRIVER_RULES) do
    local frame = _G[rule.frameName]
    if frame then
      local wanted = enabled and current ~= "" and current == NormalizeClass(rule.className)
      if wanted then
        EnableRule(frame, rule)
        activeCount = activeCount + 1
      else
        DisableRule(frame)
      end
    end
  end

  local db = self:EnsureDB()
  db.performance = db.performance or {}
  db.performance.classDriverGateBeta17 = true
  db.performance.activeLegacyClassDrivers = activeCount
  db.performance.classDriverGateClass = current
  return activeCount
end

local manager = CreateFrame("Frame", "RetreatUIClassDriverPerformanceManager")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE",
  "CHARACTER_POINTS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED",
  "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED", "ASCENSION_KNOWN_ENTRIES_UPDATED",
}) do
  pcall(manager.RegisterEvent, manager, eventName)
end

manager:SetScript("OnEvent", function()
  RUI:After(0, function()
    if RetreatUI and RetreatUI.SyncClassPerformanceDrivers then
      RetreatUI:SyncClassPerformanceDrivers()
    end
  end)
end)

-- Class helpers are already created by the time this late-loaded file runs.
-- Apply the gate immediately instead of waiting for the first lifecycle event.
RUI:After(0, function()
  if RetreatUI and RetreatUI.SyncClassPerformanceDrivers then
    RetreatUI:SyncClassPerformanceDrivers()
  end
end)

RUI._classDriverPerformanceBeta17 = true

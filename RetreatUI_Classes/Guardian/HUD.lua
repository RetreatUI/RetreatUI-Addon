local RUI = RetreatUI
if not RUI then return end

local module = RUI:RegisterAdvancedClassHUD("Guardian", {
  frameName = "RetreatUIGuardianHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {
    GLADIATOR=true, INSPIRATION=true, PROTECTION=true, VANGUARD=true,
  },
  coreOrder = {
    "Shield of Denial", "Reprisal", "Heavy Blow", "Hammer of the Law",
    "Shoulder the Burden", "Heroic Resolve",
  },
  strictCoreOrder = true,
  maxCore = 6,
  utilityOrder = {
    "Hold the Line", "Chivalry", "Turn the Blade", "Knight's Calling",
    "Counter Stance", "Unyielding Stand", "Reflective Shield",
    "Press the Attack", "Raise Shield", "Brace", "Battle Rush",
    "Advance", "Glorious Arena",
  },
  strictUtilityOrder = true,
  maxUtility = 13,
  maxProcs = 8,
  coreIconSize = 38,
  utilityIconSize = 32,
})

if not module or not RUI.HUDWidgets then return end
local W = RUI.HUDWidgets
local reminderFrame
local reminderIcons = {}
local reminderDriver
local elapsed = 0

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
  if not ok then return nil end
  return a, b, c, d, e, f, g, h
end

local function SpellKnown(spellID)
  if RUI.IsSpellIDLearned then return RUI:IsSpellIDLearned(spellID) end
  if type(IsSpellKnown) == "function" then
    local known = SafeCall(IsSpellKnown, spellID)
    if known then return true end
  end
  local name = type(GetSpellInfo) == "function" and GetSpellInfo(spellID) or nil
  return name and type(IsSpellKnown) == "function" and SafeCall(IsSpellKnown, name) == true
end

local function PlayerAura(spellIDs)
  local wanted = {}
  for _, spellID in ipairs(spellIDs or {}) do wanted[tonumber(spellID)] = true end
  if type(UnitBuff) ~= "function" then return nil end
  for index = 1, 40 do
    local values = {UnitBuff("player", index)}
    if not values[1] then break end
    if values[11] and wanted[tonumber(values[11])] then
      return {name=values[1], icon=values[3], count=tonumber(values[4]) or 0,
        duration=tonumber(values[6]) or 0, expires=tonumber(values[7]) or 0,
        spellID=tonumber(values[11])}
    end
  end
  return nil
end

local function HasShield()
  local link = type(GetInventoryItemLink) == "function" and SafeCall(GetInventoryItemLink, "player", 17) or nil
  if not link then return false end
  if type(GetItemInfo) == "function" then
    local _, _, _, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(link)
    if equipLoc == "INVTYPE_SHIELD" then return true end
    local combined = string.lower(tostring(itemType or "") .. " " .. tostring(itemSubType or ""))
    if string.find(combined, "shield", 1, true) then return true end
  end
  -- Ascension custom shields do not always return cached item metadata. An
  -- equipped offhand on Guardian is safer than suppressing the reminder.
  return true
end

local function OffhandEnchant()
  if type(GetWeaponEnchantInfo) ~= "function" then return false, 0 end
  local values = {GetWeaponEnchantInfo()}
  return values[5] == true or values[5] == 1, tonumber(values[6]) or 0
end

local function TextureFor(spellID, fallback)
  if type(GetSpellInfo) == "function" then
    local _, _, texture = GetSpellInfo(spellID)
    if texture then return texture end
  end
  return fallback or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function CreateReminderIcon(index)
  local icon = W:CreateIcon(reminderFrame, 30)
  icon.reminderIndex = index
  icon.label = icon:CreateFontString(nil, "OVERLAY")
  icon.label:SetPoint("BOTTOM", icon, "TOP", 0, 2)
  icon.label:SetWidth(92)
  icon.label:SetJustifyH("CENTER")
  RUI:ApplyFont(icon.label, 8, "OUTLINE")
  icon.cooldownText:SetText("")
  icon.stackText:SetText("!")
  icon:EnableMouse(true)
  icon:SetScript("OnEnter", function(self)
    if not self.reminderName or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.reminderName, 1, 1, 1)
    if self.reminderDescription then
      GameTooltip:AddLine(self.reminderDescription, 0.82, 0.82, 0.82, true)
    end
    GameTooltip:Show()
  end)
  icon:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  icon:Hide()
  reminderIcons[index] = icon
  return icon
end

local function CreateReminderFrame()
  if reminderFrame then return reminderFrame end
  reminderFrame = CreateFrame("Frame", "RetreatUIGuardianReminderTracker", UIParent)
  reminderFrame:SetSize(63, 30)
  reminderFrame:SetFrameStrata("HIGH")
  reminderFrame:SetClampedToScreen(true)
  CreateReminderIcon(1)
  CreateReminderIcon(2)
  reminderFrame:Hide()
  return reminderFrame
end

local function PositionReminderFrame()
  local frame = CreateReminderFrame()
  frame:ClearAllPoints()
  local power = _G.RetreatUIPrimaryPowerBar
  if power and type(power.SetPoint) == "function" then
    frame:SetPoint("BOTTOMRIGHT", power, "TOPLEFT", -8, 4)
  else
    local layout = RUI.layout and RUI.layout.power or {x=0, y=-152, width=360, height=16}
    frame:SetPoint("CENTER", UIParent, "CENTER",
      (tonumber(layout.x) or 0) - (tonumber(layout.width) or 360) / 2 - 8 - frame:GetWidth() / 2,
      (tonumber(layout.y) or -152) + (tonumber(layout.height) or 16) / 2 + 4 + frame:GetHeight() / 2)
  end
end

local function GuardianHUDActive()
  if type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() ~= "Guardian" then return false end
  if type(RUI.IsInstallerModuleEnabled) == "function" and not RUI:IsInstallerModuleEnabled("classHUD") then return false end
  local root = _G.RetreatUIGuardianHUD
  return root and root.IsShown and root:IsShown() == true
end

local function SetReminder(icon, reminder)
  if not reminder then icon:Hide(); return false end
  icon.texture:SetTexture(reminder.texture)
  if icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
  icon.label:SetText(reminder.label or "")
  icon.reminderName = reminder.name
  icon.reminderDescription = reminder.description
  icon.stackText:SetText("!")
  if reminder.remaining and reminder.remaining > 0 then
    icon.cooldownText:SetText(W:FormatCooldown(reminder.remaining))
  else
    icon.cooldownText:SetText("")
  end
  local theme = RUI:GetTheme()
  W:SetBorder(icon, theme.accent2, 1)
  W:SetGlow(icon, theme.accent2, 0.92)
  icon:Show()
  return true
end

local function ReinforcementReminder()
  if not HasShield() or not SpellKnown(653386) then return nil end
  local enchanted, remainingMS = OffhandEnchant()
  if enchanted and remainingMS > 300000 then return nil end

  local level = type(UnitLevel) == "function" and tonumber(UnitLevel("player")) or 1
  local spellID = level >= 58 and 653279 or 653131
  local name = level >= 58 and "Jagged Reinforcement" or "Spiked Reinforcement"
  return {
    name=name,
    label="REINFORCE",
    texture=TextureFor(spellID, "Interface\\Icons\\INV_Shield_06"),
    remaining=enchanted and math.max(0, remainingMS / 1000) or 0,
    description=enchanted and "Your offhand reinforcement expires in 5 minutes or less."
      or "Your shield is missing its reinforcement.",
  }
end

local function HonorReminder()
  if not HasShield() then return nil end
  local level = type(UnitLevel) == "function" and tonumber(UnitLevel("player")) or 1
  if level >= 60 and SpellKnown(680280) then
    if PlayerAura({680280, 300856}) then return nil end
    return {
      name="Greater Honor", label="HONOR",
      texture=TextureFor(680280, "Interface\\Icons\\Ability_Warrior_VictoryRush"),
      description="Greater Honor is missing.",
    }
  end
  if level < 60 and SpellKnown(301232) then
    if PlayerAura({300856}) then return nil end
    return {
      name="Honor", label="HONOR",
      texture=TextureFor(300856, "Interface\\Icons\\Ability_Warrior_VictoryRush"),
      description="Honor is missing.",
    }
  end
  return nil
end

local function UpdateReminders()
  local frame = CreateReminderFrame()
  if not GuardianHUDActive() then frame:Hide(); return end

  local reminders = {ReinforcementReminder(), HonorReminder()}
  local visible = {}
  for _, reminder in ipairs(reminders) do
    if reminder then visible[#visible + 1] = reminder end
  end

  local size, gap = 30, 3
  local total = #visible > 0 and (#visible * size + (#visible - 1) * gap) or 1
  frame:SetSize(total, size)
  PositionReminderFrame()

  for index, icon in ipairs(reminderIcons) do
    icon:ClearAllPoints()
    if visible[index] then
      icon:SetPoint("LEFT", frame, "LEFT", (index - 1) * (size + gap), 0)
      SetReminder(icon, visible[index])
    else
      icon:Hide()
    end
  end

  if #visible > 0 then frame:Show() else frame:Hide() end
end

reminderDriver = CreateFrame("Frame", "RetreatUIGuardianReminderDriver")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
  "UNIT_INVENTORY_CHANGED", "UNIT_AURA", "SPELLS_CHANGED",
  "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED",
}) do
  pcall(reminderDriver.RegisterEvent, reminderDriver, eventName)
end

reminderDriver:SetScript("OnEvent", function(_, _, unit)
  if unit and unit ~= "player" then return end
  UpdateReminders()
end)
reminderDriver:SetScript("OnUpdate", function(_, delta)
  elapsed = elapsed + delta
  if elapsed < 0.50 then return end
  elapsed = 0
  UpdateReminders()
end)

module.guardianWAAuditRevision = 1
RUI._guardianWAAuditLoaded = true

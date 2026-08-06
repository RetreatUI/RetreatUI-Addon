local RUI = RetreatUITBC
if not RUI then return end

local Druid = {}
RUI:RegisterModule("druid", Druid)

local SPELLS = {
  cat = {
    { id = 27002, name = "Shred" },
    { id = 27003, name = "Rake", aura = 27003 },
    { id = 27008, name = "Rip", aura = 27008 },
    { id = 26996, name = "Mangle (Cat)" },
    { id = 27005, name = "Pounce" },
    { id = 27006, name = "Cower" },
  },
  bear = {
    { id = 26996, name = "Mangle (Bear)" },
    { id = 33745, name = "Lacerate", aura = 33745 },
    { id = 26997, name = "Swipe" },
    { id = 26998, name = "Demoralizing Roar", aura = 26998 },
    { id = 27009, name = "Maul" },
    { id = 27004, name = "Soothe Animal" },
  },
  caster = {
    { id = 26988, name = "Moonfire", aura = 26988 },
    { id = 27013, name = "Insect Swarm", aura = 27013 },
    { id = 26986, name = "Starfire" },
    { id = 26985, name = "Wrath" },
    { id = 26989, name = "Entangling Roots", aura = 26989 },
    { id = 33786, name = "Cyclone", aura = 33786 },
  },
  utility = {
    { id = 26994, name = "Rebirth" },
    { id = 26992, name = "Innervate" },
    { id = 26990, name = "Mark of the Wild" },
    { id = 26991, name = "Gift of the Wild" },
    { id = 22812, name = "Barkskin" },
    { id = 29166, name = "Innervate" },
  },
}

local frame
local icons = {}
local utilityIcons = {}

local function IsKnown(id)
  if IsSpellKnown then return IsSpellKnown(id) end
  local name = GetSpellInfo(id)
  if not name then return false end
  for tab = 1, GetNumSpellTabs() do
    local _, _, offset, count = GetSpellTabInfo(tab)
    for index = offset + 1, offset + count do
      local spellName = GetSpellBookItemName(index, BOOKTYPE_SPELL)
      if spellName == name then return true end
    end
  end
  return false
end

local function CurrentForm()
  local form = GetShapeshiftFormID and GetShapeshiftFormID()
  if form == 1 or form == 5 then return "cat" end
  if form == 8 or form == 7 then return "bear" end
  local powerType = UnitPowerType("player")
  if powerType == 3 then return "cat" end
  if powerType == 1 then return "bear" end
  return "caster"
end

local function AuraRemaining(spellId)
  for index = 1, 40 do
    local name, _, _, _, duration, expires, source, _, _, auraSpellId = UnitDebuff("target", index)
    if not name then break end
    if auraSpellId == spellId and source == "player" then
      return math.max(0, (expires or 0) - GetTime()), duration or 0
    end
  end
  return 0, 0
end

local function CreateIcon(parent)
  local button = CreateFrame("Frame", nil, parent)
  button:SetSize(34, 34)
  button.texture = button:CreateTexture(nil, "ARTWORK")
  button.texture:SetPoint("TOPLEFT", 2, -2)
  button.texture:SetPoint("BOTTOMRIGHT", -2, 2)
  button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.cooldown:SetAllPoints(button.texture)
  button.timer = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.timer:SetPoint("CENTER", 0, 0)
  button.timer:SetTextColor(1, 1, 1)
  button.border = button:CreateTexture(nil, "BACKGROUND")
  button.border:SetAllPoints()
  button.border:SetColorTexture(0, 0, 0, 1)
  return button
end

local function SetSpell(icon, entry)
  icon.entry = entry
  local texture = GetSpellTexture(entry.id)
  icon.texture:SetTexture(texture or 134400)
  local start, duration, enabled = GetSpellCooldown(entry.id)
  if enabled == 1 and duration and duration > 1.5 then
    icon.cooldown:SetCooldown(start, duration)
  else
    icon.cooldown:Clear()
  end
  if entry.aura and UnitExists("target") then
    local remaining = AuraRemaining(entry.aura)
    icon.timer:SetText(remaining > 0 and string.format("%.1f", remaining) or "")
    icon.texture:SetDesaturated(remaining <= 0)
  else
    icon.timer:SetText("")
    icon.texture:SetDesaturated(false)
  end
end

local function EnsureFrame()
  if frame then return frame end
  frame = CreateFrame("Frame", "RetreatUITBCDruidHUD", UIParent)
  frame:SetSize(420, 82)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 27)

  frame.resource = CreateFrame("StatusBar", nil, frame)
  frame.resource:SetSize(300, 16)
  frame.resource:SetPoint("TOP", 0, 0)
  frame.resource:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  frame.resource.bg = frame.resource:CreateTexture(nil, "BACKGROUND")
  frame.resource.bg:SetAllPoints()
  frame.resource.bg:SetColorTexture(0.03, 0.03, 0.03, 0.9)
  frame.resource.text = frame.resource:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.resource.text:SetPoint("CENTER")

  frame.combo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.combo:SetPoint("LEFT", frame.resource, "RIGHT", 8, 0)

  for index = 1, 10 do
    icons[index] = CreateIcon(frame)
    icons[index]:SetPoint("TOPLEFT", frame, "TOPLEFT", 22 + ((index - 1) * 38), -23)
  end
  for index = 1, 8 do
    utilityIcons[index] = CreateIcon(frame)
    utilityIcons[index]:SetSize(28, 28)
    utilityIcons[index]:SetPoint("TOPLEFT", frame, "TOPLEFT", 58 + ((index - 1) * 32), -61)
  end
  return frame
end

local function RefreshResource()
  local powerType = UnitPowerType("player")
  local current = UnitPower("player", powerType)
  local maximum = UnitPowerMax("player", powerType)
  frame.resource:SetMinMaxValues(0, math.max(1, maximum))
  frame.resource:SetValue(current)
  if powerType == 3 then frame.resource:SetStatusBarColor(1, 0.85, 0.05)
  elseif powerType == 1 then frame.resource:SetStatusBarColor(0.8, 0.12, 0.08)
  else frame.resource:SetStatusBarColor(0.1, 0.35, 0.95) end
  frame.resource.text:SetText(current .. " / " .. maximum)
  local combo = GetComboPoints and GetComboPoints("player", "target") or 0
  frame.combo:SetText(combo > 0 and tostring(combo) or "")
end

local function RefreshHUD()
  EnsureFrame()
  if RUI:GetPlayerClass() ~= "DRUID" or not RUI.db.hud.enabled then frame:Hide(); return end
  frame:Show()
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", RUI.db.hud.x or 0, RUI.db.hud.y or 27)
  frame:SetScale(RUI.db.hud.scale or 1)
  RefreshResource()

  local active = SPELLS[CurrentForm()]
  local shown = 0
  for _, entry in ipairs(active) do
    if IsKnown(entry.id) then
      shown = shown + 1
      icons[shown]:Show()
      SetSpell(icons[shown], entry)
    end
  end
  for index = shown + 1, #icons do icons[index]:Hide() end

  shown = 0
  for _, entry in ipairs(SPELLS.utility) do
    if IsKnown(entry.id) then
      shown = shown + 1
      utilityIcons[shown]:Show()
      SetSpell(utilityIcons[shown], entry)
    end
  end
  for index = shown + 1, #utilityIcons do utilityIcons[index]:Hide() end
end

function Druid:OnLogin()
  if RUI:GetPlayerClass() ~= "DRUID" then return end
  EnsureFrame()
  local watcher = CreateFrame("Frame")
  watcher:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  watcher:RegisterEvent("UNIT_POWER_UPDATE")
  watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
  watcher:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  watcher:RegisterEvent("UNIT_AURA")
  watcher:SetScript("OnEvent", RefreshHUD)
  watcher:SetScript("OnUpdate", function(_, elapsed)
    watcher.elapsed = (watcher.elapsed or 0) + elapsed
    if watcher.elapsed >= 0.1 then watcher.elapsed = 0; RefreshHUD() end
  end)
  RefreshHUD()
end

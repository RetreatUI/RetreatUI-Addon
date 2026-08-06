local RUI = RetreatUITBC
if not RUI then return end

local Druid = {}
RUI:RegisterModule("druid", Druid)

local SPELLS = {
  cat = {
    { id = 27002, aura = nil }, -- Shred
    { id = 27003, aura = 27003 }, -- Rake
    { id = 27008, aura = 27008 }, -- Rip
    { id = 33983, aura = nil }, -- Mangle (Cat)
    { id = 27005, aura = nil }, -- Pounce
    { id = 27006, aura = nil }, -- Cower
  },
  bear = {
    { id = 33917, aura = nil }, -- Mangle (Bear)
    { id = 33745, aura = 33745 }, -- Lacerate
    { id = 26997, aura = nil }, -- Swipe
    { id = 26998, aura = 26998 }, -- Demoralizing Roar
    { id = 26996, aura = nil }, -- Maul
    { id = 26999, aura = nil }, -- Frenzied Regeneration
  },
  caster = {
    { id = 26988, aura = 26988 }, -- Moonfire
    { id = 27013, aura = 27013 }, -- Insect Swarm
    { id = 26986, aura = nil }, -- Starfire
    { id = 26985, aura = nil }, -- Wrath
    { id = 26989, aura = 26989 }, -- Entangling Roots
    { id = 33786, aura = 33786 }, -- Cyclone
  },
  utility = {
    { id = 26994, aura = nil }, -- Rebirth
    { id = 29166, aura = nil }, -- Innervate
    { id = 22812, aura = nil }, -- Barkskin
    { id = 26990, aura = nil }, -- Mark of the Wild
    { id = 26991, aura = nil }, -- Gift of the Wild
    { id = 26982, aura = nil }, -- Remove Curse
  },
}

local root, mainIcons, utilityIcons = nil, {}, {}

local function SpellKnown(spellId)
  if IsSpellKnown and IsSpellKnown(spellId) then return true end
  local spellName = GetSpellInfo(spellId)
  if not spellName then return false end
  for tab = 1, GetNumSpellTabs() do
    local _, _, offset, count = GetSpellTabInfo(tab)
    for slot = offset + 1, offset + count do
      if GetSpellBookItemName(slot, BOOKTYPE_SPELL) == spellName then return true end
    end
  end
  return false
end

local function FormKey()
  local powerType = UnitPowerType("player")
  if powerType == 3 then return "cat" end
  if powerType == 1 then return "bear" end
  return "caster"
end

local function PlayerDebuffRemaining(spellId)
  if not UnitExists("target") then return 0 end
  for index = 1, 40 do
    local name, _, _, _, _, expires, caster, _, _, id = UnitDebuff("target", index)
    if not name then break end
    if id == spellId and caster == "player" then
      return math.max(0, (expires or 0) - GetTime())
    end
  end
  return 0
end

local function CreateIcon(parent, size)
  local icon = CreateFrame("Frame", nil, parent)
  icon:SetSize(size, size)
  icon.border = icon:CreateTexture(nil, "BACKGROUND")
  icon.border:SetAllPoints()
  icon.border:SetColorTexture(0, 0, 0, 1)
  icon.texture = icon:CreateTexture(nil, "ARTWORK")
  icon.texture:SetPoint("TOPLEFT", 2, -2)
  icon.texture:SetPoint("BOTTOMRIGHT", -2, 2)
  icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
  icon.cooldown:SetAllPoints(icon.texture)
  icon.timer = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  icon.timer:SetPoint("CENTER")
  icon.timer:SetTextColor(1, 1, 1)
  return icon
end

local function Build()
  if root then return end
  root = CreateFrame("Frame", "RetreatUITBCDruidHUD", UIParent)
  root:SetSize(430, 104)

  root.resource = CreateFrame("StatusBar", nil, root)
  root.resource:SetSize(300, 16)
  root.resource:SetPoint("TOP", 0, 0)
  root.resource:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  root.resource.bg = root.resource:CreateTexture(nil, "BACKGROUND")
  root.resource.bg:SetAllPoints()
  root.resource.bg:SetColorTexture(0.02, 0.02, 0.02, 0.94)
  root.resource.text = root.resource:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  root.resource.text:SetPoint("CENTER")

  root.combo = root:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  root.combo:SetPoint("LEFT", root.resource, "RIGHT", 8, 0)

  for i = 1, 10 do
    mainIcons[i] = CreateIcon(root, 34)
    mainIcons[i]:SetPoint("TOPLEFT", 22 + ((i - 1) * 38), -23)
  end
  for i = 1, 8 do
    utilityIcons[i] = CreateIcon(root, 28)
    utilityIcons[i]:SetPoint("TOPLEFT", 58 + ((i - 1) * 32), -63)
  end
end

local function PaintIcon(icon, entry)
  icon.texture:SetTexture(GetSpellTexture(entry.id) or 134400)
  local start, duration, enabled = GetSpellCooldown(entry.id)
  if enabled == 1 and duration and duration > 1.5 then
    icon.cooldown:SetCooldown(start, duration)
  else
    icon.cooldown:Clear()
  end
  if entry.aura then
    local remaining = PlayerDebuffRemaining(entry.aura)
    icon.timer:SetText(remaining > 0 and string.format("%.1f", remaining) or "")
    icon.texture:SetDesaturated(remaining <= 0)
  else
    icon.timer:SetText("")
    icon.texture:SetDesaturated(false)
  end
end

local function PaintRow(entries, widgets)
  local shown = 0
  for _, entry in ipairs(entries) do
    if SpellKnown(entry.id) then
      shown = shown + 1
      widgets[shown]:Show()
      PaintIcon(widgets[shown], entry)
    end
  end
  for i = shown + 1, #widgets do widgets[i]:Hide() end
end

local function Refresh()
  Build()
  local db = RUI:EnsureDB()
  if RUI:GetPlayerClass() ~= "DRUID" or not db.hud.enabled then root:Hide(); return end
  root:Show()
  root:ClearAllPoints()
  root:SetPoint("CENTER", UIParent, "CENTER", db.hud.x or 0, db.hud.y or 27)
  root:SetScale(db.hud.scale or 1)

  local powerType = UnitPowerType("player")
  local current, maximum = UnitPower("player", powerType), UnitPowerMax("player", powerType)
  root.resource:SetMinMaxValues(0, math.max(1, maximum))
  root.resource:SetValue(current)
  root.resource.text:SetText(current .. " / " .. maximum)
  if powerType == 3 then root.resource:SetStatusBarColor(1, 0.82, 0.04)
  elseif powerType == 1 then root.resource:SetStatusBarColor(0.78, 0.08, 0.05)
  else root.resource:SetStatusBarColor(0.08, 0.30, 0.78) end

  local combo = GetComboPoints and GetComboPoints("player", "target") or 0
  root.combo:SetText(combo > 0 and tostring(combo) or "")
  PaintRow(SPELLS[FormKey()], mainIcons)
  PaintRow(SPELLS.utility, utilityIcons)
end

function Druid:OnLogin()
  if RUI:GetPlayerClass() ~= "DRUID" then return end
  Build()
  local events = CreateFrame("Frame")
  events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  events:RegisterEvent("UNIT_POWER_UPDATE")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  events:RegisterEvent("UNIT_AURA")
  events:SetScript("OnEvent", Refresh)
  events:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed >= 0.1 then self.elapsed = 0; Refresh() end
  end)
  Refresh()
end

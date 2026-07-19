local RUI = RetreatUI
local W = RUI.HUDWidgets
local CLASS_NAME = "Cultist"

local module = {
  ready = true,
  className = CLASS_NAME,
  frameName = "RetreatUICultistHUD",
  supportedLoadouts = {TANK = true},
  usesPrimaryPower = true,
}

local root, driver, timerDriver
local elapsed = 0

local function Aura(unit, wanted, debuff)
  local getter = debuff and UnitDebuff or UnitBuff
  if not getter then return nil end
  for index = 1, 40 do
    local values = {getter(unit, index)}
    local name = values[1]
    if not name then break end
    if name == wanted then
      return {
        name = name,
        icon = values[3],
        count = values[4] or 0,
        duration = values[6] or 0,
        expires = values[7] or 0,
        caster = values[8],
        spellID = values[11],
        raw = values,
      }
    end
  end
end

local function Definitions(row)
  return RUI:GetHUDSpellDefinitions(CLASS_NAME, row)
end

local function Learned(definition)
  if definition and definition.hudRow and RUI.IsSpellRecordCastable then
    return RUI:IsSpellRecordCastable(definition)
  end
  return RUI:IsSpellRecordLearned(definition)
end

local function DefinitionTexture(definition)
  return RUI:GetSpellRecordTexture(definition)
end

local function BuildRows()
  W:BuildSpellRow(root.coreRow, Definitions("core"), 38, 1, Learned, DefinitionTexture)
  W:BuildSpellRow(root.utilityRow, Definitions("utility"), 32, 1, Learned, DefinitionTexture)
end

local function UpdateRows()
  local function PlayerAura(name)
    return Aura("player", name, false) or Aura("player", name, true)
  end
  W:UpdateSpellRow(root.coreRow, PlayerAura)
  W:UpdateSpellRow(root.utilityRow, PlayerAura)
end

local function TalentLearned(name)
  if RUI.IsSpellLearned and RUI:IsSpellLearned(name) then return true end
  local id = RUI.GetSpellID and RUI:GetSpellID(name)
  return id and RUI.IsSpellIDLearned and RUI:IsSpellIDLearned(id) or false
end

local function ReadInsanity()
  local aura = Aura("player", "Insanity", false) or Aura("player", "Insanity", true)
  if aura and tonumber(aura.count) then return tonumber(aura.count), aura end

  if UnitPowerType and UnitPower then
    local ok, powerType, token = pcall(UnitPowerType, "player")
    if ok and token and string.upper(tostring(token)) == "INSANITY" then
      local value = UnitPower("player", powerType or 0)
      if type(value) == "number" then return value, nil end
    end
  end
  return 0, nil
end

local function ActiveCultistForm()
  local wanted = {
    ["dreadnought"] = true,
    ["void monstrosity"] = true,
    ["strength of the black empire"] = true,
  }

  if GetNumShapeshiftForms and GetShapeshiftFormInfo then
    local current = GetShapeshiftForm and GetShapeshiftForm() or 0
    local count = GetNumShapeshiftForms() or 0
    for index = 1, count do
      local texture, name, active = GetShapeshiftFormInfo(index)
      local lower = name and string.lower(name) or ""
      if wanted[lower] and (active == true or active == 1 or index == current) then
        return name, texture
      end
    end
  end

  for _, name in ipairs({"Strength of the Black Empire", "Void Monstrosity", "Dreadnought"}) do
    local aura = Aura("player", name, false)
    if aura then return name, aura.icon end
  end
  return nil
end

local function HasDreadnought()
  if TalentLearned("Dreadnought") then return true end
  local name = ActiveCultistForm()
  return name ~= nil
end

local function InsanityColor(value, dreadnought)
  if dreadnought then
    if value >= 100 then return RUI:GetTheme().accent2, 6 end
    if value >= 80 then return RUI:GetTheme().accent2, nil end
    if value >= 60 then return RUI:GetTheme().accent, nil end
    return nil, nil
  end
  if value >= 100 then return {1.00, 0.08, 0.04, 1}, 8 end
  if value >= 80 then return {1.00, 0.40, 0.04, 1}, nil end
  if value >= 60 then return {1.00, 0.82, 0.08, 1}, nil end
  return nil, nil
end

local function UpdateInsanity()
  local value, aura = ReadInsanity()
  value = math.max(0, math.min(100, tonumber(value) or 0))
  local color, pulse = InsanityColor(value, HasDreadnought())
  W:SetCounter(
    root.insanity,
    aura and aura.icon or root.insanity.fallback,
    string.format("%d / 100", math.floor(value + 0.5)),
    aura ~= nil or value > 0,
    color,
    pulse
  )
end

local function FormatAmount(value)
  value = tonumber(value)
  if not value or value <= 0 then return nil end
  if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
  if value >= 1000 then return string.format("%.1fk", value / 1000) end
  return tostring(math.floor(value + 0.5))
end

local function AuraAbsorbValue(aura)
  if not aura or type(aura.raw) ~= "table" then return nil end
  local largest
  for index = 12, #aura.raw do
    local value = aura.raw[index]
    if type(value) == "number"
      and value > 1
      and value < 1000000000
      and math.abs(value - (tonumber(aura.expires) or 0)) > 0.01
      and math.abs(value - (tonumber(aura.duration) or 0)) > 0.01 then
      if not largest or value > largest then largest = value end
    end
  end
  return largest
end

local function FindShieldAura()
  for _, name in ipairs({"Void-Enhanced Shield", "Void Enhanced Shield", "Void Shield"}) do
    local aura = Aura("player", name, false) or Aura("player", name, true)
    if aura then return aura end
  end
  return nil
end

local function UpdateShield()
  local aura = FindShieldAura()
  local amount = AuraAbsorbValue(aura)
  local value
  if amount then
    value = FormatAmount(amount)
  elseif aura and tonumber(aura.count) and tonumber(aura.count) > 0 then
    value = tostring(aura.count)
  elseif aura then
    value = "ACTIVE"
  else
    value = "0"
  end

  W:SetCounter(
    root.shield,
    aura and aura.icon or root.shield.fallback,
    value,
    aura ~= nil,
    aura and RUI:GetTheme().accent2 or nil,
    nil
  )
end

local function UpdateFormTracker()
  local name, texture = ActiveCultistForm()
  W:SetFormTracker(
    root.formTracker,
    name,
    texture or (name and select(3, GetSpellInfo(name))) or "Interface\\Icons\\Spell_Shadow_Shadowform",
    RUI:GetTheme().accent2
  )
end

local function UpdateTotalMadness()
  if HasDreadnought() then
    root.totalMadness:Hide()
    return
  end

  local aura = Aura("player", "Total Madness", false) or Aura("player", "Total Madness", true)
  if not aura then
    root.totalMadness:Hide()
    return
  end

  local remain = aura.expires and aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
  root.totalMadness:Show()
  W:SetCounter(
    root.totalMadness,
    aura.icon or root.totalMadness.fallback,
    remain > 0 and W:FormatCooldown(remain) or "ACTIVE",
    true,
    {1.00, 0.08, 0.64, 1},
    remain > 0 and remain <= 2 and 10 or 6
  )
end

local function CreateAuraTracker(definition)
  local frame = W:CreateIcon(root, 30)
  frame.definition = definition
  frame:Hide()
  return frame
end

local function UpdateAuraTrackers()
  local active = {}
  for _, tracker in ipairs(root.trackers or {}) do
    local definition = tracker.definition or {}
    local name = definition.buff or definition.name
    local aura = Aura("player", name, false)
    if aura then
      tracker.aura = aura
      active[#active + 1] = tracker
    else
      tracker.aura = nil
      tracker:Hide()
    end
  end

  local layout = RUI.layout.auraTrackers or {}
  local size = layout.size or 30
  local spacing = layout.spacing or 3
  local y = layout.y or -83
  local total = #active > 0 and (#active * size + (#active - 1) * spacing) or 0

  for index, tracker in ipairs(active) do
    local aura = tracker.aura
    tracker:ClearAllPoints()
    tracker:SetPoint("CENTER", UIParent, "CENTER",
      (layout.x or 0) - total / 2 + size / 2 + (index - 1) * (size + spacing), y)
    tracker.texture:SetTexture(aura.icon or DefinitionTexture(tracker.definition) or "Interface\\Icons\\INV_Misc_QuestionMark")
    tracker:SetAlpha(1)
    tracker.stackText:SetText(aura.count and aura.count > 1 and tostring(aura.count) or "")
    if aura.expires and aura.expires > 0 then
      local remain = math.max(0, aura.expires - GetTime())
      tracker.cooldownText:SetText(W:FormatCooldown(remain))
      tracker.cooldownText:SetTextColor(1, remain <= 3 and 0.25 or 0.95, remain <= 3 and 0.15 or 0.35, 1)
    else
      tracker.cooldownText:SetText("")
    end
    W:SetBorder(tracker, RUI:GetTheme().accent2, 1)
    tracker:Show()
  end
end

local function UpdateAll()
  if not root then return end
  UpdateInsanity()
  UpdateShield()
  UpdateFormTracker()
  UpdateTotalMadness()
  UpdateRows()
  UpdateAuraTrackers()
end

local function Build()
  if root then return end
  root = CreateFrame("Frame", "RetreatUICultistHUD", UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("MEDIUM")

  local counters = RUI.layout.counters or {}
  local left = counters.imp or {x = -105, y = -118}
  local right = counters.blood or {x = 105, y = -118}

  root.insanity = W:CreateCounter(root, {
    label = "INSANITY",
    key = "insanity",
    fallback = "Interface\\Icons\\Spell_Shadow_MindTwisting",
    x = left.x,
    y = left.y,
    width = 104,
  })
  root.shield = W:CreateCounter(root, {
    label = "SHIELD",
    key = "voidShield",
    fallback = "Interface\\Icons\\Spell_Shadow_AntiShadow",
    x = right.x,
    y = right.y,
    width = 104,
  })
  root.formTracker = W:CreateFormTracker(root, {
    x = left.x - 62,
    y = left.y,
    width = 108,
    size = 38,
  })
  root.totalMadness = W:CreateCounter(root, {
    label = "TOTAL MADNESS",
    key = "totalMadness",
    fallback = "Interface\\Icons\\Spell_Shadow_MindTwisting",
    x = 0,
    y = -66,
    width = 118,
    size = 46,
    height = 78,
  })
  root.totalMadness:Hide()

  root.coreRow = CreateFrame("Frame", nil, root)
  root.coreRow:SetSize(520, 38)
  root.coreRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.core.x, RUI.layout.core.y)

  root.utilityRow = CreateFrame("Frame", nil, root)
  root.utilityRow:SetSize(520, 32)
  root.utilityRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.utility.x, RUI.layout.utility.y)
  BuildRows()

  root.trackers = {}
  for _, definition in ipairs(RUI:GetAuraTrackerDefinitions(CLASS_NAME) or {}) do
    local name = definition.buff or definition.name
    if name ~= "Void-Enhanced Shield" and name ~= "Void Enhanced Shield" and name ~= "Void Shield" then
      root.trackers[#root.trackers + 1] = CreateAuraTracker(definition)
    end
  end

  driver = CreateFrame("Frame")
  for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED",
    "UNIT_AURA", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "ACTIONBAR_UPDATE_COOLDOWN",
    "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS",
  }) do
    pcall(driver.RegisterEvent, driver, event)
  end

  driver:SetScript("OnEvent", function(_, event, unit)
    if not root or not root:IsShown() then return end
    if event == "UNIT_AURA" and unit ~= "player" then return end
    if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" or event == "CHARACTER_POINTS_CHANGED" then
      RUI:After(0.15, function()
        if RUI.ScanSpellbook then RUI:ScanSpellbook() end
        BuildRows()
        UpdateAll()
      end)
    else
      UpdateAll()
    end
  end)

  timerDriver = CreateFrame("Frame")
  timerDriver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.12 then return end
    elapsed = 0
    if root and root:IsShown() then UpdateAll() end
  end)
end

function module:activate()
  Build()
  root:Show()
  driver:Show()
  timerDriver:Show()
  UpdateAll()
  return true
end

function module:deactivate()
  if root then root:Hide() end
  if driver then driver:Hide() end
  if timerDriver then timerDriver:Hide() end
end

RUI:RegisterClassModule(CLASS_NAME, module)

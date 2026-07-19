local RUI = RetreatUI
local W = RUI.HUDWidgets
local CLASS_NAME = "Venomancer"

local module = {
  ready = true,
  className = CLASS_NAME,
  frameName = "RetreatUIVenomancerHUD",
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

local function ExposedColor(count)
  if count >= 9 then return {1.00, 0.08, 0.04, 1}, 7 end
  if count >= 7 then return {1.00, 0.40, 0.04, 1}, nil end
  if count >= 4 then return {1.00, 0.82, 0.08, 1}, nil end
  return nil, nil
end

local function UpdateExposedFlesh()
  local aura = Aura("player", "Exposed Flesh", false) or Aura("player", "Exposed Flesh", true)
  local count = aura and tonumber(aura.count) or 0
  local color, pulse = ExposedColor(count)
  W:SetCounter(
    root.exposed,
    aura and aura.icon or root.exposed.fallback,
    tostring(math.floor(count + 0.5)),
    aura ~= nil or count > 0,
    color,
    pulse
  )
end

local function UpdateCarapace()
  local aura = Aura("player", "Carapace Regeneration", false) or Aura("player", "Carapace Regeneration", true)
  local count = aura and tonumber(aura.count) or 0
  local maximum = TalentLearned("Fortify Carapace") and 5 or 3
  local color = count >= maximum and RUI:GetTheme().accent2 or nil
  W:SetCounter(
    root.carapace,
    aura and aura.icon or root.carapace.fallback,
    string.format("%d / %d", math.floor(count + 0.5), maximum),
    aura ~= nil or count > 0,
    color,
    count >= maximum and 4 or nil
  )
end

local function ActiveVenomancerForm()
  local wanted = {
    ["beetle form"] = true,
    ["spider lord"] = true,
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

  for _, name in ipairs({"Spider Lord", "Beetle Form"}) do
    local aura = Aura("player", name, false)
    if aura then return name, aura.icon end
  end
  return nil
end

local function UpdateFormTracker()
  local name, texture = ActiveVenomancerForm()
  W:SetFormTracker(
    root.formTracker,
    name,
    texture or (name and select(3, GetSpellInfo(name))) or "Interface\\Icons\\INV_Misc_MonsterScales_15",
    RUI:GetTheme().accent2
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
      tracker.cooldownText:SetTextColor(remain <= 3 and 1 or 1, remain <= 3 and 0.25 or 0.95, remain <= 3 and 0.15 or 0.35, 1)
    else
      tracker.cooldownText:SetText("")
    end
    W:SetBorder(tracker, RUI:GetTheme().accent2, 1)
    tracker:Show()
  end
end

local function UpdateAll()
  if not root then return end
  UpdateExposedFlesh()
  UpdateCarapace()
  UpdateFormTracker()
  UpdateRows()
  UpdateAuraTrackers()
end

local function Build()
  if root then return end
  root = CreateFrame("Frame", "RetreatUIVenomancerHUD", UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("MEDIUM")

  local counters = RUI.layout.counters or {}
  local left = counters.imp or {x = -105, y = -118}
  local right = counters.blood or {x = 105, y = -118}

  root.exposed = W:CreateCounter(root, {
    label = "EXPOSED FLESH",
    key = "exposedFlesh",
    fallback = "Interface\\Icons\\Ability_Creature_Poison_03",
    x = left.x,
    y = left.y,
    width = 104,
  })
  root.carapace = W:CreateCounter(root, {
    label = "CARAPACE",
    key = "carapace",
    fallback = "Interface\\Icons\\INV_Misc_MonsterScales_15",
    x = right.x,
    y = right.y,
    width = 104,
  })
  root.formTracker = W:CreateFormTracker(root, {
    x = left.x - 62,
    y = left.y,
    width = 98,
    size = 38,
  })

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
    if name ~= "Carapace Regeneration" then
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

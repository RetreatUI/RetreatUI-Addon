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
local previewStarted = GetTime and GetTime() or 0

-- Development preview. Learned-spell filtering remains the live behaviour once
-- this flag is disabled; race racials are always read from the real character.
local PREVIEW_MODE = true

local PREVIEW_LEARNED = {
  ["Beetle Form"] = true,
  ["Spider Form"] = true,
  ["Chitin Rush"] = true,
  ["Claw Strike"] = true,
  ["Hivebreak"] = true,
  ["Carapace Crash"] = true,
  ["Venomtip Poison"] = true,
  ["Expulsion"] = true,
  ["Barbed Stinger"] = true,
  ["Regrow Exoskeleton"] = true,
  ["Carapace Regeneration"] = true,
  ["Harden"] = true,
  ["Lifeblood"] = true,
  ["Burrow"] = true,
  ["Vile Sting"] = true,
  ["Myotoxin"] = true,
  ["Spindlebind"] = true,
  ["Pinch"] = true,
  ["Impale"] = true,
  ["Shadra's Lair"] = true,
  ["Hive Instinct"] = true,
  ["Toxic Stride"] = true,
}

local PREVIEW_TALENTS = {
  ["Deadly Sting"] = true,
  ["Unbreakable"] = true,
  ["Fortify Carapace"] = true,
  ["Tome of Ahn'kahet"] = true,
  ["Reformed"] = true,
  ["Shedder"] = true,
}

local FALLBACK_TEXTURES = {
  ["Beetle Form"] = "Interface\\Icons\\Ability_Hunter_Pet_Beetle",
  ["Spider Form"] = "Interface\\Icons\\Ability_Hunter_Pet_Spider",
  ["Chitin Rush"] = "Interface\\Icons\\Ability_Druid_FeralChargeCat",
  ["Claw Strike"] = "Interface\\Icons\\Ability_Druid_Rake",
  ["Hivebreak"] = "Interface\\Icons\\Ability_Creature_Poison_05",
  ["Carapace Crash"] = "Interface\\Icons\\Ability_Druid_Maul",
  ["Venomtip Poison"] = "Interface\\Icons\\Ability_Creature_Poison_03",
  ["Expulsion"] = "Interface\\Icons\\Spell_Nature_CorrosiveBreath",
  ["Barbed Stinger"] = "Interface\\Icons\\Ability_Hunter_AspectMastery",
  ["Regrow Exoskeleton"] = "Interface\\Icons\\INV_Misc_MonsterScales_15",
  ["Carapace Regeneration"] = "Interface\\Icons\\INV_Misc_MonsterScales_15",
  ["Harden"] = "Interface\\Icons\\Ability_Warrior_ShieldWall",
  ["Lifeblood"] = "Interface\\Icons\\Spell_Nature_HealingTouch",
  ["Burrow"] = "Interface\\Icons\\Ability_Vanish",
  ["Vile Sting"] = "Interface\\Icons\\Ability_Hunter_SniperShot",
  ["Myotoxin"] = "Interface\\Icons\\Spell_Nature_NullifyDisease",
  ["Spindlebind"] = "Interface\\Icons\\Spell_Nature_Web",
  ["Pinch"] = "Interface\\Icons\\Ability_Gouge",
  ["Impale"] = "Interface\\Icons\\Ability_ImpalingBolt",
  ["Shadra's Lair"] = "Interface\\Icons\\Spell_Nature_Web",
  ["Hive Instinct"] = "Interface\\Icons\\Ability_Hunter_FocusedAim",
  ["Toxic Stride"] = "Interface\\Icons\\Ability_Rogue_Sprint",
  ["Nullifying Venom"] = "Interface\\Icons\\Spell_Nature_NullifyDisease",
  ["Debilitating Venom"] = "Interface\\Icons\\Ability_PoisonSting",
  ["Blight Venom"] = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
  ["Weakening Venom"] = "Interface\\Icons\\Ability_Creature_Poison_02",
  ["Tome of Ahn'kahet"] = "Interface\\Icons\\INV_Misc_Book_09",
  ["Exposed Flesh"] = "Interface\\Icons\\Ability_Creature_Poison_03",
}

local function Normalize(value)
  return string.lower(tostring(value or "")):gsub("’", "'")
end

local function RealAura(unit, wanted, debuff)
  local getter = debuff and UnitDebuff or UnitBuff
  if not getter then return nil end
  local wantedLower = Normalize(wanted)
  for index = 1, 40 do
    local values = {getter(unit, index)}
    local name = values[1]
    if not name then break end
    if Normalize(name) == wantedLower then
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

local PREVIEW_AURAS = {
  player = {
    ["beetle form"] = {duration=3600, count=0},
    ["exposed flesh"] = {duration=30, count=7},
    ["carapace regeneration"] = {duration=18, remaining=11, count=2},
    ["harden"] = {duration=10, remaining=8, count=0},
    ["tome of ahn'kahet"] = {duration=15, remaining=12, count=0},
    ["nullifying venom"] = {duration=7200, remaining=6900, count=0},
    ["blight venom"] = {duration=7200, remaining=6850, count=0},
    ["shadra's lair"] = {duration=8, remaining=6, count=0},
    ["deadly sting"] = {duration=8, remaining=6, count=0},
  },
  target = {
    ["barbed stinger"] = {duration=17, remaining=9, count=0},
    ["myotoxin"] = {duration=20, remaining=14, count=0},
    ["weakening venom"] = {duration=10, remaining=8, count=0},
    ["venomtip poison"] = {duration=15, remaining=11, count=0},
  },
}

local function PreviewAura(unit, wanted)
  if not PREVIEW_MODE then return nil end
  local record = PREVIEW_AURAS[unit] and PREVIEW_AURAS[unit][Normalize(wanted)]
  if not record then return nil end
  local now = GetTime and GetTime() or previewStarted
  local remaining = tonumber(record.remaining)
  local expires = remaining and (previewStarted + remaining) or (now + (record.duration or 0))
  if remaining and expires <= now then
    -- Loop preview timers so the state remains visible during layout testing.
    previewStarted = now
    expires = now + remaining
  end
  return {
    name = wanted,
    icon = select(3, GetSpellInfo(wanted)) or FALLBACK_TEXTURES[wanted],
    count = record.count or 0,
    duration = record.duration or 0,
    expires = expires,
  }
end

local function Aura(unit, wanted, debuff)
  return RealAura(unit, wanted, debuff) or PreviewAura(unit, wanted)
end

local function PlayerAura(name)
  return Aura("player", name, false) or Aura("player", name, true)
end

local function TargetAura(name)
  return Aura("target", name, true) or Aura("target", name, false)
end

local function TalentLearned(name)
  if PREVIEW_MODE and PREVIEW_TALENTS[name] then return true end
  if RUI.IsSpellLearned and RUI:IsSpellLearned(name) then return true end
  local id = RUI.GetSpellID and RUI:GetSpellID(name)
  return id and RUI.IsSpellIDLearned and RUI:IsSpellIDLearned(id) or false
end

local function MainDefinitions(forceRacialScan)
  local output, seen = {}, {}
  for _, row in ipairs({"core", "utility"}) do
    for _, definition in ipairs(RUI:GetHUDSpellDefinitions(CLASS_NAME, row) or {}) do
      local key = Normalize(definition.name)
      if key ~= "" and not seen[key] then
        output[#output + 1] = definition
        seen[key] = true
      end
    end
  end
  if RUI.GetRacialSpellDefinitions then
    for _, racial in ipairs(RUI:GetRacialSpellDefinitions(forceRacialScan)) do
      local key = Normalize(racial.name)
      if key ~= "" and not seen[key] then
        racial.category = "racial"
        racial.trackCooldown = true
        racial.order = 900 + #output
        output[#output + 1] = racial
        seen[key] = true
      end
    end
  end
  table.sort(output, function(a, b)
    return (tonumber(a.order) or 9999) < (tonumber(b.order) or 9999)
  end)
  return output
end

local function Learned(definition)
  if definition and definition.racial then return true end
  if PREVIEW_MODE then return definition and PREVIEW_LEARNED[definition.name] == true end
  if definition and definition.hudRow and RUI.IsSpellRecordCastable then
    return RUI:IsSpellRecordCastable(definition)
  end
  return RUI:IsSpellRecordLearned(definition)
end

local function DefinitionTexture(definition)
  local texture = RUI:GetSpellRecordTexture(definition)
  if texture and texture ~= "Interface\\Icons\\INV_Misc_QuestionMark" then return texture end
  return FALLBACK_TEXTURES[definition and definition.name]
    or select(3, GetSpellInfo(definition and (definition.id or definition.name) or ""))
    or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function BuildMainRow(forceRacialScan)
  W:BuildSpellRow(root.mainRow, MainDefinitions(forceRacialScan), 38, 1, Learned, DefinitionTexture)
end

local function EnsureGlow(icon)
  if icon.decisionGlow then return icon.decisionGlow end
  local glow = icon:CreateTexture(nil, "OVERLAY")
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  glow:SetBlendMode("ADD")
  glow:SetPoint("CENTER", icon, "CENTER", 0, 0)
  glow:SetSize((icon:GetWidth() or 38) * 1.75, (icon:GetHeight() or 38) * 1.75)
  glow:Hide()
  icon.decisionGlow = glow
  return glow
end

local function SetDecisionGlow(icon, active, color, speed)
  if not icon then return end
  local glow = EnsureGlow(icon)
  if not active then glow:Hide(); return end
  color = color or RUI:GetTheme().accent2
  glow:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, 1)
  glow:SetAlpha(0.38 + 0.62 * math.abs(math.sin((GetTime and GetTime() or 0) * (speed or 6))))
  glow:Show()
end

local function ActiveForm()
  for _, name in ipairs({"Spider Lord", "Beetle Form", "Spider Form"}) do
    local aura = PlayerAura(name)
    if aura then return name, aura.icon end
  end
  if GetNumShapeshiftForms and GetShapeshiftFormInfo then
    local current = GetShapeshiftForm and GetShapeshiftForm() or 0
    for index = 1, (GetNumShapeshiftForms() or 0) do
      local texture, name, active = GetShapeshiftFormInfo(index)
      if name and (active == true or active == 1 or index == current) then
        local lower = Normalize(name)
        if lower == "beetle form" or lower == "spider form" or lower == "spider lord" then
          return name, texture
        end
      end
    end
  end
end

local function IsBeetleForm()
  local name = ActiveForm()
  return name == "Beetle Form" or name == "Spider Lord"
end

local function ExposedFlesh()
  local aura = PlayerAura("Exposed Flesh")
  return aura and tonumber(aura.count) or 0, aura
end

local function UpdateExposedFlesh()
  local count, aura = ExposedFlesh()
  local maximum = TalentLearned("Unbreakable") and 10 or 5
  local color, pulse
  if count >= maximum then color, pulse = {1.00, 0.16, 0.05, 1}, 7
  elseif count >= math.ceil(maximum * 0.7) then color = RUI:GetTheme().accent2
  elseif count >= math.ceil(maximum * 0.4) then color = RUI:GetTheme().accent end
  W:SetCounter(root.exposed, aura and aura.icon or root.exposed.fallback,
    string.format("%d / %d", math.floor(count + 0.5), maximum), true, color, pulse)
  return count
end

local function UpdateCarapace()
  local aura = PlayerAura("Carapace Regeneration")
  local count = aura and tonumber(aura.count) or 0
  local maximum = TalentLearned("Fortify Carapace") and 5 or 3
  W:SetCounter(root.carapace, aura and aura.icon or root.carapace.fallback,
    string.format("%d / %d", math.floor(count + 0.5), maximum), true,
    count >= maximum and RUI:GetTheme().accent2 or nil,
    count >= maximum and 5 or nil)
end

local function UpdateFormTracker()
  local name, texture = ActiveForm()
  W:SetFormTracker(root.formTracker, name,
    texture or FALLBACK_TEXTURES[name or "Beetle Form"], RUI:GetTheme().accent2)
end

local function SpellReady(definition)
  if PREVIEW_MODE then return true end
  local start, duration, enabled = W:ReadSpellCooldown(definition)
  local remaining = duration > 0 and math.max(0, start + duration - GetTime()) or 0
  return enabled ~= 0 and (duration <= 1.5 or remaining <= 0.05)
end

local function ApplyDecisionHighlights(exposed)
  local beetle = IsBeetleForm()
  local deadly = PlayerAura("Deadly Sting")
  local barbed = TargetAura("Barbed Stinger")
  local theme = RUI:GetTheme()

  for _, icon in ipairs(root.mainRow.icons or {}) do
    if icon:IsShown() and icon.definition then
      local definition = icon.definition
      local name = definition.name
      icon:SetAlpha(1)
      SetDecisionGlow(icon, false)

      if definition.requiresForm == "Beetle Form" and not beetle then
        W:SetIconInactive(icon, true)
      end

      if name == "Hivebreak" and deadly and SpellReady(definition) then
        W:SetBorder(icon, theme.accent2, 1)
        icon.stackText:SetText("FREE")
        SetDecisionGlow(icon, true, theme.accent2, 7)
      elseif definition.shed and exposed > 0 and SpellReady(definition) then
        W:SetBorder(icon, theme.accent, 1)
        icon.stackText:SetText(tostring(exposed))
        SetDecisionGlow(icon, true, theme.accent, 5)
      end

      if name == "Barbed Stinger" and barbed then
        icon.stackText:SetText("PULL")
        W:SetBorder(icon, theme.accent2, 1)
        SetDecisionGlow(icon, true, theme.accent2, 6)
      end
    end
  end
end

local function UpdateMainRow(exposed)
  W:UpdateSpellRow(root.mainRow, PlayerAura)
  ApplyDecisionHighlights(exposed)
end

local TRACKER_NAMES = {
  "Nullifying Venom", "Debilitating Venom", "Blight Venom", "Weakening Venom",
  "Carapace Regeneration", "Harden", "Lifeblood", "Burrow",
  "Regrow Exoskeleton", "Shadra's Lair", "Toxic Stride", "Tome of Ahn'kahet",
}

local function TrackerDefinition(name)
  for _, definition in ipairs(RUI:GetClassSpellRecords(CLASS_NAME) or {}) do
    if definition.name == name then return definition end
  end
  return {name=name, buff=name, fallbackIcon=FALLBACK_TEXTURES[name]}
end

local function BuildTrackers()
  root.trackers = root.trackers or {}
  for index, name in ipairs(TRACKER_NAMES) do
    local tracker = root.trackers[index]
    if not tracker then
      tracker = W:CreateIcon(root, 30)
      root.trackers[index] = tracker
    end
    tracker.definition = TrackerDefinition(name)
  end
end

local function UpdateTrackers()
  local active = {}
  for _, tracker in ipairs(root.trackers or {}) do
    local definition = tracker.definition or {}
    local aura = PlayerAura(definition.buff or definition.name)
    if aura then
      tracker.aura = aura
      active[#active + 1] = tracker
    else
      tracker.aura = nil
      tracker:Hide()
    end
  end

  local layout = RUI.layout.auraTrackers or {}
  local size, spacing = layout.size or 30, layout.spacing or 3
  local total = #active > 0 and (#active * size + (#active - 1) * spacing) or 0
  for index, tracker in ipairs(active) do
    local aura, definition = tracker.aura, tracker.definition or {}
    tracker:ClearAllPoints()
    tracker:SetPoint("CENTER", UIParent, "CENTER",
      (layout.x or 0) - total / 2 + size / 2 + (index - 1) * (size + spacing), layout.y or -83)
    tracker.texture:SetTexture(aura.icon or DefinitionTexture(definition))
    tracker:SetAlpha(1)
    tracker.stackText:SetText(aura.count and aura.count > 1 and tostring(aura.count) or "")
    if aura.expires and aura.expires > 0 then
      local remain = math.max(0, aura.expires - GetTime())
      tracker.cooldownText:SetText(remain > 3600 and "2h" or W:FormatCooldown(remain))
      tracker.cooldownText:SetTextColor(1, remain <= 3 and 0.25 or 0.95, remain <= 3 and 0.15 or 0.35, 1)
    else
      tracker.cooldownText:SetText("")
    end
    local isTome = definition.name == "Tome of Ahn'kahet"
    W:SetBorder(tracker, isTome and RUI:GetTheme().accent2 or RUI:GetTheme().accent, 1)
    SetDecisionGlow(tracker, isTome, RUI:GetTheme().accent2, 6)
    tracker:Show()
  end
end

local function UpdateAll()
  if not root then return end
  local exposed = UpdateExposedFlesh()
  UpdateCarapace()
  UpdateFormTracker()
  UpdateMainRow(exposed)
  UpdateTrackers()
end

local function Build()
  if root then return end
  root = CreateFrame("Frame", "RetreatUIVenomancerHUD", UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("MEDIUM")

  if PREVIEW_MODE then
    root.previewText = root:CreateFontString(nil, "OVERLAY")
    root.previewText:SetPoint("CENTER", UIParent, "CENTER", 0, -48)
    RUI:ApplyFont(root.previewText, 9, "OUTLINE")
    root.previewText:SetText("VENOMANCER PREVIEW")
    local accent = RUI:GetTheme().accent
    root.previewText:SetTextColor(accent[1], accent[2], accent[3], 1)
  end

  local counters = RUI.layout.counters or {}
  local left = counters.imp or {x=-105, y=-118}
  local right = counters.blood or {x=105, y=-118}

  root.exposed = W:CreateCounter(root, {
    label="EXPOSED FLESH", key="exposedFlesh", fallback=FALLBACK_TEXTURES["Exposed Flesh"],
    x=left.x, y=left.y, width=110,
  })
  root.carapace = W:CreateCounter(root, {
    label="CARAPACE", key="carapace", fallback=FALLBACK_TEXTURES["Carapace Regeneration"],
    x=right.x, y=right.y, width=104,
  })
  root.formTracker = W:CreateFormTracker(root, {
    x=left.x - 72, y=left.y, width=100, size=38,
  })

  root.mainRow = CreateFrame("Frame", nil, root)
  root.mainRow:SetSize(920, 38)
  root.mainRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.core.x, RUI.layout.core.y)
  BuildMainRow(true)
  BuildTrackers()

  driver = CreateFrame("Frame")
  for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED",
    "UNIT_AURA", "PLAYER_TARGET_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
    "ACTIONBAR_UPDATE_COOLDOWN", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS",
  }) do pcall(driver.RegisterEvent, driver, event) end

  driver:SetScript("OnEvent", function(_, event, unit)
    if not root or not root:IsShown() then return end
    if event == "UNIT_AURA" and unit ~= "player" and unit ~= "target" then return end
    if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" or event == "CHARACTER_POINTS_CHANGED" then
      RUI:After(0.15, function()
        if RUI.ScanSpellbook then RUI:ScanSpellbook() end
        if RUI.InvalidateRacialCache then RUI:InvalidateRacialCache() end
        BuildMainRow(true)
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
  root:Show(); driver:Show(); timerDriver:Show()
  BuildMainRow(true)
  UpdateAll()
  return true
end

function module:deactivate()
  if root then root:Hide() end
  if driver then driver:Hide() end
  if timerDriver then timerDriver:Hide() end
end

RUI:RegisterClassModule(CLASS_NAME, module)

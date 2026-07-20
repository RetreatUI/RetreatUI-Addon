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
local tentacleExpires = 0
local previewStarted = GetTime and GetTime() or 0

-- Development preview. The same code falls back to actual learned spells and
-- real auras when this flag is disabled. Race racials always come from the
-- current character and are never simulated.
local PREVIEW_MODE = true

local PREVIEW_LEARNED = {
  ["Twilight Shieldtoss"] = true,
  ["Entropic Slam"] = true,
  ["Dreadfall"] = true,
  ["Dreadnought"] = true,
  ["Void-Enhanced Shield"] = true,
  ["Abyssal Ward"] = true,
  ["Embrace the Void"] = true,
  ["Test of Pride"] = true,
  ["Horrifying Presence"] = true,
  ["Crushing Dissonance"] = true,
  ["Mass Nightmare"] = true,
  ["Entropic Singularity"] = true,
  ["Devour Magic"] = true,
  ["Sermon of Dread"] = true,
  ["Presence of Y'Shaarj"] = true,
  ["Tentacle of Yogg-Saron"] = true,
  ["Satiate"] = true,
  ["Twisted Seal"] = true,
}

local PREVIEW_TALENTS = {
  ["Dreadnought"] = true,
  ["Shroud of Pride"] = true,
  ["Overwhelming Void"] = true,
  ["General of Y'Shaarj"] = true,
}

local FALLBACK_TEXTURES = {
  ["Twilight Shieldtoss"] = "Interface\\Icons\\INV_Shield_04",
  ["Entropic Slam"] = "Interface\\Icons\\Ability_Warrior_Devastate",
  ["Dreadfall"] = "Interface\\Icons\\Spell_Shadow_DeathCoil",
  ["Dreadnought"] = "Interface\\Icons\\Spell_Shadow_Shadowform",
  ["Void-Enhanced Shield"] = "Interface\\Icons\\Spell_Shadow_AntiShadow",
  ["Abyssal Ward"] = "Interface\\Icons\\Spell_Shadow_DemonicFortitude",
  ["Embrace the Void"] = "Interface\\Icons\\Spell_Shadow_Shadowform",
  ["Test of Pride"] = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
  ["Horrifying Presence"] = "Interface\\Icons\\Spell_Shadow_Possession",
  ["Crushing Dissonance"] = "Interface\\Icons\\Spell_Shadow_PsychicScream",
  ["Mass Nightmare"] = "Interface\\Icons\\Spell_Shadow_PsychicScream",
  ["Entropic Singularity"] = "Interface\\Icons\\Spell_Shadow_Shadowfury",
  ["Devour Magic"] = "Interface\\Icons\\Spell_Shadow_DemonicFortitude",
  ["Sermon of Dread"] = "Interface\\Icons\\Spell_Shadow_AuraOfDarkness",
  ["Presence of Y'Shaarj"] = "Interface\\Icons\\Spell_Shadow_Twilight",
  ["Tentacle of Yogg-Saron"] = "Interface\\Icons\\Spell_Shadow_Twilight",
  ["Satiate"] = "Interface\\Icons\\Spell_Shadow_SiphonMana",
  ["Twisted Seal"] = "Interface\\Icons\\Spell_Shadow_SealOfKings",
  ["Insanity"] = "Interface\\Icons\\Spell_Shadow_MindTwisting",
  ["Total Madness"] = "Interface\\Icons\\Spell_Shadow_MindTwisting",
}

local AURA_ALIASES = {
  ["Void-Enhanced Shield"] = {"Void-Enhanced Shield", "Void Enhanced Shield", "Void Shield"},
  ["Presence of Y'Shaarj"] = {"Presence of Y'Shaarj", "Presence of Y'shaarj", "Presence of Y’Shaarj"},
  ["Tentacle of Yogg-Saron"] = {"Tentacle of Yogg-Saron", "Tentacle of Y'Shaarj", "Tentacle of Y'shaarj", "Tentacle of Y’Shaarj"},
  ["Dreadnought"] = {"Dreadnought", "Void Monstrosity", "Strength of the Black Empire"},
}

local function Normalize(value)
  return string.lower(tostring(value or "")):gsub("’", "'")
end

local function RealAura(unit, wanted, debuff)
  local getter = debuff and UnitDebuff or UnitBuff
  if not getter then return nil end
  local wantedNames = AURA_ALIASES[wanted] or {wanted}
  local wantedSet = {}
  for _, name in ipairs(wantedNames) do wantedSet[Normalize(name)] = true end

  for index = 1, 40 do
    local values = {getter(unit, index)}
    local name = values[1]
    if not name then break end
    if wantedSet[Normalize(name)] then
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
    ["dreadnought"] = {duration=20, remaining=13, count=0},
    ["abyssal ward"] = {duration=10, remaining=8, count=4},
    ["tentacle of yogg-saron"] = {duration=30, remaining=22, count=0},
    ["presence of y'shaarj"] = {duration=3600, count=0},
    ["satiate"] = {duration=6, remaining=4, count=0},
  },
  target = {},
}

local function PreviewAura(unit, wanted)
  if not PREVIEW_MODE then return nil end
  local key = Normalize(wanted)
  local record = PREVIEW_AURAS[unit] and PREVIEW_AURAS[unit][key]
  if not record then
    -- Aliases should resolve to the canonical preview state too.
    for canonical, aliases in pairs(AURA_ALIASES) do
      for _, alias in ipairs(aliases) do
        if Normalize(alias) == key then
          record = PREVIEW_AURAS[unit] and PREVIEW_AURAS[unit][Normalize(canonical)]
          if record then wanted = canonical break end
        end
      end
      if record then break end
    end
  end
  if not record then return nil end

  local now = GetTime and GetTime() or previewStarted
  local remaining = tonumber(record.remaining)
  local expires = remaining and (previewStarted + remaining) or (now + (record.duration or 0))
  if remaining and expires <= now then
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
  local aura = RealAura(unit, wanted, debuff) or PreviewAura(unit, wanted)
  if aura then return aura end
  if wanted == "Tentacle of Yogg-Saron" and tentacleExpires > (GetTime and GetTime() or 0) then
    return {
      name=wanted,
      icon=select(3, GetSpellInfo(802042)) or FALLBACK_TEXTURES[wanted],
      count=0, duration=30, expires=tentacleExpires,
    }
  end
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

local function ReadInsanity()
  local aura = RealAura("player", "Insanity", false) or RealAura("player", "Insanity", true)
  if aura and tonumber(aura.count) then return tonumber(aura.count), aura end
  if UnitPowerType and UnitPower then
    local ok, powerType, token = pcall(UnitPowerType, "player")
    if ok and token and string.upper(tostring(token)) == "INSANITY" then
      local value = UnitPower("player", powerType or 0)
      if type(value) == "number" then return value, nil end
    end
  end
  if PREVIEW_MODE then return 84, nil end
  return 0, nil
end

local function UpdateInsanity()
  local value, aura = ReadInsanity()
  value = math.max(0, math.min(100, tonumber(value) or 0))
  local color, pulse
  if value >= 100 then color, pulse = {1.00, 0.12, 0.04, 1}, 8
  elseif value >= 80 then color = RUI:GetTheme().accent2
  elseif value >= 60 then color = RUI:GetTheme().accent end
  W:SetCounter(root.insanity, aura and aura.icon or root.insanity.fallback,
    string.format("%d / 100", math.floor(value + 0.5)), true, color, pulse)
  return value
end

local function UpdateTotalMadness()
  local aura = RealAura("player", "Total Madness", false) or RealAura("player", "Total Madness", true)
  if not aura then
    W:SetCounter(root.totalMadness, root.totalMadness.fallback, "", false, {0.52, 0.52, 0.58, 1}, nil)
    SetDecisionGlow(root.totalMadness.icon, false)
    return
  end
  local remain = aura.expires and aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
  local value = remain > 0 and W:FormatCooldown(remain) or "ACTIVE"
  if aura.count and aura.count > 1 then value = value .. "  " .. tostring(aura.count) end
  W:SetCounter(root.totalMadness, aura.icon or root.totalMadness.fallback, value, true,
    {1.00, 0.08, 0.64, 1}, remain > 0 and remain <= 2 and 10 or 6)
  SetDecisionGlow(root.totalMadness.icon, true, {1.00, 0.08, 0.64, 1}, 6)
end

local function SpellReady(definition)
  if PREVIEW_MODE then return true end
  local start, duration, enabled = W:ReadSpellCooldown(definition)
  local remaining = duration > 0 and math.max(0, start + duration - GetTime()) or 0
  return enabled ~= 0 and (duration <= 1.5 or remaining <= 0.05)
end

local function ApplyDecisionHighlights(insanity)
  local theme = RUI:GetTheme()
  local sermon = TargetAura("Sermon of Dread")
  local presence = PlayerAura("Presence of Y'Shaarj")
  local satiate = PlayerAura("Satiate")

  for _, icon in ipairs(root.mainRow.icons or {}) do
    if icon:IsShown() and icon.definition then
      local definition = icon.definition
      local name = definition.name
      icon:SetAlpha(1)
      SetDecisionGlow(icon, false)

      if name == "Entropic Slam" then
        if insanity < 60 then
          W:SetIconInactive(icon, true)
          icon.stackText:SetText("60")
        elseif SpellReady(definition) then
          W:SetBorder(icon, theme.accent2, 1)
          icon.stackText:SetText("60+")
          SetDecisionGlow(icon, true, theme.accent2, 6)
        end
      elseif name == "Dreadnought" then
        local active = PlayerAura("Dreadnought")
        if active then
          W:SetBorder(icon, theme.accent2, 1)
          SetDecisionGlow(icon, true, theme.accent2, 5)
        elseif insanity < 80 then
          W:SetIconInactive(icon, true)
          icon.stackText:SetText("80")
        elseif SpellReady(definition) then
          W:SetBorder(icon, theme.accent2, 1)
          icon.stackText:SetText("READY")
          SetDecisionGlow(icon, true, theme.accent2, 6)
        end
      elseif name == "Mass Nightmare" and TalentLearned("Overwhelming Void") and insanity >= 80 and SpellReady(definition) then
        W:SetBorder(icon, theme.accent2, 1)
        icon.stackText:SetText("80+")
        SetDecisionGlow(icon, true, theme.accent2, 7)
      elseif name == "Sermon of Dread" and not sermon and SpellReady(definition) then
        W:SetBorder(icon, theme.accent, 1)
        icon.stackText:SetText("AP")
        SetDecisionGlow(icon, true, theme.accent, 5)
      elseif name == "Presence of Y'Shaarj" then
        if presence then
          icon:SetAlpha(0.68)
          icon.stackText:SetText("ON")
        else
          icon.stackText:SetText("ON")
          W:SetBorder(icon, theme.accent2, 1)
          SetDecisionGlow(icon, true, theme.accent2, 5)
        end
      elseif name == "Satiate" and satiate then
        local warning = {1.00, 0.36, 0.04, 1}
        W:SetBorder(icon, warning, 1)
        icon.stackText:SetText("+20%")
        SetDecisionGlow(icon, true, warning, 8)
      elseif name == "Embrace the Void" and PlayerAura("Embrace the Void") then
        W:SetBorder(icon, theme.accent2, 1)
        SetDecisionGlow(icon, true, theme.accent2, 8)
      end
    end
  end
end

local function UpdateMainRow(insanity)
  W:UpdateSpellRow(root.mainRow, PlayerAura)
  ApplyDecisionHighlights(insanity)
end

local TRACKER_NAMES = {
  "Dreadnought", "Void-Enhanced Shield", "Abyssal Ward", "Embrace the Void",
  "Horrifying Presence", "Tentacle of Yogg-Saron", "Satiate", "Twisted Seal",
}

local function TrackerDefinition(name)
  for _, definition in ipairs(RUI:GetClassSpellRecords(CLASS_NAME) or {}) do
    if definition.name == name and definition.auraTracker then return definition end
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
    local remain = 0
    if aura.expires and aura.expires > 0 then
      remain = math.max(0, aura.expires - GetTime())
      tracker.cooldownText:SetText(W:FormatCooldown(remain))
      tracker.cooldownText:SetTextColor(1, remain <= 3 and 0.25 or 0.95, remain <= 3 and 0.15 or 0.35, 1)
    else
      tracker.cooldownText:SetText("")
    end
    local warning = definition.name == "Satiate"
    local color = warning and {1.00, 0.36, 0.04, 1} or RUI:GetTheme().accent2
    W:SetBorder(tracker, color, 1)
    SetDecisionGlow(tracker, warning or definition.name == "Dreadnought", color, warning and 8 or 5)
    tracker:Show()
  end
end

local function UpdateAll()
  if not root then return end
  local insanity = UpdateInsanity()
  UpdateTotalMadness()
  UpdateMainRow(insanity)
  UpdateTrackers()
end

local function CastMatchesTentacle(...)
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    local name = type(value) == "string" and value or (type(value) == "number" and GetSpellInfo(value))
    if name then
      local lower = Normalize(name)
      if lower == "tentacle of yogg-saron" or lower == "tentacle of y'shaarj" then return true end
    end
  end
  return false
end

local function Build()
  if root then return end
  root = CreateFrame("Frame", "RetreatUICultistHUD", UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("MEDIUM")

  if PREVIEW_MODE then
    root.previewText = root:CreateFontString(nil, "OVERLAY")
    root.previewText:SetPoint("CENTER", UIParent, "CENTER", 0, -48)
    RUI:ApplyFont(root.previewText, 9, "OUTLINE")
    root.previewText:SetText("CULTIST PREVIEW")
    local accent = RUI:GetTheme().accent
    root.previewText:SetTextColor(accent[1], accent[2], accent[3], 1)
  end

  local counters = RUI.layout.counters or {}
  local left = counters.imp or {x=-105, y=-118}
  local right = counters.blood or {x=105, y=-118}

  root.insanity = W:CreateCounter(root, {
    label="INSANITY", key="insanity", fallback=FALLBACK_TEXTURES["Insanity"],
    x=left.x, y=left.y, width=104,
  })
  root.totalMadness = W:CreateCounter(root, {
    label="TOTAL MADNESS", key="totalMadness", fallback=FALLBACK_TEXTURES["Total Madness"],
    x=right.x, y=right.y, width=118,
  })

  root.mainRow = CreateFrame("Frame", nil, root)
  root.mainRow:SetSize(900, 38)
  root.mainRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.core.x, RUI.layout.core.y)
  BuildMainRow(true)
  BuildTrackers()

  driver = CreateFrame("Frame")
  for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED",
    "UNIT_AURA", "PLAYER_TARGET_CHANGED", "UNIT_SPELLCAST_SUCCEEDED", "SPELL_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES", "ACTIONBAR_UPDATE_COOLDOWN",
  }) do pcall(driver.RegisterEvent, driver, event) end

  driver:SetScript("OnEvent", function(_, event, ...)
    if not root or not root:IsShown() then return end
    local unit = select(1, ...)
    if event == "UNIT_AURA" and unit ~= "player" and unit ~= "target" then return end
    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and CastMatchesTentacle(select(2, ...)) then
      tentacleExpires = GetTime() + 30
    end
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

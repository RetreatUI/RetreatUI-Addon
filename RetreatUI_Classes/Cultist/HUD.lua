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
local tentacleTexture



local function StrictTexture(definition)
  if not definition then return nil end
  return W:ResolveStrictSpellTexture(definition)
end

local function ResolveTexture(name, aliases, exactID)
  return StrictTexture({name=name, aliases=aliases, id=exactID})
end

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

local AURA_ALIASES = {
  ["Void-Enhanced Shield"] = {"Void-Enhanced Shield", "Void Enhanced Shield", "Void Shield"},
  ["Tentacle of Yogg-Saron"] = {"Tentacle of Yogg-Saron", "Tentacle of Yogg Saron", "Tentacle of Y'Shaarj", "Tentacle of Y'shaarj", "Tentacle of Y’Shaarj"},
  ["Presence of Y'Shaarj"] = {"Presence of Y'Shaarj", "Presence of Y'shaarj", "Presence of Y’Shaarj"},
  ["Gaze of C'Thun"] = {"Gaze of C'Thun", "Gaze of C’Thun"},
}

local function AuraByNames(unit, names, debuff)
  if type(names) ~= "table" then names = {names} end
  for _, name in ipairs(names or {}) do
    local aura = Aura(unit, name, debuff)
    if aura then return aura end
  end
end

local function PlayerAura(name)
  local names = AURA_ALIASES[name] or {name}
  return AuraByNames("player", names, false) or AuraByNames("player", names, true)
end

local function TargetAura(name, debuff)
  local names = AURA_ALIASES[name] or {name}
  return AuraByNames("target", names, debuff ~= false)
end

local function NormalizeSpellName(value)
  return type(value) == "string" and string.lower(value:gsub("’", "'")) or ""
end

local function CastMatchesTentacle(...)
  local wanted = {
    [NormalizeSpellName("Tentacle of Yogg-Saron")] = true,
    [NormalizeSpellName("Tentacle of Yogg Saron")] = true,
    [NormalizeSpellName("Tentacle of Y'Shaarj")] = true,
    [NormalizeSpellName("Tentacle of Y'shaarj")] = true,
  }
  for index = 1, select("#", ...) do
    local value = select(index, ...)
    local name
    if type(value) == "string" then
      name = value
    elseif type(value) == "number" and GetSpellInfo then
      name = GetSpellInfo(value)
    end
    if name and wanted[NormalizeSpellName(name)] then return true end
  end
  return false
end

local function TentacleAura()
  local aura = PlayerAura("Tentacle of Yogg-Saron")
  if aura then return aura end
  local now = GetTime()
  if tentacleExpires > now then
    return {
      name = "Tentacle of Yogg-Saron",
      icon = tentacleTexture or ResolveTexture("Tentacle of Yogg-Saron", AURA_ALIASES["Tentacle of Yogg-Saron"]),
      count = 0,
      duration = 30,
      expires = tentacleExpires,
    }
  end
end

-- The class database is the single source of truth for row placement.
-- Main row: rotation, taunts, interrupt, movement and defensive cooldowns.
-- Small row: maintenance, control, summons, resource tools, dispel and racials.

local function Definitions(row, forceRacialScan)
  local definitions, seen = {}, {}
  for _, definition in ipairs(RUI:GetTankHUDDefinitions(CLASS_NAME, row) or {}) do
    definitions[#definitions + 1] = definition
    seen[string.lower(definition.name or "")] = true
  end

  if row == "utility" and RUI.GetRacialSpellDefinitions then
    for _, racial in ipairs(RUI:GetRacialSpellDefinitions(forceRacialScan)) do
      local key = string.lower(racial.name or "")
      if key ~= "" and not seen[key] then
        racial.category = "racial"
        racial.hudRow = "utility"
        racial.order = 900
        definitions[#definitions + 1] = racial
        seen[key] = true
      end
    end
  end
  return definitions
end

local function DefinitionTexture(definition)
  if not definition then return nil end
  return RUI:GetSpellRecordTexture(definition)
end

local function Learned(definition)
  if definition and definition.racial then return true end
  if definition and definition.hudRow and RUI.IsSpellRecordCastable then
    return RUI:IsSpellRecordCastable(definition)
  end
  return RUI:IsSpellRecordLearned(definition)
end

local function BuildRows(forceRacialScan)
  W:BuildSpellRow(root.coreRow, Definitions("core", false), 38, 1, Learned, DefinitionTexture)
  W:BuildSpellRow(root.utilityRow, Definitions("utility", forceRacialScan), 32, 1, Learned, DefinitionTexture)
end

local UpdateRows

local function TalentLearned(name)
  if RUI.IsSpellLearned and RUI:IsSpellLearned(name) then return true end
  local id = RUI.GetSpellID and RUI:GetSpellID(name)
  return id and RUI.IsSpellIDLearned and RUI:IsSpellIDLearned(id) or false
end

local function ReadInsanity()
  local aura = Aura("player", "Insanity", false) or Aura("player", "Insanity", true)
  if aura and tonumber(aura.count) then return tonumber(aura.count), aura end

  local primaryType = -1
  if UnitPowerType then
    local ok, value = pcall(UnitPowerType, "player")
    if ok and type(value) == "number" then primaryType = value end
  end

  -- Retail's Insanity token is power ID 13. Ascension builds have also exposed
  -- custom resources through neighbouring IDs, so probe a tiny fixed set and
  -- prefer an exact 100-point resource while never reusing the Mana power.
  if UnitPower and UnitPowerMax then
    local candidates = {}
    if type(SPELL_POWER_INSANITY) == "number" then candidates[#candidates + 1] = SPELL_POWER_INSANITY end
    for _, powerType in ipairs({13, 12, 14, 15, 10, 11}) do candidates[#candidates + 1] = powerType end
    local fallbackValue
    for _, powerType in ipairs(candidates) do
      if powerType ~= primaryType then
        local okMax, maximum = pcall(UnitPowerMax, "player", powerType)
        local okValue, value = pcall(UnitPower, "player", powerType)
        maximum, value = tonumber(maximum), tonumber(value)
        if okMax and okValue and maximum and maximum > 0 and value then
          if maximum == 100 then return value, nil end
          if not fallbackValue and maximum <= 200 then fallbackValue = value end
        end
      end
    end
    if fallbackValue then return fallbackValue, nil end
  end
  return 0, nil
end

local function SpellReady(definition)
  local start, duration, enabled = W:ReadSpellCooldown(definition)
  local remaining = duration > 0 and math.max(0, start + duration - GetTime()) or 0
  return enabled ~= 0 and (duration <= 1.5 or remaining <= 0.05)
end

local function ChannelInfo(name)
  if not UnitChannelInfo then return nil end
  local values = {UnitChannelInfo("player")}
  local channelName = values[1]
  if not channelName or NormalizeSpellName(channelName) ~= NormalizeSpellName(name) then return nil end
  local startMS = tonumber(values[5]) or 0
  local endMS = tonumber(values[6]) or 0
  return {
    name = channelName,
    texture = values[4],
    startTime = startMS / 1000,
    endTime = endMS / 1000,
    remaining = math.max(0, endMS / 1000 - GetTime()),
  }
end

local function ApplyDecisionHighlights(insanity)
  local tentacleActive = TentacleAura() ~= nil
  local targetExists = UnitExists and UnitExists("target")
  local hostileTarget = targetExists and UnitCanAttack and UnitCanAttack("player", "target")
  local friendlyTarget = targetExists and UnitIsFriend and UnitIsFriend("player", "target")

  for _, row in ipairs({root.coreRow, root.utilityRow}) do
    for _, icon in ipairs(row.icons or {}) do
      local definition = icon.definition
      if icon:IsShown() and definition then
        W:SetGlow(icon, nil, 0)

        if definition.name == "Entropic Slam" then
          local usable = insanity >= 60 and SpellReady(definition)
          W:SetIconInactive(icon, not usable)
          if usable then
            local alpha = 0.35 + 0.65 * math.abs(math.sin(GetTime() * 6))
            W:SetBorder(icon, RUI:GetTheme().accent2, alpha)
            W:SetGlow(icon, RUI:GetTheme().accent2, alpha * 0.75)
            icon.stackText:SetText("60+")
          else
            icon.stackText:SetText("60")
          end

        elseif definition.name == "Mass Nightmare"
          and TalentLearned("Overwhelming Void")
          and insanity >= 80
          and SpellReady(definition) then
          local alpha = 0.45 + 0.55 * math.abs(math.sin(GetTime() * 7))
          W:SetBorder(icon, RUI:GetTheme().accent2, alpha)
          W:SetGlow(icon, RUI:GetTheme().accent2, alpha * 0.65)
          icon.stackText:SetText("80+")

        elseif definition.name == "Gaze of C'Thun" and tentacleActive and SpellReady(definition) then
          local alpha = 0.42 + 0.58 * math.abs(math.sin(GetTime() * 5))
          W:SetBorder(icon, RUI:GetTheme().accent2, alpha)
          W:SetGlow(icon, RUI:GetTheme().accent2, alpha * 0.55)

        elseif definition.name == "Sermon of Dread" then
          local aura = hostileTarget and TargetAura("Sermon of Dread", true) or nil
          if hostileTarget and not aura then
            local alpha = 0.40 + 0.60 * math.abs(math.sin(GetTime() * 5))
            W:SetBorder(icon, RUI:GetTheme().accent, alpha)
            W:SetGlow(icon, RUI:GetTheme().accent, alpha * 0.45)
            icon.stackText:SetText("AP")
          elseif aura and aura.expires and aura.expires > 0 then
            local remain = math.max(0, aura.expires - GetTime())
            icon.cooldownText:SetText(W:FormatCooldown(remain))
            icon.cooldownText:SetTextColor(1, remain <= 3 and 0.25 or 0.95, remain <= 3 and 0.15 or 0.35, 1)
          end

        elseif definition.name == "Void-Enhanced Shield" and friendlyTarget and TargetAura("Wracked Mind", true) then
          W:SetIconInactive(icon, true)
          icon.stackText:SetText("LOCK")
          W:SetBorder(icon, {0.65, 0.20, 0.20, 1}, 1)

        elseif definition.name == "Presence of Y'Shaarj" then
          local active = PlayerAura("Presence of Y'Shaarj") ~= nil
          W:SetIconInactive(icon, active)
          if not active then
            local alpha = 0.40 + 0.60 * math.abs(math.sin(GetTime() * 5))
            W:SetBorder(icon, RUI:GetTheme().accent, alpha)
            W:SetGlow(icon, RUI:GetTheme().accent, alpha * 0.55)
            icon.stackText:SetText("ON")
          else
            W:SetBorder(icon, {0, 0, 0, 1}, 1)
          end

        elseif definition.name == "Horrifying Presence" then
          local aura = PlayerAura("Horrifying Presence")
          if aura then
            local remain = aura.expires and aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
            local alpha = 0.42 + 0.58 * math.abs(math.sin(GetTime() * 6))
            W:SetBorder(icon, RUI:GetTheme().accent2, alpha)
            W:SetGlow(icon, RUI:GetTheme().accent2, alpha * 0.60)
            if remain > 0 then
              icon.cooldownText:SetText(W:FormatCooldown(remain))
              icon.cooldownText:SetTextColor(1, 0.95, 0.35, 1)
            end
            icon.stackText:SetText("THREAT")
          end

        elseif definition.name == "Satiate" then
          local channel = ChannelInfo("Satiate")
          if channel then
            local danger = {1.00, 0.24, 0.10, 1}
            local alpha = 0.45 + 0.55 * math.abs(math.sin(GetTime() * 8))
            W:SetBorder(icon, danger, alpha)
            W:SetGlow(icon, danger, alpha * 0.75)
            icon.cooldownText:SetText(W:FormatCooldown(channel.remaining))
            icon.cooldownText:SetTextColor(1, 0.30, 0.15, 1)
            icon.stackText:SetText("+20%")
          end

        elseif definition.name == "Embrace the Void" and PlayerAura("Embrace the Void") then
          local alpha = 0.50 + 0.50 * math.abs(math.sin(GetTime() * 8))
          W:SetBorder(icon, RUI:GetTheme().accent2, alpha)
          W:SetGlow(icon, RUI:GetTheme().accent2, alpha * 0.70)
        end
      end
    end
  end
end

UpdateRows = function(insanity)
  W:UpdateSpellRow(root.coreRow, PlayerAura)
  W:UpdateSpellRow(root.utilityRow, PlayerAura)
  ApplyDecisionHighlights(insanity or select(1, ReadInsanity()))
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

local function HasDreadnoughtTalent()
  return TalentLearned("Dreadnought") or TalentLearned("Strength of the Black Empire")
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
  local value = select(1, ReadInsanity())
  value = math.max(0, math.min(100, tonumber(value) or 0))
  local color, pulse = InsanityColor(value, HasDreadnoughtTalent())
  color = color or {0.50, 0.12, 0.82, 1}

  root.insanityBar:SetMinMaxValues(0, 100)
  root.insanityBar:SetValue(value)
  root.insanityBar:SetStatusBarColor(color[1], color[2], color[3], 1)
  root.insanityBar.text:SetText(string.format("INSANITY  %d / 100", math.floor(value + 0.5)))

  if pulse then
    local alpha = 0.60 + 0.40 * math.abs(math.sin(GetTime() * pulse))
    root.insanityBar:SetAlpha(alpha)
  else
    root.insanityBar:SetAlpha(1)
  end
  return value
end

local function DreadnoughtDefinition()
  for _, definition in ipairs(RUI:GetClassSpellRecords(CLASS_NAME) or {}) do
    if definition.name == "Dreadnought" and definition.category == "form" then return definition end
  end
  return {name="Dreadnought", id=567548, aliases={"Void Monstrosity"}}
end

local function UpdateDreadnoughtTracker(insanity)
  local definition = DreadnoughtDefinition()
  local name, texture = ActiveCultistForm()
  local aura = name and PlayerAura(name) or PlayerAura("Dreadnought")
  local fallback = DefinitionTexture(definition) or StrictTexture(definition)

  if aura or name then
    local remain = aura and aura.expires and aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
    local value = remain > 0 and W:FormatCooldown(remain) or "ACTIVE"
    local pulse = remain > 0 and remain <= 3 and 10 or 5
    W:SetCounter(root.dreadnought, aura and aura.icon or texture or fallback, value, true, RUI:GetTheme().accent2, pulse)
    local alpha = 0.42 + 0.58 * math.abs(math.sin(GetTime() * pulse))
    W:SetGlow(root.dreadnought.icon, RUI:GetTheme().accent2, alpha * 0.75)
    return
  end

  local startTime, duration, enabled = W:ReadSpellCooldown(definition)
  local remaining = duration > 0 and math.max(0, startTime + duration - GetTime()) or 0
  local ready = enabled ~= 0 and (duration <= 1.5 or remaining <= 0.05)
  if ready and insanity >= 80 then
    local alpha = 0.42 + 0.58 * math.abs(math.sin(GetTime() * 6))
    W:SetCounter(root.dreadnought, fallback, "READY", true, RUI:GetTheme().accent2, nil)
    W:SetBorder(root.dreadnought.icon, RUI:GetTheme().accent2, alpha)
    W:SetGlow(root.dreadnought.icon, RUI:GetTheme().accent2, alpha * 0.75)
  elseif not ready and remaining > 0 then
    W:SetCounter(root.dreadnought, fallback, W:FormatCooldown(remaining), true, {0.52, 0.52, 0.58, 1}, nil)
    W:SetGlow(root.dreadnought.icon, nil, 0)
  else
    root.dreadnought:Hide()
    W:SetGlow(root.dreadnought.icon, nil, 0)
  end
end

local function UpdateTotalMadness()
  local aura = Aura("player", "Total Madness", false) or Aura("player", "Total Madness", true)
  local inactiveColor = {0.52, 0.52, 0.58, 1}

  if not aura then
    W:SetCounter(root.totalMadness, root.totalMadness.fallback, "", false, inactiveColor, nil)
    W:SetGlow(root.totalMadness.icon, nil, 0)
    return
  end

  local remain = aura.expires and aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
  local stacks = tonumber(aura.count) or 0
  local value = remain > 0 and W:FormatCooldown(remain) or "ACTIVE"
  if stacks > 1 then value = value .. "  " .. tostring(stacks) end
  local color = {1.00, 0.08, 0.64, 1}
  local speed = remain > 0 and remain <= 2 and 10 or 6
  W:SetCounter(root.totalMadness, aura.icon or root.totalMadness.fallback, value, true, color, speed)
  local alpha = 0.42 + 0.58 * math.abs(math.sin(GetTime() * speed))
  W:SetGlow(root.totalMadness.icon, color, alpha * 0.85)
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
    local aura
    if definition.name == "Tentacle of Yogg-Saron" then
      aura = TentacleAura()
    else
      aura = PlayerAura(name)
    end

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
    local definition = tracker.definition or {}
    tracker:ClearAllPoints()
    tracker:SetPoint("CENTER", UIParent, "CENTER",
      (layout.x or 0) - total / 2 + size / 2 + (index - 1) * (size + spacing), y)
    tracker.texture:SetTexture(aura.icon or DefinitionTexture(definition))
    tracker:SetAlpha(1)

    local count = tonumber(aura.count) or 0
    if definition.name == "Abyssal Ward" and count > 0 then
      tracker.stackText:SetText(tostring(count))
    else
      tracker.stackText:SetText(count > 1 and tostring(count) or "")
    end

    local remain = 0
    if aura.expires and aura.expires > 0 then
      remain = math.max(0, aura.expires - GetTime())
      tracker.cooldownText:SetText(W:FormatCooldown(remain))
      tracker.cooldownText:SetTextColor(1, remain <= 3 and 0.25 or 0.95, remain <= 3 and 0.15 or 0.35, 1)
    else
      tracker.cooldownText:SetText("")
    end

    local alpha = 1
    if definition.name == "Embrace the Void" then
      alpha = 0.45 + 0.55 * math.abs(math.sin(GetTime() * 8))
    elseif definition.name == "Abyssal Ward" and remain > 0 and remain <= 3 then
      alpha = 0.45 + 0.55 * math.abs(math.sin(GetTime() * 7))
    end
    W:SetBorder(tracker, RUI:GetTheme().accent2, alpha)
    tracker:Show()
  end
end

local function UpdateAll()
  if not root then return end
  local insanity = UpdateInsanity()
  UpdateDreadnoughtTracker(insanity)
  UpdateTotalMadness()
  UpdateRows(insanity)
  UpdateAuraTrackers()
end

local function Build()
  if root then return end
  root = CreateFrame("Frame", "RetreatUICultistHUD", UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("MEDIUM")


  local framework = RUI:GetTankMechanicLayout()
  local left = framework.build or {x = -105, y = -96}
  local right = framework.core or {x = 105, y = -96}
  local state = framework.state or {x = -167, y = -96}

  root.insanityBar = CreateFrame("StatusBar", "RetreatUICultistInsanityBar", root)
  root.insanityBar:SetSize((RUI.layout.power and RUI.layout.power.width) or 360, 10)
  root.insanityBar:SetPoint("CENTER", UIParent, "CENTER", 0, -132)
  root.insanityBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  root.insanityBar:SetMinMaxValues(0, 100)
  root.insanityBar:SetValue(0)
  RUI:SkinFrame(root.insanityBar, {0.018,0.018,0.022,0.96}, {0,0,0,1})
  root.insanityBar.text = root.insanityBar:CreateFontString(nil, "OVERLAY")
  root.insanityBar.text:SetPoint("CENTER")
  RUI:ApplyFont(root.insanityBar.text, 8, "OUTLINE")
  root.insanityBar.text:SetText("INSANITY  0 / 100")
  root.insanityBar:Show()
  root.dreadnought = W:CreateCounter(root, {
    label = "DREADNOUGHT",
    key = "dreadnought",
    fallback = ResolveTexture("Dreadnought", {"Void Monstrosity", "Strength of the Black Empire"}, 567548),
    x = left.x,
    y = left.y + 22,
    width = 108,
    size = 38,
    height = 70,
    hideWhenInactive = true,
  })
  root.totalMadness = W:CreateCounter(root, {
    label = "TOTAL MADNESS",
    key = "totalMadness",
    fallback = ResolveTexture("Total Madness"),
    x = right.x,
    y = right.y,
    width = 118,
    size = 38,
    height = 70,
  })

  root.coreRow = CreateFrame("Frame", nil, root)
  root.coreRow:SetSize(520, 38)
  root.coreRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.core.x, RUI.layout.core.y)

  root.utilityRow = CreateFrame("Frame", nil, root)
  root.utilityRow:SetSize(520, 32)
  root.utilityRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.utility.x, RUI.layout.utility.y)
  BuildRows()

  root.trackers = {}
  local allowedTrackers = {
    ["Void-Enhanced Shield"] = true,
    ["Abyssal Ward"] = true,
    ["Embrace the Void"] = true,
    ["Tentacle of Yogg-Saron"] = true,
    ["Armageddon"] = true,
    ["Doomcloak"] = true,
    ["Bulwark of Shadow"] = true,
    ["Eldritch Bastion"] = true,
    ["Voidwarding"] = true,
    ["Twisted Seal"] = true,
  }
  for _, definition in ipairs(RUI:GetAuraTrackerDefinitions(CLASS_NAME) or {}) do
    if allowedTrackers[definition.name] then
      root.trackers[#root.trackers + 1] = CreateAuraTracker(definition)
    end
  end

  driver = CreateFrame("Frame")
  for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED",
    "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "ACTIONBAR_UPDATE_COOLDOWN",
    "UNIT_POWER", "UNIT_POWER_FREQUENT", "UNIT_DISPLAYPOWER",
    "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS",
  }) do
    pcall(driver.RegisterEvent, driver, event)
  end

  driver:SetScript("OnEvent", function(_, event, ...)
    if not root or not root:IsShown() then return end
    local unit = select(1, ...)
    if event == "UNIT_AURA" and unit ~= "player" then return end

    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and CastMatchesTentacle(select(2, ...)) then
      tentacleExpires = GetTime() + 30
      local texture
      for index = 2, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "number" and GetSpellInfo then
          local name, _, icon = GetSpellInfo(value)
          if name and CastMatchesTentacle(name) then texture = icon break end
        end
      end
      tentacleTexture = texture or ResolveTexture("Tentacle of Yogg-Saron", AURA_ALIASES["Tentacle of Yogg-Saron"])
    end

    if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" or event == "CHARACTER_POINTS_CHANGED" then
      RUI:After(0.15, function()
        if RUI.ScanSpellbook then RUI:ScanSpellbook() end
        if RUI.InvalidateRacialCache then RUI:InvalidateRacialCache() end
        BuildRows(true)
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

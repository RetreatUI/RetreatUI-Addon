local RUI = RetreatUI
local CLASS_NAME = "Knight of Xoroth"
local module = {
  ready = true,
  className = CLASS_NAME,
  frameName = "RetreatUIKnightOfXorothHUD",
  supportedLoadouts = {TANK=true},
  usesPrimaryPower = true,
}

local root, driver, timerDriver, demonfireDriver
local icons = {}
local targetAuraBars = {}
local impGUIDs = {}
local timerElapsed = 0
local impTimerElapsed = 0
local demonfireElapsed = 0
local hasCooldownTimers = false
local hasAuraTimers = false
local hasTargetTimers = false
local spellRefreshPending = false
local lastImpcallerState
local lastDemonfireStacks

local STANCE_DEFINITIONS = {
  ["pestilence of war"] = {
    name = "Pestilence of War",
    effect = "Leech",
    fallback = "Interface\\Icons\\Spell_Shadow_VampiricAura",
  },
  ["pestilence of conquest"] = {
    name = "Pestilence of Conquest",
    effect = "Silence",
    fallback = "Interface\\Icons\\Spell_Holy_Silence",
  },
  ["pestilence of famine"] = {
    name = "Pestilence of Famine",
    effect = "Slow",
    fallback = "Interface\\Icons\\Spell_Frost_FrostShock",
  },
}

local function HasImpcaller()
  if RUI:IsSpellLearned("Impcaller") then return true end
  if IsSpellKnown then
    local ok, known = pcall(IsSpellKnown, 706755)
    if ok and known then return true end
  end
  return RUI.IsSpellIDLearned and RUI:IsSpellIDLearned(706755) or false
end

local function CoreDefinitions()
  return RUI:GetHUDSpellDefinitions(CLASS_NAME, "core")
end

local function UtilityDefinitions(forceRacialScan)
  local definitions, seen = {}, {}
  for _, definition in ipairs(RUI:GetHUDSpellDefinitions(CLASS_NAME, "utility")) do
    definitions[#definitions + 1] = definition
    seen[string.lower(definition.name or "")] = true
  end

  if RUI.GetRacialSpellDefinitions then
    for _, racial in ipairs(RUI:GetRacialSpellDefinitions(forceRacialScan)) do
      local key = string.lower(racial.name or "")
      if key ~= "" and not seen[key] then
        racial.category = racial.category or "racial"
        racial.trackCooldown = true
        definitions[#definitions + 1] = racial
        seen[key] = true
      end
    end
  end
  return definitions
end

local function TargetDebuffDefinitions()
  return RUI:GetTargetDebuffDefinitions(CLASS_NAME)
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
        index = index,
        raw = values,
      }
    end
  end
  return nil
end

local function CreateBorder(frame)
  local border = CreateFrame("Frame", nil, frame)
  border:SetPoint("TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", 1, -1)
  RUI:SkinFrame(border, {0,0,0,0}, {0,0,0,1})
  frame.border = border
  return border
end

local function CreateIcon(parent, size)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(size, size)
  frame.texture = frame:CreateTexture(nil, "BACKGROUND")
  frame.texture:SetPoint("TOPLEFT", 1, -1)
  frame.texture:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.texture:SetTexCoord(0.08,0.92,0.08,0.92)
  CreateBorder(frame)

  frame.cooldownShade = frame:CreateTexture(nil, "ARTWORK")
  frame.cooldownShade:SetPoint("TOPLEFT", frame.texture, "TOPLEFT", 0, 0)
  frame.cooldownShade:SetPoint("BOTTOMRIGHT", frame.texture, "BOTTOMRIGHT", 0, 0)
  frame.cooldownShade:SetTexture("Interface\\Buttons\\WHITE8X8")
  frame.cooldownShade:SetVertexColor(0, 0, 0, 0.58)
  frame.cooldownShade:Hide()

  frame.cooldownText = frame:CreateFontString(nil, "OVERLAY")
  frame.cooldownText:SetPoint("CENTER")
  frame.cooldownText:SetTextColor(1, 0.95, 0.35, 1)
  if frame.cooldownText.SetShadowOffset then frame.cooldownText:SetShadowOffset(1, -1) end
  RUI:ApplyFont(frame.cooldownText, math.max(11, math.floor(size*0.38)), "OUTLINE")

  frame.stackText = frame:CreateFontString(nil, "OVERLAY")
  frame.stackText:SetPoint("BOTTOMRIGHT", -2, 2)
  RUI:ApplyFont(frame.stackText, math.max(9, math.floor(size*0.28)), "OUTLINE")
  frame:Hide()
  return frame
end

local function SetBorder(frame, active)
  if not frame or not frame.border then return end
  local theme = RUI:GetTheme()
  if active then
    frame.border:SetBackdropBorderColor(theme.accent2[1],theme.accent2[2],theme.accent2[3],1)
  else
    frame.border:SetBackdropBorderColor(0,0,0,1)
  end
end

local function EnsureSpellIcon(row, index, size)
  row.icons = row.icons or {}
  if not row.icons[index] then row.icons[index] = CreateIcon(row, size) end
  return row.icons[index]
end

local function DefinitionLearned(definition)
  return RUI:IsSpellRecordLearned(definition)
end

local function DefinitionTexture(definition)
  return RUI:GetSpellRecordTexture(definition)
end

local function BuildRow(row, definitions, size, spacing)
  local visible = {}
  for _, definition in ipairs(definitions) do
    local allowed = true
    if type(definition.show) == "function" then
      local ok, result = pcall(definition.show)
      allowed = ok and result ~= false
    end
    if allowed and DefinitionLearned(definition) then
      table.insert(visible, definition)
    end
  end
  local count = #visible
  local total = count > 0 and (count*size + (count-1)*spacing) or 0
  for index, definition in ipairs(visible) do
    local frame = EnsureSpellIcon(row, index, size)
    frame.definition = definition
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", row, "CENTER", -total/2 + size/2 + (index-1)*(size+spacing), 0)
    frame.texture:SetTexture(DefinitionTexture(definition))
    frame:Show()
  end
  for index = count+1, #(row.icons or {}) do row.icons[index]:Hide() end
end

local function ReadSpellCooldown(definition)
  if not GetSpellCooldown then return 0, 0, 0 end

  local spellName = definition.name

  -- Resolve through the learned spellbook entry first. Some Ascension
  -- Character Advancement IDs are not the same record as the castable spell.
  local bookIndex = RUI.GetSpellRecordBookIndex and RUI:GetSpellRecordBookIndex(definition)
  if not bookIndex and RUI.GetSpellBookIndex then
    bookIndex = RUI:GetSpellBookIndex(spellName)
  end
  if bookIndex then
    local ok, start, duration, enabled = pcall(GetSpellCooldown, bookIndex, BOOKTYPE_SPELL or "spell")
    if ok and start ~= nil and duration ~= nil then
      return tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
    end
  end

  local runtimeID = RUI.GetSpellRecordRuntimeID and RUI:GetSpellRecordRuntimeID(definition)
  if runtimeID then
    local ok, start, duration, enabled = pcall(GetSpellCooldown, runtimeID)
    if ok and start ~= nil and duration ~= nil then
      return tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
    end
  end

  local ok, start, duration, enabled = pcall(GetSpellCooldown, spellName)
  if ok and start ~= nil and duration ~= nil then
    return tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
  end

  -- Final fallback to the supplied catalogue ID.
  if definition.id and definition.id ~= runtimeID then
    local idOK, start, duration, enabled = pcall(GetSpellCooldown, definition.id)
    if idOK and start ~= nil and duration ~= nil then
      return tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
    end
  end

  return 0, 0, 0
end

local function ReadSpellCharges(definition)
  if not GetSpellCharges or type(definition) ~= "table" then return nil end

  local candidates, seen = {}, {}
  local function AddCandidate(value)
    if value == nil then return end
    local key = tostring(value)
    if seen[key] then return end
    seen[key] = true
    candidates[#candidates + 1] = value
  end

  AddCandidate(RUI.GetSpellRecordRuntimeID and RUI:GetSpellRecordRuntimeID(definition))
  AddCandidate(definition.id)
  AddCandidate(definition.name)
  for _, alias in ipairs(definition.aliases or {}) do AddCandidate(alias) end

  for _, candidate in ipairs(candidates) do
    local ok, current, maximum, start, duration = pcall(GetSpellCharges, candidate)
    current, maximum = tonumber(current), tonumber(maximum)
    if ok and current and maximum and maximum > 0 then
      return current, maximum, tonumber(start) or 0, tonumber(duration) or 0
    end
  end
  return nil
end

local function FormatCooldown(remaining)
  remaining = tonumber(remaining) or 0
  if remaining <= 0.05 then return "" end
  if remaining >= 3600 then return tostring(math.ceil(remaining / 3600)) .. "h" end
  if remaining >= 60 then return tostring(math.ceil(remaining / 60)) .. "m" end
  if remaining >= 10 then return tostring(math.ceil(remaining)) end
  return string.format("%.1f", remaining)
end

local function SetCooldownDisplay(frame, remaining, active)
  if not frame then return end
  if active then
    if frame.cooldownShade then frame.cooldownShade:Show() end
    if frame.cooldownText then
      frame.cooldownText:SetText(FormatCooldown(remaining))
      if remaining <= 3 then
        frame.cooldownText:SetTextColor(1, 0.25, 0.15, 1)
      else
        frame.cooldownText:SetTextColor(1, 0.95, 0.35, 1)
      end
    end
  else
    if frame.cooldownShade then frame.cooldownShade:Hide() end
    if frame.cooldownText then frame.cooldownText:SetText("") end
  end
end

local function UpdateSpellRow(row, cooldownOnly, auraState)
  local activeCooldown = false
  for _, frame in ipairs(row.icons or {}) do
    if frame:IsShown() and frame.definition then
      local definition = frame.definition
      local chargeCurrent, chargeMaximum, chargeStart, chargeDuration
      if definition.trackCharges then
        chargeCurrent, chargeMaximum, chargeStart, chargeDuration = ReadSpellCharges(definition)
      end

      if chargeCurrent and chargeMaximum then
        local rechargeRemaining = chargeDuration > 0 and math.max(0, chargeStart + chargeDuration - GetTime()) or 0
        local recharging = chargeCurrent < chargeMaximum and rechargeRemaining > 0.05
        SetCooldownDisplay(frame, rechargeRemaining, recharging)
        if frame.texture.SetDesaturated then frame.texture:SetDesaturated(chargeCurrent <= 0) end
        frame.stackText:SetText(string.format("%d/%d", chargeCurrent, chargeMaximum))
        if recharging then activeCooldown = true end
      else
        local start, duration, enabled = ReadSpellCooldown(definition)
        local remaining = duration > 0 and math.max(0, start + duration - GetTime()) or 0
        local onCooldown = duration > 1.5 and remaining > 0.05 and enabled ~= 0
        SetCooldownDisplay(frame, remaining, onCooldown)
        if frame.texture.SetDesaturated then frame.texture:SetDesaturated(onCooldown) end
        if onCooldown then activeCooldown = true end
      end

      -- Buff borders/stacks only need an aura event refresh. Do not rescan all
      -- player auras for every countdown tick.
      if not cooldownOnly then
        local buff
        if definition.buff then
          buff = auraState and (auraState.byName[definition.buff] or auraState.byLower[string.lower(definition.buff)])
            or Aura("player", definition.buff, false)
        end
        SetBorder(frame, buff ~= nil)
        if not (chargeCurrent and chargeMaximum) then
          frame.stackText:SetText(buff and buff.count and buff.count > 1 and tostring(buff.count) or "")
        end
      end
    end
  end
  return activeCooldown
end

local function CreateCounter(name, spellName, fallback, x, y)
  local frame = CreateIcon(root, 38)
  frame:SetPoint("CENTER", UIParent, "CENTER", x, y or RUI.layout.custom.y)
  frame.counterName = name
  local _, _, texture = GetSpellInfo(spellName)
  frame.texture:SetTexture(texture or fallback)
  if frame.cooldownShade then frame.cooldownShade:Hide() end
  frame.cooldownText:SetText("0")
  frame.cooldownText:SetTextColor(1, 1, 1, 1)
  RUI:ApplyFont(frame.cooldownText, 17, "OUTLINE")
  frame:Show()
  return frame
end

local function AuraCounter(match)
  local total = 0
  for index=1,40 do
    local name, _, _, count = UnitBuff("player", index)
    if not name then break end
    if match(string.lower(name)) then total = total + ((count and count > 0) and count or 1) end
  end
  return total
end

local function CollectPlayerAuraState()
  local state = {byName = {}, byLower = {}, byID = {}, list = {}, imp = 0, blood = 0, demonfire = 0}
  if not UnitBuff then return state end

  for index = 1, 40 do
    local values = {UnitBuff("player", index)}
    local name = values[1]
    if not name then break end
    local lower = string.lower(name)
    local aura = {
      name = name,
      icon = values[3],
      count = values[4] or 0,
      duration = values[6] or 0,
      expires = values[7] or 0,
      caster = values[8],
      spellID = values[11],
      index = index,
      raw = values,
    }
    state.list[#state.list + 1] = aura
    state.byName[name] = aura
    state.byLower[lower] = aura
    if aura.spellID then state.byID[tonumber(aura.spellID)] = aura end

    local amount = aura.count and aura.count > 0 and aura.count or 1
    if lower:find("hellfire imp", 1, true) or lower:find("impcaller", 1, true) then
      state.imp = state.imp + amount
    end
    if lower:find("demon's blood", 1, true) then state.blood = state.blood + amount end
    if lower:find("demonfire", 1, true) then
      state.demonfire = aura.count and aura.count > 0 and aura.count or 1
    end
  end
  return state
end

local function CombatImpCount()
  local now = GetTime()
  local count = 0
  for guid, expires in pairs(impGUIDs) do
    if expires <= now then impGUIDs[guid] = nil else count = count + 1 end
  end
  return count
end

local function ProcessCombatLog()
  if not CombatLogGetCurrentEventInfo then return false end
  local _, subevent, _, sourceGUID, _, _, _, destGUID, destName, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
  if subevent == "SPELL_SUMMON" and sourceGUID == UnitGUID("player") then
    local destination = string.lower(destName or "")
    local spell = string.lower(spellName or "")
    if destination:find("hellfire imp",1,true) or spell:find("hellfire imp",1,true) or spell:find("impcaller",1,true) then
      impGUIDs[destGUID or tostring(spellID)..":"..tostring(GetTime())] = GetTime()+60
      return true
    end
  elseif (subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" or subevent == "SPELL_INSTAKILL") and destGUID then
    if impGUIDs[destGUID] then
      impGUIDs[destGUID] = nil
      return true
    end
  end
  return false
end

local absorbTooltip
local absorbCache = {time=0, expires=0, value=nil, source=nil}

local function FormatAmount(value)
  value = tonumber(value)
  if not value or value <= 0 then return "" end
  if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
  if value >= 1000 then return string.format("%.1fk", value / 1000) end
  return tostring(math.floor(value + 0.5))
end

local function ParseLargestNumber(text)
  if type(text) ~= "string" then return nil end
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local largest
  for token, suffix in text:gmatch("(%d[%d,%.]*)%s*([kKmM]?)") do
    local normalized = token:gsub(",", "")
    local value = tonumber(normalized)
    if value then
      suffix = string.lower(suffix or "")
      if suffix == "k" then value = value * 1000 end
      if suffix == "m" then value = value * 1000000 end
      if not largest or value > largest then largest = value end
    end
  end
  return largest
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

local function ReadTotalAbsorb()
  if type(UnitGetTotalAbsorbs) ~= "function" then return nil end
  local ok, value = pcall(UnitGetTotalAbsorbs, "player")
  value = ok and tonumber(value) or nil
  if value and value > 0 then return value end
  return nil
end

local function EnsureAbsorbTooltip()
  if absorbTooltip then return absorbTooltip end
  absorbTooltip = CreateFrame("GameTooltip", "RetreatUIBlackShieldTooltip", UIParent, "GameTooltipTemplate")
  absorbTooltip:SetOwner(UIParent, "ANCHOR_NONE")
  return absorbTooltip
end

local function ReadTooltipLines(aura, useAuraMethod)
  local tooltip = EnsureAbsorbTooltip()
  tooltip:ClearLines()
  tooltip:SetOwner(UIParent, "ANCHOR_NONE")

  local ok = false
  if useAuraMethod and type(tooltip.SetUnitAura) == "function" then
    ok = pcall(tooltip.SetUnitAura, tooltip, "player", aura.index, "HELPFUL")
  elseif type(tooltip.SetUnitBuff) == "function" then
    ok = pcall(tooltip.SetUnitBuff, tooltip, "player", aura.index)
  end
  if not ok then
    tooltip:Hide()
    return nil, nil
  end

  tooltip:Show()
  local tooltipName = tooltip:GetName()
  local lines = tooltip:NumLines() or 0
  local keywordValue, fallbackValue
  local collected = {}

  for index = 1, lines do
    local left = _G[tooltipName .. "TextLeft" .. index]
    local right = _G[tooltipName .. "TextRight" .. index]
    local texts = {left and left:GetText(), right and right:GetText()}
    for _, line in ipairs(texts) do
      if line and line ~= "" then
        collected[#collected + 1] = line
        local lower = string.lower(line)
        local candidate = ParseLargestNumber(line)
        if candidate and candidate > 1 then
          local durationText = lower:find(" sec", 1, true)
            or lower:find(" second", 1, true)
            or lower:find(" min", 1, true)
            or lower:find(" minute", 1, true)
          if not durationText and (not fallbackValue or candidate > fallbackValue) then
            fallbackValue = candidate
          end
          if lower:find("absorb", 1, true)
            or lower:find("shield", 1, true)
            or lower:find("damage remaining", 1, true)
            or lower:find("damage absorbed", 1, true) then
            if not keywordValue or candidate > keywordValue then keywordValue = candidate end
          end
        end
      end
    end
  end

  tooltip:Hide()
  return keywordValue or fallbackValue, collected
end

local function ReadTooltipAbsorb(aura)
  local value, lines = ReadTooltipLines(aura, false)
  if value then return value, "unit-buff", lines end
  local fallbackLines = lines
  value, lines = ReadTooltipLines(aura, true)
  if value then return value, "unit-aura", lines end
  return nil, nil, lines or fallbackLines
end

local function ReadBlackShieldAbsorb(aura, force)
  if not aura or not aura.index then return nil end
  local now = GetTime()
  if not force and absorbCache.expires == aura.expires and now - absorbCache.time < 0.20 then
    return absorbCache.value
  end

  local value = AuraAbsorbValue(aura)
  local source = value and "aura-value" or nil

  if not value then
    value = ReadTotalAbsorb()
    source = value and "unit-total" or nil
  end

  if not value then
    value, source = ReadTooltipAbsorb(aura)
  end

  absorbCache.time = now
  absorbCache.expires = aura.expires
  absorbCache.value = value
  absorbCache.source = source
  return value
end

local function CreateAuraTracker(auraName, fallback)
  local layout = RUI.layout.auraTrackers
  local frame = CreateIcon(root, layout.size or 30)
  frame.auraName = auraName
  frame.fallback = fallback
  frame.cooldownText:ClearAllPoints()
  frame.cooldownText:SetPoint("TOP", frame, "TOP", 0, -2)
  RUI:ApplyFont(frame.cooldownText, 9, "OUTLINE")
  frame.valueText = frame:CreateFontString(nil, "OVERLAY")
  frame.valueText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
  frame.valueText:SetTextColor(1, 1, 1, 1)
  RUI:ApplyFont(frame.valueText, 9, "OUTLINE")
  frame.stackText:ClearAllPoints()
  frame.stackText:SetPoint("TOPRIGHT", -2, -2)
  frame:Hide()
  return frame
end

local function UpdateAuraTrackers(auraState)
  local active = {}
  for _, frame in ipairs(root.auraTrackers or {}) do
    local definition = frame.definition or {}
    local aura = auraState and (
        (definition.id and auraState.byID and auraState.byID[tonumber(definition.id)])
        or auraState.byName[frame.auraName]
        or auraState.byLower[string.lower(frame.auraName)]
      )
      or Aura("player", frame.auraName, false)
    if aura and aura.expires and aura.expires > 0 then
      frame.aura = aura
      active[#active + 1] = frame
    else
      frame.aura = nil
      frame:Hide()
    end
  end

  local layout = RUI.layout.auraTrackers
  local size = layout.size or 30
  local spacing = layout.spacing or 3
  local total = #active > 0 and (#active * size + (#active - 1) * spacing) or 0

  for index, frame in ipairs(active) do
    local aura = frame.aura
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER",
      (layout.x or 0) - total / 2 + size / 2 + (index - 1) * (size + spacing),
      layout.y or -83)
    frame.texture:SetTexture(aura.icon or select(3, GetSpellInfo(frame.auraName)) or frame.fallback)
    if frame.texture.SetDesaturated then frame.texture:SetDesaturated(false) end
    if frame.cooldownShade then frame.cooldownShade:Hide() end
    local remaining = math.max(0, (aura.expires or 0) - GetTime())
    frame.cooldownText:SetText(FormatCooldown(remaining))
    frame.cooldownText:SetTextColor(1, 0.95, 0.35, 1)
    frame.stackText:SetText(aura.count and aura.count > 1 and tostring(aura.count) or "")
    if frame.auraName == "Black Shield" then
      frame.valueText:SetText(FormatAmount(ReadBlackShieldAbsorb(aura)))
    else
      frame.valueText:SetText("")
    end
    SetBorder(frame, true)
    frame:Show()
  end
  return #active > 0
end

local function UpdateAuraTrackerTimers()
  local active = false
  for _, frame in ipairs(root.auraTrackers or {}) do
    local aura = frame.aura
    if frame:IsShown() and aura and aura.expires and aura.expires > 0 then
      local remaining = math.max(0, aura.expires - GetTime())
      if remaining > 0.05 then
        active = true
        frame.cooldownText:SetText(FormatCooldown(remaining))
        if frame.auraName == "Black Shield" then
          frame.valueText:SetText(FormatAmount(ReadBlackShieldAbsorb(aura)))
        end
      else
        frame:Hide()
        frame.aura = nil
      end
    end
  end
  return active
end

local function StanceDefinition(name)
  if type(name) ~= "string" or name == "" then return nil end
  local lower = string.lower(name)
  if STANCE_DEFINITIONS[lower] then return STANCE_DEFINITIONS[lower] end
  for key, definition in pairs(STANCE_DEFINITIONS) do
    if string.find(lower, key, 1, true) then return definition end
  end
  return nil
end

local function ActivePestilenceStance(auraState)
  local currentForm = 0
  if type(GetShapeshiftForm) == "function" then
    local ok, value = pcall(GetShapeshiftForm)
    if ok then currentForm = tonumber(value) or 0 end
  end

  if type(GetNumShapeshiftForms) == "function" and type(GetShapeshiftFormInfo) == "function" then
    local okCount, count = pcall(GetNumShapeshiftForms)
    count = okCount and tonumber(count) or 0
    for index = 1, count do
      local ok, texture, name, active = pcall(GetShapeshiftFormInfo, index)
      if ok then
        local definition = StanceDefinition(name)
        if not definition then definition = StanceDefinition(texture) end
        local isActive = active == true or active == 1 or index == currentForm
        if definition and isActive then
          return definition, texture, name or definition.name
        end
      end
    end
  end

  -- Ascension builds can expose stances as persistent player buffs instead of
  -- standard shapeshift forms, so keep this fallback for all three Pestilences.
  if auraState and auraState.list then
    for _, aura in ipairs(auraState.list) do
      local definition = StanceDefinition(aura.name)
      if definition then return definition, aura.icon, aura.name end
    end
  elseif type(UnitBuff) == "function" then
    for index = 1, 40 do
      local name, _, texture = UnitBuff("player", index)
      if not name then break end
      local definition = StanceDefinition(name)
      if definition then return definition, texture, name end
    end
  end

  return nil
end

local function CreateStanceTracker()
  local layout = RUI.layout.stanceTracker or {size=38, gap=6}
  local frame = CreateIcon(root, layout.size or 38)
  frame:ClearAllPoints()
  if root.imp then
    frame:SetPoint("RIGHT", root.imp, "LEFT", -(layout.gap or 6), 0)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", -150, -118)
  end
  if frame.cooldownShade then frame.cooldownShade:Hide() end
  frame.cooldownText:SetText("")
  frame.stackText:SetText("")

  frame.effectText = frame:CreateFontString(nil, "OVERLAY")
  -- The effect belongs above the icon. This keeps Leech, Silence and Slow
  -- readable without colliding with the Rage bar below the resource cluster.
  frame.effectText:SetPoint("BOTTOM", frame, "TOP", 0, 3)
  frame.effectText:SetTextColor(1, 1, 1, 1)
  RUI:ApplyFont(frame.effectText, 9, "OUTLINE")

  frame:EnableMouse(false)
  frame:Hide()
  root.stanceTracker = frame
end

local function UpdateStanceTracker(auraState)
  local frame = root and root.stanceTracker
  if not frame then return end

  local definition, texture, stanceName = ActivePestilenceStance(auraState)
  if not definition then
    frame.stanceName = nil
    frame.effectText:SetText("")
    frame:Hide()
    return
  end

  local spellTexture = select(3, GetSpellInfo(definition.name))
  frame.texture:SetTexture(texture or spellTexture or definition.fallback)
  if frame.texture.SetDesaturated then frame.texture:SetDesaturated(false) end
  if frame.cooldownShade then frame.cooldownShade:Hide() end
  frame.cooldownText:SetText("")
  frame.stackText:SetText("")
  frame.effectText:SetText(definition.effect)
  frame.stanceName = stanceName or definition.name
  SetBorder(frame, true)
  frame:Show()
end

local function CreateDemonfire()
  root.demonfire = root.demonfire or {}
  for i=1,6 do
    local icon = CreateIcon(root,25)
    icon:SetPoint("CENTER", UIParent, "CENTER", (i-3.5)*25, RUI.layout.demonfire.y)
    local _,_,texture = GetSpellInfo("Hellfire Bellows")
    icon.texture:SetTexture(texture or "Interface\\Icons\\Spell_Fire_Immolation")
    if icon.cooldownShade then icon.cooldownShade:Hide() end
    icon.cooldownText:SetText("")
    icon.stackText:SetText("")
    icon:Show()
    root.demonfire[i]=icon
  end
end

local function DemonfireStacks()
  for index=1,40 do
    local name,_,_,count=UnitBuff("player",index)
    if not name then break end
    if string.lower(name):find("demonfire",1,true) then
      count = tonumber(count) or 0
      return count > 0 and count or 1
    end
  end
  return 0
end

local function UpdateDemonfireDisplay(force, auraState)
  if not root or not root:IsShown() then return end
  local stacks = auraState and tonumber(auraState.demonfire) or DemonfireStacks()
  stacks = math.max(0, math.min(6, tonumber(stacks) or 0))
  if not force and stacks == lastDemonfireStacks then return end
  lastDemonfireStacks = stacks

  for index, icon in ipairs(root.demonfire or {}) do
    if icon.texture.SetDesaturated then icon.texture:SetDesaturated(index > stacks) end
    icon:SetAlpha(index <= stacks and 1 or 0.35)
  end
end

local function TargetFrameAnchor()
  return _G.ElvUF_Target or _G.TargetFrame or nil
end

local function TargetDebuffOrder()
  local byName, byID = {}, {}
  for _, definition in ipairs(TargetDebuffDefinitions()) do
    local order = tonumber(definition.order) or 999
    if definition.name then byName[string.lower(definition.name)] = order end
    if definition.id then byID[tonumber(definition.id)] = order end
  end
  return byName, byID
end

local function IsOwnDebuffCaster(caster)
  if caster == "player" or caster == "pet" or caster == "vehicle" then return true end
  local playerName = UnitName and UnitName("player")
  return playerName and caster == playerName or false
end

local function CollectOwnTargetDebuffs()
  local shown = {}
  if not UnitExists or not UnitExists("target") or not UnitDebuff then return shown end
  local byName, byID = TargetDebuffOrder()

  for index = 1, 40 do
    local values = {UnitDebuff("target", index)}
    local name = values[1]
    if not name then break end
    local caster = values[8]
    if IsOwnDebuffCaster(caster) then
      local spellID = tonumber(values[11])
      shown[#shown + 1] = {
        name = name,
        icon = values[3],
        count = tonumber(values[4]) or 0,
        debuffType = values[5],
        duration = tonumber(values[6]) or 0,
        expires = tonumber(values[7]) or 0,
        caster = caster,
        spellID = spellID,
        order = (spellID and byID[spellID]) or byName[string.lower(name)] or 999,
      }
    end
  end

  table.sort(shown, function(left, right)
    if left.order ~= right.order then return left.order < right.order end
    local leftExpires = left.expires > 0 and left.expires or math.huge
    local rightExpires = right.expires > 0 and right.expires or math.huge
    if leftExpires ~= rightExpires then return leftExpires < rightExpires end
    return tostring(left.name) < tostring(right.name)
  end)
  return shown
end

local function AuraBarTexture()
  if ElvUI then
    local E = unpack(ElvUI)
    if E and E.media and E.media.normTex then return E.media.normTex end
  end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function CreateTargetAuraBar(index)
  local bar = CreateFrame("StatusBar", "RetreatUITargetAuraBar" .. tostring(index), root)
  bar:SetHeight(16)
  bar:SetStatusBarTexture(AuraBarTexture())
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  RUI:SkinFrame(bar, {0.025, 0.018, 0.018, 0.96}, {0, 0, 0, 1})

  bar.icon = bar:CreateTexture(nil, "ARTWORK")
  bar.icon:SetSize(14, 14)
  bar.icon:SetPoint("LEFT", 1, 0)
  bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  bar.nameText = bar:CreateFontString(nil, "OVERLAY")
  bar.nameText:SetPoint("LEFT", bar.icon, "RIGHT", 4, 0)
  bar.nameText:SetPoint("RIGHT", bar, "RIGHT", -47, 0)
  bar.nameText:SetJustifyH("LEFT")
  RUI:ApplyFont(bar.nameText, 10, "OUTLINE")

  bar.timeText = bar:CreateFontString(nil, "OVERLAY")
  bar.timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
  bar.timeText:SetJustifyH("RIGHT")
  bar.timeText:SetTextColor(1, 0.95, 0.35, 1)
  RUI:ApplyFont(bar.timeText, 10, "OUTLINE")

  bar.stackText = bar:CreateFontString(nil, "OVERLAY")
  bar.stackText:SetPoint("BOTTOMRIGHT", bar.icon, "BOTTOMRIGHT", 0, 0)
  RUI:ApplyFont(bar.stackText, 8, "OUTLINE")
  bar:Hide()
  return bar
end

local function PositionTargetAuraBar(bar, index)
  local targetFrame = TargetFrameAnchor()
  local width = 260
  if targetFrame and targetFrame.GetWidth then
    local ok, measured = pcall(targetFrame.GetWidth, targetFrame)
    if ok and type(measured) == "number" and measured > 0 then width = measured end
  end
  if width < 190 then width = 190 end
  if width > 340 then width = 340 end
  bar:SetWidth(width)
  bar:ClearAllPoints()

  if targetFrame then
    bar:SetPoint("BOTTOMLEFT", targetFrame, "TOPLEFT", 0, 4 + (index - 1) * 18)
  else
    local fallback = RUI.layout.targetDebuffs or {x=310, y=-59}
    bar:SetPoint("BOTTOM", UIParent, "CENTER", fallback.x or 310, (fallback.y or -59) + 30 + (index - 1) * 18)
  end
end

local function UpdateTargetDebuffs()
  local shown = CollectOwnTargetDebuffs()
  local maximum = math.min(#shown, 7)
  local theme = RUI:GetTheme()
  local hasTimed = false

  for index = 1, maximum do
    local aura = shown[index]
    if not targetAuraBars[index] then targetAuraBars[index] = CreateTargetAuraBar(index) end
    local bar = targetAuraBars[index]
    bar.aura = aura
    PositionTargetAuraBar(bar, index)

    local remaining = aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
    if aura.expires > 0 then hasTimed = true end
    if aura.duration > 0 and aura.expires > 0 then
      bar:SetMinMaxValues(0, aura.duration)
      bar:SetValue(math.min(aura.duration, remaining))
    else
      bar:SetMinMaxValues(0, 1)
      bar:SetValue(1)
    end

    local urgency = aura.duration > 0 and remaining <= 5
    if urgency then
      bar:SetStatusBarColor(0.95, 0.18, 0.08, 0.95)
      bar.timeText:SetTextColor(1, 0.35, 0.18, 1)
    else
      bar:SetStatusBarColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.82)
      bar.timeText:SetTextColor(1, 0.95, 0.35, 1)
    end

    bar.icon:SetTexture(aura.icon or (aura.spellID and select(3, GetSpellInfo(aura.spellID))) or "Interface\\Icons\\INV_Misc_QuestionMark")
    bar.nameText:SetText(aura.name or "Debuff")
    bar.timeText:SetText(remaining > 0.05 and FormatCooldown(remaining) or "")
    bar.stackText:SetText(aura.count and aura.count > 1 and tostring(aura.count) or "")
    bar:Show()
  end

  for index = maximum + 1, #targetAuraBars do
    targetAuraBars[index].aura = nil
    targetAuraBars[index]:Hide()
  end
  return hasTimed
end

local function UpdateTargetDebuffTimers()
  local active = false
  for _, bar in ipairs(targetAuraBars) do
    local aura = bar.aura
    if bar:IsShown() and aura then
      local remaining = aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
      if aura.expires <= 0 then
        -- Permanent debuffs stay visible but do not keep the timer driver awake.
      elseif remaining > 0.05 then
        active = true
        if aura.duration > 0 then
          bar:SetValue(math.min(aura.duration, remaining))
          bar.timeText:SetText(FormatCooldown(remaining))
        end
      else
        bar.aura = nil
        bar:Hide()
      end
    end
  end
  return active
end

function RUI:RefreshTargetAuraBars()
  UpdateTargetDebuffs()
  return true, "Target aura bars refreshed"
end

local function UpdateImpCounter(auraState)
  if not root or not root.imp then return end
  local auraCount = auraState and auraState.imp
    or AuraCounter(function(name) return name:find("hellfire imp",1,true) or name:find("impcaller",1,true) end)
  local imp = math.max(auraCount or 0, CombatImpCount())
  root.imp.cooldownText:SetText(tostring(imp))
end

local function UpdatePlayerAuras()
  if not root or not root:IsShown() then return end
  local auraState = CollectPlayerAuraState()
  UpdateImpCounter(auraState)
  root.blood.cooldownText:SetText(tostring(auraState.blood or 0))
  UpdateDemonfireDisplay(false, auraState)
  UpdateStanceTracker(auraState)
  hasAuraTimers = UpdateAuraTrackers(auraState)
  local coreActive = UpdateSpellRow(root.coreRow, false, auraState)
  local utilityActive = UpdateSpellRow(root.utilityRow, false, auraState)
  hasCooldownTimers = coreActive or utilityActive
end

local function UpdateCooldowns(cooldownOnly)
  if not root or not root:IsShown() then return false end
  local coreActive = UpdateSpellRow(root.coreRow, cooldownOnly)
  local utilityActive = UpdateSpellRow(root.utilityRow, cooldownOnly)
  hasCooldownTimers = coreActive or utilityActive
  return hasCooldownTimers
end

local function UpdateTargetState()
  if not root or not root:IsShown() then return end
  hasTargetTimers = UpdateTargetDebuffs()
end

local function TimersNeeded()
  return hasCooldownTimers or hasAuraTimers or hasTargetTimers or next(impGUIDs) ~= nil
end

local function RefreshTimerDriver()
  if not timerDriver then return end
  if root and root:IsShown() and TimersNeeded() then timerDriver:Show() else timerDriver:Hide() end
end

local function UpdateAll()
  if not root or not root:IsShown() then return end

  local impcallerState = HasImpcaller()
  if lastImpcallerState == nil or lastImpcallerState ~= impcallerState then
    lastImpcallerState = impcallerState
    BuildRow(root.coreRow, CoreDefinitions(), 38, 1)
  end

  RUI:UpdatePrimaryPower()
  UpdatePlayerAuras()
  UpdateTargetState()
  RefreshTimerDriver()
end


function RUI:DebugBlackShieldAbsorb()
  local aura = Aura("player", "Black Shield", false)
  if not aura then
    self:Print("Black Shield is not active. Use the command again while the shield is running.")
    return false
  end

  local value = ReadBlackShieldAbsorb(aura, true)
  self:Print("Black Shield absorb: " .. (value and FormatAmount(value) or "not detected")
    .. " | source: " .. tostring(absorbCache.source or "none")
    .. " | aura index: " .. tostring(aura.index)
    .. " | spell ID: " .. tostring(aura.spellID or "unknown"))

  local extra = {}
  for index = 12, #(aura.raw or {}) do
    local rawValue = aura.raw[index]
    if rawValue ~= nil then extra[#extra + 1] = tostring(index) .. "=" .. tostring(rawValue) end
  end
  if #extra > 0 then self:Print("Black Shield aura values: " .. table.concat(extra, ", ")) end

  local _, _, lines = ReadTooltipAbsorb(aura)
  if lines and #lines > 0 then
    for index, line in ipairs(lines) do
      self:Print("Shield tooltip " .. tostring(index) .. ": " .. tostring(line))
    end
  else
    self:Print("No readable Black Shield tooltip lines were returned by the Ascension client.")
  end
  return value ~= nil
end

local function Build()
  if root then return end
  root=CreateFrame("Frame","RetreatUIKnightOfXorothHUD",UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("MEDIUM")

  local counterLayout = RUI.layout.counters or {}
  local impLayout = counterLayout.imp or {x=-105, y=RUI.layout.demonfire.y}
  local bloodLayout = counterLayout.blood or {x=105, y=RUI.layout.demonfire.y}
  root.imp=CreateCounter("IMP","Call: Hellfire Imp","Interface\\Icons\\Spell_Shadow_SummonImp",impLayout.x,impLayout.y)
  root.blood=CreateCounter("DB","Demon's Blood","Interface\\Icons\\Spell_Shadow_LifeDrain",bloodLayout.x,bloodLayout.y)
  CreateDemonfire()
  CreateStanceTracker()

  root.auraTrackers = {}
  for _, definition in ipairs(RUI:GetAuraTrackerDefinitions(CLASS_NAME)) do
    local tracker = CreateAuraTracker(definition.name, definition.fallbackIcon)
    tracker.definition = definition
    root.auraTrackers[#root.auraTrackers + 1] = tracker
  end

  root.coreRow=CreateFrame("Frame",nil,root)
  root.coreRow:SetSize(520,38)
  root.coreRow:SetPoint("CENTER",UIParent,"CENTER",RUI.layout.core.x,RUI.layout.core.y)
  root.utilityRow=CreateFrame("Frame",nil,root)
  root.utilityRow:SetSize(520,32)
  root.utilityRow:SetPoint("CENTER",UIParent,"CENTER",RUI.layout.utility.x,RUI.layout.utility.y)

  BuildRow(root.coreRow,CoreDefinitions(),38,1)
  BuildRow(root.utilityRow,UtilityDefinitions(false),32,1)

  driver=CreateFrame("Frame")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("SPELLS_CHANGED")
  driver:RegisterEvent("UNIT_AURA")
  driver:RegisterEvent("PLAYER_TARGET_CHANGED")
  driver:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  driver:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  if GetSpellCharges then pcall(driver.RegisterEvent, driver, "SPELL_UPDATE_CHARGES") end
  driver:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
  driver:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  driver:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
  driver:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")
  driver:SetScript("OnEvent",function(_,event,unit)
    if not root or not root:IsShown() then return end

    if event=="UNIT_AURA" then
      if unit=="player" then
        UpdatePlayerAuras()
      elseif unit=="target" then
        UpdateTargetState()
      end
      RefreshTimerDriver()
      return
    end

    if event=="PLAYER_TARGET_CHANGED" then
      UpdateTargetState()
      RefreshTimerDriver()
      return
    end

    if event=="SPELL_UPDATE_COOLDOWN" or event=="SPELL_UPDATE_CHARGES" or event=="ACTIONBAR_UPDATE_COOLDOWN" then
      UpdateCooldowns(true)
      RefreshTimerDriver()
      return
    end

    if event=="UPDATE_SHAPESHIFT_FORM" or event=="UPDATE_SHAPESHIFT_FORMS" or event=="UPDATE_SHAPESHIFT_USABLE" then
      UpdateStanceTracker()
      return
    end

    if event=="SPELLS_CHANGED" then
      if spellRefreshPending then return end
      spellRefreshPending = true
      RUI:After(0.15, function()
        spellRefreshPending = false
        if not root or not root:IsShown() then return end
        local _, changed = RUI:ScanSpellbook()
        -- SPELLS_CHANGED also fires when some spellbook UI modules are opened.
        -- Rebuild the HUD only when the learned spell set actually changed.
        if not changed then return end
        if RUI.InvalidateRacialCache then RUI:InvalidateRacialCache() end
        lastImpcallerState = HasImpcaller()
        BuildRow(root.coreRow,CoreDefinitions(),38,1)
        BuildRow(root.utilityRow,UtilityDefinitions(true),32,1)
        -- Spell database discovery is intentionally not rebuilt here. It is a
        -- support/report operation and caused a second full spellbook scan when
        -- opening the spellbook.
        UpdateAll()
      end)
      return
    end

    if event=="COMBAT_LOG_EVENT_UNFILTERED" then
      if ProcessCombatLog() then
        UpdateImpCounter()
        RefreshTimerDriver()
      end
      return
    end

    if event=="PLAYER_ENTERING_WORLD" then
      for guid in pairs(impGUIDs) do impGUIDs[guid]=nil end
      UpdateAll()
    end
  end)

  timerDriver=CreateFrame("Frame")
  timerDriver:Hide()
  timerDriver:SetScript("OnUpdate",function(self,delta)
    timerElapsed = timerElapsed + delta
    impTimerElapsed = impTimerElapsed + delta
    if timerElapsed < 0.20 then return end
    timerElapsed = 0

    if hasCooldownTimers then hasCooldownTimers = UpdateCooldowns(true) end
    if hasAuraTimers then hasAuraTimers = UpdateAuraTrackerTimers() end
    if hasTargetTimers then hasTargetTimers = UpdateTargetDebuffTimers() end

    if impTimerElapsed >= 1.0 then
      impTimerElapsed = 0
      if next(impGUIDs) ~= nil then UpdateImpCounter() end
    end

    if not TimersNeeded() then self:Hide() end
  end)

  -- Ascension does not consistently fire UNIT_AURA when Demonfire stacks
  -- change. Poll only that single resource at a low cost and update the six
  -- icons only when the cached stack count changes.
  demonfireDriver=CreateFrame("Frame")
  demonfireDriver:Hide()
  demonfireDriver:SetScript("OnUpdate",function(_,delta)
    demonfireElapsed = demonfireElapsed + delta
    if demonfireElapsed < 0.12 then return end
    demonfireElapsed = 0
    UpdateDemonfireDisplay(false)
  end)
end

function module:activate()
  Build()
  root:Show()
  driver:Show()
  if demonfireDriver then demonfireDriver:Show() end
  lastDemonfireStacks = nil
  UpdateDemonfireDisplay(true)
  UpdateAll()
  RefreshTimerDriver()
  return true
end

function module:deactivate()
  if root then root:Hide() end
  if driver then driver:Hide() end
  if timerDriver then timerDriver:Hide() end
  if demonfireDriver then demonfireDriver:Hide() end
  demonfireElapsed = 0
  lastDemonfireStacks = nil
end

RUI:RegisterClassModule("Knight of Xoroth",module)

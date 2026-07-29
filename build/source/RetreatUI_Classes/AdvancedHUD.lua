local RUI = RetreatUI
if not RUI then return end

-- Shared data-driven HUD used by the 17 Collector-built class packages.
-- Each class supplies spell/proc/debuff/resource records in Data.lua; this
-- module only renders records that are actually present in the live spellbook
-- or live aura list, so all specializations can share one safe foundation.
local W = RUI.HUDWidgets
local instances = {}

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function SafeFrameName(className)
  return "RetreatUI" .. tostring(className or "Class"):gsub("[^%a%d]", "") .. "HUD"
end

local function ClampDefinitions(definitions, maximum)
  if not maximum or #definitions <= maximum then return definitions end
  local result = {}
  for index = 1, maximum do result[index] = definitions[index] end
  return result
end

local function ReadAura(unit, harmful)
  local getter = harmful and UnitDebuff or UnitBuff
  local state = {list={}, byName={}, byLower={}, byID={}}
  if not getter or not UnitExists or not UnitExists(unit) then return state end

  for index = 1, 40 do
    local values = {getter(unit, index)}
    local name = values[1]
    if not name then break end
    local aura = {
      name = name,
      icon = values[3],
      count = tonumber(values[4]) or 0,
      debuffType = values[5],
      duration = tonumber(values[6]) or 0,
      expires = tonumber(values[7]) or 0,
      caster = values[8],
      spellID = tonumber(values[11]),
      index = index,
    }
    state.list[#state.list + 1] = aura
    state.byName[name] = aura
    state.byLower[Normalize(name)] = aura
    if aura.spellID then state.byID[aura.spellID] = aura end
  end
  return state
end

local function FindAura(state, reference)
  if not state or reference == nil then return nil end
  if type(reference) == "number" then return state.byID[reference] end
  return state.byName[reference] or state.byLower[Normalize(reference)]
end

local function AnyAura(state, references)
  if references == nil then return nil end
  if type(references) ~= "table" then references = {references} end
  for _, reference in ipairs(references) do
    local aura = FindAura(state, reference)
    if aura then return aura end
  end
  return nil
end

local function PowerTexture()
  if ElvUI then
    local E = unpack(ElvUI)
    if E and E.media and E.media.normTex then return E.media.normTex end
  end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function TargetFrameAnchor()
  -- ElvUI's internal UnitFrames.units.target value is not guaranteed to be a
  -- frame object; on some Ascension builds it is the string "target". Passing
  -- that value to SetPoint makes WoW look for a globally named region called
  -- "target" and aborts the entire class HUD refresh. Only use live frames.
  local frame = _G.ElvUF_Target or _G.TargetFrame
  if frame and type(frame) ~= "string" and frame.GetWidth and frame.SetPoint then
    return frame
  end
  return nil
end

function RUI:RegisterAdvancedClassHUD(className, options)
  options = options or {}
  if instances[className] then return instances[className].module end

  local state = {
    className = className,
    options = options,
    root = nil,
    events = nil,
    timer = nil,
    elapsed = 0,
    cooldownElapsed = 0,
    auraElapsed = 0,
    spellRefreshPending = false,
    procFrames = {},
    targetBars = {},
    resourceSegments = {},
    resourceReady = false,
    resourceNativeReady = false,
    resourceSnapshot = nil,
    resourcePowerType = nil,
    resourceForceZero = false,
    stanceTracker = nil,
    stanceAura = nil,
    classStateTracker = nil,
  }
  instances[className] = state

  local module = {
    ready = true,
    className = className,
    frameName = options.frameName or SafeFrameName(className),
    supportedLoadouts = options.supportedLoadouts or {BASELINE=true},
    usesPrimaryPower = options.usesPrimaryPower ~= false,
    advancedCollectorHUD = true,
  }
  state.module = module

  local function Database()
    return RUI:GetClassSpellDatabase(className) or {}
  end

  local function CoreDefinitions()
    return RUI:GetHUDSpellDefinitions(className, "core") or {}
  end

  local function UtilityDefinitions(forceRacialScan)
    local definitions, seen = {}, {}
    for _, definition in ipairs(RUI:GetHUDSpellDefinitions(className, "utility") or {}) do
      local key = Normalize(definition.name)
      if key ~= "" and not seen[key] then
        definitions[#definitions + 1] = definition
        seen[key] = true
      end
    end

    if RUI.GetRacialSpellDefinitions then
      for _, racial in ipairs(RUI:GetRacialSpellDefinitions(forceRacialScan)) do
        local key = Normalize(racial.name)
        if key ~= "" and not seen[key] then
          racial.category = "racial"
          racial.hudRow = "utility"
          racial.order = 900
          definitions[#definitions + 1] = racial
          seen[key] = true
        end
      end
    end

    table.sort(definitions, function(left, right)
      local a, b = tonumber(left.order) or 9999, tonumber(right.order) or 9999
      if a ~= b then return a < b end
      return tostring(left.name or "") < tostring(right.name or "")
    end)
    return definitions
  end

  local function Learned(definition)
    if RUI.IsSpellRecordCastable then return RUI:IsSpellRecordCastable(definition) end
    return RUI:IsSpellRecordLearned(definition)
  end

  local function Texture(definition)
    return RUI:GetSpellRecordTexture(definition)
  end

  local function LearnedDefinitions(definitions, maximum)
    local result = {}
    for _, definition in ipairs(definitions or {}) do
      if Learned(definition) then
        result[#result + 1] = definition
        if maximum and #result >= maximum then break end
      end
    end
    return result
  end

  local function BuildRows(forceRacialScan)
    if not state.root then return end
    local core = LearnedDefinitions(CoreDefinitions(), options.maxCore or 16)
    local utility = LearnedDefinitions(UtilityDefinitions(forceRacialScan), options.maxUtility or 18)
    W:BuildSpellRow(state.root.coreRow, core, 38, 1, function() return true end, Texture)
    W:BuildSpellRow(state.root.utilityRow, utility, 32, 1, function() return true end, Texture)
  end

  -----------------------------------------------------------------------------
  -- Strong proc glows on the exact spell(s) made free/instant/empowered.
  -----------------------------------------------------------------------------
  local function SpellRecordUsable(definition)
    if type(definition) ~= "table" or type(IsUsableSpell) ~= "function" then return false end
    local candidates, seen = {}, {}
    local function Add(value)
      if value == nil then return end
      local key = tostring(value)
      if key == "" or seen[key] then return end
      seen[key] = true
      candidates[#candidates + 1] = value
    end

    if RUI.GetSpellRecordRuntimeID then Add(RUI:GetSpellRecordRuntimeID(definition)) end
    Add(definition.id)
    Add(definition.name)
    for _, alias in ipairs(definition.aliases or {}) do Add(alias) end

    for _, candidate in ipairs(candidates) do
      local ok, usable = pcall(IsUsableSpell, candidate)
      if ok and usable then return true end
    end
    return false
  end

  local function StateGlowDefinition()
    local configured = options.stateGlowWhenUsable
    if type(configured) == "table" then return configured end
    if type(configured) == "number" then return {id=configured} end
    if type(configured) == "string" and configured ~= "" then return {name=configured} end
    return nil
  end

  local function ApplyStateTrackerUsableGlow()
    local tracker = state.classStateTracker
    local definition = StateGlowDefinition()
    if not tracker or not definition then return end

    local usable = SpellRecordUsable(definition)
    local resourceReady = options.stateGlowResourceReady
    if type(resourceReady) == "table" and type(state.resourceSnapshot) == "table" then
      local current = tonumber(state.resourceSnapshot.current) or 0
      local maximum = tonumber(state.resourceSnapshot.maximum) or 0
      local requiredCurrent = tonumber(resourceReady.current) or tonumber(resourceReady.minimum)
      local requiredMaximum = tonumber(resourceReady.maximum)
      local thresholdReady = requiredCurrent and current >= requiredCurrent
      if requiredMaximum and maximum ~= requiredMaximum then thresholdReady = false end
      usable = thresholdReady == true
    end
    local wantedGroup = Normalize(options.stateGlowGroup)
    local theme = RUI:GetTheme()
    for _, frame in ipairs(tracker.frames or {}) do
      if frame:IsShown() and frame.state then
        local groupKey = Normalize(frame.state.group and frame.state.group.key)
        local applies = wantedGroup == "" or groupKey == wantedGroup
        if applies and usable then
          W:SetBorder(frame, theme.accent, 1)
          W:SetGlow(frame, theme.accent2, 0.82)
          if frame.stateText then
            frame.stateText:SetTextColor(theme.accent2[1], theme.accent2[2], theme.accent2[3], 1)
          end
        else
          W:SetGlow(frame, nil, 0)
          W:SetBorder(frame, theme.accent2, 1)
          if frame.stateText then frame.stateText:SetTextColor(1, 1, 1, 1) end
        end
      end
    end
  end

  local function ApplyProcGlows(playerAuras)
    local theme = RUI:GetTheme()
    for _, row in ipairs({state.root.coreRow, state.root.utilityRow}) do
      for _, icon in ipairs(row.icons or {}) do
        if icon:IsShown() and icon.definition then
          W:SetGlow(icon, nil, 0)
          local definition = icon.definition
          local aura = AnyAura(playerAuras, definition.glowWhenAura)
          if not aura then aura = AnyAura(playerAuras, definition.glowWhenAuraID) end
          local usable = definition.glowWhenUsable == true and SpellRecordUsable(definition)
          if aura or usable then
            local pulse = 0.72 + 0.28 * math.abs(math.sin(GetTime() * 7.5))
            W:SetBorder(icon, theme.accent2, 1)
            W:SetGlow(icon, theme.accent2, pulse)
            if icon.texture and icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
          end
        end
      end
    end
  end

  local function UpdateUsableGlowsOnly()
    if not state.root or not state.root:IsShown() then return end
    local theme = RUI:GetTheme()
    for _, row in ipairs({state.root.coreRow, state.root.utilityRow}) do
      for _, icon in ipairs(row.icons or {}) do
        local definition = icon.definition
        if icon:IsShown() and definition and definition.glowWhenUsable == true then
          if SpellRecordUsable(definition) then
            W:SetBorder(icon, theme.accent2, 1)
            W:SetGlow(icon, theme.accent2, 1)
            if icon.texture and icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
          else
            W:SetGlow(icon, nil, 0)
            W:SetBorder(icon, {0,0,0,1}, 1)
          end
        end
      end
    end
    ApplyStateTrackerUsableGlow()
  end

  -----------------------------------------------------------------------------
  -- Active-only proc/buff row. Definitions can safely contain hidden/internal
  -- candidates because nothing is drawn until the client reports a real aura.
  -----------------------------------------------------------------------------
  local function CreateProcFrame(index)
    local size = (RUI.layout.auraTrackers and RUI.layout.auraTrackers.size) or 30
    local frame = W:CreateIcon(state.root, size)
    frame.procIndex = index
    state.procFrames[index] = frame
    return frame
  end

  local function BuildProcLookup()
    local byName, byID = {}, {}
    local resource = Database().nativeResource or options.nativeResource or {}
    local resourceNames = {}
    for _, name in ipairs(resource.auraNames or {}) do resourceNames[Normalize(name)] = true end
    local resourceID = tonumber(resource.spellID)

    for _, definition in ipairs(RUI:GetAuraTrackerDefinitions(className) or {}) do
      local definitionID = tonumber(definition.auraID) or tonumber(definition.id)
      local nameKey = Normalize(definition.buff or definition.name)
      local isResource = (resourceID and definitionID == resourceID) or resourceNames[nameKey]
      local isClassState = RUI.IsClassStateAuraDefinition
        and RUI:IsClassStateAuraDefinition(className, definition, {
          extraDefinitions=options.stanceAuras,
          extraPrefixes=options.stanceAuraPrefix and {options.stanceAuraPrefix} or nil,
        })
      if not isResource and not isClassState then
        if definition.name then byName[Normalize(definition.name)] = definition end
        if definition.buff then byName[Normalize(definition.buff)] = definition end
        if definitionID then byID[definitionID] = definition end
        for _, alias in ipairs(definition.aliases or {}) do byName[Normalize(alias)] = definition end
      end
    end
    return byName, byID
  end

  local function UpdateProcTrackers(playerAuras)
    local byName, byID = BuildProcLookup()
    local active, seen = {}, {}

    for _, aura in ipairs(playerAuras.list or {}) do
      local definition = (aura.spellID and byID[aura.spellID]) or byName[Normalize(aura.name)]
      if definition then
        local idKey = aura.spellID and ("id:" .. tostring(aura.spellID)) or nil
        local nameKey = "name:" .. Normalize(aura.name)
        if (not idKey or not seen[idKey]) and not seen[nameKey] then
          if idKey then seen[idKey] = true end
          seen[nameKey] = true
          active[#active + 1] = {definition=definition, aura=aura}
        end
      end
    end

    table.sort(active, function(left, right)
      local a, b = tonumber(left.definition.order) or 999, tonumber(right.definition.order) or 999
      if a ~= b then return a < b end
      return tostring(left.aura.name or "") < tostring(right.aura.name or "")
    end)

    local maximum = math.min(#active, options.maxProcs or 12)
    local layout = RUI.layout.auraTrackers or {x=0,y=-83,size=30,spacing=3}
    local size, spacing = layout.size or 30, layout.spacing or 3
    local total = maximum > 0 and (maximum * size + (maximum - 1) * spacing) or 0
    local theme = RUI:GetTheme()

    for index = 1, maximum do
      local item = active[index]
      local frame = state.procFrames[index] or CreateProcFrame(index)
      local aura = item.aura
      frame.aura = aura
      frame.definition = item.definition
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", UIParent, "CENTER",
        (layout.x or 0) - total / 2 + size / 2 + (index - 1) * (size + spacing),
        layout.y or -83)
      frame.texture:SetTexture(aura.icon or Texture(item.definition))
      if frame.texture.SetDesaturated then frame.texture:SetDesaturated(false) end
      if frame.cooldownShade then frame.cooldownShade:Hide() end
      frame.stackText:SetText(aura.count and aura.count > 1 and tostring(aura.count) or "")
      local remaining = aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
      frame.cooldownText:SetText(remaining > 0.05 and W:FormatCooldown(remaining) or "")
      frame.cooldownText:SetTextColor(0.72,1.00,0.42,1)
      W:SetBorder(frame, theme.accent2, 1)
      frame:Show()
    end

    for index = maximum + 1, #state.procFrames do
      state.procFrames[index].aura = nil
      state.procFrames[index]:Hide()
    end
  end

  local function UpdateProcTimers()
    for _, frame in ipairs(state.procFrames) do
      local aura = frame.aura
      if frame:IsShown() and aura and aura.expires and aura.expires > 0 then
        local remaining = math.max(0, aura.expires - GetTime())
        if remaining > 0.05 then
          frame.cooldownText:SetText(W:FormatCooldown(remaining))
        else
          frame.aura = nil
          frame:Hide()
        end
      end
    end
  end

  -----------------------------------------------------------------------------
  -- Optional active stance/aura tracker. This is separate from the proc row and
  -- is intended for mutually exclusive class states such as Sun Cleric Vows.
  -----------------------------------------------------------------------------
  local function StanceConfig()
    local database = Database()
    local definitions = options.stanceAuras or database.stanceAuras or {}
    local prefix = options.stanceAuraPrefix or database.stanceAuraPrefix
    return definitions, prefix
  end

  local function StanceDefinitionForAura(aura)
    if not aura then return nil end
    local definitions, prefix = StanceConfig()
    local auraName = Normalize(aura.name)
    for _, definition in ipairs(definitions or {}) do
      local definitionID = tonumber(definition.auraID) or tonumber(definition.id)
      if definitionID and aura.spellID and definitionID == aura.spellID then return definition end
      if definition.name and Normalize(definition.name) == auraName then return definition end
      if definition.buff and Normalize(definition.buff) == auraName then return definition end
      for _, alias in ipairs(definition.aliases or {}) do
        if Normalize(alias) == auraName then return definition end
      end
    end
    prefix = Normalize(prefix)
    if prefix ~= "" and string.sub(auraName, 1, string.len(prefix)) == prefix then
      return {name=aura.name, label=aura.name}
    end
    return nil
  end

  local function ActiveStanceAura(playerAuras)
    for _, aura in ipairs(playerAuras.list or {}) do
      local definition = StanceDefinitionForAura(aura)
      if definition then return definition, aura end
    end
    return nil
  end

  local function ShortStanceLabel(definition, aura)
    local label = definition and definition.label or (aura and aura.name) or "STANCE"
    label = tostring(label or "STANCE")
    label = label:gsub("^[Vv][Oo][Ww]%s+[Oo][Ff]%s+[Tt][Hh][Ee]%s+", "")
    label = label:gsub("^[Vv][Oo][Ww]%s+[Oo][Ff]%s+", "")
    return label
  end

  local function CreateStanceTracker()
    local definitions, prefix = StanceConfig()
    if (#(definitions or {}) == 0) and Normalize(prefix) == "" then return end
    local config = options.stanceTracker or {}
    state.stanceTracker = W:CreateFormTracker(state.root, {
      x=config.x or -195,
      y=config.y or ((RUI.layout.demonfire and RUI.layout.demonfire.y) or -118),
      size=config.size or ((RUI.layout.stanceTracker and RUI.layout.stanceTracker.size) or 38),
      width=config.width or 100,
      height=config.height or 58,
      nameSize=config.nameSize or 8,
    })
  end

  local function UpdateStanceTracker(playerAuras)
    local frame = state.stanceTracker
    if not frame then return end
    local definition, aura = ActiveStanceAura(playerAuras)
    if not definition or not aura then
      state.stanceAura = nil
      frame:Hide()
      return
    end

    state.stanceAura = aura
    W:SetFormTracker(
      frame,
      ShortStanceLabel(definition, aura),
      aura.icon or Texture(definition),
      RUI:GetTheme().accent2
    )
    frame.icon.stackText:SetText(aura.count and aura.count > 1 and tostring(aura.count) or "")
    local remaining = aura.expires and aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
    frame.icon.cooldownText:SetText(remaining > 0.05 and W:FormatCooldown(remaining) or "")
    frame.icon.cooldownText:SetTextColor(0.72,1.00,0.42,1)
  end

  local function UpdateStanceTimer()
    local frame, aura = state.stanceTracker, state.stanceAura
    if not frame or not frame:IsShown() or not aura then return end
    if aura.expires and aura.expires > 0 then
      local remaining = math.max(0, aura.expires - GetTime())
      if remaining > 0.05 then
        frame.icon.cooldownText:SetText(W:FormatCooldown(remaining))
      else
        state.stanceAura = nil
        frame:Hide()
      end
    end
  end

  -----------------------------------------------------------------------------
  -- Player-applied target debuffs above the target frame.
  -----------------------------------------------------------------------------
  local function BuildTargetLookup()
    local byName, byID = {}, {}

    local function AddDefinition(definition, curated)
      if type(definition) ~= "table" then return end
      if curated then definition._targetDebuffCurated = true end
      if definition.name then byName[Normalize(definition.name)] = byName[Normalize(definition.name)] or definition end
      if definition.debuff then byName[Normalize(definition.debuff)] = definition end
      if definition.buff then byName[Normalize(definition.buff)] = byName[Normalize(definition.buff)] or definition end
      local definitionID = tonumber(definition.auraID) or tonumber(definition.id)
      if definitionID then byID[definitionID] = byID[definitionID] or definition end
      for _, alias in ipairs(definition.aliases or {}) do
        byName[Normalize(alias)] = byName[Normalize(alias)] or definition
      end
    end

    -- Curated records keep their requested ordering, but the target tracker is
    -- no longer limited to a whitelist. Every player-applied debuff is shown.
    for _, definition in ipairs(RUI:GetTargetDebuffDefinitions(className) or {}) do
      AddDefinition(definition, true)
    end
    local database = Database()
    for _, definition in ipairs((database and database.spells) or {}) do
      AddDefinition(definition, false)
    end
    return byName, byID
  end

  local function IsOwnTargetDebuffCaster(caster)
    if caster == "player" or caster == "pet" or caster == "vehicle" then return true end
    local playerName = UnitName and UnitName("player")
    return playerName and caster == playerName or false
  end

  local function CreateTargetBar(index)
    local bar = CreateFrame("StatusBar", nil, state.root)
    bar:SetSize(180, 16)
    bar:SetStatusBarTexture(PowerTexture())
    bar:SetMinMaxValues(0, 1)
    RUI:SkinFrame(bar, {0.015,0.015,0.020,0.96}, {0,0,0,1})

    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetSize(16,16)
    bar.icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)
    bar.icon:SetTexCoord(.08,.92,.08,.92)

    bar.nameText = bar:CreateFontString(nil, "OVERLAY")
    bar.nameText:SetPoint("LEFT", 4, 0)
    bar.nameText:SetWidth(118)
    bar.nameText:SetJustifyH("LEFT")
    RUI:ApplyFont(bar.nameText, 8, "OUTLINE")

    bar.timeText = bar:CreateFontString(nil, "OVERLAY")
    bar.timeText:SetPoint("RIGHT", -4, 0)
    RUI:ApplyFont(bar.timeText, 8, "OUTLINE")

    bar.stackText = bar:CreateFontString(nil, "OVERLAY")
    bar.stackText:SetPoint("BOTTOMRIGHT", bar.icon, "BOTTOMRIGHT", -1, 1)
    RUI:ApplyFont(bar.stackText, 8, "OUTLINE")
    bar:Hide()
    return bar
  end

  local function PositionTargetBar(bar, index)
    local targetFrame = TargetFrameAnchor()
    local width = 180
    if targetFrame and targetFrame.GetWidth then
      local ok, measured = pcall(targetFrame.GetWidth, targetFrame)
      if ok and tonumber(measured) and measured > 80 then width = measured end
    end
    bar:SetWidth(width)
    bar:ClearAllPoints()
    local anchored = false
    if targetFrame then
      anchored = pcall(bar.SetPoint, bar, "BOTTOMLEFT", targetFrame, "TOPLEFT", 0, 4 + (index - 1) * 18)
    end
    if not anchored then
      local fallback = RUI.layout.targetDebuffs or {x=310,y=-59}
      bar:SetPoint("CENTER", UIParent, "CENTER", fallback.x or 310, (fallback.y or -59) + (index - 1) * 18)
    end
  end

  local function UpdateTargetDebuffs()
    if not state.root or not state.root:IsShown() then return end
    local result = {}
    if UnitExists and UnitExists("target") and UnitDebuff then
      local byName, byID = BuildTargetLookup()
      local seen = {}
      for index = 1, 40 do
        local values = {UnitDebuff("target", index)}
        local name = values[1]
        if not name then break end
        local spellID = tonumber(values[11])
        local definition = (spellID and byID[spellID]) or byName[Normalize(name)]
        local caster = values[8]
        -- Ascension usually returns a unit token for normal auras, but some
        -- custom class debuffs have no caster. Accept nil only when the aura
        -- matches the active class database; explicit player/pet/vehicle auras
        -- are always tracked, even if they were not manually curated.
        local owned = IsOwnTargetDebuffCaster(caster) or (caster == nil and definition ~= nil)
        if owned then
          local idKey = spellID and ("id:" .. tostring(spellID)) or nil
          local nameKey = "name:" .. Normalize(name)
          if (not idKey or not seen[idKey]) and not seen[nameKey] then
            if idKey then seen[idKey] = true end
            seen[nameKey] = true
            local resolvedDefinition = definition or {
              name=name, id=spellID, order=900, targetDebuff=true,
              fallbackIcon=values[3],
            }
            result[#result + 1] = {
              name=name, icon=values[3], count=tonumber(values[4]) or 0,
              duration=tonumber(values[6]) or 0, expires=tonumber(values[7]) or 0,
              caster=caster, spellID=spellID, definition=resolvedDefinition,
            }
          end
        end
      end
    end

    table.sort(result, function(left, right)
      local a, b = tonumber(left.definition.order) or 999, tonumber(right.definition.order) or 999
      if a ~= b then return a < b end
      return tostring(left.name or "") < tostring(right.name or "")
    end)

    local maximum = math.min(#result, options.maxTargetDebuffs or 12)
    local theme = RUI:GetTheme()
    for index = 1, maximum do
      local aura = result[index]
      local bar = state.targetBars[index]
      if not bar then bar = CreateTargetBar(index); state.targetBars[index] = bar end
      bar.aura = aura
      PositionTargetBar(bar, index)
      local remaining = aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
      if aura.duration > 0 and aura.expires > 0 then
        bar:SetMinMaxValues(0, aura.duration)
        bar:SetValue(math.min(aura.duration, remaining))
      else
        bar:SetMinMaxValues(0,1); bar:SetValue(1)
      end
      if aura.duration > 0 and remaining <= 5 then
        bar:SetStatusBarColor(0.95,0.18,0.08,0.95)
        bar.timeText:SetTextColor(1,0.35,0.18,1)
      else
        bar:SetStatusBarColor(theme.accent[1],theme.accent[2],theme.accent[3],0.82)
        bar.timeText:SetTextColor(1,0.95,0.35,1)
      end
      bar.icon:SetTexture(aura.icon or (aura.spellID and select(3,GetSpellInfo(aura.spellID))) or "Interface\\Icons\\INV_Misc_QuestionMark")
      bar.nameText:SetText(aura.name or "Debuff")
      bar.timeText:SetText(remaining > 0.05 and W:FormatCooldown(remaining) or "")
      bar.stackText:SetText(aura.count and aura.count > 1 and tostring(aura.count) or "")
      bar:Show()
    end
    for index = maximum + 1, #state.targetBars do
      state.targetBars[index].aura = nil
      state.targetBars[index]:Hide()
    end
  end

  local function UpdateTargetTimers()
    for _, bar in ipairs(state.targetBars) do
      local aura = bar.aura
      if bar:IsShown() and aura and aura.expires and aura.expires > 0 then
        local remaining = math.max(0, aura.expires - GetTime())
        if remaining > 0.05 then
          if aura.duration > 0 then bar:SetValue(math.min(aura.duration, remaining)) end
          bar.timeText:SetText(W:FormatCooldown(remaining))
        else
          bar.aura = nil
          bar:Hide()
        end
      end
    end
  end

  -----------------------------------------------------------------------------
  -- Compact native class-resource replacement. It is only considered complete
  -- after a valid live source has been read; until then Ascension's frame stays.
  -----------------------------------------------------------------------------
  local function ResourceConfig()
    return Database().nativeResource or options.nativeResource
  end

  local function PositionResourceBar(config)
    if not state.root or not state.root.resourceBar or type(config) ~= "table" then return end
    local bar = state.root.resourceBar
    local height = tonumber(config.height) or 10
    local width = tonumber(config.width) or 330
    local x = tonumber(config.x) or 0
    local y = tonumber(config.y) or ((RUI.layout.demonfire and RUI.layout.demonfire.y) or -118)

    if config.matchPrimaryPower == true then
      local primary = _G.RetreatUIPrimaryPowerBar
      local powerLayout = RUI.layout.power or {x=0, y=-152, width=360, height=16}
      width = primary and primary.GetWidth and primary:GetWidth() or tonumber(powerLayout.width) or width
      bar:ClearAllPoints()
      bar:SetSize(width, height)
      if primary and primary.GetHeight then
        bar:SetPoint("BOTTOM", primary, "TOP", tonumber(config.xOffset) or 0, tonumber(config.gap) or 1)
        if bar.SetFrameLevel and primary.GetFrameLevel then
          bar:SetFrameLevel(math.max(bar:GetFrameLevel() or 1, (primary:GetFrameLevel() or 1) + 1))
        end
      else
        local primaryHeight = tonumber(powerLayout.height) or 16
        y = (tonumber(powerLayout.y) or -152) + primaryHeight / 2 + height / 2 + (tonumber(config.gap) or 1)
        bar:SetPoint("CENTER", UIParent, "CENTER", (tonumber(powerLayout.x) or 0) + (tonumber(config.xOffset) or 0), y)
      end
      return
    end

    bar:ClearAllPoints()
    bar:SetSize(width, height)
    bar:SetPoint("CENTER", UIParent, "CENTER", x, y)
  end

  local function CreateResourceSegment(index)
    local frame = CreateFrame("Frame", nil, state.root)
    frame:SetSize(25,25)
    RUI:SkinFrame(frame, {0.012,0.012,0.016,0.96}, {0,0,0,1})
    frame.texture = frame:CreateTexture(nil, "ARTWORK")
    frame.texture:SetPoint("TOPLEFT",1,-1)
    frame.texture:SetPoint("BOTTOMRIGHT",-1,1)
    frame.texture:SetTexCoord(.08,.92,.08,.92)
    frame:Hide()
    state.resourceSegments[index] = frame
    return frame
  end

  local function HideResource()
    if not state.root then return end
    state.root.resourceBar:Hide()
    state.root.resourceLabel:Hide()
    for _, segment in ipairs(state.resourceSegments) do segment:Hide() end
  end

  local function ResourceAura(playerAuras, config)
    local aura = AnyAura(playerAuras, config.auraNames)
    if not aura and config.spellID then aura = FindAura(playerAuras, tonumber(config.spellID)) end
    return aura
  end

  local function PowerResourceSnapshot(config)
    if type(config.fallbackPower) ~= "table" then return nil end

    if state.resourcePowerType ~= nil and UnitPower and UnitPowerMax then
      local okMax, maximum = pcall(UnitPowerMax, "player", state.resourcePowerType)
      local okCurrent, current = pcall(UnitPower, "player", state.resourcePowerType)
      maximum = okMax and tonumber(maximum) or nil
      current = okCurrent and tonumber(current) or nil
      if maximum and maximum > 0 and current then
        return {
          current=current, maximum=maximum, icon=config.icon,
          label=config.title, fallback=true, source="power",
          powerType=state.resourcePowerType,
        }
      end
      state.resourcePowerType = nil
    end

    if RUI.FindCustomPower then
      local found = RUI:FindCustomPower(config.fallbackPower)
      if found then
        state.resourcePowerType = found.powerType
        return {
          current=found.current, maximum=found.maximum, icon=config.icon,
          label=config.title, fallback=true, source="power",
          powerType=found.powerType,
        }
      end
    end
    return nil
  end

  local function SnapshotResource(playerAuras, forceDiscovery)
    local config = ResourceConfig()
    if type(config) ~= "table" then return nil end

    -- Direct UnitPower reads are both faster and more accurate than recursively
    -- inspecting Ascension's UI frames. Sun Cleric opts into this path first.
    if config.preferPower == true then
      local power = PowerResourceSnapshot(config)
      if power then return power end
    end

    local aura = ResourceAura(playerAuras, config)
    if aura then
      local maximum
      if type(config.maxByName) == "table" then
        maximum = tonumber(config.maxByName[Normalize(aura.name)]) or tonumber(config.maxByName[aura.name])
      end
      maximum = maximum or tonumber(config.maxStacks) or tonumber(config.maximum) or math.max(1, tonumber(aura.count) or 1)
      local current = tonumber(aura.count) or 0
      if current <= 0 then current = 1 end
      return {
        current=current, maximum=maximum, icon=aura.icon,
        label=aura.name or config.title, duration=aura.duration,
        expirationTime=aura.expires, aura=true, source="aura",
      }
    end

    if RUI.ReadAscensionResourceSnapshot and type(config.keywords) == "table" then
      local snapshot = RUI:ReadAscensionResourceSnapshot(config.keywords, config.title, forceDiscovery == true)
      if snapshot and tonumber(snapshot.maximum) and tonumber(snapshot.current) then
        snapshot.source = "native"
        return snapshot
      end
    end

    if config.preferPower ~= true then return PowerResourceSnapshot(config) end
    return nil
  end

  local function UpdateResource(playerAuras, forceDiscovery)
    local config = ResourceConfig()
    if type(config) ~= "table" then
      state.resourceReady = false
      state.resourceNativeReady = false
      HideResource()
      return
    end
    local snapshot = SnapshotResource(playerAuras, forceDiscovery)
    if not snapshot and (state.resourceForceZero or config.keepVisible == true) then
      snapshot = {}
      if state.resourceSnapshot then
        for key, value in pairs(state.resourceSnapshot) do snapshot[key] = value end
      end
      snapshot.current = state.resourceForceZero and 0 or (tonumber(snapshot.current) or tonumber(config.defaultCurrent) or 0)
      snapshot.maximum = tonumber(snapshot.maximum) or tonumber(config.maximum) or tonumber(config.maxStacks) or 1
      snapshot.icon = snapshot.icon or config.icon
      snapshot.label = snapshot.label or config.title
      snapshot.source = "displayFallback"
    end
    if not snapshot then
      state.resourceReady = false
      state.resourceNativeReady = false
      HideResource()
      return
    end

    state.resourceReady = true
    state.resourceNativeReady = snapshot.source == "native" or snapshot.source == "power"
      or (snapshot.source == "aura" and config.hideNativeOnAura == true)
    state.resourceSnapshot = snapshot
    local current = math.max(0, tonumber(snapshot.current) or 0)
    local maximum = math.max(1, tonumber(snapshot.maximum) or 1)
    if current > maximum then current = maximum end
    if state.resourceForceZero then
      if snapshot.source == "displayFallback" then
        current = 0
      elseif current < maximum then
        state.resourceForceZero = false
      else
        current = 0
      end
    end
    local label = string.upper(tostring(config.title or snapshot.label or "CLASS RESOURCE"))
    local icon = snapshot.icon or config.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    local mode = config.mode or "auto"
    if mode == "auto" then
      mode = maximum <= 20 and maximum == math.floor(maximum) and "segments" or "bar"
    end
    HideResource()

    local theme = RUI:GetTheme()
    if mode == "segments" and maximum <= 24 then
      maximum = math.floor(maximum + .5)
      current = math.floor(current + .5)
      while #state.resourceSegments < maximum do CreateResourceSegment(#state.resourceSegments + 1) end
      local size = maximum > 12 and math.max(12, math.floor(330 / maximum)) or 25
      local spacing = 1
      local total = maximum * size + (maximum - 1) * spacing
      local firstX = -total / 2 + size / 2
      local y = (RUI.layout.demonfire and RUI.layout.demonfire.y) or -118
      state.root.resourceLabel:SetText(label .. "  " .. tostring(current) .. " / " .. tostring(maximum))
      state.root.resourceLabel:SetTextColor(theme.accent[1],theme.accent[2],theme.accent[3],1)
      state.root.resourceLabel:Show()
      for index, segment in ipairs(state.resourceSegments) do
        if index <= maximum then
          local active = index <= current
          segment:ClearAllPoints()
          segment:SetSize(size,size)
          segment:SetPoint("CENTER", UIParent, "CENTER", firstX + (index - 1) * (size + spacing), y)
          segment.texture:SetTexture(icon)
          if segment.texture.SetDesaturated then segment.texture:SetDesaturated(not active) end
          segment.texture:SetVertexColor(active and 1 or .45, active and 1 or .45, active and 1 or .45, 1)
          segment:SetAlpha(active and 1 or .28)
          segment:SetBackdropBorderColor(theme.accent[1],theme.accent[2],theme.accent[3],active and 1 or .35)
          segment:Show()
        else
          segment:Hide()
        end
      end
    else
      local bar = state.root.resourceBar
      PositionResourceBar(config)
      bar:SetMinMaxValues(0, maximum)
      bar:SetValue(current)
      bar:SetStatusBarColor(theme.accent[1],theme.accent[2],theme.accent[3],1)
      local valueText = tostring(math.floor(current + .5)) .. " / " .. tostring(math.floor(maximum + .5))
      if config.showLabel == false or label == "" then
        bar.text:SetText(valueText)
      else
        bar.text:SetText(label .. "  " .. valueText)
      end
      bar:Show()
    end
  end

  function module.customResourcesComplete()
    -- Aura-only mirrors are useful for testing, but do not prove that we have
    -- replaced Ascension's complete native resource. Keep the native frame
    -- until a native/custom-power source is confirmed, unless a class opts in.
    return state.resourceNativeReady == true
  end

  local function ResourceResetMatches(...)
    local config = ResourceConfig()
    local resetValues = type(config) == "table" and config.resetOnCast or nil
    if type(resetValues) ~= "table" then return false end
    local expectedIDs, expectedNames = {}, {}
    for _, value in ipairs(resetValues) do
      if type(value) == "number" then expectedIDs[tonumber(value)] = true
      else expectedNames[Normalize(value)] = true end
    end
    for index = 1, select("#", ...) do
      local value = select(index, ...)
      if type(value) == "number" and expectedIDs[tonumber(value)] then return true end
      if type(value) == "string" and expectedNames[Normalize(value)] then return true end
    end
    return false
  end

  local function ResetResourceAfterCast()
    state.resourceForceZero = true
    if state.resourceSnapshot then state.resourceSnapshot.current = 0 end
    UpdateResource(ReadAura("player", false), false)
    UpdateUsableGlowsOnly()
  end

  -----------------------------------------------------------------------------
  -- Lifecycle
  -----------------------------------------------------------------------------
  local function UpdatePlayerState(forceResourceDiscovery)
    if not state.root or not state.root:IsShown() then return end
    local playerAuras = ReadAura("player", false)
    W:UpdateSpellRow(state.root.coreRow, function(reference) return FindAura(playerAuras, reference) end)
    W:UpdateSpellRow(state.root.utilityRow, function(reference) return FindAura(playerAuras, reference) end)
    ApplyProcGlows(playerAuras)
    UpdateProcTrackers(playerAuras)
    UpdateResource(playerAuras, forceResourceDiscovery)
    if state.classStateTracker then
      state.classStateTracker:Update(playerAuras)
      ApplyStateTrackerUsableGlow()
    end
  end

  local function UpdateCooldownsOnly()
    if not state.root or not state.root:IsShown() then return end
    local playerAuras = ReadAura("player", false)
    W:UpdateSpellRow(state.root.coreRow, function(reference) return FindAura(playerAuras, reference) end)
    W:UpdateSpellRow(state.root.utilityRow, function(reference) return FindAura(playerAuras, reference) end)
    ApplyProcGlows(playerAuras)
    ApplyStateTrackerUsableGlow()
  end

  local function UpdateCooldownTimersOnly()
    if not state.root or not state.root:IsShown() then return end
    for _, row in ipairs({state.root.coreRow, state.root.utilityRow}) do
      for _, icon in ipairs(row.icons or {}) do
        if icon:IsShown() and icon.definition then
          local definition = icon.definition
          local chargeCurrent, chargeMaximum, chargeStart, chargeDuration
          if definition.trackCharges then
            chargeCurrent, chargeMaximum, chargeStart, chargeDuration = W:ReadSpellCharges(definition)
          end
          if definition.trackCooldown == false then
            W:SetCooldownDisplay(icon, 0, false)
          elseif chargeCurrent and chargeMaximum then
            local remaining = chargeDuration > 0 and math.max(0, chargeStart + chargeDuration - GetTime()) or 0
            W:SetCooldownDisplay(icon, remaining, chargeCurrent < chargeMaximum and remaining > 0.05)
            icon.stackText:SetText(string.format("%d/%d", chargeCurrent, chargeMaximum))
          else
            local startTime, duration, enabled = W:ReadSpellCooldown(definition)
            local remaining = duration > 0 and math.max(0, startTime + duration - GetTime()) or 0
            W:SetCooldownDisplay(icon, remaining, duration > 1.5 and remaining > 0.05 and enabled ~= 0)
          end
        end
      end
    end
  end

  local function UpdateAll(forceResourceDiscovery)
    if not state.root or not state.root:IsShown() then return end
    if RUI.UpdatePrimaryPower then RUI:UpdatePrimaryPower(true) end
    UpdatePlayerState(forceResourceDiscovery)
    UpdateTargetDebuffs()
  end

  local function Build()
    if state.root then return end
    local root = CreateFrame("Frame", module.frameName, UIParent)
    root:SetAllPoints(UIParent)
    root:SetFrameStrata("MEDIUM")
    state.root = root

    root.coreRow = CreateFrame("Frame", nil, root)
    root.coreRow:SetSize(640,38)
    local hudYOffset = tonumber(options.hudYOffset) or 0
    root.coreRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.core.x, RUI.layout.core.y + hudYOffset)

    root.utilityRow = CreateFrame("Frame", nil, root)
    root.utilityRow:SetSize(640,32)
    root.utilityRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.utility.x, RUI.layout.utility.y + hudYOffset)

    root.resourceLabel = root:CreateFontString(nil, "OVERLAY")
    root.resourceLabel:SetPoint("CENTER", UIParent, "CENTER", 0, ((RUI.layout.demonfire and RUI.layout.demonfire.y) or -118) + 22)
    RUI:ApplyFont(root.resourceLabel, 8, "OUTLINE")
    root.resourceLabel:Hide()

    local resourceConfig = ResourceConfig() or {}
    root.resourceBar = CreateFrame("StatusBar", nil, root)
    root.resourceBar:SetStatusBarTexture(PowerTexture())
    PositionResourceBar(resourceConfig)
    root.resourceBar:SetMinMaxValues(0,1)
    RUI:SkinFrame(root.resourceBar, {0.018,0.018,0.022,0.96}, {0,0,0,1})
    root.resourceBar.text = root.resourceBar:CreateFontString(nil,"OVERLAY")
    root.resourceBar.text:SetPoint("CENTER")
    RUI:ApplyFont(root.resourceBar.text,8,"OUTLINE")
    root.resourceBar:Hide()

    if RUI.CreateClassStateTracker then
      local stanceConfig = options.stanceTracker or {}
      state.classStateTracker = RUI:CreateClassStateTracker(root, className, {
        x=stanceConfig.x or -195,
        y=stanceConfig.y or ((RUI.layout.demonfire and RUI.layout.demonfire.y) or -118),
        anchor=stanceConfig.anchor,
        anchorFrameName=stanceConfig.anchorFrameName,
        fallbackX=stanceConfig.fallbackX,
        fallbackY=stanceConfig.fallbackY,
        direction=stanceConfig.direction,
        size=stanceConfig.size or 38,
        width=stanceConfig.width or 90,
        height=stanceConfig.height or 58,
        nameSize=stanceConfig.nameSize or 8,
        gap=stanceConfig.gap,
        maxStates=options.maxStates or 5,
        extraDefinitions=options.stanceAuras,
        extraPrefixes=options.stanceAuraPrefix and {options.stanceAuraPrefix} or nil,
      })
    end
    BuildRows(false)

    state.events = CreateFrame("Frame")
    for _, eventName in ipairs({
      "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
      "UNIT_AURA", "PLAYER_TARGET_CHANGED", "UNIT_TARGET",
      "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN", "UNIT_SPELLCAST_SUCCEEDED",
      "UNIT_POWER", "UNIT_POWER_FREQUENT", "UNIT_DISPLAYPOWER", "UNIT_POWER_BAR_SHOW", "UNIT_POWER_BAR_HIDE",
      "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_USABLE",
    }) do pcall(state.events.RegisterEvent, state.events, eventName) end
    if GetSpellCharges then pcall(state.events.RegisterEvent, state.events, "SPELL_UPDATE_CHARGES") end

    state.events:SetScript("OnEvent", function(_, event, unit, ...)
      if not state.root or not state.root:IsShown() then return end
      if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and ResourceResetMatches(...) then ResetResourceAfterCast() end
        return
      end
      if event == "UNIT_AURA" then
        if unit == "player" then UpdatePlayerState(false) end
        if unit == "target" then UpdateTargetDebuffs() end
        return
      end
      if event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_TARGET" and unit == "player") then
        UpdateTargetDebuffs(); return
      end
      if event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" or event == "UPDATE_SHAPESHIFT_USABLE" then
        UpdatePlayerState(false)
        return
      end
      if event == "UNIT_POWER" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER"
        or event == "UNIT_POWER_BAR_SHOW" or event == "UNIT_POWER_BAR_HIDE" then
        if unit and unit ~= "player" then return end
        if RUI.UpdatePrimaryPower then RUI:UpdatePrimaryPower(true) end
        local playerAuras = ReadAura("player", false)
        UpdateResource(playerAuras, false)
        UpdateUsableGlowsOnly()
        return
      end
      if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
        UpdateCooldownsOnly(); return
      end
      if event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "CHARACTER_POINTS_CHANGED" then
        if state.spellRefreshPending then return end
        state.spellRefreshPending = true
        RUI:After(0.15, function()
          state.spellRefreshPending = false
          if not state.root or not state.root:IsShown() then return end
          local _, changed = RUI:ScanSpellbook()
          if event ~= "SPELLS_CHANGED" then changed = true end
          if changed then
            if RUI.InvalidateRacialCache then RUI:InvalidateRacialCache() end
            BuildRows(true)
          end
          UpdateAll(true)
        end)
        return
      end
      if event == "PLAYER_ENTERING_WORLD" then
        BuildRows(true)
        UpdateAll(true)
        for _, delay in ipairs({0.10,0.50,1.00,2.00,4.00}) do
          RUI:After(delay, function() if state.root and state.root:IsShown() then UpdateAll(false) end end)
        end
      end
    end)

    state.timer = CreateFrame("Frame")
    state.timer:Hide()
    state.timer:SetScript("OnUpdate", function(_, delta)
      -- Cooldown text is intentionally lightweight and may update more often
      -- than aura scanning. This keeps RetreatUI aligned with ElvUI timers
      -- without reintroducing the expensive full-HUD refresh loop.
      state.cooldownElapsed = state.cooldownElapsed + delta
      state.auraElapsed = state.auraElapsed + delta

      if state.cooldownElapsed >= 0.10 then
        state.cooldownElapsed = 0
        UpdateCooldownTimersOnly()
      end

      if state.auraElapsed >= 0.20 then
        state.auraElapsed = 0
        UpdateProcTimers()
        if state.classStateTracker then state.classStateTracker:UpdateTimers() end
        UpdateTargetTimers()
      end
    end)
  end

  function module:activate()
    Build()
    state.root:Show()
    state.root:SetAlpha(1)
    state.events:Show()
    state.timer:Show()
    state.elapsed = 0
    state.cooldownElapsed = 0
    state.auraElapsed = 0
    state.resourceReady = false
    state.resourceNativeReady = false
    state.resourcePowerType = nil
    state.resourceForceZero = false
    BuildRows(true)
    UpdateAll(true)
    for _, delay in ipairs({0.10,0.50,1.00,2.00,4.00}) do
      RUI:After(delay, function() if state.root and state.root:IsShown() then UpdateAll(false) end end)
    end
    return true
  end

  function module:deactivate()
    if state.root then state.root:Hide() end
    if state.events then state.events:Hide() end
    if state.timer then state.timer:Hide() end
    state.elapsed = 0
    state.cooldownElapsed = 0
    state.auraElapsed = 0
    state.resourceReady = false
    state.resourceNativeReady = false
    state.resourcePowerType = nil
    state.resourceForceZero = false
    for _, frame in ipairs(state.procFrames) do frame:Hide() end
    for _, bar in ipairs(state.targetBars) do bar:Hide() end
    state.stanceAura = nil
    if state.stanceTracker then state.stanceTracker:Hide() end
    if state.classStateTracker then state.classStateTracker:Hide() end
    HideResource()
    if type(RUI.RestoreNativeResourceMirrorSources) == "function" then RUI:RestoreNativeResourceMirrorSources() end
  end

  RUI:RegisterClassModule(className, module)
  return module
end

RUI._advancedClassHUDLoaded = true

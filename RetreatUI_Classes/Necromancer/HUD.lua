local RUI = RetreatUI
if not RUI then return end

local CLASS_NAME = "Necromancer"
local W = RUI.HUDWidgets

local module = {
  ready = true,
  className = CLASS_NAME,
  frameName = "RetreatUINecromancerHUD",
  supportedLoadouts = {BASELINE=true, RIME=true, DEATH=true, ANIMATION=true},
  usesPrimaryPower = true,
}

local root, eventDriver, timerDriver
local procFrames = {}
local targetBars = {}
local lifeForceSegments = {}
local lifeForceReady = false
local lifeForceObservedMax = 3
local elapsed = 0
local spellRefreshPending = false

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function CoreDefinitions()
  return RUI:GetHUDSpellDefinitions(CLASS_NAME, "core")
end

local function UtilityDefinitions(forceRacialScan)
  local definitions, seen = {}, {}
  for _, definition in ipairs(RUI:GetHUDSpellDefinitions(CLASS_NAME, "utility") or {}) do
    definitions[#definitions + 1] = definition
    seen[Normalize(definition.name)] = true
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

local function BuildRows(forceRacialScan)
  if not root then return end
  W:BuildSpellRow(root.coreRow, CoreDefinitions(), 38, 1, Learned, Texture)
  W:BuildSpellRow(root.utilityRow, UtilityDefinitions(forceRacialScan), 32, 1, Learned, Texture)
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

local function ApplyProcGlows(playerAuras)
  if not root then return end
  local theme = RUI:GetTheme()
  for _, row in ipairs({root.coreRow, root.utilityRow}) do
    for _, icon in ipairs(row.icons or {}) do
      if icon:IsShown() and icon.definition then
        W:SetGlow(icon, nil, 0)
        local definition = icon.definition
        local aura = AnyAura(playerAuras, definition.glowWhenAura)
        if not aura then aura = AnyAura(playerAuras, definition.glowWhenAuraID) end
        if aura then
          local pulse = 0.74 + 0.26 * math.abs(math.sin(GetTime() * 8.0))
          W:SetBorder(icon, theme.accent2, 1)
          W:SetGlow(icon, theme.accent2, pulse)
          if icon.texture and icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
        end
      end
    end
  end
end

-------------------------------------------------------------------------------
-- Life Force mirror
-------------------------------------------------------------------------------
local LIFE_FORCE_ICON = "Interface\\Icons\\Spell_Shadow_AnimateDead"

local function CreateLifeForceSegment(index)
  local frame = CreateFrame("Frame", "RetreatUILifeForceSegment" .. tostring(index), root)
  frame:SetSize(25, 25)
  RUI:SkinFrame(frame, {0.01,0.02,0.01,0.98}, {0,0,0,1})

  frame.texture = frame:CreateTexture(nil, "ARTWORK")
  frame.texture:SetPoint("TOPLEFT", 1, -1)
  frame.texture:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.texture:SetTexture(LIFE_FORCE_ICON)
  frame.texture:SetTexCoord(0.08,0.92,0.08,0.92)

  frame.fill = frame:CreateTexture(nil, "BACKGROUND")
  frame.fill:SetPoint("TOPLEFT", 1, -1)
  frame.fill:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
  frame.fill:SetVertexColor(0.025,0.14,0.02,1)
  frame:Hide()
  return frame
end

local function EnsureLifeForceSegments(maximum)
  maximum = math.max(1, math.min(20, math.floor(tonumber(maximum) or 1)))
  while #lifeForceSegments < maximum do
    lifeForceSegments[#lifeForceSegments + 1] = CreateLifeForceSegment(#lifeForceSegments + 1)
  end

  local size = maximum > 12 and math.max(13, math.floor(330 / maximum)) or 25
  local spacing = 1
  local total = maximum * size + (maximum - 1) * spacing
  local firstX = -total / 2 + size / 2
  local y = (RUI.layout.demonfire and RUI.layout.demonfire.y) or -118

  for index, frame in ipairs(lifeForceSegments) do
    frame:ClearAllPoints()
    frame:SetSize(size, size)
    frame:SetPoint("CENTER", UIParent, "CENTER", firstX + (index - 1) * (size + spacing), y)
  end
end

local function SnapshotLifeForce(forceDiscovery)
  -- Ascension exposes Life Force as aura 805011 on supported builds. Use that
  -- live stack value first, while borrowing the maximum from the native resource
  -- snapshot when available. The native frame remains visible until one of these
  -- sources has returned a valid value.
  local auraCurrent, auraIcon
  if UnitBuff then
    for index = 1, 40 do
      local values = {UnitBuff("player", index)}
      local name = values[1]
      if not name then break end
      local spellID = tonumber(values[11])
      if spellID == 805011 or Normalize(name) == "life force" then
        auraCurrent = tonumber(values[4]) or 0
        auraIcon = values[3]
        break
      end
    end
  end

  local snapshot
  if RUI.ReadAscensionResourceSnapshot then
    snapshot = RUI:ReadAscensionResourceSnapshot(
      {"life force", "lifeforce"}, "LIFE FORCE", forceDiscovery == true
    )
  end

  local snapshotCurrent, snapshotMaximum, snapshotIcon
  if snapshot then
    snapshotCurrent = tonumber(snapshot.current)
    snapshotMaximum = tonumber(snapshot.maximum)
    snapshotIcon = snapshot.icon
    if (not snapshotMaximum or snapshotMaximum <= 0) and type(snapshot.segments) == "table" then
      snapshotMaximum = #snapshot.segments
    end
    if snapshotCurrent == nil and type(snapshot.segments) == "table" then
      snapshotCurrent = 0
      for _, segment in ipairs(snapshot.segments) do
        if segment.active then snapshotCurrent = snapshotCurrent + 1 end
      end
    end
  end

  if auraCurrent ~= nil then
    if snapshotMaximum and snapshotMaximum > 0 then
      lifeForceObservedMax = math.max(lifeForceObservedMax, snapshotMaximum)
    else
      lifeForceObservedMax = math.max(lifeForceObservedMax, auraCurrent)
    end
    return math.max(0, auraCurrent), math.max(1, lifeForceObservedMax), auraIcon or snapshotIcon
  end

  if snapshotMaximum and snapshotMaximum > 0 and snapshotCurrent ~= nil then
    lifeForceObservedMax = math.max(lifeForceObservedMax, snapshotMaximum)
    return math.max(0, snapshotCurrent), math.max(1, snapshotMaximum), snapshotIcon
  end

  if RUI.FindCustomPower then
    local found = RUI:FindCustomPower({
      excludeToken = "RUNICPOWER",
      minimumMax = 1,
      maximumMax = 20,
    })
    if found and tonumber(found.maximum) and tonumber(found.maximum) > 0 then
      lifeForceObservedMax = math.max(lifeForceObservedMax, tonumber(found.maximum))
      return math.max(0, tonumber(found.current) or 0), tonumber(found.maximum), nil
    end
  end

  return nil
end

local function HideLifeForce()
  if root and root.lifeForceLabel then root.lifeForceLabel:Hide() end
  for _, frame in ipairs(lifeForceSegments) do frame:Hide() end
end

local function UpdateLifeForce(forceDiscovery)
  if not root or not root:IsShown() then return end
  local current, maximum, texture = SnapshotLifeForce(forceDiscovery)
  if current == nil then
    lifeForceReady = false
    HideLifeForce()
    return
  end

  lifeForceReady = true
  current = math.max(0, math.min(maximum, math.floor(current + 0.5)))
  maximum = math.max(1, math.min(20, math.floor(maximum + 0.5)))
  EnsureLifeForceSegments(maximum)

  root.lifeForceLabel:SetText("LIFE FORCE  " .. tostring(current) .. " / " .. tostring(maximum))
  root.lifeForceLabel:Show()
  local theme = RUI:GetTheme()

  for index, frame in ipairs(lifeForceSegments) do
    if index <= maximum then
      local active = index <= current
      frame.texture:SetTexture(texture or LIFE_FORCE_ICON)
      frame.fill:SetVertexColor(
        active and 0.08 or 0.018,
        active and 0.58 or 0.11,
        active and 0.04 or 0.018,
        1
      )
      frame.texture:SetVertexColor(
        active and 0.55 or 0.25,
        active and 1.00 or 0.48,
        active and 0.30 or 0.25,
        1
      )
      if frame.texture.SetDesaturated then frame.texture:SetDesaturated(not active) end
      frame:SetAlpha(active and 1 or 0.34)
      frame:Show()
      frame:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], active and 1 or 0.35)
    else
      frame:Hide()
    end
  end
end

function module.customResourcesComplete()
  return lifeForceReady == true
end

-------------------------------------------------------------------------------
-- Proc / player aura trackers
-------------------------------------------------------------------------------
local function CreateProcFrame(index)
  local frame = W:CreateIcon(root, (RUI.layout.auraTrackers and RUI.layout.auraTrackers.size) or 30)
  frame.procIndex = index
  procFrames[index] = frame
  return frame
end

local function ProcDefinitions()
  return RUI:GetAuraTrackerDefinitions(CLASS_NAME) or {}
end

local function BuildProcLookup()
  local byName, byID = {}, {}
  for _, definition in ipairs(ProcDefinitions()) do
    local isClassState = RUI.IsClassStateAuraDefinition
      and RUI:IsClassStateAuraDefinition(CLASS_NAME, definition)
    if not isClassState then
      if definition.name then byName[Normalize(definition.name)] = definition end
      if definition.buff then byName[Normalize(definition.buff)] = definition end
      local definitionID = tonumber(definition.auraID) or tonumber(definition.id)
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

  local layout = RUI.layout.auraTrackers or {x=0,y=-83,size=30,spacing=3}
  local size, spacing = layout.size or 30, layout.spacing or 3
  local total = #active > 0 and (#active * size + (#active - 1) * spacing) or 0
  local theme = RUI:GetTheme()

  for index, item in ipairs(active) do
    local frame = procFrames[index] or CreateProcFrame(index)
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

  for index = #active + 1, #procFrames do
    procFrames[index].aura = nil
    procFrames[index]:Hide()
  end
end

local function UpdateProcTimers()
  for _, frame in ipairs(procFrames) do
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

-------------------------------------------------------------------------------
-- Active undead stance / form
-------------------------------------------------------------------------------
local STANCES = {
  ["undead: assault"] = "ASSAULT",
  ["undead assault"] = "ASSAULT",
  ["undead: protect"] = "PROTECT",
  ["undead protect"] = "PROTECT",
  ["undead: pacify"] = "PACIFY",
  ["undead pacify"] = "PACIFY",
}

local function MatchStance(name)
  local lower = Normalize(name)
  for key, label in pairs(STANCES) do
    if lower == key or string.find(lower, key, 1, true) then return label end
  end
  return nil
end

local function ActiveStance(playerAuras)
  local current = 0
  if GetShapeshiftForm then
    local ok, value = pcall(GetShapeshiftForm)
    if ok then current = tonumber(value) or 0 end
  end
  if GetNumShapeshiftForms and GetShapeshiftFormInfo then
    local ok, count = pcall(GetNumShapeshiftForms)
    count = ok and tonumber(count) or 0
    for index = 1, count do
      local success, texture, name, active = pcall(GetShapeshiftFormInfo, index)
      if success then
        local label = MatchStance(name)
        if label and (active == true or active == 1 or index == current) then
          return label, name, texture
        end
      end
    end
  end
  for _, aura in ipairs(playerAuras.list or {}) do
    local label = MatchStance(aura.name)
    if label then return label, aura.name, aura.icon end
  end
  return nil
end

local function UpdateStance(playerAuras)
  if not root or not root.stance then return end
  local label, name, texture = ActiveStance(playerAuras)
  if not label then
    root.stance:Hide()
    return
  end
  W:SetFormTracker(root.stance, label, texture or select(3, GetSpellInfo(name or "")), RUI:GetTheme().accent2)
end

-------------------------------------------------------------------------------
-- Target debuff bars
-------------------------------------------------------------------------------
local function TargetFrameAnchor()
  return _G.ElvUF_Target or _G.TargetFrame or nil
end

local function TargetDebuffLookup()
  local byName, byID = {}, {}
  for _, definition in ipairs(RUI:GetTargetDebuffDefinitions(CLASS_NAME) or {}) do
    local order = tonumber(definition.order) or 999
    if definition.name then byName[Normalize(definition.name)] = {order=order, definition=definition} end
    if definition.id then byID[tonumber(definition.id)] = {order=order, definition=definition} end
    for _, alias in ipairs(definition.aliases or {}) do
      byName[Normalize(alias)] = {order=order, definition=definition}
    end
  end
  return byName, byID
end

local function IsOwnCaster(caster)
  if caster == "player" or caster == "pet" or caster == "vehicle" then return true end
  local playerName = UnitName and UnitName("player")
  if playerName and caster == playerName then return true end
  -- Ascension sometimes returns no caster for custom auras. Since we already
  -- filter against a strict Necromancer whitelist, accept nil rather than miss
  -- the player's disease entirely.
  return caster == nil
end

local function CollectTargetDebuffs()
  local result = {}
  if not UnitExists or not UnitExists("target") or not UnitDebuff then return result end
  local byName, byID = TargetDebuffLookup()

  for index = 1, 40 do
    local values = {UnitDebuff("target", index)}
    local name = values[1]
    if not name then break end
    local spellID = tonumber(values[11])
    local match = (spellID and byID[spellID]) or byName[Normalize(name)]
    if match and IsOwnCaster(values[8]) then
      result[#result + 1] = {
        name=name,
        icon=values[3],
        count=tonumber(values[4]) or 0,
        debuffType=values[5],
        duration=tonumber(values[6]) or 0,
        expires=tonumber(values[7]) or 0,
        caster=values[8],
        spellID=spellID,
        order=match.order,
      }
    end
  end

  table.sort(result, function(left, right)
    if left.order ~= right.order then return left.order < right.order end
    local a = left.expires > 0 and left.expires or math.huge
    local b = right.expires > 0 and right.expires or math.huge
    if a ~= b then return a < b end
    return tostring(left.name) < tostring(right.name)
  end)
  return result
end

local function BarTexture()
  if ElvUI then
    local E = unpack(ElvUI)
    if E and E.media and E.media.normTex then return E.media.normTex end
  end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function CreateTargetBar(index)
  local bar = CreateFrame("StatusBar", "RetreatUINecromancerTargetAuraBar" .. tostring(index), root)
  bar:SetHeight(16)
  bar:SetStatusBarTexture(BarTexture())
  bar:SetMinMaxValues(0,1)
  bar:SetValue(1)
  RUI:SkinFrame(bar, {0.015,0.025,0.012,0.96}, {0,0,0,1})

  bar.icon = bar:CreateTexture(nil, "ARTWORK")
  bar.icon:SetSize(14,14)
  bar.icon:SetPoint("LEFT",1,0)
  bar.icon:SetTexCoord(0.08,0.92,0.08,0.92)

  bar.nameText = bar:CreateFontString(nil, "OVERLAY")
  bar.nameText:SetPoint("LEFT", bar.icon, "RIGHT", 4, 0)
  bar.nameText:SetPoint("RIGHT", bar, "RIGHT", -47, 0)
  bar.nameText:SetJustifyH("LEFT")
  RUI:ApplyFont(bar.nameText, 10, "OUTLINE")

  bar.timeText = bar:CreateFontString(nil, "OVERLAY")
  bar.timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
  bar.timeText:SetJustifyH("RIGHT")
  RUI:ApplyFont(bar.timeText, 10, "OUTLINE")

  bar.stackText = bar:CreateFontString(nil, "OVERLAY")
  bar.stackText:SetPoint("BOTTOMRIGHT", bar.icon, "BOTTOMRIGHT", 0, 0)
  RUI:ApplyFont(bar.stackText, 8, "OUTLINE")
  bar:Hide()
  return bar
end

local function PositionTargetBar(bar, index)
  local targetFrame = TargetFrameAnchor()
  local width = 260
  if targetFrame and targetFrame.GetWidth then
    local ok, measured = pcall(targetFrame.GetWidth, targetFrame)
    if ok and tonumber(measured) and measured > 0 then width = measured end
  end
  width = math.max(190, math.min(340, width))
  bar:SetWidth(width)
  bar:ClearAllPoints()
  if targetFrame then
    bar:SetPoint("BOTTOMLEFT", targetFrame, "TOPLEFT", 0, 4 + (index - 1) * 18)
  else
    local fallback = RUI.layout.targetDebuffs or {x=310,y=-59}
    bar:SetPoint("BOTTOM", UIParent, "CENTER", fallback.x or 310, (fallback.y or -59) + 30 + (index - 1) * 18)
  end
end

local function UpdateTargetDebuffs()
  local auras = CollectTargetDebuffs()
  local maximum = math.min(#auras, 8)
  local theme = RUI:GetTheme()

  for index = 1, maximum do
    local aura = auras[index]
    local bar = targetBars[index]
    if not bar then
      bar = CreateTargetBar(index)
      targetBars[index] = bar
    end
    bar.aura = aura
    PositionTargetBar(bar, index)

    local remaining = aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
    if aura.duration > 0 and aura.expires > 0 then
      bar:SetMinMaxValues(0, aura.duration)
      bar:SetValue(math.min(aura.duration, remaining))
    else
      bar:SetMinMaxValues(0,1)
      bar:SetValue(1)
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

  for index = maximum + 1, #targetBars do
    targetBars[index].aura = nil
    targetBars[index]:Hide()
  end
end

local function UpdateTargetTimers()
  for _, bar in ipairs(targetBars) do
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

-------------------------------------------------------------------------------
-- Update and lifecycle
-------------------------------------------------------------------------------
local function UpdatePlayerState(forceResourceDiscovery)
  if not root or not root:IsShown() then return end
  local playerAuras = ReadAura("player", false)
  W:UpdateSpellRow(root.coreRow, function(reference) return FindAura(playerAuras, reference) end)
  W:UpdateSpellRow(root.utilityRow, function(reference) return FindAura(playerAuras, reference) end)
  ApplyProcGlows(playerAuras)
  UpdateProcTrackers(playerAuras)
  UpdateStance(playerAuras)
  if root.classStateTracker then root.classStateTracker:Update(playerAuras) end
  if root.guardianHUD then root.guardianHUD:Refresh(playerAuras, false) end
  UpdateLifeForce(forceResourceDiscovery)
end

local function UpdateCooldownsOnly()
  if not root or not root:IsShown() then return end
  local playerAuras = ReadAura("player", false)
  W:UpdateSpellRow(root.coreRow, function(reference) return FindAura(playerAuras, reference) end)
  W:UpdateSpellRow(root.utilityRow, function(reference) return FindAura(playerAuras, reference) end)
  ApplyProcGlows(playerAuras)
end

local function UpdateAll(forceResourceDiscovery)
  if not root or not root:IsShown() then return end
  if RUI.UpdatePrimaryPower then RUI:UpdatePrimaryPower(true) end
  UpdatePlayerState(forceResourceDiscovery)
  UpdateTargetDebuffs()
end

local function Build()
  if root then return end
  root = CreateFrame("Frame", module.frameName, UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("MEDIUM")

  root.lifeForceLabel = root:CreateFontString(nil, "OVERLAY")
  root.lifeForceLabel:SetPoint("CENTER", UIParent, "CENTER", 0, ((RUI.layout.demonfire and RUI.layout.demonfire.y) or -118) + 22)
  RUI:ApplyFont(root.lifeForceLabel, 8, "OUTLINE")
  local theme = RUI:GetTheme()
  root.lifeForceLabel:SetTextColor(theme.accent[1],theme.accent[2],theme.accent[3],1)
  root.lifeForceLabel:Hide()

  root.stance = W:CreateFormTracker(root, {
    x=-195,
    y=(RUI.layout.demonfire and RUI.layout.demonfire.y) or -118,
    size=38,
    width=90,
    height=58,
  })
  if RUI.CreateClassStateTracker then
    root.classStateTracker = RUI:CreateClassStateTracker(root, CLASS_NAME, {
      x=-295,
      y=(RUI.layout.demonfire and RUI.layout.demonfire.y) or -118,
      size=38, width=90, height=58, maxStates=4,
      excludePrefixes={"Undead: "},
      excludeNames={"Undead Assault", "Undead Protect", "Undead Pacify"},
    })
  end

  if RUI.NecromancerGuardianHUD and RUI.NecromancerGuardianHUD.Create then
    root.guardianHUD = RUI.NecromancerGuardianHUD:Create(root, function()
      return ReadAura("player", false)
    end)
  end

  root.coreRow = CreateFrame("Frame", nil, root)
  root.coreRow:SetSize(560,38)
  root.coreRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.core.x, RUI.layout.core.y)

  root.utilityRow = CreateFrame("Frame", nil, root)
  root.utilityRow:SetSize(560,32)
  root.utilityRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.utility.x, RUI.layout.utility.y)

  BuildRows(false)

  eventDriver = CreateFrame("Frame")
  for _, eventName in ipairs({
    "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE",
    "UNIT_AURA", "PLAYER_TARGET_CHANGED", "UNIT_TARGET",
    "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN",
    "UNIT_POWER", "UNIT_POWER_FREQUENT", "UNIT_DISPLAYPOWER",
    "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_USABLE",
    "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
  }) do pcall(eventDriver.RegisterEvent, eventDriver, eventName) end
  if GetSpellCharges then pcall(eventDriver.RegisterEvent, eventDriver, "SPELL_UPDATE_CHARGES") end

  eventDriver:SetScript("OnEvent", function(_, event, ...)
    if not root or not root:IsShown() then return end
    local unit = ...

    if root.guardianHUD then root.guardianHUD:HandleEvent(event, ...) end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" or event == "UNIT_HEALTH" or
       event == "UNIT_MAXHEALTH" or event == "NAME_PLATE_UNIT_ADDED" or
       event == "NAME_PLATE_UNIT_REMOVED" then
      return
    end

    if event == "UNIT_AURA" then
      if unit == "player" then UpdatePlayerState(false) end
      if unit == "target" then UpdateTargetDebuffs() end
      return
    end

    if event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_TARGET" and unit == "player") then
      UpdateTargetDebuffs()
      return
    end

    if event == "UNIT_POWER" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER" then
      if unit and unit ~= "player" then return end
      if RUI.UpdatePrimaryPower then RUI:UpdatePrimaryPower(true) end
      UpdateLifeForce(false)
      return
    end

    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
      UpdateCooldownsOnly()
      return
    end

    if event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" or event == "UPDATE_SHAPESHIFT_USABLE" then
      local playerAuras = ReadAura("player", false)
      UpdateStance(playerAuras)
      if root.classStateTracker then root.classStateTracker:Update(playerAuras) end
      return
    end

    if event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
      if spellRefreshPending then return end
      spellRefreshPending = true
      RUI:After(0.15, function()
        spellRefreshPending = false
        if not root or not root:IsShown() then return end
        local _, changed = RUI:ScanSpellbook()
        if event == "PLAYER_TALENT_UPDATE" then changed = true end
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
        RUI:After(delay, function()
          if root and root:IsShown() then UpdateAll(true) end
        end)
      end
    end
  end)

  timerDriver = CreateFrame("Frame")
  timerDriver:Hide()
  timerDriver:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.10 then return end
    elapsed = 0
    UpdateCooldownsOnly()
    UpdateProcTimers()
    if root and root.classStateTracker then root.classStateTracker:UpdateTimers() end
    UpdateTargetTimers()
    if root and root.guardianHUD then root.guardianHUD:Update() end
    UpdateLifeForce(false)
  end)
end

function module:activate()
  Build()
  root:Show()
  root:SetAlpha(1)
  if root.guardianHUD then root.guardianHUD:Activate() end
  eventDriver:Show()
  timerDriver:Show()
  elapsed = 0
  lifeForceReady = false
  BuildRows(true)
  UpdateAll(true)
  for _, delay in ipairs({0.10,0.50,1.00,2.00,4.00}) do
    RUI:After(delay, function()
      if root and root:IsShown() then UpdateAll(true) end
    end)
  end
  return true
end

function module:deactivate()
  if root and root.classStateTracker then root.classStateTracker:Hide() end
  if root and root.guardianHUD then root.guardianHUD:Deactivate() end
  if root then root:Hide() end
  if eventDriver then eventDriver:Hide() end
  if timerDriver then timerDriver:Hide() end
  elapsed = 0
  lifeForceReady = false
  for _, frame in ipairs(procFrames) do frame:Hide() end
  for _, bar in ipairs(targetBars) do bar:Hide() end
  HideLifeForce()
end

RUI:RegisterClassModule(CLASS_NAME, module)

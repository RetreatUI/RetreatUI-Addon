local RUI = RetreatUI
local W = RUI.HUDWidgets
local CLASS_NAME = "Bloodmage"

local module = {
  ready = true,
  className = CLASS_NAME,
  frameName = "RetreatUIBloodmageHUD",
  supportedLoadouts = {TANK=true},
  usesPrimaryPower = true,
}

local root, driver, timerDriver
local targetAuraBars = {}
local elapsed = 0
local lastFormKey, lastCombatState
local eternalCurseLearned = false
local pendingRowRefresh = false
local pendingSpellbookRefresh = false
local targetBarsPositioned = false

local function CombatLocked()
  return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end


local function Aura(unit, wanted, debuff)
  local getter = debuff and UnitDebuff or UnitBuff
  if not getter or not unit or not wanted then return nil end
  for index = 1, 40 do
    local values = {getter(unit, index)}
    local name = values[1]
    if not name then break end
    if name == wanted then
      return {
        name=name, icon=values[3], count=values[4] or 0,
        duration=values[6] or 0, expires=values[7] or 0,
        caster=values[8], spellID=values[11], raw=values,
      }
    end
  end
end

local function PlayerAura(name)
  return Aura("player", name, false) or Aura("player", name, true)
end

local function StrictTexture(definition)
  if not definition then return nil end
  return W:ResolveStrictSpellTexture(definition)
end

local function SpellTexture(name, exactID, aliases)
  return StrictTexture({name=name, id=exactID, aliases=aliases})
end

local function RefreshEternalCurseState()
  local learned = false
  if RUI.IsSpellIDLearned then learned = RUI:IsSpellIDLearned(800157) == true end
  if not learned and RUI.IsSpellLearned then learned = RUI:IsSpellLearned("Eternal Curse") == true end
  eternalCurseLearned = learned
  return learned
end

local function HasEternalCurse()
  return eternalCurseLearned == true
end

local function ActiveForm()
  -- Eternal Curse permanently locks Bloodmage into Cursed Form. Ascension does
  -- not expose a normal stance aura in that state, so detect the talent first.
  if HasEternalCurse() then return "Cursed Form", nil, nil end
  if GetNumShapeshiftForms and GetShapeshiftFormInfo then
    local current = GetShapeshiftForm and GetShapeshiftForm() or 0
    local count = GetNumShapeshiftForms() or 0
    for index = 1, count do
      local texture, name, active = GetShapeshiftFormInfo(index)
      local lower = name and string.lower(name) or ""
      if lower == "cursed form" or lower == "blood curse" then
        if active == true or active == 1 or index == current then
          return "Cursed Form", texture, PlayerAura("Cursed Form") or PlayerAura("Blood Curse")
        end
      end
    end
  end

  local cursed = PlayerAura("Cursed Form") or PlayerAura("Blood Curse")
  if cursed then return "Cursed Form", cursed.icon, cursed end
  return "Mortal Form", SpellTexture("Blood Curse", 562720), nil
end

local function InCursedForm()
  return ActiveForm() == "Cursed Form"
end

local function InCombat()
  if UnitAffectingCombat then return UnitAffectingCombat("player") and true or false end
  if InCombatLockdown then return InCombatLockdown() and true or false end
  return false
end

local function DefinitionAllowed(definition)
  if not definition then return false end
  local form = InCursedForm() and "Cursed Form" or "Mortal Form"
  if definition.requiresForm and definition.requiresForm ~= form then return false end
  if definition.hideInCombat and InCombat() then return false end
  return true
end

local function Definitions(row, forceRacialScan)
  local result, seen = {}, {}
  local source = RUI:GetTankHUDDefinitions(CLASS_NAME, row) or {}
  for _, definition in ipairs(source) do
    if DefinitionAllowed(definition) then
      result[#result + 1] = definition
      seen[string.lower(definition.name or "")] = true
    end
  end
  if row == "utility" and RUI.GetRacialSpellDefinitions then
    for _, racial in ipairs(RUI:GetRacialSpellDefinitions(forceRacialScan)) do
      local key = string.lower(racial.name or "")
      if key ~= "" and not seen[key] then
        racial.category = "racial"
        racial.hudRow = "utility"
        racial.order = 900
        result[#result + 1] = racial
        seen[key] = true
      end
    end
  end
  return result
end

local function TargetDebuffDefinitions()
  return RUI:GetTargetDebuffDefinitions(CLASS_NAME) or {}
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
  if not root then return false end
  if CombatLocked() then
    pendingRowRefresh = true
    return false
  end
  W:BuildSpellRow(root.coreRow, Definitions("core", false), 38, 1, Learned, DefinitionTexture)
  W:BuildSpellRow(root.utilityRow, Definitions("utility", forceRacialScan), 32, 1, Learned, DefinitionTexture)
  pendingRowRefresh = false
  return true
end

local function IsOwnAura(aura)
  if not aura then return false end
  if aura.caster == "player" then return true end
  if aura.caster and UnitIsUnit then
    local ok, same = pcall(UnitIsUnit, aura.caster, "player")
    if ok and same then return true end
  end
  -- Some Ascension aura records do not expose a caster. Blood Bond is unique
  -- enough that an uncategorised copy on a group member is still useful.
  return aura.caster == nil
end

local function BondUnits()
  local units = {"player", "target", "focus", "mouseover"}
  if GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0 then
    for index = 1, 40 do units[#units + 1] = "raid" .. tostring(index) end
  else
    for index = 1, 4 do units[#units + 1] = "party" .. tostring(index) end
  end
  return units
end

local function FindBloodBondTarget()
  local seen = {}
  for _, unit in ipairs(BondUnits()) do
    if not seen[unit] and UnitExists and UnitExists(unit) then
      seen[unit] = true
      local aura = Aura(unit, "Blood Bond", false)
      if aura and IsOwnAura(aura) then
        return unit, aura
      end
    end
  end
end

local function UpdateBloodBond()
  if not (RUI.IsSpellLearned and RUI:IsSpellLearned("Blood Bond")) then
    root.bondTracker:Hide()
    return
  end

  local unit, aura = FindBloodBondTarget()
  root.bondTracker:Show()
  local bondTexture = (aura and aura.icon) or SpellTexture("Blood Bond")
  if bondTexture then
    root.bondTracker.icon.texture:SetTexture(bondTexture)
    root.bondTracker.icon:Show()
  else
    root.bondTracker.icon:Hide()
  end

  if unit then
    local name = UnitName and UnitName(unit) or "BONDED ALLY"
    local classToken
    if UnitClass then
      local _, token = UnitClass(unit)
      classToken = token
    end
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    root.bondTracker.nameText:SetText(name or "BONDED ALLY")
    root.bondTracker.nameText:SetTextColor(color and color.r or 1, color and color.g or 0.35, color and color.b or 0.35, 1)
    if root.bondTracker.icon.texture.SetDesaturated then root.bondTracker.icon.texture:SetDesaturated(false) end
    root.bondTracker.icon:SetAlpha(1)
    W:SetBorder(root.bondTracker.icon, RUI:GetTheme().accent, 1)
  else
    root.bondTracker.nameText:SetText("NO BOND")
    root.bondTracker.nameText:SetTextColor(1, 0.22, 0.16, 1)
    if root.bondTracker.icon.texture.SetDesaturated then root.bondTracker.icon.texture:SetDesaturated(true) end
    root.bondTracker.icon:SetAlpha(0.48)
    W:SetBorder(root.bondTracker.icon, {0.55, 0.08, 0.10, 1}, 1)
  end
end

local function CreateBondTracker(x, iconY)
  local frame = CreateFrame("Frame", nil, root)
  -- Blood Bond and Mortal/Cursed Form are a matched resource pair: identical
  -- icon size, identical height and equal distance from the screen centre.
  frame:SetSize(116, 64)
  frame:SetPoint("CENTER", UIParent, "CENTER", x or -70, (iconY or -118) - 10)
  frame.icon = W:CreateIcon(frame, 38)
  frame.icon:ClearAllPoints()
  frame.icon:SetPoint("CENTER", frame, "CENTER", 0, 10)
  frame.icon.cooldownText:SetText("")
  frame.icon.stackText:SetText("")
  -- WoW 3.3.5/Ascension requires a FontString to have a font before SetText.
  frame.labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.labelText:SetPoint("TOP", frame.icon, "BOTTOM", 0, -2)
  frame.labelText:SetWidth(116)
  frame.labelText:SetJustifyH("CENTER")
  RUI:ApplyFont(frame.labelText, 8, "OUTLINE")
  frame.labelText:SetText("BLOOD BOND")
  local accent = RUI:GetTheme().accent
  frame.labelText:SetTextColor(accent[1], accent[2], accent[3], 1)
  frame.nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.nameText:SetPoint("TOP", frame.labelText, "BOTTOM", 0, -1)
  frame.nameText:SetWidth(116)
  frame.nameText:SetJustifyH("CENTER")
  RUI:ApplyFont(frame.nameText, 10, "OUTLINE")
  frame:Hide()
  return frame
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
    local aura = PlayerAura(name)
    if not aura and type(definition.auraNames) == "table" then
      for _, auraName in ipairs(definition.auraNames) do
        aura = PlayerAura(auraName)
        if aura then break end
      end
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
    tracker:ClearAllPoints()
    tracker:SetPoint("CENTER", UIParent, "CENTER", (layout.x or 0) - total / 2 + size / 2 + (index - 1) * (size + spacing), y)
    tracker.texture:SetTexture(aura.icon or DefinitionTexture(tracker.definition))
    tracker.stackText:SetText(aura.count and aura.count > 1 and tostring(aura.count) or "")
    if aura.expires and aura.expires > 0 then
      local remain = math.max(0, aura.expires - GetTime())
      tracker.cooldownText:SetText(W:FormatCooldown(remain))
      tracker.cooldownText:SetTextColor(1, remain <= 3 and 0.25 or 0.95, remain <= 3 and 0.15 or 0.35, 1)
    else
      tracker.cooldownText:SetText("")
    end
    local alpha = 0.52 + 0.48 * math.abs(math.sin(GetTime() * 5))
    W:SetBorder(tracker, RUI:GetTheme().accent2, alpha)
    tracker:SetAlpha(1)
    tracker:Show()
  end
end

local function TargetHasBiteWound()
  local aura = Aura("target", "Bite Wound", true)
  if not aura then return false end
  return IsOwnAura(aura)
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
    local spellID = tonumber(values[11])
    local configuredOrder = (spellID and byID[spellID]) or byName[string.lower(name)]
    -- Ascension occasionally omits the caster on class mechanics. Registered
    -- Bloodmage target debuffs still belong in the tracker in that case.
    if IsOwnDebuffCaster(caster) or (caster == nil and configuredOrder ~= nil) then
      shown[#shown + 1] = {
        name = name,
        icon = values[3],
        count = tonumber(values[4]) or 0,
        debuffType = values[5],
        duration = tonumber(values[6]) or 0,
        expires = tonumber(values[7]) or 0,
        caster = caster,
        spellID = spellID,
        order = configuredOrder or 999,
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
  local bar = CreateFrame("StatusBar", "RetreatUIBloodmageTargetAuraBar" .. tostring(index), root)
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
  if not bar or CombatLocked() then return false end
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
  return true
end

local function PositionAllTargetAuraBars()
  if CombatLocked() then
    targetBarsPositioned = false
    return false
  end
  for index = 1, 7 do
    if not targetAuraBars[index] then targetAuraBars[index] = CreateTargetAuraBar(index) end
    PositionTargetAuraBar(targetAuraBars[index], index)
  end
  targetBarsPositioned = true
  return true
end

local function UpdateTargetDebuffs()
  if not targetBarsPositioned and not CombatLocked() then PositionAllTargetAuraBars() end
  local shown = CollectOwnTargetDebuffs()
  local maximum = math.min(#shown, 7)
  local theme = RUI:GetTheme()

  for index = 1, maximum do
    local aura = shown[index]
    if not targetAuraBars[index] then
      if CombatLocked() then break end
      targetAuraBars[index] = CreateTargetAuraBar(index)
      PositionTargetAuraBar(targetAuraBars[index], index)
    end
    local bar = targetAuraBars[index]
    bar.aura = aura

    local remaining = aura.expires > 0 and math.max(0, aura.expires - GetTime()) or 0
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
    bar.timeText:SetText(remaining > 0.05 and W:FormatCooldown(remaining) or "")
    bar.stackText:SetText(aura.count and aura.count > 1 and tostring(aura.count) or "")
    bar:Show()
  end

  for index = maximum + 1, #targetAuraBars do
    targetAuraBars[index].aura = nil
    targetAuraBars[index]:Hide()
  end
end

local function ApplyDecisionHighlights()
  local hasBite = TargetHasBiteWound()
  for _, row in ipairs({root.coreRow, root.utilityRow}) do
    for _, icon in ipairs(row.icons or {}) do
      if icon:IsShown() and icon.definition then
        local name = icon.definition.name
        W:SetGlow(icon, nil, 0)
        if name == "Bloodfang Bite" and not hasBite and UnitExists and UnitExists("target") then
          local alpha = 0.40 + 0.60 * math.abs(math.sin(GetTime() * 6))
          W:SetBorder(icon, RUI:GetTheme().accent, alpha)
          W:SetGlow(icon, RUI:GetTheme().accent, alpha * 0.60)
        end
      end
    end
  end
end

local function UpdateRows()
  W:UpdateSpellRow(root.coreRow, PlayerAura)
  W:UpdateSpellRow(root.utilityRow, PlayerAura)
  ApplyDecisionHighlights()
end

local function RefreshConditionalRows(forceRacialScan)
  local form = InCursedForm() and "cursed" or "mortal"
  local combat = InCombat() and "combat" or "safe"
  if forceRacialScan or form ~= lastFormKey or combat ~= lastCombatState or pendingRowRefresh then
    lastFormKey, lastCombatState = form, combat
    if CombatLocked() then
      pendingRowRefresh = true
      return false
    end
    return BuildRows(forceRacialScan == true)
  end
  return true
end

local function UpdateAll()
  if not root then return end
  RefreshConditionalRows(false)
  UpdateBloodBond()
  UpdateRows()
  UpdateAuraTrackers()
  UpdateTargetDebuffs()
end

local function Build()
  if root then return end
  root = CreateFrame("Frame", "RetreatUIBloodmageHUD", UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("MEDIUM")


  local resourceTrackerY = (RUI.layout and RUI.layout.demonfire and RUI.layout.demonfire.y) or -118
  root.bondTracker = CreateBondTracker(0, resourceTrackerY)

  root.coreRow = CreateFrame("Frame", nil, root)
  root.coreRow:SetSize(620, 38)
  root.coreRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.core.x, RUI.layout.core.y)

  root.utilityRow = CreateFrame("Frame", nil, root)
  root.utilityRow:SetSize(620, 32)
  root.utilityRow:SetPoint("CENTER", UIParent, "CENTER", RUI.layout.utility.x, RUI.layout.utility.y)

  root.trackers = {}
  local allowed = {
      ["Saturating Sutures"]=true,
      ["Blood Rush"]=true,
      ["Enraging Howls"]=true,
      ["Call of the Darkwing"]=true,
      ["Monstrous Hunger"]=true,
  }
  for _, definition in ipairs(RUI:GetAuraTrackerDefinitions(CLASS_NAME) or {}) do
    if allowed[definition.name] then root.trackers[#root.trackers + 1] = CreateAuraTracker(definition) end
  end

  RefreshEternalCurseState()
  PositionAllTargetAuraBars()
  BuildRows(true)

  driver = CreateFrame("Frame")
  for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED",
    "UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PARTY_MEMBERS_CHANGED",
    "RAID_ROSTER_UPDATE", "GROUP_ROSTER_UPDATE", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
    "ACTIONBAR_UPDATE_COOLDOWN", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  }) do pcall(driver.RegisterEvent, driver, event) end

  driver:SetScript("OnEvent", function(_, event, unit)
    if not root or not root:IsShown() then return end
    if event == "UNIT_AURA" and unit and unit ~= "player" and unit ~= "target" and not string.find(unit, "party", 1, true) and not string.find(unit, "raid", 1, true) then return end

    if event == "PLAYER_REGEN_DISABLED" then
      -- Never rebuild rows or move frames after combat lockdown begins.
      lastCombatState = "combat"
      pendingRowRefresh = true
      UpdateBloodBond()
      UpdateRows()
      UpdateAuraTrackers()
      UpdateTargetDebuffs()
      return
    end

    if event == "PLAYER_REGEN_ENABLED" then
      if pendingSpellbookRefresh and RUI.ScanSpellbook then RUI:ScanSpellbook() end
      RefreshEternalCurseState()
      if pendingSpellbookRefresh and RUI.InvalidateRacialCache then RUI:InvalidateRacialCache() end
      pendingSpellbookRefresh = false
      lastFormKey, lastCombatState = nil, nil
      targetBarsPositioned = false
      PositionAllTargetAuraBars()
      RefreshConditionalRows(true)
      UpdateAll()
      return
    end

    if event == "SPELLS_CHANGED" or event == "PLAYER_LEVEL_UP" or event == "CHARACTER_POINTS_CHANGED" then
      RUI:After(0.15, function()
        if CombatLocked() then
          pendingSpellbookRefresh = true
          pendingRowRefresh = true
          return
        end
        if RUI.ScanSpellbook then RUI:ScanSpellbook() end
        RefreshEternalCurseState()
        if RUI.InvalidateRacialCache then RUI:InvalidateRacialCache() end
        pendingSpellbookRefresh = false
        lastFormKey, lastCombatState = nil, nil
        RefreshConditionalRows(true)
        UpdateAll()
      end)
      return
    end

    if event == "PLAYER_ENTERING_WORLD" and not CombatLocked() then
      targetBarsPositioned = false
      PositionAllTargetAuraBars()
    end
    UpdateAll()
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
  lastFormKey, lastCombatState = nil, nil
  pendingRowRefresh = false
  pendingSpellbookRefresh = false
  RefreshEternalCurseState()
  targetBarsPositioned = false
  PositionAllTargetAuraBars()
  RefreshConditionalRows(true)
  UpdateAll()
  return true
end

function module:deactivate()
  if root then root:Hide() end
  if driver then driver:Hide() end
  if timerDriver then timerDriver:Hide() end
end

RUI:RegisterClassModule(CLASS_NAME, module)

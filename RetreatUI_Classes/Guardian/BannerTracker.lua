local RUI = RetreatUI
if not RUI then return end

local tracker
local activeFallback
local elapsed = 0

local KNOWN_DURATIONS = {
  ["standard of valiance"] = 20,
  ["standard of recovery"] = 300,
}

local function Normalize(value)
  value = string.lower(tostring(value or "")):gsub("’", "'")
  return value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function IsStandard(name)
  return string.find(Normalize(name), "standard of ", 1, true) == 1
end

local function ShortName(name)
  local result = tostring(name or "STANDARD")
  result = result:gsub("^[Ss][Tt][Aa][Nn][Dd][Aa][Rr][Dd] [Oo][Ff] ", "")
  return string.upper(result)
end

local function ThemeColor(key, fallback)
  local theme = RUI.GetTheme and RUI:GetTheme() or nil
  local color = theme and theme[key]
  if type(color) ~= "table" then color = fallback end
  return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

local function PowerTexture()
  if ElvUI then
    local E = unpack(ElvUI)
    if E and E.media and E.media.normTex then return E.media.normTex end
  end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function CreateTracker()
  if tracker then return tracker end

  tracker = CreateFrame("Frame", "RetreatUIGuardianBannerTracker", UIParent)
  tracker:SetSize(204, 20)
  tracker:SetFrameStrata("MEDIUM")
  tracker:SetClampedToScreen(true)

  tracker.background = tracker:CreateTexture(nil, "BACKGROUND")
  tracker.background:SetAllPoints(tracker)
  tracker.background:SetTexture("Interface\\Buttons\\WHITE8X8")
  tracker.background:SetVertexColor(0.03, 0.03, 0.04, 0.92)

  tracker.icon = tracker:CreateTexture(nil, "ARTWORK")
  tracker.icon:SetPoint("TOPLEFT", tracker, "TOPLEFT", 1, -1)
  tracker.icon:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMLEFT", 19, 1)
  tracker.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  tracker.bar = CreateFrame("StatusBar", nil, tracker)
  tracker.bar:SetPoint("TOPLEFT", tracker.icon, "TOPRIGHT", 2, 0)
  tracker.bar:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", -1, 1)
  tracker.bar:SetStatusBarTexture(PowerTexture())
  tracker.bar:SetMinMaxValues(0, 1)
  tracker.bar:SetValue(1)
  local r, g, b = ThemeColor("accent2", {0.95, 0.55, 0.12, 1})
  tracker.bar:SetStatusBarColor(r, g, b, 0.88)

  tracker.text = tracker.bar:CreateFontString(nil, "OVERLAY")
  tracker.text:SetPoint("LEFT", tracker.bar, "LEFT", 5, 0)
  tracker.text:SetPoint("RIGHT", tracker.bar, "RIGHT", -5, 0)
  tracker.text:SetJustifyH("CENTER")
  if RUI.ApplyFont then RUI:ApplyFont(tracker.text, 9, "OUTLINE") end

  tracker.border = CreateFrame("Frame", nil, tracker)
  tracker.border:SetPoint("TOPLEFT", tracker, "TOPLEFT", -1, 1)
  tracker.border:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", 1, -1)
  if RUI.SkinFrame then
    RUI:SkinFrame(tracker.border, {0, 0, 0, 0}, {0, 0, 0, 1})
  end

  tracker:Hide()
  return tracker
end

local function PositionTracker()
  local frame = CreateTracker()
  frame:ClearAllPoints()

  local root = _G.RetreatUIGuardianHUD
  local anchor = root and root.coreRow or root
  if anchor and type(anchor.SetPoint) == "function" then
    frame:SetPoint("BOTTOM", anchor, "TOP", 0, 8)
    return
  end

  local power = RUI.layout and RUI.layout.power or {x=0, y=-152, height=16}
  frame:SetPoint("CENTER", UIParent, "CENTER",
    tonumber(power.x) or 0,
    (tonumber(power.y) or -152) + (tonumber(power.height) or 16) / 2 + 70)
end

local function GuardianHUDActive()
  if type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() ~= "Guardian" then return false end
  if type(RUI.IsInstallerModuleEnabled) == "function" and not RUI:IsInstallerModuleEnabled("classHUD") then return false end
  local root = _G.RetreatUIGuardianHUD
  return root and root.IsShown and root:IsShown() == true
end

local function ReadTotemStandard()
  if type(GetTotemInfo) ~= "function" then return nil end
  local now = GetTime()

  for slot = 1, 4 do
    local haveTotem, name, startTime, duration, icon = GetTotemInfo(slot)
    if (haveTotem == true or haveTotem == 1) and IsStandard(name) then
      startTime = tonumber(startTime) or now
      duration = tonumber(duration) or 0
      if duration <= 0 then duration = KNOWN_DURATIONS[Normalize(name)] or 20 end
      local remaining = math.max(0, startTime + duration - now)
      if remaining > 0.05 then
        return {
          name = name,
          icon = icon,
          startTime = startTime,
          duration = duration,
          remaining = remaining,
          source = "totem",
        }
      end
    end
  end
end

local function StartFallback(name, spellID)
  if not IsStandard(name) then return end
  local duration = KNOWN_DURATIONS[Normalize(name)] or 20
  local _, _, icon = type(GetSpellInfo) == "function" and GetSpellInfo(spellID or name) or nil
  activeFallback = {
    name = name,
    spellID = tonumber(spellID),
    icon = icon,
    startTime = GetTime(),
    duration = duration,
    expires = GetTime() + duration,
    source = "cast",
  }
end

local function ReadFallback()
  if not activeFallback then return nil end
  local remaining = (tonumber(activeFallback.expires) or 0) - GetTime()
  if remaining <= 0.05 then activeFallback = nil; return nil end
  return {
    name = activeFallback.name,
    icon = activeFallback.icon,
    startTime = activeFallback.startTime,
    duration = activeFallback.duration,
    remaining = remaining,
    source = activeFallback.source,
  }
end

local function SetTrackerState(state)
  local frame = CreateTracker()
  if not GuardianHUDActive() or not state then frame:Hide(); return end

  PositionTracker()
  local duration = math.max(0.1, tonumber(state.duration) or 1)
  local remaining = math.max(0, tonumber(state.remaining) or 0)
  frame.bar:SetMinMaxValues(0, duration)
  frame.bar:SetValue(math.min(duration, remaining))
  frame.icon:SetTexture(state.icon or "Interface\\Icons\\INV_Banner_03")

  local timer
  if RUI.HUDWidgets and RUI.HUDWidgets.FormatCooldown then
    timer = RUI.HUDWidgets:FormatCooldown(remaining)
  elseif remaining >= 60 then
    timer = tostring(math.ceil(remaining / 60)) .. "m"
  else
    timer = tostring(math.ceil(remaining))
  end
  frame.text:SetText(ShortName(state.name) .. "  " .. timer)
  frame:Show()
end

local function UpdateTracker()
  if not GuardianHUDActive() then
    if tracker then tracker:Hide() end
    return
  end
  SetTrackerState(ReadTotemStandard() or ReadFallback())
end

local function CombatLogCast(...)
  local eventType = select(2, ...)
  local sourceGUID = select(3, ...)
  local spellID = select(9, ...)
  local spellName = select(10, ...)

  -- Newer combat-log layouts insert hideCaster before sourceGUID.
  if sourceGUID ~= UnitGUID("player") then
    sourceGUID = select(4, ...)
    spellID = select(12, ...)
    spellName = select(13, ...)
  end

  if sourceGUID == UnitGUID("player")
    and (eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_SUMMON")
    and IsStandard(spellName) then
    StartFallback(spellName, spellID)
  end
end

local events = CreateFrame("Frame", "RetreatUIGuardianBannerTrackerDriver")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TOTEM_UPDATE",
  "UNIT_SPELLCAST_SUCCEEDED", "COMBAT_LOG_EVENT_UNFILTERED",
  "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
}) do
  pcall(events.RegisterEvent, events, eventName)
end

events:SetScript("OnEvent", function(_, eventName, ...)
  if eventName == "COMBAT_LOG_EVENT_UNFILTERED" then
    CombatLogCast(...)
  elseif eventName == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, spellName, _, _, spellID = ...
    if unit == "player" and IsStandard(spellName) then StartFallback(spellName, spellID) end
  end
  UpdateTracker()
end)

events:SetScript("OnUpdate", function(_, delta)
  elapsed = elapsed + delta
  if elapsed < 0.10 then return end
  elapsed = 0
  UpdateTracker()
end)

RUI._guardianBannerTrackerLoaded = true

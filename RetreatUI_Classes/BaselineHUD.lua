local RUI = RetreatUI
if not RUI then return end

local roots = {}
local mirrors = {}

local function SafeFrameName(className)
  return "RetreatUI" .. tostring(className or "Class"):gsub("[^%a%d]", "") .. "HUD"
end

local function PowerTexture()
  if ElvUI then
    local E = unpack(ElvUI)
    if E and E.media and E.media.normTex then return E.media.normTex end
  end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function BuildRoot(className, frameName)
  local root = roots[className]
  if root then return root end
  root = CreateFrame("Frame", frameName, UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("MEDIUM")
  roots[className] = root
  return root
end

local function CreateBar(parent, height)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(360, height or 10)
  bar:SetStatusBarTexture(PowerTexture())
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  RUI:SkinFrame(bar, {0.018,0.018,0.022,0.96}, {0,0,0,1})

  bar.text = bar:CreateFontString(nil, "OVERLAY")
  bar.text:SetPoint("CENTER")
  RUI:ApplyFont(bar.text, 9, "OUTLINE")
  bar.text:SetTextColor(1,1,1,1)
  bar:Hide()
  return bar
end

local function CreateSegment(parent)
  local segment = CreateFrame("Frame", nil, parent)
  segment:SetSize(25, 25)
  RUI:SkinFrame(segment, {0.012,0.012,0.016,0.96}, {0,0,0,1})

  segment.icon = segment:CreateTexture(nil, "ARTWORK")
  segment.icon:SetPoint("TOPLEFT", 1, -1)
  segment.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  segment.icon:SetTexCoord(.08, .92, .08, .92)

  segment.fill = segment:CreateTexture(nil, "BORDER")
  segment.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
  segment.fill:SetPoint("TOPLEFT", 1, -1)
  segment.fill:SetPoint("BOTTOMRIGHT", -1, 1)
  segment.fill:Hide()
  segment:Hide()
  return segment
end

local function CreateMirror(className, root, options)
  local mirror = mirrors[className]
  if mirror then return mirror end
  options = options or {}
  local theme = RUI:GetClassTheme(className)
  local layout = RUI.layout or {}

  mirror = {
    className = className,
    options = options,
    ready = false,
    sourceFrame = nil,
    elapsed = 0,
    lastSignature = nil,
    segments = {},
  }

  mirror.bar1 = CreateBar(root, 10)
  mirror.bar1:SetPoint("CENTER", UIParent, "CENTER", 0, (layout.custom and layout.custom.y or -183))
  mirror.bar1:SetStatusBarColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)

  mirror.bar2 = CreateBar(root, 8)
  mirror.bar2:SetPoint("TOP", mirror.bar1, "BOTTOM", 0, -2)
  mirror.bar2:SetStatusBarColor(theme.accent2[1], theme.accent2[2], theme.accent2[3], 1)

  mirror.state = CreateFrame("Frame", nil, root)
  mirror.state:SetSize(220, 38)
  mirror.state:SetPoint("CENTER", UIParent, "CENTER", 0, (layout.demonfire and layout.demonfire.y or -118))
  RUI:SkinFrame(mirror.state, theme.panelStrong, theme.accent)

  mirror.state.icon = mirror.state:CreateTexture(nil, "ARTWORK")
  mirror.state.icon:SetSize(30, 30)
  mirror.state.icon:SetPoint("LEFT", 4, 0)
  mirror.state.icon:SetTexCoord(.08, .92, .08, .92)

  mirror.state.label = mirror.state:CreateFontString(nil, "OVERLAY")
  mirror.state.label:SetPoint("LEFT", mirror.state.icon, "RIGHT", 8, 0)
  mirror.state.label:SetPoint("RIGHT", -48, 0)
  mirror.state.label:SetJustifyH("LEFT")
  RUI:ApplyFont(mirror.state.label, 9, "OUTLINE")
  mirror.state.label:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)

  mirror.state.timer = mirror.state:CreateFontString(nil, "OVERLAY")
  mirror.state.timer:SetPoint("RIGHT", -8, 0)
  mirror.state.timer:SetJustifyH("RIGHT")
  RUI:ApplyFont(mirror.state.timer, 9, "OUTLINE")
  mirror.state.timer:SetTextColor(1,1,1,1)
  mirror.state:Hide()

  mirror.segmentLabel = root:CreateFontString(nil, "OVERLAY")
  mirror.segmentLabel:SetPoint("CENTER", UIParent, "CENTER", 0, (layout.demonfire and layout.demonfire.y or -118) + 22)
  RUI:ApplyFont(mirror.segmentLabel, 8, "OUTLINE")
  mirror.segmentLabel:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
  mirror.segmentLabel:Hide()

  mirror.driver = CreateFrame("Frame")
  mirror.driver:Hide()

  local function HideAll()
    mirror.bar1:Hide()
    mirror.bar2:Hide()
    mirror.state:Hide()
    mirror.segmentLabel:Hide()
    for _, segment in ipairs(mirror.segments) do segment:Hide() end
  end

  local function EnsureSegments(maximum)
    maximum = math.max(0, math.min(24, math.floor(tonumber(maximum) or 0)))
    while #mirror.segments < maximum do
      mirror.segments[#mirror.segments + 1] = CreateSegment(root)
    end
    local size = maximum > 12 and math.max(12, math.floor(330 / maximum)) or 25
    local spacing = 1
    local totalWidth = maximum > 0 and (maximum * size + (maximum - 1) * spacing) or 0
    local startX = -totalWidth / 2 + size / 2
    local y = layout.demonfire and layout.demonfire.y or -118
    for index, segment in ipairs(mirror.segments) do
      segment:ClearAllPoints()
      segment:SetSize(size, size)
      segment:SetPoint("CENTER", UIParent, "CENTER", startX + (index - 1) * (size + spacing), y)
    end
  end

  local function SnapshotFromAura()
    local keywords = options.auraKeywords
    if type(keywords) ~= "table" or #keywords == 0 or not UnitBuff then return nil end
    for index = 1, 40 do
      local values = {UnitBuff("player", index)}
      local name = values[1]
      if not name then break end
      local lower = string.lower(tostring(name))
      local matched = false
      for _, keyword in ipairs(keywords) do
        if string.find(lower, string.lower(tostring(keyword)), 1, true) then matched = true break end
      end
      if matched then
        return {
          label = name,
          icon = values[3],
          duration = tonumber(values[6]) or 0,
          expirationTime = tonumber(values[7]) or 0,
          bars = {}, segments = {},
          aura = true,
        }
      end
    end
    return nil
  end

  local function SnapshotFromFallback()
    local fallback = options.fallbackPower
    if type(fallback) ~= "table" or type(RUI.FindCustomPower) ~= "function" then return nil end
    local result = RUI:FindCustomPower(fallback)
    if not result then return nil end
    return {
      current = result.current,
      maximum = result.maximum,
      label = options.title or "CLASS RESOURCE",
      icon = options.icon,
      bars = {},
      segments = {},
      frame = nil,
      fallback = true,
    }
  end

  local function ChooseMode(snapshot)
    if options.mode and options.mode ~= "auto" then return options.mode end
    if snapshot and #snapshot.segments > 0 then return "segments" end
    local maximum = snapshot and tonumber(snapshot.maximum)
    if maximum and maximum <= 12 and maximum == math.floor(maximum) then return "segments" end
    if snapshot and ((snapshot.bars and #snapshot.bars > 0) or (snapshot.current and snapshot.maximum)) then return "bar" end
    return "state"
  end

  local function SnapshotSignature(snapshot, mode)
    local parts = {mode or "", tostring(snapshot and snapshot.label or ""), tostring(snapshot and snapshot.icon or "")}
    if snapshot then
      parts[#parts + 1] = tostring(snapshot.current or "")
      parts[#parts + 1] = tostring(snapshot.maximum or "")
      if snapshot.expirationTime and snapshot.expirationTime > 0 and GetTime then
        parts[#parts + 1] = tostring(math.max(0, math.floor(snapshot.expirationTime - GetTime())))
      end
      for index = 1, math.min(2, #(snapshot.bars or {})) do
        local bar = snapshot.bars[index]
        parts[#parts + 1] = tostring(bar.current or "") .. "/" .. tostring(bar.maximum or "")
      end
    end
    return table.concat(parts, "|")
  end

  local function Update(forceDiscovery)
    if not root:IsShown() then return end
    local snapshot = SnapshotFromAura()
    if not snapshot and type(RUI.ReadAscensionResourceSnapshot) == "function" then
      snapshot = RUI:ReadAscensionResourceSnapshot(options.keywords, options.title, forceDiscovery == true)
    end
    if not snapshot then snapshot = SnapshotFromFallback() end
    if not snapshot then
      mirror.ready = false
      mirror.sourceFrame = nil
      mirror.lastSignature = nil
      HideAll()
      return
    end

    local mode = ChooseMode(snapshot)
    local signature = SnapshotSignature(snapshot, mode)
    if signature == mirror.lastSignature and not forceDiscovery then return end
    mirror.lastSignature = signature
    HideAll()

    local label = (options.preferSnapshotLabel and snapshot.label) or options.title or snapshot.label or "CLASS RESOURCE"
    local icon = snapshot.icon or options.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    local current = math.max(0, tonumber(snapshot.current) or 0)
    local maximum = math.max(1, tonumber(snapshot.maximum) or 1)

    if mode == "segments" and maximum <= 24 then
      EnsureSegments(maximum)
      mirror.segmentLabel:SetText(string.upper(tostring(label)) .. "  " .. math.floor(current + .5) .. " / " .. math.floor(maximum + .5))
      mirror.segmentLabel:Show()
      for index, segment in ipairs(mirror.segments) do
        if index <= maximum then
          local active = index <= current
          segment.icon:SetTexture(icon)
          if segment.icon.SetDesaturated then segment.icon:SetDesaturated(not active) end
          segment:SetAlpha(active and 1 or .30)
          segment:Show()
        else
          segment:Hide()
        end
      end
    elseif mode == "bar" then
      local sourceBars = snapshot.bars or {}
      local bar1Current = sourceBars[1] and sourceBars[1].current or current
      local bar1Maximum = sourceBars[1] and sourceBars[1].maximum or maximum
      mirror.bar1:SetMinMaxValues(0, math.max(1, tonumber(bar1Maximum) or 1))
      mirror.bar1:SetValue(math.max(0, tonumber(bar1Current) or 0))
      mirror.bar1.text:SetText(string.upper(tostring(label)) .. "  " .. math.floor((tonumber(bar1Current) or 0) + .5) .. " / " .. math.floor((tonumber(bar1Maximum) or 1) + .5))
      mirror.bar1:Show()

      if sourceBars[2] then
        local second = sourceBars[2]
        mirror.bar2:SetMinMaxValues(0, math.max(1, tonumber(second.maximum) or 1))
        mirror.bar2:SetValue(math.max(0, tonumber(second.current) or 0))
        mirror.bar2.text:SetText(math.floor((tonumber(second.current) or 0) + .5) .. " / " .. math.floor((tonumber(second.maximum) or 1) + .5))
        mirror.bar2:Show()
      end
    else
      mirror.state.icon:SetTexture(icon)
      mirror.state.label:SetText(string.upper(tostring(label)))
      local remaining = 0
      if snapshot.expirationTime and snapshot.expirationTime > 0 and GetTime then
        remaining = math.max(0, snapshot.expirationTime - GetTime())
      end
      if remaining > 0 then
        mirror.state.timer:SetText(remaining >= 60 and (math.floor(remaining / 60) .. "m") or (math.ceil(remaining) .. "s"))
      else
        mirror.state.timer:SetText("")
      end
      mirror.state:Show()
    end

    local wasReady = mirror.ready
    mirror.ready = true
    mirror.sourceFrame = snapshot.frame
    if not wasReady and type(RUI.ScheduleFrameCleanupPasses) == "function" then
      RUI:After(.05, function() RUI:ScheduleFrameCleanupPasses(true) end)
    end
  end

  mirror.Update = Update
  mirror.HideAll = HideAll
  mirror.driver:SetScript("OnUpdate", function(_, elapsed)
    mirror.elapsed = mirror.elapsed + elapsed
    if mirror.elapsed < .12 then return end
    mirror.elapsed = 0
    Update(false)
  end)

  mirror.events = CreateFrame("Frame")
  for _, eventName in ipairs({
    "PLAYER_ENTERING_WORLD", "UNIT_AURA", "UNIT_POWER", "UNIT_POWER_FREQUENT",
    "UNIT_DISPLAYPOWER", "UNIT_POWER_BAR_SHOW", "UNIT_POWER_BAR_HIDE",
    "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "UPDATE_SHAPESHIFT_FORM",
  }) do pcall(mirror.events.RegisterEvent, mirror.events, eventName) end
  mirror.events:SetScript("OnEvent", function(_, event, unit)
    if unit and unit ~= "player" then return end
    Update(event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE")
  end)
  mirror.events:Hide()

  mirrors[className] = mirror
  return mirror
end

function RUI:RegisterBaselineClassHUD(className, options)
  options = options or {}
  local module = {
    ready = true,
    baseline = true,
    usesPrimaryPower = options.usesPrimaryPower ~= false,
    frameName = options.frameName or SafeFrameName(className),
  }

  local mirrorEnabled = options.mirrorNativeResource ~= false
  function module.customResourcesComplete()
    local mirror = mirrors[className]
    return mirrorEnabled and mirror ~= nil and mirror.ready == true
  end

  function module:activate()
    local root = BuildRoot(className, self.frameName)
    root:Show()
    if mirrorEnabled then
      local mirror = CreateMirror(className, root, options.nativeResource or {})
      mirror.elapsed = 0
      mirror.driver:Show()
      mirror.events:Show()
      mirror.Update(true)
    end
    return true
  end

  function module:deactivate()
    local root = roots[className]
    local mirror = mirrors[className]
    if mirror then
      mirror.driver:Hide()
      mirror.events:Hide()
      mirror.elapsed = 0
      mirror.ready = false
      mirror.lastSignature = nil
      mirror.HideAll()
    end
    if root then root:Hide() end
    if type(RUI.RestoreNativeResourceMirrorSources) == "function" then RUI:RestoreNativeResourceMirrorSources() end
  end

  return RUI:RegisterClassModule(className, module)
end

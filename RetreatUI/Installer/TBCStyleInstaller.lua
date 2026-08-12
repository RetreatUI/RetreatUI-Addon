local RUI = RetreatUI
if not RUI then return end

local frame

local function Theme() return RUI:GetTheme() end

local function Backdrop(widget, bg, border)
  RUI:SkinFrame(widget, bg or Theme().background, border or Theme().dim)
end

local function Text(parent, value, size, color)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  RUI:ApplyFont(fs, size or 11, "OUTLINE")
  fs:SetText(value or "")
  color = color or Theme().text
  fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  return fs
end

local function Button(parent, label, width, callback)
  local theme = Theme()
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width or 140, 30)
  button:RegisterForClicks("LeftButtonUp")
  Backdrop(button, theme.panelStrong, {theme.accent[1] * 0.58, theme.accent[2] * 0.58, theme.accent[3] * 0.58, 1})
  button.label = Text(button, label, 10, theme.text)
  button.label:SetPoint("CENTER")
  button:SetScript("OnClick", function(self)
    if not self.disabled and callback then callback(self) end
  end)
  button:SetScript("OnEnter", function(self)
    if not self.disabled then self:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1) end
  end)
  button:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(theme.accent[1] * 0.58, theme.accent[2] * 0.58, theme.accent[3] * 0.58, 1)
  end)
  function button:SetEnabled(enabled)
    self.disabled = not enabled
    self:SetAlpha(enabled and 1 or 0.38)
    self:EnableMouse(enabled)
  end
  function button:SetLabel(value) self.label:SetText(value or "") end
  return button
end

local function CurrentClass()
  local className = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or "Class"
  if RUI.NormalizeClassName then className = RUI:NormalizeClassName(className) or className end
  return className
end

local function BuildSteps()
  return {
    {
      id = "welcome",
      title = "WELCOME",
      subtitle = "RetreatUI for Conquest of Azeroth.",
      description = "Continue through the installer to apply the shared profiles, General WeakAuras and the verified WeakAura package for your current CoA class.",
    },
    {
      id = "elvui",
      component = "elvui",
      title = "ELVUI",
      subtitle = "Choose the resolution profile to import.",
      description = "Imports the full RetreatUI ElvUI profile through ElvUI's native Distributor.",
      options = {
        {label = "1440P", method = "ImportParityElvUI", argument = "1440p"},
        {label = "1080P", method = "ImportParityElvUI", argument = "1080p"},
      },
    },
    {
      id = "bigwigs",
      component = "bigwigs",
      title = "BIGWIGS",
      subtitle = "Choose the resolution profile to import.",
      description = "Registers and imports the RetreatUI BigWigs profile through BigWigsAPI.",
      options = {
        {label = "1440P", method = "ImportParityBigWigs", argument = "1440p"},
        {label = "1080P", method = "ImportParityBigWigs", argument = "1080p"},
      },
    },
    {
      id = "details",
      component = "details",
      title = "DETAILS",
      subtitle = "Import the shared damage-meter profile.",
      description = "Imports the RetreatUI Details profile through DetailsAPI.",
      options = {
        {label = "SETUP DETAILS", method = "ImportParityDetails"},
      },
    },
    {
      id = "turboplates",
      component = "turboplates",
      title = "TURBOPLATES",
      subtitle = "Choose the resolution profile to apply.",
      description = "Applies the verified nameplate settings translated to TurboPlates. This step remains locked until the mapping is complete; no approximate fallback is used.",
      options = {
        {label = "1440P", method = "ImportParityTurboPlates", argument = "1440p"},
        {label = "1080P", method = "ImportParityTurboPlates", argument = "1080p"},
      },
    },
    {
      id = "generalwa",
      component = "generalwa",
      title = "GENERAL WEAKAURAS",
      subtitle = "Import the shared Core WeakAura package.",
      description = "Opens WeakAuras' normal import window with the complete General Core export.",
      options = {
        {label = "CORE", method = "ImportParityGeneralWeakAuras"},
      },
    },
    {
      id = "classwa",
      component = "classwa",
      title = "CLASS WEAKAURA",
      subtitle = function() return "Current class: " .. CurrentClass() end,
      description = "Opens WeakAuras' normal import window for the verified package mapped to your current CoA class. The button stays locked until that class mapping is complete.",
      options = {
        {label = "IMPORT CLASS WA", method = "ImportParityClassWeakAuras"},
      },
    },
    {
      id = "reload",
      title = "INSTALLATION COMPLETE",
      subtitle = "The selected profiles and WeakAuras are ready.",
      description = "Reload the UI to finish applying the imported settings. Reopen this installer at any time with /retreatui or /rui.",
      reload = true,
      options = {
        {label = "RELOAD", reload = true},
      },
    },
  }
end

local function Resolve(value)
  if type(value) == "function" then return value() end
  return value or ""
end

local function Status(text, success)
  if not frame or not frame.status then return end
  local theme = Theme()
  frame.status:SetText(text or "")
  local color = success == true and theme.success or success == false and theme.danger or theme.muted
  frame.status:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function ComponentReady(component)
  if not component then return true end
  if type(RUI.IsParityImportReady) ~= "function" then return false end
  return RUI:IsParityImportReady(component) == true
end

local function NotReadyMessage(component)
  if component == "elvui" then return "Enable ElvUI to unlock this step." end
  if component == "bigwigs" then return "Enable BigWigs to unlock this step." end
  if component == "details" then return "Enable Details to unlock this step." end
  if component == "turboplates" then return "TurboPlates parity mapping is still being verified." end
  if component == "generalwa" then return "Enable WeakAuras to unlock this step." end
  if component == "classwa" then return "The " .. CurrentClass() .. " WeakAura mapping is still being verified." end
  return "This step is not ready."
end

local function RefreshDots()
  if not frame or not frame.dots then return end
  local theme = Theme()
  for index, dot in ipairs(frame.dots) do
    local color
    if index < frame.currentStep then color = theme.success
    elseif index == frame.currentStep then color = theme.accent
    else color = theme.dim end
    dot:SetVertexColor(color[1], color[2], color[3], index == frame.currentStep and 1 or 0.78)
  end
end

local function SetOptionButton(button, option, ready)
  if not option then
    button:Hide()
    return
  end
  button:Show()
  button:SetLabel(option.label or "APPLY")
  button:SetEnabled(ready)
end

local function Refresh()
  if not frame then return end
  local steps = frame.steps
  local total = #steps
  frame.currentStep = math.max(1, math.min(total, frame.currentStep or 1))
  local step = steps[frame.currentStep]
  local ready = ComponentReady(step.component)

  frame.progress:SetText(string.format("STEP %d OF %d", frame.currentStep, total))
  frame.pageTitle:SetText(Resolve(step.title))
  frame.pageSubtitle:SetText(Resolve(step.subtitle))
  frame.description:SetText(Resolve(step.description))
  RefreshDots()

  frame.back:SetEnabled(frame.currentStep > 1)
  frame.next:SetEnabled(frame.currentStep < total)
  frame.next:SetLabel(frame.currentStep == 1 and "CONTINUE" or "NEXT")

  SetOptionButton(frame.action1, step.options and step.options[1], step.reload or ready)
  SetOptionButton(frame.action2, step.options and step.options[2], step.reload or ready)

  local saved = frame.results[step.id]
  if saved then
    Status(saved.message, saved.success)
  elseif step.reload then
    Status("Ready to reload.", true)
  elseif step.component then
    Status(ready and "READY" or NotReadyMessage(step.component), ready and nil or false)
  else
    Status("Continue to begin setup.", nil)
  end
end

local function RunOption(slot)
  if not frame then return end
  local step = frame.steps[frame.currentStep]
  local option = step and step.options and step.options[slot]
  if not option then return end

  if option.reload then
    local db = RUI:EnsureDB()
    db.installer = db.installer or {}
    db.installer.initialCompleted = true
    db.installer.completedVersion = RUI.version
    ReloadUI()
    return
  end

  local method = option.method and RUI[option.method]
  if type(method) ~= "function" then
    frame.results[step.id] = {success = false, message = "This import is not available yet."}
    Refresh()
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    frame.results[step.id] = {success = false, message = "Leave combat before applying this step."}
    Refresh()
    return
  end

  local ok, success, message = pcall(method, RUI, option.argument)
  if not ok then
    success, message = false, tostring(success)
  end

  frame.results[step.id] = {
    success = success == true,
    message = message or (success and "Imported successfully." or "Import failed."),
  }
  Refresh()
end

local function BuildInstaller()
  if frame then return frame end
  local theme = Theme()
  frame = CreateFrame("Frame", "RetreatUICleanInstaller", UIParent)
  frame:SetSize(760, 500)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if not InCombatLockdown or not InCombatLockdown() then self:StartMoving() end
  end)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  Backdrop(frame, theme.background, {theme.accent[1] * 0.58, theme.accent[2] * 0.58, theme.accent[3] * 0.58, 1})

  frame.brand = Text(frame, "RETREATUI — CONQUEST OF AZEROTH", 18, theme.accent)
  frame.brand:SetPoint("TOPLEFT", 28, -26)
  frame.progress = Text(frame, "", 10, theme.muted)
  frame.progress:SetPoint("TOPRIGHT", -46, -30)

  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetTexture("Interface\\Buttons\\WHITE8X8")
  divider:SetVertexColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.65)
  divider:SetPoint("TOPLEFT", 28, -62)
  divider:SetPoint("TOPRIGHT", -28, -62)
  divider:SetHeight(1)

  frame.steps = BuildSteps()
  frame.dots = {}
  local total = #frame.steps
  local dotWidth, dotGap = 8, 9
  local totalWidth = total * dotWidth + (total - 1) * dotGap
  for index = 1, total do
    local dot = frame:CreateTexture(nil, "ARTWORK")
    dot:SetTexture("Interface\\Buttons\\WHITE8X8")
    dot:SetSize(dotWidth, 3)
    dot:SetPoint("TOPLEFT", frame, "TOP", -totalWidth / 2 + (index - 1) * (dotWidth + dotGap), -75)
    frame.dots[index] = dot
  end

  frame.pageTitle = Text(frame, "", 24, theme.text)
  frame.pageTitle:SetPoint("TOPLEFT", 42, -112)
  frame.pageSubtitle = Text(frame, "", 12, theme.accent)
  frame.pageSubtitle:SetPoint("TOPLEFT", frame.pageTitle, "BOTTOMLEFT", 0, -12)
  frame.description = Text(frame, "", 11, theme.muted)
  frame.description:SetPoint("TOPLEFT", frame.pageSubtitle, "BOTTOMLEFT", 0, -24)
  frame.description:SetWidth(660)
  frame.description:SetHeight(100)
  frame.description:SetJustifyH("LEFT")
  frame.description:SetJustifyV("TOP")
  frame.description:SetWordWrap(true)

  local statusPanel = CreateFrame("Frame", nil, frame)
  statusPanel:SetSize(660, 66)
  statusPanel:SetPoint("CENTER", 0, -35)
  Backdrop(statusPanel, theme.panel, {theme.dim[1], theme.dim[2], theme.dim[3], 0.45})
  local statusLabel = Text(statusPanel, "STATUS", 9, theme.muted)
  statusLabel:SetPoint("TOPLEFT", 14, -11)
  frame.status = Text(statusPanel, "", 10, theme.muted)
  frame.status:SetPoint("TOPLEFT", statusLabel, "BOTTOMLEFT", 0, -8)
  frame.status:SetPoint("RIGHT", statusPanel, "RIGHT", -14, 0)
  frame.status:SetJustifyH("LEFT")
  frame.status:SetWordWrap(true)

  frame.action1 = Button(frame, "APPLY", 180, function() RunOption(1) end)
  frame.action1:SetPoint("CENTER", -100, -126)
  frame.action2 = Button(frame, "APPLY", 180, function() RunOption(2) end)
  frame.action2:SetPoint("CENTER", 100, -126)

  frame.back = Button(frame, "BACK", 100, function()
    frame.currentStep = math.max(1, (frame.currentStep or 1) - 1)
    Refresh()
  end)
  frame.back:SetPoint("BOTTOMLEFT", 28, 22)

  frame.next = Button(frame, "NEXT", 120, function()
    frame.currentStep = math.min(#frame.steps, (frame.currentStep or 1) + 1)
    Refresh()
  end)
  frame.next:SetPoint("BOTTOMRIGHT", -28, 22)

  frame.close = Button(frame, "X", 32, function() frame:Hide() end)
  frame.close:SetPoint("TOPRIGHT", -10, -10)

  frame.currentStep = 1
  frame.results = {}
  Refresh()
  return frame
end

function RUI:HideInstaller()
  if frame then frame:Hide() end
end

function RUI:ShowInstaller()
  BuildInstaller()
  frame.currentStep = 1
  frame.results = frame.results or {}
  Refresh()
  frame:Show()
  return true
end

function RUI:RefreshInstallerTheme()
  if frame then frame:Hide(); frame = nil end
end

RUI._cleanStepInstallerLoaded = true
RUI._cleanStepInstallerRevision = 3

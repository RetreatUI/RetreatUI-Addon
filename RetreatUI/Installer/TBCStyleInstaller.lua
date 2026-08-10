local RUI = RetreatUI
if not RUI then return end

-- TBC-style CoA installer: only the imports the user actually wants.
-- Guardian gets one extra Macro step; every other class skips it entirely.
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
  Backdrop(button, theme.panelStrong, {theme.accent[1]*0.58, theme.accent[2]*0.58, theme.accent[3]*0.58, 1})
  button.label = Text(button, label, 10, theme.text)
  button.label:SetPoint("CENTER")
  button:SetScript("OnClick", function(self) if not self.disabled and callback then callback(self) end end)
  button:SetScript("OnEnter", function(self)
    if not self.disabled then self:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1) end
  end)
  button:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(theme.accent[1]*0.58, theme.accent[2]*0.58, theme.accent[3]*0.58, 1)
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

local function ModuleDefinition(key)
  return RUI.moduleInstallers and RUI.moduleInstallers[key]
end

local function ModuleReady(key)
  local definition = ModuleDefinition(key)
  if not definition then return false, "Component is not registered." end
  local available, reason = RUI:GetInstallerModuleAvailability(key)
  if not available then return false, tostring(reason or definition.missing or "Dependency is missing.") end
  return true, "READY"
end

local function InstallModule(key)
  if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before applying this step." end
  if not ModuleDefinition(key) then return false, "Component is not registered." end
  RUI:SetInstallerModuleEnabled(key, true)
  local record = RUI:InstallModule(key)
  if not record then return false, "The installer did not return a result." end
  if record.state == "success" then return true, record.message or "Installed successfully." end
  if record.state == "skipped" then return false, record.message or "This component was skipped." end
  return false, record.message or "Installation failed."
end

local function InstallGuardianMacros()
  if CurrentClass() ~= "Guardian" then return false, "Guardian macros are only installed on Guardian." end
  if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before creating Guardian macros." end
  if type(RUI.CreateGuardianFormationMacros) ~= "function" then return false, "Guardian macro package is not loaded." end
  local ok, err = pcall(RUI.CreateGuardianFormationMacros)
  if not ok then return false, tostring(err) end
  return true, "Guardian formation macros created or updated."
end

local function BuildSteps()
  local steps = {
    {
      id="welcome",
      title="WELCOME",
      subtitle="RetreatUI for Conquest of Azeroth.",
      description="Clean setup only: ElvUI, Details, TurboPlates and WeakAuras. Guardian also gets its formation macros. Nothing else is part of this installer.",
    },
    {
      id="elvui", key="unitframes",
      title="IMPORT ELVUI",
      subtitle="Install the RetreatUI ElvUI profile.",
      description="Applies the RetreatUI unitframes, castbars and shared layout.",
    },
  }

  if CurrentClass() == "Guardian" then
    steps[#steps + 1] = {
      id="macros", custom="guardianMacros",
      title="IMPORT GUARDIAN MACROS",
      subtitle="Create or update Guardian formation macros.",
      description="Installs the Guardian formation-aware macro package for the current character.",
    }
  end

  steps[#steps + 1] = {
    id="details", key="details",
    title="IMPORT DETAILS",
    subtitle="Install the RetreatUI Details profile.",
    description="Applies the shared RetreatUI damage-meter layout, fonts and positioning.",
  }
  steps[#steps + 1] = {
    id="turboplates", key="nameplates",
    title="IMPORT TURBOPLATES",
    subtitle="Install the RetreatUI TurboPlates profile.",
    description="Applies the shared RetreatUI nameplate profile.",
  }
  steps[#steps + 1] = {
    id="weakauras", key="classHUD",
    title=function() return "IMPORT " .. string.upper(CurrentClass()) .. " WEAKAURAS" end,
    subtitle=function() return "Install RetreatUI - General + " .. CurrentClass() .. " HUD WeakAuras." end,
    description="General contains Trinkets, Buffs & Procs and Racials. The class package contains Resource, Main, Utility, State and Target trackers.",
  }
  steps[#steps + 1] = {
    id="reload", reload=true,
    title="RELOAD",
    subtitle="RetreatUI setup is ready.",
    description="Reload the UI to finish applying the imported profiles and WeakAuras. Reopen the installer any time with /retreatui or /rui.",
  }
  return steps
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

local function Refresh()
  if not frame then return end
  local steps = frame.steps or BuildSteps()
  local total = #steps
  local index = math.max(1, math.min(total, frame.currentStep or 1))
  frame.currentStep = index
  local step = steps[index]

  frame.progress:SetText(string.format("STEP %d OF %d", index, total))
  frame.pageTitle:SetText(Resolve(step.title))
  frame.pageSubtitle:SetText(Resolve(step.subtitle))
  frame.description:SetText(Resolve(step.description))
  RefreshDots()

  frame.back:SetEnabled(index > 1)
  frame.next:SetEnabled(index < total)
  frame.next:SetLabel(index == 1 and "GET STARTED" or "NEXT")

  if step.reload then
    frame.action:Show()
    frame.action:SetLabel("RELOAD UI")
    frame.action:SetEnabled(true)
    Status("Ready to reload.", true)
  elseif step.custom == "guardianMacros" then
    frame.action:Show()
    frame.action:SetLabel("IMPORT MACROS")
    frame.action:SetEnabled(CurrentClass() == "Guardian")
    local saved = frame.results[step.id]
    Status(saved and saved.message or "READY", saved and saved.success or nil)
  elseif step.key then
    frame.action:Show()
    local definition = ModuleDefinition(step.key)
    frame.action:SetLabel(definition and ("APPLY " .. string.upper(definition.label or "COMPONENT")) or "APPLY")
    local saved = frame.results[step.id]
    if saved then
      Status(saved.message, saved.success)
    else
      local ready, reason = ModuleReady(step.key)
      Status(ready and "READY" or reason, ready and nil or false)
    end
    local ready = ModuleReady(step.key)
    frame.action:SetEnabled(ready == true)
  else
    frame.action:Hide()
    Status("Only the core RetreatUI imports are included here.", nil)
  end
end

local function RunAction()
  if not frame then return end
  local steps = frame.steps or BuildSteps()
  local step = steps[frame.currentStep or 1]
  if not step then return end

  if step.reload then
    local db = RUI:EnsureDB()
    db.installer = db.installer or {}
    db.installer.initialCompleted = true
    db.installer.completedVersion = RUI.version
    ReloadUI()
    return
  end

  local success, message
  if step.custom == "guardianMacros" then
    success, message = InstallGuardianMacros()
  elseif step.key then
    success, message = InstallModule(step.key)
  else
    return
  end

  frame.results[step.id] = {
    success = success,
    message = message or (success and "Installed successfully." or "Installation failed."),
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
  frame:SetScript("OnDragStart", function(self) if not InCombatLockdown or not InCombatLockdown() then self:StartMoving() end end)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  Backdrop(frame, theme.background, {theme.accent[1]*0.58, theme.accent[2]*0.58, theme.accent[3]*0.58, 1})

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
    dot:SetPoint("TOPLEFT", frame, "TOP", -totalWidth/2 + (index-1)*(dotWidth+dotGap), -75)
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

  frame.action = Button(frame, "APPLY", 230, RunAction)
  frame.action:SetPoint("CENTER", 0, -126)
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
RUI._cleanStepInstallerRevision = 2

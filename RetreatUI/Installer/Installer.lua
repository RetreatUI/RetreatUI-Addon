local RUI = RetreatUI
local Installer = {}
RUI.Installer = Installer

local frame, currentPage
local pageFrames, navButtons = {}, {}
local PAGE_DEFS = {
  {key="welcome", title="SYSTEM CHECK", subtitle="Requirements"},
  {key="install", title="INSTALL", subtitle="One complete setup"},
  {key="complete", title="COMPLETE", subtitle="Validation"},
}

local function Text(parent, text, size, accent)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  RUI:ApplyFont(fs, size or 12, "OUTLINE")
  fs:SetText(text or "")
  local theme = RUI:GetTheme()
  local color = accent and theme.accent or theme.text
  fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  return fs
end

local function Panel(parent, background, border)
  local panel = CreateFrame("Frame", nil, parent)
  RUI:SkinFrame(panel, background, border)
  return panel
end

local function Button(parent, label, width, height, onClick)
  local button = CreateFrame("Button", nil, parent)
  RUI:SkinFrame(button, RUI:GetTheme().panel, {0, 0, 0, 1})
  button:SetSize(width or 130, height or 32)
  button:RegisterForClicks("LeftButtonUp")
  button.text = Text(button, label, 11, false)
  button.text:SetPoint("CENTER")
  button:SetScript("OnClick", function(self)
    if not self.disabled and onClick then onClick(self) end
  end)
  button:SetScript("OnEnter", function(self)
    if self.disabled then return end
    local theme = RUI:GetTheme()
    self:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
  end)
  button:SetScript("OnLeave", function(self)
    local theme = RUI:GetTheme()
    self:SetBackdropBorderColor(theme.accent[1] * 0.45, theme.accent[2] * 0.45, theme.accent[3] * 0.45, 1)
  end)
  function button:SetLabel(value) self.text:SetText(value) end
  function button:SetEnabled(value)
    self.disabled = not value
    self:SetAlpha(value and 1 or 0.38)
    if value then self:Enable() else self:Disable() end
  end
  local theme = RUI:GetTheme()
  button:SetBackdropBorderColor(theme.accent[1] * 0.45, theme.accent[2] * 0.45, theme.accent[3] * 0.45, 1)
  return button
end

local function SetStatusText(fontString, state, label)
  local theme = RUI:GetTheme()
  if state == "success" or state == "ready" then
    fontString:SetTextColor(theme.accent2[1], theme.accent2[2], theme.accent2[3], 1)
  elseif state == "skipped" or state == "optional" then
    fontString:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
  elseif state == "running" then
    fontString:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
  else
    fontString:SetTextColor(1, 0.28, 0.18, 1)
  end
  fontString:SetText(label)
end

local function CreateDependencyRow(parent, index)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(620, 28)
  row:SetPoint("TOPLEFT", 22, -50 - (index - 1) * 34)
  row.label = Text(row, "", 11, false)
  row.label:SetPoint("LEFT", 0, 0)
  row.status = Text(row, "", 10, false)
  row.status:SetPoint("RIGHT", 0, 0)
  return row
end

local function CreateWelcomePage()
  local page = CreateFrame("Frame", nil, frame.content)
  page:SetAllPoints(); page:Hide()

  local title = Text(page, "WELCOME TO RETREATUI", 26, true)
  title:SetPoint("TOPLEFT", 34, -30)
  local subtitle = Text(page, "One complete interface. Core and class modules are installed together with no manual profile imports.", 13, false)
  subtitle:SetPoint("TOPLEFT", 34, -68)
  subtitle:SetPoint("TOPRIGHT", -34, -68)
  subtitle:SetJustifyH("LEFT")

  local scope = Panel(page, RUI:GetTheme().panelSoft, RUI:GetTheme().accent)
  scope:SetPoint("TOPLEFT", 34, -112)
  scope:SetPoint("TOPRIGHT", -34, -112)
  scope:SetHeight(78)
  local scopeTitle = Text(scope, "SUPPORTED SETUP", 11, true)
  scopeTitle:SetPoint("TOPLEFT", 18, -15)
  local detectedClass = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or "Supported class"
  local scopeText = Text(scope, tostring(detectedClass) .. "  •  Primary resolution: 1920 × 1080  •  Native RetreatUI class HUD", 11, false)
  scopeText:SetPoint("TOPLEFT", 18, -43)

  local requiredCount, optionalCount = 0, 0
  for _, dependency in ipairs(RUI.installerDependencies or {}) do
    if not dependency.hidden then
      if dependency.required then requiredCount = requiredCount + 1 else optionalCount = optionalCount + 1 end
    end
  end

  local required = Panel(page, RUI:GetTheme().panel, {0.14, 0.10, 0.10, 1})
  required:SetPoint("TOPLEFT", 34, -212)
  required:SetPoint("TOPRIGHT", -34, -212)
  required:SetHeight(58 + requiredCount * 34)
  local requiredTitle = Text(required, "REQUIRED ADDONS", 13, true)
  requiredTitle:SetPoint("TOPLEFT", 20, -18)
  page.requiredRows = {}
  for index = 1, requiredCount do page.requiredRows[index] = CreateDependencyRow(required, index) end

  local optionalTop = -212 - (58 + requiredCount * 34) - 16
  local optional = Panel(page, RUI:GetTheme().panel, {0.14, 0.10, 0.10, 1})
  optional:SetPoint("TOPLEFT", 34, optionalTop)
  optional:SetPoint("TOPRIGHT", -34, optionalTop)
  optional:SetHeight(58 + optionalCount * 34)
  local optionalTitle = Text(optional, "OPTIONAL INTEGRATION", 13, true)
  optionalTitle:SetPoint("TOPLEFT", 20, -18)
  page.optionalRows = {}
  for index = 1, optionalCount do page.optionalRows[index] = CreateDependencyRow(optional, index) end

  page.refresh = Button(page, "CHECK AGAIN", 132, 30, function() page.Refresh() end)
  page.refresh:SetPoint("BOTTOMLEFT", 34, 26)
  page.notice = Text(page, "", 11, false)
  page.notice:SetPoint("BOTTOMRIGHT", -34, 32)
  page.notice:SetJustifyH("RIGHT")

  page.Refresh = function()
    local requiredIndex, optionalIndex = 0, 0
    local ready = true
    for _, dependency in ipairs(RUI.installerDependencies or {}) do
      if not dependency.hidden then
        local available, status = RUI:GetDependencyStatus(dependency, false)
      local rows
      local index
      if dependency.required then
        requiredIndex = requiredIndex + 1
        rows, index = page.requiredRows, requiredIndex
        if not available then ready = false end
      else
        optionalIndex = optionalIndex + 1
        rows, index = page.optionalRows, optionalIndex
      end
      local row = rows[index]
      row.label:SetText(dependency.label)
      if available then
        SetStatusText(row.status, "ready", status == "Loaded" and "LOADED" or "READY")
      elseif dependency.required then
        if status == "Version mismatch" then
          SetStatusText(row.status, "error", "VERSION MISMATCH")
        else
          SetStatusText(row.status, "error", "MISSING")
        end
      else
        SetStatusText(row.status, "optional", "NOT INSTALLED")
      end
      end
    end

    if type(RUI.IsSupportedCharacter) == "function" and not RUI:IsSupportedCharacter() then ready = false end
    if ready then
      SetStatusText(page.notice, "ready", "All required components are ready.")
    else
      SetStatusText(page.notice, "error", "Install the missing required addons, then restart the game.")
    end
    if frame and frame.next then frame.next:SetEnabled(ready) end
  end
  return page
end

local function CreateInstallRow(parent, index, key)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(650, 29)
  row:SetPoint("TOPLEFT", 24, -56 - (index - 1) * 34)
  row.key = key
  row.label = Text(row, "", 11, false)
  row.label:SetPoint("LEFT", 0, 0)
  row.status = Text(row, "WAITING", 10, false)
  row.status:SetPoint("RIGHT", 0, 0)
  return row
end

local function CreateInstallPage()
  local page = CreateFrame("Frame", nil, frame.content)
  page:SetAllPoints(); page:Hide()

  local title = Text(page, "INSTALL RETREATUI", 25, true)
  title:SetPoint("TOPLEFT", 34, -30)
  local description = Text(page, "The installer applies the full supported setup and validates every required component before completion.", 13, false)
  description:SetPoint("TOPLEFT", 34, -70)
  description:SetPoint("TOPRIGHT", -34, -70)

  local card = Panel(page, RUI:GetTheme().panelSoft, RUI:GetTheme().accent)
  card:SetPoint("TOPLEFT", 34, -112)
  card:SetPoint("TOPRIGHT", -34, -112)
  card:SetHeight(360)

  page.rows = {}
  for index, key in ipairs(RUI.moduleOrder) do
    local row = CreateInstallRow(card, index, key)
    local definition = RUI.moduleInstallers[key]
    row.label:SetText(definition.label .. (definition.required and "" or "  (optional)"))
    page.rows[key] = row
  end

  page.result = Text(page, "Ready to install.", 12, false)
  page.result:SetPoint("TOPLEFT", 40, -500)
  page.result:SetPoint("TOPRIGHT", -220, -500)
  page.result:SetJustifyH("LEFT")

  page.install = Button(page, "INSTALL RETREATUI", 176, 34, function(button)
    button:SetEnabled(false)
    button:SetLabel("INSTALLING")
    for _, row in pairs(page.rows) do SetStatusText(row.status, "optional", "WAITING") end

    local valid, problems = RUI:InstallAllModules(function(key, state)
      local row = page.rows[key]
      if not row then return end
      if state == "running" then
        SetStatusText(row.status, "running", "INSTALLING")
      elseif state == "success" then
        SetStatusText(row.status, "success", "INSTALLED")
      elseif state == "skipped" then
        SetStatusText(row.status, "skipped", "SKIPPED")
      else
        SetStatusText(row.status, "error", "FAILED")
      end
    end)

    if valid then
      local warnings = RUI:GetOptionalIntegrationWarnings()
      if #warnings > 0 then
        SetStatusText(page.result, "optional", "Required setup installed. Optional warning: " .. table.concat(warnings, "  •  "))
      else
        SetStatusText(page.result, "success", "Installation validated successfully.")
      end
      button:SetLabel("INSTALLED")
      if frame and frame.next then frame.next:SetEnabled(true) end
    else
      SetStatusText(page.result, "error", table.concat(problems or {"Installation failed."}, "  •  "))
      button:SetLabel("RETRY INSTALLATION")
      button:SetEnabled(true)
      if frame and frame.next then frame.next:SetEnabled(false) end
    end
  end)
  page.install:SetPoint("BOTTOMRIGHT", -34, 24)

  page.Refresh = function()
    local valid = RUI:ValidateInstallation()
    for _, key in ipairs(RUI.moduleOrder) do
      local row = page.rows[key]
      local record = RUI:GetModuleStatus(key)
      if record and record.version == RUI.version then
        if record.state == "success" then SetStatusText(row.status, "success", "INSTALLED")
        elseif record.state == "skipped" then SetStatusText(row.status, "skipped", "SKIPPED")
        else SetStatusText(row.status, "error", "FAILED") end
      else
        SetStatusText(row.status, "optional", "WAITING")
      end
    end
    if valid then
      page.install:SetLabel("INSTALLED")
      page.install:SetEnabled(false)
      local warnings = RUI:GetOptionalIntegrationWarnings()
      if #warnings > 0 then
        SetStatusText(page.result, "optional", "Required setup installed. Optional warning: " .. table.concat(warnings, "  •  "))
      else
        SetStatusText(page.result, "success", "Installation validated successfully.")
      end
    else
      page.install:SetLabel("INSTALL RETREATUI")
      page.install:SetEnabled(true)
      SetStatusText(page.result, "optional", "Ready to install.")
    end
    if frame and frame.next then frame.next:SetEnabled(valid) end
  end
  return page
end

local function CreateCompletePage()
  local page = CreateFrame("Frame", nil, frame.content)
  page:SetAllPoints(); page:Hide()

  local title = Text(page, "RETREATUI IS READY", 27, true)
  title:SetPoint("TOP", 0, -48)
  local subtitle = Text(page, "The complete supported setup has been installed and validated.", 13, false)
  subtitle:SetPoint("TOP", 0, -92)

  local card = Panel(page, RUI:GetTheme().panelSoft, RUI:GetTheme().accent)
  card:SetPoint("TOPLEFT", 92, -150)
  card:SetPoint("TOPRIGHT", -92, -150)
  card:SetHeight(220)

  local check = card:CreateTexture(nil, "ARTWORK")
  check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:SetSize(52, 52)
  check:SetPoint("TOP", 0, -28)
  check:SetVertexColor(0.25, 1, 0.25, 1)

  page.message = Text(card, "", 13, false)
  page.message:SetPoint("TOPLEFT", 30, -100)
  page.message:SetPoint("TOPRIGHT", -30, -100)
  page.message:SetJustifyH("CENTER")
  page.message:SetSpacing(8)

  page.reload = Button(page, "FINISH & RELOAD", 172, 36, function()
    local valid, problems = RUI:ValidateInstallation()
    if not valid then
      SetStatusText(page.message, "error", table.concat(problems or {"Validation failed."}, "\n"))
      page.reload:SetEnabled(false)
      return
    end
    local db = RUI:EnsureDB()
    db.installer.completedVersion = RUI.version
    db.installer.initialCompleted = true
    db.installer.lastAttemptOK = true
    ReloadUI()
  end)
  page.reload:SetPoint("BOTTOM", 0, 52)

  page.Refresh = function()
    local valid, problems = RUI:ValidateInstallation()
    page.reload:SetEnabled(valid)
    if valid then
      local warnings = RUI:GetOptionalIntegrationWarnings()
      if #warnings > 0 then
        SetStatusText(page.message, "optional", "The required RetreatUI setup is ready.\nOptional integration warning: " .. table.concat(warnings, "  •  "))
      else
        SetStatusText(page.message, "success", "ElvUI, the class HUD, TurboPlates, NPC tracking and Details! are ready.\nDBM styling was applied when available.")
      end
    else
      SetStatusText(page.message, "error", table.concat(problems or {"Validation failed."}, "\n"))
    end
  end
  return page
end

function Installer:ShowPage(index)
  index = tonumber(index) or 1
  if index < 1 then index = 1 elseif index > #PAGE_DEFS then index = #PAGE_DEFS end

  if index == 2 then
    local ready = RUI:GetInstallerReadiness(false)
    if not ready then index = 1 end
  elseif index == 3 then
    local valid = RUI:ValidateInstallation()
    if not valid then index = 2 end
  end

  currentPage = index
  for pageIndex = 1, #PAGE_DEFS do
    if pageFrames[pageIndex] then
      if pageIndex == index then pageFrames[pageIndex]:Show() else pageFrames[pageIndex]:Hide() end
    end
    local nav = navButtons[pageIndex]
    if nav then
      local theme = RUI:GetTheme()
      if pageIndex == index then
        nav:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
        nav:SetBackdropColor(theme.accent[1] * 0.12, theme.accent[2] * 0.12, theme.accent[3] * 0.12, 1)
      else
        nav:SetBackdropBorderColor(0.14, 0.10, 0.10, 1)
        nav:SetBackdropColor(theme.sidebar[1], theme.sidebar[2], theme.sidebar[3], 1)
      end
    end
  end

  local targetPage = pageFrames[index]
  if targetPage and type(targetPage.Refresh) == "function" then
    local ok, err = pcall(targetPage.Refresh)
    if not ok then RUI:Print("Installer refresh failed: " .. tostring(err)) end
  end

  frame.back:SetEnabled(index > 1)
  frame.next:Show()
  frame.next:SetLabel(index == 1 and "CONTINUE" or "NEXT")
  if index == 3 then
    frame.next:Hide()
  elseif index == 1 then
    frame.next:SetEnabled(select(1, RUI:GetInstallerReadiness(false)))
  elseif index == 2 then
    frame.next:SetEnabled(select(1, RUI:ValidateInstallation()))
  end
  frame.progress:SetText(index .. " / " .. #PAGE_DEFS)
  return true
end

local function BuildInstaller()
  if frame then return frame end
  local theme = RUI:GetTheme()
  frame = Panel(UIParent, theme.background, {theme.accent[1], theme.accent[2], theme.accent[3], 1})
  frame:SetSize(980, 630)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

  frame.sidebar = Panel(frame, theme.sidebar, {0, 0, 0, 1})
  frame.sidebar:SetPoint("TOPLEFT", 4, -4)
  frame.sidebar:SetPoint("BOTTOMLEFT", 4, 4)
  frame.sidebar:SetWidth(220)

  frame.content = Panel(frame, theme.background, {0, 0, 0, 1})
  frame.content:SetPoint("TOPLEFT", 228, -4)
  frame.content:SetPoint("BOTTOMRIGHT", -4, 58)

  frame.footer = Panel(frame, theme.sidebar, {0, 0, 0, 1})
  frame.footer:SetPoint("BOTTOMLEFT", 228, 4)
  frame.footer:SetPoint("BOTTOMRIGHT", -4, 4)
  frame.footer:SetHeight(50)

  local logo = frame.sidebar:CreateTexture(nil, "ARTWORK")
  logo:SetTexture("Interface\\AddOns\\RetreatUI\\Media\\RetreatUI_Logo.tga")
  logo:SetSize(112, 92)
  logo:SetPoint("TOP", 0, -12)
  local heading = Text(frame.sidebar, "RETREATUI", 16, true)
  heading:SetPoint("TOP", 0, -103)
  local version = Text(frame.sidebar, "VERSION " .. tostring(RUI.version), 9, false)
  version:SetPoint("TOP", 0, -126)

  for index, def in ipairs(PAGE_DEFS) do
    local nav = CreateFrame("Frame", nil, frame.sidebar)
    RUI:SkinFrame(nav, theme.sidebar, {0.14, 0.10, 0.10, 1})
    nav:SetSize(192, 48)
    nav:SetPoint("TOP", 0, -168 - (index - 1) * 58)
    local number = Text(nav, tostring(index), 13, true)
    number:SetPoint("LEFT", 14, 0)
    local title = Text(nav, def.title, 10, false)
    title:SetPoint("TOPLEFT", 44, -9)
    local subtitle = Text(nav, def.subtitle, 8, false)
    subtitle:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
    subtitle:SetPoint("BOTTOMLEFT", 44, 9)
    navButtons[index] = nav
  end

  pageFrames[1] = CreateWelcomePage()
  pageFrames[2] = CreateInstallPage()
  pageFrames[3] = CreateCompletePage()

  frame.back = Button(frame.footer, "BACK", 100, 30, function() Installer:ShowPage(currentPage - 1) end)
  frame.back:SetPoint("LEFT", 18, 0)
  frame.close = Button(frame.footer, "CLOSE", 100, 30, function() frame:Hide() end)
  frame.close:SetPoint("LEFT", 128, 0)
  frame.next = Button(frame.footer, "CONTINUE", 112, 30, function() Installer:ShowPage(currentPage + 1) end)
  frame.next:SetPoint("RIGHT", -18, 0)
  frame.progress = Text(frame.footer, "", 9, false)
  frame.progress:SetPoint("CENTER")
  return frame
end

function RUI:HideInstaller()
  if frame then frame:Hide() end
end

function RUI:ShowInstaller(force)
  if type(self.IsSupportedCharacter) == "function" and not self:IsSupportedCharacter() then
    self:HideInstaller()
    self:Print(self:GetUnsupportedMessage())
    return false
  end
  BuildInstaller()
  frame:Show()
  Installer:ShowPage(1)
  return true
end

function RUI:RefreshInstallerTheme()
  if frame then
    frame:Hide()
    frame = nil
    pageFrames = {}
    navButtons = {}
    currentPage = 1
  end
end

RUI._installerLoaded = true

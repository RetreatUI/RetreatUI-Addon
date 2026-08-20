local RUI = RetreatUI
local Installer = {}
RUI.Installer = Installer

local frame, currentPage
local pages, navButtons = {}, {}
local PAGE_DEFS = {
  {title="READINESS", subtitle="Check requirements"},
  {title="COMPONENTS", subtitle="Choose integrations"},
  {title="INSTALL", subtitle="Apply and validate"},
  {title="COMPLETE", subtitle="Ready to play"},
}

local function Theme() return RUI:GetTheme() end

local function Text(parent, value, size, color)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  RUI:ApplyFont(fs, size or 11, "OUTLINE")
  fs:SetText(value or "")
  color = color or Theme().text
  fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  return fs
end

local function Panel(parent, bg, border)
  local panel = CreateFrame("Frame", nil, parent)
  RUI:SkinFrame(panel, bg or Theme().panel, border or {0,0,0,1})
  return panel
end

local function Button(parent, label, width, height, callback)
  local theme = Theme()
  local button = CreateFrame("Button", nil, parent)
  RUI:SkinFrame(button, theme.panelStrong, {theme.accent[1]*0.58, theme.accent[2]*0.58, theme.accent[3]*0.58, 1})
  button:SetSize(width or 130, height or 30)
  button:EnableMouse(true)
  button:RegisterForClicks("LeftButtonUp")
  button.label = Text(button, label, 9)
  button.label:SetPoint("CENTER")
  button:SetScript("OnClick", function(self)
    if not self.disabled and callback then callback(self) end
  end)
  button:SetScript("OnEnter", function(self)
    if not self.disabled then self:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1) end
  end)
  button:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(theme.accent[1]*0.58, theme.accent[2]*0.58, theme.accent[3]*0.58, 1)
  end)
  function button:SetLabel(value) self.label:SetText(value or "") end
  function button:SetEnabled(enabled)
    self.disabled = not enabled
    self:SetAlpha(enabled and 1 or 0.35)
    self:EnableMouse(enabled)
  end
  return button
end

local function StatusColor(state)
  local theme = Theme()
  if state == "success" or state == "ready" or state == "installed" then return theme.success end
  if state == "running" then return theme.accent end
  if state == "optional" or state == "skipped" or state == "disabled" then return theme.muted end
  return theme.danger
end

local function SetStatus(fs, state, label)
  local color = StatusColor(state)
  fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  fs:SetText(label or "")
end

local function SetRowState(row, state, label, detail)
  if row.status then SetStatus(row.status, state, label) end
  if row.detail then
    local theme = Theme()
    row.detail:SetText(detail or "")
    row.detail:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
  end
  if row.marker then
    local color = StatusColor(state)
    row.marker:SetVertexColor(color[1], color[2], color[3], 0.95)
  end
end

local function PageTitle(page, title, description)
  local theme = Theme()
  local titleText = Text(page, title, 24, theme.text)
  titleText:SetPoint("TOPLEFT", 28, -24)
  local descriptionText = Text(page, description, 10, theme.muted)
  descriptionText:SetPoint("TOPLEFT", 28, -58)
  descriptionText:SetWidth(610)
  descriptionText:SetJustifyH("LEFT")
end

local function SectionLabel(parent, value, y)
  local theme = Theme()
  local label = Text(parent, value, 9, theme.accent)
  label:SetPoint("TOPLEFT", 28, y)
  return label
end

local function CreateListRow(parent, index, top, height)
  local theme = Theme()
  local row = Panel(parent, {theme.panel[1], theme.panel[2], theme.panel[3], 0.76}, {theme.dim[1], theme.dim[2], theme.dim[3], 0.34})
  row:SetPoint("TOPLEFT", 28, top - ((index-1) * (height + 5)))
  row:SetPoint("RIGHT", -28, 0)
  row:SetHeight(height)

  row.marker = row:CreateTexture(nil, "ARTWORK")
  row.marker:SetTexture("Interface\\Buttons\\WHITE8X8")
  row.marker:SetSize(3, height - 12)
  row.marker:SetPoint("LEFT", 7, 0)
  row.marker:SetVertexColor(theme.muted[1], theme.muted[2], theme.muted[3], 0.75)

  row.label = Text(row, "", 10, theme.text)
  row.label:SetPoint("TOPLEFT", 19, -7)
  row.label:SetWidth(270)
  row.label:SetJustifyH("LEFT")

  row.detail = Text(row, "", 8, theme.muted)
  row.detail:SetPoint("BOTTOMLEFT", 19, 6)
  row.detail:SetWidth(420)
  row.detail:SetJustifyH("LEFT")

  row.status = Text(row, "", 9, theme.muted)
  row.status:SetPoint("RIGHT", -12, 0)
  row.status:SetWidth(115)
  row.status:SetJustifyH("RIGHT")
  return row
end

local function DependencyRepairText(dependency, status)
  if status == "Version mismatch" then
    return "Replace RetreatUI and RetreatUI_Classes with matching versions."
  end
  if status == "Missing" then
    if dependency.key == "classes" then return "Install both RetreatUI folders from the same ZIP." end
    return "Install " .. tostring(dependency.label) .. " before continuing."
  end
  if status == "Could not load" then return "Enable the addon at character selection, then check again." end
  if dependency.required then return "Required component detected and ready." end
  return "Optional component. RetreatUI will continue without it."
end

local function CreateReadinessPage()
  local theme = Theme()
  local page = CreateFrame("Frame", nil, frame.content)
  page:SetAllPoints()
  page:Hide()
  PageTitle(page, "System readiness", "RetreatUI checks the current class and every required addon before changing any profiles.")

  local summary = Panel(page, {theme.panelStrong[1], theme.panelStrong[2], theme.panelStrong[3], 0.82}, {theme.dim[1], theme.dim[2], theme.dim[3], 0.42})
  summary:SetPoint("TOPLEFT", 28, -91)
  summary:SetPoint("TOPRIGHT", -28, -91)
  summary:SetHeight(60)
  summary.class = Text(summary, "", 13, theme.text)
  summary.class:SetPoint("TOPLEFT", 16, -11)
  summary.version = Text(summary, "RetreatUI " .. tostring(RUI.version), 9, theme.muted)
  summary.version:SetPoint("BOTTOMLEFT", 16, 10)
  summary.state = Text(summary, "CHECKING", 10, theme.muted)
  summary.state:SetPoint("RIGHT", -16, 0)
  page.summary = summary

  SectionLabel(page, "REQUIREMENTS", -174)
  page.rows = {}
  local dependencies = {}
  for _, dependency in ipairs(RUI.installerDependencies or {}) do dependencies[#dependencies+1] = dependency end
  for index, dependency in ipairs(dependencies) do
    local row = CreateListRow(page, index, -194, 42)
    row.label:SetText(dependency.label .. (dependency.required and "  •  Required" or "  •  Optional"))
    page.rows[index] = row
  end

  page.notice = Text(page, "", 9, theme.muted)
  page.notice:SetPoint("BOTTOMLEFT", 28, 22)
  page.notice:SetWidth(500)
  page.notice:SetJustifyH("LEFT")
  page.refresh = Button(page, "CHECK AGAIN", 128, 28, function() page.Refresh() end)
  page.refresh:SetPoint("BOTTOMRIGHT", -28, 16)

  page.Refresh = function()
    local className = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or "Unknown"
    summary.class:SetText(tostring(className) .. " setup")
    local ready = true
    for index, dependency in ipairs(dependencies) do
      local available, status = RUI:GetDependencyStatus(dependency, false)
      local row = page.rows[index]
      if available then
        SetRowState(row, "ready", status == "Loaded" and "LOADED" or "READY", DependencyRepairText(dependency, status))
      elseif dependency.required then
        ready = false
        SetRowState(row, "error", status == "Version mismatch" and "MISMATCH" or "MISSING", DependencyRepairText(dependency, status))
      else
        SetRowState(row, "optional", "OPTIONAL", DependencyRepairText(dependency, status))
      end
    end
    if type(RUI.IsSupportedCharacter) == "function" and not RUI:IsSupportedCharacter() then ready = false end
    SetStatus(summary.state, ready and "ready" or "error", ready and "READY" or "ACTION REQUIRED")
    SetStatus(page.notice, ready and "ready" or "error", ready and "All required components are ready to install." or "Resolve the red requirement before continuing.")
    page.ready = ready
    if frame and frame.next and currentPage == 1 then frame.next:SetEnabled(ready) end
  end
  return page
end

local function ResolveModuleIcon(definition)
  local icon = definition and definition.icon
  if type(icon) == "function" then
    local ok, value = pcall(icon, RUI)
    icon = ok and value or nil
  end
  if type(icon) ~= "string" or icon == "" then icon = "Interface\\Icons\\INV_Misc_Gear_01" end
  return icon
end

local function ModuleAvailability(definition)
  if not definition or not definition.available then return true end
  local ok, available = pcall(definition.available, RUI)
  return ok and available == true
end

local function CreateComponentRow(parent, key, definition, index, page)
  local theme = Theme()
  local row = CreateListRow(parent, index, -110, 34)
  row.label:ClearAllPoints()
  row.label:SetPoint("LEFT", 52, 0)
  row.label:SetWidth(280)
  row.label:SetText(definition.label)
  row.detail:Hide()

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetTexture(ResolveModuleIcon(definition))
  row.icon:SetSize(24,24)
  row.icon:SetPoint("LEFT", 19, 0)
  row.icon:SetTexCoord(.08,.92,.08,.92)

  row.requirement = Text(row, definition.required and "REQUIRED" or "OPTIONAL", 7, definition.required and theme.accent or theme.muted)
  row.requirement:SetPoint("LEFT", 335, 0)
  row.requirement:SetWidth(70)
  row.requirement:SetJustifyH("LEFT")

  row.status:ClearAllPoints()
  row.status:SetPoint("RIGHT", -88, 0)
  row.status:SetWidth(92)

  row.toggle = Button(row, "ON", 64, 22, function()
    if definition.selectable == false then return end
    RUI:SetInstallerModuleEnabled(key, not RUI:IsInstallerModuleEnabled(key))
    page.Refresh()
  end)
  row.toggle:SetPoint("RIGHT", -10, 0)
  return row
end

local function CreateComponentsPage()
  local theme = Theme()
  local page = CreateFrame("Frame", nil, frame.content)
  page:SetAllPoints()
  page:Hide()
  PageTitle(page, "Choose components", "Required systems stay enabled. Optional integrations can be changed without resetting existing profiles.")
  SectionLabel(page, "INSTALLATION COMPONENTS", -88)

  page.rows = {}
  for index, key in ipairs(RUI.moduleOrder or {}) do
    local definition = RUI.moduleInstallers[key]
    if definition then page.rows[key] = CreateComponentRow(page, key, definition, index, page) end
  end

  page.note = Text(page, "Existing RetreatUI positions, assignments and profiles are preserved during updates.", 9, theme.muted)
  page.note:SetPoint("BOTTOMLEFT", 28, 22)
  page.note:SetWidth(560)

  page.Refresh = function()
    local ready = select(1, RUI:GetInstallerReadiness(false))
    for _, key in ipairs(RUI.moduleOrder or {}) do
      local definition = RUI.moduleInstallers[key]
      local row = page.rows[key]
      if definition and row then
        local enabled = RUI:IsInstallerModuleEnabled(key)
        local available = ModuleAvailability(definition)
        if definition.selectable == false then
          row.toggle:SetLabel("LOCKED")
          row.toggle:SetEnabled(false)
        else
          row.toggle:SetLabel(enabled and "ON" or "OFF")
          row.toggle:SetEnabled(true)
        end
        if not enabled then
          SetRowState(row, "disabled", "DISABLED")
        elseif available then
          SetRowState(row, "ready", "READY")
        elseif definition.required then
          ready = false
          SetRowState(row, "error", "MISSING")
        else
          SetRowState(row, "optional", "SKIPPED")
        end
      end
    end
    page.ready = ready
    if frame and frame.next and currentPage == 2 then frame.next:SetEnabled(ready) end
  end
  return page
end

local function CreateInstallStatusRow(parent, key, definition, index)
  local row = CreateListRow(parent, index, -110, 34)
  row.label:ClearAllPoints()
  row.label:SetPoint("LEFT", 19, 0)
  row.label:SetWidth(340)
  row.label:SetText(definition.label)
  row.detail:Hide()
  row.status:ClearAllPoints()
  row.status:SetPoint("RIGHT", -14, 0)
  row.status:SetWidth(140)
  return row
end

local function CreateInstallPage()
  local theme = Theme()
  local page = CreateFrame("Frame", nil, frame.content)
  page:SetAllPoints()
  page:Hide()
  PageTitle(page, "Install RetreatUI", "The selected modules are applied in order and validated before the setup is marked complete.")
  SectionLabel(page, "INSTALLATION PROGRESS", -88)

  page.rows = {}
  for index, key in ipairs(RUI.moduleOrder or {}) do
    local definition = RUI.moduleInstallers[key]
    if definition then page.rows[key] = CreateInstallStatusRow(page, key, definition, index) end
  end

  page.result = Text(page, "Ready to install.", 9, theme.muted)
  page.result:SetPoint("BOTTOMLEFT", 28, 22)
  page.result:SetWidth(470)
  page.result:SetJustifyH("LEFT")

  page.install = Button(page, "INSTALL", 150, 30, function(button)
    button:SetEnabled(false)
    button:SetLabel("INSTALLING")
    page.installed = false
    for _, key in ipairs(RUI.moduleOrder or {}) do
      local row = page.rows[key]
      if row then SetRowState(row, "optional", "WAITING") end
    end

    local valid, problems = RUI:InstallAllModules(function(key, state)
      local row = page.rows[key]
      if not row then return end
      local labels = {running="INSTALLING", success="INSTALLED", skipped="SKIPPED", error="FAILED"}
      SetRowState(row, state, labels[state] or "FAILED")
    end)

    if valid then
      if type(RUI.MarkClassInstallCompleted) == "function" then RUI:MarkClassInstallCompleted() end
      local warnings = RUI:GetOptionalIntegrationWarnings()
      page.installed = true
      SetStatus(page.result, #warnings > 0 and "optional" or "success", #warnings > 0 and ("Installed with optional warnings: " .. table.concat(warnings, " • ")) or "Installation completed and validated.")
      button:SetLabel("INSTALLED")
      button:SetEnabled(false)
    else
      SetStatus(page.result, "error", table.concat(problems or {"Installation failed."}, " • "))
      button:SetLabel("RETRY")
      button:SetEnabled(true)
    end
    if frame and frame.next and currentPage == 3 then frame.next:SetEnabled(valid) end
  end)
  page.install:SetPoint("BOTTOMRIGHT", -28, 16)

  page.Refresh = function()
    local valid = select(1, RUI:ValidateInstallation())
    local ready = select(1, RUI:GetInstallerReadiness(false))
    for _, key in ipairs(RUI.moduleOrder or {}) do
      local row = page.rows[key]
      local definition = RUI.moduleInstallers[key]
      if row and definition then
        local enabled = RUI:IsInstallerModuleEnabled(key)
        local record = RUI:GetModuleStatus(key)
        if not enabled then
          SetRowState(row, "skipped", "DISABLED")
        elseif record and record.version == RUI.version then
          local labels = {success="INSTALLED", skipped="SKIPPED", error="FAILED"}
          SetRowState(row, record.state, labels[record.state] or string.upper(record.state or "FAILED"))
        elseif not ModuleAvailability(definition) then
          SetRowState(row, definition.required and "error" or "optional", definition.required and "MISSING" or "SKIPPED")
        else
          SetRowState(row, "ready", "READY")
        end
      end
    end
    page.installed = valid
    page.install:SetLabel(valid and "INSTALLED" or "INSTALL")
    page.install:SetEnabled(ready and not valid)
    if valid then SetStatus(page.result, "success", "Installation is already complete for this version.")
    elseif ready then SetStatus(page.result, "ready", "Ready to install. No existing profiles will be reset.")
    else SetStatus(page.result, "error", "A required component is missing.") end
    if frame and frame.next and currentPage == 3 then frame.next:SetEnabled(valid) end
  end
  return page
end

local function CreateCompletePage()
  local theme = Theme()
  local page = CreateFrame("Frame", nil, frame.content)
  page:SetAllPoints()
  page:Hide()
  PageTitle(page, "Setup complete", "RetreatUI has validated the core, class HUD and selected integrations.")

  local card = Panel(page, {theme.panelStrong[1], theme.panelStrong[2], theme.panelStrong[3], 0.86}, {theme.dim[1], theme.dim[2], theme.dim[3], 0.44})
  card:SetPoint("TOPLEFT", 28, -103)
  card:SetPoint("TOPRIGHT", -28, -103)
  card:SetHeight(230)
  card.check = card:CreateTexture(nil, "ARTWORK")
  card.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  card.check:SetSize(52,52)
  card.check:SetPoint("TOP", 0, -26)
  card.check:SetVertexColor(theme.success[1], theme.success[2], theme.success[3], 1)
  card.title = Text(card, "RETREATUI IS READY", 16, theme.text)
  card.title:SetPoint("TOP", 0, -91)
  card.message = Text(card, "", 10, theme.muted)
  card.message:SetPoint("TOP", 0, -126)
  card.message:SetWidth(560)
  card.message:SetHeight(72)
  card.message:SetJustifyH("CENTER")
  card.message:SetJustifyV("TOP")
  page.card = card

  page.close = Button(page, "CLOSE", 130, 30, function() frame:Hide() end)
  page.close:SetPoint("BOTTOMLEFT", 28, 18)
  page.reload = Button(page, "FINISH & RELOAD", 170, 30, function()
    local valid, problems = RUI:ValidateInstallation()
    if not valid then
      SetStatus(card.message, "error", table.concat(problems or {"Validation failed."}, "\n"))
      return
    end
    local db = RUI:EnsureDB()
    db.installer.lastAttemptOK = true
    if type(RUI.MarkClassInstallCompleted) == "function" then RUI:MarkClassInstallCompleted() end
    ReloadUI()
  end)
  page.reload:SetPoint("BOTTOMRIGHT", -28, 18)

  page.Refresh = function()
    local valid, problems = RUI:ValidateInstallation()
    page.reload:SetEnabled(valid)
    card.check:SetVertexColor((valid and theme.success or theme.danger)[1], (valid and theme.success or theme.danger)[2], (valid and theme.success or theme.danger)[3], 1)
    SetStatus(card.message, valid and "success" or "error", valid and "Your current class setup is installed. Reload once to apply every protected frame safely." or table.concat(problems or {"Validation failed."}, "\n"))
  end
  return page
end

function Installer:ShowPage(index)
  index = math.max(1, math.min(#PAGE_DEFS, tonumber(index) or 1))
  if index >= 2 and not select(1, RUI:GetInstallerReadiness(false)) then index = 1 end
  if index == 4 and not select(1, RUI:ValidateInstallation()) then index = 3 end
  currentPage = index
  local theme = Theme()

  for i=1,#PAGE_DEFS do
    if pages[i] then if i == index then pages[i]:Show() else pages[i]:Hide() end end
    local nav = navButtons[i]
    if nav then
      if i == index then
        nav:SetBackdropColor(theme.accent[1]*0.13, theme.accent[2]*0.13, theme.accent[3]*0.13, 1)
        nav:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.92)
        nav.number:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
      else
        nav:SetBackdropColor(theme.sidebar[1], theme.sidebar[2], theme.sidebar[3], 1)
        nav:SetBackdropBorderColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.38)
        nav.number:SetTextColor(theme.muted[1], theme.muted[2], theme.muted[3], 1)
      end
    end
  end

  if pages[index] and pages[index].Refresh then
    local ok, err = pcall(pages[index].Refresh)
    if not ok and RUI.Print then RUI:Print("Installer refresh failed: " .. tostring(err)) end
  end

  frame.back:SetEnabled(index > 1)
  if index == 1 then frame.next:SetLabel("CONTINUE"); frame.next:SetEnabled(pages[1].ready == true)
  elseif index == 2 then frame.next:SetLabel("CONTINUE"); frame.next:SetEnabled(pages[2].ready == true)
  elseif index == 3 then frame.next:SetLabel("COMPLETE"); frame.next:SetEnabled(select(1, RUI:ValidateInstallation()))
  end
  if index == 4 then frame.next:Hide() else frame.next:Show() end
  frame.progress:SetText(index .. " / " .. #PAGE_DEFS)
end

local function BuildInstaller()
  if frame then return frame end
  local theme = Theme()
  frame = Panel(UIParent, theme.background, {theme.dim[1], theme.dim[2], theme.dim[3], 0.86})
  frame:SetSize(930, 580)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  frame.topAccent = frame:CreateTexture(nil, "ARTWORK")
  frame.topAccent:SetTexture("Interface\\Buttons\\WHITE8X8")
  frame.topAccent:SetPoint("TOPLEFT", 1, -1)
  frame.topAccent:SetPoint("TOPRIGHT", -1, -1)
  frame.topAccent:SetHeight(3)
  frame.topAccent:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.94)

  frame.sidebar = Panel(frame, theme.sidebar, {theme.dim[1], theme.dim[2], theme.dim[3], 0.34})
  frame.sidebar:SetPoint("TOPLEFT", 4, -4)
  frame.sidebar:SetPoint("BOTTOMLEFT", 4, 4)
  frame.sidebar:SetWidth(188)

  frame.content = Panel(frame, theme.background, {theme.dim[1], theme.dim[2], theme.dim[3], 0.28})
  frame.content:SetPoint("TOPLEFT", 196, -4)
  frame.content:SetPoint("BOTTOMRIGHT", -4, 55)

  frame.footer = Panel(frame, theme.sidebar, {theme.dim[1], theme.dim[2], theme.dim[3], 0.34})
  frame.footer:SetPoint("BOTTOMLEFT", 196, 4)
  frame.footer:SetPoint("BOTTOMRIGHT", -4, 4)
  frame.footer:SetHeight(47)

  local logo = frame.sidebar:CreateTexture(nil, "ARTWORK")
  logo:SetTexture("Interface\\AddOns\\RetreatUI\\Media\\RetreatUI_Logo.tga")
  logo:SetSize(82,82)
  logo:SetPoint("TOP", 0, -13)
  logo:SetAlpha(1)

  local className = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or "Unknown"
  local classText = Text(frame.sidebar, tostring(className), 11, theme.text)
  classText:SetPoint("TOP", 0, -99)
  classText:SetWidth(164)
  classText:SetJustifyH("CENTER")
  local versionText = Text(frame.sidebar, "VERSION " .. tostring(RUI.version), 8, theme.muted)
  versionText:SetPoint("TOP", 0, -121)

  for index, def in ipairs(PAGE_DEFS) do
    local nav = Panel(frame.sidebar, theme.sidebar, {theme.dim[1], theme.dim[2], theme.dim[3], 0.38})
    nav:SetSize(160, 50)
    nav:SetPoint("TOP", 0, -158 - ((index-1)*58))
    nav.number = Text(nav, string.format("0%d", index), 11, theme.muted)
    nav.number:SetPoint("LEFT", 11, 0)
    nav.title = Text(nav, def.title, 9, theme.text)
    nav.title:SetPoint("TOPLEFT", 42, -9)
    nav.subtitle = Text(nav, def.subtitle, 8, theme.muted)
    nav.subtitle:SetPoint("BOTTOMLEFT", 42, 9)
    navButtons[index] = nav
  end

  local safety = Text(frame.sidebar, "Profiles are preserved\nunless you explicitly reset them.", 8, theme.muted)
  safety:SetPoint("BOTTOM", 0, 22)
  safety:SetWidth(164)
  safety:SetJustifyH("CENTER")

  pages[1] = CreateReadinessPage()
  pages[2] = CreateComponentsPage()
  pages[3] = CreateInstallPage()
  pages[4] = CreateCompletePage()

  frame.back = Button(frame.footer, "BACK", 92, 27, function() Installer:ShowPage(currentPage-1) end)
  frame.back:SetPoint("LEFT", 14, 0)
  frame.close = Button(frame.footer, "CLOSE", 92, 27, function() frame:Hide() end)
  frame.close:SetPoint("LEFT", 114, 0)
  frame.next = Button(frame.footer, "CONTINUE", 116, 27, function() Installer:ShowPage(currentPage+1) end)
  frame.next:SetPoint("RIGHT", -14, 0)
  frame.progress = Text(frame.footer, "", 9, theme.muted)
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
    pages = {}
    navButtons = {}
    currentPage = 1
  end
end

RUI._installerLoaded = true

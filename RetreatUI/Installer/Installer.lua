local RUI = RetreatUI
local Installer = {}
RUI.Installer = Installer

local frame, currentPage
local pages, navButtons = {}, {}
local PAGE_DEFS = {
  {title="WELCOME", subtitle="System check"},
  {title="INSTALL", subtitle="Apply setup"},
  {title="COMPLETE", subtitle="Validation"},
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
  RUI:SkinFrame(button, theme.panelStrong, {theme.accent[1]*0.55, theme.accent[2]*0.55, theme.accent[3]*0.55, 1})
  button:SetSize(width or 130, height or 32)
  button:EnableMouse(true)
  button:RegisterForClicks("LeftButtonUp")
  button.label = Text(button, label, 10)
  button.label:SetPoint("CENTER")
  button:SetScript("OnClick", function(self) if not self.disabled and callback then callback(self) end end)
  button:SetScript("OnEnter", function(self)
    if not self.disabled then self:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1) end
  end)
  button:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(theme.accent[1]*0.55, theme.accent[2]*0.55, theme.accent[3]*0.55, 1)
  end)
  function button:SetLabel(value) self.label:SetText(value) end
  function button:SetEnabled(enabled)
    self.disabled = not enabled
    self:SetAlpha(enabled and 1 or 0.34)
    self:EnableMouse(enabled)
  end
  return button
end
local function SetStatus(fs, state, label)
  local theme = Theme()
  local color = theme.danger
  if state == "success" or state == "ready" then color = theme.success
  elseif state == "optional" or state == "skipped" then color = theme.muted
  elseif state == "running" then color = theme.accent end
  fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  fs:SetText(label or "")
end

local function Artwork(parent)
  local theme = Theme()
  local visual = theme.installer
  local art = parent:CreateTexture(nil, "BACKGROUND")
  art:SetTexture(visual.artwork)
  art:SetAllPoints(parent)
  local crop = visual.artworkCrop or {0,1,0,1}
  art:SetTexCoord(crop[1] or 0, crop[2] or 1, crop[3] or 0, crop[4] or 1)
  art:SetAlpha(visual.artworkAlpha or 0.92)

  -- The class artwork now fills the entire installer page. A single even tint
  -- preserves readability without hiding the artwork behind a directional fade.
  local tint = parent:CreateTexture(nil, "BORDER")
  tint:SetTexture("Interface\\Buttons\\WHITE8X8")
  tint:SetAllPoints(parent)
  tint:SetVertexColor(theme.background[1], theme.background[2], theme.background[3], 0.32)
  return art
end

local function ClassCard(parent)
  local theme, info = Theme(), RUI:GetClassInfo()
  local visual = theme.installer

  -- Permanent installer rule: class artwork is used once as the page background.
  -- No class thumbnail/icon is rendered here for any current or future class.
  local card = CreateFrame("Frame", nil, parent)
  card:SetSize(455, 88)

  local title = Text(card, visual.title or info.name, 18, theme.accent)
  title:SetPoint("TOPLEFT", 14, -7)
  local subtitle = Text(card, visual.subtitle or visual.loadout, 10, theme.accent2)
  subtitle:SetPoint("TOPLEFT", 14, -35)
  local description = Text(card, visual.description, 9, theme.muted)
  description:SetPoint("TOPLEFT", 14, -61)
  description:SetPoint("RIGHT", -14, 0)
  description:SetJustifyH("LEFT")
  return card
end

local function DependencyTile(parent, dependency, index)
  local theme = Theme()

  -- Dependency entries are intentionally unboxed so the class artwork remains
  -- visible across the full welcome page.
  local tile = CreateFrame("Frame", nil, parent)
  tile:SetSize(205, 34)
  tile:SetPoint("TOPLEFT", ((index-1)%2)*215, -30 - math.floor((index-1)/2)*42)

  local marker = tile:CreateTexture(nil, "ARTWORK")
  marker:SetTexture("Interface\\Buttons\\WHITE8X8")
  marker:SetSize(2, 18)
  marker:SetPoint("LEFT", 0, 0)
  marker:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.8)

  tile.name = Text(tile, dependency.label, 9)
  tile.name:SetPoint("LEFT", 10, 0)
  tile.status = Text(tile, "CHECKING", 8, theme.muted)
  tile.status:SetPoint("RIGHT", -6, 0)
  return tile
end

local function CreateWelcomePage()
  local theme = Theme()
  local page = CreateFrame("Frame", nil, frame.content); page:SetAllPoints(); page:Hide()
  Artwork(page)

  local eyebrow = Text(page, "CONQUEST OF AZEROTH", 9, theme.accent2)
  eyebrow:SetPoint("TOPLEFT", 30, -26)
  local title = Text(page, "WELCOME", 30, theme.text)
  title:SetPoint("TOPLEFT", 30, -48)
  local subtitle = Text(page, "One framework. Class-aware HUDs. One complete setup.", 12, theme.muted)
  subtitle:SetPoint("TOPLEFT", 30, -87)

  page.classCard = ClassCard(page)
  page.classCard:SetPoint("TOPLEFT", 30, -120)

  -- Supported setup is now presented directly on the artwork without an
  -- enclosing panel.
  local setup = CreateFrame("Frame", nil, page)
  setup:SetSize(455, 48)
  setup:SetPoint("TOPLEFT", 30, -226)
  Text(setup, "SUPPORTED SETUP", 9, theme.accent):SetPoint("TOPLEFT", 0, -2)
  local info = RUI:GetClassInfo(); local visual = theme.installer
  local setupText = Text(setup, tostring(info.name) .. "  •  1920 × 1080  •  " .. tostring(visual.loadout), 9, theme.text)
  setupText:SetPoint("TOPLEFT", 0, -27)

  local deps = {}
  for _, dependency in ipairs(RUI.installerDependencies or {}) do if not dependency.hidden then deps[#deps+1] = dependency end end

  -- Addon status uses an open two-column list, matching the installer module
  -- page and leaving the class background fully visible.
  local dependencyPanel = CreateFrame("Frame", nil, page)
  dependencyPanel:SetSize(430, 172)
  dependencyPanel:SetPoint("TOPLEFT", 30, -286)
  Text(dependencyPanel, "ADDON STATUS", 10, theme.accent):SetPoint("TOPLEFT", 0, -2)
  page.dependencyRows = {}
  for index, dependency in ipairs(deps) do page.dependencyRows[index] = DependencyTile(dependencyPanel, dependency, index) end

  page.notice = Text(page, "", 9, theme.muted)
  page.notice:SetPoint("BOTTOMLEFT", 30, 25)
  page.refresh = Button(dependencyPanel, "CHECK AGAIN", 118, 28, function() page.Refresh() end)
  page.refresh:SetPoint("BOTTOMRIGHT", 0, 4)

  page.Refresh = function()
    local ready = true
    for index, dependency in ipairs(deps) do
      local available, status = RUI:GetDependencyStatus(dependency, false)
      local row = page.dependencyRows[index]
      if available then SetStatus(row.status, "ready", status == "Loaded" and "LOADED" or "READY")
      elseif dependency.required then ready = false; SetStatus(row.status, "error", status == "Version mismatch" and "MISMATCH" or "MISSING")
      else SetStatus(row.status, "optional", "OPTIONAL") end
    end
    if type(RUI.IsSupportedCharacter) == "function" and not RUI:IsSupportedCharacter() then ready = false end
    SetStatus(page.notice, ready and "ready" or "error", ready and "All required components are ready." or "A required component is missing or unsupported.")
    if frame and frame.next then frame.next:SetEnabled(ready) end
  end
  return page
end

local function ResolveModuleIcon(definition)
  local icon = definition and definition.icon
  if type(icon) == "function" then
    local ok, value = pcall(icon, RUI)
    icon = ok and value or nil
  end
  if type(icon) ~= "string" or icon == "" then
    icon = "Interface\\Icons\\INV_Misc_Gear_01"
  end
  return icon
end

local function CreateInstallModuleRow(parent, key, definition, index)
  local theme = Theme()
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(510, 34)
  row:SetPoint("TOPLEFT", 30, -146 - (index-1)*39)

  -- A very light row shade keeps the list readable while allowing the class
  -- artwork to remain visible. There is deliberately no enclosing panel.
  local shade = row:CreateTexture(nil, "BACKGROUND")
  shade:SetTexture("Interface\\Buttons\\WHITE8X8")
  shade:SetAllPoints(row)
  shade:SetVertexColor(0, 0, 0, 0.34)

  local accent = row:CreateTexture(nil, "BORDER")
  accent:SetTexture("Interface\\Buttons\\WHITE8X8")
  accent:SetSize(2, 22)
  accent:SetPoint("LEFT", 0, 0)
  accent:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.9)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetTexture(ResolveModuleIcon(definition))
  row.icon:SetSize(24, 24)
  row.icon:SetPoint("LEFT", 9, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  row.label = Text(row, definition.label .. (definition.required and "" or "  (optional)"), 9)
  row.label:SetPoint("LEFT", 43, 0)

  row.status = Text(row, "WAITING", 8, theme.muted)
  row.status:SetPoint("RIGHT", -12, 0)
  return row
end

local function CreateInstallPage()
  local theme = Theme()
  local page = CreateFrame("Frame", nil, frame.content); page:SetAllPoints(); page:Hide()
  Artwork(page)
  Text(page, "INSTALL SETUP", 28, theme.text):SetPoint("TOPLEFT", 30, -34)
  local intro = Text(page, "Apply every supported profile and integration in one pass.", 11, theme.muted)
  intro:SetPoint("TOPLEFT", 30, -74)
  Text(page, "INSTALLATION MODULES", 10, theme.accent):SetPoint("TOPLEFT", 30, -112)

  page.rows = {}
  for index, key in ipairs(RUI.moduleOrder or {}) do
    local definition = RUI.moduleInstallers[key]
    page.rows[key] = CreateInstallModuleRow(page, key, definition, index)
  end

  page.refresh = Button(page, "CHECK AGAIN", 132, 30, function()
    if page.Refresh then page.Refresh() end
  end)
  page.refresh:SetPoint("BOTTOMLEFT", 30, 22)

  page.refreshHint = Text(page, "Re-scan addon and module status.", 8, theme.muted)
  page.refreshHint:SetPoint("LEFT", page.refresh, "RIGHT", 14, 0)

  page.result = Text(page, "Ready to install.", 9, theme.muted)
  page.result:SetPoint("BOTTOMLEFT", 30, 61)
  page.result:SetWidth(580)
  page.result:SetJustifyH("LEFT")

  page.install = Button(page, "INSTALL", 172, 32, function(button)
    button:SetEnabled(false); button:SetLabel("INSTALLING")
    for _, row in pairs(page.rows) do SetStatus(row.status, "optional", "WAITING") end
    local valid, problems = RUI:InstallAllModules(function(key, state)
      local row = page.rows[key]; if not row then return end
      local labels = {running="INSTALLING", success="INSTALLED", skipped="SKIPPED", error="FAILED"}
      SetStatus(row.status, state, labels[state] or "FAILED")
    end)
    if valid then
      local warnings = RUI:GetOptionalIntegrationWarnings()
      SetStatus(page.result, #warnings > 0 and "optional" or "success", #warnings > 0 and ("Installed. Optional: " .. table.concat(warnings, " • ")) or "Installation validated successfully.")
      button:SetLabel("INSTALLED")
    else
      SetStatus(page.result, "error", table.concat(problems or {"Installation failed."}, " • "))
      button:SetLabel("RETRY INSTALLATION"); button:SetEnabled(true)
    end
    if frame and frame.next then frame.next:SetEnabled(valid) end
  end)
  page.install:SetPoint("BOTTOMRIGHT", -30, 22)

  page.Refresh = function()
    local valid = RUI:ValidateInstallation()
    local ready = select(1, RUI:GetInstallerReadiness(false))

    for _, key in ipairs(RUI.moduleOrder or {}) do
      local row = page.rows[key]
      local definition = RUI.moduleInstallers[key]
      local record = RUI:GetModuleStatus(key)

      if record and record.version == RUI.version then
        local label = record.state == "success" and "INSTALLED" or string.upper(record.state or "FAILED")
        SetStatus(row.status, record.state, label)
      elseif definition and definition.available then
        local ok, available = pcall(definition.available, RUI)
        if not ok or not available then
          SetStatus(row.status, definition.required and "error" or "optional", definition.required and "MISSING" or "OPTIONAL")
        else
          SetStatus(row.status, "ready", "READY")
        end
      else
        SetStatus(row.status, "ready", "READY")
      end
    end

    page.install:SetLabel(valid and "INSTALLED" or "INSTALL")
    page.install:SetEnabled(not valid and ready)
    if valid then
      SetStatus(page.result, "success", "Installation validated successfully.")
    elseif ready then
      SetStatus(page.result, "optional", "Ready to install.")
    else
      SetStatus(page.result, "error", "A required addon or class module is missing.")
    end
    if frame and frame.next then frame.next:SetEnabled(valid) end
  end
  return page
end

local function CreateCompletePage()
  local theme = Theme()
  local page = CreateFrame("Frame", nil, frame.content); page:SetAllPoints(); page:Hide()
  Artwork(page)
  Text(page, "SETUP IS READY", 30, theme.text):SetPoint("TOPLEFT", 54, -76)
  local subtitle = Text(page, "Your class-aware setup has been installed and validated.", 12, theme.muted)
  subtitle:SetPoint("TOPLEFT", 54, -118)

  -- The completion state is shown directly on the class artwork. No large
  -- confirmation card is used on the final page.
  local check = page:CreateTexture(nil, "ARTWORK")
  check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:SetSize(58, 58)
  check:SetPoint("TOP", 0, -184)
  check:SetVertexColor(theme.success[1], theme.success[2], theme.success[3], 1)

  page.message = Text(page, "", 11, theme.text)
  page.message:SetPoint("TOP", 0, -264)
  page.message:SetWidth(560)
  page.message:SetHeight(72)
  page.message:SetJustifyH("CENTER")
  page.message:SetJustifyV("TOP")

  page.reload = Button(page, "FINISH & RELOAD", 174, 34, function()
    local valid, problems = RUI:ValidateInstallation()
    if not valid then SetStatus(page.message, "error", table.concat(problems or {"Validation failed."}, "\n")); return end
    local db = RUI:EnsureDB(); db.installer.completedVersion = RUI.version; db.installer.initialCompleted = true; db.installer.lastAttemptOK = true
    ReloadUI()
  end)
  page.reload:SetPoint("TOP", 0, -370)
  page.Refresh = function()
    local valid, problems = RUI:ValidateInstallation(); page.reload:SetEnabled(valid)
    SetStatus(page.message, valid and "success" or "error", valid and "Core, class HUD and supported integrations are ready." or table.concat(problems or {"Validation failed."}, "\n"))
  end
  return page
end

function Installer:ShowPage(index)
  index = math.max(1, math.min(#PAGE_DEFS, tonumber(index) or 1))
  if index == 2 and not select(1, RUI:GetInstallerReadiness(false)) then index = 1 end
  if index == 3 and not select(1, RUI:ValidateInstallation()) then index = 2 end
  currentPage = index
  local theme = Theme()
  for i=1,#PAGE_DEFS do
    if pages[i] then if i == index then pages[i]:Show() else pages[i]:Hide() end end
    local nav = navButtons[i]
    if nav then
      if i == index then nav:SetBackdropColor(theme.accent[1]*0.12, theme.accent[2]*0.12, theme.accent[3]*0.12, 1); nav:SetBackdropBorderColor(theme.accent[1],theme.accent[2],theme.accent[3],1)
      else nav:SetBackdropColor(theme.sidebar[1],theme.sidebar[2],theme.sidebar[3],1); nav:SetBackdropBorderColor(0,0,0,0.75) end
    end
  end
  if pages[index] and pages[index].Refresh then pcall(pages[index].Refresh) end
  frame.back:SetEnabled(index > 1)
  frame.next:SetLabel(index == 1 and "CONTINUE" or "NEXT")
  if index == 3 then frame.next:Hide() else frame.next:Show() end
  frame.progress:SetText(index .. " / " .. #PAGE_DEFS)
end

local function BuildInstaller()
  if frame then return frame end
  local theme = Theme()
  frame = Panel(UIParent, theme.background, theme.accent)
  frame:SetSize(1040, 640); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true)
  frame:EnableMouse(true); frame:SetMovable(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

  frame.sidebar = Panel(frame, theme.sidebar, {0,0,0,1}); frame.sidebar:SetPoint("TOPLEFT",4,-4); frame.sidebar:SetPoint("BOTTOMLEFT",4,4); frame.sidebar:SetWidth(194)
  frame.content = Panel(frame, theme.background, {0,0,0,1}); frame.content:SetPoint("TOPLEFT",202,-4); frame.content:SetPoint("BOTTOMRIGHT",-4,58)
  frame.footer = Panel(frame, theme.sidebar, {0,0,0,1}); frame.footer:SetPoint("BOTTOMLEFT",202,4); frame.footer:SetPoint("BOTTOMRIGHT",-4,4); frame.footer:SetHeight(50)

  -- Permanent installer rule: exactly one visible RetreatUI brand mark.
  -- Class artwork appears only as the full-page background; class thumbnails
  -- are never rendered in the welcome card.
  local logoArtwork = "Interface\\AddOns\\RetreatUI\\Media\\RetreatUI_Logo.tga"

  -- The logo texture already has feathered transparency. A slightly larger,
  -- class-tinted copy underneath creates a subtle glow without a visible box.
  local logoGlow = frame.sidebar:CreateTexture(nil, "BORDER")
  logoGlow:SetTexture(logoArtwork)
  logoGlow:SetSize(154, 154)
  logoGlow:SetPoint("TOP", 0, 1)
  logoGlow:SetTexCoord(0, 1, 0, 1)
  logoGlow:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
  logoGlow:SetAlpha(0.14)

  local logo = frame.sidebar:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(logoArtwork)
  logo:SetSize(146, 146)
  logo:SetPoint("TOP", 0, -3)
  logo:SetTexCoord(0, 1, 0, 1)
  logo:SetAlpha(1)

  -- Permanent branding rule: the RetreatUI logo texture already contains the
  -- brand name. Never draw a second RETREATUI text label above or below it.
  Text(frame.sidebar, "VERSION " .. tostring(RUI.version), 8, theme.muted):SetPoint("TOP",0,-132)
  for index, def in ipairs(PAGE_DEFS) do
    local nav = Panel(frame.sidebar, theme.sidebar, {0,0,0,0.75}); nav:SetSize(166,52); nav:SetPoint("TOP",0,-178-(index-1)*62)
    Text(nav, string.format("0%d", index), 12, theme.accent):SetPoint("LEFT",12,0)
    Text(nav, def.title, 10, theme.text):SetPoint("TOPLEFT",44,-10)
    Text(nav, def.subtitle, 8, theme.muted):SetPoint("BOTTOMLEFT",44,10)
    navButtons[index] = nav
  end
  local className = Text(frame.sidebar, tostring(RUI:GetDetectedClass()), 9, theme.accent2); className:SetPoint("BOTTOM",0,34); className:SetWidth(164); className:SetJustifyH("CENTER")

  pages[1], pages[2], pages[3] = CreateWelcomePage(), CreateInstallPage(), CreateCompletePage()
  frame.back = Button(frame.footer,"BACK",96,28,function() Installer:ShowPage(currentPage-1) end); frame.back:SetPoint("LEFT",16,0)
  frame.close = Button(frame.footer,"CLOSE",96,28,function() frame:Hide() end); frame.close:SetPoint("LEFT",120,0)
  frame.next = Button(frame.footer,"CONTINUE",112,28,function() Installer:ShowPage(currentPage+1) end); frame.next:SetPoint("RIGHT",-16,0)
  frame.progress = Text(frame.footer,"",9,theme.muted); frame.progress:SetPoint("CENTER")
  return frame
end

function RUI:HideInstaller() if frame then frame:Hide() end end
function RUI:ShowInstaller(force)
  if type(self.IsSupportedCharacter) == "function" and not self:IsSupportedCharacter() then self:HideInstaller(); self:Print(self:GetUnsupportedMessage()); return false end
  BuildInstaller(); frame:Show(); Installer:ShowPage(1); return true
end
function RUI:RefreshInstallerTheme()
  if frame then frame:Hide(); frame=nil; pages={}; navButtons={}; currentPage=1 end
end
RUI._installerLoaded = true

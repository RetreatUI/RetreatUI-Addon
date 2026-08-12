local RUI = RetreatUI
if not RUI then return end

-- beta.20 installer contract:
-- NaowhUI TBC installer geometry and flow, adapted only for CoA dependencies.
-- No DBM/BigWigs step, no class macro step, no modular/fancy component picker.

local frame
local pages = {}
local currentPage = 1

local BLANK = "Interface\\Buttons\\WHITE8X8"
local ACCENT_R, ACCENT_G, ACCENT_B = 12/255, 210/255, 157/255
local BG_R, BG_G, BG_B = 0.06, 0.08, 0.10
local FRAME_BORDER_ALPHA = 0.15
local WIDGET_BORDER_ALPHA = 0.25
local TEXT_DIM_ALPHA = 0.65
local STEP_WIDTH = 200
local STEP_BUTTON_WIDTH = 180
local BUTTON_HEIGHT = 20

local STEP_TITLES = {
  "Welcome",
  "ElvUI",
  "Details",
  "TurboPlates",
  "General WeakAuras",
  "Class WeakAura",
  "Installation Complete",
}

local function ApplyFont(fontString, size)
  if RUI.ApplyFont then
    RUI:ApplyFont(fontString, size or 14, "")
  else
    fontString:SetFont(STANDARD_TEXT_FONT, size or 14, "")
  end
end

local function ColorTexture(texture, r, g, b, a)
  texture:SetTexture(BLANK)
  texture:SetVertexColor(r, g, b, a or 1)
end

local function CreateBorder(parent, thickness, r, g, b, a)
  local edges = {}
  for i = 1, 4 do
    local edge = parent:CreateTexture(nil, "BORDER")
    ColorTexture(edge, r, g, b, a)
    edges[i] = edge
  end

  local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(thickness)
  bottom:SetPoint("BOTTOMLEFT")
  bottom:SetPoint("BOTTOMRIGHT")
  bottom:SetHeight(thickness)
  left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
  left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
  left:SetWidth(thickness)
  right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
  right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
  right:SetWidth(thickness)

  return {
    SetColor = function(_, cr, cg, cb, ca)
      for _, edge in ipairs(edges) do edge:SetVertexColor(cr, cg, cb, ca or 1) end
    end,
  }
end

local function SetButtonState(button)
  if button.disabled then
    button.border:SetColor(1, 1, 1, FRAME_BORDER_ALPHA)
    button.text:SetTextColor(1, 1, 1, 0.25)
  else
    button.border:SetColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
    button.text:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
  end
end

local function CreateButton(name, parent, width, height)
  local button = CreateFrame("Button", name, parent)
  button:SetSize(width, height)
  button:RegisterForClicks("LeftButtonUp")
  button.bg = button:CreateTexture(nil, "BACKGROUND")
  button.bg:SetAllPoints()
  ColorTexture(button.bg, BG_R, BG_G, BG_B, 0.92)
  button.border = CreateBorder(button, 1, ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
  button.text = button:CreateFontString(nil, "OVERLAY")
  button.text:SetPoint("CENTER")
  ApplyFont(button.text, 15)
  button.text:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
  button:SetScript("OnEnter", function(self)
    if self.disabled then return end
    self.border:SetColor(ACCENT_R, ACCENT_G, ACCENT_B, 1)
    self.bg:SetVertexColor(BG_R + 0.03, BG_G + 0.03, BG_B + 0.03, 0.98)
  end)
  button:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(BG_R, BG_G, BG_B, 0.92)
    SetButtonState(self)
  end)
  function button:SetLabel(value) self.text:SetText(value or "") end
  function button:SetEnabledState(enabled)
    self.disabled = not enabled
    self:EnableMouse(enabled)
    SetButtonState(self)
  end
  return button
end

local function CreateDescription(anchor, offset)
  local desc = frame:CreateFontString(nil, "OVERLAY")
  ApplyFont(desc, 14)
  desc:SetTextColor(1, 1, 1, TEXT_DIM_ALPHA)
  if anchor then desc:SetPoint("TOP", anchor, "BOTTOM", 0, -20) else desc:SetPoint("TOPLEFT", 20, offset) end
  desc:SetWidth(frame:GetWidth() - 40)
  desc:SetJustifyH("CENTER")
  desc:SetWordWrap(true)
  return desc
end

local function AddOnReady(...)
  for index = 1, select("#", ...) do
    local name = select(index, ...)
    if name then
      if RUI.IsAddOnAvailable and RUI:IsAddOnAvailable(name) then return true end
      if GetAddOnInfo and GetAddOnInfo(name) then return true end
    end
  end
  return false
end

local function CurrentClass()
  local className = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or "Unknown CoA Class"
  if RUI.NormalizeClassName then className = RUI:NormalizeClassName(className) or className end
  return className
end

local function RunModule(key)
  if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before applying this step." end
  if type(RUI.InstallModule) ~= "function" then return false, "RetreatUI installer modules are unavailable." end
  if RUI.SetInstallerModuleEnabled then RUI:SetInstallerModuleEnabled(key, true) end
  local record = RUI:InstallModule(key)
  if type(record) ~= "table" then return false, "The installer did not return a result." end
  if record.state == "success" then return true, record.message or "Installed successfully." end
  return false, record.message or "Installation failed."
end

local function RunGeneralWeakAuras()
  if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before importing WeakAuras." end
  if type(RUI.InstallNaowhGeneralWeakAuras) ~= "function" then return false, "The beta.20 General WeakAura payload is not loaded." end
  return RUI:InstallNaowhGeneralWeakAuras()
end

local function RunClassWeakAuras()
  if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before importing WeakAuras." end
  if type(RUI.InstallNaowhClassWeakAuras) ~= "function" then return false, "The beta.20 CoA class WeakAura payload is not loaded." end
  return RUI:InstallNaowhClassWeakAuras(CurrentClass())
end

local function SetResult(success, message)
  frame.result:SetText(message or (success and "Installation complete." or "Installation failed."))
  if success then frame.result:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B, 1) else frame.result:SetTextColor(1, 0.30, 0.24, 1) end
end

local function SetupReset()
  frame.next:SetEnabledState(currentPage < #pages)
  frame.prev:SetEnabledState(currentPage > 1)
  frame.option1:Hide()
  frame.option1:SetScript("OnClick", nil)
  frame.option1:SetLabel("")
  frame.option1:ClearAllPoints()
  frame.option1:SetPoint("BOTTOM", 0, 45)
  frame.option1:SetWidth(160)
  frame.option2:Hide()
  frame.option2:SetScript("OnClick", nil)
  frame.option2:SetLabel("")
  frame.option2:ClearAllPoints()
  frame.option2:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 45)
  frame.subtitle:SetText("")
  frame.desc1:SetText("")
  frame.desc2:SetText("")
  frame.desc3:SetText("")
  frame.desc4:SetText("")
  frame.result:SetText("")
  frame.logo:Hide()
end

local function RefreshSteps()
  for index, line in ipairs(frame.side.lines) do
    line.text:SetText(STEP_TITLES[index] or "")
    if index == currentPage then
      line.indicator:Show()
      line.text:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B, 1)
    else
      line.indicator:Hide()
      line.text:SetTextColor(1, 1, 1, 1)
    end
  end
end

local function SetPage(index)
  currentPage = math.max(1, math.min(#pages, tonumber(index) or 1))
  SetupReset()
  frame.status:SetMinMaxValues(0, #pages)
  frame.status:SetValue(currentPage)
  frame.status.text:SetText(string.format("%d / %d", currentPage, #pages))
  RefreshSteps()
  pages[currentPage]()
end

local function BindAction(button, label, callback)
  button:Show()
  button:SetLabel(label)
  button:SetEnabledState(true)
  button:SetScript("OnClick", function()
    local ok, success, message = pcall(callback)
    if not ok then SetResult(false, tostring(success)); return end
    SetResult(success == true, message)
  end)
end

pages[1] = function()
  frame.subtitle:SetText("Welcome to RetreatUI")
  frame.desc1:SetText("To start the installation process, click on 'Continue'")
  frame.desc2:SetText("NaowhUI TBC layout converted for Project Ascension: Conquest of Azeroth.")
  frame.logo:Show()
end

pages[2] = function()
  frame.subtitle:SetText("ElvUI")
  if not AddOnReady("ElvUI") then frame.desc1:SetText("Enable ElvUI to unlock this step"); return end
  frame.desc2:SetText("Click on the button below to setup ElvUI")
  BindAction(frame.option1, "Setup ElvUI", function() return RunModule("unitframes") end)
end

pages[3] = function()
  frame.subtitle:SetText("Details")
  if not AddOnReady("Details") then frame.desc1:SetText("Enable Details to unlock this step"); return end
  frame.desc2:SetText("Click on the button below to setup Details")
  BindAction(frame.option1, "Setup Details", function() return RunModule("details") end)
end

pages[4] = function()
  frame.subtitle:SetText("TurboPlates")
  if not AddOnReady("TurboPlates") then frame.desc1:SetText("Enable TurboPlates to unlock this step"); return end
  frame.desc2:SetText("Click on the button below to setup TurboPlates")
  BindAction(frame.option1, "Setup TurboPlates", function() return RunModule("nameplates") end)
end

pages[5] = function()
  frame.subtitle:SetText("General WeakAuras")
  if not AddOnReady("WeakAuras") then frame.desc1:SetText("Enable WeakAuras to unlock this step"); return end
  frame.desc2:SetText("Click on the button below to import the General WeakAuras")
  BindAction(frame.option1, "Core", RunGeneralWeakAuras)
end

pages[6] = function()
  local className = CurrentClass()
  frame.subtitle:SetText("Class WeakAura")
  if not AddOnReady("WeakAuras") then frame.desc1:SetText("Enable WeakAuras to unlock this step"); return end
  frame.desc2:SetText("Click on the button below to import your Class WeakAura")
  frame.desc3:SetText("Your class: " .. tostring(className))
  BindAction(frame.option1, "Import Class WA", RunClassWeakAuras)
end

pages[7] = function()
  frame.subtitle:SetText("Installation Complete")
  frame.desc1:SetText("You have completed the installation process")
  frame.desc2:SetText("Please click on 'Reload' to save your settings and reload your UI")
  BindAction(frame.option1, "Reload", function()
    local db = RUI:EnsureDB()
    db.installer = db.installer or {}
    db.installer.initialCompleted = true
    db.installer.completedVersion = RUI.version
    ReloadUI()
    return true, "Reloading UI"
  end)
end

local function BuildInstaller()
  if frame then return frame end
  frame = CreateFrame("Frame", "RetreatUICleanInstaller", UIParent)
  frame:SetSize(550, 400)
  frame:SetPoint("CENTER", UIParent, "CENTER", -(STEP_WIDTH * 0.5), 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame.bg = frame:CreateTexture(nil, "BACKGROUND")
  frame.bg:SetAllPoints()
  ColorTexture(frame.bg, BG_R, BG_G, BG_B, 1)
  frame.border = CreateBorder(frame, 2, 1, 1, 1, FRAME_BORDER_ALPHA)

  frame.move = CreateFrame("Frame", nil, frame)
  frame.move:SetSize(450, 50)
  frame.move:SetPoint("TOP", frame, "TOP")
  frame.move:EnableMouse(true)
  frame.move:RegisterForDrag("LeftButton")
  frame.move:SetScript("OnDragStart", function() if not InCombatLockdown or not InCombatLockdown() then frame:StartMoving() end end)
  frame.move:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

  frame.title = frame:CreateFontString(nil, "OVERLAY")
  ApplyFont(frame.title, 20)
  frame.title:SetTextColor(1, 1, 1, 1)
  frame.title:SetPoint("TOP", 0, -12)
  frame.title:SetText("RetreatUI Installation")
  frame.subtitle = frame:CreateFontString(nil, "OVERLAY")
  ApplyFont(frame.subtitle, 16)
  frame.subtitle:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
  frame.subtitle:SetPoint("TOP", 0, -42)
  frame.desc1 = CreateDescription(nil, -75)
  frame.desc2 = CreateDescription(frame.desc1)
  frame.desc3 = CreateDescription(frame.desc2)
  frame.desc4 = CreateDescription(frame.desc3)

  frame.logo = frame:CreateTexture(nil, "ARTWORK")
  frame.logo:SetTexture("Interface\\AddOns\\RetreatUI\\Media\\RetreatUI_Logo.tga")
  frame.logo:SetSize(256, 128)
  frame.logo:SetPoint("BOTTOM", 0, 70)

  frame.option1 = CreateButton("RetreatUIInstallOption1Button", frame, 160, 30)
  frame.option1:SetPoint("BOTTOM", 0, 45)
  frame.option1:Hide()
  frame.option2 = CreateButton("RetreatUIInstallOption2Button", frame, 110, 30)
  frame.option2:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 45)
  frame.option2:Hide()

  frame.prev = CreateButton("RetreatUIInstallPrevButton", frame, 110, 25)
  frame.prev:SetPoint("BOTTOMLEFT", 8, 8)
  frame.prev:SetLabel(PREVIOUS or "Previous")
  frame.prev:SetScript("OnClick", function() SetPage(currentPage - 1) end)
  frame.next = CreateButton("RetreatUIInstallNextButton", frame, 110, 25)
  frame.next:SetPoint("BOTTOMRIGHT", -8, 8)
  frame.next:SetLabel(CONTINUE or "Continue")
  frame.next:SetScript("OnClick", function() SetPage(currentPage + 1) end)

  local statusHolder = CreateFrame("Frame", nil, frame)
  statusHolder:SetPoint("TOPLEFT", frame.prev, "TOPRIGHT", 6, 0)
  statusHolder:SetPoint("BOTTOMRIGHT", frame.next, "BOTTOMLEFT", -6, 0)
  statusHolder.bg = statusHolder:CreateTexture(nil, "BACKGROUND")
  statusHolder.bg:SetAllPoints()
  ColorTexture(statusHolder.bg, 0.075, 0.113, 0.141, 0.9)
  statusHolder.border = CreateBorder(statusHolder, 1, 1, 1, 1, WIDGET_BORDER_ALPHA)
  frame.status = CreateFrame("StatusBar", nil, statusHolder)
  frame.status:SetPoint("TOPLEFT", 1, -1)
  frame.status:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.status:SetStatusBarTexture(BLANK)
  frame.status:SetStatusBarColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
  frame.status.text = frame.status:CreateFontString(nil, "OVERLAY")
  ApplyFont(frame.status.text, 13)
  frame.status.text:SetTextColor(1, 1, 1, 0.9)
  frame.status.text:SetPoint("CENTER")

  frame.result = frame:CreateFontString(nil, "OVERLAY")
  ApplyFont(frame.result, 11)
  frame.result:SetPoint("BOTTOM", frame.option1, "TOP", 0, 7)
  frame.result:SetWidth(490)
  frame.result:SetJustifyH("CENTER")
  frame.result:SetTextColor(1, 1, 1, TEXT_DIM_ALPHA)
  frame.close = CreateButton("RetreatUIInstallCloseButton", frame, 25, 25)
  frame.close:SetPoint("TOPRIGHT", -13, -12)
  frame.close:SetLabel("X")
  frame.close:SetScript("OnClick", function() frame:Hide() end)

  frame.side = CreateFrame("Frame", "RetreatUIInstallTitleFrame", frame)
  frame.side:SetPoint("TOPLEFT", frame, "TOPRIGHT", 3, 0)
  frame.side:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 3, 0)
  frame.side:SetWidth(STEP_WIDTH)
  frame.side.bg = frame.side:CreateTexture(nil, "BACKGROUND")
  frame.side.bg:SetAllPoints()
  ColorTexture(frame.side.bg, BG_R, BG_G, BG_B, 1)
  frame.side.border = CreateBorder(frame.side, 2, 1, 1, 1, FRAME_BORDER_ALPHA)
  frame.side.title = frame.side:CreateFontString(nil, "OVERLAY")
  frame.side.title:SetPoint("TOP", frame.side, "TOP", 0, -8)
  ApplyFont(frame.side.title, 18)
  frame.side.title:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
  frame.side.title:SetText("Steps")
  frame.side.lines = {}
  for index = 1, #STEP_TITLES do
    local line = CreateFrame("Button", nil, frame.side)
    if index == 1 then line:SetPoint("TOP", frame.side.title, "BOTTOM", 0, -8) else line:SetPoint("TOP", frame.side.lines[index - 1], "BOTTOM", 0, 0) end
    line:SetSize(STEP_BUTTON_WIDTH, BUTTON_HEIGHT)
    line:SetID(index)
    line.indicator = line:CreateTexture(nil, "ARTWORK")
    ColorTexture(line.indicator, ACCENT_R, ACCENT_G, ACCENT_B, 1)
    line.indicator:SetWidth(3)
    line.indicator:SetPoint("TOPLEFT", line, "TOPLEFT", -1, 0)
    line.indicator:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", -1, 0)
    line.text = line:CreateFontString(nil, "OVERLAY")
    line.text:SetPoint("TOPLEFT", 4, -2)
    line.text:SetPoint("BOTTOMRIGHT", -4, 2)
    ApplyFont(line.text, 13)
    line.text:SetJustifyH("RIGHT")
    line:SetScript("OnClick", function(self) SetPage(self:GetID()) end)
    frame.side.lines[index] = line
  end
  frame:Hide()
  SetPage(1)
  return frame
end

function RUI:HideInstaller() if frame then frame:Hide() end end
function RUI:ShowInstaller()
  BuildInstaller()
  SetPage(1)
  frame:Show()
  return true
end
function RUI:RefreshInstallerTheme() if frame then frame:Hide(); frame = nil end end

RUI._cleanStepInstallerLoaded = true
RUI._cleanStepInstallerRevision = 20

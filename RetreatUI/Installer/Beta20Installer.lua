local RUI = RetreatUI
if not RUI then return end

-- Compact beta.20 CoA installer.
-- Flow: Welcome -> ElvUI -> Details -> TurboPlates -> General WA -> Class WA -> Complete.
local FRAME_W, FRAME_H = 550, 400
local STEPS_W, STEP_BUTTON_W, STEP_H = 200, 180, 20
local BG = {0.06, 0.08, 0.10, 1}
local ACCENT = {12/255, 210/255, 157/255, 1}
local WHITE = {1, 1, 1, 1}
local DIM = {1, 1, 1, 0.65}
local TEX = "Interface\\Buttons\\WHITE8X8"
local frame, page = nil, 1

local STEPS = {
  "Welcome",
  "ElvUI",
  "Details",
  "TurboPlates",
  "General WeakAuras",
  "Class WeakAura",
  "Installation Complete",
}

local function Font(fs, size)
  if RUI.ApplyFont then RUI:ApplyFont(fs, size or 14, "")
  else fs:SetFont(STANDARD_TEXT_FONT, size or 14, "") end
end

local function Solid(parent, layer, r, g, b, a)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetTexture(TEX)
  t:SetVertexColor(r, g, b, a or 1)
  return t
end

local function Border(parent, alpha)
  local top = Solid(parent, "BORDER", 1, 1, 1, alpha or .15)
  top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(2)
  local bottom = Solid(parent, "BORDER", 1, 1, 1, alpha or .15)
  bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(2)
  local left = Solid(parent, "BORDER", 1, 1, 1, alpha or .15)
  left:SetPoint("TOPLEFT", top, "BOTTOMLEFT"); left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT"); left:SetWidth(2)
  local right = Solid(parent, "BORDER", 1, 1, 1, alpha or .15)
  right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT"); right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT"); right:SetWidth(2)
  return {top, bottom, left, right}
end

local function SetBorderColor(edges, color, alpha)
  for _, edge in ipairs(edges or {}) do
    edge:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
  end
end

local function Button(parent, width, height, label)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, height)
  b.bg = Solid(b, "BACKGROUND", BG[1], BG[2], BG[3], .92)
  b.bg:SetAllPoints()
  b.border = Border(b, .25)
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetPoint("CENTER")
  Font(b.text, 14)
  b.text:SetText(label or "")

  function b:SetLabel(value) self.text:SetText(value or "") end
  function b:SetEnabledState(enabled)
    self.disabled = not enabled
    self:EnableMouse(enabled)
    self:SetAlpha(enabled and 1 or .35)
    SetBorderColor(self.border, enabled and ACCENT or WHITE, enabled and .9 or .15)
    self.text:SetTextColor(enabled and ACCENT[1] or 1, enabled and ACCENT[2] or 1, enabled and ACCENT[3] or 1, enabled and .95 or .35)
  end

  b:SetScript("OnEnter", function(self) if not self.disabled then SetBorderColor(self.border, ACCENT, 1) end end)
  b:SetScript("OnLeave", function(self) if not self.disabled then SetBorderColor(self.border, ACCENT, .9) end end)
  b:SetEnabledState(true)
  return b
end

local function AddOnReady(name)
  if RUI.IsAddOnAvailable and RUI:IsAddOnAvailable(name) then return true end
  return GetAddOnInfo and GetAddOnInfo(name) ~= nil
end

local function CurrentClass()
  local className = RUI.GetDetectedClass and RUI:GetDetectedClass() or "Unknown CoA Class"
  return RUI.NormalizeClassName and (RUI:NormalizeClassName(className) or className) or className
end

local function InstallModule(key)
  if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before applying this step." end
  if RUI.SetInstallerModuleEnabled then RUI:SetInstallerModuleEnabled(key, true) end
  if not RUI.InstallModule then return false, "Installer module is unavailable." end
  local result = RUI:InstallModule(key)
  if type(result) ~= "table" then return false, "No installer result was returned." end
  if result.state == "success" then return true, result.message or "Installed successfully." end
  return false, result.message or "Installation failed."
end

local function SetResult(ok, message)
  frame.result:SetText(message or "")
  if ok == true then frame.result:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
  elseif ok == false then frame.result:SetTextColor(1, .30, .24, 1)
  else frame.result:SetTextColor(DIM[1], DIM[2], DIM[3], DIM[4]) end
end

local function Action(button, label, callback)
  button:Show()
  button:SetLabel(label)
  button:SetEnabledState(true)
  button:SetScript("OnClick", function()
    local called, ok, message = pcall(callback)
    if not called then SetResult(false, tostring(ok)); return end
    SetResult(ok == true, message)
  end)
end

local function ResetPage()
  frame.logo:Hide()
  frame.option1:Hide(); frame.option2:Hide()
  frame.option1:SetScript("OnClick", nil); frame.option2:SetScript("OnClick", nil)
  frame.option1:ClearAllPoints(); frame.option2:ClearAllPoints()
  frame.option1:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 45)
  frame.option2:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 45)
  frame.option1:SetWidth(110); frame.option2:SetWidth(110)
  frame.subtitle:SetText("")
  frame.desc1:SetText(""); frame.desc2:SetText(""); frame.desc3:SetText("")
  SetResult(nil, "")
end

local function RefreshSteps()
  for index, row in ipairs(frame.steps.rows) do
    row.text:SetText(STEPS[index])
    if index == page then
      row.marker:Show(); row.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    else
      row.marker:Hide(); row.text:SetTextColor(1, 1, 1, 1)
    end
  end
  frame.progress:SetMinMaxValues(0, #STEPS)
  frame.progress:SetValue(page)
  frame.progress.text:SetText(string.format("%d / %d", page, #STEPS))
  frame.previous:SetEnabledState(page > 1)
  frame.continue:SetEnabledState(page < #STEPS)
end

local render = {}

render[1] = function()
  frame.subtitle:SetText("Welcome to RetreatUI")
  frame.desc1:SetText("To start the installation process, click on 'Continue'")
  frame.desc2:SetText("Project Ascension: Conquest of Azeroth profile setup")
  frame.logo:Show()
end

render[2] = function()
  frame.subtitle:SetText("ElvUI")
  if not AddOnReady("ElvUI") then frame.desc1:SetText("Enable ElvUI to unlock this step"); return end
  frame.desc1:SetText("Select the layout resolution you use in CoA")
  frame.desc2:SetText("Click one of the buttons below to setup ElvUI")
  Action(frame.option1, "1440p", function() return RUI:InstallElvUIProfile("1440p") end)
  Action(frame.option2, "1080p", function() return RUI:InstallElvUIProfile("1080p") end)
end

render[3] = function()
  frame.subtitle:SetText("Details")
  if not AddOnReady("Details") then frame.desc1:SetText("Enable Details to unlock this step"); return end
  frame.desc2:SetText("Click on the button below to setup Details")
  frame.option1:ClearAllPoints(); frame.option1:SetPoint("BOTTOM", frame, "BOTTOM", 0, 45); frame.option1:SetWidth(160)
  Action(frame.option1, "Setup Details", function() return InstallModule("details") end)
end

render[4] = function()
  frame.subtitle:SetText("TurboPlates")
  if not AddOnReady("TurboPlates") then frame.desc1:SetText("Enable TurboPlates to unlock this step"); return end
  frame.desc1:SetText("Select the TurboPlates layout resolution")
  frame.desc2:SetText("RetreatUI keeps the CoA NPC spell and cooldown data")
  Action(frame.option1, "1440p", function()
    if RUI.InstallTurboPlatesProfile then return RUI:InstallTurboPlatesProfile("1440p") end
    return InstallModule("nameplates")
  end)
  Action(frame.option2, "1080p", function()
    if RUI.InstallTurboPlatesProfile then return RUI:InstallTurboPlatesProfile("1080p") end
    return InstallModule("nameplates")
  end)
end

render[5] = function()
  frame.subtitle:SetText("General WeakAuras")
  if not AddOnReady("WeakAuras") then frame.desc1:SetText("Enable WeakAuras to unlock this step"); return end
  frame.desc2:SetText("Click on the button below to import the General WeakAuras")
  frame.option1:ClearAllPoints(); frame.option1:SetPoint("BOTTOM", frame, "BOTTOM", 0, 45); frame.option1:SetWidth(160)
  Action(frame.option1, "Core", function()
    if not RUI.InstallGeneralWeakAuras then return false, "General WeakAura package is unavailable." end
    return RUI:InstallGeneralWeakAuras()
  end)
end

render[6] = function()
  local className = CurrentClass()
  frame.subtitle:SetText("Class WeakAura")
  if not AddOnReady("WeakAuras") then frame.desc1:SetText("Enable WeakAuras to unlock this step"); return end
  frame.desc2:SetText("Click on the button below to import your Class WeakAura")
  frame.desc3:SetText("Your class: " .. tostring(className))
  frame.option1:ClearAllPoints(); frame.option1:SetPoint("BOTTOM", frame, "BOTTOM", 0, 45); frame.option1:SetWidth(180)
  Action(frame.option1, "Import Class WA", function()
    if not RUI.InstallClassWeakAuras then return false, "CoA class WeakAura package is unavailable." end
    return RUI:InstallClassWeakAuras(className)
  end)
end

render[7] = function()
  frame.subtitle:SetText("Installation Complete")
  frame.desc1:SetText("You have completed the installation process")
  frame.desc2:SetText("Click 'Reload' to save the settings and reload your UI")
  frame.option1:ClearAllPoints(); frame.option1:SetPoint("BOTTOM", frame, "BOTTOM", 0, 45); frame.option1:SetWidth(140)
  Action(frame.option1, "Reload", function()
    local db = RUI:EnsureDB(); db.installer = db.installer or {}
    db.installer.initialCompleted = true; db.installer.completedVersion = RUI.version
    ReloadUI(); return true, "Reloading UI"
  end)
end

local function ShowPage(index)
  page = math.max(1, math.min(#STEPS, tonumber(index) or 1))
  ResetPage(); RefreshSteps(); render[page]()
end

local function Build()
  if frame then return frame end
  frame = CreateFrame("Frame", "RetreatUICleanInstaller", UIParent)
  frame:SetSize(FRAME_W, FRAME_H)
  frame:SetPoint("CENTER", UIParent, "CENTER", -(STEPS_W * .5), 0)
  frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true); frame:SetMovable(true); frame:EnableMouse(true)
  frame.bg = Solid(frame, "BACKGROUND", BG[1], BG[2], BG[3], 1); frame.bg:SetAllPoints(); Border(frame, .15)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) if not InCombatLockdown or not InCombatLockdown() then self:StartMoving() end end)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

  frame.title = frame:CreateFontString(nil, "OVERLAY"); Font(frame.title, 20); frame.title:SetPoint("TOP", 0, -12); frame.title:SetText("RetreatUI Installation")
  frame.subtitle = frame:CreateFontString(nil, "OVERLAY"); Font(frame.subtitle, 16); frame.subtitle:SetPoint("TOP", 0, -42); frame.subtitle:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], .9)

  local function Description(previous, y)
    local fs = frame:CreateFontString(nil, "OVERLAY")
    Font(fs, 14); fs:SetWidth(FRAME_W - 40); fs:SetJustifyH("CENTER"); fs:SetTextColor(DIM[1], DIM[2], DIM[3], DIM[4])
    if previous then fs:SetPoint("TOP", previous, "BOTTOM", 0, -18) else fs:SetPoint("TOP", frame, "TOP", 0, y) end
    return fs
  end
  frame.desc1 = Description(nil, -78); frame.desc2 = Description(frame.desc1); frame.desc3 = Description(frame.desc2)
  frame.logo = frame:CreateTexture(nil, "ARTWORK"); frame.logo:SetTexture("Interface\\AddOns\\RetreatUI\\Media\\RetreatUI_Logo.tga"); frame.logo:SetSize(256,128); frame.logo:SetPoint("BOTTOM", 0, 70)

  frame.option1 = Button(frame, 110, 30, ""); frame.option2 = Button(frame, 110, 30, "")
  frame.result = frame:CreateFontString(nil, "OVERLAY"); Font(frame.result, 11); frame.result:SetWidth(500); frame.result:SetPoint("BOTTOM", 0, 82); frame.result:SetJustifyH("CENTER")

  frame.previous = Button(frame, 110, 25, PREVIOUS or "Previous"); frame.previous:SetPoint("BOTTOMLEFT", 8, 8); frame.previous:SetScript("OnClick", function() ShowPage(page - 1) end)
  frame.continue = Button(frame, 110, 25, CONTINUE or "Continue"); frame.continue:SetPoint("BOTTOMRIGHT", -8, 8); frame.continue:SetScript("OnClick", function() ShowPage(page + 1) end)

  local progressHolder = CreateFrame("Frame", nil, frame)
  progressHolder:SetPoint("TOPLEFT", frame.previous, "TOPRIGHT", 6, 0); progressHolder:SetPoint("BOTTOMRIGHT", frame.continue, "BOTTOMLEFT", -6, 0)
  local progressBg = Solid(progressHolder, "BACKGROUND", .075, .113, .141, .9); progressBg:SetAllPoints(); Border(progressHolder, .25)
  frame.progress = CreateFrame("StatusBar", nil, progressHolder); frame.progress:SetPoint("TOPLEFT", 1, -1); frame.progress:SetPoint("BOTTOMRIGHT", -1, 1)
  frame.progress:SetStatusBarTexture(TEX); frame.progress:SetStatusBarColor(ACCENT[1], ACCENT[2], ACCENT[3], .9)
  frame.progress.text = frame.progress:CreateFontString(nil, "OVERLAY"); Font(frame.progress.text, 13); frame.progress.text:SetPoint("CENTER")

  frame.close = Button(frame, 25, 25, "X"); frame.close:SetPoint("TOPRIGHT", -13, -12); frame.close:SetScript("OnClick", function() frame:Hide() end)

  frame.steps = CreateFrame("Frame", nil, frame); frame.steps:SetWidth(STEPS_W); frame.steps:SetPoint("TOPLEFT", frame, "TOPRIGHT", 3, 0); frame.steps:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 3, 0)
  local sideBg = Solid(frame.steps, "BACKGROUND", BG[1], BG[2], BG[3], 1); sideBg:SetAllPoints(); Border(frame.steps, .15)
  frame.steps.title = frame.steps:CreateFontString(nil, "OVERLAY"); Font(frame.steps.title, 18); frame.steps.title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], .9); frame.steps.title:SetPoint("TOP", 0, -8); frame.steps.title:SetText("Steps")
  frame.steps.rows = {}
  for index = 1, #STEPS do
    local row = CreateFrame("Button", nil, frame.steps); row:SetSize(STEP_BUTTON_W, STEP_H); row:SetID(index)
    if index == 1 then row:SetPoint("TOP", frame.steps.title, "BOTTOM", 0, -8) else row:SetPoint("TOP", frame.steps.rows[index-1], "BOTTOM", 0, 0) end
    row.marker = Solid(row, "ARTWORK", ACCENT[1], ACCENT[2], ACCENT[3], 1); row.marker:SetWidth(3); row.marker:SetPoint("TOPLEFT", -1, 0); row.marker:SetPoint("BOTTOMLEFT", -1, 0)
    row.text = row:CreateFontString(nil, "OVERLAY"); Font(row.text, 13); row.text:SetPoint("TOPLEFT", 4, -2); row.text:SetPoint("BOTTOMRIGHT", -4, 2); row.text:SetJustifyH("RIGHT")
    row:SetScript("OnClick", function(self) ShowPage(self:GetID()) end)
    frame.steps.rows[index] = row
  end

  frame:Hide(); ShowPage(1); return frame
end

function RUI:HideInstaller() if frame then frame:Hide() end end
function RUI:ShowInstaller() Build(); ShowPage(1); frame:Show(); return true end
function RUI:RefreshInstallerTheme() if frame then frame:Hide(); frame = nil end end

RUI._beta20InstallerLoaded = true
RUI._beta20InstallerRevision = 21

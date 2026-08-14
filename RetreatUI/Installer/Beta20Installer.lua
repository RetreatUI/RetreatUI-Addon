local RUI = RetreatUI
if not RUI then return end

-- Compact beta.20 CoA installer.
-- Flow: Welcome -> ElvUI -> Details -> TurboPlates -> General WA -> Class WA -> Complete.
local frame
local currentPage = 1
local totalPages = 7

local function SetBackdrop(widget, bg, border)
  widget:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  widget:SetBackdropColor(unpack(bg))
  widget:SetBackdropBorderColor(unpack(border))
end

local function Font(parent, text, size)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetFont(STANDARD_TEXT_FONT, size or 12, "OUTLINE")
  fs:SetText(text or "")
  return fs
end

local function Button(parent, text, width, callback)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width or 150, 28)
  SetBackdrop(button, {0.035, 0.045, 0.055, 0.98}, {0.0, 0.75, 0.62, 1})
  button.label = Font(button, text, 11)
  button.label:SetPoint("CENTER")
  button.label:SetTextColor(0.0, 0.9, 0.75)
  button:SetScript("OnClick", callback)
  return button
end

local function CurrentClass()
  if type(RUI.GetDetectedClass) == "function" then return RUI:GetDetectedClass() end
  local localized, token = UnitClass("player")
  return localized or token or "Class"
end

local function Result(text, success)
  if not frame then return end
  frame.status:SetText(text or "")
  if success == true then
    frame.status:SetTextColor(0.30, 0.95, 0.55)
  elseif success == false then
    frame.status:SetTextColor(1.0, 0.25, 0.18)
  else
    frame.status:SetTextColor(0.72, 0.72, 0.72)
  end
end

local pages = {
  {
    title = "Welcome",
    text = "Welcome to RetreatUI for Conquest of Azeroth.\n\nThis installer applies the shared beta.20 layout one component at a time.",
  },
  {
    title = "ElvUI",
    text = "Click on the button below to setup ElvUI",
    button = "Setup ElvUI",
    action = function()
      if type(RUI.InstallBeta20ElvUIProfile) ~= "function" then return false, "ElvUI beta.20 installer is unavailable" end
      return RUI:InstallBeta20ElvUIProfile()
    end,
  },
  {
    title = "Details",
    text = "Click on the button below to setup Details",
    button = "Setup Details",
    action = function()
      if type(RUI.InstallDetailsProfile) ~= "function" then return false, "Details profile installer is unavailable" end
      return RUI:InstallDetailsProfile()
    end,
  },
  {
    title = "TurboPlates",
    text = "Click on the button below to setup TurboPlates",
    button = "Setup TurboPlates",
    action = function()
      if type(RUI.InstallBeta20TurboPlates) == "function" then return RUI:InstallBeta20TurboPlates() end
      if type(RUI.ApplyTurboPlatesProfile) == "function" then return RUI:ApplyTurboPlatesProfile() end
      return false, "TurboPlates beta.20 installer is unavailable"
    end,
  },
  {
    title = "General WeakAuras",
    text = "Click on the button below to install and verify the General WeakAuras",
    button = "Install Core WA",
    action = function()
      if type(RUI.InstallGeneralWeakAuras) ~= "function" then return false, "General WeakAuras installer is unavailable" end
      return RUI:InstallGeneralWeakAuras()
    end,
  },
  {
    title = "Class WeakAura",
    text = function() return "Click on the button below to install and verify your Class WeakAura\n\nYour class: " .. tostring(CurrentClass()) end,
    button = "Install Class WA",
    action = function()
      if type(RUI.InstallClassWeakAuras) ~= "function" then return false, "Class WeakAuras installer is unavailable" end
      return RUI:InstallClassWeakAuras(CurrentClass())
    end,
  },
  {
    title = "Complete",
    text = "Setup is complete.\n\nReload the UI once to refresh every profile and runtime component.",
    button = "Reload UI",
    action = function()
      local db = RUI:EnsureDB()
      db.installerCompleted = true
      ReloadUI()
      return true, "Reloading"
    end,
  },
}

local function Resolve(value)
  return type(value) == "function" and value() or tostring(value or "")
end

local function Refresh()
  if not frame then return end
  currentPage = math.max(1, math.min(totalPages, currentPage))
  local page = pages[currentPage]
  frame.subtitle:SetText(Resolve(page.title))
  frame.description:SetText(Resolve(page.text))
  frame.progress:SetText(string.format("%d / %d", currentPage, totalPages))
  frame.progressFill:SetWidth(math.max(1, 300 * currentPage / totalPages))

  frame.previous:SetShown(currentPage > 1)
  frame.continue:SetShown(currentPage < totalPages)

  if page.button then
    frame.action:Show()
    frame.action.label:SetText(page.button)
  else
    frame.action:Hide()
  end
  Result("", nil)
end

local function RunAction()
  local page = pages[currentPage]
  if not page or type(page.action) ~= "function" then return end
  if InCombatLockdown and InCombatLockdown() then
    Result("Leave combat before applying this component.", false)
    return
  end

  local ok, success, message = pcall(page.action)
  if not ok then
    Result(tostring(success), false)
  elseif success then
    Result(message or "Installed and verified.", true)
  else
    Result(message or "Installation failed.", false)
  end
end

local function Build()
  if frame then return frame end

  frame = CreateFrame("Frame", "RetreatUIBeta20Installer", UIParent, "BackdropTemplate")
  frame:SetSize(550, 395)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  SetBackdrop(frame, {0.018, 0.025, 0.032, 0.985}, {0.12, 0.18, 0.20, 1})

  frame.title = Font(frame, "RetreatUI Installation", 18)
  frame.title:SetPoint("TOP", 0, -14)
  frame.title:SetTextColor(1, 0.82, 0)

  frame.subtitle = Font(frame, "", 14)
  frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -6)
  frame.subtitle:SetTextColor(0.0, 0.9, 0.75)

  frame.description = Font(frame, "", 12)
  frame.description:SetPoint("TOP", frame.subtitle, "BOTTOM", 0, -36)
  frame.description:SetWidth(470)
  frame.description:SetJustifyH("CENTER")
  frame.description:SetTextColor(0.72, 0.72, 0.72)

  frame.status = Font(frame, "", 10)
  frame.status:SetPoint("BOTTOM", 0, 66)
  frame.status:SetWidth(510)
  frame.status:SetJustifyH("CENTER")

  frame.action = Button(frame, "Install", 165, RunAction)
  frame.action:SetPoint("BOTTOM", 0, 34)

  frame.previous = Button(frame, "Previous", 110, function()
    currentPage = currentPage - 1
    Refresh()
  end)
  frame.previous:SetPoint("BOTTOMLEFT", 8, 8)

  frame.continue = Button(frame, "Continue", 110, function()
    currentPage = currentPage + 1
    Refresh()
  end)
  frame.continue:SetPoint("BOTTOMRIGHT", -8, 8)

  local progressBack = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  progressBack:SetSize(300, 26)
  progressBack:SetPoint("BOTTOM", 0, 7)
  SetBackdrop(progressBack, {0.035, 0.045, 0.055, 1}, {0.25, 0.30, 0.32, 1})

  frame.progressFill = progressBack:CreateTexture(nil, "ARTWORK")
  frame.progressFill:SetColorTexture(0.0, 0.75, 0.62, 1)
  frame.progressFill:SetPoint("LEFT", 1, 0)
  frame.progressFill:SetHeight(24)

  frame.progress = Font(progressBack, "", 11)
  frame.progress:SetPoint("CENTER")
  frame.progress:SetTextColor(1, 0.82, 0)

  local close = Button(frame, "X", 24, function() frame:Hide() end)
  close:SetSize(24, 24)
  close:SetPoint("TOPRIGHT", -10, -10)

  Refresh()
  return frame
end

function RUI:OpenBeta20Installer()
  local f = Build()
  f:Show()
  f:Raise()
end

SLASH_RETREATUI1 = "/rui"
SlashCmdList.RETREATUI = function(msg)
  msg = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "reset" then
    currentPage = 1
    local db = RUI:EnsureDB()
    db.installerCompleted = false
    RUI:OpenBeta20Installer()
    Refresh()
  else
    RUI:OpenBeta20Installer()
  end
end

RUI._beta20InstallerLoaded = true

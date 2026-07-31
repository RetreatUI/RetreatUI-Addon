local RUI = RetreatUI

local popup
local popupShown = false
local warningPrinted = false

local UNSUPPORTED_MESSAGE = "RetreatUI supports only the official Ascension ElvUI 7.27. The modified ElvUI 2.0 fork is not supported."

local function NormalizeAddOnName(value)
  return string.lower(tostring(value or ""))
end

local function AddOnExists(name)
  local target = NormalizeAddOnName(name)
  if target == "" then return false end

  -- Ascension's GetAddOnInfo implementation is not reliable when an unknown
  -- addon name is passed directly. Enumerate the installed addon list and
  -- require an exact internal-folder-name match instead.
  if type(GetNumAddOns) == "function" and type(GetAddOnInfo) == "function" then
    local countOK, count = pcall(GetNumAddOns)
    if countOK and type(count) == "number" then
      for index = 1, count do
        local infoOK, installedName = pcall(GetAddOnInfo, index)
        if infoOK and NormalizeAddOnName(installedName) == target then
          return true
        end
      end
      return false
    end
  end

  if IsAddOnLoaded and IsAddOnLoaded(name) then return true end
  if type(GetAddOnInfo) == "function" then
    local infoOK, installedName = pcall(GetAddOnInfo, name)
    return infoOK and NormalizeAddOnName(installedName) == target
  end
  return false
end

local function AddMarker(markers, seen, value)
  if not value or seen[value] then return end
  seen[value] = true
  markers[#markers + 1] = value
end

local function GetElvUIEngine()
  if type(ElvUI) ~= "table" then return nil end
  local ok, engine = pcall(unpack, ElvUI)
  return ok and engine or nil
end

function RUI:DetectUnsupportedElvUI()
  local markers, seen = {}, {}

  local hasPartyDamage = AddOnExists("ElvUI_PartyDamage")
  local hasDTBars2 = AddOnExists("ElvUI_DTBars2")
  local E = GetElvUIEngine()
  local hasAbsorbEngine = E and type(E.AbsorbEngine) == "table" or false
  local hasSupportSpecCache = E and type(E.SupportSpecCache) == "table" or false
  local hasAbsorbSettings = type(_G.ElvUI_AbsorbSettings) == "table"

  if hasPartyDamage then AddMarker(markers, seen, "ElvUI_PartyDamage") end
  if hasDTBars2 then AddMarker(markers, seen, "ElvUI_DTBars2") end
  if hasAbsorbEngine then AddMarker(markers, seen, "custom AbsorbEngine") end
  if hasSupportSpecCache then AddMarker(markers, seen, "custom SupportSpecCache") end
  if hasAbsorbSettings then AddMarker(markers, seen, "ElvUI_AbsorbSettings") end

  -- Never block from one generic runtime table alone. A positive detection now
  -- requires either the fork's unique PartyDamage addon folder or a combination
  -- of independent ElvUI 2.0 runtime/package markers.
  local hardMatch = hasPartyDamage
    or (hasAbsorbEngine and hasSupportSpecCache)
    or (hasDTBars2 and (hasAbsorbEngine or hasSupportSpecCache))

  self.elvUICompatibility = self.elvUICompatibility or {}
  self.elvUICompatibility.checked = true
  self.elvUICompatibility.unsupported = hardMatch
  self.elvUICompatibility.markers = markers
  self.elvUICompatibility.elvuiVersion = GetAddOnMetadata and GetAddOnMetadata("ElvUI", "Version") or nil
  return hardMatch, markers
end

function RUI:IsUnsupportedElvUIInstalled()
  return self:DetectUnsupportedElvUI()
end

function RUI:IsElvUICompatible()
  return not self:IsUnsupportedElvUIInstalled()
end

function RUI:GetElvUICompatibilityMessage()
  local unsupported, markers = self:DetectUnsupportedElvUI()
  if not unsupported then return "Official Ascension ElvUI compatibility check passed." end
  local detected = #markers > 0 and table.concat(markers, ", ") or "modified ElvUI runtime"
  return UNSUPPORTED_MESSAGE .. " Detected: " .. detected .. "."
end

local function ApplyPopupFont(fontString, size)
  if type(RUI.ApplyFont) == "function" then
    RUI:ApplyFont(fontString, size or 12, "OUTLINE")
  elseif fontString.SetFont and GameFontNormal and GameFontNormal.GetFont then
    local font = GameFontNormal:GetFont()
    fontString:SetFont(font, size or 12, "OUTLINE")
  end
end

local function PopupText(parent, value, size, accent)
  local text = parent:CreateFontString(nil, "OVERLAY")
  ApplyPopupFont(text, size)
  text:SetText(value or "")
  local theme = type(RUI.GetTheme) == "function" and RUI:GetTheme() or nil
  local color = theme and (accent and theme.accent or theme.text) or (accent and {1, 0.35, 0.12, 1} or {1, 1, 1, 1})
  text:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
  return text
end

local function BuildPopup()
  if popup then return popup end

  local theme = type(RUI.GetTheme) == "function" and RUI:GetTheme() or nil
  local frame = CreateFrame("Frame", "RetreatUIUnsupportedElvUIPopup", UIParent)
  frame:SetSize(650, 470)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

  if type(RUI.SkinFrame) == "function" and theme then
    RUI:SkinFrame(frame, theme.background, theme.accent)
  else
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })
    frame:SetBackdropColor(0.04, 0.04, 0.04, 0.98)
    frame:SetBackdropBorderColor(1, 0.25, 0.05, 1)
  end

  frame.title = PopupText(frame, "UNSUPPORTED ELVUI VERSION DETECTED", 20, true)
  frame.title:SetPoint("TOP", 0, -24)

  frame.subtitle = PopupText(frame, "RetreatUI has detected the modified ElvUI 2.0 fork.", 13, false)
  frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -12)

  frame.body = PopupText(frame, "", 12, false)
  frame.body:SetPoint("TOPLEFT", 34, -92)
  frame.body:SetPoint("TOPRIGHT", -34, -92)
  frame.body:SetHeight(310)
  frame.body:SetJustifyH("LEFT")
  frame.body:SetJustifyV("TOP")
  if frame.body.SetSpacing then frame.body:SetSpacing(6) end

  frame.close = CreateFrame("Button", nil, frame)
  frame.close:SetSize(150, 32)
  frame.close:SetPoint("BOTTOMRIGHT", -26, 22)
  frame.close:RegisterForClicks("LeftButtonUp")
  if type(RUI.SkinFrame) == "function" and theme then
    RUI:SkinFrame(frame.close, theme.panel, {0, 0, 0, 1})
  else
    frame.close:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    frame.close:SetBackdropColor(0.12, 0.12, 0.12, 1)
    frame.close:SetBackdropBorderColor(0, 0, 0, 1)
  end
  frame.close.text = PopupText(frame.close, "UNDERSTOOD", 10, false)
  frame.close.text:SetPoint("CENTER")
  frame.close:SetScript("OnClick", function() frame:Hide() end)

  frame:Hide()
  popup = frame
  return frame
end

function RUI:ShowUnsupportedElvUIPopup(force)
  local unsupported, markers = self:DetectUnsupportedElvUI()
  if not unsupported then return false end
  if popupShown and not force then return true end

  popupShown = true
  local frame = BuildPopup()
  local detected = #markers > 0 and table.concat(markers, ", ") or "modified ElvUI runtime"
  frame.body:SetText(
    "RetreatUI supports only the official Ascension ElvUI 7.27. ElvUI 2.0 replaces core libraries, unit-frame, aura, range, threat and group systems. Running both versions together can cause severe FPS drops, missing party frames and repeated Lua errors.\n\n"
    .. "RetreatUI has disabled its ElvUI installer and ElvUI-specific runtime changes for this session.\n\n"
    .. "To fix the problem:\n"
    .. "1. Close Project Ascension completely.\n"
    .. "2. Remove every ElvUI* folder from Interface\\AddOns.\n"
    .. "3. Reinstall the official ElvUI through the Ascension Launcher.\n"
    .. "4. Start the game and run /rui install.\n\n"
    .. "Detected markers: " .. detected
  )
  frame:Show()
  frame:Raise()

  if not warningPrinted then
    warningPrinted = true
    local message = self:GetElvUICompatibilityMessage()
    if type(self.Print) == "function" then self:Print(message)
    elseif type(self.BootstrapPrint) == "function" then self.BootstrapPrint(message) end
  end
  return true
end

local function CompatibilityFailure(self)
  self:ShowUnsupportedElvUIPopup(false)
  return false, self:GetElvUICompatibilityMessage()
end

local function WrapBlockedMethod(methodName)
  local original = RUI[methodName]
  if type(original) ~= "function" then return end
  RUI["_compatible_" .. methodName] = original
  RUI[methodName] = function(self, ...)
    if self:IsUnsupportedElvUIInstalled() then
      return CompatibilityFailure(self)
    end
    return original(self, ...)
  end
end

-- Never write RetreatUI settings into the unsupported fork. These wrappers are
-- intentionally limited to ElvUI-owned operations; the standalone class HUD
-- remains available so users can still reach the warning and status commands.
for _, methodName in ipairs({
  "InstallElvUIProfile",
  "ApplyElvUIHUDPolish",
  "ApplyPartyFramePosition",
  "ApplyTargetTargetFrame",
  "DisableElvUINamePlates",
  "RepairElvUIAuraProfiles",
  "RemoveRightLootTradeChat",
}) do
  WrapBlockedMethod(methodName)
end

local originalReadiness = RUI.GetInstallerReadiness
if type(originalReadiness) == "function" then
  RUI.GetInstallerReadiness = function(self, loadNow)
    local ready, missing = originalReadiness(self, loadNow)
    if not self:IsUnsupportedElvUIInstalled() then return ready, missing end
    local result = {}
    for _, value in ipairs(missing or {}) do result[#result + 1] = value end
    result[#result + 1] = "Official Ascension ElvUI 7.27 required; ElvUI 2.0 is unsupported"
    return false, result
  end
end

local originalValidation = RUI.ValidateInstallation
if type(originalValidation) == "function" then
  RUI.ValidateInstallation = function(self)
    local valid, problems = originalValidation(self)
    if not self:IsUnsupportedElvUIInstalled() then return valid, problems end
    local result = {}
    for _, value in ipairs(problems or {}) do result[#result + 1] = value end
    result[#result + 1] = self:GetElvUICompatibilityMessage()
    return false, result
  end
end

local originalInstallAll = RUI.InstallAllModules
if type(originalInstallAll) == "function" then
  RUI.InstallAllModules = function(self, progressCallback)
    if self:IsUnsupportedElvUIInstalled() then
      self:ShowUnsupportedElvUIPopup(true)
      return false, {self:GetElvUICompatibilityMessage()}
    end
    return originalInstallAll(self, progressCallback)
  end
end

local originalShowInstaller = RUI.ShowInstaller
if type(originalShowInstaller) == "function" then
  RUI.ShowInstaller = function(self, ...)
    if self:IsUnsupportedElvUIInstalled() then
      self:ShowUnsupportedElvUIPopup(true)
      return false
    end
    return originalShowInstaller(self, ...)
  end
end

local compatibilityEvents = CreateFrame("Frame")
compatibilityEvents:RegisterEvent("PLAYER_LOGIN")
compatibilityEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
compatibilityEvents:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    RUI:After(0.20, function()
      if RUI:IsUnsupportedElvUIInstalled() then RUI:ShowUnsupportedElvUIPopup(false) end
    end)
  elseif not popupShown and RUI:IsUnsupportedElvUIInstalled() then
    RUI:ShowUnsupportedElvUIPopup(false)
  end
end)

RUI._compatibilityLoaded = true

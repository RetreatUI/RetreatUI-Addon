local RUI = RetreatUI

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.0.1",
  summary = "The class-aware framework, themed installer and first beta class modules are now part of the public release.",
  changes = {
    "Released the redesigned class-aware installer with full-page artwork for Knight of Xoroth, Venomancer and Cultist.",
    "Kept Knight of Xoroth Tank as the stable and fully supported class module.",
    "Added beta HUD support for Venomancer Fortitude Tank and Cultist Dreadnought Tank.",
    "Added shared counter, form, cooldown, charge and dynamic-centering widgets across class HUDs.",
    "Added talent-aware spell replacements, passive conversions and resource colors based on resource type.",
    "Fixed installer dependency refresh, module placement, completion layout and integrated logo presentation.",
  },
}
local updateFrame
local pendingPopup
local loginHandled = false

local function ParseVersion(value)
  value = tostring(value or "")
  local base, suffix = value:match("^([%d%.]+)(.*)$")
  base, suffix = base or value, suffix or ""
  local parts, suffixParts = {}, {}
  for number in base:gmatch("(%d+)") do parts[#parts + 1] = tonumber(number) or 0 end
  for number in suffix:gmatch("(%d+)") do suffixParts[#suffixParts + 1] = tonumber(number) or 0 end
  return parts, suffix, suffixParts
end

function RUI:CompareVersions(left, right)
  local a, aSuffix, aSuffixParts = ParseVersion(left)
  local b, bSuffix, bSuffixParts = ParseVersion(right)
  local count = math.max(#a, #b)
  for index = 1, count do
    local av, bv = a[index] or 0, b[index] or 0
    if av > bv then return 1 elseif av < bv then return -1 end
  end
  if aSuffix == "" and bSuffix ~= "" then return 1 end
  if aSuffix ~= "" and bSuffix == "" then return -1 end
  local suffixCount = math.max(#aSuffixParts, #bSuffixParts)
  for index = 1, suffixCount do
    local av, bv = aSuffixParts[index] or 0, bSuffixParts[index] or 0
    if av > bv then return 1 elseif av < bv then return -1 end
  end
  if aSuffix > bSuffix then return 1 elseif aSuffix < bSuffix then return -1 end
  return 0
end

local function PopupText(parent, value, size, accent)
  local text = parent:CreateFontString(nil, "OVERLAY")
  RUI:ApplyFont(text, size or 12, "OUTLINE")
  text:SetText(value or "")
  local theme = RUI:GetTheme()
  local color = accent and theme.accent or theme.text
  text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  return text
end

local function PopupButton(parent, label, width, callback)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width or 130, 30)
  RUI:SkinFrame(button, RUI:GetTheme().panel, {0, 0, 0, 1})
  button:RegisterForClicks("LeftButtonUp")
  button.text = PopupText(button, label, 10, false)
  button.text:SetPoint("CENTER")
  button:SetScript("OnClick", function() if callback then callback() end end)
  return button
end

local function BuildUpdateFrame()
  if updateFrame then return updateFrame end
  local theme = RUI:GetTheme()
  local popup = CreateFrame("Frame", "RetreatUIUpdatePopup", UIParent)
  popup:SetSize(580, 380)
  popup:SetPoint("CENTER")
  popup:SetFrameStrata("DIALOG")
  popup:SetClampedToScreen(true)
  popup:EnableMouse(true)
  popup:SetMovable(true)
  popup:RegisterForDrag("LeftButton")
  popup:SetScript("OnDragStart", popup.StartMoving)
  popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
  RUI:SkinFrame(popup, theme.background, theme.accent)

  popup.title = PopupText(popup, "RETREATUI UPDATED", 22, true)
  popup.title:SetPoint("TOP", 0, -24)
  popup.versionText = PopupText(popup, "", 12, false)
  popup.versionText:SetPoint("TOP", popup.title, "BOTTOM", 0, -13)
  popup.body = PopupText(popup, "", 12, false)
  popup.body:SetPoint("TOPLEFT", 34, -96)
  popup.body:SetPoint("TOPRIGHT", -34, -96)
  popup.body:SetJustifyH("LEFT")
  popup.body:SetJustifyV("TOP")
  popup.body:SetHeight(200)
  popup.body:SetSpacing(7)
  popup.close = PopupButton(popup, "CLOSE", 120, function() popup:Hide() end)
  popup.close:SetPoint("BOTTOMRIGHT", -24, 22)
  popup.installer = PopupButton(popup, "OPEN INSTALLER", 150, function()
    popup:Hide()
    if type(RUI.ShowInstaller) == "function" and RUI:IsSupportedCharacter() then RUI:ShowInstaller(true) end
  end)
  popup.installer:SetPoint("RIGHT", popup.close, "LEFT", -10, 0)
  popup:Hide()
  updateFrame = popup
  return popup
end

local function ChangelogBody(previousVersion)
  local lines = {}
  if previousVersion and previousVersion ~= "" then
    lines[#lines + 1] = "Updated from " .. tostring(previousVersion) .. " to " .. tostring(RUI.version) .. "."
    lines[#lines + 1] = ""
  end
  for _, change in ipairs(RUI.changelog.changes or {}) do lines[#lines + 1] = "- " .. tostring(change) end
  return table.concat(lines, "\n")
end

function RUI:ShowUpdatePopup(previousVersion)
  if InCombatLockdown and InCombatLockdown() then
    pendingPopup = previousVersion
    return false
  end
  local popup = BuildUpdateFrame()
  popup.versionText:SetText("Version " .. tostring(self.version))
  popup.body:SetText(ChangelogBody(previousVersion))
  popup:Show()
  local db = self:EnsureDB()
  db.version.lastPopupVersion = self.version
  db.version.lastSeenVersion = self.version
  return true
end

function RUI:ShowChangelog()
  return self:ShowUpdatePopup(nil)
end

function RUI:HandleVersionLogin()
  if loginHandled then return end
  loginHandled = true
  local db = self:EnsureDB()
  local installedBefore = db.installer.initialCompleted == true or (db.installer.completedVersion and db.installer.completedVersion ~= "")
  local previous = db.version.lastPopupVersion or db.version.lastSeenVersion or db.installer.completedVersion
  if installedBefore and previous and self:CompareVersions(self.version, previous) > 0 then
    self:ShowUpdatePopup(previous)
  elseif installedBefore and not previous then
    db.version.lastPopupVersion = self.version
    db.version.lastSeenVersion = self.version
  end
end

local versionEvents = CreateFrame("Frame")
versionEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
versionEvents:SetScript("OnEvent", function()
  if pendingPopup ~= nil then
    local previous = pendingPopup
    pendingPopup = nil
    RUI:ShowUpdatePopup(previous)
  end
end)

RUI._versionLoaded = true

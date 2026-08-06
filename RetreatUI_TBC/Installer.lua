local RUI = RetreatUITBC
if not RUI then return end

local frame

local OPTIONS = {
  { key = "elvui", label = "ElvUI Layout", addon = "ElvUI", kind = "profile" },
  { key = "plater", label = "Plater Profile", addon = "Plater", kind = "plater" },
  { key = "details", label = "Details Profile", addon = "Details", kind = "profile" },
  { key = "generalWA", label = "General WeakAuras", addon = "WeakAuras", kind = "wa", payload = "general" },
  { key = "classWA", label = "Druid WeakAuras", addon = "WeakAuras", kind = "waClass" },
}

local function SetBackdrop(widget, color, border)
  widget:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  widget:SetBackdropColor(unpack(color))
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
  button:SetSize(width or 130, 28)
  SetBackdrop(button, { 0.035, 0.045, 0.055, 0.98 }, { 0.58, 0.36, 0.08, 1 })
  button.label = Font(button, text, 11)
  button.label:SetPoint("CENTER")
  button:SetScript("OnClick", callback)
  button:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.95, 0.58, 0.12, 1) end)
  button:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.58, 0.36, 0.08, 1) end)
  return button
end

local function HasPayload(key)
  local payload = RUI.weakAuraPayloads and RUI.weakAuraPayloads[key]
  return type(payload) == "string" and payload ~= ""
end

local function GetReadiness(option)
  if not RUI:IsAddonLoaded(option.addon) then
    return false, option.addon .. " NOT LOADED"
  end
  if option.kind == "plater" then
    local payload = RUI.profilePayloads and RUI.profilePayloads.plater
    if type(payload) ~= "string" or payload == "" then return false, "PROFILE NOT EMBEDDED" end
  elseif option.kind == "wa" then
    if not HasPayload(option.payload) then return false, "PAYLOAD NOT EMBEDDED" end
  elseif option.kind == "waClass" then
    if RUI:GetPlayerClass() ~= "DRUID" then return false, "DRUID PACKAGE ONLY" end
    if not HasPayload("druidResource") or not HasPayload("druidMain") or not HasPayload("druidUtility") then
      return false, "DRUID PAYLOADS INCOMPLETE"
    end
  end
  return true, "READY"
end

local function RefreshRows()
  if not frame or not frame.rows then return end
  local db = RUI:EnsureDB()
  for _, option in ipairs(OPTIONS) do
    local row = frame.rows[option.key]
    local ready, status = GetReadiness(option)
    local enabled = db.selected[option.key]
    row.status:SetText(status)
    row.status:SetTextColor(ready and 0.25 or 0.95, ready and 0.8 or 0.3, ready and 0.35 or 0.2)
    row.toggle.label:SetText(enabled and "ON" or "OFF")
    row:SetAlpha(enabled and 1 or 0.55)
  end
end

local function AddResults(messages, results, verb)
  local allOk = true
  for key, result in pairs(results or {}) do
    local ok = result[1] == true
    allOk = allOk and ok
    messages[#messages + 1] = key .. ": " .. (ok and verb or tostring(result[2] or "failed"))
  end
  return allOk
end

local function BuildInstaller()
  if frame then return frame end
  frame = CreateFrame("Frame", "RetreatUITBCInstaller", UIParent, "BackdropTemplate")
  frame:SetSize(760, 500)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  SetBackdrop(frame, { 0.018, 0.025, 0.032, 0.98 }, { 0.55, 0.34, 0.08, 1 })

  local title = Font(frame, "RETREATUI — THE BURNING CRUSADE", 20)
  title:SetPoint("TOPLEFT", 28, -26)
  title:SetTextColor(0.95, 0.58, 0.12)

  local subtitle = Font(frame, "Only components with real embedded data are marked READY.", 11)
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -9)
  subtitle:SetTextColor(0.72, 0.76, 0.82)

  local className = UnitClass("player") or "Unknown"
  local classText = Font(frame, "Detected class: " .. className, 12)
  classText:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -23)

  frame.rows = {}
  for index, option in ipairs(OPTIONS) do
    local row = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    row:SetSize(700, 48)
    row:SetPoint("TOPLEFT", 28, -125 - ((index - 1) * 56))
    SetBackdrop(row, { 0.03, 0.04, 0.05, 0.92 }, { 0.12, 0.15, 0.18, 1 })
    row.title = Font(row, option.label, 12)
    row.title:SetPoint("LEFT", 16, 8)
    row.status = Font(row, "CHECKING", 9)
    row.status:SetPoint("LEFT", 16, -10)
    row.toggle = Button(row, "ON", 64, function(self)
      local db = RUI:EnsureDB()
      db.selected[option.key] = not db.selected[option.key]
      RefreshRows()
    end)
    row.toggle:SetPoint("RIGHT", -12, 0)
    frame.rows[option.key] = row
  end

  frame.result = Font(frame, "Ready.", 10)
  frame.result:SetPoint("BOTTOMLEFT", 28, 26)
  frame.result:SetWidth(485)
  frame.result:SetJustifyH("LEFT")

  frame.install = Button(frame, "INSTALL SELECTED", 165, function()
    if InCombatLockdown and InCombatLockdown() then
      frame.result:SetText("Leave combat before installing.")
      frame.result:SetTextColor(0.95, 0.25, 0.2)
      return
    end

    local db = RUI:EnsureDB()
    local messages, allOk = {}, true
    local profiles = RUI.modules.profiles
    local wa = RUI.modules.weakauras

    if profiles and profiles.InstallSelected then
      allOk = AddResults(messages, profiles:InstallSelected(), "installed") and allOk
    end
    if wa and wa.InstallSelected then
      allOk = AddResults(messages, wa:InstallSelected(), "imported") and allOk
    end

    if #messages == 0 then
      allOk = false
      messages[1] = "Nothing was selected or no installer modules were available."
    end

    db.installerCompleted = allOk
    db.lastInstallSuccessful = allOk
    db.lastInstallResults = messages
    frame.result:SetText(table.concat(messages, "  •  "))
    frame.result:SetTextColor(allOk and 0.35 or 0.95, allOk and 0.9 or 0.35, allOk and 0.45 or 0.2)
    RefreshRows()
  end)
  frame.install:SetPoint("BOTTOMRIGHT", -28, 18)

  frame.reload = Button(frame, "RELOAD UI", 110, function() ReloadUI() end)
  frame.reload:SetPoint("RIGHT", frame.install, "LEFT", -10, 0)
  frame.close = Button(frame, "X", 32, function() frame:Hide() end)
  frame.close:SetPoint("TOPRIGHT", -10, -10)
  return frame
end

function RUI:OpenInstaller()
  local installer = BuildInstaller()
  RefreshRows()
  installer:Show()
end

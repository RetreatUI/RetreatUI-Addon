local RUI = RetreatUITBC
if not RUI then return end

local frame

local OPTIONS = {
  { key = "elvui", label = "ElvUI Layout", addon = "ElvUI" },
  { key = "plater", label = "Plater Profile", addon = "Plater" },
  { key = "details", label = "Details Profile", addon = "Details" },
  { key = "generalWA", label = "General WeakAuras", addon = "WeakAuras" },
  { key = "classWA", label = "Class WeakAuras", addon = "WeakAuras" },
}

local function SetBackdrop(widget, color, border)
  widget:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
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

  local subtitle = Font(frame, "Install the shared layout, addon profiles and the correct class HUD package.", 11)
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -9)
  subtitle:SetTextColor(0.72, 0.76, 0.82)

  local className = UnitClass("player") or "Unknown"
  local classText = Font(frame, "Detected class: " .. className, 12)
  classText:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -23)
  classText:SetTextColor(0.85, 0.85, 0.85)

  frame.rows = {}
  for index, option in ipairs(OPTIONS) do
    local row = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    row:SetSize(700, 48)
    row:SetPoint("TOPLEFT", 28, -125 - ((index - 1) * 56))
    SetBackdrop(row, { 0.03, 0.04, 0.05, 0.92 }, { 0.12, 0.15, 0.18, 1 })

    row.title = Font(row, option.label, 12)
    row.title:SetPoint("LEFT", 16, 8)
    row.title:SetTextColor(0.92, 0.92, 0.92)

    local available = RUI:IsAddonLoaded(option.addon)
    row.status = Font(row, available and "READY" or (option.addon .. " NOT LOADED"), 9)
    row.status:SetPoint("LEFT", 16, -10)
    row.status:SetTextColor(available and 0.25 or 0.9, available and 0.8 or 0.25, available and 0.35 or 0.2)

    row.toggle = Button(row, "ON", 64, function(self)
      local db = RUI:EnsureDB()
      db.selected[option.key] = not db.selected[option.key]
      self.label:SetText(db.selected[option.key] and "ON" or "OFF")
      row:SetAlpha(db.selected[option.key] and 1 or 0.55)
    end)
    row.toggle:SetPoint("RIGHT", -12, 0)
    frame.rows[option.key] = row
  end

  frame.result = Font(frame, "Ready.", 10)
  frame.result:SetPoint("BOTTOMLEFT", 28, 26)
  frame.result:SetTextColor(0.7, 0.75, 0.8)

  frame.install = Button(frame, "INSTALL SELECTED", 165, function()
    if InCombatLockdown and InCombatLockdown() then
      frame.result:SetText("Leave combat before installing.")
      frame.result:SetTextColor(0.95, 0.25, 0.2)
      return
    end

    local messages = {}
    local profiles = RUI.modules.profiles
    if profiles and profiles.InstallSelected then
      local results = profiles:InstallSelected()
      for key, result in pairs(results) do
        messages[#messages + 1] = key .. ": " .. (result[1] and "installed" or tostring(result[2] or "skipped"))
      end
    end

    local wa = RUI.modules.weakauras
    if wa and wa.InstallSelected then
      local results = wa:InstallSelected()
      for key, result in pairs(results) do
        messages[#messages + 1] = key .. ": " .. (result[1] and "imported" or tostring(result[2] or "skipped"))
      end
    end

    local db = RUI:EnsureDB()
    db.installerCompleted = true
    frame.result:SetText(#messages > 0 and table.concat(messages, "  •  ") or "Core HUD installed. Optional profiles were skipped.")
    frame.result:SetTextColor(0.35, 0.9, 0.45)
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
  local db = self:EnsureDB()
  for _, option in ipairs(OPTIONS) do
    local row = installer.rows[option.key]
    local enabled = db.selected[option.key]
    row.toggle.label:SetText(enabled and "ON" or "OFF")
    row:SetAlpha(enabled and 1 or 0.55)
  end
  installer:Show()
end

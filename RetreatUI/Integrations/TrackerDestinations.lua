local RUI = RetreatUI
if not RUI or RUI._trackerDestinationsLoaded then return end

local DESTINATIONS = {"hud", "targetFrame", "nameplates"}
local DESTINATION_LABELS = {
  hud = "HUD (WeakAuras)",
  targetFrame = "Target Frame (ElvUI)",
  nameplates = "Nameplates (TurboPlates)",
}

local function HasValue(values, wanted)
  if type(values) ~= "table" then return false end
  for _, value in ipairs(values) do
    if value == wanted then return true end
  end
  return false
end

local function HasType(entryOrTypes, wanted)
  if type(entryOrTypes) ~= "table" then return false end
  local values = entryOrTypes.trackingTypes or entryOrTypes
  if type(values) == "table" then
    for _, value in ipairs(values) do
      if value == wanted then return true end
    end
  end
  return entryOrTypes.trackingType == wanted
end

local function InferDestinations(entryOrItem, types, unit)
  types = type(types) == "table" and types or (entryOrItem and entryOrItem.trackingTypes) or {}
  unit = unit or (entryOrItem and entryOrItem.unit) or (entryOrItem and entryOrItem.defaultUnit)

  local result = {}
  local hasDebuff = HasType(types, "debuff")
  local hasHUDDriver = HasType(types, "cooldown")
    or HasType(types, "buff")
    or HasType(types, "proc")
    or HasType(types, "charges")
    or HasType(types, "resource")
    or HasType(types, "summon")

  if hasHUDDriver or not hasDebuff then result[#result + 1] = "hud" end
  if hasDebuff and (unit == nil or unit == "target" or unit == "focus") then
    result[#result + 1] = "targetFrame"
    result[#result + 1] = "nameplates"
  end
  if #result == 0 then result[1] = "hud" end
  return result
end

local function CleanDestinations(values, entryOrItem, types, unit)
  local source = type(values) == "table" and values or InferDestinations(entryOrItem, types, unit)
  local result, seen = {}, {}
  for _, allowed in ipairs(DESTINATIONS) do
    for _, value in ipairs(source) do
      if value == allowed and not seen[value] then
        result[#result + 1] = value
        seen[value] = true
      end
    end
  end
  if #result == 0 then return InferDestinations(entryOrItem, types, unit) end
  return result
end

function RUI:GetTrackerDestinations(entry)
  if type(entry) ~= "table" then return {"hud"} end
  return CleanDestinations(entry.destinations, entry, entry.trackingTypes, entry.unit)
end

function RUI:TrackerUsesDestination(entry, destination)
  return HasValue(self:GetTrackerDestinations(entry), destination)
end

function RUI:GetTrackerDestinationEntries(className, destination, requiredType)
  local result = {}
  for _, entry in ipairs(self:GetSelectedTrackers(className) or {}) do
    if self:TrackerUsesDestination(entry, destination)
      and (requiredType == nil or HasType(entry, requiredType))
    then
      result[#result + 1] = entry
    end
  end
  return result
end

local function CollectEditorDestinations(frame)
  local result = {}
  if not frame or type(frame.destinationChecks) ~= "table" then return result end
  for _, key in ipairs(DESTINATIONS) do
    local check = frame.destinationChecks[key]
    if check and check:GetChecked() then result[#result + 1] = key end
  end
  return result
end

local function MakeCheck(parent, label, x, y)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetWidth(22); check:SetHeight(22)
  check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  check.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)
  check.text:SetText(label)
  return check
end

local function RefreshDestinationControls(frame)
  if not frame or type(frame.destinationChecks) ~= "table" then return end
  local hud = frame.destinationChecks.hud:GetChecked() and true or false

  if frame.buildWeakAura then
    if hud then frame.buildWeakAura:Enable() else frame.buildWeakAura:Disable() end
  end

  for _, control in ipairs({frame.groupButton, frame.sizeMinus, frame.sizePlus, frame.glowButton}) do
    if control then
      if hud then control:Enable() else control:Disable() end
    end
  end

  if frame.safety then
    if hud then
      frame.safety:SetText("HUD builds a native WeakAura. Target Frame and Nameplates are applied through ElvUI/TurboPlates.")
    else
      frame.safety:SetText("This tracker is routed through ElvUI/TurboPlates; no WeakAura will be created.")
    end
  end
end

local function EnsureDestinationControls(frame)
  if not frame or frame.destinationChecks then return end
  frame:SetHeight(630)

  frame.destinationLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.destinationLabel:SetPoint("TOPLEFT", 24, -274)
  frame.destinationLabel:SetText("Where should this appear?")

  frame.destinationHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.destinationHint:SetPoint("TOPLEFT", frame.destinationLabel, "BOTTOMLEFT", 0, -3)
  frame.destinationHint:SetText("Each destination is owned by its native addon.")

  frame.destinationChecks = {
    hud = MakeCheck(frame, DESTINATION_LABELS.hud, 24, -308),
    targetFrame = MakeCheck(frame, DESTINATION_LABELS.targetFrame, 188, -308),
    nameplates = MakeCheck(frame, DESTINATION_LABELS.nameplates, 370, -308),
  }

  if frame.settingsLabel then
    frame.settingsLabel:ClearAllPoints(); frame.settingsLabel:SetPoint("TOPLEFT", 24, -346)
  end
  if frame.unitButton then
    frame.unitButton:ClearAllPoints(); frame.unitButton:SetPoint("TOPLEFT", 24, -375)
  end
  if frame.groupButton then
    frame.groupButton:ClearAllPoints(); frame.groupButton:SetPoint("TOPLEFT", 24, -411)
  end
  if frame.sizeMinus then
    frame.sizeMinus:ClearAllPoints(); frame.sizeMinus:SetPoint("TOPLEFT", 230, -412)
  end
  if frame.cooldownText then
    frame.cooldownText:ClearAllPoints(); frame.cooldownText:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -451)
  end
  if frame.duration then
    frame.duration:ClearAllPoints(); frame.duration:SetPoint("TOPLEFT", frame, "TOPLEFT", 185, -451)
  end
  if frame.stacks then
    frame.stacks:ClearAllPoints(); frame.stacks:SetPoint("TOPLEFT", frame, "TOPLEFT", 330, -451)
  end
  if frame.learnedOnly then
    frame.learnedOnly:ClearAllPoints(); frame.learnedOnly:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -483)
  end
  if frame.combatOnly then
    frame.combatOnly:ClearAllPoints(); frame.combatOnly:SetPoint("TOPLEFT", frame, "TOPLEFT", 185, -483)
  end

  for _, key in ipairs(DESTINATIONS) do
    local check = frame.destinationChecks[key]
    check:SetScript("OnClick", function(self)
      local selected = CollectEditorDestinations(frame)
      if #selected == 0 then self:SetChecked(1) end
      RefreshDestinationControls(frame)
    end)
  end
end

local BaseSaveTrackerSelection = RUI.SaveTrackerSelection
if type(BaseSaveTrackerSelection) == "function" then
  function RUI:SaveTrackerSelection(item, config)
    config = type(config) == "table" and config or {}
    local requested = config.destinations
    local frame = self.trackerEditorFrame
    if requested == nil and frame and frame.item == item and frame.destinationChecks then
      requested = CollectEditorDestinations(frame)
    end

    local ok, savedOrReason = BaseSaveTrackerSelection(self, item, config)
    if not ok then return ok, savedOrReason end

    local saved = savedOrReason
    saved.destinations = CleanDestinations(requested, saved, saved.trackingTypes, saved.unit)
    if self.ApplyTrackerDestinations then pcall(self.ApplyTrackerDestinations, self, item.className) end
    return true, saved
  end
end

local BaseRemoveTrackerSelection = RUI.RemoveTrackerSelection
if type(BaseRemoveTrackerSelection) == "function" then
  function RUI:RemoveTrackerSelection(className, key)
    local removed = BaseRemoveTrackerSelection(self, className, key)
    if removed and self.ApplyTrackerDestinations then pcall(self.ApplyTrackerDestinations, self, className) end
    return removed
  end
end

local BaseApplyTrackerProfileData = RUI.ApplyTrackerProfileData
if type(BaseApplyTrackerProfileData) == "function" then
  function RUI:ApplyTrackerProfileData(data, options)
    local ok, result = BaseApplyTrackerProfileData(self, data, options)
    if ok then
      local selected = self:GetSelectedTrackers(data.className)
      for _, entry in ipairs(selected) do
        entry.destinations = CleanDestinations(entry.destinations, entry, entry.trackingTypes, entry.unit)
      end
      if self.ApplyTrackerDestinations then pcall(self.ApplyTrackerDestinations, self, data.className) end
    end
    return ok, result
  end
end

local BaseBuildNativeTrackerImport = RUI.BuildNativeTrackerImport
if type(BaseBuildNativeTrackerImport) == "function" then
  function RUI:BuildNativeTrackerImport(entry)
    if type(entry) == "table" and not self:TrackerUsesDestination(entry, "hud") then
      return nil, "This tracker is routed to ElvUI/TurboPlates. Enable HUD to build a WeakAura."
    end
    return BaseBuildNativeTrackerImport(self, entry)
  end
end

local BaseOpenTrackerEditor = RUI.OpenTrackerEditor
if type(BaseOpenTrackerEditor) == "function" then
  function RUI:OpenTrackerEditor(item, ...)
    local opened = BaseOpenTrackerEditor(self, item, ...)
    local frame = self.trackerEditorFrame
    if not frame then return opened end

    EnsureDestinationControls(frame)
    local existing = self:GetTrackerSelection(item.className, item.key)
    local types = (existing and existing.trackingTypes) or item.trackingTypes or {"cooldown"}
    local unit = (existing and existing.unit) or item.defaultUnit
    local destinations = CleanDestinations(existing and existing.destinations, existing or item, types, unit)
    for _, key in ipairs(DESTINATIONS) do
      frame.destinationChecks[key]:SetChecked(HasValue(destinations, key) and 1 or nil)
    end
    RefreshDestinationControls(frame)
    return opened
  end
end

function RUI:ApplyTurboPlatesTrackerDestinations(className)
  if type(TurboPlatesDB) ~= "table" then return false, "TurboPlates is not loaded" end
  TurboPlatesDB.auras = TurboPlatesDB.auras or {}
  TurboPlatesDB.auras.whitelist = TurboPlatesDB.auras.whitelist or {}
  TurboPlatesDB.auras.showDebuffs = true

  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.integrations = RetreatUIDB.integrations or {}
  local managed = RetreatUIDB.integrations.turboPlatesTrackerWhitelist or {}
  RetreatUIDB.integrations.turboPlatesTrackerWhitelist = managed
  local desired = {}

  for _, entry in ipairs(self:GetTrackerDestinationEntries(className, "nameplates", "debuff")) do
    local spellID = tonumber(entry.auraID) or tonumber(entry.spellID)
    if spellID and spellID > 0 then desired[spellID] = true end
  end

  for key, record in pairs(managed) do
    local spellID = tonumber(record.spellID) or tonumber(key)
    if spellID and not desired[spellID] then
      if record.hadOriginal then
        TurboPlatesDB.auras.whitelist[spellID] = record.original
      else
        TurboPlatesDB.auras.whitelist[spellID] = nil
      end
      managed[key] = nil
    end
  end

  for spellID in pairs(desired) do
    local key = tostring(spellID)
    if not managed[key] then
      managed[key] = {
        spellID = spellID,
        hadOriginal = TurboPlatesDB.auras.whitelist[spellID] ~= nil,
        original = TurboPlatesDB.auras.whitelist[spellID],
      }
    end
    TurboPlatesDB.auras.whitelist[spellID] = true
  end

  return true, "TurboPlates tracker destinations applied"
end

function RUI:ApplyTrackerDestinations(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if type(className) ~= "string" or className == "" then return false end

  if self.ApplyElvUITargetDebuffDestinations then
    pcall(self.ApplyElvUITargetDebuffDestinations, self, className)
  end
  pcall(self.ApplyTurboPlatesTrackerDestinations, self, className)
  return true
end

local function MigrateExistingSelections()
  if type(RetreatUIDB) ~= "table" or type(RetreatUIDB.trackerBuilder) ~= "table" then return end
  local selected = RetreatUIDB.trackerBuilder.selected
  if type(selected) ~= "table" then return end
  for _, classEntries in pairs(selected) do
    if type(classEntries) == "table" then
      for _, entry in pairs(classEntries) do
        if type(entry) == "table" and type(entry.destinations) ~= "table" then
          entry.destinations = CleanDestinations(nil, entry, entry.trackingTypes, entry.unit)
        end
      end
    end
  end
end

MigrateExistingSelections()
RUI._trackerDestinationsLoaded = true
RUI.trackerDestinationSchema = 1

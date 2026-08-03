local RUI = RetreatUI
if not RUI then return end

-- Party utility, interrupt, combat-res, dispel, external and group defensive
-- tracking was removed from RetreatUI. Keep this migration loaded before the
-- installer so old SavedVariables cannot re-enable or display the retired
-- module after upgrading from the previous stable release.
local function RemoveModuleKey(key)
  if type(RUI.moduleOrder) ~= "table" then return end
  for index = #RUI.moduleOrder, 1, -1 do
    if RUI.moduleOrder[index] == key then table.remove(RUI.moduleOrder, index) end
  end
end

RemoveModuleKey("partyTrackers")
if type(RUI.moduleInstallers) == "table" then RUI.moduleInstallers.partyTrackers = nil end

local db = type(RUI.EnsureDB) == "function" and RUI:EnsureDB() or nil
if db then
  db.features = db.features or {}
  db.features.partyUtility = false
  db.features.partyInterrupts = false

  db.partyUtility = db.partyUtility or {}
  db.partyUtility.enabled = false

  db.partyInterrupts = db.partyInterrupts or {}
  db.partyInterrupts.enabled = false

  db.installer = db.installer or {}
  db.installer.moduleSelections = db.installer.moduleSelections or {}
  db.installer.moduleSelections.partyTrackers = false

  if type(db.moduleStatus) == "table" then
    db.moduleStatus.partyTrackers = nil
  end
end

for _, frameName in ipairs({
  "RetreatUIPartyInterruptTracker",
  "RetreatUIPartyUtilityDriverV4",
  "RetreatUIPartyUtilitySettingsV4",
}) do
  local frame = _G[frameName]
  if frame and type(frame.Hide) == "function" then pcall(frame.Hide, frame) end
  if frame and type(frame.UnregisterAllEvents) == "function" then pcall(frame.UnregisterAllEvents, frame) end
  if frame and type(frame.SetScript) == "function" then
    pcall(frame.SetScript, frame, "OnUpdate", nil)
    pcall(frame.SetScript, frame, "OnEvent", nil)
  end
end

RUI.InitializePartyUtilityTracker = nil
RUI.RefreshPartyUtility = nil
RUI.OpenPartyUtilitySettings = nil
RUI.TogglePartyUtilityPreview = nil
RUI.SetPartyInterruptEditorPreview = nil
RUI.GetPartyInterruptTrackerStatus = nil
RUI.GetPartyUtilityStatus = nil
RUI._partyUtilityV4Loaded = false
RUI._partyTrackersRetired = true

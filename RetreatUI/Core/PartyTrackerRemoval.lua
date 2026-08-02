local RUI = RetreatUI
if not RUI then return end

-- Party utility and interrupt tracking are intentionally removed from the
-- active RetreatUI build. The previous implementations remain available in
-- repository history for a later clean redesign.

local function RemoveModuleRegistration()
  local order = {}
  for _, key in ipairs(RUI.moduleOrder or {}) do
    if key ~= "partyTrackers" then order[#order + 1] = key end
  end
  RUI.moduleOrder = order

  if type(RUI.moduleInstallers) == "table" then
    RUI.moduleInstallers.partyTrackers = nil
  end
end

local function DisableSavedSettings()
  if type(RUI.EnsureDB) ~= "function" then return end
  local db = RUI:EnsureDB()
  db.features = db.features or {}
  db.features.partyUtility = false
  db.features.partyInterrupts = false

  db.partyUtility = db.partyUtility or {}
  db.partyUtility.enabled = false

  db.partyInterrupts = db.partyInterrupts or {}
  db.partyInterrupts.enabled = false

  if db.installer and db.installer.moduleSelections then
    db.installer.moduleSelections.partyTrackers = nil
  end
  if db.moduleStatus then
    db.moduleStatus.partyTrackers = nil
  end
end

local function HideLegacyFrames()
  for _, name in ipairs({
    "RetreatUIPartyInterruptTracker",
    "RetreatUIPartyUtilitySettings",
    "RetreatUIPartyInterruptSettings",
  }) do
    local frame = _G[name]
    if frame then
      if type(frame.UnregisterAllEvents) == "function" then pcall(frame.UnregisterAllEvents, frame) end
      if type(frame.Hide) == "function" then pcall(frame.Hide, frame) end
    end
  end
end

RemoveModuleRegistration()
DisableSavedSettings()
HideLegacyFrames()

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
  RemoveModuleRegistration()
  DisableSavedSettings()
  HideLegacyFrames()
end)

RUI._partyTrackersRemoved = true

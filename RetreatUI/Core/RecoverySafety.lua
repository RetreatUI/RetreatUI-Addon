local RUI = RetreatUI
if not RUI then return end

-- Emergency recovery gate.
-- The active source has been reset to the last user-confirmed stable baseline.
-- Party utility and interrupt tracking stay disabled until they are rebuilt in
-- an isolated addon and validated separately from the live RetreatUI package.
local function DisableRetiredPartyTrackers()
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

    if db.moduleStatus then
      db.moduleStatus.partyTrackers = nil
    end
  end

  if type(RUI.moduleOrder) == "table" then
    for index = #RUI.moduleOrder, 1, -1 do
      if RUI.moduleOrder[index] == "partyTrackers" then
        table.remove(RUI.moduleOrder, index)
      end
    end
  end

  if type(RUI.moduleInstallers) == "table" then
    RUI.moduleInstallers.partyTrackers = nil
  end

  RUI.InitializePartyUtilityTracker = nil
  RUI.RefreshPartyUtility = nil
  RUI.OpenPartyUtilitySettings = nil
  RUI.TogglePartyUtilityPreview = nil

  for _, frameName in ipairs({
    "RetreatUIPartyInterruptTracker",
    "RetreatUIPartyUtilityTracker",
    "RetreatUIPartyUtilitySettings",
  }) do
    local frame = _G[frameName]
    if frame and type(frame.Hide) == "function" then frame:Hide() end
  end
end

DisableRetiredPartyTrackers()
RUI._recoverySafetyLoaded = true

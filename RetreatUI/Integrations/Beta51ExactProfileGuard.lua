local RUI = RetreatUI
if not RUI then return end

local function ExactStyleActive()
  local db = type(RUI.EnsureDB)=="function" and RUI:EnsureDB() or nil
  local state = db and db.profileStyle
  if type(state)~="table" or (state.key~="focus" and state.key~="edge") then return false end
  return type(state.elvMode)=="string" and string.find(state.elvMode,"original",1,true)~=nil
end

local function PreserveMethod(name, message)
  local original = RUI[name]
  if type(original)~="function" then return end
  RUI[name] = function(self,...)
    if ExactStyleActive() then return true, message or ("Exact ElvUI profile preserved: "..name) end
    return original(self,...)
  end
end

-- These functions belong to the old generated/native RetreatUI layout. They
-- must never rewrite a successfully imported original Focus/Edge profile.
PreserveMethod("ApplyPartyFramePosition")
PreserveMethod("ApplyTargetTargetFrame")
PreserveMethod("ApplyElvUIHUDPolish")
PreserveMethod("RepairElvUIAuraProfiles")
PreserveMethod("ApplyRaidFrameHotfix")
PreserveMethod("ApplyElvUIPartyText")

-- The original ElvUI profile owns its fonts too. Do not recursively restyle it
-- after import. TurboPlates/Details are installed separately by the profile pack.
local OriginalSyncThemeFonts = RUI.SyncThemeFonts
if type(OriginalSyncThemeFonts)=="function" then
  function RUI:SyncThemeFonts(...)
    if ExactStyleActive() then return true, "Exact ElvUI profile fonts preserved" end
    return OriginalSyncThemeFonts(self,...)
  end
end

local OriginalIsInstallerModuleEnabled = RUI.IsInstallerModuleEnabled
if type(OriginalIsInstallerModuleEnabled)=="function" then
  function RUI:IsInstallerModuleEnabled(key)
    if key=="unitframes" and ExactStyleActive() then return false end
    return OriginalIsInstallerModuleEnabled(self,key)
  end
end

RUI._beta51ExactProfileGuardLoaded = true
RUI.beta51ExactProfileGuardSchema = 1

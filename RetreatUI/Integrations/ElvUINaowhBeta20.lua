local RUI = RetreatUI
if not RUI then return end

-- beta.20: import the user-supplied NaowhUI TBC ElvUI profile with Ascension
-- ElvUI 7.27's own Distributor decoder. Layout data stays untouched; only media
-- names that are not shipped by RetreatUI are substituted.

local PROFILE_NAME = "RetreatUI"
local MEDIA_REPLACEMENTS = {
  ["Naowh"] = "Fira Sans Heavy",
  ["NaowhLeft"] = "ElvUI Norm",
}

local function ReplaceUnsupportedMedia(value)
  if type(value) ~= "table" then return end
  for key, child in pairs(value) do
    if type(child) == "table" then
      ReplaceUnsupportedMedia(child)
    elseif type(child) == "string" and MEDIA_REPLACEMENTS[child] then
      value[key] = MEDIA_REPLACEMENTS[child]
    end
  end
end

local function CharacterKey()
  if not UnitName then return nil end
  local character = UnitName("player")
  local realm = GetRealmName and GetRealmName()
  if character and realm and realm ~= "" then return character .. " - " .. realm end
  return character
end

local function ApplyPrivateNaowhSettings(E)
  if not E or type(E.private) ~= "table" then return end
  E.private.general = E.private.general or {}
  local general = E.private.general
  general.chatBubbleFont = "Fira Sans Heavy"
  general.chatBubbleFontOutline = "OUTLINE"
  general.chatBubbleFontSize = 10
  general.chatBubbles = "backdrop_noborder"
  general.dmgfont = "Fira Sans Heavy"
  general.glossTex = "ElvUI Norm"
  general.minimap = general.minimap or {}
  general.minimap.hideTracking = true
  general.namefont = "Fira Sans Heavy"
  general.normTex = "ElvUI Norm"

  E.private.nameplates = E.private.nameplates or {}
  E.private.nameplates.enable = false
end

local function ApplyNaowhGlobalSettings(E, resolution)
  local scale = RUI.NaowhElvUIScales and RUI.NaowhElvUIScales[resolution]
  if E and E.data and type(E.data.global) == "table" then
    E.data.global.general = E.data.global.general or {}
    if scale then E.data.global.general.UIScale = scale end
    if type(E.data.global.general.WorldMapCoordinates) == "table" then
      E.data.global.general.WorldMapCoordinates.position = "BOTTOM"
    end
  end
  if E and E.SetupCVars then pcall(E.SetupCVars, E, true) end
end

function RUI:InstallElvUIProfile(resolution)
  resolution = resolution == "1080p" and "1080p" or "1440p"

  local loaded = self:EnsureAddOnLoaded("ElvUI")
  if not loaded or not ElvUI or not ElvDB then return false, "ElvUI is not loaded" end
  local E = unpack(ElvUI)
  if not E or not E.GetModule then return false, "ElvUI 7.27 profile API is unavailable" end

  local distributor
  local ok, value = pcall(E.GetModule, E, "Distributor", true)
  if ok then distributor = value end
  if not distributor or type(distributor.Decode) ~= "function" then
    return false, "ElvUI Distributor:Decode is unavailable in this CoA build"
  end

  local export = self.NaowhElvUIExports and self.NaowhElvUIExports[resolution]
  if type(export) ~= "string" or export == "" then return false, "Naowh ElvUI " .. resolution .. " profile is missing" end

  local decodeOK, profileType, _, profile = pcall(distributor.Decode, distributor, export)
  if not decodeOK then return false, "ElvUI profile decode failed: " .. tostring(profileType) end
  if profileType ~= "profile" or type(profile) ~= "table" then
    return false, "ElvUI rejected the Naowh profile export"
  end

  ReplaceUnsupportedMedia(profile)
  profile.nameplates = profile.nameplates or {}
  profile.nameplates.enable = false

  ElvDB.profiles = ElvDB.profiles or {}
  ElvDB.profiles[PROFILE_NAME] = profile
  ElvDB.profileKeys = ElvDB.profileKeys or {}
  local characterKey = CharacterKey()
  if characterKey and characterKey ~= "" then ElvDB.profileKeys[characterKey] = PROFILE_NAME end

  -- Ascension 7.27 can omit default aura fields from sparse exports. The
  -- compatibility repair only fills missing defaults; it must not reposition or
  -- restyle the Naowh profile.
  if type(self.RepairElvUIAuraProfiles) == "function" then
    pcall(self.RepairElvUIAuraProfiles, self, false)
  end

  ApplyPrivateNaowhSettings(E)
  ApplyNaowhGlobalSettings(E, resolution)

  local activateOK, activateError = pcall(function()
    if E.data and E.data.SetProfile then E.data:SetProfile(PROFILE_NAME) end
    if E.UpdateAll then E:UpdateAll(true) end
  end)

  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.version = self.version
  db.integrations.elvui.profile = PROFILE_NAME
  db.integrations.elvui.naowhResolution = resolution
  db.integrations.elvui.naowhBeta20 = true

  if not activateOK then
    db.integrations.elvui.activationWarning = tostring(activateError)
    db.integrations.elvui.activationPendingReload = true
    return true, "Naowh " .. resolution .. " ElvUI layout saved; activation will finish after reload"
  end

  db.integrations.elvui.activationWarning = nil
  db.integrations.elvui.activationPendingReload = nil
  return true, "Naowh " .. resolution .. " ElvUI layout installed for CoA"
end

-- Historical beta.11-beta.19 HUD polish functions repositioned frames after the
-- profile import. beta.20 owns those positions in the Naowh profile itself, so
-- keep compatibility callers harmless instead of letting them mutate the 1:1
-- layout after installation.
function RUI:ApplyPartyFramePosition()
  return true, "Naowh beta.20 party position preserved"
end

function RUI:ApplyTargetTargetFrame()
  return true, "Naowh beta.20 target-target position preserved"
end

function RUI:ApplyElvUIHUDPolish()
  return true, "Naowh beta.20 ElvUI layout preserved"
end

RUI._naowhElvUIBeta20Loaded = true
RUI._naowhElvUIBeta20Revision = 20

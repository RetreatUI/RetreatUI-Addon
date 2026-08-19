local RUI = RetreatUI
if not RUI then return end

-- beta.20 imports the bundled ElvUI layout through Ascension ElvUI 7.27's
-- Distributor decoder. Only unavailable media names are normalized to media
-- already shipped with RetreatUI.
local PROFILE_NAME = "RetreatUI"

local function GetExports(self)
  if type(self.Beta20ElvUIExports) == "table" then return self.Beta20ElvUIExports end
  return nil
end

local function MediaExists(mediaType, name)
  if type(name) ~= "string" or name == "" then return false end
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if not LSM or type(LSM.Fetch) ~= "function" then return true end
  local ok, value = pcall(LSM.Fetch, LSM, mediaType, name, true)
  return ok and value ~= nil
end

-- Never use a broad substring match here. In particular, "text" contains
-- "tex"; the old beta.20 normalizer consequently replaced ElvUI tag/text
-- strings with the literal statusbar media name "ElvUI Norm".
local STATUSBAR_MEDIA_KEYS = {
  texture = true,
  statusbar = true,
  statusbartexture = true,
  bartexture = true,
  healthtexture = true,
  powertexture = true,
  castbartexture = true,
  normtex = true,
  glosstex = true,
}

local function IsStatusbarMediaKey(key)
  local lowered = tostring(key or ""):lower()
  if STATUSBAR_MEDIA_KEYS[lowered] then return true end
  if lowered:sub(-7) == "texture" then return true end
  if lowered:sub(-9) == "statusbar" then return true end
  return false
end

local function NormalizeUnsupportedMedia(value)
  if type(value) ~= "table" then return end
  for key, child in pairs(value) do
    if type(child) == "table" then
      NormalizeUnsupportedMedia(child)
    elseif type(child) == "string" then
      local lowered = tostring(key):lower()
      if lowered:find("font", 1, true) and not MediaExists("font", child) then
        value[key] = "Fira Sans Heavy"
      elseif IsStatusbarMediaKey(key)
        and not child:find("\\", 1, true)
        and not MediaExists("statusbar", child) then
        value[key] = "ElvUI Norm"
      end
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

local function ApplyPrivateSettings(E)
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

local function ApplyGlobalSettings(E, resolution)
  local scales = RUI.Beta20ElvUIScales
  local scale = type(scales) == "table" and scales[resolution] or nil

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

  local exports = GetExports(self)
  local export = type(exports) == "table" and exports[resolution] or nil
  if type(export) ~= "string" or export == "" then
    return false, "RetreatUI ElvUI " .. resolution .. " profile is missing"
  end

  local decodeOK, profileType, _, profile = pcall(distributor.Decode, distributor, export)
  if not decodeOK then return false, "ElvUI profile decode failed: " .. tostring(profileType) end
  if profileType ~= "profile" or type(profile) ~= "table" then
    return false, "ElvUI rejected the bundled RetreatUI profile export"
  end

  NormalizeUnsupportedMedia(profile)
  profile.nameplates = profile.nameplates or {}
  profile.nameplates.enable = false

  ElvDB.profiles = ElvDB.profiles or {}
  ElvDB.profiles[PROFILE_NAME] = profile
  ElvDB.profileKeys = ElvDB.profileKeys or {}
  local characterKey = CharacterKey()
  if characterKey and characterKey ~= "" then ElvDB.profileKeys[characterKey] = PROFILE_NAME end

  if type(self.RepairElvUIAuraProfiles) == "function" then
    pcall(self.RepairElvUIAuraProfiles, self, false)
  end

  ApplyPrivateSettings(E)
  ApplyGlobalSettings(E, resolution)

  local activateOK, activateError = pcall(function()
    if E.data and E.data.SetProfile then E.data:SetProfile(PROFILE_NAME) end
    if E.UpdateAll then E:UpdateAll(true) end
  end)

  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.version = self.version
  db.integrations.elvui.profile = PROFILE_NAME
  db.integrations.elvui.resolution = resolution
  db.integrations.elvui.beta20 = true

  if not activateOK then
    db.integrations.elvui.activationWarning = tostring(activateError)
    db.integrations.elvui.activationPendingReload = true
    return true, "RetreatUI " .. resolution .. " ElvUI layout saved; activation will finish after reload"
  end

  db.integrations.elvui.activationWarning = nil
  db.integrations.elvui.activationPendingReload = nil
  return true, "RetreatUI " .. resolution .. " ElvUI layout installed for CoA"
end

-- beta.20 owns these positions in the imported profile. Compatibility callers
-- are intentionally harmless so /rui repair cannot move the layout afterwards.
function RUI:ApplyPartyFramePosition()
  return true, "RetreatUI beta.20 party position preserved"
end

function RUI:ApplyTargetTargetFrame()
  return true, "RetreatUI beta.20 target-target position preserved"
end

function RUI:ApplyElvUIHUDPolish()
  return true, "RetreatUI beta.20 ElvUI layout preserved"
end

RUI._elvUIBeta20Loaded = true
RUI._elvUIBeta20Revision = 23

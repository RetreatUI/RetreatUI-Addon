local RUI = RetreatUI
if not RUI then return end

local function Copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}; seen[value] = result
  for key, child in pairs(value) do result[Copy(key, seen)] = Copy(child, seen) end
  return result
end

local function Engine()
  if type(ElvUI) ~= "table" then return nil end
  if type(ElvUI[1]) == "table" then return ElvUI[1] end
  local ok, E = pcall(function() return unpack(ElvUI) end)
  return ok and type(E) == "table" and E or nil
end

local function Resolution()
  if type(GetCVar) == "function" then
    local ok, value = pcall(GetCVar, "gxResolution")
    if ok and type(value) == "string" then
      local height = tonumber(value:match("x(%d+)$"))
      if height and height >= 1200 then return "1440p" end
    end
  end
  local height = GetScreenHeight and tonumber(GetScreenHeight()) or 1080
  return height and height >= 1200 and "1440p" or "1080p"
end

local function PreserveScale()
  local result = {}
  if type(GetCVar) == "function" then
    local ok1, v1 = pcall(GetCVar, "useUiScale"); if ok1 then result.useUiScale = v1 end
    local ok2, v2 = pcall(GetCVar, "uiScale"); if ok2 then result.uiScale = v2 end
  end
  return result
end
local function RestoreScale(state)
  if type(SetCVar) ~= "function" or type(state) ~= "table" then return end
  if state.useUiScale ~= nil then pcall(SetCVar, "useUiScale", tostring(state.useUiScale)) end
  if state.uiScale ~= nil then pcall(SetCVar, "uiScale", tostring(state.uiScale)) end
end
local function SanitizeScale(profile)
  if type(profile) ~= "table" then return end
  profile.general = profile.general or {}
  profile.general.autoScale = nil
  profile.general.customUIScale = nil
  profile.general.uiScale = nil
end

local function Decode(payload)
  if type(payload) ~= "string" or payload == "" then return nil, "reference payload missing" end
  local E = Engine(); if not E or type(E.GetModule) ~= "function" then return nil, "ElvUI engine unavailable" end
  local okModule, D = pcall(E.GetModule, E, "Distributor", true)
  if not okModule or type(D) ~= "table" or type(D.Decode) ~= "function" then return nil, "ElvUI Distributor unavailable" end
  local ok, profileType, _, data = pcall(D.Decode, D, payload)
  if not ok or profileType ~= "profile" or type(data) ~= "table" then return nil, "reference profile decode failed" end
  return Copy(data), nil, E, D
end

local function InstallTable(self, profileName, profile)
  local E = Engine(); if not E or not E.mynameRealm then return false, "ElvUI engine unavailable" end
  profile = Copy(profile or {}); SanitizeScale(profile)
  profile.nameplates = profile.nameplates or {}; profile.nameplates.enable = false
  ElvDB = ElvDB or {}; ElvDB.profiles = ElvDB.profiles or {}; ElvDB.profileKeys = ElvDB.profileKeys or {}
  ElvDB.profiles[profileName] = profile
  local scale = PreserveScale()
  local switched = false
  if E.data and type(E.data.SetProfile) == "function" then switched = pcall(E.data.SetProfile, E.data, profileName) end
  if not switched and E.db and type(E.db.SetProfile) == "function" then switched = pcall(E.db.SetProfile, E.db, profileName) end
  ElvDB.profileKeys[E.mynameRealm] = profileName
  RestoreScale(scale)
  if type(self.DisableElvUINamePlates) == "function" then pcall(self.DisableElvUINamePlates, self) end
  if type(E.UpdateMoverPositions) == "function" then pcall(E.UpdateMoverPositions, E) end
  if type(E.StaggeredUpdateAll) == "function" then pcall(E.StaggeredUpdateAll, E)
  elseif type(E.UpdateAll) == "function" then pcall(E.UpdateAll, E, true) end
  return true, profile
end

function RUI:InstallRetreatStyleElvUI(styleKey, requestedResolution)
  local style = self.ProfileStyles and self.ProfileStyles[styleKey]
  if not style then return false, "Unknown profile style" end
  if not self:EnsureAddOnLoaded("ElvUI") then return false, "ElvUI is not loaded" end

  local resolution = requestedResolution or Resolution()
  local source = self.ReferenceElvUIProfiles and self.ReferenceElvUIProfiles[styleKey]
  local reference = source and source[resolution]
  local profile, reason = reference and Decode(reference.profile)
  local mode = "reference " .. resolution

  if type(profile) ~= "table" then
    mode = "native CoA fallback"
    profile = type(self.GetNativeElvUIProfile) == "function" and self:GetNativeElvUIProfile(styleKey) or nil
    if type(profile) ~= "table" then return false, reason or "No profile data available" end
  end

  local profileName = style.elvProfileName or (styleKey == "focus" and "Retreat Focus" or "Retreat Edge")
  local ok, installed = InstallTable(self, profileName, profile)
  if not ok then return false, installed end

  self.ElvUIProfile = Copy(installed)
  local db = self:EnsureDB(); db.profileStyle = db.profileStyle or {}
  db.profileStyle.key = styleKey
  db.profileStyle.resolution = resolution
  db.profileStyle.elvProfileName = profileName
  db.profileStyle.elvMode = mode
  db.profileStyle.version = self.version

  return true, style.label .. " activated (" .. mode .. ")"
end

RUI._beta50ProfileImportLoaded = true
RUI.beta50ProfileImportSchema = 1

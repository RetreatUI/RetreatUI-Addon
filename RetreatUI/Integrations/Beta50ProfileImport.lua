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

local function Decode(payload)
  if type(payload) ~= "string" or payload == "" then return nil, "Original ElvUI profile payload is missing" end
  local E = Engine()
  if not E or type(E.GetModule) ~= "function" then return nil, "ElvUI engine unavailable" end
  local okModule, D = pcall(E.GetModule, E, "Distributor", true)
  if not okModule or type(D) ~= "table" or type(D.Decode) ~= "function" then
    return nil, "This Ascension ElvUI build does not expose the Distributor decoder required by the original profile"
  end
  local ok, profileType, _, data = pcall(D.Decode, D, payload)
  if not ok then return nil, "Original ElvUI profile decode threw an error: " .. tostring(profileType) end
  if profileType ~= "profile" or type(data) ~= "table" then
    return nil, "Original ElvUI profile was rejected by this ElvUI version"
  end
  return Copy(data), nil, E
end

local function InstallTable(self, profileName, profile)
  local E = Engine()
  if not E or not E.mynameRealm then return false, "ElvUI engine unavailable" end

  -- Store the decoded source profile unchanged. RetreatUI does not rebuild,
  -- normalize or restyle the profile table.
  local exactProfile = Copy(profile or {})
  ElvDB = ElvDB or {}
  ElvDB.profiles = ElvDB.profiles or {}
  ElvDB.profileKeys = ElvDB.profileKeys or {}
  ElvDB.profiles[profileName] = exactProfile

  local scale = PreserveScale()
  local switched = false
  if E.data and type(E.data.SetProfile) == "function" then
    local ok = pcall(E.data.SetProfile, E.data, profileName)
    switched = ok == true
  end
  if not switched and E.db and type(E.db.SetProfile) == "function" then
    local ok = pcall(E.db.SetProfile, E.db, profileName)
    switched = ok == true
  end
  ElvDB.profileKeys[E.mynameRealm] = profileName

  if not switched then
    RestoreScale(scale)
    return false, "Original profile was decoded but ElvUI could not activate it"
  end

  -- TurboPlates is the RetreatUI nameplate system, so only the conflicting
  -- ElvUI nameplate module is disabled after the exact profile is activated.
  if type(self.DisableElvUINamePlates) == "function" then pcall(self.DisableElvUINamePlates, self) end

  if type(E.UpdateMoverPositions) == "function" then pcall(E.UpdateMoverPositions, E) end
  if type(E.StaggeredUpdateAll) == "function" then pcall(E.StaggeredUpdateAll, E)
  elseif type(E.UpdateAll) == "function" then pcall(E.UpdateAll, E, true) end

  -- Never let importing somebody else's ElvUI profile change the user's WoW
  -- global UI scale. Layout data itself remains untouched.
  RestoreScale(scale)
  return true, exactProfile
end

function RUI:InstallRetreatStyleElvUI(styleKey, requestedResolution)
  local style = self.ProfileStyles and self.ProfileStyles[styleKey]
  if not style then return false, "Unknown profile style" end
  if not self:EnsureAddOnLoaded("ElvUI") then return false, "ElvUI is not loaded" end

  local resolution = requestedResolution or Resolution()
  local source = self.ReferenceElvUIProfiles and self.ReferenceElvUIProfiles[styleKey]
  local reference = source and source[resolution]
  if not reference or type(reference.profile) ~= "string" or reference.profile == "" then
    return false, style.label .. " has no original ElvUI profile available for " .. resolution
  end

  local profile, reason = Decode(reference.profile)
  if type(profile) ~= "table" then
    return false, reason or "Original ElvUI profile could not be decoded"
  end

  local profileName = style.elvProfileName or (styleKey == "focus" and "Retreat Focus" or "Retreat Edge")
  local ok, installed = InstallTable(self, profileName, profile)
  if not ok then return false, installed end

  self.ElvUIProfile = Copy(installed)
  local db = self:EnsureDB()
  db.profileStyle = db.profileStyle or {}
  db.profileStyle.key = styleKey
  db.profileStyle.resolution = resolution
  db.profileStyle.elvProfileName = profileName
  db.profileStyle.elvMode = "original " .. resolution
  db.profileStyle.version = self.version

  return true, style.label .. " original ElvUI profile activated"
end

RUI._beta50ProfileImportLoaded = true
RUI.beta50ProfileImportSchema = 2

local RUI = RetreatUI
if not RUI then return end

local function Copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}
  seen[value] = result
  for key, child in pairs(value) do result[Copy(key, seen)] = Copy(child, seen) end
  return result
end

local function Engine()
  if type(ElvUI) ~= "table" then return nil end
  if type(ElvUI[1]) == "table" then return ElvUI[1] end
  local ok, E = pcall(function() return unpack(ElvUI) end)
  return ok and type(E) == "table" and E or nil
end

local function PreserveScale()
  local state = {}
  if type(GetCVar) == "function" then
    local ok1, value1 = pcall(GetCVar, "useUiScale")
    local ok2, value2 = pcall(GetCVar, "uiScale")
    if ok1 then state.useUiScale = value1 end
    if ok2 then state.uiScale = value2 end
  end
  return state
end

local function RestoreScale(state)
  if type(state) ~= "table" or type(SetCVar) ~= "function" then return end
  if state.useUiScale ~= nil then pcall(SetCVar, "useUiScale", tostring(state.useUiScale)) end
  if state.uiScale ~= nil then pcall(SetCVar, "uiScale", tostring(state.uiScale)) end
end

local function SanitizeScale(profile)
  if type(profile) ~= "table" then return profile end
  profile.general = profile.general or {}
  profile.general.autoScale = nil
  profile.general.customUIScale = nil
  profile.general.uiScale = nil
  return profile
end

local function InstallProfileTable(self, profileName, profile)
  local E = Engine()
  if not E or not E.mynameRealm then return false, "ElvUI engine is unavailable" end
  profile = SanitizeScale(Copy(profile or {}))
  profile.nameplates = profile.nameplates or {}
  profile.nameplates.enable = false

  ElvDB = ElvDB or {}
  ElvDB.profileKeys = ElvDB.profileKeys or {}
  ElvDB.profiles = ElvDB.profiles or {}
  ElvDB.profiles[profileName] = profile

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
  if not switched then
    ElvDB.profileKeys[E.mynameRealm] = profileName
  end
  RestoreScale(scale)

  if type(self.DisableElvUINamePlates) == "function" then pcall(self.DisableElvUINamePlates, self) end
  if type(E.StaggeredUpdateAll) == "function" then pcall(E.StaggeredUpdateAll, E)
  elseif type(E.UpdateAll) == "function" then pcall(E.UpdateAll, E, true) end

  local active = ElvDB.profileKeys and ElvDB.profileKeys[E.mynameRealm]
  if active ~= profileName and switched then
    -- Older Ascension ElvUI builds may update AceDB before profileKeys. Keep the
    -- saved-variable view in sync after a successful native profile switch.
    ElvDB.profileKeys[E.mynameRealm] = profileName
    active = profileName
  end
  if active ~= profileName then return false, "ElvUI did not activate " .. profileName end
  return true
end

if type(RUI.ProfileStyles) == "table" then
  if RUI.ProfileStyles.focus then RUI.ProfileStyles.focus.elvProfileName = "Retreat Focus" end
  if RUI.ProfileStyles.edge then RUI.ProfileStyles.edge.elvProfileName = "Retreat Edge" end
end

function RUI:GetActiveElvUIProfileName()
  local E = Engine()
  if type(ElvDB) ~= "table" or type(ElvDB.profileKeys) ~= "table" or not E or not E.mynameRealm then return nil end
  return ElvDB.profileKeys[E.mynameRealm]
end

function RUI:GetRetreatStyleKey()
  local active = self:GetActiveElvUIProfileName()
  for key, style in pairs(self.ProfileStyles or {}) do
    if style.elvProfileName and active == style.elvProfileName then return key end
  end
  return nil
end

function RUI:IsRetreatStyleActuallyActive(styleKey)
  local style = self.ProfileStyles and self.ProfileStyles[styleKey]
  return style and self:GetActiveElvUIProfileName() == style.elvProfileName or false
end

function RUI:InstallRetreatStyleElvUI(styleKey)
  local style = self.ProfileStyles and self.ProfileStyles[styleKey]
  if not style then return false, "Unknown profile style" end
  if not self:EnsureAddOnLoaded("ElvUI") then return false, "ElvUI is not loaded" end
  if type(self.GetNativeElvUIProfile) ~= "function" then return false, "RetreatUI native profile pack is unavailable" end

  local profile = self:GetNativeElvUIProfile(styleKey)
  if type(profile) ~= "table" then return false, "Native profile data is missing for " .. tostring(styleKey) end
  local profileName = style.elvProfileName or (styleKey == "focus" and "Retreat Focus" or "Retreat Edge")
  local ok, reason = InstallProfileTable(self, profileName, profile)
  if not ok then return false, reason end

  self.ElvUIProfile = Copy(profile)
  local db = self:EnsureDB(); db.profileStyle = db.profileStyle or {}
  db.profileStyle.key = styleKey
  db.profileStyle.elvProfileName = profileName
  db.profileStyle.elvMode = "native CoA"
  db.profileStyle.version = self.version

  return true, style.label .. " activated as ElvUI profile '" .. profileName .. "'"
end

RUI._profileSwitchFix = true
RUI.profileSwitchFixSchema = 3

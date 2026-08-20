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

local FOCUS_BASELINE = Copy(RUI.ElvUIProfile or {})

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

local function EdgeFallback(base)
  local profile = Copy(base or {})
  profile.movers = profile.movers or {}
  profile.movers.ElvUF_PlayerMover = "BOTTOM,ElvUIParent,BOTTOM,-345,365"
  profile.movers.ElvUF_TargetMover = "BOTTOM,ElvUIParent,BOTTOM,345,365"
  profile.movers.ElvUF_PlayerCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,-345,326"
  profile.movers.ElvUF_TargetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,345,326"
  profile.movers.ElvUF_PartyMover = "TOPLEFT,ElvUIParent,BOTTOMLEFT,265,690"
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  local player = profile.unitframe.units.player or {}; profile.unitframe.units.player = player
  local target = profile.unitframe.units.target or {}; profile.unitframe.units.target = target
  local party = profile.unitframe.units.party or {}; profile.unitframe.units.party = party
  player.width, player.height = 300, 52
  target.width, target.height = 300, 52
  party.width, party.height = 210, 42
  if player.castbar then player.castbar.width = 300 end
  if target.castbar then target.castbar.width = 300 end
  profile.chat = profile.chat or {}; profile.chat.panelWidth = 390
  profile.general = profile.general or {}; profile.general.minimap = profile.general.minimap or {}; profile.general.minimap.size = 220
  profile.actionbar = profile.actionbar or {}
  if profile.actionbar.bar1 then profile.actionbar.bar1.buttonsize = 32 end
  if profile.actionbar.bar2 then profile.actionbar.bar2.buttonsize = 28 end
  return profile
end

local function DecodeProfile(payload)
  if type(payload) ~= "string" or payload == "" then return nil end
  local E = Engine()
  if not E or type(E.GetModule) ~= "function" then return nil end
  local okModule, D = pcall(E.GetModule, E, "Distributor", true)
  if not okModule or type(D) ~= "table" or type(D.Decode) ~= "function" then return nil end
  local ok, profileType, _, data = pcall(D.Decode, D, payload)
  if not ok or profileType ~= "profile" or type(data) ~= "table" then return nil end
  return Copy(data)
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
  ElvDB.profileKeys[E.mynameRealm] = profileName

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
  RestoreScale(scale)

  if type(self.DisableElvUINamePlates) == "function" then pcall(self.DisableElvUINamePlates, self) end
  if type(E.StaggeredUpdateAll) == "function" then pcall(E.StaggeredUpdateAll, E)
  elseif type(E.UpdateAll) == "function" then pcall(E.UpdateAll, E, true) end

  local active = ElvDB.profileKeys and ElvDB.profileKeys[E.mynameRealm]
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

function RUI:InstallRetreatStyleElvUI(styleKey, resolution)
  local style = self.ProfileStyles and self.ProfileStyles[styleKey]
  if not style then return false, "Unknown profile style" end
  if not self:EnsureAddOnLoaded("ElvUI") then return false, "ElvUI is not loaded" end

  local profileName = style.elvProfileName or (styleKey == "focus" and "Retreat Focus" or "Retreat Edge")
  local payloads = self.ProfileImportPayloads and self.ProfileImportPayloads[styleKey]
  local payload = payloads and payloads.elvui and payloads.elvui[resolution or self:GetRetreatStyleResolution()]
  local profile = payload and DecodeProfile(payload.profile)
  local mode = "reference"

  if type(profile) ~= "table" then
    mode = "CoA compatibility"
    profile = styleKey == "edge" and EdgeFallback(FOCUS_BASELINE) or Copy(FOCUS_BASELINE)
  end

  local ok, reason = InstallProfileTable(self, profileName, profile)
  if not ok then return false, reason end

  self.ElvUIProfile = Copy(profile)
  local state = self:EnsureDB(); state.profileStyle = state.profileStyle or {}
  state.profileStyle.key = styleKey
  state.profileStyle.elvProfileName = profileName
  state.profileStyle.elvMode = mode
  state.profileStyle.version = self.version

  return true, style.label .. " activated as ElvUI profile '" .. profileName .. "' (" .. mode .. ")"
end

RUI._profileSwitchFix = true
RUI.profileSwitchFixSchema = 2

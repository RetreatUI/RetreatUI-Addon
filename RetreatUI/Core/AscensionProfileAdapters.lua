local RUI = RetreatUI
if not RUI then return end

local AUDITED = {
  WeakAuras = "5.21.2",
  ElvUI = "7.27",
  Details = "#Details.20240508.12893.160",
  TurboPlates = "1.4.5",
  DBM = "5.21",
}

local function AddOnVersion(name)
  if type(GetAddOnMetadata) ~= "function" then return nil end
  local ok, value = pcall(GetAddOnMetadata, name, "Version")
  if ok and value and value ~= "" then return tostring(value) end
  return nil
end

local function IsLoaded(name)
  return type(IsAddOnLoaded) == "function" and IsAddOnLoaded(name) == true
end

local function DataCopy(value, seen, depth)
  depth = (depth or 0) + 1
  if depth > 32 then return nil, "profile data is nested too deeply" end

  local kind = type(value)
  if kind == "nil" or kind == "string" or kind == "number" or kind == "boolean" then
    return value
  end
  if kind ~= "table" then
    return nil, "profile data contains unsupported value type: " .. kind
  end

  seen = seen or {}
  if seen[value] then return nil, "profile data contains a cyclic table" end
  seen[value] = true

  local result = {}
  for key, child in pairs(value) do
    local keyType = type(key)
    if keyType ~= "string" and keyType ~= "number" then
      seen[value] = nil
      return nil, "profile data contains an unsupported key type: " .. keyType
    end
    local copied, reason = DataCopy(child, seen, depth)
    if reason then
      seen[value] = nil
      return nil, reason
    end
    result[key] = copied
  end

  seen[value] = nil
  return result
end

local function EnsureLoaded(self, addon)
  if IsLoaded(addon) then return true end
  if type(self.EnsureAddOnLoaded) == "function" then
    local ok = self:EnsureAddOnLoaded(addon)
    if ok then return true end
  end
  return IsLoaded(addon)
end

local function ElvDistributor(self)
  if not EnsureLoaded(self, "ElvUI") or type(_G.ElvUI) ~= "table" then
    return nil, "ElvUI is not loaded"
  end
  local ok, E = pcall(unpack, _G.ElvUI)
  if not ok or type(E) ~= "table" or type(E.GetModule) ~= "function" then
    return nil, "ElvUI core object is unavailable"
  end
  local moduleOK, D = pcall(E.GetModule, E, "Distributor", true)
  if not moduleOK or type(D) ~= "table" then
    return nil, "ElvUI Distributor module is unavailable"
  end
  return D, nil, E
end

local function DetailsObject(self)
  if not EnsureLoaded(self, "Details") then return nil, "Details is not loaded" end
  local details = _G.Details or _G._detalhes
  if type(details) ~= "table" then return nil, "Details core object is unavailable" end
  return details
end

local function RuntimeDBMVersion()
  if type(_G.DBM) == "table" then
    if _G.DBM.DisplayVersion then return tostring(_G.DBM.DisplayVersion) end
    if _G.DBM.Version then return tostring(_G.DBM.Version) end
  end
  return AddOnVersion("DBM-Core")
end

function RUI:GetAscensionAddonCompatibility()
  local result = {}

  do
    local wa = _G.WeakAuras
    result.WeakAuras = {
      audited = AUDITED.WeakAuras,
      installed = AddOnVersion("WeakAuras"),
      loaded = IsLoaded("WeakAuras"),
      import = type(wa) == "table" and type(wa.Import) == "function",
      getData = type(wa) == "table" and type(wa.GetData) == "function",
      internalVersion = type(wa) == "table" and type(wa.InternalVersion) == "function",
      newAura = type(wa) == "table" and type(wa.NewAura) == "function",
    }
  end

  do
    local D = ElvDistributor(self)
    result.ElvUI = {
      audited = AUDITED.ElvUI,
      installed = AddOnVersion("ElvUI"),
      loaded = IsLoaded("ElvUI"),
      nativeExport = type(D) == "table" and type(D.ExportProfile) == "function",
      nativeImport = type(D) == "table" and type(D.ImportProfile) == "function",
    }
  end

  do
    local details = DetailsObject(self)
    result.Details = {
      audited = AUDITED.Details,
      installed = AddOnVersion("Details"),
      loaded = IsLoaded("Details"),
      nativeExport = type(details) == "table" and type(details.ExportCurrentProfile) == "function",
      nativeImport = type(details) == "table" and type(details.ImportProfile) == "function",
      apply = type(details) == "table" and type(details.ApplyProfile) == "function",
    }
  end

  result.TurboPlates = {
    audited = AUDITED.TurboPlates,
    installed = AddOnVersion("TurboPlates"),
    loaded = IsLoaded("TurboPlates"),
    savedVariables = type(_G.TurboPlatesDB) == "table",
    nativeExternalAPI = false,
  }

  result.DBM = {
    audited = AUDITED.DBM,
    installed = RuntimeDBMVersion(),
    loaded = IsLoaded("DBM-Core"),
    coreOptions = type(_G.DBM_SavedOptions) == "table",
    barOptions = type(_G.DBT_SavedOptions) == "table",
  }

  return result
end

function RUI:PrintAscensionAddonCompatibility()
  local status = self:GetAscensionAddonCompatibility()
  local function yes(value) return value and "yes" or "no" end

  local wa = status.WeakAuras
  self:Print("WeakAuras " .. tostring(wa.installed or "missing") .. " (audited " .. AUDITED.WeakAuras .. ") | Import " .. yes(wa.import) .. " | GetData " .. yes(wa.getData))

  local elv = status.ElvUI
  self:Print("ElvUI " .. tostring(elv.installed or "missing") .. " (audited " .. AUDITED.ElvUI .. ") | native export " .. yes(elv.nativeExport) .. " | native import " .. yes(elv.nativeImport))

  local details = status.Details
  self:Print("Details " .. tostring(details.installed or "missing") .. " | native export " .. yes(details.nativeExport) .. " | native import " .. yes(details.nativeImport) .. " | apply " .. yes(details.apply))

  local tp = status.TurboPlates
  self:Print("TurboPlates " .. tostring(tp.installed or "missing") .. " (audited " .. AUDITED.TurboPlates .. ") | TurboPlatesDB " .. yes(tp.savedVariables) .. " | public native API no")

  local dbm = status.DBM
  self:Print("DBM " .. tostring(dbm.installed or "missing") .. " (audited " .. AUDITED.DBM .. ") | DBM_SavedOptions " .. yes(dbm.coreOptions) .. " | DBT_SavedOptions " .. yes(dbm.barOptions))

  return status
end

function RUI:CaptureElvUINativeProfile()
  local D, reason = ElvDistributor(self)
  if not D then return nil, reason end
  if type(D.ExportProfile) ~= "function" then return nil, "ElvUI Distributor does not expose ExportProfile" end

  local ok, profileKey, payload = pcall(D.ExportProfile, D, "profile", "text")
  if not ok then return nil, "ElvUI native export failed: " .. tostring(profileKey) end
  if type(payload) ~= "string" or payload:sub(1, 4) ~= "!E1!" then
    return nil, "ElvUI native export did not return an !E1! profile"
  end

  return {
    format = "ElvUI-native-text-v1",
    addonVersion = AddOnVersion("ElvUI"),
    profileKey = profileKey,
    payload = payload,
  }
end

function RUI:ImportElvUINativeProfile(profile)
  if InCombatLockdown and InCombatLockdown() then return false, "leave combat before importing ElvUI" end
  local D, reason = ElvDistributor(self)
  if not D then return false, reason end
  if type(D.ImportProfile) ~= "function" then return false, "ElvUI Distributor does not expose ImportProfile" end

  local payload = type(profile) == "table" and profile.payload or profile
  if type(payload) ~= "string" or payload:sub(1, 4) ~= "!E1!" then
    return false, "invalid ElvUI native profile payload"
  end

  local ok, accepted = pcall(D.ImportProfile, D, payload)
  if not ok then return false, "ElvUI native import failed: " .. tostring(accepted) end
  if accepted ~= true then return false, "ElvUI native importer rejected the profile" end
  return true, "ElvUI native importer accepted the profile"
end

function RUI:CaptureDetailsNativeProfile()
  local details, reason = DetailsObject(self)
  if not details then return nil, reason end
  if type(details.ExportCurrentProfile) ~= "function" then return nil, "Details does not expose ExportCurrentProfile" end

  local ok, payload = pcall(details.ExportCurrentProfile, details)
  if not ok then return nil, "Details native export failed: " .. tostring(payload) end
  if type(payload) ~= "string" or payload == "" then return nil, "Details native export returned no data" end

  local profileName
  if type(details.GetCurrentProfileName) == "function" then
    local nameOK, value = pcall(details.GetCurrentProfileName, details)
    if nameOK then profileName = value end
  end

  return {
    format = "Details-native-print-v1",
    addonVersion = AddOnVersion("Details"),
    profileName = profileName,
    payload = payload,
  }
end

function RUI:ImportDetailsNativeProfile(profile, profileName)
  if InCombatLockdown and InCombatLockdown() then return false, "leave combat before importing Details" end
  local details, reason = DetailsObject(self)
  if not details then return false, reason end
  if type(details.ImportProfile) ~= "function" then return false, "Details does not expose ImportProfile" end

  local payload = type(profile) == "table" and profile.payload or profile
  profileName = profileName or (type(profile) == "table" and profile.profileName) or "RetreatUI"
  if type(payload) ~= "string" or payload == "" then return false, "invalid Details native profile payload" end
  if type(profileName) ~= "string" or #profileName < 2 then profileName = "RetreatUI" end

  -- Auto-run code remains disabled. This is deliberate even for trusted local profiles.
  local ok, imported, importReason = pcall(details.ImportProfile, details, payload, profileName, false, false, true)
  if not ok then return false, "Details native import failed: " .. tostring(imported) end
  if imported == false then return false, tostring(importReason or "Details rejected the profile") end

  if type(details.GetProfile) == "function" then
    local verifyOK, stored = pcall(details.GetProfile, details, profileName, false)
    if not verifyOK or type(stored) ~= "table" then return false, "Details import did not create the requested profile" end
  end

  if type(details.ApplyProfile) == "function" then
    local applyOK, applied = pcall(details.ApplyProfile, details, profileName, true)
    if not applyOK or applied == false then return false, "Details imported but could not activate the profile" end
  end

  return true, "Details native profile imported and activated"
end

function RUI:CaptureTurboPlatesProfileData()
  if not EnsureLoaded(self, "TurboPlates") then return nil, "TurboPlates is not loaded" end
  if type(_G.TurboPlatesDB) ~= "table" then return nil, "TurboPlatesDB is unavailable" end

  local copy, reason = DataCopy(_G.TurboPlatesDB)
  if not copy then return nil, reason end
  return {
    format = "TurboPlatesDB-data-v1",
    addonVersion = AddOnVersion("TurboPlates"),
    data = copy,
  }
end

function RUI:ApplyTurboPlatesProfileData(profile)
  if type(profile) ~= "table" or profile.format ~= "TurboPlatesDB-data-v1" or type(profile.data) ~= "table" then
    return false, "invalid TurboPlates profile data"
  end
  local installedVersion = AddOnVersion("TurboPlates")
  if not installedVersion or tostring(profile.addonVersion or "") ~= tostring(installedVersion) then
    return false, "TurboPlates profile version does not match the installed addon"
  end
  if installedVersion ~= AUDITED.TurboPlates then
    return false, "TurboPlates version has not been audited for automatic profile application"
  end

  local nextData, reason = DataCopy(profile.data)
  if not nextData then return false, reason end

  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.profileAdapterBackups = RetreatUIDB.profileAdapterBackups or {}
  if type(_G.TurboPlatesDB) == "table" then
    local backup = DataCopy(_G.TurboPlatesDB)
    if backup then RetreatUIDB.profileAdapterBackups.turboPlates = backup end
  end

  _G.TurboPlatesDB = nextData
  return true, "TurboPlates profile applied; reload the UI to rebuild nameplates"
end

function RUI:CaptureDBMCoreProfileData()
  if not EnsureLoaded(self, "DBM-Core") then return nil, "DBM-Core is not loaded" end
  local options, reason = DataCopy(_G.DBM_SavedOptions or {})
  if not options then return nil, reason end
  local bars, barReason = DataCopy(_G.DBT_SavedOptions or {})
  if not bars then return nil, barReason end

  return {
    format = "DBM-Ascension-core-v1",
    addonVersion = RuntimeDBMVersion(),
    options = options,
    bars = bars,
  }
end

function RUI:ApplyDBMCoreProfileData(profile)
  if type(profile) ~= "table" or profile.format ~= "DBM-Ascension-core-v1" then
    return false, "invalid DBM profile data"
  end
  local installedVersion = RuntimeDBMVersion()
  if tostring(installedVersion or "") ~= tostring(profile.addonVersion or "") then
    return false, "DBM profile version does not match the installed DBM build"
  end
  if tostring(installedVersion or "") ~= AUDITED.DBM then
    return false, "DBM version has not been audited for automatic profile application"
  end

  local options, reason = DataCopy(profile.options or {})
  if not options then return false, reason end
  local bars, barReason = DataCopy(profile.bars or {})
  if not bars then return false, barReason end

  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.profileAdapterBackups = RetreatUIDB.profileAdapterBackups or {}
  local oldOptions = DataCopy(_G.DBM_SavedOptions or {})
  local oldBars = DataCopy(_G.DBT_SavedOptions or {})
  RetreatUIDB.profileAdapterBackups.dbm = {options = oldOptions or {}, bars = oldBars or {}}

  _G.DBM_SavedOptions = options
  _G.DBT_SavedOptions = bars
  return true, "DBM core profile applied; reload the UI before using DBM"
end

function RUI:BuildWeakAurasNativeImportEnvelope(root, children)
  if type(root) ~= "table" or type(root.id) ~= "string" or root.id == "" or type(root.regionType) ~= "string" then
    return nil, "invalid WeakAuras root display"
  end
  if children ~= nil and type(children) ~= "table" then return nil, "invalid WeakAuras children list" end

  local rootCopy, reason = DataCopy(root)
  if not rootCopy then return nil, reason end
  local childrenCopy = {}
  for index, child in ipairs(children or {}) do
    if type(child) ~= "table" or type(child.id) ~= "string" or child.id == "" then
      return nil, "invalid WeakAuras child at index " .. tostring(index)
    end
    local copy, childReason = DataCopy(child)
    if not copy then return nil, childReason end
    childrenCopy[#childrenCopy + 1] = copy
  end

  return {
    d = rootCopy,
    c = childrenCopy,
    v = 2000,
  }
end

function RUI:OpenWeakAurasNativeImport(envelope)
  if InCombatLockdown and InCombatLockdown() then return false, "leave combat before importing WeakAuras" end
  if not EnsureLoaded(self, "WeakAuras") then return false, "WeakAuras is not loaded" end
  local wa = _G.WeakAuras
  if type(wa) ~= "table" or type(wa.Import) ~= "function" then return false, "WeakAuras.Import is unavailable" end
  if type(envelope) ~= "table" or type(envelope.d) ~= "table" or type(envelope.v) ~= "number" then
    return false, "invalid WeakAuras import envelope"
  end

  local ok, result, reason = pcall(wa.Import, envelope)
  if not ok then return false, "WeakAuras native import failed: " .. tostring(result) end
  if result == false then return false, tostring(reason or "WeakAuras rejected the import") end
  return true, "WeakAuras native import/update window opened"
end

function RUI:CaptureUnifiedProfileSnapshot(profileName)
  local snapshot = {
    schema = 1,
    name = type(profileName) == "string" and profileName or "RetreatUI",
    createdAt = date and date("%Y-%m-%d %H:%M:%S") or nil,
    className = self.GetDetectedClass and self:GetDetectedClass() or nil,
    components = {},
  }

  if type(self.GetTrackerProfileData) == "function" then
    snapshot.components.trackers = self:GetTrackerProfileData(snapshot.className)
  end

  local elv = self:CaptureElvUINativeProfile()
  if elv then snapshot.components.elvui = elv end
  local details = self:CaptureDetailsNativeProfile()
  if details then snapshot.components.details = details end
  local tp = self:CaptureTurboPlatesProfileData()
  if tp then snapshot.components.turboPlates = tp end
  local dbm = self:CaptureDBMCoreProfileData()
  if dbm then snapshot.components.dbm = dbm end

  snapshot.components.weakAuras = {
    mode = "tracker-builder-native-import",
    addonVersion = AddOnVersion("WeakAuras"),
  }

  local clean, reason = DataCopy(snapshot)
  if not clean then return nil, reason end
  return clean
end

RUI.ascensionProfileAdapterSchema = 1
RUI.ascensionAuditedAddonVersions = AUDITED

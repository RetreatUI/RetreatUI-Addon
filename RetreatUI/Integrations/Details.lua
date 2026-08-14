local RUI = RetreatUI
if not RUI then return end

local function DetailsObject()
  local details = _G.Details or _G._detalhes
  return type(details) == "table" and details or nil
end

function RUI:ApplyDetailsFont()
  local details = DetailsObject()
  if not details then return false, "Details is not loaded" end
  local changed = 0
  local profileName = self.DetailsProfileName or "RetreatUI"

  if type(details.GetProfile) == "function" then
    local ok, profile = pcall(details.GetProfile, details, profileName)
    if ok and type(profile) == "table" then changed = changed + self:ForceFontFields(profile) end
  end
  if type(_detalhes_global) == "table" then changed = changed + self:ForceFontFields(_detalhes_global) end
  if type(details.GetInstance) == "function" then
    for index = 1, 20 do
      local ok, instance = pcall(details.GetInstance, details, index)
      if ok and type(instance) == "table" then
        instance.row_info = instance.row_info or {}
        instance.row_info.font_face = self.fontName
        instance.window_info = instance.window_info or {}
        instance.window_info.font_face = self.fontName
        changed = changed + 2
      end
    end
  end
  if type(details.RefreshMainWindow) == "function" then pcall(details.RefreshMainWindow, details, -1, true) end
  return true, "RetreatUI font applied to Details"
end

local PROFILE_PREFIX = "D!ProfileV2-"

local function RawProfilePayload(payload)
  if type(payload) ~= "string" then return nil end
  if payload:sub(1, #PROFILE_PREFIX) == PROFILE_PREFIX then
    return payload:sub(#PROFILE_PREFIX + 1)
  end
  return payload
end

local function TryNativeImport(details, payload, profileName)
  if type(details.ImportProfile) ~= "function" then return nil, "native importer unavailable" end
  local ok, result = pcall(details.ImportProfile, details, payload, profileName, false, false, true)
  if not ok then return false, tostring(result) end
  if result == false or result == nil then return false, "profile rejected" end
  return true
end

local function ImportProfile(payload, profileName)
  local details = DetailsObject()
  if not details then return false, "Details is not loaded" end

  -- The visible D!ProfileV2- marker is an export envelope. The native profile
  -- importer hands its argument directly to the Details decompressor, which
  -- expects the compressed printable body rather than the envelope prefix.
  local raw = RawProfilePayload(payload)
  if type(raw) ~= "string" or raw == "" then return false, "Bundled Details profile payload is empty" end

  if type(details.ImportProfile) == "function" then
    local ok, reason = TryNativeImport(details, raw, profileName)
    if ok then return true end

    -- Compatibility only for builds that perform envelope handling internally.
    if raw ~= payload then
      local wrappedOK, wrappedReason = TryNativeImport(details, payload, profileName)
      if wrappedOK then return true end
      reason = tostring(reason) .. "; wrapped form: " .. tostring(wrappedReason)
    end
    return false, "Details rejected the bundled profile: " .. tostring(reason)
  end

  local api = _G.DetailsAPI
  if type(api) == "table" and type(api.ImportProfile) == "function" then
    local ok, result, detail = pcall(api.ImportProfile, api, raw, profileName)
    if not ok then ok, result, detail = pcall(api.ImportProfile, raw, profileName) end
    if not ok then return false, "Details profile import error: " .. tostring(result) end
    if result == false or result == nil then return false, tostring(detail or "Details rejected the bundled profile") end
    if type(details.ApplyProfile) == "function" then
      local applied, applyResult = pcall(details.ApplyProfile, details, profileName, true)
      if not applied or applyResult == false then
        return false, "Details profile imported, but activation failed: " .. tostring(applyResult)
      end
    end
    return true
  end

  return false, "The installed Details build does not expose a profile importer"
end

function RUI:InstallDetailsProfile()
  local loaded = self:EnsureAddOnLoaded("Details")
  if not loaded then return false, "Details is not installed or could not be loaded" end
  local details = DetailsObject()
  if not details then return false, "Details did not initialize" end
  if type(self.DetailsProfileString) ~= "string" or self.DetailsProfileString == "" then
    return false, "Bundled Details profile is missing"
  end
  if self.DetailsProfileFormat ~= "D!ProfileV2" and self.DetailsProfileString:sub(1, #PROFILE_PREFIX) ~= PROFILE_PREFIX then
    return false, "Bundled Details profile is not D!ProfileV2"
  end

  local profileName = self.DetailsProfileName or "RetreatUI"
  local ok, message = ImportProfile(self.DetailsProfileString, profileName)
  if not ok then return false, message end

  self:ApplyDetailsFont()
  local db = self:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.details = {
    version = self.version,
    profile = profileName,
    imported = true,
    format = "D!ProfileV2",
  }
  return true, "RetreatUI Details profile imported and activated"
end

function RUI:ValidateDetailsProfile()
  local loaded = self:EnsureAddOnLoaded("Details")
  if not loaded then return false, "Details is required but could not be loaded" end
  local details = DetailsObject()
  if not details then return false, "Details did not initialize" end
  local hasImporter = type(details.ImportProfile) == "function"
  if not hasImporter then
    local api = _G.DetailsAPI
    hasImporter = type(api) == "table" and type(api.ImportProfile) == "function"
  end
  if not hasImporter then return false, "The installed Details build does not expose a profile importer" end

  local db = self:EnsureDB()
  local marker = db.integrations and db.integrations.details
  if type(marker) ~= "table" or marker.version ~= self.version or marker.imported ~= true or marker.format ~= "D!ProfileV2" then
    return false, "The RetreatUI Details profile was not imported"
  end
  return true
end

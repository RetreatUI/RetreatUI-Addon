local RUI = RetreatUI

function RUI:ApplyDetailsFont()
  local details = _G.Details or _G._detalhes
  if type(details) ~= "table" then return false, "Details is not loaded" end
  local changed = 0
  local profileName = self.DetailsProfileName or "RetreatUI"

  if type(details.GetProfile) == "function" then
    local ok, profile = pcall(details.GetProfile, details, profileName)
    if ok and type(profile) == "table" then changed = changed + self:ForceFontFields(profile) end
  end

  if type(_detalhes_global) == "table" then
    changed = changed + self:ForceFontFields(_detalhes_global)
  end

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

local function ImportV2Profile(payload, profileName)
  local api = _G.DetailsAPI
  if type(api) ~= "table" then
    return false, "This Details build does not expose the V2 profile API required by the bundled profile."
  end
  if type(api.ImportProfile) ~= "function" then
    return false, "DetailsAPI.ImportProfile is unavailable in this Details build."
  end

  local ok, result, detail = pcall(api.ImportProfile, api, payload, profileName)
  if not ok then
    -- Some Details builds expose the API as plain functions rather than methods.
    ok, result, detail = pcall(api.ImportProfile, payload, profileName)
  end
  if not ok then return false, "Details V2 import error: " .. tostring(result) end
  if result == false then return false, tostring(detail or "Details rejected the V2 profile") end

  if type(api.SetProfile) == "function" then
    local setOK, setResult = pcall(api.SetProfile, api, profileName)
    if not setOK then setOK, setResult = pcall(api.SetProfile, profileName) end
    if not setOK or setResult == false then
      return false, "Details profile imported, but activation failed: " .. tostring(setResult)
    end
  end
  return true
end

local function ImportLegacyProfile(details, payload, profileName)
  if type(details.ImportProfile) ~= "function" then
    return false, "Details legacy profile API is unavailable"
  end
  local ok, imported, importError = pcall(details.ImportProfile, details, payload, profileName, false, false, true)
  if not ok then return false, "Details import error: " .. tostring(imported) end
  if imported == false then return false, tostring(importError or "Details rejected the profile") end

  if type(details.ApplyProfile) == "function" then
    local applyOK, applyResult = pcall(details.ApplyProfile, details, profileName)
    if not applyOK or applyResult == false then
      return false, "Profile imported, but activation failed: " .. tostring(applyResult)
    end
  end
  return true
end

function RUI:InstallDetailsProfile()
  local loaded = self:EnsureAddOnLoaded("Details")
  if not loaded then return false, "Details is not installed or could not be loaded" end

  local details = _G.Details or _G._detalhes
  if type(details) ~= "table" then return false, "Details profile API is unavailable" end
  if type(self.DetailsProfileString) ~= "string" or self.DetailsProfileString == "" then
    return false, "Bundled Details profile is missing"
  end

  local profileName = self.DetailsProfileName or "RetreatUI"
  local isV2 = self.DetailsProfileFormat == "D!ProfileV2" or self.DetailsProfileString:sub(1, 12) == "D!ProfileV2-"

  local ok, message
  if isV2 then
    -- Never feed a D!ProfileV2 payload into Details:ImportProfile(). The legacy
    -- importer attempts its old decompress/deserialize path and produces the
    -- "couldn't decode / failed to decompress" failure seen in CoA.
    ok, message = ImportV2Profile(self.DetailsProfileString, profileName)
  else
    ok, message = ImportLegacyProfile(details, self.DetailsProfileString, profileName)
  end
  if not ok then return false, message end

  self:ApplyDetailsFont()
  local db = self:EnsureDB()
  db.integrations.details = {
    version = self.version,
    profile = profileName,
    imported = true,
    format = isV2 and "D!ProfileV2" or "legacy",
  }
  return true, "RetreatUI Details profile imported"
end

function RUI:ValidateDetailsProfile()
  local loaded = self:EnsureAddOnLoaded("Details")
  if not loaded then return false, "Details! is required but could not be loaded" end

  local details = _G.Details or _G._detalhes
  if type(details) ~= "table" then return false, "Details! did not initialize" end

  if self.DetailsProfileFormat == "D!ProfileV2" then
    local api = _G.DetailsAPI
    if type(api) ~= "table" or type(api.ImportProfile) ~= "function" then
      return false, "The installed Details build does not support the bundled V2 profile format"
    end
  end

  local db = self:EnsureDB()
  local marker = db.integrations and db.integrations.details
  if type(marker) ~= "table" or marker.version ~= self.version or marker.imported ~= true then
    return false, "The RetreatUI Details profile was not imported"
  end

  return true
end
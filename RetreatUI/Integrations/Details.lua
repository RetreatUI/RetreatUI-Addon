local RUI = RetreatUI
if not RUI then return end

local function DetailsObject()
  local details = _G.Details or _G._detalhes
  return type(details) == "table" and details or nil
end

local function ProfileExists(details, profileName)
  if type(details.GetProfile) == "function" then
    local ok, profile = pcall(details.GetProfile, details, profileName, false)
    if ok and type(profile) == "table" then return true end
  end
  if type(_G._detalhes_global) == "table"
    and type(_G._detalhes_global.__profiles) == "table"
    and type(_G._detalhes_global.__profiles[profileName]) == "table" then
    return true
  end
  return false
end

local function ApplyImportedProfile(details, profileName)
  if type(details.ApplyProfile) ~= "function" then return true end
  local ok, result = pcall(details.ApplyProfile, details, profileName, true)
  if not ok then return false, tostring(result) end
  if result == false then return false, "Details refused to activate the imported profile" end
  return true
end

local function ImportProfile(payload, profileName)
  local details = DetailsObject()
  if not details then return false, "Details is not loaded" end
  if type(details.ImportProfile) ~= "function" then
    return false, "The installed Details build does not expose ImportProfile"
  end
  if type(payload) ~= "string" or payload == "" then
    return false, "Bundled Details profile payload is empty"
  end

  -- Use the exact same contract as the working RetreatUI-TBC installer:
  -- pass the complete D!ProfileV2 transmission to Details:ImportProfile.
  -- Some Classic/CoA builds return nil even after a successful side-effect,
  -- so only an explicit false means rejection. We then verify the profile
  -- actually exists and activate it before reporting success.
  local ok, imported, importError = pcall(
    details.ImportProfile,
    details,
    payload,
    profileName,
    false,
    false,
    true
  )

  if not ok then return false, "Details import error: " .. tostring(imported) end
  if imported == false then
    return false, tostring(importError or "Details rejected the bundled profile")
  end
  if not ProfileExists(details, profileName) then
    return false, "Details import returned without creating the RetreatUI profile"
  end

  local applied, applyError = ApplyImportedProfile(details, profileName)
  if not applied then return false, applyError end
  return true
end

function RUI:InstallDetailsProfile()
  local loaded = self:EnsureAddOnLoaded("Details")
  if not loaded then return false, "Details is not installed or could not be loaded" end
  local details = DetailsObject()
  if not details then return false, "Details did not initialize" end
  if type(self.DetailsProfileString) ~= "string" or self.DetailsProfileString == "" then
    return false, "Bundled Details profile is missing"
  end
  if self.DetailsProfileFormat ~= "D!ProfileV2" and self.DetailsProfileString:sub(1, 11) ~= "D!ProfileV2-" then
    return false, "Bundled Details profile is not D!ProfileV2"
  end

  local profileName = self.DetailsProfileName or "RetreatUI"
  local ok, message = ImportProfile(self.DetailsProfileString, profileName)
  if not ok then return false, message end

  local db = self:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.details = {
    version = self.version,
    profile = profileName,
    imported = true,
    format = "D!ProfileV2",
  }
  return true, "RetreatUI Details profile imported, verified and activated"
end

function RUI:ValidateDetailsProfile()
  local loaded = self:EnsureAddOnLoaded("Details")
  if not loaded then return false, "Details is required but could not be loaded" end
  local details = DetailsObject()
  if not details then return false, "Details did not initialize" end
  if type(details.ImportProfile) ~= "function" then
    return false, "The installed Details build does not expose ImportProfile"
  end

  local profileName = self.DetailsProfileName or "RetreatUI"
  if not ProfileExists(details, profileName) then
    return false, "The RetreatUI Details profile does not exist"
  end

  local db = self:EnsureDB()
  local marker = db.integrations and db.integrations.details
  if type(marker) ~= "table" or marker.version ~= self.version or marker.imported ~= true or marker.format ~= "D!ProfileV2" then
    return false, "The RetreatUI Details profile was not installed by this version"
  end
  return true
end

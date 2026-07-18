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
  return true, "Fira Sans Heavy applied to Details"
end

function RUI:InstallDetailsProfile()
  local loaded = self:EnsureAddOnLoaded("Details")
  if not loaded then return false, "Details is not installed or could not be loaded" end

  local details = _G.Details or _G._detalhes
  if type(details) ~= "table" or type(details.ImportProfile) ~= "function" then
    return false, "Details profile API is unavailable"
  end
  if type(self.DetailsProfileString) ~= "string" or self.DetailsProfileString == "" then
    return false, "Bundled Details profile is missing"
  end

  local profileName = self.DetailsProfileName or "RetreatUI"
  local ok, imported, importError = pcall(details.ImportProfile, details, self.DetailsProfileString, profileName, false, false, true)
  if not ok then return false, "Details import error: " .. tostring(imported) end
  if imported == false then return false, tostring(importError or "Details rejected the profile") end

  if type(details.ApplyProfile) == "function" then
    local applyOK, applyResult = pcall(details.ApplyProfile, details, profileName)
    if not applyOK or applyResult == false then
      return false, "Profile imported, but activation failed: " .. tostring(applyResult)
    end
  end

  self:ApplyDetailsFont()
  local db = self:EnsureDB()
  db.integrations.details = {
    version = self.version,
    profile = profileName,
    imported = true,
  }
  return true, "RetreatUI Details profile imported with Fira Sans Heavy"
end

function RUI:ValidateDetailsProfile()
  local loaded = self:EnsureAddOnLoaded("Details")
  if not loaded then return false, "Details! is required but could not be loaded" end

  local details = _G.Details or _G._detalhes
  if type(details) ~= "table" then return false, "Details! did not initialize" end

  local db = self:EnsureDB()
  local marker = db.integrations and db.integrations.details
  if type(marker) ~= "table" or marker.version ~= self.version or marker.imported ~= true then
    return false, "The RetreatUI Details profile was not imported"
  end

  return true
end

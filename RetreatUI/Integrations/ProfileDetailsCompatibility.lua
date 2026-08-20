local RUI = RetreatUI
if not RUI then return end

-- The two source UI packages ship Details profile transmissions from a different
-- runtime lineage than Project Ascension's audited Details build. Calling the
-- reference payload importer directly causes visible decode/decompress errors.
-- beta.46 therefore keeps Details on RetreatUI's CoA-compatible installer path.
function RUI:InstallRetreatStyleDetails(styleKey, resolution)
  if not self.ProfileStyles or not self.ProfileStyles[styleKey] then
    return false, "Unknown profile style"
  end
  if not self.EnsureAddOnLoaded or not self:EnsureAddOnLoaded("Details") then
    return false, "Details is not installed or could not be loaded"
  end
  if type(self.InstallDetailsProfile) ~= "function" then
    return false, "RetreatUI Details compatibility profile is unavailable"
  end

  local ok, message = self:InstallDetailsProfile()
  if not ok then return false, message end

  local db = self:EnsureDB()
  db.profileStyle = db.profileStyle or {}
  db.profileStyle.detailsStyle = styleKey
  db.profileStyle.detailsResolution = resolution or (self.GetRetreatStyleResolution and self:GetRetreatStyleResolution())
  db.profileStyle.detailsCompatibility = true
  return true, self.ProfileStyles[styleKey].label .. " Details profile applied (CoA compatibility mode)"
end

RUI._profileDetailsCompatibilityLoaded = true

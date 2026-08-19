local RUI = RetreatUI
if not RUI then return end

-- The Tracker Builder replaces RetreatUI's old bundled per-class WeakAura packs.
-- Keep the installer-facing methods available so legacy installer pages fail safe
-- instead of calling the old direct WeakAuras.Add path.

function RUI:ValidateCoAWeakAurasImportAPI()
  if not self.EnsureAddOnLoaded or not self:EnsureAddOnLoaded("WeakAuras") then
    return false, "WeakAuras is not installed or could not be loaded"
  end
  local wa = _G.WeakAuras
  if type(wa) ~= "table" or type(wa.Import) ~= "function" then
    return false, "The audited Ascension WeakAuras native Import API is unavailable"
  end
  return true, "WeakAuras native import API is ready for Tracker Builder profiles"
end

function RUI:InstallGeneralWeakAuras()
  return true, "Bundled WeakAura packs are retired. Use /rui tracker to build the trackers you want."
end

function RUI:InstallClassWeakAuras(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass()) or "this class"
  return true, "No bundled " .. tostring(className) .. " WeakAura pack is installed. Use /rui tracker to choose abilities and build your own HUD."
end

RUI._trackerBuilderWeakAurasBridge = true

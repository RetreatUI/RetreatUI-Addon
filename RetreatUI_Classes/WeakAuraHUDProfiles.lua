local RUI = RetreatUI
if not RUI then return end

-- Capture the exact class-HUD curation that was already live-tested by the
-- native AdvancedHUD. WeakAuras is now the renderer, but these per-class lists,
-- strict ordering rules and row limits remain authoritative for what belongs in
-- Main and Utility. This avoids maintaining a second spell-selection database.
RUI.weakAuraHUDProfiles = RUI.weakAuraHUDProfiles or {}

local originalRegisterAdvancedClassHUD = RUI.RegisterAdvancedClassHUD
if type(originalRegisterAdvancedClassHUD) == "function" then
  function RUI:RegisterAdvancedClassHUD(className, options)
    options = options or {}
    local normalized = self.NormalizeClassName and self:NormalizeClassName(className) or className
    local copy = {}
    for key, value in pairs(options) do
      if type(value) == "table" then
        local list = {}
        for index, item in ipairs(value) do list[index] = item end
        for nestedKey, nestedValue in pairs(value) do
          if type(nestedKey) ~= "number" then list[nestedKey] = nestedValue end
        end
        copy[key] = list
      else
        copy[key] = value
      end
    end
    self.weakAuraHUDProfiles[normalized or className] = copy

    local module = originalRegisterAdvancedClassHUD(self, className, options)
    if type(module) == "table" then module.weakAuraHUDProfile = copy end
    return module
  end
end

function RUI:GetWeakAuraHUDProfile(className)
  className = self.NormalizeClassName and self:NormalizeClassName(className or self:GetDetectedClass()) or className
  return className and self.weakAuraHUDProfiles[className] or nil
end

RUI._weakAuraHUDProfilesLoaded = true

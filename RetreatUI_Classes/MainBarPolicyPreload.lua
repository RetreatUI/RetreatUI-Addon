local RUI = RetreatUI
if not RUI or type(RUI.RegisterAdvancedClassHUD) ~= "function" then return end
if RUI._mainBarPolicyPreloadInstalled then return end

-- Every learned offensive and defensive cooldown now shares Main Rotation.
-- Raise the advanced-HUD cap before class modules register so no class silently
-- truncates the merged row through an old class-specific maxCore value.
local OriginalRegisterAdvancedClassHUD = RUI.RegisterAdvancedClassHUD
function RUI:RegisterAdvancedClassHUD(className, options)
  options = options or {}
  options.maxCore = 100
  return OriginalRegisterAdvancedClassHUD(self, className, options)
end

RUI._mainBarPolicyPreloadInstalled = true

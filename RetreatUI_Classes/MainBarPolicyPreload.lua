local RUI = RetreatUI
if not RUI or type(RUI.RegisterAdvancedClassHUD) ~= "function" then return end
if RUI._mainBarPolicyPreloadInstalled then return end

-- Main keeps rotation and offensive actions, capped visually at nine icons.
-- Defensives and any Main overflow share Utility, so both source lists must be
-- collected without old class-specific truncation before the final split.
local OriginalRegisterAdvancedClassHUD = RUI.RegisterAdvancedClassHUD
function RUI:RegisterAdvancedClassHUD(className, options)
  options = options or {}
  options.maxCore = 100
  options.maxUtility = 100
  options.mainRowFirstLineMax = 9
  return OriginalRegisterAdvancedClassHUD(self, className, options)
end

RUI._mainBarPolicyPreloadInstalled = true

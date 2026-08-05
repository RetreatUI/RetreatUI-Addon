local RUI = RetreatUI
if not RUI or type(RUI.RegisterAdvancedClassHUD) ~= "function" then return end
if RUI._mainBarPolicyPreloadInstalled then return end

-- Main keeps rotation, resource and every learned offensive action. Defensive
-- and utility actions stay on Utility. Both source lists are collected without
-- old class-specific truncation; Main wraps after nine instead of spilling into
-- Utility.
local OriginalRegisterAdvancedClassHUD = RUI.RegisterAdvancedClassHUD
function RUI:RegisterAdvancedClassHUD(className, options)
  options = options or {}
  options.maxCore = 100
  options.maxUtility = 100
  options.mainRowFirstLineMax = 9
  return OriginalRegisterAdvancedClassHUD(self, className, options)
end

RUI._mainBarPolicyPreloadInstalled = true

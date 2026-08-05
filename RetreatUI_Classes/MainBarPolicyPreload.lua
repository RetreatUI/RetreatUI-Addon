local RUI = RetreatUI
if not RUI or type(RUI.RegisterAdvancedClassHUD) ~= "function" then return end
if RUI._mainBarPolicyPreloadInstalled then return end

-- Final layout rule: rotation/resource/offensive stay on Main; defensive and
-- utility stay on Utility. Main wraps after nine but never spills into Utility.
-- Both lists are collected without old class-specific truncation.
local OriginalRegisterAdvancedClassHUD = RUI.RegisterAdvancedClassHUD
function RUI:RegisterAdvancedClassHUD(className, options)
  options = options or {}
  options.maxCore = 100
  options.maxUtility = 100
  options.mainRowFirstLineMax = 9
  return OriginalRegisterAdvancedClassHUD(self, className, options)
end

RUI._mainBarPolicyPreloadInstalled = true
RUI._offensiveMainDefensiveUtilityPolicy = true

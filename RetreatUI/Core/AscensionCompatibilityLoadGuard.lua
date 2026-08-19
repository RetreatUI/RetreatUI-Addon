local RUI = RetreatUI
if not RUI or type(RUI.GetAscensionAddonCompatibility) ~= "function" then return end

local original = RUI.GetAscensionAddonCompatibility
local AUDITED_ADDONS = {"WeakAuras", "ElvUI", "Details", "TurboPlates", "DBM-Core"}

function RUI:GetAscensionAddonCompatibility()
  if type(self.EnsureAddOnLoaded) == "function" then
    for _, addonName in ipairs(AUDITED_ADDONS) do
      pcall(self.EnsureAddOnLoaded, self, addonName)
    end
  end
  return original(self)
end

RUI._ascensionCompatibilityLoadGuard = true

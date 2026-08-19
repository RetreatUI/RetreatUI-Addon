local RUI = RetreatUI
if not RUI then return end

_G["SLASH_RETREATUIWATEST1"] = "/ruiwatest"
SlashCmdList = SlashCmdList or {}
SlashCmdList["RETREATUIWATEST"] = function()
  if type(RUI.OpenNativeCooldownTrackerTest) ~= "function" then
    RUI:Print("Native WeakAuras tracker test did not finish loading.")
    return
  end
  local ok, message = RUI:OpenNativeCooldownTrackerTest()
  RUI:Print(message or (ok and "WeakAuras native import test opened." or "WeakAuras native import test failed."))
end

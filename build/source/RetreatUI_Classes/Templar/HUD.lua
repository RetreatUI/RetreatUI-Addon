local RUI = RetreatUI

RUI:RegisterAdvancedClassHUD("Templar", {
  frameName = "RetreatUITemplarHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {DISCIPLINE=true,FIGHTING=true,RUNES=true},
  -- Keep the active Oath aligned with the left edge of the Energy bar instead
  -- of overlapping the player health frame.
  stanceTracker = {
    x = -160,
    y = (RUI.layout.demonfire and RUI.layout.demonfire.y) or -118,
    size = 38,
    width = 90,
    height = 58,
  },
})

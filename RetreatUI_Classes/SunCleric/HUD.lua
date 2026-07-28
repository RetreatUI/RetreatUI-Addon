local RUI = RetreatUI

RUI:RegisterAdvancedClassHUD("Sun Cleric", {
  frameName = "RetreatUISunClericHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {BLESSINGS=true,PIETY=true,SERAPHIM=true,VALKYR=true},
  stanceAuraPrefix = "Vow of ",
  stanceTracker = {x=-195, y=-118, size=38, width=100, height=58},
})

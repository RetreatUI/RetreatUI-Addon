local RUI = RetreatUI

RUI:RegisterAdvancedClassHUD("Witch Doctor", {
  frameName = "RetreatUIWitchDoctorHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {BREWING=true,SHADOWHUNTING=true,VOODOO=true},
  maxStates = 1,
  stanceTracker = {x=-195, y=-118, size=38, width=90, height=58, nameSize=8},
})

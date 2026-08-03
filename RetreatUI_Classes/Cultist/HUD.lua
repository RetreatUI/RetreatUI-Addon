local RUI = RetreatUI

RUI:RegisterAdvancedClassHUD("Cultist", {
  frameName = "RetreatUICultistHUD",
  usesPrimaryPower = true,
  maxCore = 24,
  maxUtility = 24,
  supportedLoadouts = {BULWARK=true,CORRUPTION=true,GODBLADE=true,INFLUENCE=true},
})

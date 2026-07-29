local RUI = RetreatUI

RUI:RegisterAdvancedClassHUD("Guardian", {
  frameName = "RetreatUIGuardianHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {GLADIATOR=true,INSPIRATION=true,PROTECTION=true},
})

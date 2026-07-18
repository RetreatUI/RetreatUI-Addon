local RUI = RetreatUI

RUI:RegisterClassDefinition("Knight of Xoroth", {
  ready = true,
  supportedLoadouts = {TANK=true},
  detectionPriority = 10,
  detectionThreshold = 1,
  detectionSpells = {
    "Sever",
    "Shieldgore",
    "Call: Hellfire Imp",
    "Black Shield",
  },
  hudFrameName = "RetreatUIKnightOfXorothHUD",
})

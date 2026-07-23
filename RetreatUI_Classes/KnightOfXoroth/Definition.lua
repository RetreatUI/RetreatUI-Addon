local RUI = RetreatUI

RUI:RegisterClassDefinition("Knight of Xoroth", {
  ready = true,
  releaseStatus = "stable",
  theme = "Fire Explosion",
  accent = {1.00, 0.24, 0.05},
  accent2 = {1.00, 0.72, 0.10},
  background = {0.055, 0.014, 0.006},
  installerTheme = {
    title = "KNIGHT OF XOROTH",
    subtitle = "Xoroth Tank • Hellfire",
    description = "Burn your enemies. Feed the flames. Serve Xoroth.",
    loadout = "Xoroth Tank",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\KnightOfXoroth_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\KnightOfXoroth_Installer.tga",
  },
  primaryResource = "RAGE",
  supportedLoadouts = {TANK=true},
  detectionPriority = 10,
  detectionThreshold = 1,
  detectionSpells = {
    "Sever",
    "Shieldgore",
    "Call: Hellfire Imp",
    "Black Shield",
  },
  tankFramework = {
    buildMechanic="Demonfire",
    combatState={"Pestilence of Famine","Pestilence of War","Pestilence of Conquest"},
    coreMechanic="Demon's Blood",
    taunt="Torment",
    interrupt="Shadowfury",
  },
  hudFrameName = "RetreatUIKnightOfXorothHUD",
})

local definition = RUI:GetClassInfo("Knight of Xoroth")
if definition and definition.tankFramework then
  RUI:RegisterTankProfile("Knight of Xoroth", definition.tankFramework)
end

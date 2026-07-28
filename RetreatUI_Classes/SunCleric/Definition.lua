local RUI = RetreatUI

RUI:RegisterClassDefinition("Sun Cleric", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Healer / Damage",
  theme = "Solar Grace",
  accent = {1.000, 0.720, 0.180},
  accent2 = {1.000, 0.940, 0.580},
  background = {0.056, 0.032, 0.006},
  aliases = {"SunCleric"},
  installerTheme = {
    title = "SUN CLERIC",
    subtitle = "Solar Grace • All Specializations",
    description = "Carry the dawn. Temper mercy with flame. Banish shadow.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\SunCleric_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\SunCleric_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "MANA",
  dynamicPrimaryResource = true,
  supportedLoadouts = {BLESSINGS=true,PIETY=true,SERAPHIM=true,VALKYR=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Dawnbreak","Justicar's Wrath","Glorious Execution"},
  hudFrameName = "RetreatUISunClericHUD",
})

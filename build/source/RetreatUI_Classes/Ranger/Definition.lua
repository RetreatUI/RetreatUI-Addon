local RUI = RetreatUI

RUI:RegisterClassDefinition("Ranger", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Damage",
  theme = "Wild Hunt",
  accent = {0.420, 0.780, 0.200},
  accent2 = {0.700, 0.480, 0.180},
  background = {0.012, 0.036, 0.008},
  installerTheme = {
    title = "RANGER",
    subtitle = "Wild Hunt • All Specializations",
    description = "Read the trail. Control the range. Strike before they react.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Ranger_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Ranger_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "FOCUS",
  dynamicPrimaryResource = true,
  supportedLoadouts = {ARCHERY=true,DUELING=true,SURVIVAL=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Crippling Shot","Incendiary Shot","Woodland Arrow"},
  hudFrameName = "RetreatUIRangerHUD",
})

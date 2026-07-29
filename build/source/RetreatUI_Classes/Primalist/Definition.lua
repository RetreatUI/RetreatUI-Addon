local RUI = RetreatUI

RUI:RegisterClassDefinition("Primalist", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Tank / Damage / Healer",
  theme = "Primal Fury",
  accent = {0.950, 0.480, 0.100},
  accent2 = {0.240, 0.780, 0.220},
  background = {0.042, 0.020, 0.004},
  installerTheme = {
    title = "PRIMALIST",
    subtitle = "Primal Fury • All Specializations",
    description = "Awaken instinct. Harness the wild. Strike with nature.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Primalist_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Primalist_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "RAGE",
  dynamicPrimaryResource = true,
  supportedLoadouts = {GEOMANCY=true,LIFE=true,MOUNTAINKING=true,PRIMAL=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Quake","Rylak's Bite","Totemic Smash"},
  hudFrameName = "RetreatUIPrimalistHUD",
})

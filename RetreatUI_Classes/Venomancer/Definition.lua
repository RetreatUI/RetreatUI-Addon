local RUI = RetreatUI

RUI:RegisterClassDefinition("Venomancer", {
  ready = true,
  releaseStatus = "beta",
  theme = "Poison Jungle",
  accent = {0.28, 0.88, 0.08},
  accent2 = {0.72, 0.20, 0.92},
  background = {0.010, 0.045, 0.018},
  installerTheme = {
    title = "VENOMANCER",
    subtitle = "Fortitude Tank • Poison Jungle",
    description = "Strength grows. Poison flows. The jungle protects.",
    loadout = "Fortitude Tank",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Venomancer_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Venomancer_Installer.tga",
  },
  primaryResource = "RAGE",
  supportedLoadouts = {TANK=true},
  detectionPriority = 20,
  detectionThreshold = 1,
  detectionSpells = {
    "Beetle Form",
    "Exposed Flesh",
    "Chitin Rush",
    "Regrow Exoskeleton",
  },
  hudFrameName = "RetreatUIVenomancerHUD",
})

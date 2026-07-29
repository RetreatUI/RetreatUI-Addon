local RUI = RetreatUI

RUI:RegisterClassDefinition("Starcaller", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Damage / Healer",
  theme = "Astral Convergence",
  accent = {0.340, 0.550, 1.000},
  accent2 = {0.780, 0.520, 1.000},
  background = {0.010, 0.018, 0.060},
  installerTheme = {
    title = "STARCALLER",
    subtitle = "Astral Convergence • All Specializations",
    description = "Call the stars. Shape moonlight. Walk the astral path.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Starcaller_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Starcaller_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "MANA",
  dynamicPrimaryResource = true,
  supportedLoadouts = {ASTRALWARFARE=true,HYDROMANCY=true,MOONBOW=true,TIDES=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Trueshot","Aspect of the Cosmos","Aspect of the Goddess"},
  hudFrameName = "RetreatUIStarcallerHUD",
})

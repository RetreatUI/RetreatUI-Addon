local RUI = RetreatUI

RUI:RegisterClassDefinition("Chronomancer", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Damage / Healer",
  theme = "Timeweaver",
  accent = {0.960, 0.720, 0.120},
  accent2 = {0.200, 0.700, 1.000},
  background = {0.040, 0.026, 0.004},
  installerTheme = {
    title = "CHRONOMANCER",
    subtitle = "Timeweaver • All Specializations",
    description = "Bend the moment. Undo disaster. Choose the winning future.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Chronomancer_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Chronomancer_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "MANA",
  dynamicPrimaryResource = true,
  supportedLoadouts = {DISPLACEMENT=true,DUALITY=true,TIME=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Aeon of Oblivion","Aeon of Protection","Aeon of Renewal"},
  hudFrameName = "RetreatUIChronomancerHUD",
})

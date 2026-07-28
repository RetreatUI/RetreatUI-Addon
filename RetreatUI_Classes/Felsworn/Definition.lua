local RUI = RetreatUI

RUI:RegisterClassDefinition("Felsworn", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Damage / Tank",
  theme = "Fel Dominion",
  accent = {0.300, 0.920, 0.120},
  accent2 = {0.660, 0.160, 0.860},
  background = {0.012, 0.044, 0.004},
  installerTheme = {
    title = "FELSWORN",
    subtitle = "Fel Dominion • All Specializations",
    description = "Master corruption. Weaponize sacrifice. Rule the fel flame.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Felsworn_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Felsworn_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "ENERGY",
  dynamicPrimaryResource = false,
  supportedLoadouts = {DEMONOLOGY=true,FELBLOOD=true,SLAYING=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Chaos Rush","Annihilan Strike","Manaburn","Felbane"},
  hudFrameName = "RetreatUIFelswornHUD",
})

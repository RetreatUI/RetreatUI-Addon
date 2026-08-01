local RUI = RetreatUI

RUI:RegisterClassDefinition("Guardian", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Tank / Healer",
  theme = "Ancient Bulwark",
  accent = {0.280, 0.780, 0.380},
  accent2 = {0.680, 0.520, 0.200},
  background = {0.008, 0.038, 0.020},
  installerTheme = {
    title = "GUARDIAN",
    subtitle = "Ancient Bulwark • All Specializations",
    description = "Stand unbroken. Shelter allies. Answer with ancient might.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Guardian_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Guardian_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "ENERGY",
  dynamicPrimaryResource = true,
  supportedLoadouts = {GLADIATOR=true,INSPIRATION=true,PROTECTION=true,VANGUARD=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Standard of Rallying","Heavy Blow","Centurion Strike"},
  hudFrameName = "RetreatUIGuardianHUD",
})

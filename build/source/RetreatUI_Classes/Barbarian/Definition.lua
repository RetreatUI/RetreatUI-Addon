local RUI = RetreatUI

RUI:RegisterClassDefinition("Barbarian", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Damage / Tank",
  theme = "Unbroken",
  accent = {0.860, 0.240, 0.080},
  accent2 = {0.560, 0.420, 0.180},
  background = {0.046, 0.010, 0.004},
  installerTheme = {
    title = "BARBARIAN",
    subtitle = "Unbroken • All Specializations",
    description = "Raise the axe. Defy restraint. Win through raw momentum.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Barbarian_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Barbarian_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "ENERGY",
  dynamicPrimaryResource = true,
  supportedLoadouts = {ANCESTRY=true,BRUTALITY=true,TACTICS=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Berserker Axe","Killing Spree","Barbed Spear"},
  hudFrameName = "RetreatUIBarbarianHUD",
})

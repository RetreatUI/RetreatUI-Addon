local RUI = RetreatUI

RUI:RegisterClassDefinition("Stormbringer", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Damage / Tank",
  theme = "Tempest",
  accent = {0.180, 0.620, 1.000},
  accent2 = {0.800, 0.920, 1.000},
  background = {0.006, 0.026, 0.052},
  installerTheme = {
    title = "STORMBRINGER",
    subtitle = "Tempest • All Specializations",
    description = "Ride the storm. Command thunder. Break the enemy line.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Stormbringer_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Stormbringer_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "MANA",
  dynamicPrimaryResource = true,
  supportedLoadouts = {GIFTS=true,LIGHTNING=true,WIND=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Gale","Wind Gate","Flurry"},
  hudFrameName = "RetreatUIStormbringerHUD",
})

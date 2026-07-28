local RUI = RetreatUI

RUI:RegisterClassDefinition("Reaper", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Damage",
  theme = "Soul Hunger",
  accent = {0.500, 0.150, 0.700},
  accent2 = {0.120, 0.850, 0.720},
  background = {0.025, 0.004, 0.040},
  installerTheme = {
    title = "REAPER",
    subtitle = "Soul Hunger • All Specializations",
    description = "Harvest weakness. Devour essence. Leave no soul behind.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Reaper_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Reaper_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "RUNIC_POWER",
  dynamicPrimaryResource = true,
  supportedLoadouts = {DOMINATION=true,REAPING=true,SOUL=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Ghostly Weapon","Withering Touch","Soul Tap"},
  hudFrameName = "RetreatUIReaperHUD",
})

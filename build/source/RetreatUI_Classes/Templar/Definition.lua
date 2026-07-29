local RUI = RetreatUI

RUI:RegisterClassDefinition("Templar", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Tank / Healer / Damage",
  theme = "Sacred Bulwark",
  accent = {0.960, 0.720, 0.160},
  accent2 = {0.920, 0.920, 0.720},
  background = {0.044, 0.030, 0.004},
  installerTheme = {
    title = "TEMPLAR",
    subtitle = "Sacred Bulwark • All Specializations",
    description = "Chain the strike. Hold the oath. Turn discipline into power.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Templar_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Templar_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "ENERGY",
  dynamicPrimaryResource = true,
  supportedLoadouts = {DISCIPLINE=true,FIGHTING=true,RUNES=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Righteous Upheaval","Norgannon's Wrath","Crusader's Brand"},
  hudFrameName = "RetreatUITemplarHUD",
})

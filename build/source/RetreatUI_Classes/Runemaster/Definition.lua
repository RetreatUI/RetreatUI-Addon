local RUI = RetreatUI

RUI:RegisterClassDefinition("Runemaster", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Tank / Damage",
  theme = "Runic Matrix",
  accent = {0.180, 0.720, 1.000},
  accent2 = {0.180, 1.000, 0.780},
  background = {0.004, 0.034, 0.050},
  installerTheme = {
    title = "RUNEMASTER",
    subtitle = "Runic Matrix • All Specializations",
    description = "Etch the pattern. Channel the leyline. Rewrite the battle.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Runemaster_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Runemaster_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "MANA",
  dynamicPrimaryResource = true,
  supportedLoadouts = {ARCANE=true,RIFTBLADE=true,RUNIC=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Smolder","Hoarfrost","Runic Brand"},
  hudFrameName = "RetreatUIRunemasterHUD",
})

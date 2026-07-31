local RUI = RetreatUI

RUI:RegisterClassDefinition("Tinker", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Damage / Tank / Healer",
  theme = "Machinist",
  accent = {0.080, 0.620, 1.000},
  accent2 = {0.950, 0.600, 0.120},
  background = {0.006, 0.026, 0.048},
  installerTheme = {
    title = "TINKER",
    subtitle = "Machinist • All Specializations",
    description = "Build the solution. Prime the engine. Control the fight.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Tinker_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Tinker_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "MANA",
  dynamicPrimaryResource = true,
  supportedLoadouts = {FIREARMS=true,INVENTION=true,MECHANICS=true},
  aliases = {"TINKER"},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {
    {id=504527, name="Makeshift Dynamite"},
    {id=500241, name="Rocket Boots"},
    {id=801005, name="Bomb Toss"},
  },
  hudFrameName = "RetreatUITinkerHUD",
})

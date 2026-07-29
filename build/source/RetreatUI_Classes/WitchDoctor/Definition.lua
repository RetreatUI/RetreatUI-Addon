local RUI = RetreatUI

RUI:RegisterClassDefinition("Witch Doctor", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Healer / Damage",
  theme = "Loa's Call",
  accent = {0.440, 0.880, 0.200},
  accent2 = {0.580, 0.220, 0.820},
  background = {0.014, 0.040, 0.008},
  aliases = {"WitchDoctor"},
  installerTheme = {
    title = "WITCH DOCTOR",
    subtitle = "Loa's Call • All Specializations",
    description = "Invoke the loa. Mix potent rites. Curse those who resist.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\WitchDoctor_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\WitchDoctor_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "MANA",
  dynamicPrimaryResource = true,
  supportedLoadouts = {BREWING=true,SHADOWHUNTING=true,VOODOO=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Hexfire","Mojo Beam","Spirit Eclipse"},
  hudFrameName = "RetreatUIWitchDoctorHUD",
})

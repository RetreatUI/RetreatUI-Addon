local RUI = RetreatUI

RUI:RegisterClassDefinition("Witch Hunter", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Damage",
  theme = "Night Pursuit",
  accent = {0.720, 0.280, 0.920},
  accent2 = {0.200, 0.180, 0.320},
  background = {0.026, 0.008, 0.042},
  aliases = {"WitchHunter"},
  installerTheme = {
    title = "WITCH HUNTER",
    subtitle = "Night Pursuit • All Specializations",
    description = "Mark the guilty. Hunt the occult. End the threat cleanly.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\WitchHunter_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\WitchHunter_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "MANA",
  dynamicPrimaryResource = true,
  supportedLoadouts = {BOLTSLINGER=true,DARKNESS=true,INQUISITION=true,WITCHKNIGHT=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Hunt","Purifier's Edge","March of the Black King"},
  hudFrameName = "RetreatUIWitchHunterHUD",
})

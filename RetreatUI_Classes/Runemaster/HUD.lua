local RUI = RetreatUI

-- Native RetreatUI conversion of the supplied Runemaster WeakAura pack.
-- The WA used compact centred rows with a seven-icon priority row and a
-- secondary utility row. RetreatUI keeps that structure while using learned
-- spell detection, native cooldowns, build profiles and active-only proc icons.
-- The source WeakAura remains external and is never imported or modified.
RUI:RegisterAdvancedClassHUD("Runemaster", {
  frameName = "RetreatUIRunemasterHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {ARCANE=true,RIFTBLADE=true,RUNIC=true},

  maxCore = 7,
  coreIconSize = 38,
  coreSpacing = 2,
  coreOrder = {
    "Power Engraving",
    "Primordial Pulse",
    "Zenith",
    "Fists of Power",
    "Fist of the Ancients",
    "Runic Brand",
    "Warpdagger",
  },
  strictCoreOrder = false,

  maxUtility = 10,
  utilityIconSize = 30,
  utilitySpacing = 2,
  utilityOrder = {
    "Glacial Rune",
    "Silencing Rune",
    "Permafrost Rune",
    "Hurricane",
    "Runic Hurricane",
    "Granite Resolve",
    "Warding Rune",
    "Phase Out",
    "Speed Rune",
    "Resonance Rune",
  },
  strictUtilityOrder = false,

  maxProcs = 10,
})

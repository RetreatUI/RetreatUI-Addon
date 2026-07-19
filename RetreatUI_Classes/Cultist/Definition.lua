local RUI = RetreatUI

RUI:RegisterClassDefinition("Cultist", {
  ready = true,
  releaseStatus = "beta",
  theme = "Insanity",
  accent = {0.55, 0.16, 0.92},
  accent2 = {0.86, 0.25, 1.00},
  background = {0.018, 0.008, 0.048},
  installerTheme = {
    title = "Cultist",
    subtitle = "Dreadnought Tank • Forbidden Rite",
    description = "Embrace the void. Bend insanity. Become unstoppable.",
    loadout = "Dreadnought Tank",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Cultist_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Cultist_Installer.tga",
  },
  primaryResource = "MANA",
  roles = "Tank / Damage / Healer",
  supportedLoadouts = {TANK=true},
  detectionPriority = 25,
  detectionThreshold = 2,
  detectionSpells = {
    "Dreadnought",
    "Twilight Shieldtoss",
    "Void Strikes",
    "Dreadfall",
    "Inner Darkness",
  },
  hudFrameName = "RetreatUICultistHUD",
})

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
  -- UnitClass() returns the internal SPIRITMAGE token on some localized
  -- Ascension clients. Keep English display aliases as well, then fall back to
  -- language-independent spell IDs when the localized class name is unknown.
  aliases = {"SPIRITMAGE", "Spirit Mage", "SpiritMage"},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {
    {id=801087, name="Smolder"},
    {id=801104, name="Hoarfrost"},
    {id=712299, name="Runic Brand"},
  },
  hudFrameName = "RetreatUIRunemasterHUD",
})

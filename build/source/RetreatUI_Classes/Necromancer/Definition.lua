local RUI = RetreatUI

RUI:RegisterClassDefinition("Necromancer", {
  ready = true,
  releaseStatus = "full-class",
  roles = "Damage / Healer",
  theme = "Graveborn",
  accent = {0.420, 0.820, 0.200},
  accent2 = {0.180, 0.450, 0.120},
  background = {0.010, 0.036, 0.012},
  installerTheme = {
    title = "NECROMANCER",
    subtitle = "Graveborn • Rime / Death / Animation",
    description = "Command the dead. Bind lost souls. Outlast the grave.",
    loadout = "Complete Necromancer HUD",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Necromancer_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Necromancer_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "RUNIC_POWER",
  dynamicPrimaryResource = false,
  supportedLoadouts = {BASELINE=true, RIME=true, DEATH=true, ANIMATION=true},
  detectionPriority = 20,
  detectionThreshold = 1,
  detectionSpells = {
    "Lichfrost", "Crypt Swarm", "Raise: Ghoul",
    {name="Fetid Ward", id=680388},
    {name="Glacial Tap", id=805369},
  },
  hudFrameName = "RetreatUINecromancerHUD",
})

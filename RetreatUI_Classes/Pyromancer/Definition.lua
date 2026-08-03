local RUI = RetreatUI

RUI:RegisterClassDefinition("Pyromancer", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Damage",
  theme = "Living Flame",
  accent = {1.000, 0.280, 0.040},
  accent2 = {1.000, 0.680, 0.100},
  background = {0.052, 0.010, 0.004},
  installerTheme = {
    title = "PYROMANCER",
    subtitle = "Pyrolancer • Living Flame",
    description = "A Pyrolancer HUD curated from both supplied WeakAura packs, with Heat, Embers, cooldowns, procs and target effects.",
    loadout = "Pyrolancer / All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Pyromancer_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Pyromancer_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "MANA",
  dynamicPrimaryResource = true,
  supportedLoadouts = {DESTRUCTION=true,DRACONIC=true,INCINERATION=true,PYROLANCER=true},
  detectionPriority = 100,
  detectionThreshold = 1,
  detectionSpells = {"Eruption","Lava Shard","Firefall","Destroyer's Maw","Pillar of Flame"},
  hudFrameName = "RetreatUIPyromancerHUD",
})

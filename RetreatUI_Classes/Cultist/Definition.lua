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
  tankFramework = {
    buildMechanic="Insanity",
    combatState={"Strength of the Black Empire","Void Monstrosity","Dreadnought"},
    coreMechanic="Total Madness",
    taunt={"Horrifying Presence","Test of Pride"},
    interrupt={"Mass Nightmare","Crushing Dissonance"},
    dispel="Devour Magic",
    combatBuffs={"Void-Enhanced Shield","Abyssal Ward","Embrace the Void","Tentacle of Yogg-Saron","Armageddon","Doomcloak","Bulwark of Shadow","Eldritch Bastion","Voidwarding","Twisted Seal"},
  },
  hudFrameName = "RetreatUICultistHUD",
})

local definition = RUI:GetClassInfo("Cultist")
if definition and definition.tankFramework then
  RUI:RegisterTankProfile("Cultist", definition.tankFramework)
end

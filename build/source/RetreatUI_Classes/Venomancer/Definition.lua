local RUI = RetreatUI

RUI:RegisterClassDefinition("Venomancer", {
  ready = true,
  releaseStatus = "all-spec",
  theme = "Poison Jungle",
  accent = {0.28, 0.88, 0.08},
  accent2 = {0.72, 0.20, 0.92},
  background = {0.010, 0.045, 0.018},
  installerTheme = {
    title = "VENOMANCER",
    subtitle = "Poison Jungle • All Specializations",
    description = "Strength grows. Poison flows. The jungle protects.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Venomancer_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Venomancer_Installer.tga",
  },
  primaryResource = "RAGE",
  dynamicPrimaryResource = true,
  supportedLoadouts = {FORTITUDE=true,STALKING=true,VENOM=true,VIZIER=true},
  detectionPriority = 20,
  detectionThreshold = 1,
  detectionSpells = {
    "Beetle Form",
    "Exposed Flesh",
    "Chitin Rush",
    "Regrow Exoskeleton",
  },
  tankFramework = {
    buildMechanic="Exposed Flesh",
    combatState={"Spider Lord","Beetle Form"},
    coreMechanic="Carapace",
    taunt="Vile Sting",
    interrupt="Nullifying Toxin",
    combatBuffs={"Harden","Regrow Exoskeleton","Catalyst","Lifeblood"},
  },
  hudFrameName = "RetreatUIVenomancerHUD",
})

local definition = RUI:GetClassInfo("Venomancer")
if definition and definition.tankFramework then
  RUI:RegisterTankProfile("Venomancer", definition.tankFramework)
end

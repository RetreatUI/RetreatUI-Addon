local RUI = RetreatUI

RUI:RegisterClassDefinition("Bloodmage", {
  ready = true,
  releaseStatus = "all-spec",
  roles = "Tank / Damage / Healer",
  theme = "Crimson Covenant",
  accent = {0.94, 0.10, 0.15},
  accent2 = {1.00, 0.42, 0.48},
  background = {0.040, 0.006, 0.010},
  installerTheme = {
    title = "BLOODMAGE",
    subtitle = "Blood • Ferocity • Fleshweaver • Packleader",
    description = "Spend blood. Command rage. Refuse death.",
    loadout = "All Specializations",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Bloodmage_Icon.tga",
    background = "Interface\\AddOns\\RetreatUI\\Media\\Themes\\Bloodmage_Installer.tga",
    artworkAlpha = 0.94,
  },
  primaryResource = "RAGE",
  supportedLoadouts = {BLOOD=true, FEROCITY=true, FLESHWEAVER=true, PACKLEADER=true},
  detectionPriority = 24,
  detectionThreshold = 1,
  detectionSpells = {
    {name="Blood Curse", id=562720},
    {name="Bloodfang Bite", id=806156},
    {name="Bare Fangs", id=801957},
    "Eternal Resolve",
    "Rotclaw",
  },
  tankFramework = {
    combatState={"Cursed Form"},
    coreMechanic="Blood Bond",
    taunt="Bare Fangs",
    combatBuffs={"Saturating Sutures", "Blood Rush", "Enraging Howl", "Trail of Blood", "Call of the Darkwing"},
  },
  hudFrameName = "RetreatUIBloodmageHUD",
})

local definition = RUI:GetClassInfo("Bloodmage")
if definition and definition.tankFramework then
  RUI:RegisterTankProfile("Bloodmage", definition.tankFramework)
end

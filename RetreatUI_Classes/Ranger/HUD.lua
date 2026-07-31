local RUI = RetreatUI

RUI:RegisterAdvancedClassHUD("Ranger", {
  frameName = "RetreatUIRangerHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {ARCHERY=true,DUELING=true,SURVIVAL=true},

  maxCore = 7,
  coreIconSize = 36,
  coreSpacing = 2,
  coreOrder = {
    "Incendiary Shot",
    "Woodland Arrow",
    "Viper's Bite",
    "Barbed Shot",
    "Falconstrike",
    "Crippling Shot",
    "Brutal Shot",
  },
  strictCoreOrder = false,

  maxUtility = 9,
  utilityIconSize = 28,
  utilitySpacing = 2,
  utilityOrder = {
    "Throatpunch",
    "Knockout",
    "Whipvine Arrow",
    "Hookshot",
    "Elude",
    "Horn of Perseverance",
    "Horn of War",
    "Horn of Endurance",
    "Horn of Alacrity",
  },
  strictUtilityOrder = false,

  -- Active horn, Skirmish and class proc icons share one centred row and only
  -- appear while their aura is active.
  maxProcs = 6,
})

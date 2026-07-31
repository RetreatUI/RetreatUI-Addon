local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

-- Pyromancer owns two distinct class resources:
--   Heat   -> one compact 0 / 100 bar from the shared Advanced HUD
--   Embers -> the five native RetreatUI segments in Pyromancer/HUD.lua
-- Keeping them separate prevents the same Ember state from being rendered by
-- both the generic resource engine and the Pyromancer-specific segment row.
local database = RUI:GetClassSpellDatabase("Pyromancer")
if type(database) ~= "table" then return end

database.nativeResource = {
  title = "HEAT",
  keywords = {"heat"},
  maximum = 100,
  maxStacks = 100,
  defaultCurrent = 0,
  keepVisible = true,
  mode = "bar",
  showLabel = false,
  width = 360,
  height = 9,
  matchPrimaryPower = true,
  gap = 1,
  icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
}

database.pyromancerResourceRevision = 1

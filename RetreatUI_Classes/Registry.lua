local RUI = RetreatUI

-- Class metadata belongs to the Classes package. A class becomes playable only
-- when its own folder also registers ready=true, spell data and a HUD module.
local definitions = {
  ["Necromancer"] = {theme="Graveborn", accent={0.42,0.82,0.20}, accent2={0.18,0.45,0.12}, roles="Damage / Healer"},
  ["Pyromancer"] = {theme="Living Flame", accent={1.00,0.28,0.04}, accent2={1.00,0.68,0.10}, roles="Damage"},
  ["Cultist"] = {theme="Forbidden Rite", accent={0.62,0.20,0.82}, accent2={0.92,0.18,0.48}, roles="Tank / Damage / Healer"},
  ["Starcaller"] = {theme="Astral Convergence", accent={0.34,0.55,1.00}, accent2={0.78,0.52,1.00}, roles="Damage / Healer"},
  ["Sun Cleric"] = {theme="Solar Grace", accent={1.00,0.72,0.18}, accent2={1.00,0.94,0.58}, roles="Healer / Damage", aliases={"SunCleric"}},
  ["Tinker"] = {theme="Machinist", accent={0.08,0.62,1.00}, accent2={0.95,0.60,0.12}, roles="Damage / Tank / Healer"},
  ["Runemaster"] = {theme="Runic Matrix", accent={0.18,0.72,1.00}, accent2={0.18,1.00,0.78}, roles="Tank / Damage"},
  ["Primalist"] = {theme="Primal Fury", accent={0.95,0.48,0.10}, accent2={0.24,0.78,0.22}, roles="Tank / Damage / Healer"},
  ["Reaper"] = {theme="Soul Hunger", accent={0.50,0.15,0.70}, accent2={0.12,0.85,0.72}, roles="Damage"},
  ["Venomancer"] = {theme="Venom Bloom", accent={0.45,0.90,0.12}, accent2={0.70,0.18,0.80}, roles="Damage / Healer"},
  ["Chronomancer"] = {theme="Timeweaver", accent={0.96,0.72,0.12}, accent2={0.20,0.70,1.00}, roles="Damage / Healer"},
  ["Bloodmage"] = {theme="Crimson Covenant", accent={0.90,0.08,0.12}, accent2={0.40,0.02,0.06}, roles="Tank / Damage / Healer"},
  ["Guardian"] = {theme="Ancient Bulwark", accent={0.28,0.78,0.38}, accent2={0.68,0.52,0.20}, roles="Tank / Healer"},
  ["Stormbringer"] = {theme="Tempest", accent={0.18,0.62,1.00}, accent2={0.80,0.92,1.00}, roles="Damage / Tank"},
  ["Felsworn"] = {theme="Fel Dominion", accent={0.30,0.92,0.12}, accent2={0.66,0.16,0.86}, roles="Damage / Tank"},
  ["Barbarian"] = {theme="Unbroken", accent={0.86,0.24,0.08}, accent2={0.56,0.42,0.18}, roles="Damage / Tank"},
  ["Witch Doctor"] = {theme="Loa's Call", accent={0.44,0.88,0.20}, accent2={0.58,0.22,0.82}, roles="Healer / Damage", aliases={"WitchDoctor"}},
  ["Witch Hunter"] = {theme="Night Pursuit", accent={0.72,0.28,0.92}, accent2={0.20,0.18,0.32}, roles="Damage", aliases={"WitchHunter"}},
  ["Knight of Xoroth"] = {theme="Xorothian Flame", accent={1.00,0.22,0.02}, accent2={0.20,0.88,0.12}, roles="Tank / Damage", aliases={"KnightOfXoroth"}},
  ["Templar"] = {theme="Sacred Bulwark", accent={0.96,0.72,0.16}, accent2={0.92,0.92,0.72}, roles="Tank / Healer / Damage"},
  ["Ranger"] = {theme="Wild Hunt", accent={0.42,0.78,0.20}, accent2={0.70,0.48,0.18}, roles="Damage"},
}

for className, definition in pairs(definitions) do
  definition.ready = false
  RUI:RegisterClassDefinition(className, definition)
end

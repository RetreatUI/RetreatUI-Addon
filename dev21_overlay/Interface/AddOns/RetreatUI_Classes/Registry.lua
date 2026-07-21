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
  ["Bloodmage"] = {theme="Crimson Covenant", accent={0.90,0.08,0.12}, accent2={0.40,0.02,0.06}, roles="Damage / Healer"},
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

-- RetreatUI v1.0.2-dev.21
-- Keep the complete dev.20 package intact and apply only the final agreed
-- Venomancer main-row cleanup. The filter is enforced at both the class-data
-- resolver and the shared row builder so it also covers the development
-- preview definitions without allowing forms, counters or filler abilities back.
local DEV21_VERSION = "1.0.2-dev.21"
RUI.version = DEV21_VERSION
RUI.classesVersion = DEV21_VERSION
RUI.classPackage = RUI.classPackage or {}
RUI.classPackage.version = DEV21_VERSION
if RUI.changelog then
  RUI.changelog.version = DEV21_VERSION
  RUI.changelog.title = "RetreatUI " .. DEV21_VERSION
  RUI.changelog.summary = "Final Venomancer preview cleanup."
  RUI.changelog.changes = {
    "Reduced the Venomancer main HUD row to the eight agreed decision-critical abilities.",
    "Removed Venomtip Poison, Hivebreak, Carapace Crash and Claw Strike from the main HUD row.",
    "Kept Venomtip Poison in target-debuff tracking instead of duplicating it on the action row.",
    "Preserved Bloodmage, Cultist, installer artwork and all other dev.20 behavior unchanged.",
  }
end

local VENOMANCER_CORE_ALLOWED = {
  ["Chitin Rush"] = true,
  ["Expulsion"] = true,
  ["Barbed Stinger"] = true,
  ["Regrow Exoskeleton"] = true,
  ["Harden"] = true,
  ["Lifeblood"] = true,
  ["Vile Sting"] = true,
  ["Nullifying Toxin"] = true,
}

local function DefinitionName(definition)
  if type(definition) ~= "table" then return nil end
  return definition.name or definition.spellName or definition.label or definition.buff
end

local function FilterVenomancerCore(definitions)
  local filtered = {}
  local seen = {}
  for _, definition in ipairs(definitions or {}) do
    local name = DefinitionName(definition)
    if name and VENOMANCER_CORE_ALLOWED[name] and not seen[name] then
      seen[name] = true
      filtered[#filtered + 1] = definition
    end
  end
  table.sort(filtered, function(left, right)
    local leftOrder = tonumber(left and left.order) or 9999
    local rightOrder = tonumber(right and right.order) or 9999
    if leftOrder == rightOrder then
      return tostring(DefinitionName(left) or "") < tostring(DefinitionName(right) or "")
    end
    return leftOrder < rightOrder
  end)
  return filtered
end

if type(RUI.GetHUDSpellDefinitions) == "function" and not RUI._dev21OriginalGetHUDSpellDefinitions then
  RUI._dev21OriginalGetHUDSpellDefinitions = RUI.GetHUDSpellDefinitions
  function RUI:GetHUDSpellDefinitions(className, row)
    local definitionsForRow = self._dev21OriginalGetHUDSpellDefinitions(self, className, row)
    if className == "Venomancer" and row == "core" then
      return FilterVenomancerCore(definitionsForRow)
    end
    return definitionsForRow
  end
end

local widgets = RUI.HUDWidgets
if widgets and type(widgets.BuildSpellRow) == "function" and not widgets._dev21OriginalBuildSpellRow then
  widgets._dev21OriginalBuildSpellRow = widgets.BuildSpellRow
  function widgets:BuildSpellRow(rowFrame, definitionsForRow, iconSize, spacing, learnedPredicate, textureResolver, ...)
    local parent = rowFrame and rowFrame.GetParent and rowFrame:GetParent() or nil
    local parentName = parent and parent.GetName and parent:GetName() or nil
    if parentName == "RetreatUIVenomancerHUD" and (tonumber(iconSize) or 0) >= 36 then
      definitionsForRow = FilterVenomancerCore(definitionsForRow)
    end
    return self._dev21OriginalBuildSpellRow(
      self,
      rowFrame,
      definitionsForRow,
      iconSize,
      spacing,
      learnedPredicate,
      textureResolver,
      ...
    )
  end
end

RUI._dev21VenomancerCleanupLoaded = true
-- Rebuilt to regenerate the downloadable dev.21 artifact.

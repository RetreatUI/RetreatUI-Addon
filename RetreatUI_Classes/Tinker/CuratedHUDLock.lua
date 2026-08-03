local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

local database = RUI:GetClassSpellDatabase("Tinker")
if type(database) ~= "table" then return end

local function Normalize(value)
  return string.lower(tostring(value or "")):gsub("’", "'"):gsub("`", "'")
    :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function Set(values)
  local result = {}
  for _, value in ipairs(values) do result[Normalize(value)] = true end
  return result
end

-- This is the existing tester-curated Tinker order, plus the two explicitly
-- reviewed healer actions restored from beta.26. The visible rows remain capped
-- by Tinker/HUD.lua at seven core and eight utility icons.
local core = Set({
  "Bomb Toss",
  "Blasting Round",
  "Makeshift Dynamite",
  "Blackpowder Barrage",
  "Overclock Weapon",
  "Activate Mechsuit: Shredder",
  "Supercharge",
  "Rocket Barrage",
  "Cannonball Launcher",
  "Build: Sentry Turret",
  "Build: Scraptron",
  "Build: Battle Turret X-13",
  "Build: ZIGGI-6K",
  "Zap!",
  "Overcharge",
})

local utility = Set({
  "Build: Noise Box",
  "Reload",
  "Battery Swap",
  "Remote Detonation",
  "Distracto Shot",
  "Deploy Blast Mine",
  "Deploy Shrapnel Mine",
  "Invisibility Cloak",
  "Arcanoreflector",
  "Nanobot Barrier",
  "Nanobot Cleanser",
  "Anti-Magic Grenades",
  "Minicopter-Z",
  "Build: Shield Beacon",
  "Build: Replenishment Beacon",
  "Rocket Boots",
  "Kinetic Shield",
  "Discombobulate!",
})

local coreCategories = {rotation=true, offensive=true, summon=true, resource=true}
local utilityCategories = {
  interrupt=true, taunt=true, control=true, mobility=true, defensive=true,
  utility=true, stance=true, form=true, ally=true,
}

for _, record in ipairs(database.spells or {}) do
  if type(record) == "table" then
    local name = Normalize(record.name)
    local category = Normalize(record.category)
    if coreCategories[category] and not core[name] then
      record.trackHUD = false
    elseif utilityCategories[category] and not utility[name] then
      record.trackHUD = false
    end
  end
end

-- Do not merge every class-labelled spellbook cooldown back into this exact
-- profile. That safety net is useful for unaudited classes, not a locked HUD.
database.disableLiveClassCooldowns = true
database.tinkerCuratedHUDLockRevision = 1

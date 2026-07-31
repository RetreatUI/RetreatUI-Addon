local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

-- Native RetreatUI additions identified while auditing the supplied
-- Avoti Ranger/Archer WeakAura pack. The source WeakAura is never imported;
-- only confirmed spell and aura IDs are added to RetreatUI's existing Ranger
-- database so the normal learned-spell, cooldown and active-aura systems own
-- the presentation.
local database = RUI:GetClassSpellDatabase("Ranger")
if type(database) ~= "table" then return end

database.spells = database.spells or {}

local function Normalize(value)
  return string.lower(tostring(value or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local byID, byName = {}, {}
for _, record in ipairs(database.spells) do
  if type(record) == "table" then
    if tonumber(record.id) then byID[tonumber(record.id)] = record end
    if record.name then byName[Normalize(record.name)] = record end
  end
end

local function AddUnique(record)
  local id = tonumber(record and record.id)
  local name = Normalize(record and record.name)
  if (id and byID[id]) or (name ~= "" and byName[name]) then return false end
  database.spells[#database.spells + 1] = record
  if id then byID[id] = record end
  if name ~= "" then byName[name] = record end
  return true
end

local function MergeUnique(target, values)
  target = type(target) == "table" and target or {}
  local seen = {}
  for _, value in ipairs(target) do seen[tostring(value)] = true end
  for _, value in ipairs(values or {}) do
    if not seen[tostring(value)] then
      target[#target + 1] = value
      seen[tostring(value)] = true
    end
  end
  return target
end

-- The pack identifies the five-point Archery/Advantage resource through aura
-- ID 804329. Keep the existing Advantage naming as a fallback while adding the
-- language-independent ID and the alternate display name used by the pack.
local resource = database.nativeResource or {}
database.nativeResource = resource
resource.title = resource.title or "ADVANTAGE"
resource.maximum = 5
resource.maxStacks = 5
resource.defaultCurrent = tonumber(resource.defaultCurrent) or 0
resource.keepVisible = true
resource.mode = "segments"
resource.icon = resource.icon or "Interface\\Icons\\Ability_Hunter_FocusedAim"
resource.spellIDs = MergeUnique(resource.spellIDs, {804329})
resource.auraNames = MergeUnique(resource.auraNames, {"Advantage", "Archery Points"})
resource.keywords = MergeUnique(resource.keywords, {"advantage", "archery points"})

-- Existing horn cooldowns also need active-duration coverage. Only an active
-- aura is rendered in the proc row, so this does not create four permanent
-- horn blocks.
for _, name in ipairs({"Horn of War", "Horn of Alacrity"}) do
  local record = byName[Normalize(name)]
  if record then
    record.buff = name
    record.trackDuration = true
    record.auraTracker = true
  end
end

AddUnique({
  name = "Barbed Shot",
  id = 807237,
  category = "rotation",
  hudRow = "core",
  order = 24,
  trackCooldown = true,
  targetDebuff = true,
  sourceTab = "Archery",
})

AddUnique({
  name = "Falconstrike",
  aliases = {"Falcon Strike"},
  id = 801434,
  category = "rotation",
  hudRow = "core",
  order = 26,
  trackCooldown = true,
  sourceTab = "Archery",
})

AddUnique({
  name = "Elude",
  id = 801345,
  category = "defensive",
  hudRow = "utility",
  order = 115,
  trackCooldown = true,
  buff = "Elude",
  trackDuration = true,
  auraTracker = true,
  sourceTab = "Class",
})

AddUnique({
  name = "Horn of Perseverance",
  id = 800088,
  category = "defensive",
  hudRow = "utility",
  order = 175,
  trackCooldown = true,
  buff = "Horn of Perseverance",
  trackDuration = true,
  auraTracker = true,
  partyCooldown = true,
  cooldownCategory = "defensive",
  sourceTab = "Survival",
})

AddUnique({
  name = "Horn of Endurance",
  id = 806359,
  category = "defensive",
  hudRow = "utility",
  order = 176,
  trackCooldown = true,
  buff = "Horn of Endurance",
  trackDuration = true,
  auraTracker = true,
  partyCooldown = true,
  cooldownCategory = "defensive",
  sourceTab = "Survival",
})

AddUnique({
  name = "Skirmish",
  id = 802039,
  category = "proc",
  order = 35,
  buff = "Skirmish",
  trackDuration = true,
  auraTracker = true,
  trackHUD = false,
  sourceTab = "Class",
})

-- Mark the database revision used by diagnostics without replacing the complete
-- collector version stored in Ranger/Data.lua.
database.waAuditRevision = 1

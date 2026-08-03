local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

-- Behavioral reference: https://wago.io/w-XCZHABg
-- The original package is not embedded. Racials, generic group reminders and
-- duplicate mana bars are excluded.
local database = RUI:GetClassSpellDatabase("Tinker")
if type(database) ~= "table" then return end
database.spells = database.spells or {}

local function Normalize(value)
  return string.lower(tostring(value or "")):gsub("’", "'"):gsub("`", "'")
    :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function Find(name)
  local wanted = Normalize(name)
  for _, record in ipairs(database.spells) do
    if type(record) == "table" then
      if Normalize(record.name) == wanted then return record end
      for _, alias in ipairs(record.aliases or {}) do
        if Normalize(alias) == wanted then return record end
      end
    end
  end
end

local function MergeList(target, values)
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

local function Patch(name, values)
  local record = Find(name)
  if not record then return nil end
  if values.aliases then
    record.aliases = MergeList(record.aliases, values.aliases)
    values.aliases = nil
  end
  for key, value in pairs(values) do record[key] = value end
  return record
end

local function Upsert(values)
  local record = Find(values.name)
  if record then
    if values.aliases then record.aliases = MergeList(record.aliases, values.aliases) end
    for key, value in pairs(values) do
      if key ~= "aliases" and (record[key] == nil or key == "auraID" or key == "buffID") then
        record[key] = value
      end
    end
    return record
  end
  database.spells[#database.spells + 1] = values
  return values
end

Patch("Eureka!", {
  buff="Eureka!", auraID=503553, buffID=503553,
  trackDuration=true,
})
Patch("Nanobot Barrier", {
  aliases={"Nanobot Swarm"}, buff="Nanobot Swarm",
  auraID=801709, buffID=801709,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Build: Battery Recharge Station", {
  aliases={"Recharge Station"},
})
Patch("Build: Restorative Beacon", {
  aliases={"Resto Beacon"},
})
Patch("Build: Noise Box", {
  aliases={"Noise Box"}, learnedByAny={807723, 807197}, runtimeID=807723,
})

Upsert({
  name="Overcharge", id=524835, category="offensive", hudRow="core", order=26,
  trackCooldown=true, forceHUD=true,
  glowWhenAura={"Build: Shield Beacon", "Build: Replenishment Beacon", "Build: Restorative Beacon"},
  source="Wago w-XCZHABg",
})
Upsert({
  name="Discombobulate!", id=807197, category="control", hudRow="utility", order=118,
  trackCooldown=true, targetDebuff=true, forceHUD=true,
  source="Wago w-XCZHABg",
})

for _, aura in ipairs({
  {name="Nanobot Recharger", id=803552, order=322},
  {name="Nanobot Reconstruction", id=502561, order=324},
}) do
  Upsert({
    name=aura.name, id=aura.id, auraID=aura.id, buffID=aura.id,
    category="proc", order=aura.order, buff=aura.name,
    trackDuration=true, auraTracker=true, trackHUD=false,
    source="Wago w-XCZHABg",
  })
end

database.tinkerHealerWAAuditRevision = 1
database.tinkerHealerWagoSource = "w-XCZHABg"

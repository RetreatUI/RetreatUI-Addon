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

local function AddAudit(values, approved)
  local record = Find(values.name)
  if record then
    if values.aliases then record.aliases = MergeList(record.aliases, values.aliases) end
    for key, value in pairs(values) do
      if key ~= "aliases" and key ~= "auditRecord" and key ~= "hudApproved"
        and (record[key] == nil or key == "auraID" or key == "buffID"
          or key == "runtimeID" or key == "runtimeIDs") then
        record[key] = value
      end
    end
    return record
  end
  values.auditRecord = true
  values.hudApproved = approved == true
  if approved ~= true then values.trackHUD = false end
  database.spells[#database.spells + 1] = values
  return values
end

Patch("Eureka!", {
  buff="Eureka!", auraID=503553, buffID=503553,
  trackDuration=true,
})
Patch("Build: Battery Recharge Station", {
  aliases={"Recharge Station"},
})
Patch("Build: Restorative Beacon", {
  aliases={"Resto Beacon"},
})
Patch("Build: Noise Box", {
  aliases={"Noise Box"}, runtimeID=807723,
})

-- These two actions are explicitly placed in Tinker's curated core/utility
-- order. No other audit action is allowed to expand those rows.
AddAudit({
  name="Overcharge", id=524835, category="offensive", hudRow="core", order=26,
  trackCooldown=true, forceHUD=true,
  glowWhenAura={"Build: Shield Beacon", "Build: Replenishment Beacon", "Build: Restorative Beacon"},
  source="Wago w-XCZHABg",
}, true)
AddAudit({
  name="Discombobulate!", id=807197, category="control", hudRow="utility", order=118,
  trackCooldown=true, targetDebuff=true, forceHUD=true,
  source="Wago w-XCZHABg",
}, true)

for _, aura in ipairs({
  {name="Nanobot Swarm", id=801709, order=320},
  {name="Nanobot Recharger", id=803552, order=322},
  {name="Nanobot Reconstruction", id=502561, order=324},
}) do
  AddAudit({
    name=aura.name, id=aura.id, auraID=aura.id, buffID=aura.id,
    category="proc", order=aura.order, buff=aura.name,
    trackDuration=true, auraTracker=true,
    source="Wago w-XCZHABg",
  }, false)
end

database.tinkerHealerWAAuditRevision = 3
database.tinkerHealerWagoSource = "w-XCZHABg"
database.tinkerAuditHUDPolicy = "explicit-whitelist"

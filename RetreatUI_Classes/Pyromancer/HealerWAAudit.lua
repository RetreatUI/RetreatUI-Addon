local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

-- Behavioral reference: https://wago.io/g1d1f6fiC
-- Only Pyromancer-specific abilities, replacement IDs and active effects are
-- retained. Layout, cast/mana bars, racials and generic reminders are omitted.
local database = RUI:GetClassSpellDatabase("Pyromancer")
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
    local aliases = values.aliases
    values.aliases = nil
    for key, value in pairs(values) do
      if record[key] == nil or key == "runtimeID" or key == "auraID" or key == "buffID" then
        record[key] = value
      end
    end
    if aliases then record.aliases = MergeList(record.aliases, aliases) end
    return record
  end
  database.spells[#database.spells + 1] = values
  return values
end

-- Replacement spell IDs used by the Flameweaving/Pyrolancer build.
Patch("Circle of Fire", {
  learnedByAny={800807, 997003}, runtimeID=997003,
  source="RetreatUI collector + Wago g1d1f6fiC runtime correction",
})
Patch("Dragon Leap", {
  learnedByAny={806611, 807616}, runtimeID=807616,
  source="RetreatUI collector + Wago g1d1f6fiC runtime correction",
})
Patch("Gaze of Ysera", {
  learnedByAny={806148, 503229}, runtimeID=503229,
  source="RetreatUI collector + Wago g1d1f6fiC runtime correction",
})
Patch("Meteor", {
  learnedByAny={500135, 500649}, runtimeID=500135,
})
Patch("Volcanic Shell", {
  learnedByAny={805477, 807622}, runtimeID=807622,
  buff="Volcanic Shell", auraID=807621, buffID=807621,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Inferno Barrier", {
  aliases={"Lava Barrier"}, learnedByAny={504380, 535650}, runtimeID=504380,
})

-- Existing effects with verified active aura IDs.
Patch("Roaring Pyre", {
  buff="Roaring Pyre", auraID=704279, buffID=704279,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Lifebinder's Fire", {auraID=680367, buffID=680367})
Patch("Sageweaving", {auraID=806783, buffID=806783})
Patch("Ignis Ultimatus", {glowWhenAuraID={804301}})

-- Missing Flameweaving/Pyrolancer actions.
Upsert({
  name="Eruption", id=800103, category="rotation", hudRow="core", order=12,
  trackCooldown=true, buff="Eruption", auraID=800103, buffID=800103,
  trackDuration=true, separateAuraTracker=false, forceHUD=true,
  source="Wago g1d1f6fiC",
})
Upsert({
  name="Lava Shard", id=503233, runtimeID=803950,
  learnedByAny={503233, 803950}, category="rotation", hudRow="core", order=14,
  trackCooldown=true, forceHUD=true, source="Wago g1d1f6fiC",
})
Upsert({
  name="Spellburn", aliases={"SpellBurn"}, id=800808,
  category="rotation", hudRow="core", order=16, trackCooldown=true,
  targetDebuff=true, forceHUD=true, source="Wago g1d1f6fiC",
})
Upsert({
  name="Blaze", id=572160, runtimeID=572159, learnedByAny={572160, 572159},
  category="rotation", hudRow="core", order=17, trackCooldown=true,
  buff="Blaze", auraID=534601, buffID=534601,
  trackDuration=true, separateAuraTracker=false, forceHUD=true,
  source="Wago g1d1f6fiC",
})
Upsert({
  name="Flame Step", id=801911, category="mobility", hudRow="utility", order=70,
  trackCooldown=true, forceHUD=true, source="Wago g1d1f6fiC",
})
Upsert({
  name="Reborn from Ash", id=804231, category="defensive", hudRow="utility", order=250,
  trackCooldown=true, forceHUD=true, source="Wago g1d1f6fiC",
})
Upsert({
  name="Supernova", id=803546, category="offensive", hudRow="core", order=205,
  trackCooldown=true, forceHUD=true, source="Wago g1d1f6fiC",
})

-- Active-only healer and skin states.
for _, aura in ipairs({
  {name="Ashen Skin", id=504720, order=260},
  {name="Ember Skin", id=504707, order=261},
  {name="Magma Skin", id=681314, order=262},
  {name="Dragon Skin", id=680387, order=263},
  {name="Flamecasting", aliases={"Searing Speed"}, id=804301, order=264},
}) do
  Upsert({
    name=aura.name, aliases=aura.aliases, id=aura.id, auraID=aura.id, buffID=aura.id,
    category="proc", order=aura.order, buff=aura.name,
    trackDuration=true, auraTracker=true, trackHUD=false,
    source="Wago g1d1f6fiC",
  })
end

database.pyromancerHealerWAAuditRevision = 1
database.pyromancerHealerWagoSource = "g1d1f6fiC"

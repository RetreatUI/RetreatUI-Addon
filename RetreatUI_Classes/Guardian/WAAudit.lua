local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

-- Native RetreatUI implementation of the supplied Guardian Tank WeakAura.
-- The WeakAura itself is never imported or bundled. Exact cooldown, charge,
-- aura, power and reminder IDs were audited and merged into the normal
-- RetreatUI spell database, with one native tracker per ability/effect.
local database = RUI:GetClassSpellDatabase("Guardian")
if type(database) ~= "table" then return end
database.spells = database.spells or {}

local function Normalize(value)
  value = string.lower(tostring(value or "")):gsub("’", "'")
  return value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local byID, byName = {}, {}
for _, record in ipairs(database.spells) do
  if type(record) == "table" then
    if tonumber(record.id) then byID[tonumber(record.id)] = record end
    if record.name then byName[Normalize(record.name)] = record end
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

local function Find(record)
  local id = tonumber(record and record.id)
  local name = Normalize(record and record.name)
  return (id and byID[id]) or (name ~= "" and byName[name])
end

local function AddOrMerge(record)
  local existing = Find(record)
  if existing then
    existing.aliases = MergeList(existing.aliases, record.aliases)
    existing.waSpellIDs = MergeList(existing.waSpellIDs, record.waSpellIDs or {record.id})
    for key, value in pairs(record) do
      if key ~= "aliases" and key ~= "waSpellIDs" and key ~= "id" then
        existing[key] = value
      end
    end
    return existing, false
  end

  database.spells[#database.spells + 1] = record
  if tonumber(record.id) then byID[tonumber(record.id)] = record end
  if record.name then byName[Normalize(record.name)] = record end
  record.waSpellIDs = MergeList(record.waSpellIDs, {record.id})
  return record, true
end

local function ExactAbility(record)
  local ability = AddOrMerge(record)

  -- Collector advancement IDs can return a definite false when the active
  -- Guardian specialization uses another internal tree name (Vanguard). The
  -- supplied WA deliberately keys these abilities from the live spellbook, so
  -- the native HUD must do the same instead of suppressing a learned spell.
  if ability.collectorEntryID ~= nil then
    ability.collectorEntryIDFromCollector = ability.collectorEntryID
    ability.collectorEntryID = nil
  end
  ability.entryID = nil
  ability.talentID = nil
  ability.forceHUD = true
  ability.trackCooldown = record.trackCooldown ~= false
  return ability
end

-- First WA row: high-frequency Vanguard mitigation and rotation.
local core = {
  {name="Shield of Denial", id=704159, category="defensive", hudRow="core", forceMain=true, order=10},
  {
    name="Reprisal", id=802740, category="rotation", hudRow="core", forceMain=true, order=20,
    trackCharges=true,
    -- Reprisal's six-second availability proc is a separate Ascension aura.
    -- Track that aura on the existing Reprisal ability icon so the icon glows
    -- and shows the remaining proc duration without creating a duplicate icon.
    buff="Reprisal", auraID=504885, buffID=504885,
    trackDuration=true, separateAuraTracker=false,
    glowWhenAuraID={504885},
  },
  {name="Heavy Blow", id=503119, category="rotation", hudRow="core", forceMain=true, order=30},
  {name="Hammer of the Law", id=704418, category="offensive", hudRow="core", forceMain=true, order=40, targetDebuff=true},
  {name="Shoulder the Burden", aliases={"Shoulder The Burden"}, id=572904, category="defensive", hudRow="core", forceMain=true, order=50},
  {name="Heroic Resolve", id=504910, category="defensive", hudRow="core", forceMain=true, order=60, trackCharges=true},
}
for _, record in ipairs(core) do ExactAbility(record) end

-- Second WA row: longer defensive, control and mobility tools.
local utility = {
  {name="Hold the Line", id=803830, category="defensive", hudRow="utility", forceUtility=true, order=110},
  {name="Chivalry", id=504149, category="defensive", hudRow="utility", forceUtility=true, order=120,
    buff="Chivalry", auraID=504149, buffID=504149, trackDuration=true, separateAuraTracker=false},
  {name="Turn the Blade", id=707170, category="defensive", hudRow="utility", forceUtility=true, order=130},
  {name="Knight's Calling", id=504151, category="offensive", hudRow="utility", forceUtility=true, order=140},
  {name="Counter Stance", id=802188, category="defensive", hudRow="utility", forceUtility=true, order=150},
  {name="Unyielding Stand", id=500269, category="defensive", hudRow="utility", forceUtility=true, order=160},
  {name="Reflective Shield", id=300927, category="defensive", hudRow="utility", forceUtility=true, order=170,
    buff="Reflective Shield", auraID=300927, buffID=300927, trackDuration=true, separateAuraTracker=false},
  {name="Press the Attack", id=801219, category="defensive", hudRow="utility", forceUtility=true, order=180},
  {name="Raise Shield", id=500168, category="defensive", hudRow="utility", forceUtility=true, order=190,
    buff="Raise Shield", auraID=500168, buffID=500168, trackDuration=true, separateAuraTracker=false},
  {name="Brace", id=800313, category="defensive", hudRow="utility", forceUtility=true, order=200,
    buff="Brace", auraID=800313, buffID=800313, trackDuration=true, separateAuraTracker=false},
  {name="Battle Rush", id=501546, category="mobility", hudRow="utility", forceUtility=true, order=210, trackCharges=true},
  {name="Advance", id=500170, category="mobility", hudRow="utility", forceUtility=true, order=220, trackCharges=true},
  {name="Glorious Arena", id=300983, category="control", hudRow="utility", forceUtility=true, order=230, targetDebuff=true},
}
for _, record in ipairs(utility) do ExactAbility(record) end

-- Active-only effects from the WA. Their durations belong in the native proc
-- row and are not duplicated as permanent cooldown icons.
local valiant = byName[Normalize("Valiant Knight")]
if valiant then
  valiant.buff = "Valiant Knight"
  valiant.auraID = 583027
  valiant.buffID = 583027
  valiant.trackDuration = true
  valiant.auraTracker = true
  valiant.trackHUD = false
end

AddOrMerge({
  name="Honor Guard", id=504586, category="proc", order=25,
  buff="Honor Guard", auraID=504586, buffID=504586,
  trackDuration=true, auraTracker=true, trackHUD=false,
  source="Guardian Tank WA audit",
})

-- The WA confirms Guardian's primary resource as Energy (power type 3).
database.resources = {{key="primary", name="Energy", type="primary", position="power"}}
database.guardianWAAuditRevision = 2
database.guardianWASourceVersion = "5.21.2 Beta"
database.guardianReminderIDs = {
  reinforcementSpell=653386,
  spikedReinforcement=653131,
  jaggedReinforcement=653279,
  reinforcementEnchantAura=189852,
  honorSpell=301232,
  honorAura=300856,
  greaterHonorSpell=680280,
  greaterHonorAura=680280,
}

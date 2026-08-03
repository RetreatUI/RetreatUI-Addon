local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

-- Behavioral reference: https://wago.io/25AZFWqQH
-- IMPORTANT: Eternal is intentionally read-only. This overlay patches only
-- collector records with an explicit non-Eternal sourceTab and adds only the
-- Fleshweaver, Sanguine and Accursed mechanics verified in the package.
local database = RUI:GetClassSpellDatabase("Bloodmage")
if type(database) ~= "table" then return end
database.spells = database.spells or {}

local function Normalize(value)
  return string.lower(tostring(value or "")):gsub("’", "'"):gsub("`", "'")
    :gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function IsProtectedEternal(record)
  if type(record) ~= "table" then return true end
  -- The curated Eternal block has no sourceTab. Never mutate it.
  if record.sourceTab == nil then return true end
  return Normalize(record.sourceTab) == "eternal"
end

local function FindNonEternal(name)
  local wanted = Normalize(name)
  for _, record in ipairs(database.spells) do
    if not IsProtectedEternal(record) then
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

local function PatchNonEternal(name, values)
  local record = FindNonEternal(name)
  if not record then return nil end
  if values.aliases then
    record.aliases = MergeList(record.aliases, values.aliases)
    values.aliases = nil
  end
  for key, value in pairs(values) do record[key] = value end
  return record
end

local function Add(values)
  -- New records must be explicitly assigned to a non-Eternal source.
  if not values.sourceTab or Normalize(values.sourceTab) == "eternal" then return nil end
  local existing = FindNonEternal(values.name)
  if existing then
    if values.aliases then existing.aliases = MergeList(existing.aliases, values.aliases) end
    for key, value in pairs(values) do
      if key ~= "aliases" and existing[key] == nil then existing[key] = value end
    end
    return existing
  end
  database.spells[#database.spells + 1] = values
  return values
end

-- Verified non-Eternal replacement IDs and active effects.
PatchNonEternal("Hemal Excision", {
  learnedByAny={281200, 803681}, runtimeID=803681,
  buff="Hemal Excision", auraID=803681, buffID=803681,
  trackDuration=true, separateAuraTracker=false,
})
PatchNonEternal("Aortic Assault", {
  learnedByAny={806212, 563270}, runtimeIDs={806212, 563270},
  glowWhenAuraID={681514},
})
PatchNonEternal("Reave", {
  learnedByAny={280990, 800490}, runtimeIDs={280990, 800490},
})
PatchNonEternal("Darkcasting", {
  auraID=712383, buffID=712383,
})
PatchNonEternal("Thirst", {
  auraID=706613, buffID=706613, maxStacks=10,
})

-- Fleshweaver ---------------------------------------------------------------
Add({
  name="Sanguine Mend", id=504085, learnedByAny={504085, 803880},
  runtimeIDs={504085, 803880}, category="rotation", hudRow="core", order=12,
  trackCooldown=true, forceHUD=true, sourceTab="Fleshweaver",
  source="Wago 25AZFWqQH",
})
Add({
  name="Blood Bolt", id=578305, category="rotation", hudRow="core", order=14,
  trackCooldown=true, forceHUD=true, sourceTab="Fleshweaver",
  source="Wago 25AZFWqQH",
})
Add({
  name="Dark Liturgy", id=800781, category="rotation", hudRow="core", order=16,
  trackCooldown=true, forceHUD=true, sourceTab="Fleshweaver",
  source="Wago 25AZFWqQH",
})
Add({
  name="Sanguine Rupture", id=572907, category="rotation", hudRow="core", order=18,
  trackCooldown=true, targetDebuff=true, forceHUD=true, sourceTab="Fleshweaver",
  source="Wago 25AZFWqQH",
})
Add({
  name="Bloodmoon Blast", id=501614, category="rotation", hudRow="core", order=22,
  trackCooldown=true, forceHUD=true, sourceTab="Fleshweaver",
  source="Wago 25AZFWqQH",
})
Add({
  name="Pooled Vitality", id=680687, auraID=680687, buffID=680687,
  category="proc", order=330, buff="Pooled Vitality", maxStacks=10,
  trackDuration=true, auraTracker=true, trackHUD=false, sourceTab="Fleshweaver",
  source="Wago 25AZFWqQH",
})

-- Sanguine ------------------------------------------------------------------
Add({
  name="Keleseth's Calamity", id=560249, runtimeIDs={560249, 706613},
  category="offensive", hudRow="core", order=155, trackCooldown=true,
  glowWhenAuraID={706613}, forceHUD=true, sourceTab="Sanguine",
  source="Wago 25AZFWqQH",
})
Add({
  name="Valanar's Vengeance", id=560315,
  category="offensive", hudRow="core", order=165, trackCooldown=true,
  glowWhenAuraID={706613}, forceHUD=true, sourceTab="Sanguine",
  source="Wago 25AZFWqQH",
})
Add({
  name="Insatiable", id=706663, auraID=706663, buffID=706663,
  category="proc", order=340, buff="Insatiable",
  trackDuration=true, auraTracker=true, trackHUD=false, sourceTab="Sanguine",
  source="Wago 25AZFWqQH",
})

-- Accursed ------------------------------------------------------------------
Add({
  name="Accursed Bloodmoon Blast", aliases={"Bloodmoon Blast"}, id=500444,
  category="rotation", hudRow="core", order=23, trackCooldown=true,
  forceHUD=true, sourceTab="Accursed", source="Wago 25AZFWqQH",
})
Add({
  name="Ravenous Strike", id=572551, category="rotation", hudRow="core", order=24,
  trackCooldown=true, forceHUD=true, sourceTab="Accursed",
  source="Wago 25AZFWqQH",
})

-- Active non-Eternal notifiers used across those three builds.
for _, aura in ipairs({
  {name="Bloodpale", id=681514, sourceTab="Accursed", order=350},
  {name="Sanguine Scripture", id=504264, sourceTab="Sanguine", order=352},
  {name="Gore Tome", id=807788, sourceTab="Fleshweaver", order=354},
  {name="Heartbreak", id=807563, sourceTab="Fleshweaver", order=356},
  {name="Hypovolemic Shock", id=572305, sourceTab="Fleshweaver", order=358},
}) do
  Add({
    name=aura.name, id=aura.id, auraID=aura.id, buffID=aura.id,
    category="proc", order=aura.order, buff=aura.name,
    trackDuration=true, auraTracker=true, trackHUD=false,
    sourceTab=aura.sourceTab, source="Wago 25AZFWqQH",
  })
end

database.bloodmagePackAuditRevision = 1
database.bloodmagePackSource = "25AZFWqQH"
database.bloodmageEternalAuditPolicy = "read-only"

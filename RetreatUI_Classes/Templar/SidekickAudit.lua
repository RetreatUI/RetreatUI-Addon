local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

-- Behavioral reference: https://ascensionsidekick.com/weakauras/w_173c2281
-- RetreatUI already covered nearly the full pack. This overlay keeps only the
-- remaining spec variants and exact active aura IDs; trinkets, racials, food,
-- flask and generic personal-buff reminders are excluded.
local database = RUI:GetClassSpellDatabase("Templar")
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
    if not seen[tostring(value)] then target[#target + 1] = value; seen[tostring(value)] = true end
  end
  return target
end

local function Patch(name, values)
  local record = Find(name)
  if not record then return nil end
  for key, value in pairs(values) do
    if key == "runtimeIDs" or key == "learnedByAny" or key == "aliases" then
      record[key] = MergeList(record[key], value)
    else
      record[key] = value
    end
  end
  return record
end

local function Add(values)
  local existing = Find(values.name)
  if existing then return Patch(values.name, values) end
  database.spells[#database.spells + 1] = values
  return values
end

Patch("Argent Blade", {
  learnedByAny={804929, 807268}, runtimeIDs={804929, 807268},
  source="RetreatUI collector + Sidekick w_173c2281 runtime variants",
})
Patch("Chastise", {
  learnedByAny={503135, 503141, 563269, 563270},
  runtimeIDs={503135, 503141, 563269, 563270},
})
Patch("Righteous Tempest", {
  auraID=748502, buffID=748502,
})

Add({
  name="Oathkeeper Benediction", aliases={"Benediction"},
  id=803375, auraID=803373, buffID=803373,
  learnedByAny={803375, 803373}, runtimeIDs={803375, 803373},
  category="rotation", hudRow="core", order=9, trackCooldown=true,
  buff="Benediction", trackDuration=true, separateAuraTracker=false,
  forceHUD=true, source="Sidekick w_173c2281",
})
Add({
  name="Vindication", id=801446, category="rotation", hudRow="core", order=17,
  trackCooldown=true, forceHUD=true, source="Sidekick w_173c2281",
})
Add({
  name="Divine Stand", id=807729, auraID=807729, buffID=807729,
  category="proc", order=360, buff="Divine Stand",
  trackDuration=true, auraTracker=true, trackHUD=false,
  source="Sidekick w_173c2281",
})
Add({
  name="Holy Stagger", aliases={"Stagger"}, id=803237, auraID=803237, buffID=803237,
  category="proc", order=362, buff="Holy Stagger",
  trackDuration=true, auraTracker=true, trackHUD=false,
  source="Sidekick w_173c2281",
})

database.nativeResource = database.nativeResource or {}
database.nativeResource.spellIDs = MergeList(database.nativeResource.spellIDs, {704576})
database.nativeResource.auraNames = MergeList(database.nativeResource.auraNames, {"Oath Chain"})

database.templarSidekickAuditRevision = 1
database.templarSidekickSource = "w_173c2281"

local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

-- Behavioral reference: https://ascensionsidekick.com/weakauras/w_cb1725f1
-- The package is compact and healer-focused. Its duplicate mana bar and layout
-- are omitted; exact Sands/Aeon states and missing cooldowns are retained.
local database = RUI:GetClassSpellDatabase("Chronomancer")
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

Patch("Fabric of Time", {
  aliases={"Fabric Time Aura"}, learnedByAny={806299, 570177},
  runtimeIDs={806299, 570177}, buff="Fabric of Time",
  auraID=704482, buffID=704482,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Fortify Timeline", {
  learnedByAny={804491, 807455}, runtimeIDs={804491, 807455},
})

Add({
  name="Hasten", id=801304, auraID=801304, buffID=801304,
  learnedByAny={806296, 801304},
  category="utility", hudRow="utility", order=105, trackCooldown=true,
  buff="Hasten", trackDuration=true, separateAuraTracker=false,
  forceHUD=true, source="Sidekick w_cb1725f1",
})
Add({
  name="Time Out!", id=803897, auraID=803897, buffID=803897,
  learnedByAny={806296, 803897},
  category="defensive", hudRow="utility", order=250, trackCooldown=true,
  buff="Time Out!", trackDuration=true, separateAuraTracker=false,
  forceHUD=true, source="Sidekick w_cb1725f1",
})
Add({
  name="Endless Sands: Active", id=806728, auraID=806728, buffID=806728,
  category="proc", order=360, buff="Endless Sands",
  trackDuration=true, auraTracker=true, trackHUD=false,
  source="Sidekick w_cb1725f1",
})

database.nativeResource = database.nativeResource or {}
database.nativeResource.spellIDs = MergeList(database.nativeResource.spellIDs, {
  804488, 806290, 806291, 806292, 806293,
})
database.nativeResource.auraNames = MergeList(database.nativeResource.auraNames, {
  "Aeon of Renewal", "Aeon of Resilience", "Aeon of Protection", "Aeon of Oblivion",
})

database.chronomancerSidekickAuditRevision = 2
database.chronomancerSidekickSource = "w_cb1725f1"

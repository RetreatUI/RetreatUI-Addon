local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

-- Behavioral reference: https://wago.io/dGSLgbxJP
--
-- Only Cultist-specific mechanics that were absent from RetreatUI are ported.
-- The original WeakAura is not embedded or imported, and its racials, items,
-- castbar, mana bar, copied custom-text snippets and party scanners are omitted.
local database = RUI:GetClassSpellDatabase("Cultist")
if type(database) ~= "table" then return end

database.spells = database.spells or {}

local function Normalize(value)
  value = string.lower(tostring(value or "")):gsub("’", "'"):gsub("`", "'")
  return value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
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

local function Merge(record, values)
  for key, value in pairs(values or {}) do record[key] = value end
  return record
end

local function Patch(name, values)
  local record = Find(name)
  if not record then return nil end
  return Merge(record, values)
end

local function Upsert(values)
  local record = Find(values.name)
  if not record then
    record = {}
    database.spells[#database.spells + 1] = record
  end
  return Merge(record, values)
end

-- Main Cultist bar -----------------------------------------------------------
Upsert({
  name="Darkwither", id=502220, category="rotation", hudRow="core", order=12,
  trackCooldown=true, targetDebuff=true, debuff="Darkwither", auraID=620610,
  source="Wago dGSLgbxJP",
})

Upsert({
  name="Blade of the Empire", id=502118, aliases={"Blade of the Empire 2"},
  category="rotation", hudRow="core", order=14, trackCooldown=true,
  trackCharges=true, buff="Blade of the Empire", auraID=502133, buffID=502133,
  trackDuration=true, separateAuraTracker=false, source="Wago dGSLgbxJP",
})

Patch("Gaze of C'Thun", {
  id=502138,
  trackCharges=true,
  source="RetreatUI collector + Wago dGSLgbxJP runtime correction",
})

Upsert({
  name="Gaze of C'Thun: Corruption",
  aliases={"Gaze of C'thun Corruption", "Gaze of C'Thun Corruption"},
  id=502141, category="rotation", hudRow="core", order=82,
  trackCooldown=true, glowWhenAura={"Dark Revelation"},
  source="Wago dGSLgbxJP",
})

Upsert({
  name="Hammer of the Twisting Light", aliases={"Hammer of TL"}, id=806830,
  category="rotation", hudRow="core", order=84, trackCooldown=true,
  source="Wago dGSLgbxJP",
})

Upsert({
  name="Entropic Slam", id=572846, category="rotation", hudRow="core", order=86,
  trackCooldown=true, glowWhenUsable=true, source="Wago dGSLgbxJP",
})

Upsert({
  name="Eldritch Devastation", id=803398, category="offensive", hudRow="core", order=205,
  trackCooldown=true, source="Wago dGSLgbxJP",
})

Upsert({
  name="Dreadnought", id=567549, category="defensive", hudRow="core", order=210,
  trackCooldown=true, buff="Dreadnought", auraID=567549, buffID=567549,
  trackDuration=true, separateAuraTracker=false, source="Wago dGSLgbxJP",
})

Upsert({
  name="Void Shield", id=500715, category="defensive", hudRow="core", order=220,
  trackCooldown=true, buff="Void Shield", auraID=500715, buffID=500715,
  trackDuration=true, separateAuraTracker=false, source="Wago dGSLgbxJP",
})

Upsert({
  name="Herald of the Depths", id=520326, category="defensive", hudRow="core", order=230,
  trackCooldown=true, buff="Herald of the Depths", auraID=520326, buffID=520326,
  trackDuration=true, separateAuraTracker=false, source="Wago dGSLgbxJP",
})

-- Support bar ---------------------------------------------------------------
Upsert({
  name="Malevolence", id=502241, category="utility", hudRow="utility", order=35,
  trackCooldown=true, source="Wago dGSLgbxJP",
})

Upsert({
  name="Eldritch Shock", id=808037, category="control", hudRow="utility", order=40,
  trackCooldown=true, targetDebuff=true, source="Wago dGSLgbxJP",
})

Upsert({
  name="Sanity Tap", id=802575, category="utility", hudRow="utility", order=45,
  trackCooldown=true, glowWhenUsable=true, source="Wago dGSLgbxJP",
})

Upsert({
  name="Sermon of Dread", id=620612, category="control", hudRow="utility", order=75,
  trackCooldown=true, targetDebuff=true, source="Wago dGSLgbxJP",
})

Upsert({
  name="Eldritch Mending", aliases={"Eldtritch Mending"}, id=502228,
  category="ally", hudRow="utility", order=95, trackCooldown=true,
  source="Wago dGSLgbxJP",
})

Upsert({
  name="Test of Pride", id=804412, category="taunt", hudRow="utility", order=150,
  trackCooldown=true, targetDebuff=true, source="Wago dGSLgbxJP",
})

Upsert({
  name="Horrifying Presence", id=500723, category="taunt", hudRow="utility", order=155,
  trackCooldown=true, targetDebuff=true, source="Wago dGSLgbxJP",
})

Upsert({
  name="Isolate", id=800368, category="control", hudRow="utility", order=185,
  trackCooldown=true, targetDebuff=true, source="Wago dGSLgbxJP",
})

Upsert({
  name="Satiate", id=804275, category="utility", hudRow="utility", order=300,
  trackCooldown=true, source="Wago dGSLgbxJP",
})

-- Exact active effects ------------------------------------------------------
Patch("Dark Infusion", {
  buff="Dark Infusion", auraID=570249, buffID=570249,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Forbidden Ritual", {id=502267})
Patch("Eldritch Eye", {
  buff="Eldritch Eye", auraID=802049, buffID=802049,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Rift", {
  buff="Rift", trackDuration=true, separateAuraTracker=false,
})
Patch("End Times", {
  buff="End Times", auraID=805115, buffID=805115,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Abyssal Ward", {
  buff="Abyssal Ward", auraID=804670, buffID=804670,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Voidborne", {
  buff="Voidborne", auraID=681104, buffID=681104,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Embrace the Void", {
  buff="Embrace the Void", auraID=582591, buffID=582591,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Hallucination", {
  buff="Hallucination", trackDuration=true, separateAuraTracker=false,
})
Patch("Blessing of Yogg-Saron", {auraID=806769, buffID=806769})

Upsert({
  name="Shadow of the Void", id=300277, auraID=300277, category="proc", order=5,
  buff="Shadow of the Void", trackDuration=true, auraTracker=true, trackHUD=false,
  source="Wago dGSLgbxJP",
})

Upsert({
  name="Void Monstrosity", id=680556, auraID=680556, category="proc", order=8,
  buff="Void Monstrosity", aliases={"Faceless Monstrosity"},
  trackDuration=true, auraTracker=true, trackHUD=false,
  source="Wago dGSLgbxJP",
})

database.version = math.max(tonumber(database.version) or 1, 4)
database.cultistWagoAuditRevision = 1
database.cultistWagoSource = "dGSLgbxJP"

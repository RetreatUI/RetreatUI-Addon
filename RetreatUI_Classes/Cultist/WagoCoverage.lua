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

local function UpsertHUD(values)
  values.forceHUD = true
  values.trackCooldown = values.trackCooldown ~= false
  return Upsert(values)
end

-- Main Cultist bar -----------------------------------------------------------
UpsertHUD({
  name="Darkwither", id=502220, category="rotation", hudRow="core", order=12,
  targetDebuff=true, debuff="Darkwither", auraID=620610,
  source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Blade of the Empire", id=502118, aliases={"Blade of the Empire 2"},
  learnedBySpellID=502116,
  category="rotation", hudRow="core", order=14, trackCharges=true,
  buff="Blade of the Empire", auraID=502133, buffID=502133,
  trackDuration=true, separateAuraTracker=false, source="Wago dGSLgbxJP",
})

Patch("Gaze of C'Thun", {
  id=502138,
  runtimeID=502138,
  chargeSpellID=502117,
  trackCharges=true,
  forceHUD=true,
  source="RetreatUI collector + Wago dGSLgbxJP runtime correction",
})

UpsertHUD({
  name="Gaze of C'Thun: Corruption",
  aliases={"Gaze of C'thun Corruption", "Gaze of C'Thun Corruption"},
  id=502141, runtimeID=502141,
  learnedByAny={300313, 502141},
  requiresSpellID=502138,
  category="rotation", hudRow="core", order=82,
  glowWhenAura={"Dark Revelation"},
  fallbackIcon="Interface\\icons\\nhi_arcanearrow_Border",
  source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Hammer of the Twisting Light", aliases={"Hammer of TL"}, id=806830,
  category="rotation", hudRow="core", order=84,
  source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Entropic Slam", id=572846, category="rotation", hudRow="core", order=86,
  glowWhenUsable=true, source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Eldritch Devastation", id=803398, category="offensive", hudRow="core", order=205,
  source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Dreadnought", id=567549, category="defensive", hudRow="core", order=210,
  buff="Dreadnought", auraID=567549, buffID=567549,
  trackDuration=true, separateAuraTracker=false, source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Void Shield", id=500715, category="defensive", hudRow="core", order=220,
  buff="Void Shield", auraID=500715, buffID=500715,
  trackDuration=true, separateAuraTracker=false, source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Herald of the Depths", id=520326, category="defensive", hudRow="core", order=230,
  buff="Herald of the Depths", auraID=520326, buffID=520326,
  trackDuration=true, separateAuraTracker=false, source="Wago dGSLgbxJP",
})

-- Support bar ---------------------------------------------------------------
UpsertHUD({
  name="Malevolence", id=502241, category="utility", hudRow="utility", order=35,
  source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Eldritch Shock", id=808037, category="control", hudRow="utility", order=40,
  targetDebuff=true, source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Sanity Tap", id=802575, category="utility", hudRow="utility", order=45,
  glowWhenUsable=true, source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Sermon of Dread", id=620612, category="control", hudRow="utility", order=75,
  targetDebuff=true, source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Eldritch Mending", aliases={"Eldtritch Mending"}, id=502228,
  category="ally", hudRow="utility", order=95,
  source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Test of Pride", id=804412, category="taunt", hudRow="utility", order=150,
  targetDebuff=true, source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Horrifying Presence", id=500723, category="taunt", hudRow="utility", order=155,
  targetDebuff=true, source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Isolate", id=800368, category="control", hudRow="utility", order=185,
  targetDebuff=true, source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Horrorbolt", id=502174, category="utility", hudRow="utility", order=190,
  source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Wrath of the Black Empire", id=502167,
  category="utility", hudRow="utility", order=195,
  source="Wago dGSLgbxJP",
})

UpsertHUD({
  name="Satiate", id=804275, category="utility", hudRow="utility", order=300,
  source="Wago dGSLgbxJP",
})

-- Replacement/runtime corrections ------------------------------------------
Patch("Obliteration Beam", {
  learnedBySpellID=806897,
  runtimeID=805572,
})
Patch("Dreadfall", {
  learnedBySpellID=524876,
  runtimeID=806175,
})
Patch("Empire's Grasp", {
  runtimeID=804533,
})
Patch("Forbidden Ritual", {
  runtimeID=502267,
})

-- Exact active effects ------------------------------------------------------
Patch("Dark Infusion", {
  buff="Dark Infusion", auraID=570249, buffID=570249,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Eldritch Eye", {
  buff="Eldritch Eye", auraID=802049, buffID=802049,
  trackDuration=true, separateAuraTracker=false,
})
Patch("Rift", {
  buff="Rift", auraID=806250, buffID=806250,
  trackDuration=true, separateAuraTracker=false,
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
Patch("Vision of Doom", {
  buff="Vision of Doom", auraID=520388, buffID=520388,
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

Upsert({
  name="Saronite Blessing", id=301262, auraID=600327,
  category="proc", order=12, buff="Saronite Blessing",
  trackDuration=true, auraTracker=true, trackHUD=false,
  source="Wago dGSLgbxJP",
})

Upsert({
  name="Threat Gene", id=500717, auraID=500717,
  category="proc", order=14, buff="Threat Gene",
  trackDuration=true, auraTracker=true, trackHUD=false,
  source="Wago dGSLgbxJP",
})

database.version = math.max(tonumber(database.version) or 1, 4)
database.cultistWagoAuditRevision = 2
database.cultistWagoSource = "dGSLgbxJP"

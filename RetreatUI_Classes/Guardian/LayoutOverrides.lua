local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

local database = RUI:GetClassSpellDatabase("Guardian")
if type(database) ~= "table" then return end
database.spells = database.spells or {}

local function Normalize(value)
  value = string.lower(tostring(value or "")):gsub("’", "'")
  return value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function FindByName(name)
  local wanted = Normalize(name)
  for _, record in ipairs(database.spells) do
    if type(record) == "table" and Normalize(record.name) == wanted then return record end
    for _, alias in ipairs(type(record) == "table" and record.aliases or {}) do
      if Normalize(alias) == wanted then return record end
    end
  end
end

local function EnsureAbility(name, fallbackID)
  local record = FindByName(name)
  if not record then
    record = {
      name = name,
      id = fallbackID,
      aliases = {},
      source = "Guardian live spellbook layout",
    }
    database.spells[#database.spells + 1] = record
  end

  -- Spellbook-name resolution is deliberately primary. Ascension changes the
  -- spell ID between ranks, while the learned spell remains named Ram.
  record.id = tonumber(record.id) or fallbackID
  record.collectorEntryIDFromCollector = record.collectorEntryIDFromCollector or record.collectorEntryID
  record.collectorEntryID = nil
  record.entryID = nil
  record.talentID = nil
  record.forceHUD = true
  return record
end

local ram = EnsureAbility("Ram", 573204)
ram.category = "rotation"
ram.hudRow = "core"
ram.forceMain = true
ram.forceUtility = nil
ram.order = 30
ram.trackCooldown = true
ram.rankSafeByName = true
ram.knownRankIDs = ram.knownRankIDs or {573204}

local raiseShield = FindByName("Raise Shield")
if raiseShield then
  raiseShield.category = "defensive"
  raiseShield.hudRow = "core"
  raiseShield.forceMain = true
  raiseShield.forceUtility = nil
  raiseShield.order = 25
  raiseShield.trackCooldown = true
  raiseShield.trackCharges = true
  raiseShield.buff = "Raise Shield"
  raiseShield.auraID = 500168
  raiseShield.buffID = 500168
  raiseShield.trackDuration = true
  raiseShield.separateAuraTracker = false
end

local brace = FindByName("Brace")
if brace then
  brace.category = "defensive"
  brace.hudRow = "core"
  brace.forceMain = true
  brace.forceUtility = nil
  brace.order = 85
  brace.trackCooldown = true
  brace.buff = "Brace"
  brace.auraID = 800313
  brace.buffID = 800313
  brace.trackDuration = true
  brace.separateAuraTracker = false
end

-- Guardian policy: every learned offensive or defensive cooldown belongs in
-- the main row. Mobility, control, interrupts, taunts, racials and ordinary
-- utility remain in the secondary row. Active-only proc records are untouched.
for _, record in ipairs(database.spells) do
  if type(record) == "table" then
    local name = Normalize(record.name)
    local category = Normalize(record.category)
    local isStandard = string.match(name, "^standard of ") ~= nil
    local hasCooldown = record.trackCooldown ~= false
      or record.trackCharges == true
      or (tonumber(record.cooldownHint) or 0) > 1.5

    if isStandard then
      -- Standards are represented by the active banner uptime tracker instead
      -- of permanent cooldown buttons in either HUD row.
      record.hudRow = nil
      record.trackHUD = false
      record.forceMain = nil
      record.forceUtility = nil
      record.bannerTracker = true
    elseif record.auraTracker ~= true and hasCooldown
      and (category == "offensive" or category == "defensive") then
      record.hudRow = "core"
      record.forceMain = true
      record.forceUtility = nil
    elseif record.auraTracker ~= true and record.hudRow ~= "core"
      and (category == "mobility" or category == "control"
        or category == "interrupt" or category == "taunt"
        or category == "racial" or category == "utility") then
      record.hudRow = "utility"
      record.forceUtility = true
    end
  end
end

database.guardianWAAuditRevision = math.max(tonumber(database.guardianWAAuditRevision) or 0, 4)
database.guardianMainCooldownPolicy = "offensive-and-defensive"
database.guardianBannerTracker = true

-- Guardian/HUD.lua registers a curated layout. Extend that registration with
-- priority names first, then allow every future qualifying cooldown to append
-- automatically according to its data order.
local originalRegister = RUI.RegisterAdvancedClassHUD
if type(originalRegister) ~= "function" then return end

function RUI:RegisterAdvancedClassHUD(className, options)
  self.RegisterAdvancedClassHUD = originalRegister

  if className == "Guardian" then
    options = options or {}
    options.coreOrder = {
      "Shield of Denial", "Reprisal", "Raise Shield", "Ram", "Heavy Blow",
      "Hammer of the Law", "Shoulder the Burden", "Heroic Resolve", "Brace",
    }
    options.strictCoreOrder = false
    options.maxCore = 32
    options.utilityOrder = {
      "Battle Rush", "Advance", "Glorious Arena",
    }
    options.strictUtilityOrder = false
    options.maxUtility = 24
  end

  return originalRegister(self, className, options)
end

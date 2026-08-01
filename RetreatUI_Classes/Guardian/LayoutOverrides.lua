local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

local database = RUI:GetClassSpellDatabase("Guardian")
if type(database) ~= "table" then return end

local function Normalize(value)
  value = string.lower(tostring(value or "")):gsub("’", "'")
  return value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Raise Shield is a high-frequency Vanguard mitigation button with two charges
-- and a short recharge. It belongs in the main rotation row, and its active
-- five-second mitigation remains on the same icon instead of becoming a
-- duplicate proc tracker.
for _, record in ipairs(database.spells or {}) do
  if type(record) == "table" and Normalize(record.name) == "raise shield" then
    record.category = "defensive"
    record.hudRow = "core"
    record.forceMain = true
    record.forceUtility = nil
    record.order = 25
    record.trackCooldown = true
    record.trackCharges = true
    record.buff = "Raise Shield"
    record.auraID = 500168
    record.buffID = 500168
    record.trackDuration = true
    record.separateAuraTracker = false
    break
  end
end

database.guardianWAAuditRevision = math.max(tonumber(database.guardianWAAuditRevision) or 0, 3)

-- Guardian/HUD.lua supplies a strict curated row order. Apply the corrected
-- Vanguard ordering at registration time, then immediately restore the shared
-- registration function so no other class is affected.
local originalRegister = RUI.RegisterAdvancedClassHUD
if type(originalRegister) ~= "function" then return end

function RUI:RegisterAdvancedClassHUD(className, options)
  self.RegisterAdvancedClassHUD = originalRegister

  if className == "Guardian" then
    options = options or {}
    options.coreOrder = {
      "Shield of Denial", "Reprisal", "Raise Shield", "Heavy Blow",
      "Hammer of the Law", "Shoulder the Burden", "Heroic Resolve",
    }
    options.strictCoreOrder = true
    options.maxCore = 7
    options.utilityOrder = {
      "Hold the Line", "Chivalry", "Turn the Blade", "Knight's Calling",
      "Counter Stance", "Unyielding Stand", "Reflective Shield",
      "Press the Attack", "Brace", "Battle Rush", "Advance", "Glorious Arena",
    }
    options.strictUtilityOrder = true
    options.maxUtility = 12
  end

  return originalRegister(self, className, options)
end

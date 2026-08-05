RetreatUI = {
  HUDWidgets = {},
  databases = {
    Bloodmage = {
      spells = {
        {name="Wicked Howl", id=804207, category="offensive", cooldownCategory="offensive", hudRow="core", forceMain=true, trackHUD=true, trackCooldown=true, cooldownHint=180},
        {name="Eternal Resolve", id=801962, category="defensive", cooldownCategory="defensive", hudRow="utility", forceUtility=true, trackHUD=true, trackCooldown=true, cooldownHint=180},
      },
    },
  },
}
local RUI = RetreatUI

function RUI:GetClassSpellDatabase(className) return self.databases[className] end
function RUI:GetClassSpellRecords(className)
  local database = self.databases[className]
  return database and database.spells or {}
end
function RUI:GetDetectedClass() return "Bloodmage" end
function RUI:GetSpellRecordCooldownHint(record) return tonumber(record.cooldownHint) or 0 end
function RUI:ShouldShowSpellRecord(record) return record.disabled ~= true end
function RUI:IsMeaningfulHUDCooldown(record)
  return record.forceHUD == true or record.forceMain == true or record.forceUtility == true
    or record.trackCharges == true or (tonumber(record.cooldownHint) or 0) > 1.5
end
function RUI:IsSpellRecordCastable(record) return record.passive ~= true and record.learned ~= false end
function RUI:GetLiveClassCooldownDefinitions() return {} end

dofile("RetreatUI_Classes/Bloodmage/EternalClassification.lua")
dofile("RetreatUI_Classes/CooldownPolicy.lua")

local byName = {}
for _, record in ipairs(RUI:GetClassSpellRecords("Bloodmage")) do byName[record.name] = record end

local wicked = assert(byName["Wicked Howl"], "Wicked Howl record missing")
assert(wicked.category == "defensive", "Wicked Howl must be defensive")
assert(wicked.cooldownCategory == "defensive", "Wicked Howl cooldown category must be defensive")
assert(wicked.hudRow == "utility" and wicked.forceUtility == true and wicked.forceMain == false,
  "Wicked Howl must be forced to Utility")
assert(wicked.cooldownHint == 120, "Wicked Howl must use the verified 2 minute cooldown")
assert(wicked.targetDebuff == false and wicked.buff == "Wicked Howl" and wicked.trackDuration == true,
  "Wicked Howl must track its self-buff, not a target debuff")

local resolve = assert(byName["Eternal Resolve"], "Eternal Resolve record missing")
assert(resolve.category == "offensive", "Eternal Resolve must be offensive")
assert(resolve.cooldownCategory == "offensive", "Eternal Resolve cooldown category must be offensive")
assert(resolve.hudRow == "core" and resolve.forceMain == true and resolve.forceUtility == false,
  "Eternal Resolve must be forced to Main")
assert(resolve.cooldownHint == 180, "Eternal Resolve must use the verified 3 minute cooldown")

local function Contains(records, name)
  for _, record in ipairs(records or {}) do if record.name == name then return true end end
  return false
end

local main = RUI:GetHUDSpellDefinitions("Bloodmage", "core")
local utility = RUI:GetHUDSpellDefinitions("Bloodmage", "utility")
assert(Contains(main, "Eternal Resolve"), "Eternal Resolve must render on Main")
assert(not Contains(main, "Wicked Howl"), "Wicked Howl must not render on Main")
assert(Contains(utility, "Wicked Howl"), "Wicked Howl must render on Utility")
assert(not Contains(utility, "Eternal Resolve"), "Eternal Resolve must not render on Utility")

print("RetreatUI Eternal Bloodmage classification tests passed")

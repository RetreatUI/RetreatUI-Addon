-- Deterministic policy tests for the RetreatUI class HUD.
-- Run from the repository root with: lua5.1 tests/test_hud_policy.lua

RetreatUI = {
  HUDWidgets = {},
  databases = {},
}
local RUI = RetreatUI

function RUI:NormalizeClassName(name) return name end
function RUI:GetDetectedClass() return self.testClass end
function RUI:GetClassSpellRecords(className)
  return self.databases[className] or {}
end
function RUI:GetSpellRecordCooldownHint(record)
  return tonumber(record and record.cooldownHint) or 0
end
function RUI:ShouldShowSpellRecord(record)
  return type(record) == "table" and record.disabled ~= true
end
function RUI:IsMeaningfulHUDCooldown(record)
  return record.forceHUD == true
    or record.forceMain == true
    or record.forceUtility == true
    or record.trackCharges == true
    or (tonumber(record.cooldownHint) or 0) > 1.5
end
function RUI:IsSpellRecordCastable(record)
  return record.learned ~= false and record.passive ~= true
end
function RUI:GetLiveClassCooldownDefinitions()
  return {
    {name="Explicit Live Safety Net", category="rotation", forceMain=true, trackCooldown=true, cooldownHint=4},
    {name="Generic Live Discovery", category="rotation", trackCooldown=true, cooldownHint=4},
    {name="Live Stance", category="stance", forceMain=true, trackCooldown=true, cooldownHint=3},
  }
end

-- StateTracker supplies the exact per-class state catalogue used by the final
-- action-row guard. Loading it here verifies names, aliases and prefixes.
dofile("RetreatUI_Classes/StateTracker.lua")
dofile("RetreatUI_Classes/CooldownPolicy.lua")
dofile("RetreatUI_Classes/StateHUDGuard.lua")

local function Names(records)
  local names = {}
  for _, record in ipairs(records or {}) do names[#names + 1] = record.name end
  table.sort(names)
  return table.concat(names, "|")
end

local function AssertNames(label, actual, expected)
  local got, want = Names(actual), table.concat(expected, "|")
  if got ~= want then
    error(string.format("%s\nexpected: %s\nactual:   %s", label, want, got), 2)
  end
end

RUI.testClass = "Bloodmage"
RUI.databases.Bloodmage = {
  {name="Three Second Builder", category="rotation", trackCooldown=true, cooldownHint=3},
  {name="Two Second Resource Button", category="resource", trackCooldown=true, cooldownHint=2},
  {name="Four Second Offensive Filler", category="offensive", trackCooldown=true, cooldownHint=4},
  {name="Short Charge Filler", category="rotation", trackCooldown=true, trackCharges=true, cooldownHint=0},
  {name="Aneurysm", category="interrupt", trackCooldown=true, cooldownHint=24},
  {name="Dash", category="mobility", trackCooldown=true, cooldownHint=8},
  {name="Major Burst", category="offensive", trackCooldown=true, cooldownHint=120,
    partyCooldown=true, cooldownCategory="offensive"},
  {name="Major Wall", category="defensive", trackCooldown=true, cooldownHint=120,
    partyCooldown=true, cooldownCategory="defensive"},
  {name="Uncurated Long Offensive", category="offensive", trackCooldown=true, cooldownHint=60},
  {name="Uncurated Long Defensive", category="defensive", trackCooldown=true, cooldownHint=60},
  {name="Cursed Form", category="rotation", trackCooldown=true, cooldownHint=3},
  {name="Mortal Form", category="form", trackCooldown=true, cooldownHint=3},
  {name="Hidden Spell", category="rotation", trackCooldown=true, cooldownHint=3, trackHUD=false},
  {name="Passive Spell", category="rotation", trackCooldown=true, cooldownHint=3, passive=true},
  {name="Unlearned Spell", category="rotation", trackCooldown=true, cooldownHint=3, learned=false},
}

AssertNames("Bloodmage Main Rotation must contain short learned rotational cooldowns only",
  RUI:GetHUDSpellDefinitions("Bloodmage", "core"), {
    "Explicit Live Safety Net",
    "Four Second Offensive Filler",
    "Short Charge Filler",
    "Three Second Builder",
    "Two Second Resource Button",
  })

AssertNames("Bloodmage Utility must contain combat utility, not stances",
  RUI:GetHUDSpellDefinitions("Bloodmage", "utility"), {
    "Aneurysm",
    "Dash",
    "Uncurated Long Defensive",
  })

AssertNames("Bloodmage Offensive row must contain only explicitly curated majors",
  RUI:GetHUDSpellDefinitions("Bloodmage", "offensive"), {
    "Major Burst",
  })

AssertNames("Bloodmage Defensive row must contain only explicitly curated majors",
  RUI:GetHUDSpellDefinitions("Bloodmage", "defensive"), {
    "Major Wall",
  })

local stateCases = {
  ["Sun Cleric"] = "Vow of Light",
  ["Templar"] = "Oath: Righteous Lunge",
  ["Felsworn"] = "Demonfire Pact",
  ["Guardian"] = "Assault Formation",
  ["Tinker"] = "Mode: Assault",
  ["Knight of Xoroth"] = "Pestilence of Death",
  ["Venomancer"] = "Spider Form",
}

for className, spellName in pairs(stateCases) do
  RUI.databases[className] = {
    {name=spellName, category="offensive", trackCooldown=true, cooldownHint=3,
      partyCooldown=true, cooldownCategory="offensive", forceMain=true},
    {name="Real Filler", category="rotation", trackCooldown=true, cooldownHint=3},
  }
  AssertNames(className .. " state activation must never enter Main Rotation",
    RUI:GetHUDSpellDefinitions(className, "core"), {
      "Explicit Live Safety Net",
      "Real Filler",
    })
  AssertNames(className .. " state activation must never enter Offensive Cooldowns",
    RUI:GetHUDSpellDefinitions(className, "offensive"), {})
end

print("RetreatUI HUD policy tests passed")

local function Fail(message)
  io.stderr:write("HUD duplicate test failed: " .. tostring(message) .. "\n")
  os.exit(1)
end

RetreatUI = {
  HUDWidgets = {},
  GetHUDSpellDefinitions = function(_, className, row)
    return {
      {name = "Unleash Pestilence", id = 1001, className = className, row = row},
      {name = "  unleash   pestilence  ", id = 1002, className = className, row = row},
      {name = "Snarl", id = 1003, className = className, row = row},
    }
  end,
  GetTankHUDDefinitions = function(_, className, row)
    return {
      {name = "Unleash Pestilence", id = 1001, className = className, row = row},
      {name = "UNLEASH PESTILENCE", id = 1001, className = className, row = row},
      {name = "Chainwhip", id = 1004, className = className, row = row},
    }
  end,
}

RetreatUI.HUDWidgets.BuildSpellRow = function(_, _, definitions)
  return definitions
end

dofile("RetreatUI/Core/HUDDefinitionDedup.lua")

local classes = {
  "Necromancer", "Pyromancer", "Cultist", "Starcaller", "Sun Cleric",
  "Tinker", "Runemaster", "Primalist", "Reaper", "Venomancer",
  "Chronomancer", "Bloodmage", "Guardian", "Stormbringer", "Felsworn",
  "Barbarian", "Witch Doctor", "Witch Hunter", "Knight of Xoroth",
  "Templar", "Ranger",
}

for _, className in ipairs(classes) do
  local shared = RetreatUI:GetHUDSpellDefinitions(className, "core")
  if #shared ~= 2 then Fail(className .. " shared HUD returned " .. tostring(#shared) .. " definitions") end

  local tank = RetreatUI:GetTankHUDDefinitions(className, "core")
  if #tank ~= 2 then Fail(className .. " tank HUD returned " .. tostring(#tank) .. " definitions") end

  local rendered = RetreatUI.HUDWidgets:BuildSpellRow({}, {
    {name = "Unleash Pestilence", id = 1001},
    {name = "Unleash Pestilence", id = 1001},
    {name = "Snarl", id = 1003},
  })
  if #rendered ~= 2 then Fail(className .. " renderer returned " .. tostring(#rendered) .. " definitions") end
end

local aliases = RetreatUI:DeduplicateHUDDefinitions({
  {name = "Fel Torpedo", aliases = {"Chaos Rush"}},
  {name = "Chaos Rush"},
})
if #aliases ~= 1 then Fail("alias collision was not removed") end

local explicit = RetreatUI:DeduplicateHUDDefinitions({
  {name = "Test Spell", allowDuplicateHUD = true},
  {name = "Test Spell", allowDuplicateHUD = true},
})
if #explicit ~= 2 then Fail("allowDuplicateHUD opt-in was not preserved") end

print("Validated duplicate protection across all 21 class HUD paths")

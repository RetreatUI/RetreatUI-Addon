local RUI = RetreatUI

local COMBAT_CVARS = {
  enableFloatingCombatText = "1",
  floatingCombatTextCombatDamage = "1",
  floatingCombatTextCombatHealing = "1",
  floatingCombatTextCombatLogPeriodicSpells = "1",
  floatingCombatTextCombatDamageAllAutos = "1",
  floatingCombatTextCombatDamageAllSpells = "1",
  floatingCombatTextCombatDamageDirectionalScale = "0",
  floatingCombatTextDodgeParryMiss = "1",
  floatingCombatTextReactives = "1",
  floatingCombatTextAuras = "0",
  floatingCombatTextCombatState = "0",
  floatingCombatTextLowManaHealth = "0",
  floatingCombatTextFriendlyHealers = "0",
}

local FONT_OBJECTS = {
  {name="CombatTextFont", size=20},
  {name="CombatTextFontCrit", size=27},
  {name="NumberFontNormal", size=14},
  {name="NumberFontNormalSmall", size=12},
  {name="NumberFontNormalLarge", size=18},
  {name="NumberFontNormalHuge", size=24},
}

local function StyleFontObject(record, fontPath)
  local object = _G[record.name]
  if not object or type(object.SetFont) ~= "function" then return false end
  local ok = pcall(object.SetFont, object, fontPath, record.size, "OUTLINE")
  if not ok then
    ok = pcall(object.SetFont, object, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TT", record.size, "OUTLINE")
  end
  if ok and object.SetShadowOffset then pcall(object.SetShadowOffset, object, 1, -1) end
  return ok
end

function RUI:ApplyCombatTextStyle()
  local fontPath = self:GetFontPath()
  local cvars, fonts = 0, 0

  if fontPath and fontPath ~= "" then
    _G.DAMAGE_TEXT_FONT = fontPath
  end

  if SetCVar then
    for name, value in pairs(COMBAT_CVARS) do
      local ok = pcall(SetCVar, name, value)
      if ok then cvars = cvars + 1 end
    end
  end

  for _, record in ipairs(FONT_OBJECTS) do
    if StyleFontObject(record, fontPath) then fonts = fonts + 1 end
  end

  -- Conservative native SCT timing: readable without filling the screen.
  _G.COMBAT_TEXT_SCROLLSPEED = 1.45
  _G.COMBAT_TEXT_FADEOUT_TIME = 1.05

  local db = self:EnsureDB()
  db.integrations.combatText = db.integrations.combatText or {}
  db.integrations.combatText.enabled = true
  db.integrations.combatText.version = self.version
  db.integrations.combatText.font = self.fontName

  return true, tostring(fonts) .. " combat fonts and " .. tostring(cvars) .. " combat-text settings applied"
end

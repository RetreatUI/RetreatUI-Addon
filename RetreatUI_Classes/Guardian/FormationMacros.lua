local RUI = RetreatUI
if not RUI then return end

local FORMATION_NAMES = {
  tower = "Tower Formation",
  assault = "Assault Formation",
  line = "Line Formation",
}

local MACROS = {
  {name="RUI Pulverize", ability="Pulverize", formation="tower"},
  {name="RUI Ram", ability="Ram", formation="tower"},
  {name="RUI Reprisal", ability="Reprisal", formation="tower"},
  {name="RUI BroadSweep", ability="Broad Sweep", formation="tower"},
  {name="RUI ShieldChal", ability="Shield Challenge", formation="tower"},
  {name="RUI ShieldDen", ability="Shield of Denial", formation="tower"},
  {name="RUI HeavyBlow", ability="Heavy Blow", formation="tower"},
  {name="RUI Advance", ability="Advance", formation="line"},
  {name="RUI BattleRush", ability="Battle Rush", formation="assault"},
}

local function Print(message)
  message = "|cff33ff77RetreatUI:|r " .. tostring(message or "")
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(message)
  elseif type(print) == "function" then
    print(message)
  end
end

local function Normalize(value)
  value = string.lower(tostring(value or "")):gsub("’", "'")
  return value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function FormationKey(name)
  local normalized = Normalize(name)
  if not string.find(normalized, "formation", 1, true) then return nil end
  if string.find(normalized, "tower", 1, true) then return "tower" end
  if string.find(normalized, "assault", 1, true) then return "assault" end
  if string.find(normalized, "line", 1, true) then return "line" end
  return nil
end

local function DiscoverFormations()
  local result = {all={}}
  if type(GetNumShapeshiftForms) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then
    return result
  end

  local count = tonumber(GetNumShapeshiftForms()) or 0
  for index = 1, count do
    local icon, name, active, castable = GetShapeshiftFormInfo(index)
    result.all[#result.all + 1] = {
      index=index, name=name, icon=icon, active=active, castable=castable,
    }
    local key = FormationKey(name)
    if key and not result[key] then result[key] = index end
  end
  return result
end

local function PrintFormationIndices(forms)
  local parts = {}
  for _, key in ipairs({"tower", "assault", "line"}) do
    if forms[key] then
      parts[#parts + 1] = FORMATION_NAMES[key] .. "=" .. tostring(forms[key])
    end
  end
  if #parts > 0 then
    Print("Detected " .. table.concat(parts, ", ") .. ".")
  else
    Print("No Guardian formations were found through the stance API.")
  end

  if #forms.all > 0 then
    local listed = {}
    for _, form in ipairs(forms.all) do
      listed[#listed + 1] = tostring(form.index) .. ":" .. tostring(form.name or "Unknown")
    end
    Print("Available stance indices: " .. table.concat(listed, ", "))
  end
end

local function MacroBody(ability, formation, index)
  return table.concat({
    "#showtooltip " .. ability,
    "/cast [nostance:" .. tostring(index) .. "] " .. formation,
    "/cast " .. ability,
  }, "\n")
end

local function MacroIcon(ability)
  if type(GetSpellInfo) == "function" then
    local _, _, icon = GetSpellInfo(ability)
    if icon then return icon end
  end
  return "INV_Misc_QuestionMark"
end

local function UpsertMacro(spec, formIndex)
  if type(GetMacroIndexByName) ~= "function" then return false, "macro API unavailable" end
  local body = MacroBody(spec.ability, FORMATION_NAMES[spec.formation], formIndex)
  local icon = MacroIcon(spec.ability)
  local index = tonumber(GetMacroIndexByName(spec.name)) or 0

  if index > 0 and type(EditMacro) == "function" then
    local ok = pcall(EditMacro, index, spec.name, icon, body)
    return ok, ok and "updated" or "update failed"
  end

  if type(CreateMacro) ~= "function" then return false, "CreateMacro unavailable" end
  local ok, created = pcall(CreateMacro, spec.name, icon, body, 1)
  if not ok or not created then return false, "character macro slots may be full" end
  return true, "created"
end

local function CreateFormationMacros()
  if type(InCombatLockdown) == "function" and InCombatLockdown() then
    Print("Formation macros cannot be created while in combat.")
    return
  end

  local forms = DiscoverFormations()
  PrintFormationIndices(forms)
  local created, updated, failed = 0, 0, 0

  for _, spec in ipairs(MACROS) do
    local formIndex = forms[spec.formation]
    if not formIndex then
      failed = failed + 1
      Print("Skipped " .. spec.ability .. ": " .. FORMATION_NAMES[spec.formation] .. " index was not found.")
    else
      local ok, status = UpsertMacro(spec, formIndex)
      if ok and status == "created" then created = created + 1
      elseif ok then updated = updated + 1
      else
        failed = failed + 1
        Print("Could not create " .. spec.name .. ": " .. tostring(status) .. ".")
      end
    end
  end

  Print(string.format("Formation macros complete: %d created, %d updated, %d skipped/failed.", created, updated, failed))
  Print("The first key press changes Formation when required; press again if Ascension's one-second Formation cooldown prevents the ability from firing immediately.")
end

SLASH_RUIGUARDIANFORMATIONS1 = "/ruiforms"
SlashCmdList.RUIGUARDIANFORMATIONS = function()
  PrintFormationIndices(DiscoverFormations())
end

SLASH_RUIGUARDIANFORMATIONMACROS1 = "/ruiformacros"
SlashCmdList.RUIGUARDIANFORMATIONMACROS = CreateFormationMacros

RUI.CreateGuardianFormationMacros = CreateFormationMacros
RUI._guardianFormationMacrosLoaded = true

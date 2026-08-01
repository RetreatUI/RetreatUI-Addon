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

-- Ascension's client uses the legacy CreateMacro signature:
-- CreateMacro(name, iconIndex, body[, perCharacter]). The second argument must
-- be a numeric macro-icon index, not a texture name or spell texture path.
-- #showtooltip replaces icon index 1 with the correct live ability icon.
local SAFE_MACRO_ICON_INDEX = 1

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

local function MacroCounts()
  if type(GetNumMacros) ~= "function" then return 0, 0 end
  local ok, general, character = pcall(GetNumMacros)
  if not ok then return 0, 0 end
  return tonumber(general) or 0, tonumber(character) or 0
end

local function MacroLimits()
  return tonumber(MAX_ACCOUNT_MACROS) or 36, tonumber(MAX_CHARACTER_MACROS) or 18
end

local function PrintMacroCounts(prefix)
  local general, character = MacroCounts()
  local generalLimit, characterLimit = MacroLimits()
  Print(string.format("%s macro slots: General %d/%d, Character %d/%d.",
    tostring(prefix or "Current"), general, generalLimit, character, characterLimit))
end

local function ExistingMacroIndex(name)
  if type(GetMacroIndexByName) ~= "function" then return 0 end
  local ok, index = pcall(GetMacroIndexByName, name)
  return ok and (tonumber(index) or 0) or 0
end

local function TryCreateMacro(name, body, perCharacter)
  if type(CreateMacro) ~= "function" then return false, nil, "CreateMacro unavailable" end

  local beforeGeneral, beforeCharacter = MacroCounts()
  local ok, result
  if perCharacter == nil then
    -- Use the exact three-argument legacy signature for a General macro.
    ok, result = pcall(CreateMacro, name, SAFE_MACRO_ICON_INDEX, body)
  else
    ok, result = pcall(CreateMacro, name, SAFE_MACRO_ICON_INDEX, body, perCharacter)
  end
  local afterGeneral, afterCharacter = MacroCounts()
  local index = ExistingMacroIndex(name)

  if ok and (tonumber(result) or 0) > 0 then
    return true, tonumber(result), nil
  end
  if index > 0 then return true, index, nil end
  if perCharacter and afterCharacter > beforeCharacter then return true, nil, nil end
  if perCharacter == nil and afterGeneral > beforeGeneral then return true, nil, nil end

  return false, nil, ok and "CreateMacro returned no macro index" or tostring(result)
end

local function CreateWithFallback(name, body)
  local errors = {}

  -- Numeric 1 is the native Wrath/Ascension per-character flag. Keep the
  -- boolean attempt for compatible custom branches, then try an exact 3-arg
  -- General macro call as the final fallback.
  for _, perCharacter in ipairs({1, true}) do
    local ok, index, reason = TryCreateMacro(name, body, perCharacter)
    if ok then return true, index, "created-character" end
    errors[#errors + 1] = tostring(reason or "unknown character-macro error")
  end

  local ok, index, reason = TryCreateMacro(name, body, nil)
  if ok then return true, index, "created-general" end
  errors[#errors + 1] = tostring(reason or "unknown general-macro error")
  return false, nil, table.concat(errors, " | ")
end

local function UpsertMacro(spec, formIndex)
  local body = MacroBody(spec.ability, FORMATION_NAMES[spec.formation], formIndex)
  local index = ExistingMacroIndex(spec.name)

  if index > 0 and type(EditMacro) == "function" then
    local ok, result = pcall(EditMacro, index, spec.name, SAFE_MACRO_ICON_INDEX, body)
    if ok then return true, "updated" end
    return false, "EditMacro failed: " .. tostring(result)
  end

  local ok, _, statusOrError = CreateWithFallback(spec.name, body)
  if ok then return true, statusOrError end
  return false, statusOrError
end

local function CreateFormationMacros()
  if type(InCombatLockdown) == "function" and InCombatLockdown() then
    Print("Formation macros cannot be created while in combat.")
    return
  end

  local forms = DiscoverFormations()
  PrintFormationIndices(forms)
  PrintMacroCounts("Before")

  local characterCreated, generalCreated, updated, failed = 0, 0, 0, 0

  for _, spec in ipairs(MACROS) do
    local formIndex = forms[spec.formation]
    if not formIndex then
      failed = failed + 1
      Print("Skipped " .. spec.ability .. ": " .. FORMATION_NAMES[spec.formation] .. " index was not found.")
    else
      local ok, status = UpsertMacro(spec, formIndex)
      if ok and status == "created-character" then
        characterCreated = characterCreated + 1
      elseif ok and status == "created-general" then
        generalCreated = generalCreated + 1
      elseif ok then
        updated = updated + 1
      else
        failed = failed + 1
        Print("Could not create " .. spec.name .. ": " .. tostring(status) .. ".")
      end
    end
  end

  Print(string.format(
    "Formation macros complete: %d Character created, %d General created, %d updated, %d failed.",
    characterCreated, generalCreated, updated, failed))
  PrintMacroCounts("After")
  Print("The first key press changes Formation when required; press again if Ascension's one-second Formation cooldown prevents the ability from firing immediately.")
end

SLASH_RUIGUARDIANFORMATIONS1 = "/ruiforms"
SlashCmdList.RUIGUARDIANFORMATIONS = function()
  PrintFormationIndices(DiscoverFormations())
  PrintMacroCounts("Current")
end

SLASH_RUIGUARDIANFORMATIONMACROS1 = "/ruiformacros"
SlashCmdList.RUIGUARDIANFORMATIONMACROS = CreateFormationMacros

RUI.CreateGuardianFormationMacros = CreateFormationMacros
RUI._guardianFormationMacrosLoaded = true

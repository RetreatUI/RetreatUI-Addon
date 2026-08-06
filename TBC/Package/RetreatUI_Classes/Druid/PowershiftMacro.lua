local RUI = RetreatUI
if not RUI then return end

local _, playerClass = UnitClass("player")
if playerClass ~= "DRUID" then return end

local MACRO_NAME = "RUI Powershift"
local MACRO_ICON = "INV_Misc_QuestionMark"
local MACRO_BODY = "#showtooltip\n/cancelaura Cat Form\n/cast !Cat Form"

local PowershiftMacro = {
    pending = false,
    warnedFull = false,
    name = MACRO_NAME,
    body = MACRO_BODY,
}

local function NormalizeBody(value)
    value = tostring(value or "")
    value = string.gsub(value, "\r\n", "\n")
    value = string.gsub(value, "\r", "\n")
    value = string.gsub(value, "%s+$", "")
    return value
end

local function CanEditMacros()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return false
    end

    return type(GetMacroIndexByName) == "function"
        and type(GetMacroInfo) == "function"
        and type(CreateMacro) == "function"
        and type(EditMacro) == "function"
        and type(GetNumMacros) == "function"
end

function PowershiftMacro:GetIndex()
    if type(GetMacroIndexByName) ~= "function" then
        return 0
    end

    return tonumber(GetMacroIndexByName(MACRO_NAME)) or 0
end

function PowershiftMacro:Ensure(announceReady)
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        self.pending = true
        if announceReady then
            RUI:Print("The powershift macro will be created after combat.")
        end
        return false, "combat"
    end

    if not CanEditMacros() then
        if announceReady then
            RUI:Print("The macro API is not available yet. Try /ruitbc macro after login.")
        end
        return false, "unavailable"
    end

    local index = self:GetIndex()
    if index > 0 then
        local _, _, currentBody = GetMacroInfo(index)
        if NormalizeBody(currentBody) ~= MACRO_BODY then
            EditMacro(index, MACRO_NAME, MACRO_ICON, MACRO_BODY, 1)
            self.pending = false
            RUI:Print("Updated the character macro '" .. MACRO_NAME .. "'.")
            return true, "updated"
        end

        self.pending = false
        if announceReady then
            RUI:Print("The character macro '" .. MACRO_NAME .. "' is ready. Drag it from Macros to your action bar.")
        end
        return true, "ready"
    end

    local _, characterCount = GetNumMacros()
    characterCount = tonumber(characterCount) or 0
    local characterLimit = tonumber(MAX_CHARACTER_MACROS) or 18

    if characterCount >= characterLimit then
        self.pending = false
        if announceReady or not self.warnedFull then
            self.warnedFull = true
            RUI:Print("No free character macro slot. Delete one macro, then use /ruitbc macro.")
        end
        return false, "full"
    end

    local createdIndex = CreateMacro(MACRO_NAME, MACRO_ICON, MACRO_BODY, 1)
    if tonumber(createdIndex) and tonumber(createdIndex) > 0 then
        self.pending = false
        RUI:Print("Created the character macro '" .. MACRO_NAME .. "'. Drag it from Macros to your action bar.")
        return true, "created"
    end

    self.pending = true
    if announceReady then
        RUI:Print("The powershift macro could not be created yet. Try /ruitbc macro again out of combat.")
    end
    return false, "failed"
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(1, function()
                PowershiftMacro:Ensure(false)
            end)
        else
            PowershiftMacro:Ensure(false)
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" and PowershiftMacro.pending then
        PowershiftMacro:Ensure(false)
    end
end)

RUI:RegisterModule("FeralPowershiftMacro", PowershiftMacro)

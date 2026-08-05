local RUI = RetreatUI
if not RUI then return end

local eventFrame = CreateFrame("Frame")
local elapsedSinceUpdate = 0

local function Initialize()
    RUI:ScanSpellbook()

    local module = RUI:GetModule("FeralDruid")
    if module and type(module.Initialize) == "function" then
        module:Initialize()
    end
end

local function Dispatch(event, ...)
    local module = RUI:GetModule("FeralDruid")
    if module and type(module.OnEvent) == "function" then
        module:OnEvent(event, ...)
    end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
eventFrame:RegisterEvent("UNIT_MAXPOWER")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        Initialize()
        return
    end

    if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        RUI:ScanSpellbook()
    end

    Dispatch(event, ...)
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate < 0.08 then return end
    elapsedSinceUpdate = 0

    local module = RUI:GetModule("FeralDruid")
    if module and type(module.OnUpdate) == "function" then
        module:OnUpdate()
    end
end)

SLASH_RETREATUITBC1 = "/ruitbc"
SlashCmdList.RETREATUITBC = function(message)
    local command = string.lower(tostring(message or ""))
    local module = RUI:GetModule("FeralDruid")

    if command == "show" and module and module.root then
        module.forceShown = true
        module.root:Show()
        RUI:Print("Feral HUD forced visible for layout testing.")
    elseif command == "auto" and module then
        module.forceShown = false
        if type(module.UpdateVisibility) == "function" then
            module:UpdateVisibility()
        end
        RUI:Print("Feral HUD returned to automatic Cat Form visibility.")
    else
        RUI:Print("Commands: /ruitbc show, /ruitbc auto")
    end
end

-- RetreatUI native role-check automation.
-- Replaces the AutoQueue WeakAura without chat output or an extra minimap button.

local addonName = ...
local RUI = _G.RetreatUI or {}
_G.RetreatUI = RUI

local AutoRoleCheck = RUI.AutoRoleCheck or {}
RUI.AutoRoleCheck = AutoRoleCheck

local STORAGE_NAME = "RetreatUIAutomationDB"
local DEFAULT_ENABLED = true

local function GetStorage()
    local storage = _G[STORAGE_NAME]
    if type(storage) ~= "table" then
        storage = {}
        _G[STORAGE_NAME] = storage
    end
    if storage.autoAcceptRoleChecks == nil then
        storage.autoAcceptRoleChecks = DEFAULT_ENABLED
    end
    return storage
end

function AutoRoleCheck:IsEnabled()
    return GetStorage().autoAcceptRoleChecks ~= false
end

function AutoRoleCheck:SetEnabled(enabled)
    GetStorage().autoAcceptRoleChecks = enabled and true or false
    if self.checkbox then
        self.checkbox:SetChecked(self:IsEnabled())
    end
end

function AutoRoleCheck:AcceptPendingRoleCheck()
    if not self:IsEnabled() then
        return false
    end
    if type(CompleteLFGRoleCheck) ~= "function" then
        return false
    end
    CompleteLFGRoleCheck(true)
    return true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("LFG_ROLE_CHECK_SHOW")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon == addonName or loadedAddon == "RetreatUI" then
            GetStorage()
        end
        return
    end
    if event == "LFG_ROLE_CHECK_SHOW" then
        AutoRoleCheck:AcceptPendingRoleCheck()
    end
end)

local function CreateOptionsPanel()
    if AutoRoleCheck.panel or type(CreateFrame) ~= "function" then
        return
    end

    local panel = CreateFrame("Frame", "RetreatUIAutomationOptionsPanel")
    panel.name = "RetreatUI - Automation"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("RetreatUI Automation")

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetWidth(560)
    description:SetJustifyH("LEFT")
    description:SetText("Small quality-of-life automations managed directly by RetreatUI.")

    local checkbox = CreateFrame("CheckButton", "RetreatUIAutoAcceptRoleChecksCheckButton", panel, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", description, "BOTTOMLEFT", -4, -18)
    checkbox:SetSize(26, 26)
    checkbox:SetChecked(AutoRoleCheck:IsEnabled())

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    label:SetText("Auto Accept Role Checks")

    local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 30, -2)
    help:SetWidth(520)
    help:SetJustifyH("LEFT")
    help:SetText("Automatically accepts the LFG role check when it appears. Dungeon queue confirmations and invitations are never accepted automatically.")

    checkbox:SetScript("OnClick", function(self)
        AutoRoleCheck:SetEnabled(self:GetChecked())
    end)
    panel:SetScript("OnShow", function()
        checkbox:SetChecked(AutoRoleCheck:IsEnabled())
    end)

    AutoRoleCheck.panel = panel
    AutoRoleCheck.checkbox = checkbox

    if _G.Settings and type(_G.Settings.RegisterCanvasLayoutCategory) == "function" then
        local category = _G.Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        _G.Settings.RegisterAddOnCategory(category)
        AutoRoleCheck.category = category
    elseif type(InterfaceOptions_AddCategory) == "function" then
        InterfaceOptions_AddCategory(panel)
    end
end

CreateOptionsPanel()

local addonName, addonTable = ...

local RUI = addonTable or {}
RetreatUI = RUI

RUI.addonName = addonName or "RetreatUI"
RUI.game = "TBC Classic Anniversary"
RUI.version = (GetAddOnMetadata and GetAddOnMetadata(RUI.addonName, "Version")) or "0.1.0-dev"
RUI.modules = RUI.modules or {}
RUI.frames = RUI.frames or {}
RUI.spellbook = RUI.spellbook or { byName = {}, byID = {} }

function RUI:RegisterModule(name, module)
    if type(name) ~= "string" or type(module) ~= "table" then
        return false
    end

    self.modules[name] = module
    return true
end

function RUI:GetModule(name)
    return self.modules[name]
end

function RUI:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFC79A54RetreatUI TBC:|r " .. tostring(message or ""))
end

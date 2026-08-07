local addonName, addonTable = ...

local RUI = RetreatUI
if not RUI then return end

RUI.classAddonName = addonName or "RetreatUI_Classes"
RUI.classAddon = addonTable or {}

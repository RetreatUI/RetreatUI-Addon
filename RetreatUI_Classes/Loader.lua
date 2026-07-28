local ADDON_NAME = ...
local RUI = RetreatUI
if not RUI then return end

RUI.classesAddonName = ADDON_NAME or "RetreatUI_Classes"
RUI.classesVersion = (GetAddOnMetadata and GetAddOnMetadata(RUI.classesAddonName, "Version")) or "1.0.10"
RUI.classesLoaded = true
RUI.classPackage = RUI.classPackage or {}
RUI.classPackage.name = RUI.classesAddonName
RUI.classPackage.version = RUI.classesVersion

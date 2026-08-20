local RUI = RetreatUI
if not RUI then return end

-- beta.45: the public HUD builder owns WeakAuras only. ElvUI/TurboPlates are profile-owned.
local BaseSaveTrackerSelection = RUI.SaveTrackerSelection
if type(BaseSaveTrackerSelection) == "function" then
  function RUI:SaveTrackerSelection(item, config)
    config = type(config) == "table" and config or {}
    if self.hudBuilderSimpleMode == true then config.destinations = {"hud"} end
    return BaseSaveTrackerSelection(self, item, config)
  end
end

local BaseOpenTrackerEditor = RUI.OpenTrackerEditor
if type(BaseOpenTrackerEditor) == "function" then
  function RUI:OpenTrackerEditor(item, ...)
    local result = BaseOpenTrackerEditor(self, item, ...)
    if self.hudBuilderSimpleMode == true then
      local frame = self.trackerEditorFrame
      if frame and frame.destinationChecks then
        for key, check in pairs(frame.destinationChecks) do
          check:SetChecked(key == "hud" and 1 or nil)
          if key ~= "hud" then check:Hide() end
        end
        if frame.destinationLabel then frame.destinationLabel:SetText("HUD output") end
        if frame.destinationHint then frame.destinationHint:SetText("RetreatUI builds a native WeakAura for this HUD element.") end
      end
    end
    return result
  end
end

function RUI:OpenSimpleHUDBuilder()
  self.hudBuilderSimpleMode = true
  if type(self.OpenTrackerBuilder) == "function" then return self:OpenTrackerBuilder() end
  return false
end

function RUI:CloseSimpleHUDBuilder()
  self.hudBuilderSimpleMode = false
  if self.trackerBuilderFrame then self.trackerBuilderFrame:Hide() end
  if self.trackerEditorFrame then self.trackerEditorFrame:Hide() end
  return true
end

RUI._hudBuilderSimpleModeLoaded = true

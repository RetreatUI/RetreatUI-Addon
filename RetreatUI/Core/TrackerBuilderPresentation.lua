local RUI = RetreatUI
if not RUI then return end

-- Presentation-only polish for the Tracker Builder list. Keep the data model
-- untouched; give metadata enough horizontal room and expose the group layout
-- editor without adding another permanent addon window.
local originalOpen = RUI.OpenTrackerBuilder
if type(originalOpen) ~= "function" then return end

local function EnsureLayoutButton(frame)
  if not frame or frame.trackerLayoutButton then return end
  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  button:SetWidth(108); button:SetHeight(24)
  button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
  button:SetText("HUD Layout")
  button:SetScript("OnClick", function()
    if type(RUI.OpenTrackerGroupLayoutEditor) == "function" then
      RUI:OpenTrackerGroupLayoutEditor()
    end
  end)
  frame.trackerLayoutButton = button
end

function RUI:OpenTrackerBuilder(...)
  local opened = originalOpen(self, ...)
  local frame = self.trackerBuilderFrame
  if frame and type(frame.rows) == "table" then
    for _, row in ipairs(frame.rows) do
      if row.meta then
        row.meta:SetWidth(510)
        if type(row.meta.SetHeight) == "function" then row.meta:SetHeight(14) end
      end
    end
    EnsureLayoutButton(frame)
  end
  if self.RefreshTrackerBuilder then self:RefreshTrackerBuilder() end
  return opened
end

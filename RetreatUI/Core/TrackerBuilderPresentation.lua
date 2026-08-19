local RUI = RetreatUI
if not RUI then return end

-- Presentation-only polish for the Tracker Builder list. Keep the data model
-- untouched; simply give the metadata line enough horizontal room to display
-- multi-type selections such as cooldown + buff + resource without wrapping.
local originalOpen = RUI.OpenTrackerBuilder
if type(originalOpen) ~= "function" then return end

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
  end
  if self.RefreshTrackerBuilder then self:RefreshTrackerBuilder() end
  return opened
end

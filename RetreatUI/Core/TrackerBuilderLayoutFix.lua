local RUI = RetreatUI
if not RUI then return end

-- beta.23 layout-only hotfix.
-- The beta.22 browser created twelve 42px rows inside a 650px frame, which
-- pushed the final row into the footer controls. Keep the same page size and
-- simply give the browser enough vertical space so no catalog entries are
-- hidden or skipped.

local originalOpen = RUI.OpenTrackerBuilder
if type(originalOpen) ~= "function" then return end

function RUI:OpenTrackerBuilder(...)
  local opened = originalOpen(self, ...)
  local frame = self.trackerBuilderFrame
  if frame and type(frame.SetHeight) == "function" then
    frame:SetHeight(710)
  end
  return opened
end

local RUI = RetreatUI
if not RUI then return end

local originalOpen = RUI.OpenTrackerGroupLayoutEditor
if type(originalOpen) ~= "function" then return end

local function ReturnToBuilder(frame)
  if not frame or not frame.returnToBuilder then return end
  frame.returnToBuilder = false
  local builder = RUI.trackerBuilderFrame
  if builder then
    if type(RUI.RefreshTrackerBuilder) == "function" then pcall(RUI.RefreshTrackerBuilder, RUI) end
    builder:Show()
  end
end

local function CloseLayout(frame)
  if not frame then return end
  frame:Hide()
  ReturnToBuilder(frame)
end

function RUI:OpenTrackerGroupLayoutEditor()
  local builder = self.trackerBuilderFrame
  local returnToBuilder = builder and builder.IsShown and builder:IsShown() or false
  if returnToBuilder then builder:Hide() end
  if self.trackerEditorFrame and self.trackerEditorFrame.IsShown and self.trackerEditorFrame:IsShown() then
    self.trackerEditorFrame:Hide()
  end

  local opened = originalOpen(self)
  local frame = self.trackerGroupLayoutEditor
  if not opened or not frame then
    if returnToBuilder and builder then builder:Show() end
    return false
  end

  frame.returnToBuilder = returnToBuilder
  if frame.done and not frame._retreatModalPolish then
    frame.done:SetScript("OnClick", function() CloseLayout(frame) end)
    frame._retreatModalPolish = true
  end
  return true
end

function RUI:ToggleTrackerGroupLayoutEditor()
  local frame = self.trackerGroupLayoutEditor
  if frame and frame.IsShown and frame:IsShown() then
    CloseLayout(frame)
    return false
  end
  return self:OpenTrackerGroupLayoutEditor()
end

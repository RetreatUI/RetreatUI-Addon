local RUI = RetreatUI
if not RUI or RUI._workspaceVisualScaleFix then return end

-- beta.47: keep WoW/ElvUI's global UI scale completely untouched. RetreatUI's
-- large beta.46 workspace used the same tiny control/font metrics as the old
-- compact shell, which made the whole addon look artificially zoomed out.
-- Scale only the RetreatUI workspace, then reduce its internal dimensions so
-- the visible footprint stays comfortably inside the current UIParent.
local WORKSPACE_SCALE = 1.17
local MAX_VISIBLE_WIDTH = 1180
local MAX_VISIBLE_HEIGHT = 720
local EDGE_MARGIN = 36

local function ApplyWorkspaceVisualScale()
  local frame = _G.RetreatUIMainWindow
  if not frame or not UIParent then return false end

  local parentWidth = tonumber(UIParent:GetWidth()) or 1280
  local parentHeight = tonumber(UIParent:GetHeight()) or 800
  local visibleWidth = math.min(MAX_VISIBLE_WIDTH, math.max(900, parentWidth - EDGE_MARGIN))
  local visibleHeight = math.min(MAX_VISIBLE_HEIGHT, math.max(620, parentHeight - EDGE_MARGIN))

  -- On genuinely smaller UI canvases, never force the minimum beyond screen.
  visibleWidth = math.min(visibleWidth, math.max(720, parentWidth - 20))
  visibleHeight = math.min(visibleHeight, math.max(540, parentHeight - 20))

  frame:SetScale(WORKSPACE_SCALE)
  frame:SetSize(visibleWidth / WORKSPACE_SCALE, visibleHeight / WORKSPACE_SCALE)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame._retreatWorkspaceScale = WORKSPACE_SCALE

  if type(frame.RefreshPage) == "function" then
    pcall(frame.RefreshPage, frame)
  end
  return true
end

local BaseOpenRetreatUI = RUI.OpenRetreatUI
if type(BaseOpenRetreatUI) == "function" then
  function RUI:OpenRetreatUI(pageKey)
    local result = BaseOpenRetreatUI(self, pageKey)
    ApplyWorkspaceVisualScale()
    return result
  end
end

-- Exposed only for RetreatUI's own resize/theme refresh paths.
function RUI:ApplyWorkspaceVisualScale()
  return ApplyWorkspaceVisualScale()
end

RUI._workspaceVisualScaleFix = true
RUI.workspaceVisualScaleSchema = 1

local RUI = RetreatUI
if not RUI then return end

local function ResizeNative(frame)
  if not frame or frame:GetName() ~= "RetreatUIMainWindow" then return end
  frame:SetScale(1)
  local sw = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1280
  local sh = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 800
  local width = math.min(1220, math.max(980, sw - 90))
  local height = math.min(740, math.max(620, sh - 90))
  if width > sw - 30 then width = math.max(820, sw - 30) end
  if height > sh - 30 then height = math.max(580, sh - 30) end
  frame:SetSize(width, height)
end

local function ReadableFonts(frame)
  if not frame then return end
  local seen = {}
  local function Visit(node)
    if not node or seen[node] then return end
    seen[node] = true
    if node.GetRegions then
      for _, region in ipairs({node:GetRegions()}) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.GetFont and region.SetFont then
          local path, size, flags = region:GetFont()
          size = tonumber(size)
          if path and size then
            local nextSize = size
            if size <= 9 then nextSize = 11
            elseif size <= 11 then nextSize = size + 1 end
            if nextSize ~= size then pcall(region.SetFont, region, path, nextSize, flags or "") end
          end
        end
      end
    end
    if node.GetChildren then
      for _, child in ipairs({node:GetChildren()}) do Visit(child) end
    end
  end
  Visit(frame)
end

local function Apply()
  local frame = _G.RetreatUIMainWindow
  if not frame then return end
  ResizeNative(frame)
  ReadableFonts(frame)
end

local BaseOpen = RUI.OpenRetreatUI
if type(BaseOpen) == "function" then
  function RUI:OpenRetreatUI(pageKey)
    local ok = BaseOpen(self, pageKey)
    Apply()
    local frame = _G.RetreatUIMainWindow
    if frame and type(frame.ShowPage) == "function" and not frame._nativeVisualWrapped then
      local BaseShowPage = frame.ShowPage
      function frame:ShowPage(key)
        BaseShowPage(self, key)
        ReadableFonts(self)
      end
      frame._nativeVisualWrapped = true
    end
    return ok
  end
end

RUI._workspaceNativeVisuals = true
RUI.workspaceNativeVisualsSchema = 1

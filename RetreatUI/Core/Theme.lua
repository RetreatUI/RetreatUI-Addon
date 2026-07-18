local RUI = RetreatUI

RUI.fontName = "Fira Sans Heavy"
RUI.preferredFontPath = "Interface\\AddOns\\TurboPlates\\Fonts\\FiraSans-Heavy.ttf"

function RUI:GetFontPath()
  if self.themeFontPath and self.themeFontPath ~= "" then return self.themeFontPath end

  if LibStub then
    local ok, media = pcall(LibStub, "LibSharedMedia-3.0", true)
    if ok and media and media.Fetch then
      local fetched = media:Fetch("font", self.fontName, true)
      if fetched and fetched ~= "" then
        self.themeFontPath = fetched
        return fetched
      end
    end
  end

  self.themeFontPath = self.preferredFontPath
  return self.themeFontPath
end

function RUI:GetTheme()
  local info = self:GetClassInfo()
  local colors = info.colors or {accent={1,0.25,0.05}, accent2={0.25,0.95,0.25}, background={0.025,0.018,0.018}}
  return {
    accent = colors.accent,
    accent2 = colors.accent2,
    background = {colors.background[1], colors.background[2], colors.background[3], 0.98},
    sidebar = {0.035, 0.022, 0.022, 0.99},
    panel = {0.055, 0.032, 0.032, 0.98},
    panelSoft = {0.075, 0.043, 0.043, 0.95},
    text = {0.96, 0.96, 0.96, 1},
    muted = {0.62, 0.62, 0.62, 1},
    fontName = self.fontName,
    fontPath = self:GetFontPath(),
  }
end

function RUI:ApplyFont(fontString, size, flags)
  if not fontString then return false end
  if fontString.SetFontObject and GameFontNormal then pcall(fontString.SetFontObject, fontString, GameFontNormal) end
  if not fontString.SetFont then return true end
  local theme = self:GetTheme()
  local ok = pcall(fontString.SetFont, fontString, theme.fontPath, size or 12, flags or "OUTLINE")
  if not ok then
    ok = pcall(fontString.SetFont, fontString, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TT", size or 12, flags or "OUTLINE")
  end
  return ok
end

local FONT_KEYS = {
  font=true, countfont=true, tabfont=true, namefont=true, valuefont=true,
  textfont=true, timefont=true, durationfont=true, stackfont=true,
  aurafont=true, warningfont=true, specialwarningfont=true,
}

function RUI:ForceFontFields(value, seen)
  if type(value) ~= "table" then return 0 end
  seen = seen or {}
  if seen[value] then return 0 end
  seen[value] = true
  local changed = 0

  for key, child in pairs(value) do
    if type(child) == "table" then
      changed = changed + self:ForceFontFields(child, seen)
    elseif type(key) == "string" and type(child) == "string" then
      local lower = string.lower(key)
      if FONT_KEYS[lower] or (string.find(lower, "font", 1, true) and not string.find(lower, "outline", 1, true) and not string.find(lower, "size", 1, true) and not string.find(lower, "path", 1, true) and not string.find(lower, "flag", 1, true)) then
        if child ~= self.fontName then
          value[key] = self.fontName
          changed = changed + 1
        end
      end
    end
  end
  return changed
end

function RUI:SkinFrame(frame, background, border)
  if not frame or not frame.SetBackdrop then return false end
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  local bg = background or self:GetTheme().panel
  local edge = border or {0,0,0,1}
  frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
  return true
end

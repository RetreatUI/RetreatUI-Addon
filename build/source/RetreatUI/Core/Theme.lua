local RUI = RetreatUI

RUI.fontName = "Fira Sans Heavy"
RUI.preferredFontPath = "Interface\\AddOns\\TurboPlates\\Fonts\\FiraSans-Heavy.ttf"

local DEFAULT_THEME = {
  id = "conquest",
  name = "Conquest",
  accent = {1.00, 0.32, 0.06},
  accent2 = {0.32, 0.60, 1.00},
  background = {0.025, 0.018, 0.018},
  installer = {
    title = "RETREATUI",
    subtitle = "Conquest of Azeroth",
    description = "A class-aware interface built around the mechanics that matter.",
    loadout = "Supported class HUD",
    icon = "Interface\\AddOns\\RetreatUI\\Media\\RetreatUI_Logo.tga",
    artwork = "Interface\\AddOns\\RetreatUI\\Media\\RetreatUI_Logo.tga",
    artworkCrop = {0, 1, 0, 1},
    artworkAlpha = 0.72,
  },
}

local RESOURCE_COLORS = {
  MANA = {0.10, 0.42, 0.95},
  RAGE = {0.95, 0.20, 0.06},
  FURY = {1.00, 0.34, 0.04},
  ENERGY = {0.95, 0.82, 0.08},
  FOCUS = {0.28, 0.82, 0.22},
  RUNICPOWER = {0.10, 0.78, 0.92},
}
RUI.resourceColors = RESOURCE_COLORS

local function CopyColor(value, fallback)
  value = type(value) == "table" and value or fallback
  return {value[1] or 1, value[2] or 1, value[3] or 1, value[4]}
end

local function Shade(color, multiplier, addition, alpha)
  multiplier = multiplier or 1
  addition = addition or 0
  return {
    math.min(1, (color[1] or 0) * multiplier + addition),
    math.min(1, (color[2] or 0) * multiplier + addition),
    math.min(1, (color[3] or 0) * multiplier + addition),
    alpha or color[4] or 1,
  }
end

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

function RUI:GetClassTheme(className)
  local info = self:GetClassInfo(className)
  local definition = info and info.definition or {}
  local declared = definition.Theme or definition.themeData or {}
  local legacyInstaller = definition.installerTheme or {}

  local accent = CopyColor(declared.accent or definition.accent, DEFAULT_THEME.accent)
  local accent2 = CopyColor(declared.accent2 or definition.accent2, DEFAULT_THEME.accent2)
  local background = CopyColor(declared.background or definition.background, DEFAULT_THEME.background)
  local declaredInstaller = declared.installer or {}

  local installer = {
    title = declaredInstaller.title or legacyInstaller.title or tostring(info.name or DEFAULT_THEME.installer.title),
    subtitle = declaredInstaller.subtitle or legacyInstaller.subtitle or DEFAULT_THEME.installer.subtitle,
    description = declaredInstaller.description or legacyInstaller.description or DEFAULT_THEME.installer.description,
    loadout = declaredInstaller.loadout or legacyInstaller.loadout or DEFAULT_THEME.installer.loadout,
    icon = declaredInstaller.icon or legacyInstaller.icon or DEFAULT_THEME.installer.icon,
    artwork = declaredInstaller.artwork or declaredInstaller.background or legacyInstaller.background or DEFAULT_THEME.installer.artwork,
    artworkCrop = declaredInstaller.artworkCrop or legacyInstaller.artworkCrop or DEFAULT_THEME.installer.artworkCrop,
    artworkAlpha = declaredInstaller.artworkAlpha or legacyInstaller.artworkAlpha or DEFAULT_THEME.installer.artworkAlpha,
    tagline = declaredInstaller.tagline or legacyInstaller.tagline,
  }

  return {
    id = declared.id or definition.theme or DEFAULT_THEME.id,
    name = declared.name or definition.theme or DEFAULT_THEME.name,
    accent = accent,
    accent2 = accent2,
    background = background,
    sidebar = Shade(background, 1.24, 0.006, 0.995),
    panel = Shade(background, 1.72, 0.012, 0.97),
    panelSoft = Shade(background, 2.25, 0.017, 0.94),
    panelStrong = Shade(background, 0.70, 0.004, 0.985),
    text = {0.96, 0.96, 0.96, 1},
    muted = {0.62, 0.64, 0.68, 1},
    dim = {0.38, 0.40, 0.44, 1},
    success = CopyColor(declared.success, accent),
    danger = {1.00, 0.22, 0.14, 1},
    installer = installer,
    fontName = self.fontName,
    fontPath = self:GetFontPath(),
  }
end

function RUI:GetTheme()
  return self:GetClassTheme()
end

function RUI:GetResourceColor(token)
  token = string.upper(tostring(token or "MANA")):gsub("[^A-Z]", "")
  return RESOURCE_COLORS[token] or RESOURCE_COLORS.MANA
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
        if child ~= self.fontName then value[key], changed = self.fontName, changed + 1 end
      end
    end
  end
  return changed
end

function RUI:SkinFrame(frame, background, border)
  if not frame or not frame.SetBackdrop then return false end
  frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  local bg = background or self:GetTheme().panel
  local edge = border or {0,0,0,1}
  frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
  frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
  return true
end

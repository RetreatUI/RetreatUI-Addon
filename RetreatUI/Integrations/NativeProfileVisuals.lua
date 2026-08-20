local RUI = RetreatUI
if not RUI then return end

local TURBO = {
  focus = {
    width = 142,
    iconW = 22,
    iconH = 18,
    font = 11,
    spacing = 1,
    y = 4,
    maxDebuffs = 6,
    overlapH = 0.76,
    overlapV = 1.10,
  },
  edge = {
    width = 184,
    iconW = 30,
    iconH = 26,
    font = 14,
    spacing = 4,
    y = 10,
    maxDebuffs = 10,
    overlapH = 0.94,
    overlapV = 1.24,
  },
}

local DETAILS = {
  focus = {
    row_height = 18,
    window_scale = 0.96,
    bg_r = 0.018,
    bg_g = 0.020,
    bg_b = 0.024,
    bg_alpha = 0.86,
    desaturated_menu = true,
  },
  edge = {
    row_height = 23,
    window_scale = 1.06,
    bg_r = 0.028,
    bg_g = 0.032,
    bg_b = 0.040,
    bg_alpha = 0.94,
    desaturated_menu = false,
  },
}

local function StyleState(self)
  local db = self:EnsureDB()
  db.profileStyle = db.profileStyle or {}
  return db.profileStyle
end

function RUI:InstallRetreatStyleTurboPlates(styleKey)
  local style = TURBO[styleKey]
  if not style or not self.ProfileStyles or not self.ProfileStyles[styleKey] then
    return false, "Unknown profile style"
  end
  if not self:EnsureAddOnLoaded("TurboPlates") or type(TurboPlatesDB) ~= "table" then
    return false, "TurboPlates is not loaded"
  end

  if type(self.ApplyTurboPlatesRuntime) == "function" then
    local ok, message = self:ApplyTurboPlatesRuntime()
    if not ok then return false, message end
  end
  if type(self.RetireLegacyTrackerDestinationState) == "function" then
    pcall(self.RetireLegacyTrackerDestinationState, self)
  end

  local db = TurboPlatesDB
  db.font = self.fontName or db.font
  db.showCastbar = true
  db.showCastIcon = true
  db.showCastTimer = true
  db.auras = db.auras or {}
  db.auras.showDebuffs = true
  db.auras.maxDebuffs = style.maxDebuffs
  db.auras.debuffIconWidth = style.iconW
  db.auras.debuffIconHeight = style.iconH
  db.auras.debuffFontSize = style.font
  db.auras.debuffStackFontSize = style.font
  db.auras.debuffXOffset = 0
  db.auras.debuffYOffset = style.y
  db.auras.growDirection = "CENTER"
  db.auras.iconSpacing = style.spacing
  db.auras.debuffSortMode = "LEAST_TIME"

  if type(SetCVar) == "function" then
    pcall(SetCVar, "nameplateWidth", tostring(style.width))
    pcall(SetCVar, "nameplateOverlapH", tostring(style.overlapH))
    pcall(SetCVar, "nameplateOverlapV", tostring(style.overlapV))
  end

  local state = StyleState(self)
  state.turboStyle = styleKey
  state.turboWidth = style.width
  return true, self.ProfileStyles[styleKey].label .. " TurboPlates visuals applied"
end

local function DetailsObject()
  local details = _G.Details or _G._detalhes
  return type(details) == "table" and details or nil
end

local function CurrentDetailsProfile(details)
  if type(details.GetCurrentProfile) == "function" then
    local ok, profile = pcall(details.GetCurrentProfile, details)
    if ok and type(profile) == "table" then return profile end
  end
  return nil
end

local function ApplyDetailsStyle(profile, style)
  if type(profile) ~= "table" or type(style) ~= "table" then return end
  profile.skin = "ElvUI"
  profile.row_height = style.row_height
  profile.window_scale = style.window_scale
  profile.bg_r = style.bg_r
  profile.bg_g = style.bg_g
  profile.bg_b = style.bg_b
  profile.bg_alpha = style.bg_alpha
  profile.desaturated_menu = style.desaturated_menu
  profile.hide_in_combat_alpha = 0
end

function RUI:InstallRetreatStyleDetails(styleKey, resolution)
  local style = DETAILS[styleKey]
  if not style or not self.ProfileStyles or not self.ProfileStyles[styleKey] then
    return false, "Unknown profile style"
  end
  if not self.EnsureAddOnLoaded or not self:EnsureAddOnLoaded("Details") then
    return false, "Details is not installed or could not be loaded"
  end
  if type(self.InstallDetailsProfile) ~= "function" then
    return false, "RetreatUI Details compatibility profile is unavailable"
  end

  local ok, message = self:InstallDetailsProfile()
  if not ok then return false, message end

  local details = DetailsObject()
  if details then
    local profile = CurrentDetailsProfile(details)
    if profile then ApplyDetailsStyle(profile, style) end
    if type(details.RefreshMainWindow) == "function" then
      pcall(details.RefreshMainWindow, details, -1, true)
    end
  end

  local state = StyleState(self)
  state.detailsStyle = styleKey
  state.detailsResolution = resolution or (self.GetRetreatStyleResolution and self:GetRetreatStyleResolution())
  state.detailsCompatibility = true
  state.detailsRowHeight = style.row_height
  return true, self.ProfileStyles[styleKey].label .. " Details visuals applied"
end

RUI._nativeProfileVisualsLoaded = true
RUI.nativeProfileVisualsSchema = 1

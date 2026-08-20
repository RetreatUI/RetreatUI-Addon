local RUI = RetreatUI
if not RUI then return end

-- beta.45 profile packs. UI profiles and HUD/WeakAuras are intentionally separate.
RUI.ProfileStyles = {
  focus = {
    key = "focus",
    label = "Retreat Focus",
    subtitle = "Compact, centered and performance-first",
    description = "A tight competitive layout with compact unit frames, restrained spacing and dense combat information.",
  },
  edge = {
    key = "edge",
    label = "Retreat Edge",
    subtitle = "Open, readable and information-rich",
    description = "A roomier layout with stronger separation between combat elements and more breathing room around nameplates.",
  },
}

local function Copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}
  seen[value] = result
  for key, item in pairs(value) do result[Copy(key, seen)] = Copy(item, seen) end
  return result
end

local function ScreenPreset()
  local height = GetScreenHeight and tonumber(GetScreenHeight()) or 1080
  return height and height >= 1200 and "1440p" or "1080p"
end

local function StyleState()
  local db = RUI:EnsureDB()
  db.profileStyle = db.profileStyle or {}
  return db.profileStyle
end

function RUI:GetRetreatStyleKey()
  local state = StyleState()
  return self.ProfileStyles[state.key] and state.key or nil
end

function RUI:GetRetreatStyleInfo(key)
  key = key or self:GetRetreatStyleKey()
  return key and self.ProfileStyles[key] or nil
end

function RUI:GetRetreatStyleResolution()
  local state = StyleState()
  return state.resolution or ScreenPreset()
end

function RUI:SetRetreatStyle(key, resolution)
  if not self.ProfileStyles[key] then return false, "Unknown RetreatUI profile style" end
  local state = StyleState()
  state.key = key
  state.resolution = resolution or ScreenPreset()
  state.version = self.version
  return true, state
end

local function DecodeElvPayload(payload)
  if type(payload) ~= "string" or payload == "" then return nil, "profile payload missing" end
  if not ElvUI then return nil, "ElvUI is not loaded" end
  local E = unpack(ElvUI)
  if not E or type(E.GetModule) ~= "function" then return nil, "ElvUI engine unavailable" end
  local okModule, distributor = pcall(E.GetModule, E, "Distributor", true)
  if not okModule or not distributor or type(distributor.Decode) ~= "function" then
    return nil, "ElvUI Distributor is unavailable"
  end
  local ok, profileType, _, data = pcall(distributor.Decode, distributor, payload)
  if not ok or type(data) ~= "table" then return nil, "ElvUI profile decode failed" end
  return {engine=E, distributor=distributor, profileType=profileType or "profile", data=data}
end

local function ApplyPrivatePayload(distributor, payload)
  if type(payload) ~= "string" or payload == "" then return true end
  local ok, profileType, _, data = pcall(distributor.Decode, distributor, payload)
  if not ok or type(data) ~= "table" then return false end
  if type(distributor.SetImportedProfile) == "function" then
    return pcall(distributor.SetImportedProfile, distributor, profileType or "private", "RetreatUI", data, true)
  end
  return false
end

local function EdgeFallback(base)
  local profile = Copy(base or {})
  profile.movers = profile.movers or {}
  profile.movers.ElvUF_PlayerMover = "BOTTOM,ElvUIParent,BOTTOM,-335,360"
  profile.movers.ElvUF_TargetMover = "BOTTOM,ElvUIParent,BOTTOM,335,360"
  profile.movers.ElvUF_PlayerCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,-335,330"
  profile.movers.ElvUF_TargetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,335,330"
  profile.movers.ElvUF_PartyMover = "TOPLEFT,ElvUIParent,BOTTOMLEFT,270,670"
  profile.unitframe = profile.unitframe or {}; profile.unitframe.units = profile.unitframe.units or {}
  local player = profile.unitframe.units.player or {}; profile.unitframe.units.player = player
  local target = profile.unitframe.units.target or {}; profile.unitframe.units.target = target
  player.width, player.height = 275, 50
  target.width, target.height = 275, 50
  if player.castbar then player.castbar.width = 275 end
  if target.castbar then target.castbar.width = 275 end
  profile.chat = profile.chat or {}; profile.chat.panelWidth = 380
  profile.general = profile.general or {}; profile.general.minimap = profile.general.minimap or {}; profile.general.minimap.size = 215
  return profile
end

function RUI:InstallRetreatStyleElvUI(styleKey, resolution)
  local style = self.ProfileStyles[styleKey]
  if not style then return false, "Unknown profile style" end
  if not self:EnsureAddOnLoaded("ElvUI") then return false, "ElvUI is not loaded" end
  local payloads = self.ProfileImportPayloads and self.ProfileImportPayloads[styleKey]
  local payload = payloads and payloads.elvui and payloads.elvui[resolution]
  local decoded, decodeReason = payload and DecodeElvPayload(payload.profile)

  if decoded and type(decoded.distributor.SetImportedProfile) == "function" then
    local ok, err = pcall(decoded.distributor.SetImportedProfile, decoded.distributor,
      decoded.profileType or "profile", "RetreatUI", decoded.data, true)
    if ok then
      ApplyPrivatePayload(decoded.distributor, payload.private)
      self.ElvUIProfile = Copy(decoded.data)
      self.ElvUIProfile.nameplates = self.ElvUIProfile.nameplates or {}
      self.ElvUIProfile.nameplates.enable = false
      if decoded.engine and decoded.engine.data and type(decoded.engine.data.SetProfile) == "function" then
        pcall(decoded.engine.data.SetProfile, decoded.engine.data, "RetreatUI")
      end
      if type(self.DisableElvUINamePlates) == "function" then pcall(self.DisableElvUINamePlates, self) end
      if type(self.RepairElvUIAuraProfiles) == "function" then pcall(self.RepairElvUIAuraProfiles, self, false) end
      if decoded.engine and type(decoded.engine.UpdateAll) == "function" then pcall(decoded.engine.UpdateAll, decoded.engine, true) end
      return true, style.label .. " ElvUI profile imported"
    end
    decodeReason = tostring(err)
  end

  local original = self.ElvUIProfile
  if styleKey == "edge" then self.ElvUIProfile = EdgeFallback(original) else self.ElvUIProfile = Copy(original) end
  local ok, message = self:InstallElvUIProfile()
  if not ok then self.ElvUIProfile = original; return false, message or decodeReason end
  return true, style.label .. " ElvUI profile installed (CoA compatibility mode)"
end

function RUI:InstallRetreatStyleDetails(styleKey, resolution)
  local payloads = self.ProfileImportPayloads and self.ProfileImportPayloads[styleKey]
  local payload = payloads and payloads.details and payloads.details[resolution]
  if type(payload) == "string" and payload ~= "" and DetailsAPI and type(DetailsAPI.ImportProfile) == "function" then
    local ok, result = pcall(DetailsAPI.ImportProfile, payload, "RetreatUI")
    if ok and result ~= false then return true, "RetreatUI Details profile imported" end
  end
  if type(self.InstallModule) == "function" then
    local result = self:InstallModule("details")
    if type(result) == "table" and result.state == "success" then return true, result.message or "Details profile installed" end
  end
  return false, "Details profile could not be imported"
end

local TURBO_STYLE = {
  focus = {width=150, iconW=24, iconH=20, font=12, spacing=2, y=5, overlapH=0.80, overlapV=1.15},
  edge  = {width=168, iconW=28, iconH=24, font=13, spacing=3, y=8, overlapH=0.88, overlapV=1.20},
}

function RUI:InstallRetreatStyleTurboPlates(styleKey)
  if not self.ProfileStyles[styleKey] then return false, "Unknown profile style" end
  if not self:EnsureAddOnLoaded("TurboPlates") or type(TurboPlatesDB) ~= "table" then
    return false, "TurboPlates is not loaded"
  end
  if type(self.ApplyTurboPlatesRuntime) == "function" then
    local ok, message = self:ApplyTurboPlatesRuntime()
    if not ok then return false, message end
  end
  local style = TURBO_STYLE[styleKey]
  local db = TurboPlatesDB
  db.font = self.fontName or db.font
  db.showCastbar, db.showCastIcon, db.showCastTimer = true, true, true
  db.auras = db.auras or {}
  db.auras.showDebuffs = true
  db.auras.maxDebuffs = math.max(tonumber(db.auras.maxDebuffs) or 0, 8)
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
  local state = StyleState(); state.turboStyle = styleKey
  return true, self.ProfileStyles[styleKey].label .. " TurboPlates profile applied"
end

local function AddResult(results, label, ok, message)
  results[#results + 1] = {label=label, ok=ok == true, message=message}
end

function RUI:InstallRetreatStyle(styleKey, resolution)
  if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before installing a RetreatUI profile" end
  if not self.ProfileStyles[styleKey] then return false, "Unknown RetreatUI profile style" end
  resolution = resolution or ScreenPreset()
  self:SetRetreatStyle(styleKey, resolution)

  local results = {}
  local okElv, msgElv = self:InstallRetreatStyleElvUI(styleKey, resolution); AddResult(results, "ElvUI", okElv, msgElv)
  local okTurbo, msgTurbo = self:InstallRetreatStyleTurboPlates(styleKey); AddResult(results, "TurboPlates", okTurbo, msgTurbo)
  local okDetails, msgDetails = self:InstallRetreatStyleDetails(styleKey, resolution); AddResult(results, "Details", okDetails, msgDetails)

  if type(self.SyncThemeFonts) == "function" then pcall(self.SyncThemeFonts, self) end
  if type(self.RunFrameCleanupNow) == "function" then pcall(self.RunFrameCleanupNow, self) end

  local state = StyleState()
  state.installedVersion = self.version
  state.installedAt = time and time() or 0
  state.requiresReload = true
  state.results = results

  local success = okElv and okTurbo
  local style = self.ProfileStyles[styleKey]
  if success then
    return true, style.label .. " applied. WeakAuras were not imported; build your HUD from the HUD page. Reload recommended.", results
  end
  return false, style.label .. " was only partially applied. Open the profile page for component status.", results
end

function RUI:ReapplyRetreatStyle()
  local key = self:GetRetreatStyleKey()
  if not key then return false, "Choose a RetreatUI profile first" end
  return self:InstallRetreatStyle(key, self:GetRetreatStyleResolution())
end

RUI._profilePacksLoaded = true
RUI.profilePackSchema = 1

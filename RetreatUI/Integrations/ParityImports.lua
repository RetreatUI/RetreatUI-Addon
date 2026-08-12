local RUI = RetreatUI
if not RUI then return end

local PROFILE_NAME = "RetreatUI"

local function InCombat()
  return InCombatLockdown and InCombatLockdown()
end

local function Loaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    local ok, value = pcall(C_AddOns.IsAddOnLoaded, name)
    if ok then return value == true end
  end
  if IsAddOnLoaded then
    local ok, value = pcall(IsAddOnLoaded, name)
    if ok then return value == true end
  end
  return false
end

local function Remember(component, resolution)
  if type(RUI.EnsureDB) ~= "function" then return end
  local db = RUI:EnsureDB()
  db.parity = db.parity or {}
  db.parity[component] = {
    version = RUI.version,
    resolution = resolution or "1440p",
    installed = true,
  }
end

local MEDIA_NAMES = {
  ["Naowh"] = "RetreatUI",
  ["NaowhLeft"] = "RetreatUI Left",
  ["NaowhRight"] = "RetreatUI Right",
  ["NaowhGradient"] = "RetreatUI Gradient",
  ["NaowhReverseGradient"] = "RetreatUI Reverse Gradient",
  ["NaowhMouseover"] = "RetreatUI Mouseover",
  ["NaowhMouseoverArrows"] = "RetreatUI Mouseover Arrows",
}

local function NeutralizeMediaNames(value, seen)
  if type(value) ~= "table" then return end
  seen = seen or {}
  if seen[value] then return end
  seen[value] = true

  for key, item in pairs(value) do
    if type(item) == "string" and MEDIA_NAMES[item] then
      value[key] = MEDIA_NAMES[item]
    elseif type(item) == "table" then
      NeutralizeMediaNames(item, seen)
    end
  end
end

function RUI:IsParityImportReady(component)
  local profiles = self.parityProfiles or {}
  if component == "elvui" then
    return ElvUI ~= nil and type(profiles.elvui) == "table" and type(profiles.elvui1080p) == "table"
  elseif component == "bigwigs" then
    return type(BigWigsAPI) == "table" and type(BigWigsAPI.RegisterProfile) == "function"
      and type(profiles.bigwigs) == "table" and type(profiles.bigwigs1080p) == "table"
  elseif component == "details" then
    return type(DetailsAPI) == "table" and type(DetailsAPI.ImportProfile) == "function"
      and type(profiles.details) == "string" and profiles.details ~= ""
  elseif component == "turboplates" then
    return type(self.ApplyParityTurboPlatesProfile) == "function"
  elseif component == "generalwa" then
    return type(WeakAuras) == "table" and type(WeakAuras.Import) == "function"
      and self.parityWeakAuras and type(self.parityWeakAuras.core) == "string"
      and self.parityWeakAuras.core:sub(1, 6) == "!WA:2!"
  elseif component == "classwa" then
    local className = type(self.GetDetectedClass) == "function" and self:GetDetectedClass() or nil
    if self.NormalizeClassName and className then className = self:NormalizeClassName(className) or className end
    return type(WeakAuras) == "table" and type(WeakAuras.Import) == "function"
      and self.parityWeakAuras and type(self.parityWeakAuras.classes) == "table"
      and className and type(self.parityWeakAuras.classes[className]) == "string"
  end
  return false
end

function RUI:ImportParityElvUI(resolution)
  if InCombat() then return false, "Leave combat before importing ElvUI." end
  if not self:IsParityImportReady("elvui") then return false, "ElvUI parity profile is not ready." end

  local E = unpack(ElvUI)
  if not E or not E.GetModule then return false, "ElvUI is not available." end
  local DI = E:GetModule("Distributor")
  if not DI or not DI.Decode or not DI.SetImportedProfile then return false, "ElvUI Distributor is not available." end

  local payload = resolution == "1080p" and self.parityProfiles.elvui1080p or self.parityProfiles.elvui
  local ok, profileType, _, data = pcall(DI.Decode, DI, payload[1])
  if not ok or not profileType or type(data) ~= "table" then return false, "ElvUI profile decode failed." end

  NeutralizeMediaNames(data)
  local imported, err = pcall(DI.SetImportedProfile, DI, profileType, PROFILE_NAME, data, true)
  if not imported then return false, tostring(err or "ElvUI profile import failed.") end

  if E.SetupCVars then pcall(E.SetupCVars, E, true) end
  E.data = E.data or {}
  E.data.global = E.data.global or {}
  E.data.global.general = E.data.global.general or {}
  E.data.global.general.mapAlphaWhenMoving = 0.4
  E.data.global.general.UIScale = payload[2]
  E.data.global.general.WorldMapCoordinates = E.data.global.general.WorldMapCoordinates or {}
  E.data.global.general.WorldMapCoordinates.position = "BOTTOM"

  E.private = E.private or {}
  E.private.general = E.private.general or {}
  E.private.general.chatBubbleFont = "RetreatUI"
  E.private.general.chatBubbleFontOutline = "OUTLINE"
  E.private.general.chatBubbleFontSize = 10
  E.private.general.chatBubbles = "backdrop_noborder"
  E.private.general.dmgfont = "GothamNarrowUltra"
  E.private.general.glossTex = "RetreatUI Left"
  E.private.general.minimap = E.private.general.minimap or {}
  E.private.general.minimap.hideTracking = true
  E.private.general.namefont = "RetreatUI"
  E.private.general.normTex = "RetreatUI Left"
  E.private.nameplates = E.private.nameplates or {}
  E.private.nameplates.enable = false

  Remember("elvui", resolution)
  return true, "ElvUI profile imported."
end

function RUI:ImportParityDetails()
  if InCombat() then return false, "Leave combat before importing Details." end
  if not self:IsParityImportReady("details") then return false, "Details parity profile is not ready." end
  local ok, err = pcall(DetailsAPI.ImportProfile, self.parityProfiles.details, PROFILE_NAME)
  if not ok then return false, tostring(err or "Details profile import failed.") end
  Remember("details")
  return true, "Details profile imported."
end

function RUI:ImportParityBigWigs(resolution)
  if InCombat() then return false, "Leave combat before importing BigWigs." end
  if not self:IsParityImportReady("bigwigs") then return false, "BigWigs parity profile is not ready." end

  local payload = resolution == "1080p" and self.parityProfiles.bigwigs1080p or self.parityProfiles.bigwigs
  local ok, err = pcall(BigWigsAPI.RegisterProfile, "RetreatUI", payload[1], PROFILE_NAME, function(success)
    if success then Remember("bigwigs", resolution) end
  end)
  if not ok then return false, tostring(err or "BigWigs profile import failed.") end
  return true, "BigWigs profile import started."
end

function RUI:ImportParityGeneralWeakAuras()
  if InCombat() then return false, "Leave combat before importing WeakAuras." end
  if not self:IsParityImportReady("generalwa") then return false, "General WeakAuras parity payload is not ready." end
  local ok, err = pcall(WeakAuras.Import, self.parityWeakAuras.core)
  if not ok then return false, tostring(err or "WeakAuras import failed.") end
  return true, "WeakAuras import window opened for General Core."
end

function RUI:ImportParityClassWeakAuras()
  if InCombat() then return false, "Leave combat before importing WeakAuras." end
  if not self:IsParityImportReady("classwa") then return false, "This CoA class parity WeakAura is not mapped yet." end

  local className = self:GetDetectedClass()
  if self.NormalizeClassName then className = self:NormalizeClassName(className) or className end
  local payload = self.parityWeakAuras.classes[className]
  local ok, err = pcall(WeakAuras.Import, payload)
  if not ok then return false, tostring(err or "Class WeakAuras import failed.") end
  return true, "WeakAuras import window opened for " .. tostring(className) .. "."
end

function RUI:ImportParityTurboPlates(resolution)
  if InCombat() then return false, "Leave combat before importing TurboPlates." end
  if not self:IsParityImportReady("turboplates") then return false, "TurboPlates parity mapping is not complete yet." end
  return self:ApplyParityTurboPlatesProfile(resolution)
end

RUI._parityImportsLoaded = true

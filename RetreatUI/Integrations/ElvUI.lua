local RUI = RetreatUI

local function SafeHide(frame)
  if not frame then return false end
  if frame.Hide then pcall(frame.Hide, frame) end
  if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
  return true
end

local ELVUI_NAMEPLATE_ADDONS = {
  "ElvUI_NamePlates",
  "ElvUI_Nameplates",
  "ElvUINamePlates",
}

local function CurrentElvUIProfile(E)
  if E and E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok and type(value) == "string" and value ~= "" then return value end
  end
  return "RetreatUI"
end

local function DisablePrivateNamePlates(profile)
  if type(profile) ~= "table" then return false end
  if type(profile.nameplates) ~= "table" then profile.nameplates = {} end
  profile.nameplates.enable = false
  return true
end

function RUI:DisableElvUINamePlates()
  local changed = false
  local addonDisableOK = true

  -- Some Ascension ElvUI packages ship nameplates as a separate addon. Mark it
  -- disabled persistently; the installer's final reload then removes it fully.
  for _, addonName in ipairs(ELVUI_NAMEPLATE_ADDONS) do
    if GetAddOnInfo and GetAddOnInfo(addonName) then
      if DisableAddOn then
        local ok = pcall(DisableAddOn, addonName)
        changed = ok or changed
        if not ok then addonDisableOK = false end
      else
        addonDisableOK = false
      end
    end
  end

  local E = ElvUI and unpack(ElvUI)
  local profileName = CurrentElvUIProfile(E)

  -- Other builds bundle NamePlates inside ElvUI. Disable the private module
  -- setting in both live and persisted profile databases. Ascension ElvUI
  -- forks have used both public and private storage for this toggle.
  if E and E.private then changed = DisablePrivateNamePlates(E.private) or changed end
  if E and E.db then changed = DisablePrivateNamePlates(E.db) or changed end
  if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
    local publicProfile = ElvDB.profiles[profileName] or ElvDB.profiles.RetreatUI
    if publicProfile then changed = DisablePrivateNamePlates(publicProfile) or changed end
  end
  if type(ElvPrivateDB) == "table" then
    ElvPrivateDB.profiles = ElvPrivateDB.profiles or {}
    local privateProfile = profileName
    if type(ElvPrivateDB.profileKeys) == "table" and UnitName then
      local character = UnitName("player")
      local realm = GetRealmName and GetRealmName()
      local key = character and realm and (character .. " - " .. realm) or character
      privateProfile = (key and ElvPrivateDB.profileKeys[key]) or privateProfile
    end
    privateProfile = privateProfile or "RetreatUI"
    ElvPrivateDB.profiles[privateProfile] = ElvPrivateDB.profiles[privateProfile] or {}
    changed = DisablePrivateNamePlates(ElvPrivateDB.profiles[privateProfile]) or changed
  end

  -- Stop an already loaded ElvUI NamePlates module immediately where the
  -- client exposes a normal Ace module Disable method.
  if E and E.GetModule then
    local module
    local ok, value = pcall(E.GetModule, E, "NamePlates", true)
    if ok then module = value end
    if not module then
      ok, value = pcall(E.GetModule, E, "Nameplates", true)
      if ok then module = value end
    end
    if module and module.Disable then
      local disabled = pcall(module.Disable, module)
      changed = disabled or changed
    end
  end

  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.nameplatesDisabled = true
  db.integrations.elvui.nameplateAddonDisableOK = addonDisableOK
  db.integrations.elvui.nameplatesDisabledVersion = self.version

  return true, changed
    and "ElvUI NamePlates disabled; TurboPlates will be the only active nameplate addon after reload"
    or "ElvUI NamePlates setting disabled for TurboPlates"
end

function RUI:AreElvUINamePlatesDisabled()
  local E = ElvUI and unpack(ElvUI)
  if E and E.private and E.private.nameplates and E.private.nameplates.enable ~= false then return false end
  if E and E.db and E.db.nameplates and E.db.nameplates.enable ~= false then return false end

  local db = self:EnsureDB()
  return db.integrations and db.integrations.elvui
    and db.integrations.elvui.nameplatesDisabled == true
    and db.integrations.elvui.nameplateAddonDisableOK ~= false
end

function RUI:RemoveRightLootTradeChat()
  local removed = false

  -- Close custom chat windows named Loot/Trade (and common variants).
  if type(NUM_CHAT_WINDOWS) == "number" and type(GetChatWindowInfo) == "function" then
    for index = NUM_CHAT_WINDOWS, 1, -1 do
      local name = GetChatWindowInfo(index)
      local lower = type(name) == "string" and string.lower(name) or ""
      if lower ~= "" and (string.find(lower, "loot", 1, true) or string.find(lower, "trade", 1, true)) then
        local frame = _G["ChatFrame" .. index]
        if frame then
          if type(FCF_UnDockFrame) == "function" then pcall(FCF_UnDockFrame, frame) end
          if type(FCF_Close) == "function" then
            pcall(FCF_Close, frame)
          else
            SafeHide(frame)
          end
          removed = true
        end
      end
    end
  end

  -- ElvUI's right chat container can remain visible even after its chat tab is closed.
  local rightFrames = {
    "RightChatPanel",
    "RightChatPanelTab",
    "RightChatPanelToggleButton",
    "RightChatPanelDataPanel",
    "RightChatDataPanel",
  }
  for _, globalName in ipairs(rightFrames) do
    if SafeHide(_G[globalName]) then removed = true end
  end

  return removed
end


local PARTY_MOVER_OLD = "TOPLEFT,ElvUIParent,BOTTOMLEFT,24,603"
local PARTY_MOVER_INTERMEDIATE = "TOPLEFT,ElvUIParent,BOTTOMLEFT,250,603"
local PARTY_MOVER_FALLBACK = "TOPLEFT,ElvUIParent,BOTTOMLEFT,430,603"
local PARTY_MOVER_Y = 603
local PARTY_PLAYER_GAP = 28
local TARGET_TARGET_MOVER_OLD = "BOTTOM,ElvUIParent,BOTTOM,310,323"
local TARGET_TARGET_MOVER_FALLBACK = "BOTTOM,ElvUIParent,BOTTOM,508,350"
local TARGET_TARGET_GAP = 8
local TARGET_TARGET_WIDTH = 120
local TARGET_TARGET_HEIGHT = 24
local HUD_POLISH_REVISION = 2
local PLAYER_CASTBAR_MOVER = "BOTTOM,ElvUIParent,BOTTOM,-310,326"
local TARGET_CASTBAR_MOVER = "BOTTOM,ElvUIParent,BOTTOM,310,326"
local ACTIONBAR3_MOVER = "BOTTOM,ElvUIParent,BOTTOM,0,26"
local STANCE_BAR_MOVER = "BOTTOM,ElvUIParent,BOTTOM,-310,8"

local function NumberOr(value, fallback)
  return type(value) == "number" and value or fallback
end

local function BuildPartyMoverPosition(E)
  local parent = _G.ElvUIParent or UIParent
  local parentWidth = parent and parent.GetWidth and parent:GetWidth() or 1920
  local partyWidth = 190
  local playerWidth = 260

  if E and E.db and E.db.unitframe and E.db.unitframe.units then
    local units = E.db.unitframe.units
    if units.party then partyWidth = NumberOr(units.party.width, partyWidth) end
    if units.player then playerWidth = NumberOr(units.player.width, playerWidth) end
  end

  local playerLeft = nil
  local playerMover = _G.ElvUF_PlayerMover
  if playerMover and playerMover.GetLeft then
    local ok, left = pcall(playerMover.GetLeft, playerMover)
    if ok and type(left) == "number" then playerLeft = left end
  end

  -- Fall back to RetreatUI's default player-frame anchor when ElvUI has not
  -- created its movers yet. This still scales correctly on 16:9 and ultrawide.
  if not playerLeft then
    local playerCenter = (parentWidth * 0.5) - 310
    playerLeft = playerCenter - (playerWidth * 0.5)
  end

  local x = math.floor(playerLeft - partyWidth - PARTY_PLAYER_GAP + 0.5)
  local maximum = math.max(8, math.floor(parentWidth - partyWidth - 8))
  if x < 8 then x = 8 end
  if x > maximum then x = maximum end
  return string.format("TOPLEFT,ElvUIParent,BOTTOMLEFT,%d,%d", x, PARTY_MOVER_Y)
end

function RUI:ApplyPartyFramePosition(force)
  local loaded = self:EnsureAddOnLoaded("ElvUI")
  if not loaded or not ElvUI or not ElvDB then return false, "ElvUI is not loaded" end

  local E = unpack(ElvUI)
  if not E or not E.db then return false, "ElvUI profile is not available" end

  local currentProfile = nil
  if E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok then currentProfile = value end
  end
  if not force and currentProfile and currentProfile ~= "RetreatUI" then
    return true, "Non-RetreatUI ElvUI profile preserved"
  end

  E.db.movers = E.db.movers or {}
  local current = E.db.movers.ElvUF_PartyMover
  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  local previousManagedPosition = db.integrations.elvui.partyPosition
  local desired = BuildPartyMoverPosition(E)

  -- Migrate only RetreatUI-managed positions automatically. User-created
  -- mover positions remain untouched unless /rui repair is used.
  local managed = not current
    or current == PARTY_MOVER_OLD
    or current == PARTY_MOVER_INTERMEDIATE
    or current == PARTY_MOVER_FALLBACK
    or current == previousManagedPosition
  if not force and not managed then
    return true, "Custom ElvUI party position preserved"
  end

  E.db.movers.ElvUF_PartyMover = desired

  if ElvDB.profiles and ElvDB.profiles.RetreatUI then
    ElvDB.profiles.RetreatUI.movers = ElvDB.profiles.RetreatUI.movers or {}
    ElvDB.profiles.RetreatUI.movers.ElvUF_PartyMover = desired
  end

  db.integrations.elvui.partyPosition = desired
  db.integrations.elvui.partyPositionVersion = self.version

  if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
  if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  self:After(0.30, function()
    if E and E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
    if E and E.UpdateAll then pcall(E.UpdateAll, E, true) end
  end)

  return true, "Party frame positioned directly left of the player frame"
end

local function BuildTargetTargetMoverPosition(E)
  local parent = _G.ElvUIParent or UIParent
  local targetMover = _G.ElvUF_TargetMover or _G.ElvUF_Target

  if targetMover and targetMover.GetRight and targetMover.GetBottom then
    local okRight, right = pcall(targetMover.GetRight, targetMover)
    local okBottom, bottom = pcall(targetMover.GetBottom, targetMover)
    if okRight and okBottom and type(right) == "number" and type(bottom) == "number" then
      local parentLeft = 0
      local parentBottom = 0
      if parent and parent.GetLeft then
        local ok, value = pcall(parent.GetLeft, parent)
        if ok and type(value) == "number" then parentLeft = value end
      end
      if parent and parent.GetBottom then
        local ok, value = pcall(parent.GetBottom, parent)
        if ok and type(value) == "number" then parentBottom = value end
      end
      local x = math.floor((right - parentLeft) + TARGET_TARGET_GAP + 0.5)
      local y = math.floor((bottom - parentBottom) + 0.5)
      return string.format("BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,%d,%d", x, y)
    end
  end

  return TARGET_TARGET_MOVER_FALLBACK
end

local function ConfigureTargetTargetFrame(units)
  if type(units) ~= "table" then return end
  local frame = units.targettarget or {}
  units.targettarget = frame

  frame.enable = true
  frame.width = TARGET_TARGET_WIDTH
  frame.height = TARGET_TARGET_HEIGHT
  frame.disableMouseoverGlow = true
  frame.threatStyle = "GLOW"

  frame.buffs = frame.buffs or {}
  frame.buffs.enable = false

  frame.debuffs = frame.debuffs or {}
  frame.debuffs.enable = false
  frame.debuffs.anchorPoint = "TOPRIGHT"

  frame.power = frame.power or {}
  frame.power.enable = false

  frame.health = frame.health or {}
  frame.health.frequentUpdates = true
  frame.health.position = "CENTER"
  frame.health.text_format = ""
  frame.health.xOffset = 0

  frame.name = frame.name or {}
  frame.name.font = "Fira Sans Heavy"
  frame.name.fontOutline = "OUTLINE"
  frame.name.fontSize = 10
  frame.name.position = "CENTER"
  frame.name.text_format = "[name:short]"
  frame.name.xOffset = 0

  frame.raidicon = frame.raidicon or {}
  frame.raidicon.enable = true
  frame.raidicon.attachTo = "TOP"
  frame.raidicon.size = 14
  frame.raidicon.xOffset = 0
  frame.raidicon.yOffset = 5
end


local function ConfigureCastbar(castbar, iconPosition, showLatency)
  if type(castbar) ~= "table" then return end
  castbar.enable = true
  castbar.width = 260
  castbar.height = 18
  castbar.insideInfoPanel = false
  castbar.icon = true
  castbar.iconAttached = true
  castbar.iconPosition = iconPosition
  castbar.format = "REMAINING"
  castbar.displayTarget = false
  castbar.spark = false
  castbar.timeToHold = 0
  if showLatency then
    castbar.latency = true
  else
    castbar.latency = nil
  end
end

local function ConfigureHUDPolish(profile, applyMovers)
  if type(profile) ~= "table" then return end

  profile.actionbar = profile.actionbar or {}
  profile.actionbar.bar3 = profile.actionbar.bar3 or {}
  local bar3 = profile.actionbar.bar3
  bar3.enabled = true
  bar3.buttons = 12
  bar3.buttonsPerRow = 12
  bar3.buttonsize = 24
  bar3.counttext = true
  bar3.hotkeytext = true
  bar3.macrotext = false
  bar3.visibility = "[vehicleui] hide; show"

  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  local units = profile.unitframe.units
  units.player = units.player or {}
  units.player.castbar = units.player.castbar or {}
  ConfigureCastbar(units.player.castbar, "LEFT", true)

  units.target = units.target or {}
  units.target.castbar = units.target.castbar or {}
  ConfigureCastbar(units.target.castbar, "RIGHT", false)
  ConfigureTargetTargetFrame(units)

  if applyMovers then
    profile.movers = profile.movers or {}
    profile.movers.ElvUF_PlayerCastbarMover = PLAYER_CASTBAR_MOVER
    profile.movers.ElvUF_TargetCastbarMover = TARGET_CASTBAR_MOVER
    profile.movers.ElvAB_3 = ACTIONBAR3_MOVER
    profile.movers.ShiftAB = STANCE_BAR_MOVER
  end
end

function RUI:ApplyElvUIHUDPolish(force)
  local loaded = self:EnsureAddOnLoaded("ElvUI")
  if not loaded or not ElvUI or not ElvDB then return false, "ElvUI is not loaded" end

  local E = unpack(ElvUI)
  if not E or not E.db then return false, "ElvUI profile is not available" end

  local currentProfile = nil
  if E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok then currentProfile = value end
  end
  if not force and currentProfile and currentProfile ~= "RetreatUI" then
    return true, "Non-RetreatUI ElvUI profile preserved"
  end

  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  local applyMovers = force or db.integrations.elvui.hudPolishRevision ~= HUD_POLISH_REVISION

  ConfigureHUDPolish(E.db, applyMovers)
  if ElvDB.profiles and ElvDB.profiles.RetreatUI then
    ConfigureHUDPolish(ElvDB.profiles.RetreatUI, applyMovers)
  end

  if applyMovers then
    db.integrations.elvui.hudPolishRevision = HUD_POLISH_REVISION
    db.integrations.elvui.hudPolishVersion = self.version
  end

  if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
  if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  self:After(0.30, function()
    if E and E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
    if E and E.UpdateAll then pcall(E.UpdateAll, E, true) end
  end)

  if applyMovers then
    return true, "Castbars moved below the unitframes, stance bar lowered, and HUD positions updated"
  end
  return true, "RetreatUI castbar, stance bar, and frame styling refreshed"
end

function RUI:ApplyTargetTargetFrame(force)
  local loaded = self:EnsureAddOnLoaded("ElvUI")
  if not loaded or not ElvUI or not ElvDB then return false, "ElvUI is not loaded" end

  local E = unpack(ElvUI)
  if not E or not E.db then return false, "ElvUI profile is not available" end

  local currentProfile = nil
  if E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok then currentProfile = value end
  end
  if not force and currentProfile and currentProfile ~= "RetreatUI" then
    return true, "Non-RetreatUI ElvUI profile preserved"
  end

  E.db.unitframe = E.db.unitframe or {}
  E.db.unitframe.units = E.db.unitframe.units or {}
  ConfigureTargetTargetFrame(E.db.unitframe.units)

  E.db.movers = E.db.movers or {}
  local current = E.db.movers.ElvUF_TargetTargetMover
  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  local previousManagedPosition = db.integrations.elvui.targetTargetPosition
  local desired = BuildTargetTargetMoverPosition(E)

  local managed = not current
    or current == TARGET_TARGET_MOVER_OLD
    or current == TARGET_TARGET_MOVER_FALLBACK
    or current == previousManagedPosition
  if force or managed then
    E.db.movers.ElvUF_TargetTargetMover = desired
    db.integrations.elvui.targetTargetPosition = desired
    db.integrations.elvui.targetTargetPositionVersion = self.version
  end

  if ElvDB.profiles and ElvDB.profiles.RetreatUI then
    local profile = ElvDB.profiles.RetreatUI
    profile.unitframe = profile.unitframe or {}
    profile.unitframe.units = profile.unitframe.units or {}
    ConfigureTargetTargetFrame(profile.unitframe.units)
    profile.movers = profile.movers or {}
    if force or managed then profile.movers.ElvUF_TargetTargetMover = desired end
  end

  if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
  if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  self:After(0.30, function()
    if E and E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
    if E and E.UpdateAll then pcall(E.UpdateAll, E, true) end
  end)

  if not managed and not force then
    return true, "Target of Target enabled; custom position preserved"
  end
  return true, "Compact Target of Target frame enabled beside the target frame"
end

function RUI:InstallElvUIProfile()
  local loaded = self:EnsureAddOnLoaded("ElvUI")
  if not loaded or not ElvUI or not ElvDB then return false, "ElvUI is not loaded" end
  local E = unpack(ElvUI)
  local profileName = "RetreatUI"
  ElvDB.profiles = ElvDB.profiles or {}
  local profile = self:DeepCopy(self.ElvUIProfile)
  self:ForceFontFields(profile)
  ElvDB.profiles[profileName] = profile

  local ok, err = pcall(function()
    if E and E.data and E.data.SetProfile then E.data:SetProfile(profileName) end
    self:DisableElvUINamePlates()
    if E and E.db then self:ForceFontFields(E.db) end
    if E and E.db and E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units.player then
      E.db.unitframe.units.player.health = E.db.unitframe.units.player.health or {}
      E.db.unitframe.units.player.health.text_format = "[health:current]"
    end
    if E and E.UpdateAll then E:UpdateAll(true) end
    self:ApplyPartyFramePosition(true)
    self:ApplyTargetTargetFrame(true)
    self:ApplyElvUIHUDPolish(true)
    self:RemoveRightLootTradeChat()
    self:After(0.25, function() self:RemoveRightLootTradeChat() end)
    self:After(1.00, function() self:RemoveRightLootTradeChat() end)
  end)
  if not ok then return false, "Profile created, but activation failed: " .. tostring(err) end
  return true, "RetreatUI ElvUI profile installed; ElvUI NamePlates disabled and right Loot/Trade chat removed"
end

function RUI:SyncThemeFonts()
  self.themeFontPath = self.preferredFontPath
  local results = {}

  if ElvUI then
    local E = unpack(ElvUI)
    local profile = ElvDB and ElvDB.profiles and ElvDB.profiles.RetreatUI
    if type(profile) == "table" then self:ForceFontFields(profile) end

    local currentProfile
    if E and E.data and E.data.GetCurrentProfile then
      local ok, value = pcall(E.data.GetCurrentProfile, E.data)
      if ok then currentProfile = value end
    end
    if currentProfile == "RetreatUI" and E and E.db then
      self:ForceFontFields(E.db)
      if E.UpdateAll then pcall(E.UpdateAll, E, true) end
    end
    table.insert(results, "ElvUI")
  end

  if TurboPlatesDB then
    TurboPlatesDB.font = self.fontName
    table.insert(results, "TurboPlates")
  end

  if self.ApplyDetailsFont then
    local ok = self:ApplyDetailsFont()
    if ok then table.insert(results, "Details") end
  end

  if self.ApplyDBMTheme then
    local ok = self:ApplyDBMTheme()
    if ok then table.insert(results, "DBM") end
  end

  -- Do not rebuild or destroy the installer here. Existing font strings remain
  -- valid, and the next /reload applies Fira Sans Heavy everywhere.
  return true, "Fira Sans Heavy applied to " .. table.concat(results, ", ")
end

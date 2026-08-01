local RUI = RetreatUI
if not RUI then return end

local HEAT_SPELL_ID = 807389
local REPAIR_REVISION = 2

local function CurrentElvUIProfile(E)
  if E and E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok and type(value) == "string" and value ~= "" then return value end
  end
  return "RetreatUI"
end

local function Trim(value)
  return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function PrependBlacklist(priority)
  local value = Trim(priority)
  if value == "" then return "Blacklist,Personal,nonPersonal" end
  local result, seen = {"Blacklist"}, {Blacklist=true}
  for token in string.gmatch(value, "([^,]+)") do
    token = Trim(token)
    if token ~= "" and not seen[token] then
      result[#result + 1] = token
      seen[token] = true
    end
  end
  return table.concat(result, ",")
end

local function ApplyHeatFilterToProfile(profile)
  if type(profile) ~= "table" then return false end
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  profile.unitframe.units.target = profile.unitframe.units.target or {}
  local target = profile.unitframe.units.target
  target.aurabar = target.aurabar or target.auraBar or {}
  target.aurabar.priority = PrependBlacklist(target.aurabar.priority)
  if type(target.auraBar) == "table" then target.auraBar.priority = target.aurabar.priority end
  target.debuffs = target.debuffs or {}
  target.debuffs.priority = PrependBlacklist(target.debuffs.priority)
  profile.chat = profile.chat or {}
  profile.chat.retreatHideLeftChat = false
  return true
end

local function EnsureHeatBlacklist(E)
  local global = E and E.global
  if type(global) ~= "table" and type(ElvDB) == "table" then
    ElvDB.global = ElvDB.global or {}
    global = ElvDB.global
  end
  if type(global) ~= "table" then return false end
  global.unitframe = global.unitframe or {}
  global.unitframe.aurafilters = global.unitframe.aurafilters or {}
  local filters = global.unitframe.aurafilters
  filters.Blacklist = filters.Blacklist or {type="Blacklist", spells={}}
  filters.Blacklist.type = "Blacklist"
  filters.Blacklist.spells = filters.Blacklist.spells or {}
  filters.Blacklist.spells[HEAT_SPELL_ID] = {enable=true, priority=0}
  filters.Blacklist.spells[tostring(HEAT_SPELL_ID)] = {enable=true, priority=0}
  filters.Blacklist.spells.Heat = {enable=true, priority=0}
  return true
end

function RUI:ApplyPyromancerHeatAuraFilter(refreshLive)
  local E = ElvUI and unpack(ElvUI)
  local changed = EnsureHeatBlacklist(E)
  if type(self.ElvUIProfile) == "table" then changed = ApplyHeatFilterToProfile(self.ElvUIProfile) or changed end
  if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
    changed = ApplyHeatFilterToProfile(ElvDB.profiles.RetreatUI) or changed
  end
  if E and E.db and CurrentElvUIProfile(E) == "RetreatUI" then changed = ApplyHeatFilterToProfile(E.db) or changed end

  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.pyromancerHeatFilterRevision = REPAIR_REVISION
  db.integrations.elvui.pyromancerHeatFilterVersion = self.version

  if refreshLive and E and E.GetModule then
    local ok, unitFrames = pcall(E.GetModule, E, "UnitFrames", true)
    if ok and unitFrames and unitFrames.Update_AllFrames then
      pcall(unitFrames.Update_AllFrames, unitFrames)
    elseif E.UpdateAll then
      pcall(E.UpdateAll, E, true)
    end
  end
  return true, changed
end

local function RestoreRegion(region, show)
  if not region then return false end
  if region.SetAlpha then pcall(region.SetAlpha, region, 1) end
  if region.EnableMouse then pcall(region.EnableMouse, region, true) end
  if show and region.Show then pcall(region.Show, region) end
  region.RetreatUIHiddenBehindDetails = nil
  return true
end

local function RestoreChatFrame(frame, show)
  if not frame then return false end
  RestoreRegion(frame, show)
  local name = type(frame.GetName) == "function" and frame:GetName() or nil
  if name then
    for _, suffix in ipairs({"Tab", "ButtonFrame", "ScrollBar", "ScrollToBottomButton"}) do
      RestoreRegion(_G[name .. suffix], suffix == "Tab")
    end
  end
  return true
end

function RUI:RestoreLeftChat()
  local restored = RestoreChatFrame(_G.ChatFrame1, true)
  local count = tonumber(NUM_CHAT_WINDOWS) or 10
  for index = 2, count do
    local frame = _G["ChatFrame" .. index]
    if frame and frame.RetreatUIHiddenBehindDetails then
      restored = RestoreChatFrame(frame, true) or restored
    end
  end
  for _, region in ipairs({_G.LeftChatPanel, _G.LeftChatDataPanel, _G.LeftChatTab}) do
    restored = RestoreRegion(region, true) or restored
  end
  local db = self:EnsureDB()
  db.integrations.details = db.integrations.details or {}
  db.integrations.details.leftChatHidden = false
  db.integrations.details.leftChatRestored = restored
  db.integrations.details.chatSeparationRevision = REPAIR_REVISION
  db.integrations.details.chatSeparationVersion = self.version
  return restored
end

function RUI:ApplyDetailsChatSeparation()
  return self:RestoreLeftChat()
end

local function Later(delay, callback)
  if RUI.After then RUI:After(delay, callback)
  elseif C_Timer and C_Timer.After then C_Timer.After(delay, callback) end
end

local function ReapplyAll()
  RUI:ApplyPyromancerHeatAuraFilter(true)
  RUI:RestoreLeftChat()
  for _, delay in ipairs({0.10, 0.50, 1.50}) do
    Later(delay, function()
      RUI:ApplyPyromancerHeatAuraFilter(true)
      RUI:RestoreLeftChat()
    end)
  end
end

if type(RUI.ElvUIProfile) == "table" then ApplyHeatFilterToProfile(RUI.ElvUIProfile) end

local originalInstallElvUIProfile = RUI.InstallElvUIProfile
if type(originalInstallElvUIProfile) == "function" then
  function RUI:InstallElvUIProfile(...)
    local results = {originalInstallElvUIProfile(self, ...)}
    self:ApplyPyromancerHeatAuraFilter(true)
    self:RestoreLeftChat()
    return unpack(results)
  end
end

local originalApplyElvUIHUDPolish = RUI.ApplyElvUIHUDPolish
if type(originalApplyElvUIHUDPolish) == "function" then
  function RUI:ApplyElvUIHUDPolish(...)
    local results = {originalApplyElvUIHUDPolish(self, ...)}
    self:ApplyPyromancerHeatAuraFilter(true)
    self:RestoreLeftChat()
    return unpack(results)
  end
end

local originalInstallDetailsProfile = RUI.InstallDetailsProfile
if type(originalInstallDetailsProfile) == "function" then
  function RUI:InstallDetailsProfile(...)
    local results = {originalInstallDetailsProfile(self, ...)}
    self:RestoreLeftChat()
    return unpack(results)
  end
end

local events = CreateFrame("Frame", "RetreatUIPyromancerAuraAndDetailsChatDriver")
for _, eventName in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "ADDON_LOADED"}) do
  pcall(events.RegisterEvent, events, eventName)
end

events:SetScript("OnEvent", function(_, eventName, addonName)
  if eventName == "ADDON_LOADED" and addonName ~= "ElvUI" and addonName ~= "Details" then return end
  ReapplyAll()
end)

RUI._pyromancerAuraAndDetailsChatLoaded = true

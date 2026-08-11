local RUI = RetreatUI
if not RUI then return end

local HEAT_SPELL_ID = 807389
local REPAIR_REVISION = 3

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

  -- Keep the profile preference only. ElvUI/Blizzard own the actual chat-frame
  -- visibility and docking state; RetreatUI must never Show/Hide chat frames.
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

function RUI:ApplyPyromancerHeatAuraFilter()
  local E = ElvUI and unpack(ElvUI)
  local changed = EnsureHeatBlacklist(E)
  if type(self.ElvUIProfile) == "table" then changed = ApplyHeatFilterToProfile(self.ElvUIProfile) or changed end
  if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
    changed = ApplyHeatFilterToProfile(ElvDB.profiles.RetreatUI) or changed
  end
  if E and E.db and CurrentElvUIProfile(E) == "RetreatUI" then
    changed = ApplyHeatFilterToProfile(E.db) or changed
  end

  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.pyromancerHeatFilterRevision = REPAIR_REVISION
  db.integrations.elvui.pyromancerHeatFilterVersion = self.version

  -- Deliberately no UnitFrames:Update_AllFrames() / ElvUI:UpdateAll() here.
  -- The filter is static profile data. Global live refreshes on target changes
  -- caused action-bar update storms and severe frame pacing spikes.
  return true, changed
end

function RUI:RestoreLeftChat()
  -- Historical versions force-showed ChatFrame1 and companion regions. If the
  -- user had another docked tab selected, that made two chat frames render in
  -- the same panel. From beta.18 onward this function is state-only.
  local db = self:EnsureDB()
  db.integrations.details = db.integrations.details or {}
  db.integrations.details.leftChatHidden = false
  db.integrations.details.leftChatRestored = false
  db.integrations.details.chatOwnedByElvUI = true
  db.integrations.details.chatSeparationRevision = REPAIR_REVISION
  db.integrations.details.chatSeparationVersion = self.version
  return false
end

function RUI:ApplyDetailsChatSeparation()
  return self:RestoreLeftChat()
end

if type(RUI.ElvUIProfile) == "table" then
  ApplyHeatFilterToProfile(RUI.ElvUIProfile)
end

local originalInstallElvUIProfile = RUI.InstallElvUIProfile
if type(originalInstallElvUIProfile) == "function" then
  function RUI:InstallElvUIProfile(...)
    local results = {originalInstallElvUIProfile(self, ...)}
    self:ApplyPyromancerHeatAuraFilter()
    self:RestoreLeftChat()
    return unpack(results)
  end
end

local originalApplyElvUIHUDPolish = RUI.ApplyElvUIHUDPolish
if type(originalApplyElvUIHUDPolish) == "function" then
  function RUI:ApplyElvUIHUDPolish(...)
    local results = {originalApplyElvUIHUDPolish(self, ...)}
    self:ApplyPyromancerHeatAuraFilter()
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

-- Only repair static profile data when ElvUI becomes available. Never refresh
-- on PLAYER_TARGET_CHANGED / PLAYER_ENTERING_WORLD and never touch chat frames.
local events = CreateFrame("Frame", "RetreatUIPyromancerAuraAndDetailsChatDriver")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, addonName)
  if addonName == "ElvUI" then RUI:ApplyPyromancerHeatAuraFilter() end
end)

RUI._pyromancerAuraAndDetailsChatLoaded = true

local RUI = RetreatUI
if not RUI then return end

local HEAT_SPELL_ID = 807389
local REPAIR_REVISION = 1

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
  if value == "" then
    -- An empty ElvUI AuraBar priority means "show everything". Keep that
    -- behaviour while giving Blacklist the first chance to reject Heat.
    return "Blacklist,Personal,nonPersonal"
  end

  local result, seen = {"Blacklist"}, {Blacklist = true}
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

  -- Keep the legacy alias synchronized because Ascension ElvUI exports have
  -- used both names even though the live module reads `aurabar`.
  if type(target.auraBar) == "table" then
    target.auraBar.priority = target.aurabar.priority
  end

  target.debuffs = target.debuffs or {}
  target.debuffs.priority = PrependBlacklist(target.debuffs.priority)

  profile.chat = profile.chat or {}
  profile.chat.retreatHideLeftChat = true
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
  filters.Blacklist = filters.Blacklist or {type = "Blacklist", spells = {}}
  filters.Blacklist.type = "Blacklist"
  filters.Blacklist.spells = filters.Blacklist.spells or {}
  filters.Blacklist.spells[HEAT_SPELL_ID] = {enable = true, priority = 0}
  filters.Blacklist.spells[tostring(HEAT_SPELL_ID)] = {enable = true, priority = 0}
  filters.Blacklist.spells.Heat = {enable = true, priority = 0}
  return true
end

function RUI:ApplyPyromancerHeatAuraFilter(refreshLive)
  local E = ElvUI and unpack(ElvUI)
  local changed = EnsureHeatBlacklist(E)

  if type(self.ElvUIProfile) == "table" then
    changed = ApplyHeatFilterToProfile(self.ElvUIProfile) or changed
  end

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

  if refreshLive and E and E.GetModule then
    local ok, unitFrames = pcall(E.GetModule, E, "UnitFrames", true)
    if ok and unitFrames and unitFrames.Update_AllFrames then
      pcall(unitFrames.Update_AllFrames, unitFrames)
    elseif E.UpdateAll then
      pcall(E.UpdateAll, E, true)
    end
  end

  return true, changed and "Pyromancer Heat removed from target aura displays" or "Pyromancer Heat target filter verified"
end

local function ObjectName(value)
  if not value or type(value.GetName) ~= "function" then return nil end
  local ok, name = pcall(value.GetName, value)
  return ok and type(name) == "string" and name or nil
end

local function TouchesLeftChatPanel(value, seen, depth)
  if not value or depth > 8 then return false end
  seen = seen or {}
  if seen[value] then return false end
  seen[value] = true

  local name = ObjectName(value)
  if value == _G.LeftChatPanel
    or value == _G.LeftChatDataPanel
    or value == _G.LeftChatTab
    or (name and string.find(string.lower(name), "leftchat", 1, true)) then
    return true
  end

  if type(value.GetParent) == "function" then
    local ok, parent = pcall(value.GetParent, value)
    if ok and parent and TouchesLeftChatPanel(parent, seen, depth + 1) then return true end
  end

  if type(value.GetNumPoints) == "function" and type(value.GetPoint) == "function" then
    local ok, count = pcall(value.GetNumPoints, value)
    if ok then
      for pointIndex = 1, tonumber(count) or 0 do
        local pointOK, _, relativeTo = pcall(value.GetPoint, value, pointIndex)
        if pointOK and relativeTo and TouchesLeftChatPanel(relativeTo, seen, depth + 1) then
          return true
        end
      end
    end
  end

  return false
end

local function DetailsProfileIsActive()
  local db = RUI:EnsureDB()
  local marker = db.integrations and db.integrations.details
  if type(marker) ~= "table" or marker.imported ~= true or marker.profile ~= (RUI.DetailsProfileName or "RetreatUI") then
    return false
  end
  return type(_G.Details) == "table" or type(_G._detalhes) == "table"
end

local function RetreatElvUIProfileIsActive()
  local E = ElvUI and unpack(ElvUI)
  return not E or CurrentElvUIProfile(E) == "RetreatUI"
end

local function ShouldHideDetailsChat()
  return DetailsProfileIsActive() and RetreatElvUIProfileIsActive()
end

local function HideChatFrame(frame)
  if not frame then return false end
  if frame.Hide then pcall(frame.Hide, frame) end
  if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
  frame.RetreatUIHiddenBehindDetails = true

  if not frame.RetreatUIHideHooked and type(frame.HookScript) == "function" then
    frame.RetreatUIHideHooked = true
    frame:HookScript("OnShow", function(chatFrame)
      if ShouldHideDetailsChat() then
        if chatFrame.Hide then pcall(chatFrame.Hide, chatFrame) end
        if chatFrame.SetAlpha then pcall(chatFrame.SetAlpha, chatFrame, 0) end
      end
    end)
  end

  local frameName = ObjectName(frame)
  if frameName then
    for _, suffix in ipairs({"Tab", "ButtonFrame", "ScrollBar", "ScrollToBottomButton"}) do
      local companion = _G[frameName .. suffix]
      if companion then
        if companion.Hide then pcall(companion.Hide, companion) end
        if companion.SetAlpha then pcall(companion.SetAlpha, companion, 0) end
        if companion.EnableMouse then pcall(companion.EnableMouse, companion, false) end
      end
    end
  end
  return true
end

function RUI:ApplyDetailsChatSeparation()
  if not ShouldHideDetailsChat() then return false end

  local hidden = false
  local count = tonumber(NUM_CHAT_WINDOWS) or 10
  for index = 1, count do
    local frame = _G["ChatFrame" .. index]
    -- ChatFrame1 is the normal General window. Also catch any other tab docked
    -- into ElvUI's left chat area, while leaving right-side chat untouched.
    if frame and (index == 1 or TouchesLeftChatPanel(frame, {}, 0)) then
      hidden = HideChatFrame(frame) or hidden
    end
  end

  local db = self:EnsureDB()
  db.integrations.details = db.integrations.details or {}
  db.integrations.details.leftChatHidden = hidden
  db.integrations.details.chatSeparationRevision = REPAIR_REVISION
  db.integrations.details.chatSeparationVersion = self.version
  return hidden
end

local function Later(delay, callback)
  if RUI.After then
    RUI:After(delay, callback)
  elseif C_Timer and C_Timer.After then
    C_Timer.After(delay, callback)
  end
end

local function ReapplyAll()
  RUI:ApplyPyromancerHeatAuraFilter(true)
  RUI:ApplyDetailsChatSeparation()
  for _, delay in ipairs({0.10, 0.50, 1.50}) do
    Later(delay, function()
      RUI:ApplyPyromancerHeatAuraFilter(true)
      RUI:ApplyDetailsChatSeparation()
    end)
  end
end

-- Make the settings part of the bundled baseline before the installer copies it.
if type(RUI.ElvUIProfile) == "table" then ApplyHeatFilterToProfile(RUI.ElvUIProfile) end

local originalInstallElvUIProfile = RUI.InstallElvUIProfile
if type(originalInstallElvUIProfile) == "function" then
  function RUI:InstallElvUIProfile(...)
    local results = {originalInstallElvUIProfile(self, ...)}
    self:ApplyPyromancerHeatAuraFilter(true)
    self:ApplyDetailsChatSeparation()
    return unpack(results)
  end
end

local originalApplyElvUIHUDPolish = RUI.ApplyElvUIHUDPolish
if type(originalApplyElvUIHUDPolish) == "function" then
  function RUI:ApplyElvUIHUDPolish(...)
    local results = {originalApplyElvUIHUDPolish(self, ...)}
    self:ApplyPyromancerHeatAuraFilter(true)
    self:ApplyDetailsChatSeparation()
    return unpack(results)
  end
end

local originalInstallDetailsProfile = RUI.InstallDetailsProfile
if type(originalInstallDetailsProfile) == "function" then
  function RUI:InstallDetailsProfile(...)
    local results = {originalInstallDetailsProfile(self, ...)}
    self:ApplyDetailsChatSeparation()
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

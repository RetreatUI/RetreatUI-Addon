local RUI = RetreatUI
if not RUI or type(RUI.RefreshTrinketTracker) ~= "function" then return end
if not RUI.HUDWidgets then return end

-- Some Ascension clients expose an equipped custom trinket texture and slot
-- cooldown without returning a standard item ID. The primary tracker uses the
-- item ID for proc discovery, so keep a lightweight slot-based fallback that
-- only takes over when the primary refresh cannot display either trinket.
local W = RUI.HUDWidgets
local SLOTS = {13, 14}
local originalRefresh = RUI.RefreshTrinketTracker
local originalInitialize = RUI.InitializeTrinketTracker

local function FrameUsable(frame)
  if not frame or type(frame.IsShown) ~= "function" then return false end
  local okShown, shown = pcall(frame.IsShown, frame)
  if not okShown or not shown then return false end
  if type(frame.GetRight) ~= "function" or type(frame.GetTop) ~= "function" then return false end
  local okRight, right = pcall(frame.GetRight, frame)
  local okTop, top = pcall(frame.GetTop, frame)
  return okRight and okTop and right ~= nil and top ~= nil
end

local function PlayerFrame()
  for _, frame in ipairs({
    _G.ElvUF_Player,
    _G.ElvUF_PlayerMover,
    _G.PlayerFrame,
  }) do
    if FrameUsable(frame) then return frame end
  end
  return nil
end

local function SlotData(slot)
  local link = GetInventoryItemLink and GetInventoryItemLink("player", slot) or nil
  local texture = GetInventoryItemTexture and GetInventoryItemTexture("player", slot) or nil

  if not texture and link and GetItemInfo then
    local ok, resolved = pcall(function()
      return select(10, GetItemInfo(link))
    end)
    if ok then texture = resolved end
  end

  return link ~= nil or texture ~= nil, texture
end

local function Cooldown(slot)
  if not GetInventoryItemCooldown then return 0 end
  local ok, start, duration, enabled = pcall(GetInventoryItemCooldown, "player", slot)
  if not ok or tonumber(enabled) == 0 then return 0 end
  start = tonumber(start) or 0
  duration = tonumber(duration) or 0
  if start <= 0 or duration <= 0 then return 0 end
  return math.max(0, (start + duration) - (GetTime and GetTime() or 0))
end

local function ShowFallback()
  if RUI.IsHUDOverlaySuppressed and RUI:IsHUDOverlaySuppressed() then return false end

  local tracker = RUI.GetTrinketTrackerFrame and RUI:GetTrinketTrackerFrame() or nil
  local player = PlayerFrame()
  if not tracker or not tracker.icons or not player then return false end

  local shown = false
  for index, slot in ipairs(SLOTS) do
    local icon = tracker.icons[index]
    local equipped, texture = SlotData(slot)
    if icon and equipped then
      icon.texture:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
      icon.stackText:SetText("")
      W:SetGlow(icon, nil, 0)
      W:SetBorder(icon, {0, 0, 0, 1}, 1)

      local remaining = Cooldown(slot)
      if remaining > 0.05 then
        W:SetCooldownDisplay(icon, remaining, true)
        icon:SetAlpha(0.58)
        if icon.texture.SetDesaturated then icon.texture:SetDesaturated(true) end
      else
        W:SetCooldownDisplay(icon, 0, false)
        icon:SetAlpha(1)
        if icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
      end

      icon:Show()
      shown = true
    elseif icon then
      icon:Hide()
    end
  end

  if not shown then
    tracker:Hide()
    return false
  end

  tracker:ClearAllPoints()
  tracker:SetPoint("BOTTOMRIGHT", player, "TOPRIGHT", 0, 2)
  tracker:Show()
  RUI.trinketTrackerFallbackActive = true
  return true
end

function RUI:RefreshTrinketTracker(force)
  local ok, shown = pcall(originalRefresh, self, force)
  if ok and shown then
    self.trinketTrackerFallbackActive = false
    return true
  end
  return ShowFallback()
end

function RUI:InitializeTrinketTracker(...)
  local result
  if originalInitialize then
    local ok, value = pcall(originalInitialize, self, ...)
    if ok then result = value end
  end
  self:RefreshTrinketTracker(true)
  return result ~= false
end

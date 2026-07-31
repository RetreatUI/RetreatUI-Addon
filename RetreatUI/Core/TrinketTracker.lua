local RUI = RetreatUI
if not RUI or not RUI.HUDWidgets then return end

-- Global trinket tracking for equipped inventory slots 13 and 14.
-- The tracker is intentionally not part of the HUD Editor: it follows the
-- live player frame, uses the same icon size as the proc row, and automatically
-- shifts horizontally when another unit frame occupies the space above the
-- player's top-right corner.
local W = RUI.HUDWidgets
local SLOTS = {13, 14}
local ICON_SPACING = 3
local PLAYER_GAP = 2
local COLLISION_GAP = 3
local UPDATE_INTERVAL = 0.08
local REFRESH_INTERVAL = 0.35

local tracker
local driver
local elapsed = 0
local refreshElapsed = 0
local states = {}

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function Number(value, fallback)
  value = tonumber(value)
  if value == nil then return fallback end
  return value
end

local function SafeShown(frame)
  if not frame or type(frame.IsShown) ~= "function" then return false end
  local ok, shown = pcall(frame.IsShown, frame)
  return ok and shown == true
end

local function FrameBounds(frame)
  if not frame or not SafeShown(frame) then return nil end
  if not frame.GetLeft or not frame.GetRight or not frame.GetTop or not frame.GetBottom then return nil end
  local okL, left = pcall(frame.GetLeft, frame)
  local okR, right = pcall(frame.GetRight, frame)
  local okT, top = pcall(frame.GetTop, frame)
  local okB, bottom = pcall(frame.GetBottom, frame)
  if not okL or not okR or not okT or not okB then return nil end
  if not left or not right or not top or not bottom then return nil end
  return {left=left, right=right, top=top, bottom=bottom}
end

local function Intersects(a, b)
  return a and b
    and a.left < b.right and a.right > b.left
    and a.bottom < b.top and a.top > b.bottom
end

local function PlayerFrame()
  local candidates = {
    _G.ElvUF_Player,
    _G.ElvUF_PlayerMover,
    _G.PlayerFrame,
  }
  for _, frame in ipairs(candidates) do
    if frame and frame.GetRight and frame.GetTop then return frame end
  end
  return nil
end

local function NearbyUnitFrames()
  return {
    _G.ElvUF_Pet,
    _G.ElvUF_PetMover,
    _G.ElvUF_TargetTarget,
    _G.ElvUF_TargetTargetMover,
    _G.ElvUF_Focus,
    _G.ElvUF_FocusMover,
    _G.ElvUF_Target,
    _G.ElvUF_TargetMover,
    _G.PetFrame,
    _G.TargetFrameToT,
    _G.FocusFrame,
    _G.TargetFrame,
  }
end

local function IconSize()
  local layout = RUI.layout and RUI.layout.auraTrackers
  return math.max(18, Number(layout and layout.size, 30))
end

local function EnsureDB()
  local db = RUI:EnsureDB()
  db.trinketTracker = db.trinketTracker or {}
  db.trinketTracker.auraByItem = db.trinketTracker.auraByItem or {}
  if db.trinketTracker.enabled == nil then db.trinketTracker.enabled = true end
  return db.trinketTracker
end

local function ReadPlayerBuffs()
  local result = {list={}, byID={}, byName={}}
  if not UnitBuff then return result end
  for index = 1, 40 do
    local values = {UnitBuff("player", index)}
    local name = values[1]
    if not name then break end
    local aura = {
      name = name,
      icon = values[3],
      count = Number(values[4], 0),
      duration = Number(values[6], 0),
      expires = Number(values[7], 0),
      caster = values[8],
      spellID = Number(values[11], nil),
    }
    result.list[#result.list + 1] = aura
    result.byName[Normalize(name)] = aura
    if aura.spellID then result.byID[aura.spellID] = aura end
  end
  return result
end

local function ItemSpell(itemID)
  if not itemID or not GetItemSpell then return nil, nil, nil end
  local ok, name, spellID = pcall(GetItemSpell, itemID)
  if not ok then return nil, nil, nil end
  spellID = Number(spellID, nil)
  local texture
  if GetSpellInfo then
    if spellID then
      local _, _, resolved = GetSpellInfo(spellID)
      texture = resolved
    end
    if not texture and name then
      local _, _, resolved = GetSpellInfo(name)
      texture = resolved
    end
  end
  return name, spellID, texture
end

local function LearnedAuraForItem(itemID)
  local db = EnsureDB()
  return db.auraByItem[tostring(itemID or "")]
end

local function SaveLearnedAura(itemID, aura)
  if not itemID or not aura then return end
  local db = EnsureDB()
  db.auraByItem[tostring(itemID)] = {
    name = aura.name,
    spellID = aura.spellID,
  }
end

local function FindTrinketAura(state, buffs)
  if not state.itemID then return nil end

  local learned = LearnedAuraForItem(state.itemID)
  if learned then
    local aura = learned.spellID and buffs.byID[Number(learned.spellID, nil)] or nil
    aura = aura or buffs.byName[Normalize(learned.name)]
    if aura then return aura end
  end

  local aura = state.itemSpellID and buffs.byID[state.itemSpellID] or nil
  aura = aura or buffs.byName[Normalize(state.itemSpellName)]
  if aura then
    SaveLearnedAura(state.itemID, aura)
    return aura
  end

  -- Some items expose the proc through a differently named aura while keeping
  -- the item's spell texture. This is a safe secondary match and is also used
  -- during the brief activation window after an on-use trinket is pressed.
  for _, candidate in ipairs(buffs.list) do
    local own = candidate.caster == nil or candidate.caster == "player"
    local textureMatch = state.itemSpellTexture and candidate.icon == state.itemSpellTexture
    local itemTextureMatch = state.activationUntil and GetTime() <= state.activationUntil
      and state.texture and candidate.icon == state.texture
    if own and candidate.duration > 0 and (textureMatch or itemTextureMatch) then
      SaveLearnedAura(state.itemID, candidate)
      return candidate
    end
  end
  return nil
end

local function ReadCooldown(slot)
  if not GetInventoryItemCooldown then return 0, 0, 0 end
  local ok, start, duration, enabled = pcall(GetInventoryItemCooldown, "player", slot)
  if not ok then return 0, 0, 0 end
  return Number(start, 0), Number(duration, 0), Number(enabled, 0)
end

local function ConfigureTooltip(icon, slot)
  icon:EnableMouse(true)
  icon:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    if GameTooltip.SetInventoryItem then
      GameTooltip:SetInventoryItem("player", slot)
    end
    GameTooltip:Show()
  end)
  icon:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
end

local function CreateTracker()
  if tracker then return tracker end
  local size = IconSize()
  local total = (size * #SLOTS) + (ICON_SPACING * (#SLOTS - 1))
  tracker = CreateFrame("Frame", "RetreatUITrinketTracker", UIParent)
  tracker:SetSize(total, size)
  tracker:SetFrameStrata("MEDIUM")
  tracker.icons = {}

  for index, slot in ipairs(SLOTS) do
    local icon = W:CreateIcon(tracker, size)
    icon.slot = slot
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", tracker, "LEFT", (index - 1) * (size + ICON_SPACING), 0)
    ConfigureTooltip(icon, slot)
    tracker.icons[index] = icon
    states[index] = {slot=slot, icon=icon, itemID=nil, lastCooldownStart=0, lastCooldownDuration=0}
  end
  tracker:Hide()
  return tracker
end

local function ResizeTracker()
  if not tracker then return end
  local size = IconSize()
  local total = (size * #SLOTS) + (ICON_SPACING * (#SLOTS - 1))
  tracker:SetSize(total, size)
  for index, icon in ipairs(tracker.icons or {}) do
    icon:SetSize(size, size)
    if icon.texture then
      icon.texture:ClearAllPoints()
      icon.texture:SetPoint("TOPLEFT", 1, -1)
      icon.texture:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    if icon.glow then icon.glow:SetSize(size * 1.75, size * 1.75) end
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", tracker, "LEFT", (index - 1) * (size + ICON_SPACING), 0)
  end
end

local function PositionTracker()
  if not tracker then return false end
  local player = PlayerFrame()
  local playerBounds = FrameBounds(player)
  if not playerBounds then return false end

  local parent = UIParent
  local parentLeft = parent.GetLeft and parent:GetLeft() or 0
  local parentBottom = parent.GetBottom and parent:GetBottom() or 0
  parentLeft = Number(parentLeft, 0)
  parentBottom = Number(parentBottom, 0)

  local width = tracker:GetWidth()
  local height = tracker:GetHeight()
  local shiftX = 0
  local candidate = {
    left = playerBounds.right - width,
    right = playerBounds.right,
    bottom = playerBounds.top + PLAYER_GAP,
    top = playerBounds.top + PLAYER_GAP + height,
  }

  -- Preserve the requested top-right placement, but move the complete row a
  -- few pixels to the right when the pet or another unit frame occupies that
  -- exact area. This prevents overlap on every class/profile without moving
  -- the user's unit frames away from their ElvUI baseline.
  for _, frame in ipairs(NearbyUnitFrames()) do
    if frame ~= player then
      local bounds = FrameBounds(frame)
      if Intersects(candidate, bounds) then
        local required = bounds.right - candidate.left + COLLISION_GAP
        if required > shiftX then shiftX = required end
      end
    end
  end

  candidate.left = candidate.left + shiftX
  candidate.right = candidate.right + shiftX
  local parentRight = parent.GetRight and parent:GetRight() or 1920
  parentRight = Number(parentRight, 1920)
  if candidate.right > parentRight - 2 then
    shiftX = shiftX - (candidate.right - (parentRight - 2))
  end

  tracker:ClearAllPoints()
  tracker:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT",
    playerBounds.right - width + shiftX - parentLeft,
    playerBounds.top + PLAYER_GAP - parentBottom)
  return true
end

local function RefreshItems(force)
  if not tracker then return end
  for index, state in ipairs(states) do
    local itemID = GetInventoryItemID and GetInventoryItemID("player", state.slot) or nil
    if not itemID and GetInventoryItemLink then
      local link = GetInventoryItemLink("player", state.slot)
      itemID = link and tonumber(string.match(link, "item:(%d+)")) or nil
    end
    if force or itemID ~= state.itemID then
      state.itemID = itemID
      state.activationUntil = nil
      state.lastCooldownStart = 0
      state.lastCooldownDuration = 0
      state.itemSpellName, state.itemSpellID, state.itemSpellTexture = ItemSpell(itemID)
      state.texture = GetInventoryItemTexture and GetInventoryItemTexture("player", state.slot) or nil
      state.icon.texture:SetTexture(state.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
      state.icon.stackText:SetText("")
      state.icon.cooldownText:SetText("")
      W:SetGlow(state.icon, nil, 0)
      W:SetBorder(state.icon, {0,0,0,1}, 1)
      if itemID then state.icon:Show() else state.icon:Hide() end
    end
  end
end

local function UpdateState(state, buffs, now)
  local icon = state.icon
  if not state.itemID then icon:Hide(); return false end
  icon:Show()

  local start, duration, enabled = ReadCooldown(state.slot)
  local remaining = duration > 0 and math.max(0, (start + duration) - now) or 0
  if start > 0 and duration > 1 and (start ~= state.lastCooldownStart or duration ~= state.lastCooldownDuration) then
    state.activationUntil = now + 1.25
  end
  state.lastCooldownStart, state.lastCooldownDuration = start, duration

  local aura = FindTrinketAura(state, buffs)
  local theme = RUI:GetTheme()
  if aura then
    local auraRemaining = aura.expires and aura.expires > 0 and math.max(0, aura.expires - now) or 0
    icon.stackText:SetText(aura.count and aura.count > 1 and tostring(aura.count) or "")
    icon.cooldownText:SetText(auraRemaining > 0.05 and W:FormatCooldown(auraRemaining) or "")
    icon.cooldownText:SetTextColor(0.72, 1.00, 0.42, 1)
    if icon.cooldownShade then icon.cooldownShade:Hide() end
    icon:SetAlpha(1)
    if icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
    W:SetBorder(icon, theme.accent2, 1)
    local pulse = 0.72 + 0.28 * math.abs(math.sin(now * 7.5))
    W:SetGlow(icon, theme.accent2, pulse)
  elseif enabled ~= 0 and remaining > 0.05 then
    icon.stackText:SetText("")
    W:SetGlow(icon, nil, 0)
    W:SetBorder(icon, {0,0,0,1}, 1)
    W:SetCooldownDisplay(icon, remaining, true)
    icon:SetAlpha(0.58)
    if icon.texture.SetDesaturated then icon.texture:SetDesaturated(true) end
  else
    icon.stackText:SetText("")
    W:SetGlow(icon, nil, 0)
    W:SetBorder(icon, {0,0,0,1}, 1)
    W:SetCooldownDisplay(icon, 0, false)
    icon:SetAlpha(1)
    if icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
  end
  return true
end

function RUI:RefreshTrinketTracker(force)
  local db = EnsureDB()
  if db.enabled == false then
    if tracker then tracker:Hide() end
    return false
  end
  CreateTracker()
  ResizeTracker()
  RefreshItems(force == true)

  local player = PlayerFrame()
  if not player or not SafeShown(player) or (self.IsHUDOverlaySuppressed and self:IsHUDOverlaySuppressed()) then
    tracker:Hide()
    return false
  end

  local buffs = ReadPlayerBuffs()
  local shown = false
  local now = GetTime and GetTime() or 0
  for _, state in ipairs(states) do
    shown = UpdateState(state, buffs, now) or shown
  end
  if shown and PositionTracker() then tracker:Show() else tracker:Hide() end
  return shown
end

function RUI:InitializeTrinketTracker()
  CreateTracker()
  EnsureDB()
  if not driver then
    driver = CreateFrame("Frame")
    for _, event in ipairs({
      "PLAYER_ENTERING_WORLD",
      "PLAYER_EQUIPMENT_CHANGED",
      "UNIT_INVENTORY_CHANGED",
      "UNIT_AURA",
      "BAG_UPDATE_COOLDOWN",
      "SPELL_UPDATE_COOLDOWN",
    }) do
      pcall(driver.RegisterEvent, driver, event)
    end
    driver:SetScript("OnEvent", function(_, event, unit)
      if unit and unit ~= "player" then return end
      RUI:RefreshTrinketTracker(event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED")
    end)
    driver:SetScript("OnUpdate", function(_, delta)
      elapsed = elapsed + delta
      refreshElapsed = refreshElapsed + delta
      if elapsed < UPDATE_INTERVAL then return end
      elapsed = 0
      local force = false
      if refreshElapsed >= REFRESH_INTERVAL then
        refreshElapsed = 0
        force = false
      end
      RUI:RefreshTrinketTracker(force)
    end)
  end
  driver:Show()
  self:RefreshTrinketTracker(true)
  return true
end

function RUI:GetTrinketTrackerFrame()
  return tracker
end

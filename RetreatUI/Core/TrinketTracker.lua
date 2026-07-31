local RUI = RetreatUI
if not RUI or not RUI.HUDWidgets then return end

-- Trinket Tracker engine v2.
--
-- Ascension custom items do not always expose the same combination of item ID,
-- item link, texture and ElvUI frame globals as the stock 3.3 client. This
-- implementation reads each equipped slot through several independent paths,
-- never requires a standard item ID for visibility, and has a screen-position
-- fallback when no usable player-frame anchor exists.

local W = RUI.HUDWidgets
local SLOT_DEFINITIONS = {
  {slot=13, inventoryName="Trinket0Slot", buttonName="CharacterTrinket0Slot"},
  {slot=14, inventoryName="Trinket1Slot", buttonName="CharacterTrinket1Slot"},
}
local ICON_SPACING = 3
local DEFAULT_ICON_SIZE = 30
local UPDATE_INTERVAL = 0.10
local ITEM_REFRESH_INTERVAL = 0.50
local PLAYER_GAP = 2

local tracker
local driver
local bootstrap
local tooltipScanner
local states = {}
local elapsed = 0
local itemElapsed = 0
local previewMode = false
local initialized = false
local lastAnchorName = "none"

RUI.trinketTrackerEngineVersion = 2

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

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if not ok then return nil end
  return a, b, c, d, e
end

local function EnsureDB()
  local db = RUI:EnsureDB()
  db.trinketTracker = db.trinketTracker or {}
  db.trinketTracker.auraByItem = db.trinketTracker.auraByItem or {}
  if db.trinketTracker.enabled == nil then db.trinketTracker.enabled = true end
  return db.trinketTracker
end

local function ModuleEnabled()
  if type(RUI.IsInstallerModuleEnabled) == "function" then
    return RUI:IsInstallerModuleEnabled("trinketHUD")
  end
  return true
end

local function TrackerEnabled()
  return ModuleEnabled() and EnsureDB().enabled ~= false
end

local function IconSize()
  local layout = RUI.layout and RUI.layout.auraTrackers
  return math.max(18, Number(layout and layout.size, DEFAULT_ICON_SIZE))
end

local function FrameBounds(frame)
  if not frame then return nil end
  if type(frame.GetLeft) ~= "function" or type(frame.GetRight) ~= "function"
    or type(frame.GetTop) ~= "function" or type(frame.GetBottom) ~= "function" then return nil end
  local left = SafeCall(frame.GetLeft, frame)
  local right = SafeCall(frame.GetRight, frame)
  local top = SafeCall(frame.GetTop, frame)
  local bottom = SafeCall(frame.GetBottom, frame)
  local width = type(frame.GetWidth) == "function" and SafeCall(frame.GetWidth, frame) or nil
  local height = type(frame.GetHeight) == "function" and SafeCall(frame.GetHeight, frame) or nil
  if not left or not right or not top or not bottom then return nil end
  if width and width <= 4 then return nil end
  if height and height <= 4 then return nil end
  return {left=left, right=right, top=top, bottom=bottom}
end

local function AnchorCandidates()
  return {
    {name="ElvUF_Player", frame=_G.ElvUF_Player, mode="player"},
    {name="ElvUF_PlayerMover", frame=_G.ElvUF_PlayerMover, mode="player"},
    {name="PlayerFrame", frame=_G.PlayerFrame, mode="player"},
    {name="RetreatUIPrimaryPowerBar", frame=_G.RetreatUIPrimaryPowerBar, mode="power"},
  }
end

local function ResolveAnchor()
  for _, candidate in ipairs(AnchorCandidates()) do
    if FrameBounds(candidate.frame) then return candidate.frame, candidate.name, candidate.mode end
  end
  return nil, "UIParent fallback", "fallback"
end

local function CharacterSlotTexture(definition)
  local button = _G[definition.buttonName]
  local candidates = {
    _G[definition.buttonName .. "IconTexture"],
    button and button.icon,
    button and button.Icon,
    button and button.iconTexture,
  }
  if button and type(button.GetRegions) == "function" then
    for _, region in ipairs({button:GetRegions()}) do
      if region and type(region.GetTexture) == "function" then candidates[#candidates + 1] = region end
    end
  end
  for _, region in ipairs(candidates) do
    if region and type(region.GetTexture) == "function" then
      local texture = SafeCall(region.GetTexture, region)
      if texture and texture ~= "" then return texture end
    end
  end
  return nil
end

local function TooltipHasItem(slot)
  if not CreateFrame or not GameTooltip then return false, nil end
  if not tooltipScanner then
    tooltipScanner = CreateFrame("GameTooltip", "RetreatUITrinketTooltipScanner", UIParent, "GameTooltipTemplate")
  end
  if not tooltipScanner or type(tooltipScanner.SetInventoryItem) ~= "function" then return false, nil end
  tooltipScanner:SetOwner(UIParent or WorldFrame, "ANCHOR_NONE")
  tooltipScanner:ClearLines()
  local ok, hasItem = pcall(tooltipScanner.SetInventoryItem, tooltipScanner, "player", slot)
  if not ok then return false, nil end
  local name
  local line = _G.RetreatUITrinketTooltipScannerTextLeft1
  if line and type(line.GetText) == "function" then name = line:GetText() end
  tooltipScanner:Hide()
  return hasItem == true, name
end

local function ItemInfoTexture(itemReference)
  if not itemReference or type(GetItemInfo) ~= "function" then return nil, nil end
  local ok, name, _, _, _, _, _, _, _, texture = pcall(GetItemInfo, itemReference)
  if not ok then return nil, nil end
  return texture, name
end

local function ReadCooldown(slot)
  if type(GetInventoryItemCooldown) ~= "function" then return 0, 0, 0 end
  local start, duration, enabled = SafeCall(GetInventoryItemCooldown, "player", slot)
  return Number(start, 0), Number(duration, 0), Number(enabled, 0)
end

local function SlotData(definition)
  local slot = definition.slot
  local itemID = type(GetInventoryItemID) == "function" and SafeCall(GetInventoryItemID, "player", slot) or nil
  local link = type(GetInventoryItemLink) == "function" and SafeCall(GetInventoryItemLink, "player", slot) or nil
  if not itemID and type(link) == "string" then itemID = tonumber(link:match("item:(%d+)")) end

  local texture = type(GetInventoryItemTexture) == "function" and SafeCall(GetInventoryItemTexture, "player", slot) or nil
  local source = texture and "inventory texture" or nil
  local itemInfoTexture, itemName = ItemInfoTexture(itemID or link)
  if not texture and itemInfoTexture then texture, source = itemInfoTexture, "item info" end

  local tooltipEquipped, tooltipName = TooltipHasItem(slot)
  itemName = itemName or tooltipName

  local paperTexture = CharacterSlotTexture(definition)
  local _, emptyTexture = type(GetInventorySlotInfo) == "function" and GetInventorySlotInfo(definition.inventoryName) or nil, nil
  if type(GetInventorySlotInfo) == "function" then
    local _, resolvedEmpty = SafeCall(GetInventorySlotInfo, definition.inventoryName)
    emptyTexture = resolvedEmpty
  end
  local paperLooksEquipped = paperTexture ~= nil and (emptyTexture == nil or tostring(paperTexture) ~= tostring(emptyTexture))
  if not texture and paperLooksEquipped then texture, source = paperTexture, "paper-doll texture" end

  local start, duration, enabled = ReadCooldown(slot)
  local cooldownEvidence = start > 0 or duration > 0
  local equipped = itemID ~= nil or link ~= nil or texture ~= nil or tooltipEquipped or cooldownEvidence

  if not source then
    if itemID then source = "item ID"
    elseif link then source = "item link"
    elseif tooltipEquipped then source = "inventory tooltip"
    elseif cooldownEvidence then source = "slot cooldown"
    else source = "empty" end
  end

  local key
  if itemID then key = "id:" .. tostring(itemID)
  elseif link then key = "link:" .. tostring(link)
  elseif itemName then key = "name:" .. Normalize(itemName)
  else key = "slot:" .. tostring(slot) end

  return {
    slot=slot,
    itemID=Number(itemID, nil),
    link=link,
    name=itemName,
    texture=texture,
    equipped=equipped == true,
    source=source,
    key=key,
    cooldownStart=start,
    cooldownDuration=duration,
    cooldownEnabled=enabled,
  }
end

local function ReadPlayerBuffs()
  local result = {list={}, byID={}, byName={}}
  if type(UnitBuff) ~= "function" then return result end
  for index = 1, 40 do
    local values = {UnitBuff("player", index)}
    local name = values[1]
    if not name then break end
    local aura = {
      name=name,
      icon=values[3],
      count=Number(values[4], 0),
      duration=Number(values[6], 0),
      expires=Number(values[7], 0),
      caster=values[8],
      spellID=Number(values[11], nil),
    }
    result.list[#result.list + 1] = aura
    result.byName[Normalize(name)] = aura
    if aura.spellID then result.byID[aura.spellID] = aura end
  end
  return result
end

local function ItemSpell(data)
  if type(GetItemSpell) ~= "function" then return nil, nil, nil end
  local reference = data.itemID or data.link
  if not reference then return nil, nil, nil end
  local name, spellID = SafeCall(GetItemSpell, reference)
  spellID = Number(spellID, nil)
  local texture
  if type(GetSpellInfo) == "function" then
    if spellID then local _, _, found = GetSpellInfo(spellID); texture = found end
    if not texture and name then local _, _, found = GetSpellInfo(name); texture = found end
  end
  return name, spellID, texture
end

local function LearnedAura(data)
  local db = EnsureDB()
  return db.auraByItem[data.key]
end

local function SaveLearnedAura(data, aura)
  if not data or not aura then return end
  local db = EnsureDB()
  db.auraByItem[data.key] = {name=aura.name, spellID=aura.spellID}
end

local function FindAura(state, buffs)
  local data = state.data
  if not data then return nil end
  local learned = LearnedAura(data)
  if learned then
    local aura = learned.spellID and buffs.byID[Number(learned.spellID, nil)] or nil
    aura = aura or buffs.byName[Normalize(learned.name)]
    if aura then return aura end
  end

  local aura = state.itemSpellID and buffs.byID[state.itemSpellID] or nil
  aura = aura or buffs.byName[Normalize(state.itemSpellName)]
  if aura then SaveLearnedAura(data, aura); return aura end

  for _, candidate in ipairs(buffs.list) do
    local own = candidate.caster == nil or candidate.caster == "player"
    local spellTextureMatch = state.itemSpellTexture and candidate.icon == state.itemSpellTexture
    local activationTextureMatch = state.activationUntil and (GetTime and GetTime() or 0) <= state.activationUntil
      and data.texture and candidate.icon == data.texture
    if own and candidate.duration > 0 and (spellTextureMatch or activationTextureMatch) then
      SaveLearnedAura(data, candidate)
      return candidate
    end
  end
  return nil
end

local function ConfigureTooltip(icon, slot)
  icon:EnableMouse(true)
  icon:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
    local shown = false
    if type(GameTooltip.SetInventoryItem) == "function" then
      shown = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", slot)
    end
    if not shown then GameTooltip:SetText("Trinket slot " .. tostring(slot), 1, 1, 1) end
    GameTooltip:Show()
  end)
  icon:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function CreateTracker()
  if tracker then return tracker end
  local size = IconSize()
  local total = size * #SLOT_DEFINITIONS + ICON_SPACING * (#SLOT_DEFINITIONS - 1)
  tracker = CreateFrame("Frame", "RetreatUITrinketTracker", UIParent)
  tracker:SetSize(total, size)
  tracker:SetFrameStrata("HIGH")
  tracker:SetFrameLevel(30)
  tracker:SetClampedToScreen(true)
  tracker.icons = {}

  for index, definition in ipairs(SLOT_DEFINITIONS) do
    local icon = W:CreateIcon(tracker, size)
    icon.slot = definition.slot
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", tracker, "LEFT", (index - 1) * (size + ICON_SPACING), 0)
    ConfigureTooltip(icon, definition.slot)
    tracker.icons[index] = icon
    states[index] = {
      definition=definition,
      icon=icon,
      data=nil,
      lastKey=nil,
      lastCooldownStart=0,
      lastCooldownDuration=0,
      activationUntil=nil,
    }
  end
  tracker:Hide()
  return tracker
end

local function ResizeTracker()
  if not tracker then return end
  local size = IconSize()
  local total = size * #SLOT_DEFINITIONS + ICON_SPACING * (#SLOT_DEFINITIONS - 1)
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
  local anchor, name, mode = ResolveAnchor()
  tracker:ClearAllPoints()
  if anchor and mode == "player" then
    tracker:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, PLAYER_GAP)
  elseif anchor and mode == "power" then
    tracker:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
  else
    local powerLayout = RUI.layout and RUI.layout.power or {x=0, y=-152, width=360, height=16}
    local x = (Number(powerLayout.x, 0) - Number(powerLayout.width, 360) / 2) + tracker:GetWidth() / 2
    local y = Number(powerLayout.y, -152) + Number(powerLayout.height, 16) / 2 + tracker:GetHeight() / 2 + 5
    tracker:SetPoint("CENTER", UIParent, "CENTER", x, y)
  end
  lastAnchorName = name
  return true
end

local function RefreshSlotState(state, force)
  local data = SlotData(state.definition)
  local changed = force or state.lastKey ~= data.key
    or not state.data or state.data.texture ~= data.texture or state.data.equipped ~= data.equipped
  state.data = data
  if changed then
    state.lastKey = data.key
    state.activationUntil = nil
    state.lastCooldownStart = data.cooldownStart
    state.lastCooldownDuration = data.cooldownDuration
    state.itemSpellName, state.itemSpellID, state.itemSpellTexture = ItemSpell(data)
    state.icon.texture:SetTexture(data.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    state.icon.stackText:SetText("")
    state.icon.cooldownText:SetText("")
    W:SetGlow(state.icon, nil, 0)
    W:SetBorder(state.icon, {0,0,0,1}, 1)
  end
end

local function PreviewData(index)
  return {
    slot=SLOT_DEFINITIONS[index].slot,
    equipped=true,
    texture=index == 1 and "Interface\\Icons\\INV_Jewelry_TrinketPVP_01" or "Interface\\Icons\\INV_Jewelry_TrinketPVP_02",
    source="preview",
    key="preview:" .. tostring(index),
    cooldownStart=0,
    cooldownDuration=0,
    cooldownEnabled=1,
  }
end

local function UpdateState(state, buffs, now, previewIndex)
  local icon = state.icon
  local data = previewIndex and PreviewData(previewIndex) or state.data
  if not data or not data.equipped then icon:Hide(); return false end

  icon.texture:SetTexture(data.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
  icon:Show()

  local start = Number(data.cooldownStart, 0)
  local duration = Number(data.cooldownDuration, 0)
  local enabled = Number(data.cooldownEnabled, 0)
  if not previewIndex then
    start, duration, enabled = ReadCooldown(data.slot)
    if start > 0 and duration > 1 and (start ~= state.lastCooldownStart or duration ~= state.lastCooldownDuration) then
      state.activationUntil = now + 1.25
    end
    state.lastCooldownStart, state.lastCooldownDuration = start, duration
  elseif previewIndex == 2 then
    start, duration, enabled = now - 5, 45, 1
  end

  local remaining = duration > 0 and math.max(0, start + duration - now) or 0
  local aura = not previewIndex and FindAura(state, buffs) or nil
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
    W:SetGlow(icon, theme.accent2, 0.90)
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
  CreateTracker()
  ResizeTracker()
  if not TrackerEnabled() and not previewMode then
    tracker:Hide()
    return false
  end
  if self.IsHUDOverlaySuppressed and self:IsHUDOverlaySuppressed() then
    tracker:Hide()
    return false
  end

  for _, state in ipairs(states) do RefreshSlotState(state, force == true) end
  local buffs = ReadPlayerBuffs()
  local now = GetTime and GetTime() or 0
  local shown = false
  for index, state in ipairs(states) do
    shown = UpdateState(state, buffs, now, previewMode and index or nil) or shown
  end

  if shown then
    PositionTracker()
    tracker:Show()
  else
    tracker:Hide()
  end
  return shown
end

function RUI:InitializeTrinketTracker()
  CreateTracker()
  EnsureDB()
  initialized = true
  if not driver then
    driver = CreateFrame("Frame", "RetreatUITrinketTrackerDriverV2")
    for _, event in ipairs({
      "PLAYER_LOGIN",
      "PLAYER_ENTERING_WORLD",
      "PLAYER_EQUIPMENT_CHANGED",
      "UNIT_INVENTORY_CHANGED",
      "UNIT_AURA",
      "BAG_UPDATE_COOLDOWN",
      "SPELL_UPDATE_COOLDOWN",
      "PLAYER_REGEN_ENABLED",
      "UI_SCALE_CHANGED",
    }) do pcall(driver.RegisterEvent, driver, event) end
    driver:SetScript("OnEvent", function(_, event, unit)
      if unit and unit ~= "player" then return end
      local force = event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED"
        or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN"
      RUI:RefreshTrinketTracker(force)
      if force and RUI.After then
        for _, delay in ipairs({0.20, 0.80, 2.00}) do
          RUI:After(delay, function() RUI:RefreshTrinketTracker(true) end)
        end
      end
    end)
    driver:SetScript("OnUpdate", function(_, delta)
      elapsed = elapsed + delta
      itemElapsed = itemElapsed + delta
      if elapsed < UPDATE_INTERVAL then return end
      elapsed = 0
      local force = itemElapsed >= ITEM_REFRESH_INTERVAL
      if force then itemElapsed = 0 end
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

function RUI:ToggleTrinketTrackerPreview(force)
  if force == nil then previewMode = not previewMode else previewMode = force == true end
  self:RefreshTrinketTracker(true)
  return previewMode
end

function RUI:GetTrinketTrackerStatus()
  local slots = {}
  for index, state in ipairs(states) do
    local data = state.data or SlotData(SLOT_DEFINITIONS[index])
    slots[index] = {
      slot=data.slot,
      equipped=data.equipped,
      itemID=data.itemID,
      link=data.link,
      texture=data.texture,
      source=data.source,
      iconShown=state.icon and state.icon.IsShown and state.icon:IsShown() or false,
    }
  end
  return {
    engine=2,
    initialized=initialized,
    enabled=TrackerEnabled(),
    frameShown=tracker and tracker.IsShown and tracker:IsShown() or false,
    anchor=lastAnchorName,
    preview=previewMode,
    slots=slots,
  }
end

local function PrintStatus()
  local status = RUI:GetTrinketTrackerStatus()
  RUI:Print("Trinket engine " .. tostring(status.engine)
    .. " | initialized: " .. tostring(status.initialized)
    .. " | enabled: " .. tostring(status.enabled)
    .. " | shown: " .. tostring(status.frameShown)
    .. " | anchor: " .. tostring(status.anchor))
  for _, slot in ipairs(status.slots or {}) do
    RUI:Print("Slot " .. tostring(slot.slot)
      .. " | equipped: " .. tostring(slot.equipped)
      .. " | itemID: " .. tostring(slot.itemID or "nil")
      .. " | texture: " .. tostring(slot.texture or "nil")
      .. " | source: " .. tostring(slot.source)
      .. " | icon: " .. tostring(slot.iconShown))
  end
end

SLASH_RETREATUITRINKETS1 = "/ruit"
SlashCmdList.RETREATUITRINKETS = function(message)
  local command = Normalize(message)
  if command == "preview" then
    local shown = RUI:ToggleTrinketTrackerPreview()
    RUI:Print("Trinket preview: " .. (shown and "shown" or "hidden"))
  elseif command == "refresh" then
    RUI:InitializeTrinketTracker()
    RUI:RefreshTrinketTracker(true)
    PrintStatus()
  else
    PrintStatus()
  end
end

bootstrap = CreateFrame("Frame", "RetreatUITrinketTrackerBootstrapV2")
bootstrap:RegisterEvent("PLAYER_LOGIN")
bootstrap:RegisterEvent("PLAYER_ENTERING_WORLD")
bootstrap:SetScript("OnEvent", function()
  if RUI.After then
    RUI:After(0.35, function()
      if TrackerEnabled() then RUI:InitializeTrinketTracker() end
    end)
  elseif TrackerEnabled() then
    RUI:InitializeTrinketTracker()
  end
end)

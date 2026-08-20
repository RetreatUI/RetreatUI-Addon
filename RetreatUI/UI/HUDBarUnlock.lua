local RUI = RetreatUI
if not RUI then return end

local TEX = "Interface\\Buttons\\WHITE8X8"
local ACCENT = {1.00, 0.34, 0.10, 1}
local MUTED = {0.58, 0.60, 0.66, 1}
local overlay
local movers = {}

local function Font(fs, size, outline)
  if RUI.ApplyFont then RUI:ApplyFont(fs, size or 11, outline or "")
  else fs:SetFont(STANDARD_TEXT_FONT, size or 11, outline or "") end
end

local function Solid(parent, r, g, b, a, layer)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetTexture(TEX)
  t:SetVertexColor(r, g, b, a or 1)
  return t
end

local function FrameSize(bar)
  local count = math.max(1, tonumber(bar.slotCount) or 1)
  local size = math.max(20, tonumber(bar.iconSize) or 36)
  local spacing = math.max(0, tonumber(bar.spacing) or 0)
  if bar.orientation == "VERTICAL" then
    return size, (count * size) + ((count - 1) * spacing)
  end
  return (count * size) + ((count - 1) * spacing), size
end

local function SaveMoverPosition(mover)
  if not mover or not mover.barID then return end
  local cx, cy = mover:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if not cx or not cy or not ux or not uy then return end
  local scale = UIParent:GetEffectiveScale() or 1
  local x = (cx - ux) / scale
  local y = (cy - uy) / scale
  RUI:UpdateHUDBar(mover.barID, {x=x, y=y}, mover.className)
  if mover.coords then mover.coords:SetText(string.format("%d, %d", math.floor(x + .5), math.floor(y + .5))) end
end

local function BuildMover(bar, className)
  local mover = CreateFrame("Frame", nil, overlay)
  mover.barID = bar.id
  mover.className = className
  mover:SetFrameStrata("FULLSCREEN_DIALOG")
  mover:SetMovable(true)
  mover:EnableMouse(true)
  mover:RegisterForDrag("LeftButton")
  mover:SetClampedToScreen(true)

  local width, height = FrameSize(bar)
  mover:SetSize(math.max(width, 80), math.max(height, 30))
  mover:SetPoint("CENTER", UIParent, "CENTER", tonumber(bar.x) or 0, tonumber(bar.y) or 0)

  mover.bg = Solid(mover, .06, .025, .012, .72)
  mover.bg:SetAllPoints()
  mover:SetBackdrop({bgFile=TEX, edgeFile=TEX, edgeSize=2})
  mover:SetBackdropColor(.06, .025, .012, .72)
  mover:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], .95)

  mover.title = mover:CreateFontString(nil, "OVERLAY")
  Font(mover.title, 11, "OUTLINE")
  mover.title:SetText(tostring(bar.name or "HUD Bar"))
  mover.title:SetTextColor(1, .82, .68, 1)
  mover.title:SetPoint("BOTTOM", mover, "TOP", 0, 5)

  mover.coords = mover:CreateFontString(nil, "OVERLAY")
  Font(mover.coords, 9, "OUTLINE")
  mover.coords:SetTextColor(MUTED[1], MUTED[2], MUTED[3], 1)
  mover.coords:SetPoint("TOP", mover, "BOTTOM", 0, -4)
  mover.coords:SetText(string.format("%d, %d", tonumber(bar.x) or 0, tonumber(bar.y) or 0))

  mover.slots = {}
  local size = math.max(20, tonumber(bar.iconSize) or 36)
  local spacing = math.max(0, tonumber(bar.spacing) or 0)
  local count = math.max(1, tonumber(bar.slotCount) or 1)
  for index = 1, count do
    local slot = CreateFrame("Frame", nil, mover)
    slot:SetSize(size, size)
    slot:SetBackdrop({bgFile=TEX, edgeFile=TEX, edgeSize=1})
    slot:SetBackdropColor(.025, .027, .032, .84)
    slot:SetBackdropBorderColor(.28, .29, .33, 1)
    if bar.orientation == "VERTICAL" then
      slot:SetPoint("TOP", mover, "TOP", 0, -((index - 1) * (size + spacing)))
    else
      slot:SetPoint("LEFT", mover, "LEFT", (index - 1) * (size + spacing), 0)
    end
    local num = slot:CreateFontString(nil, "OVERLAY")
    Font(num, 9, "OUTLINE")
    num:SetText(index)
    num:SetTextColor(.72, .72, .76, .9)
    num:SetPoint("CENTER")
    mover.slots[index] = slot
  end

  mover:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then return end
    self:StartMoving()
    self:SetBackdropBorderColor(1, .65, .20, 1)
  end)
  mover:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], .95)
    SaveMoverPosition(self)
  end)

  movers[#movers + 1] = mover
  return mover
end

local function ClearMovers()
  for _, mover in ipairs(movers) do
    mover:Hide()
    mover:SetParent(nil)
  end
  wipe(movers)
end

local function EnsureOverlay()
  if overlay then return overlay end
  overlay = CreateFrame("Frame", "RetreatUIHUDBarUnlockOverlay", UIParent)
  overlay:SetAllPoints(UIParent)
  overlay:SetFrameStrata("FULLSCREEN_DIALOG")
  overlay:EnableMouse(false)
  overlay:Hide()

  local banner = CreateFrame("Frame", nil, overlay)
  banner:SetSize(430, 54)
  banner:SetPoint("TOP", UIParent, "TOP", 0, -34)
  banner:SetBackdrop({bgFile=TEX, edgeFile=TEX, edgeSize=1})
  banner:SetBackdropColor(.018, .020, .024, .96)
  banner:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], .85)

  local title = banner:CreateFontString(nil, "OVERLAY")
  Font(title, 14)
  title:SetText("RetreatUI HUD Unlock")
  title:SetTextColor(1, 1, 1, 1)
  title:SetPoint("TOPLEFT", 14, -9)

  local hint = banner:CreateFontString(nil, "OVERLAY")
  Font(hint, 10)
  hint:SetText("Drag your HUD bars. Positions save when you release the mouse.")
  hint:SetTextColor(MUTED[1], MUTED[2], MUTED[3], 1)
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)

  local lock = CreateFrame("Button", nil, banner)
  lock:SetSize(74, 30)
  lock:SetPoint("RIGHT", -10, 0)
  lock:SetBackdrop({bgFile=TEX, edgeFile=TEX, edgeSize=1})
  lock:SetBackdropColor(.12, .07, .045, 1)
  lock:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
  lock.text = lock:CreateFontString(nil, "OVERLAY")
  Font(lock.text, 10)
  lock.text:SetText("Lock")
  lock.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
  lock.text:SetPoint("CENTER")
  lock:SetScript("OnClick", function() RUI:CloseHUDBarUnlockMode() end)

  overlay.banner = banner
  return overlay
end

function RUI:OpenHUDBarUnlockMode(className, onlyBarID)
  if InCombatLockdown and InCombatLockdown() then return false, "Leave combat before unlocking HUD bars" end
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  local bars = self:GetHUDBars(className)
  if #bars == 0 then return false, "Create a HUD bar first" end

  EnsureOverlay()
  ClearMovers()
  local shown = 0
  for _, bar in ipairs(bars) do
    if not onlyBarID or bar.id == onlyBarID then
      BuildMover(bar, className)
      shown = shown + 1
    end
  end
  if shown == 0 then return false, "HUD bar not found" end
  overlay:Show()
  return true, onlyBarID and "HUD bar unlocked" or "HUD bars unlocked"
end

function RUI:CloseHUDBarUnlockMode()
  if overlay then overlay:Hide() end
  ClearMovers()
  return true
end

function RUI:ToggleHUDBarUnlockMode(className)
  EnsureOverlay()
  if overlay:IsShown() then return self:CloseHUDBarUnlockMode() end
  return self:OpenHUDBarUnlockMode(className)
end

RUI._hudBarUnlockLoaded = true
RUI.hudBarUnlockSchema = 1

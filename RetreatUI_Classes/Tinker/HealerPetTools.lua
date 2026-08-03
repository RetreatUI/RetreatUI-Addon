local RUI = RetreatUI
if not RUI or not RUI.HUDWidgets then return end

-- Native personal-pet tools from https://wago.io/w-XCZHABg.
-- This is not party utility or interrupt tracking: it only reads the player's
-- own Tinker pet, its mana and its five exposed pet actions.
local W = RUI.HUDWidgets
local container
local manaBar
local manaText
local icons = {}
local elapsed = 0

local PET_ACTIONS = {
  {name="Pet Recharge", id=808010},
  {name="Pet Disarm", id=578123},
  {name="Pet Bomb", id=578124},
  {name="Pet Interrupt", id=581313},
  {name="Pet Mana", id=578122},
}

local function TinkerHealerActive()
  local root = _G.RetreatUITinkerHUD
  if not root or not root.IsShown or not root:IsShown() then return false end
  if RUI.activeClass and RUI.activeClass ~= "Tinker" then return false end
  if type(UnitExists) ~= "function" or not UnitExists("pet") then return false end
  if RUI.IsSpellIDLearned then
    return RUI:IsSpellIDLearned(800347) or RUI:IsSpellIDLearned(801801)
      or RUI:IsSpellIDLearned(524835) or RUI:IsSpellIDLearned(805308)
  end
  return true
end

local function EnsureFrames()
  if container then return end
  container = CreateFrame("Frame", "RetreatUITinkerHealerPetTracker", UIParent)
  container:SetSize(150, 40)
  container:SetFrameStrata("MEDIUM")
  container:Hide()

  for index, definition in ipairs(PET_ACTIONS) do
    local icon = W:CreateIcon(container, 24)
    icon.definition = definition
    icon:ClearAllPoints()
    icon:SetPoint("TOP", container, "TOP", (index - 3) * 26, 0)
    local texture = GetSpellInfo and select(3, GetSpellInfo(definition.id))
    icon.texture:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    icon.stackText:SetText("")
    icon:Show()
    icons[index] = icon
  end

  manaBar = CreateFrame("StatusBar", nil, container)
  manaBar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 5, 0)
  manaBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -5, 0)
  manaBar:SetHeight(7)
  manaBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  manaBar:SetMinMaxValues(0, 1)
  manaBar:SetValue(0)
  RUI:SkinFrame(manaBar, {0.04, 0.04, 0.04, 0.94}, {0, 0, 0, 1})

  manaText = manaBar:CreateFontString(nil, "OVERLAY")
  manaText:SetPoint("CENTER", manaBar, "CENTER", 0, 0)
  RUI:ApplyFont(manaText, 8, "OUTLINE")
  manaText:SetText("")

  if type(RUI.RegisterHUDVisibilityFrame) == "function" then
    RUI:RegisterHUDVisibilityFrame(container, TinkerHealerActive)
  end
end

local function Position()
  local root = _G.RetreatUITinkerHUD
  container:ClearAllPoints()
  if root and root.utilityRow then
    container:SetPoint("TOP", root.utilityRow, "BOTTOM", 0, -5)
  else
    local layout = RUI.layout and RUI.layout.demonfire or {x=0, y=-118}
    container:SetPoint("CENTER", UIParent, "CENTER", tonumber(layout.x) or 0, (tonumber(layout.y) or -118) - 84)
  end
  if RUI.ApplyHUDFrameScale then RUI:ApplyHUDFrameScale(container, "demonfire") end
end

local function Update()
  EnsureFrames()
  if not TinkerHealerActive() then
    container:Hide()
    return
  end

  Position()
  local theme = RUI:GetTheme()
  local now = GetTime()
  for _, icon in ipairs(icons) do
    local definition = icon.definition
    local start, duration, enabled = 0, 0, 0
    if GetSpellCooldown then
      local ok, a, b, c = pcall(GetSpellCooldown, definition.id)
      if ok then start, duration, enabled = tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0 end
    end
    local remaining = duration > 0 and math.max(0, start + duration - now) or 0
    local active = duration > 1.5 and remaining > 0.05 and enabled ~= 0
    W:SetCooldownDisplay(icon, remaining, active)
    if icon.texture.SetDesaturated then icon.texture:SetDesaturated(active) end
    W:SetBorder(icon, active and {0,0,0,1} or theme.accent2, 1)
    icon:Show()
  end

  local current = UnitPower and tonumber(UnitPower("pet", 0)) or 0
  local maximum = UnitPowerMax and tonumber(UnitPowerMax("pet", 0)) or 0
  maximum = maximum and maximum > 0 and maximum or 1
  current = math.max(0, math.min(maximum, current or 0))
  manaBar:SetMinMaxValues(0, maximum)
  manaBar:SetValue(current)
  manaBar:SetStatusBarColor(0.16, 0.45, 1.00, 1)
  manaText:SetText(string.format("%d / %d", current, maximum))
  container:Show()
end

local driver = CreateFrame("Frame", "RetreatUITinkerHealerPetDriver")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UNIT_PET", "UNIT_POWER",
  "UNIT_MANA", "SPELL_UPDATE_COOLDOWN", "SPELLS_CHANGED",
}) do
  pcall(driver.RegisterEvent, driver, eventName)
end
driver:SetScript("OnEvent", Update)
driver:SetScript("OnUpdate", function(_, delta)
  elapsed = elapsed + delta
  if elapsed < 0.10 then return end
  elapsed = 0
  Update()
end)

RUI._tinkerHealerPetToolsLoaded = true

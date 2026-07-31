local RUI = RetreatUI

local PLAYER_DEBUFFS = {
  "Curse of Xoroth", "Torn Flesh", "Ritual Fire", "Bulwark of Xoroth",
  "Pestilence of Famine", "Pestilence of War", "Pestilence of Conquest",
}

local function SafeSetCVar(name, value)
  if type(SetCVar) ~= "function" then return false end
  return pcall(SetCVar, name, tostring(value))
end

local function EnsureTurboTables()
  if type(TurboPlatesDB) ~= "table" then return nil end
  TurboPlatesDB.auras = TurboPlatesDB.auras or {}
  TurboPlatesDB.auras.whitelist = TurboPlatesDB.auras.whitelist or {}
  TurboPlatesDB.auras.blacklist = TurboPlatesDB.auras.blacklist or {}
  TurboPlatesDB.highlightSpells = TurboPlatesDB.highlightSpells or {}
  TurboPlatesDB.stacking = TurboPlatesDB.stacking or {}
  return TurboPlatesDB
end

function RUI:ApplyMobSpellsToTurboPlates()
  local db = EnsureTurboTables()
  if not db then return false, "TurboPlates is not loaded" end
  if type(MobSpellsDB) ~= "table" then
    return false, "MobSpells is not loaded; NPC spell whitelisting is unavailable"
  end

  local spellCount, namedCount = 0, 0
  for _, records in pairs(MobSpellsDB) do
    if type(records) == "table" then
      for _, record in ipairs(records) do
        local spellID = type(record) == "table" and tonumber(record[1]) or nil
        if spellID and spellID > 0 then
          if not db.auras.whitelist[spellID] then
            db.auras.whitelist[spellID] = true
            spellCount = spellCount + 1
          end
          local spellName = GetSpellInfo and GetSpellInfo(spellID)
          if spellName and spellName ~= "" and not db.highlightSpells[spellName] then
            db.highlightSpells[spellName] = true
            namedCount = namedCount + 1
          end
        end
      end
    end
  end

  db.auras.showBuffs = true
  db.auras.buffFilterMode = "WHITELIST_DISPELLABLE"
  db.showCastbar = true
  db.showCastIcon = true
  db.showCastTimer = true
  db.highlightGlowEnabled = true
  db.highlightGlowColor = {r = 1, g = 0.25, b = 0.05}

  local ruiDB = self:EnsureDB()
  ruiDB.integrations.mobSpells = ruiDB.integrations.mobSpells or {}
  ruiDB.integrations.mobSpells.enabled = true
  ruiDB.integrations.mobSpells.whitelistEntries = spellCount
  ruiDB.integrations.mobSpells.highlightEntries = namedCount
  ruiDB.integrations.mobSpells.version = self.version

  return true, "MobSpells NPC abilities added to TurboPlates aura and cast whitelists"
end

function RUI:ApplyTurboPlatesStacking()
  local db = EnsureTurboTables()
  if not db then return false, "TurboPlates is not loaded" end

  local stacking = db.stacking
  stacking.enabled = true
  stacking.preset = "snappy"
  stacking.springFrequencyRaise = 13
  stacking.springFrequencyLower = 11
  stacking.launchDamping = 0.9
  stacking.settleThreshold = 1
  stacking.xSpaceRatio = 1.05
  stacking.ySpaceRatio = 1.15
  stacking.originPosRatio = 0
  stacking.upperBorder = 60
  stacking.maxPlates = 60

  -- Fallback CVars for clients where TurboPlates' custom stacking starts late.
  SafeSetCVar("nameplateMotion", 1)
  SafeSetCVar("nameplateOverlapH", 0.8)
  SafeSetCVar("nameplateOverlapV", 1.15)

  return true, "TurboPlates nameplate stacking enabled with extra vertical spacing"
end

local MANA_BLUE = {0.10, 0.46, 1.00, 1}
local MANA_BLUE_DARK = {0.02, 0.10, 0.24, 0.96}
local MANA_BLUE_BORDER = {0.16, 0.62, 1.00, 1}
local manaColorFrame
local manaNameCache = {}
local manaGuidCache = {}
local activeColorObjects = setmetatable({}, {__mode="k"})
local discoveredPlateRoots = setmetatable({}, {__mode="k"})
local discoveryElapsed = 0
local turboNamespace
local turboNamespaceSearched = false

local function SafeObjectType(value)
  if not value or type(value.GetObjectType) ~= "function" then return nil end
  local ok, objectType = pcall(value.GetObjectType, value)
  return ok and objectType or nil
end

local function IsFrame(value)
  local objectType = SafeObjectType(value)
  return objectType == "Frame" or objectType == "Button" or objectType == "StatusBar"
end

local function IsStatusBar(value)
  return value and type(value.SetStatusBarColor) == "function"
    and (SafeObjectType(value) == "StatusBar" or type(value.GetMinMaxValues) == "function")
end

local function IsTexture(value)
  return value and type(value.SetVertexColor) == "function" and SafeObjectType(value) == "Texture"
end

local function IsTurboBorder(value)
  return type(value) == "table"
    and type(value.SetColor) == "function"
    and type(value.GetColor) == "function"
    and value.top and value.bottom and value.left and value.right
end

local function IsShown(value)
  if not value or type(value.IsShown) ~= "function" then return true end
  local ok, shown = pcall(value.IsShown, value)
  return not ok or shown == true
end

local function FrameName(value)
  if not value or type(value.GetName) ~= "function" then return "" end
  local ok, name = pcall(value.GetName, value)
  return ok and string.lower(tostring(name or "")) or ""
end

local function NormalizePlateName(value)
  value = tostring(value or "")
  value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local MANA_CLASS_TOKENS = {
  MAGE=true, PRIEST=true, WARLOCK=true, SHAMAN=true, PALADIN=true, DRUID=true,
}
local NON_MANA_CLASS_TOKENS = {
  WARRIOR=true, ROGUE=true, HUNTER=true, DEATHKNIGHT=true,
}

local function UnitManaEvidence(unit)
  if not unit or type(UnitExists) ~= "function" or not UnitExists(unit) then
    return false, "missing_unit", nil, nil, nil, 0, 0
  end

  if type(UnitIsFriend) == "function" then
    local friendOK, friendly = pcall(UnitIsFriend, "player", unit)
    if friendOK and friendly == true then
      return false, "friendly", nil, nil, nil, 0, 0
    end
  end

  local manaType = tonumber(_G.SPELL_POWER_MANA) or 0
  if type(UnitPowerType) ~= "function" then
    return false, "no_power_api", nil, nil, nil, 0, 0
  end
  local typeOK, powerType, token = pcall(UnitPowerType, unit)
  if not typeOK then return false, "power_type_error", nil, nil, nil, 0, 0 end
  local typeIsMana = tonumber(powerType) == manaType
    or powerType == "MANA"
    or token == "MANA"
    or token == "Mana"
    or token == "mana"
  if not typeIsMana then
    return false, "non_mana_power", nil, powerType, token, 0, 0
  end

  local maximum, current = 0, 0
  if type(UnitPowerMax) == "function" then
    local ok, value = pcall(UnitPowerMax, unit, manaType)
    if ok then maximum = math.max(maximum, tonumber(value) or 0) end
  end
  if type(UnitManaMax) == "function" then
    local ok, value = pcall(UnitManaMax, unit)
    if ok then maximum = math.max(maximum, tonumber(value) or 0) end
  end
  if type(UnitPower) == "function" then
    local ok, value = pcall(UnitPower, unit, manaType)
    if ok then current = math.max(current, tonumber(value) or 0) end
  end
  if type(UnitMana) == "function" then
    local ok, value = pcall(UnitMana, unit)
    if ok then current = math.max(current, tonumber(value) or 0) end
  end
  if maximum <= 0 then
    return false, "no_mana_pool", nil, powerType, token, maximum, current
  end

  local classToken
  if type(UnitClass) == "function" then
    local ok, _, tokenValue = pcall(UnitClass, unit)
    if ok then classToken = tokenValue end
  end
  if classToken and NON_MANA_CLASS_TOKENS[classToken] then
    return false, "non_mana_class", classToken, powerType, token, maximum, current
  end
  if classToken and MANA_CLASS_TOKENS[classToken] then
    return true, "mana_class", classToken, powerType, token, maximum, current
  end

  local isPlayer = false
  if type(UnitIsPlayer) == "function" then
    local ok, value = pcall(UnitIsPlayer, unit)
    isPlayer = ok and value == true
  end
  if isPlayer then
    return false, "unknown_player_class", classToken, powerType, token, maximum, current
  end

  -- Ascension exposes a synthetic 100-point MANA pool on many ordinary
  -- NPCs. Only an unclassified NPC with a pool above that default is
  -- accepted as a real mana user.
  if maximum <= 100 then
    return false, "synthetic_100_pool", classToken, powerType, token, maximum, current
  end
  return true, "large_npc_mana_pool", classToken, powerType, token, maximum, current
end

local function UnitUsesMana(unit)
  local usesMana = UnitManaEvidence(unit)
  return usesMana == true
end

local UNIT_CANDIDATES = {"target", "mouseover", "focus", "boss1", "boss2", "boss3", "boss4"}
for index = 1, 40 do UNIT_CANDIDATES[#UNIT_CANDIDATES + 1] = "nameplate" .. index end

local function CacheManaUnit(unit)
  if not UnitUsesMana(unit) then return false end
  if type(UnitName) == "function" then
    local name = NormalizePlateName(UnitName(unit))
    if name ~= "" then manaNameCache[name] = true end
  end
  if type(UnitGUID) == "function" then
    local guid = UnitGUID(unit)
    if guid then manaGuidCache[guid] = true end
  end
  return true
end

local function UnitKnownMana(unit)
  -- Never inherit mana state from a recycled frame, cached creature name or old
  -- GUID. The live unit token is the source of truth on every refresh.
  local usesMana = UnitUsesMana(unit)
  if usesMana then CacheManaUnit(unit) end
  return usesMana
end

local function RefreshManaCache()
  for _, unit in ipairs(UNIT_CANDIDATES) do
    if type(UnitExists) == "function" and UnitExists(unit) then CacheManaUnit(unit) end
  end
end

local function DirectUnit(frame)
  local containers = {
    frame,
    frame and frame.myPlate,
    frame and frame.UnitFrame,
    frame and frame.unitFrame,
    frame and frame.frame,
    frame and frame.data,
  }
  local keys = {"_unit", "unit", "unitID", "unitId", "unitToken", "displayedUnit", "realUnit", "namePlateUnitToken"}
  for _, container in pairs(containers) do
    if container then
      for _, key in ipairs(keys) do
        local unit = container[key]
        if type(unit) == "string" and type(UnitExists) == "function" and UnitExists(unit) then return unit end
      end
    end
  end
  return nil
end

local function FrameGuidUsesMana(frame)
  local containers = {frame, frame and frame.UnitFrame, frame and frame.unitFrame, frame and frame.data}
  local keys = {"guid", "GUID", "unitGUID", "UnitGUID"}
  for _, container in pairs(containers) do
    if container then
      for _, key in ipairs(keys) do
        local guid = container[key]
        if guid and manaGuidCache[guid] then return true end
      end
    end
  end
  return false
end

local function FramePowerUsesMana(frame)
  local containers = {frame, frame and frame.UnitFrame, frame and frame.unitFrame, frame and frame.data}
  local keys = {"powerType", "powerToken", "resourceType", "manaType"}
  for _, container in pairs(containers) do
    if container then
      for _, key in ipairs(keys) do
        local value = container[key]
        if value == 0 or value == "MANA" or value == "Mana" or value == "mana" then return true end
      end
    end
  end
  return false
end

local function TextMatchesManaName(value)
  local text = NormalizePlateName(value)
  if text == "" then return false end
  for manaName in pairs(manaNameCache) do
    if text == manaName or text:find(manaName, 1, true) then return true end
    if #text >= 4 and manaName:find(text, 1, true) then return true end
  end
  return false
end

local function FrameTextUsesMana(frame)
  if not frame then return false end
  if type(frame.GetRegions) == "function" then
    local regions = {frame:GetRegions()}
    for _, region in ipairs(regions) do
      if region and type(region.GetText) == "function" then
        local ok, text = pcall(region.GetText, region)
        if ok and TextMatchesManaName(text) then return true end
      end
    end
  end

  local known = {frame.name, frame.Name, frame.nameText, frame.NameText, frame.unitName, frame.UnitName, frame.label, frame.Label}
  for _, value in pairs(known) do
    local text = type(value) == "string" and value or nil
    if not text and value and type(value.GetText) == "function" then
      local ok, current = pcall(value.GetText, value)
      if ok then text = current end
    end
    if TextMatchesManaName(text) then return true end
  end
  return false
end

local function IsCastOrPowerObject(value)
  local name = FrameName(value)
  return name:find("cast", 1, true)
    or name:find("power", 1, true)
    or name:find("mana", 1, true)
    or name:find("energy", 1, true)
    or name:find("rage", 1, true)
end

local function ObjectDimensions(value)
  local width = type(value.GetWidth) == "function" and tonumber(value:GetWidth()) or 0
  local height = type(value.GetHeight) == "function" and tonumber(value:GetHeight()) or 0
  return width or 0, height or 0
end

local function IsHealthSized(value)
  local width, height = ObjectDimensions(value)
  return width >= 35 and height >= 3 and height <= 45 and width > height * 2
end

local function StatusBarMatchesUnitHealth(value, unit)
  if not IsStatusBar(value) or not unit or not IsShown(value) then return false end
  if type(value.GetMinMaxValues) ~= "function" or type(value.GetValue) ~= "function" then return false end
  if type(UnitHealthMax) ~= "function" or type(UnitHealth) ~= "function" then return false end

  local okRange, minimum, maximum = pcall(value.GetMinMaxValues, value)
  local okValue, current = pcall(value.GetValue, value)
  local okMax, unitMaximum = pcall(UnitHealthMax, unit)
  local okHealth, unitCurrent = pcall(UnitHealth, unit)
  maximum, current = tonumber(maximum), tonumber(current)
  unitMaximum, unitCurrent = tonumber(unitMaximum), tonumber(unitCurrent)
  if not (okRange and okValue and okMax and okHealth) or not maximum or not unitMaximum or maximum <= 0 or unitMaximum <= 0 then
    return false
  end

  -- TurboPlates' live health StatusBar uses the unit's actual health range. The
  -- hidden reserve healthbar does not. Matching both range and ratio
  -- lets RetreatUI select the visible red bar without accidentally recoloring
  -- cast or power bars of a similar size.
  local maxTolerance = math.max(1, unitMaximum * 0.02)
  if math.abs(maximum - unitMaximum) > maxTolerance then return false end
  local barRatio = math.max(0, (current or 0) - (tonumber(minimum) or 0)) / math.max(1, maximum - (tonumber(minimum) or 0))
  local unitRatio = math.max(0, unitCurrent or 0) / unitMaximum
  return math.abs(barRatio - unitRatio) <= 0.04
end

local function CollectLiveHealthBars(frame, unit, output, seen, depth)
  if not frame or depth > 7 or not IsShown(frame) then return end
  if IsStatusBar(frame) and IsHealthSized(frame) and not IsCastOrPowerObject(frame)
    and StatusBarMatchesUnitHealth(frame, unit) and not seen[frame] then
    seen[frame] = true
    output[#output + 1] = frame
  end
  if type(frame.GetChildren) == "function" then
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do CollectLiveHealthBars(child, unit, output, seen, depth + 1) end
  end
end

local function AddHealthObject(output, seen, value, score)
  if not value or seen[value] or IsCastOrPowerObject(value) then return end
  if not IsStatusBar(value) and not IsTexture(value) then return end
  if not IsHealthSized(value) then return end
  seen[value] = true
  output[#output + 1] = {object=value, score=score or 0}
end

local function CollectKnownHealthObjects(frame, output, seen)
  if not frame then return end
  local candidates = {
    frame.healthBar, frame.healthbar, frame.HealthBar, frame.health, frame.Health,
    frame.bar, frame.Bar, frame.statusbar, frame.StatusBar, frame.hp, frame.HP,
    frame.UnitFrame and frame.UnitFrame.healthBar,
    frame.UnitFrame and frame.UnitFrame.HealthBar,
    frame.UnitFrame and frame.UnitFrame.Health,
    frame.unitFrame and frame.unitFrame.healthBar,
    frame.unitFrame and frame.unitFrame.HealthBar,
    frame.unitFrame and frame.unitFrame.Health,
    frame.data and frame.data.healthBar,
  }
  for _, value in pairs(candidates) do AddHealthObject(output, seen, value, 1000) end
end

local function CollectHealthObjects(frame, output, seen, depth)
  if not frame or depth > 4 or not IsShown(frame) then return end
  CollectKnownHealthObjects(frame, output, seen)
  if IsStatusBar(frame) then AddHealthObject(output, seen, frame, 900) end

  if type(frame.GetRegions) == "function" then
    local regions = {frame:GetRegions()}
    for _, region in ipairs(regions) do
      if IsTexture(region) and IsHealthSized(region) then
        local width, height = ObjectDimensions(region)
        AddHealthObject(output, seen, region, width * height)
      end
    end
  end

  if type(frame.GetChildren) == "function" then
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do CollectHealthObjects(child, output, seen, depth + 1) end
  end
end

local function ColorForRole(role)
  if role == "background" then return MANA_BLUE_DARK end
  if role == "border" then return MANA_BLUE_BORDER end
  return MANA_BLUE
end

local function RememberOriginalColor(value)
  if value._ruiManaOriginalColor then return end
  if IsTurboBorder(value) then
    local ok, r, g, b, a = pcall(value.GetColor, value)
    value._ruiManaOriginalColor = {kind="turboBorder", color=ok and {r or 0, g or 0, b or 0, a or 1} or {0, 0, 0, 1}}
  elseif IsStatusBar(value) and type(value.GetStatusBarColor) == "function" then
    local r, g, b, a = value:GetStatusBarColor()
    value._ruiManaOriginalColor = {kind="statusbar", color={r or 1, g or 1, b or 1, a or 1}}
  elseif IsTexture(value) and type(value.GetVertexColor) == "function" then
    local r, g, b, a = value:GetVertexColor()
    value._ruiManaOriginalColor = {kind="texture", color={r or 1, g or 1, b or 1, a or 1}}
  elseif IsFrame(value) then
    local backdrop, border
    if type(value.GetBackdropColor) == "function" then
      local ok, r, g, b, a = pcall(value.GetBackdropColor, value)
      if ok then backdrop = {r or 0, g or 0, b or 0, a or 0} end
    end
    if type(value.GetBackdropBorderColor) == "function" then
      local ok, r, g, b, a = pcall(value.GetBackdropBorderColor, value)
      if ok then border = {r or 1, g or 1, b or 1, a or 1} end
    end
    value._ruiManaOriginalColor = {kind="frame", backdrop=backdrop, border=border}
  else
    value._ruiManaOriginalColor = {kind="unknown"}
  end
end

local function EnsureManaFillOverlay(statusBar)
  if not IsStatusBar(statusBar) or type(statusBar.GetStatusBarTexture) ~= "function" then return nil end
  local fill = statusBar:GetStatusBarTexture()
  if not fill then return nil end

  local overlay = statusBar._ruiManaFillOverlay
  if not overlay and type(statusBar.CreateTexture) == "function" then
    -- The native StatusBar fill also lives on ARTWORK. A high sublevel keeps
    -- this texture above the fill but below TurboPlates' OVERLAY border/text.
    overlay = statusBar:CreateTexture(nil, "ARTWORK", nil, 7)
    statusBar._ruiManaFillOverlay = overlay
    overlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    if type(overlay.SetBlendMode) == "function" then overlay:SetBlendMode("BLEND") end
    if type(overlay.SetDrawLayer) == "function" then
      pcall(overlay.SetDrawLayer, overlay, "ARTWORK", 7)
    end
  end
  if not overlay then return nil end

  overlay:ClearAllPoints()
  overlay:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
  overlay:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
  overlay:SetVertexColor(MANA_BLUE[1], MANA_BLUE[2], MANA_BLUE[3], MANA_BLUE[4])
  overlay:SetAlpha(1)
  overlay:Show()

  -- TurboPlates reapplies threat/reaction colors frequently. Hook the actual
  -- StatusBar method once and refresh our overlay after every native update.
  if not statusBar._ruiManaColorHooked and type(hooksecurefunc) == "function" then
    statusBar._ruiManaColorHooked = true
    pcall(hooksecurefunc, statusBar, "SetStatusBarColor", function(self)
      if not self._ruiManaBlue or self._ruiApplyingManaColor then return end
      local current = self._ruiManaFillOverlay
      local currentFill = type(self.GetStatusBarTexture) == "function" and self:GetStatusBarTexture() or nil
      if current and currentFill then
        current:ClearAllPoints()
        current:SetPoint("TOPLEFT", currentFill, "TOPLEFT", 0, 0)
        current:SetPoint("BOTTOMRIGHT", currentFill, "BOTTOMRIGHT", 0, 0)
        current:SetVertexColor(MANA_BLUE[1], MANA_BLUE[2], MANA_BLUE[3], MANA_BLUE[4])
        current:SetAlpha(1)
        current:Show()
      end
    end)
  end
  return overlay
end

local function PaintManaBlue(value, role)
  if not value then return end
  RememberOriginalColor(value)
  value._ruiManaBlue = true
  value._ruiManaRole = role
  local color = ColorForRole(role)

  if IsTurboBorder(value) then
    pcall(value.SetColor, value, color[1], color[2], color[3], color[4], true)
  elseif IsStatusBar(value) then
    -- Keep the native color assignment as a fallback, but render a separate
    -- blue texture over the moving health fill. TurboPlates cannot overwrite
    -- this overlay when it reapplies threat or reaction colors.
    value._ruiApplyingManaColor = true
    pcall(value.SetStatusBarColor, value, color[1], color[2], color[3], color[4])
    if type(value.GetStatusBarTexture) == "function" then
      local texture = value:GetStatusBarTexture()
      if texture and type(texture.SetVertexColor) == "function" then
        pcall(texture.SetVertexColor, texture, color[1], color[2], color[3], color[4])
      end
    end
    EnsureManaFillOverlay(value)
    value._ruiApplyingManaColor = false
  elseif IsTexture(value) then
    pcall(value.SetVertexColor, value, color[1], color[2], color[3], color[4])
  elseif IsFrame(value) then
    if type(value.SetBackdropColor) == "function" then
      pcall(value.SetBackdropColor, value, MANA_BLUE_DARK[1], MANA_BLUE_DARK[2], MANA_BLUE_DARK[3], MANA_BLUE_DARK[4])
    end
    if type(value.SetBackdropBorderColor) == "function" then
      pcall(value.SetBackdropBorderColor, value, MANA_BLUE_BORDER[1], MANA_BLUE_BORDER[2], MANA_BLUE_BORDER[3], MANA_BLUE_BORDER[4])
    end
  end
  activeColorObjects[value] = true
end

local function RestoreColor(value)
  if not value or not value._ruiManaBlue then return end
  value._ruiManaBlue = false
  value._ruiManaRole = nil
  activeColorObjects[value] = nil
  local original = value._ruiManaOriginalColor
  if not original then return end

  if original.kind == "turboBorder" and IsTurboBorder(value) then
    local color = original.color or {0, 0, 0, 1}
    pcall(value.SetColor, value, color[1], color[2], color[3], color[4] or 1, true)
  elseif original.kind == "statusbar" and IsStatusBar(value) then
    local color = original.color or {1, 1, 1, 1}
    value._ruiApplyingManaColor = true
    pcall(value.SetStatusBarColor, value, color[1], color[2], color[3], color[4] or 1)
    if type(value.GetStatusBarTexture) == "function" then
      local texture = value:GetStatusBarTexture()
      if texture and type(texture.SetVertexColor) == "function" then
        pcall(texture.SetVertexColor, texture, color[1], color[2], color[3], color[4] or 1)
      end
    end
    if value._ruiManaFillOverlay then value._ruiManaFillOverlay:Hide() end
    value._ruiApplyingManaColor = false
  elseif original.kind == "texture" and IsTexture(value) then
    local color = original.color or {1, 1, 1, 1}
    pcall(value.SetVertexColor, value, color[1], color[2], color[3], color[4] or 1)
  elseif original.kind == "frame" and IsFrame(value) then
    if original.backdrop and type(value.SetBackdropColor) == "function" then
      pcall(value.SetBackdropColor, value, original.backdrop[1], original.backdrop[2], original.backdrop[3], original.backdrop[4] or 0)
    end
    if original.border and type(value.SetBackdropBorderColor) == "function" then
      pcall(value.SetBackdropBorderColor, value, original.border[1], original.border[2], original.border[3], original.border[4] or 1)
    end
  end
end

local function PlateVisualRole(value)
  local name = FrameName(value)
  if name:find("border", 1, true) or name:find("edge", 1, true) or name:find("glow", 1, true) then
    return "border"
  end
  if name:find("background", 1, true) or name:find("backdrop", 1, true)
    or name:find("bg", 1, true) then
    return "background"
  end
  return "fill"
end

local function AddPlateVisual(output, seen, value, role)
  if not value or seen[value] or IsCastOrPowerObject(value) then return end
  if IsStatusBar(value) then
    if not IsHealthSized(value) then return end
  elseif IsTexture(value) then
    local width, height = ObjectDimensions(value)
    local namedSurface = PlateVisualRole(value) ~= "fill"
    local wideSurface = width >= 35 and height >= 2 and height <= 55 and width > height * 2
    if not namedSurface and not wideSurface then return end
  elseif IsFrame(value) then
    if type(value.SetBackdropColor) ~= "function" and type(value.SetBackdropBorderColor) ~= "function" then return end
  else
    return
  end
  seen[value] = true
  output[#output + 1] = {object=value, role=role or PlateVisualRole(value)}
end

local function CollectPlateVisuals(frame, output, seen, depth)
  if not frame or depth > 4 or not IsShown(frame) then return end

  if depth <= 2 then AddPlateVisual(output, seen, frame, "frame") end
  if IsStatusBar(frame) then AddPlateVisual(output, seen, frame, "fill") end

  if type(frame.GetRegions) == "function" then
    local regions = {frame:GetRegions()}
    for _, region in ipairs(regions) do
      if IsTexture(region) then AddPlateVisual(output, seen, region, PlateVisualRole(region)) end
    end
  end

  if type(frame.GetChildren) == "function" then
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do CollectPlateVisuals(child, output, seen, depth + 1) end
  end
end

local function PaintTurboPlate(myPlate, seenObjects)
  -- Ascension can report the detached TurboPlates frame as hidden while its
  -- health StatusBar is already the live rendered object. Requiring myPlate
  -- to be shown prevented the overlay from ever being created in that state.
  if not myPlate or not myPlate.hp then return false end

  local hp = myPlate.hp
  PaintManaBlue(hp, "fill")
  seenObjects[hp] = true

  if hp.bg then
    PaintManaBlue(hp.bg, "background")
    seenObjects[hp.bg] = true
  end

  if hp.border and IsTurboBorder(hp.border) then
    PaintManaBlue(hp.border, "border")
    seenObjects[hp.border] = true
  end

  -- TurboPlates stores the exact Blizzard unit on the parent nameplate and the
  -- custom plate in nameplate.myPlate. Painting these known objects avoids all
  -- heuristic frame scans and survives TurboPlates' threat-color updates.
  return true
end

local function PaintPlate(frame, seenObjects, unit)
  local visuals = {}
  local visualSeen = setmetatable({}, {__mode="k"})

  -- Paint every visible StatusBar whose live value/range matches this unit's
  -- health. This is the bar the user actually sees, even when TurboPlates keeps
  -- a separate hidden myPlate.hp reserve object.
  if unit then
    local liveBars = {}
    CollectLiveHealthBars(frame, unit, liveBars, visualSeen, 0)
    for _, bar in ipairs(liveBars) do visuals[#visuals + 1] = {object=bar, role="fill"} end
  end

  -- Keep the broader visual scan as a fallback for TurboPlates revisions where
  -- health values are normalized instead of using UnitHealthMax directly.
  local healthObjects = {}
  CollectHealthObjects(frame, healthObjects, visualSeen, 0)
  for _, candidate in ipairs(healthObjects) do visuals[#visuals + 1] = {object=candidate.object, role="fill"} end
  CollectPlateVisuals(frame, visuals, visualSeen, 0)

  local painted = 0
  for _, visual in ipairs(visuals) do
    PaintManaBlue(visual.object, visual.role)
    seenObjects[visual.object] = true
    painted = painted + 1
  end
  return painted > 0
end

local function FindPlateAncestor(frame)
  local current = frame
  for _ = 1, 7 do
    if not current then break end
    local candidates = {}
    CollectHealthObjects(current, candidates, setmetatable({}, {__mode="k"}), 0)
    if #candidates > 0 then return current end
    if type(current.GetParent) ~= "function" then break end
    current = current:GetParent()
  end
  return frame
end

local function FrameDirectlyUsesMana(frame)
  local unit = DirectUnit(frame)
  if unit and UnitKnownMana(unit) then return true end
  return FrameGuidUsesMana(frame) or FramePowerUsesMana(frame)
end

local function VisitFrame(frame, depth, visited, seenObjects)
  if not frame or depth > 7 or visited[frame] or not IsShown(frame) then return end
  visited[frame] = true

  if FrameDirectlyUsesMana(frame) then PaintPlate(FindPlateAncestor(frame), seenObjects, DirectUnit(frame)) end
  if FrameTextUsesMana(frame) then PaintPlate(FindPlateAncestor(frame), seenObjects) end

  if type(frame.GetChildren) == "function" then
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do VisitFrame(child, depth + 1, visited, seenObjects) end
  end
end

local function AddRoot(roots, seen, value)
  if IsFrame(value) and not seen[value] then
    seen[value] = true
    roots[#roots + 1] = value
    discoveredPlateRoots[value] = true
  end
end

local function CollectFramesFromTable(value, roots, seenRoots, seenTables, depth, budget)
  if depth > 4 or budget.count > 1200 then return end
  if IsFrame(value) then
    AddRoot(roots, seenRoots, value)
    return
  end
  if type(value) ~= "table" or seenTables[value] then return end
  seenTables[value] = true
  for key, child in pairs(value) do
    budget.count = budget.count + 1
    if budget.count > 1200 then return end
    local keyName = string.lower(tostring(key or ""))
    if IsFrame(child) then
      AddRoot(roots, seenRoots, child)
    elseif type(child) == "table" and (depth < 2 or keyName:find("plate", 1, true) or keyName:find("frame", 1, true)) then
      CollectFramesFromTable(child, roots, seenRoots, seenTables, depth + 1, budget)
    end
  end
end

local function FindTurboNamespace(value, visited, depth, budget)
  if budget.count > 800 or depth > 8 then return nil end
  local valueType = type(value)
  if (valueType == "table" or valueType == "function") and visited[value] then return nil end
  if valueType == "table" or valueType == "function" then visited[value] = true end
  budget.count = budget.count + 1

  if valueType == "table" then
    if type(value.unitToPlate) == "table" and type(value.UpdateColor) == "function" then
      return value
    end
    for key, child in pairs(value) do
      local keyName = string.lower(tostring(key or ""))
      if type(child) == "function" or (type(child) == "table" and (depth < 2 or keyName:find("plate", 1, true) or keyName:find("unit", 1, true))) then
        local found = FindTurboNamespace(child, visited, depth + 1, budget)
        if found then return found end
      end
    end
  elseif valueType == "function" and debug and type(debug.getupvalue) == "function" then
    for index = 1, 80 do
      local name, child = debug.getupvalue(value, index)
      if not name then break end
      if type(child) == "table" or type(child) == "function" then
        local found = FindTurboNamespace(child, visited, depth + 1, budget)
        if found then return found end
      end
    end
  end
  return nil
end

local function ResolveTurboNamespace()
  if turboNamespace and type(turboNamespace.unitToPlate) == "table" then return turboNamespace end
  if turboNamespaceSearched and not (debug and type(debug.getupvalue) == "function") then return nil end
  turboNamespaceSearched = true

  local roots = {
    _G.C_NamePlateManager and _G.C_NamePlateManager.ApplyFPSIncrease,
    _G.C_NamePlateManager and _G.C_NamePlateManager.DisableBlizzPlate,
    _G.C_NamePlateManager and _G.C_NamePlateManager.EnumerateActiveNamePlates,
  }
  for _, root in pairs(roots) do
    if type(root) == "function" then
      local found = FindTurboNamespace(root, setmetatable({}, {__mode="k"}), 0, {count=0})
      if found then
        turboNamespace = found
        return found
      end
    end
  end
  return nil
end

local function NamePlateForUnit(unit)
  if C_NamePlateManager and type(C_NamePlateManager.GetNamePlateForUnit) == "function" then
    local ok, plate = pcall(C_NamePlateManager.GetNamePlateForUnit, unit)
    if ok and plate then return plate end
  end
  if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and plate then return plate end
  end
  return nil
end

local function CollectScanRoots(fullDiscovery)
  local roots, seen = {}, setmetatable({}, {__mode="k"})

  if WorldFrame and type(WorldFrame.GetChildren) == "function" then
    local children = {WorldFrame:GetChildren()}
    for _, child in ipairs(children) do AddRoot(roots, seen, child) end
  end

  local known = {
    _G.TurboPlatesFrame, _G.TurboPlatesContainer, _G.TurboPlatesAnchor,
    _G.NamePlateDriverFrame, _G.NamePlateContainer,
  }
  for _, frame in pairs(known) do AddRoot(roots, seen, frame) end

  CollectFramesFromTable(_G.TurboPlates, roots, seen, {}, 0, {count=0})
  CollectFramesFromTable(_G.TurboPlatesDB and _G.TurboPlatesDB.frames, roots, seen, {}, 0, {count=0})

  for frame in pairs(discoveredPlateRoots) do AddRoot(roots, seen, frame) end

  if fullDiscovery and UIParent and type(UIParent.GetChildren) == "function" then
    local children = {UIParent:GetChildren()}
    for _, frame in ipairs(children) do
      local name = FrameName(frame)
      if name:find("turbo", 1, true) or name:find("nameplate", 1, true) or name:find("plate", 1, true) then
        AddRoot(roots, seen, frame)
      end
    end
  end
  return roots
end

local function ResolveTurboPlate(nameplate)
  local current = nameplate
  for _ = 1, 6 do
    if not current then break end
    if current.myPlate and current.myPlate.hp then return current.myPlate end
    if current.hp then return current end
    if type(current.GetParent) ~= "function" then break end
    current = current:GetParent()
  end
  return nil
end

local function PaintUnitTurboPlate(unit, seenObjects)
  if not UnitKnownMana(unit) then return false end

  -- The public nameplate's myPlate.hp object is the only TurboPlates object
  -- RetreatUI is allowed to recolor. Broad frame/texture scans are disabled:
  -- they can include recycled plates and make unrelated NPCs blue.
  local nameplate = NamePlateForUnit(unit)
  local myPlate = ResolveTurboPlate(nameplate)
  if myPlate and myPlate.hp then
    return PaintTurboPlate(myPlate, seenObjects) == true
  end
  return false
end

local function PaintActiveTurboPlates(seenObjects)
  local manager = _G.C_NamePlateManager
  if manager and type(manager.EnumerateActiveNamePlates) == "function" then
    pcall(function()
      for nameplate in manager.EnumerateActiveNamePlates() do
        local unit = DirectUnit(nameplate)
        local myPlate = ResolveTurboPlate(nameplate)
        if unit and UnitKnownMana(unit) then
          if myPlate then PaintTurboPlate(myPlate, seenObjects) end
        end
      end
    end)
  end

  -- Always process the stable nameplate unit tokens as well. This covers
  -- TurboPlates builds where EnumerateActiveNamePlates returns a wrapper frame.
  for index = 1, 40 do
    local unit = "nameplate" .. index
    if type(UnitExists) == "function" and UnitExists(unit) then
      PaintUnitTurboPlate(unit, seenObjects)
    end
  end
end

local function PaintMouseoverPlate(seenObjects)
  if type(UnitExists) == "function" and UnitExists("mouseover") then
    PaintUnitTurboPlate("mouseover", seenObjects)
  end
end

local function RefreshAllManaPlates(fullDiscovery)
  RefreshManaCache()
  local seenObjects = setmetatable({}, {__mode="k"})

  -- Paint only plates that can be tied to a live unit token. The old recursive
  -- frame/text/power-field discovery treated TurboPlates' default powerType=0
  -- fields as mana and made every nameplate permanently blue.
  PaintActiveTurboPlates(seenObjects)
  PaintMouseoverPlate(seenObjects)

  for _, unit in ipairs(UNIT_CANDIDATES) do
    if type(UnitExists) == "function" and UnitExists(unit) then
      PaintUnitTurboPlate(unit, seenObjects)
    end
  end

  -- Explicitly restore every overlay that was not confirmed as a live mana unit
  -- during this refresh. This also cleans up any stale blue state.
  for value in pairs(activeColorObjects) do
    if not seenObjects[value] then RestoreColor(value) end
  end
end

function RUI:InitializeTurboManaColoring()
  if manaColorFrame then
    RefreshAllManaPlates(true)
    return true
  end

  manaColorFrame = CreateFrame("Frame", "RetreatUITurboManaColoring", UIParent)
  for _, eventName in ipairs({
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "UNIT_DISPLAYPOWER", "UNIT_MAXPOWER", "UNIT_POWER", "UNIT_MANA",
    "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
    "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_FOCUS_CHANGED",
    "PLAYER_ENTERING_WORLD",
  }) do pcall(manaColorFrame.RegisterEvent, manaColorFrame, eventName) end

  manaColorFrame:SetScript("OnEvent", function(_, eventName, unit)
    if eventName == "NAME_PLATE_UNIT_ADDED" and unit then
      local seenObjects = setmetatable({}, {__mode="k"})
      PaintUnitTurboPlate(unit, seenObjects)
    end
    RUI:After(0.02, function() RefreshAllManaPlates(true) end)
    RUI:After(0.20, function()
      RefreshAllManaPlates(true)
    end)
  end)

  local elapsed = 0
  manaColorFrame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    discoveryElapsed = discoveryElapsed + delta
    if elapsed < 0.15 then return end
    elapsed = 0
    local fullDiscovery = discoveryElapsed >= 1.0
    if fullDiscovery then discoveryElapsed = 0 end
    RefreshAllManaPlates(fullDiscovery)
  end)

  RefreshAllManaPlates(true)
  return true
end


function RUI:ApplyTurboPlatesRuntime()
  if type(self.DisableElvUINamePlates) == "function" then self:DisableElvUINamePlates() end
  local loaded = self:EnsureAddOnLoaded("TurboPlates")
  if not loaded or type(TurboPlatesDB) ~= "table" then return false, "TurboPlates is not loaded" end

  local db = EnsureTurboTables()
  db.font = self.fontName
  db.showCastbar = true
  db.showCastIcon = true
  db.showCastTimer = true

  local auras = db.auras
  auras.showDebuffs = true
  auras.maxDebuffs = math.max(tonumber(auras.maxDebuffs) or 0, 8)
  auras.debuffIconWidth = 24
  auras.debuffIconHeight = 20
  auras.debuffFontSize = 12
  auras.debuffStackFontSize = 12
  auras.debuffXOffset = 0
  auras.debuffYOffset = 5
  auras.growDirection = "CENTER"
  auras.iconSpacing = 2
  auras.debuffSortMode = "LEAST_TIME"

  local playerDebuffs, seenDebuffs = {}, {}
  local function AddPlayerDebuff(name, id)
    local key = tostring(id or name or "")
    if key == "" or seenDebuffs[key] then return end
    seenDebuffs[key] = true
    playerDebuffs[#playerDebuffs + 1] = {name=name, id=tonumber(id)}
  end

  for _, spellName in ipairs(PLAYER_DEBUFFS) do AddPlayerDebuff(spellName, nil) end
  if self.GetTargetDebuffDefinitions then
    for _, definition in ipairs(self:GetTargetDebuffDefinitions(self:GetDetectedClass()) or {}) do
      AddPlayerDebuff(definition.name, definition.id)
    end
  end

  for _, record in ipairs(playerDebuffs) do
    local spellID = record.id or self:GetSpellID(record.name)
    if spellID then auras.whitelist[spellID] = true end
  end

  self:ApplyTurboPlatesStacking()
  self:InitializeTurboManaColoring()
  local mobOK = false
  if type(MobSpellsDB) == "table" then
    mobOK = select(1, self:ApplyMobSpellsToTurboPlates()) == true
  end

  local ruiDB = self:EnsureDB()
  ruiDB.integrations.turboRuntime = {
    enabled = true,
    mobSpells = mobOK,
    manaNPCFullFrameBlue = true,
    manaNPCDirectTurboPlateDetection = true,
    manaNPCIndependentFillOverlay = true,
    manaNPCExactNamespaceMap = false,
    manaNPCDirectHealthFrame = true,
    manaNPCHiddenPlateSafe = true,
    manaNPCOverlayLayerFix = true,
    manaNPCVisibleStatusBarScan = true,
    manaNPCHealthRangeMatch = true,
    manaNPCStrictLiveUnitMana = true,
    manaNPCNoHeuristicPlatePainting = true,
    manaNPCSyntheticPoolFilter = true,
    manaNPCDirectHPOnly = true,
    manaNPCStaleOverlayCleanup = true,
    dangerousAbilityPriority = false,
    version = self.version,
  }

  return true, mobOK
    and "TurboPlates runtime, full-frame mana-NPC coloring, MobSpells whitelists and separated stacking applied"
    or "TurboPlates runtime, full-frame mana-NPC coloring and separated stacking applied; MobSpells was not loaded"
end

function RUI:InstallTurboPlatesProfile()
  local loaded = self:EnsureAddOnLoaded("TurboPlates")
  if not loaded or type(TurboPlatesDB) ~= "table" then return false, "TurboPlates is not loaded" end
  local ok, message = self:ApplyTurboPlatesRuntime()
  if not ok then return false, message end
  return true, message
end

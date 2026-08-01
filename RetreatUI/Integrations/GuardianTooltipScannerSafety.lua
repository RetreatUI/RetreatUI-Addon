local RUI = RetreatUI
if not RUI then return end

local function Normalize(value)
  value = string.lower(tostring(value or "")):gsub("’", "'")
  return value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

-------------------------------------------------------------------------------
-- Guardian live-cooldown scanner safety
-------------------------------------------------------------------------------
-- Ascension's GameTooltipMods handler assumes every scanner-tooltip line has
-- text. Standards are intentionally not cooldown-HUD buttons, so remove them
-- from Guardian's live tooltip scan. The dedicated Guardian banner tracker owns
-- their active uptime instead.
local function IsStandardName(value)
  return string.find(Normalize(value), "standard of ", 1, true) == 1
end

local function RemoveStandards(spellbook)
  local removedIndices, removedIDs = {}, {}
  if type(spellbook) ~= "table" or type(spellbook.indices) ~= "table" then
    return removedIndices, removedIDs
  end

  for lowerName, index in pairs(spellbook.indices) do
    if IsStandardName(lowerName) then
      removedIndices[lowerName] = index
      spellbook.indices[lowerName] = nil
      if type(spellbook.ids) == "table" then
        removedIDs[lowerName] = spellbook.ids[lowerName]
        spellbook.ids[lowerName] = nil
      end
    end
  end
  return removedIndices, removedIDs
end

local function RestoreStandards(spellbook, removedIndices, removedIDs)
  if type(spellbook) ~= "table" then return end
  spellbook.indices = spellbook.indices or {}
  spellbook.ids = spellbook.ids or {}
  for lowerName, index in pairs(removedIndices or {}) do
    spellbook.indices[lowerName] = index
  end
  for lowerName, spellID in pairs(removedIDs or {}) do
    spellbook.ids[lowerName] = spellID
  end
end

if type(RUI.GetLiveClassCooldownDefinitions) == "function" then
  local originalGetLiveClassCooldownDefinitions = RUI.GetLiveClassCooldownDefinitions

  function RUI:GetLiveClassCooldownDefinitions(className)
    local resolvedClass = className or (self.GetDetectedClass and self:GetDetectedClass())
    if resolvedClass ~= "Guardian" then
      return originalGetLiveClassCooldownDefinitions(self, className)
    end

    if not self.spellbook and self.ScanSpellbook then self:ScanSpellbook() end
    local removedIndices, removedIDs = RemoveStandards(self.spellbook)
    local ok, result = pcall(originalGetLiveClassCooldownDefinitions, self, className)
    RestoreStandards(self.spellbook, removedIndices, removedIDs)

    if not ok or type(result) ~= "table" then return {} end
    return result
  end
end

-------------------------------------------------------------------------------
-- Ascension action-tooltip safety
-------------------------------------------------------------------------------
-- GameTooltipMods.lua reads lineText methods without checking whether a blank
-- tooltip line returned nil text. Guardian spell 800319 currently exposes such
-- a line when LibActionButton calls GameTooltip:SetAction, causing the client
-- FrameXML error at GameTooltipMods.lua:109. Normalise only existing blank
-- FontStrings before Ascension's tooltip hook reads them. A single space remains
-- visually blank while guaranteeing a string value.
local function NormaliseBlankTooltipLines(tooltip)
  if not tooltip or type(tooltip.GetName) ~= "function" then return end
  local tooltipName = tooltip:GetName()
  if not tooltipName or tooltipName == "" then return end

  local lineCount = 0
  if type(tooltip.NumLines) == "function" then
    local ok, count = pcall(tooltip.NumLines, tooltip)
    if ok then lineCount = tonumber(count) or 0 end
  end

  for index = 1, lineCount do
    local left = _G[tooltipName .. "TextLeft" .. tostring(index)]
    local right = _G[tooltipName .. "TextRight" .. tostring(index)]

    if left and type(left.GetText) == "function" and type(left.SetText) == "function"
      and left:GetText() == nil then
      left:SetText(" ")
    end
    if right and type(right.GetText) == "function" and type(right.SetText) == "function"
      and right:GetText() == nil then
      right:SetText(" ")
    end
  end
end

local function IsTooltipModsNilLineError(message)
  message = tostring(message or "")
  return string.find(message, "GameTooltipMods.lua", 1, true) ~= nil
    and string.find(message, "lineText", 1, true) ~= nil
end

local function InstallTooltipSetSpellGuard(tooltip)
  if not tooltip or tooltip.__ruiTooltipNilLineGuard then return end
  if type(tooltip.GetScript) ~= "function" or type(tooltip.SetScript) ~= "function" then return end

  local previous = tooltip:GetScript("OnTooltipSetSpell")
  tooltip:SetScript("OnTooltipSetSpell", function(self, ...)
    NormaliseBlankTooltipLines(self)

    if type(previous) == "function" then
      local ok, message = pcall(previous, self, ...)
      NormaliseBlankTooltipLines(self)
      if not ok and not IsTooltipModsNilLineError(message) then
        error(message)
      end
    else
      NormaliseBlankTooltipLines(self)
    end
  end)

  tooltip.__ruiTooltipNilLineGuard = true
end

local function InstallSetActionFallback(tooltip)
  if not tooltip or tooltip.__ruiSetActionNilLineFallback then return end
  if type(tooltip.SetAction) ~= "function" then return end

  local originalSetAction = tooltip.SetAction
  tooltip.SetAction = function(self, ...)
    NormaliseBlankTooltipLines(self)
    local results = {pcall(originalSetAction, self, ...)}
    local ok = table.remove(results, 1)
    if ok then return unpack(results) end

    local message = results[1]
    if IsTooltipModsNilLineError(message) then
      -- SetAction has already populated the tooltip before the FrameXML hook
      -- fails. Keep that usable tooltip visible after repairing its blank line.
      NormaliseBlankTooltipLines(self)
      if type(self.Show) == "function" then self:Show() end
      return
    end
    error(message)
  end

  tooltip.__ruiSetActionNilLineFallback = true
end

local function InstallTooltipSafety()
  local tooltip = _G.GameTooltip
  if not tooltip then return end
  InstallTooltipSetSpellGuard(tooltip)
  InstallSetActionFallback(tooltip)
end

InstallTooltipSafety()

-- Re-run once after login in case another addon replaces GameTooltip scripts
-- during its own load phase. The guards are idempotent.
local tooltipEvents = CreateFrame("Frame")
tooltipEvents:RegisterEvent("PLAYER_LOGIN")
tooltipEvents:SetScript("OnEvent", function()
  InstallTooltipSafety()
end)

RUI._guardianTooltipScannerSafetyLoaded = true
RUI._actionTooltipNilLineSafetyLoaded = true

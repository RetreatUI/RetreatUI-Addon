local RUI = RetreatUI
if not RUI or type(RUI.GetLiveClassCooldownDefinitions) ~= "function" then return end

-- Ascension's GameTooltipMods handler assumes every scanner-tooltip line has
-- text. Standard of Recovery currently creates an empty line and throws from
-- FrameXML before RetreatUI can read the tooltip. Standards are intentionally
-- not cooldown-HUD buttons, so remove them from Guardian's live tooltip scan.
-- The dedicated Guardian banner tracker owns their active uptime instead.
local originalGetLiveClassCooldownDefinitions = RUI.GetLiveClassCooldownDefinitions

local function Normalize(value)
  value = string.lower(tostring(value or "")):gsub("’", "'")
  return value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

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

RUI._guardianTooltipScannerSafetyLoaded = true

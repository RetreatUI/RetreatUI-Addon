local RUI = RetreatUI
if not RUI or type(RUI.ScanSpellbook) ~= "function" or RUI._spellbookScanThrottleLoaded then return end

-- Several RetreatUI systems react to the same Ascension talent/spell events.
-- Keep one real spellbook walk per short event burst and share its result with
-- the remaining consumers. This preserves immediate learned-spell detection
-- while avoiding repeated full spellbook scans in the same rendered frames.
local originalScanSpellbook = RUI.ScanSpellbook
local CACHE_WINDOW = 0.30
local lastScanAt = -1000
local lastSpellbook
local lastChanged = false

local function Now()
  if type(GetTime) == "function" then return tonumber(GetTime()) or 0 end
  if type(time) == "function" then return tonumber(time()) or 0 end
  return 0
end

RUI.spellbookScanStats = RUI.spellbookScanStats or {
  actual = 0,
  cached = 0,
}

function RUI:ScanSpellbook(force)
  local now = Now()
  if force ~= true and self.spellbook and lastSpellbook == self.spellbook
    and now - lastScanAt < CACHE_WINDOW then
    self.spellbookScanStats.cached = (tonumber(self.spellbookScanStats.cached) or 0) + 1
    return self.spellbook, lastChanged
  end

  local spellbook, changed = originalScanSpellbook(self)
  lastScanAt = now
  lastSpellbook = spellbook or self.spellbook
  lastChanged = changed == true
  self._spellbookScanAt = now
  self._spellbookLastChanged = lastChanged
  self.spellbookScanStats.actual = (tonumber(self.spellbookScanStats.actual) or 0) + 1
  return spellbook, changed
end

function RUI:InvalidateSpellbookScanCache()
  lastScanAt = -1000
  lastSpellbook = nil
  lastChanged = false
end

function RUI:GetSpellbookScanAge()
  return math.max(0, Now() - lastScanAt)
end

RUI._spellbookScanThrottleLoaded = true

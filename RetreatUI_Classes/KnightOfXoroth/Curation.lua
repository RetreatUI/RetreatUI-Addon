local RUI = RetreatUI
if not RUI then return end

-- Knight of Xoroth is deliberately curated. The HUD is NOT a second action bar.
-- Only the trackers that were explicitly approved for the compact KoX HUD are
-- allowed to render here. Everything else remains in the spell database for
-- detection, tooltips, party cooldown logic and future review.
local CLASS_NAME = "Knight of Xoroth"
local unpack = unpack or table.unpack

local CORE_ALLOW = {
  ["unleash pestilence"] = true,
}

local UTILITY_ALLOW = {
  ["chainwhip"] = true,
  ["snarl"] = true,
}

local AURA_ALLOW = {
  ["suffuse"] = true,
  ["hellrider"] = true,
  ["black shield"] = true,
}

local function Normalize(value)
  return string.lower(tostring(value or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local function IsKnight(className)
  if RUI.NormalizeClassName then className = RUI:NormalizeClassName(className) or className end
  return className == CLASS_NAME
end

local function Filter(records, allow)
  local result = {}
  for _, record in ipairs(records or {}) do
    if type(record) == "table" and allow[Normalize(record.name)] then
      result[#result + 1] = record
    end
  end
  return result
end

-- Do not let the generic live-spellbook safety net repopulate KoX with every
-- cooldown it can discover. KoX has an exact, tester-curated HUD contract.
local originalGetLiveClassCooldownDefinitions = RUI.GetLiveClassCooldownDefinitions
if type(originalGetLiveClassCooldownDefinitions) == "function" then
  function RUI:GetLiveClassCooldownDefinitions(className)
    if IsKnight(className) then return {} end
    return originalGetLiveClassCooldownDefinitions(self, className)
  end
end

local originalGetTankHUDDefinitions = RUI.GetTankHUDDefinitions
if type(originalGetTankHUDDefinitions) == "function" then
  function RUI:GetTankHUDDefinitions(className, row)
    local records = originalGetTankHUDDefinitions(self, className, row)
    if not IsKnight(className) then return records end
    if row == "core" then return Filter(records, CORE_ALLOW) end
    if row == "utility" then return Filter(records, UTILITY_ALLOW) end
    return {}
  end
end

local originalGetAuraTrackerDefinitions = RUI.GetAuraTrackerDefinitions
if type(originalGetAuraTrackerDefinitions) == "function" then
  function RUI:GetAuraTrackerDefinitions(className)
    local records = originalGetAuraTrackerDefinitions(self, className)
    if not IsKnight(className) then return records end
    return Filter(records, AURA_ALLOW)
  end
end

-- KoX no longer owns a target-frame debuff list. Target-frame aura spam is
-- intentionally retired; future target mechanics must be individually curated.
local originalGetTargetDebuffDefinitions = RUI.GetTargetDebuffDefinitions
if type(originalGetTargetDebuffDefinitions) == "function" then
  function RUI:GetTargetDebuffDefinitions(className)
    if IsKnight(className) then return {} end
    return originalGetTargetDebuffDefinitions(self, className)
  end
end

local function HideLegacyTargetBars()
  for index = 1, 12 do
    local bar = _G["RetreatUITargetAuraBar" .. tostring(index)]
    if bar then
      if bar.SetAlpha then bar:SetAlpha(0) end
      if bar.Hide then bar:Hide() end
      if bar.EnableMouse then bar:EnableMouse(false) end
    end
  end
end

local function FinalizeKnightRoot()
  local root = _G.RetreatUIKnightOfXorothHUD
  if not root then return false end

  -- Retire the old bespoke Pestilence tracker. It used its own KoX coordinates
  -- and was the exact reason Knight could ignore the global state lane.
  if root.stanceTracker then
    root.stanceTracker:Hide()
    if root.stanceTracker.SetAlpha then root.stanceTracker:SetAlpha(0) end
    root.stanceTracker:ClearAllPoints()
    root.stanceTracker:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", -1000, -1000)
  end

  -- The shared state tracker is now the ONLY Pestilence owner. Remove the old
  -- exclusion that deliberately prevented it from seeing "Pestilence of ...".
  if root.classStateTracker then
    root.classStateTracker.options = root.classStateTracker.options or {}
    root.classStateTracker.options.excludePrefixes = {}
    root.classStateTracker.options.excludeNames = root.classStateTracker.options.excludeNames or {}
    if root.classStateTracker.Update then pcall(root.classStateTracker.Update, root.classStateTracker) end
  end

  HideLegacyTargetBars()
  if RUI.ReflowClassStateTrackers then RUI:ReflowClassStateTrackers() end
  return true
end

local module = (RUI.GetClassModule and RUI:GetClassModule(CLASS_NAME))
  or (RUI.classModules and RUI.classModules[CLASS_NAME])
if module then
  local originalActivate = module.activate
  if type(originalActivate) == "function" then
    function module:activate(...)
      local results = {originalActivate(self, ...)}
      FinalizeKnightRoot()
      if RUI.After then
        for _, delay in ipairs({0, 0.05, 0.15, 0.50}) do
          RUI:After(delay, FinalizeKnightRoot)
        end
      end
      return unpack(results)
    end
  end

  local originalRefreshLayout = module.refreshLayout
  if type(originalRefreshLayout) == "function" then
    function module:refreshLayout(...)
      local results = {originalRefreshLayout(self, ...)}
      FinalizeKnightRoot()
      return unpack(results)
    end
  end
end

-- The old HUD file still contains its retired target-bar implementation for
-- upgrade compatibility. Suppress any bars it creates after target changes;
-- alpha=0 persists even if that legacy code later calls Show().
local suppressor = CreateFrame("Frame", "RetreatUIKnightTargetDebuffSuppressor")
suppressor:RegisterEvent("PLAYER_ENTERING_WORLD")
suppressor:RegisterEvent("PLAYER_TARGET_CHANGED")
suppressor:RegisterEvent("UNIT_AURA")
suppressor:SetScript("OnEvent", function(_, _, unit)
  if unit and unit ~= "target" then return end
  if RUI.GetDetectedClass and RUI:GetDetectedClass() ~= CLASS_NAME then return end
  if RUI.After then
    RUI:After(0, HideLegacyTargetBars)
  else
    HideLegacyTargetBars()
  end
end)

function RUI:RefreshTargetAuraBars()
  if self.GetDetectedClass and self:GetDetectedClass() == CLASS_NAME then
    HideLegacyTargetBars()
    return true, "Knight of Xoroth target-frame debuff bars are disabled"
  end
  return true, "Target aura bars unchanged"
end

RUI._knightOfXorothCurationLoaded = true
RUI._knightOfXorothCurationRevision = 1

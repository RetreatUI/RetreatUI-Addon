local RUI = RetreatUI
if not RUI then return end

-- Ascension can expose custom auras with a positive duration but no usable
-- expiration timestamp. WeakAuras' icon cooldown renderer assumes every timed
-- state has both fields and can perform arithmetic on expirationTime while the
-- region is being shown. Normalize every RetreatUI WA state before it reaches
-- the generated displays so an incomplete timed state safely becomes static.
local function NormalizeProgressState(state)
  if type(state) ~= "table" then return state end

  local progressType = state.progressType
  local duration = tonumber(state.duration)
  local expirationTime = tonumber(state.expirationTime)

  if progressType == "timed" and duration and duration > 0 and expirationTime and expirationTime > 0 then
    state.duration = duration
    state.expirationTime = expirationTime
    state.value = nil
    state.total = nil
    if state.autoHide == nil then state.autoHide = false end
    return state
  end

  state.progressType = "static"
  state.duration = nil
  state.expirationTime = nil
  state.modRate = nil
  state.paused = nil
  state.remaining = nil
  state.value = tonumber(state.value) or tonumber(state.current) or 1
  state.total = tonumber(state.total) or tonumber(state.maximum) or 1
  if state.total <= 0 then state.total = 1 end
  if state.value < 0 then state.value = 0 end
  if state.value > state.total then state.value = state.total end
  state.autoHide = false
  return state
end

local function NormalizeList(states)
  if type(states) ~= "table" then return states end
  for _, state in ipairs(states) do NormalizeProgressState(state) end
  return states
end

local function WrapSingle(methodName)
  local original = RUI[methodName]
  if type(original) ~= "function" then return end
  RUI[methodName] = function(self, ...)
    local state = original(self, ...)
    return NormalizeProgressState(state)
  end
end

local function WrapList(methodName)
  local original = RUI[methodName]
  if type(original) ~= "function" then return end
  RUI[methodName] = function(self, ...)
    local states = original(self, ...)
    return NormalizeList(states)
  end
end

for _, methodName in ipairs({
  "GetWeakAuraPrimaryPowerState",
  "GetWeakAuraNativeResourceState",
  "GetWeakAuraExplicitResourceState",
  "GetWeakAuraTrinketState",
}) do
  WrapSingle(methodName)
end

for _, methodName in ipairs({
  "GetWeakAuraRowStates",
  "GetWeakAuraProcStates",
  "GetWeakAuraTargetStates",
  "GetWeakAuraClassStates",
  "GetWeakAuraNativeResourceSegments",
  "GetWeakAuraExplicitResourceSegments",
}) do
  WrapList(methodName)
end

RUI.NormalizeWeakAuraProgressState = NormalizeProgressState
RUI._weakAuraStateSafetyLoaded = true
RUI._weakAuraStateSafetyRevision = 1

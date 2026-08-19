local RUI = RetreatUI
if not RUI then return end

-- Tracker Editor -> native WeakAuras action for Ascension WeakAuras 5.21.2.
-- The action only saves RetreatUI profile data and opens WeakAuras' own native
-- import/update UI. Nothing is auto-accepted and no custom trigger Lua is used.

local TYPE_KEYS = {"cooldown", "buff", "proc", "debuff", "stacks", "charges", "resource", "summon"}
local NATIVE_TYPES = {cooldown=true, buff=true, proc=true, debuff=true, stacks=true, charges=true}
local originalOpen = RUI.OpenTrackerEditor
if type(originalOpen) ~= "function" then return end

local function Chat(message)
  if type(RUI.BootstrapPrint) == "function" then
    RUI:BootstrapPrint(message)
  elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff5a1fRetreatUI:|r " .. tostring(message))
  end
end

local function CollectTypes(frame)
  local result = {}
  for _, key in ipairs(TYPE_KEYS) do
    local check = frame.typeChecks and frame.typeChecks[key]
    if check and check:GetChecked() then result[#result + 1] = key end
  end
  return result
end

local function HasNativeType(types)
  for _, value in ipairs(types or {}) do if NATIVE_TYPES[value] then return true end end
  return false
end

local function SaveCurrent(frame)
  local item = frame and frame.item
  if type(item) ~= "table" then return nil, "no tracker is open" end

  local types = CollectTypes(frame)
  if #types == 0 then return nil, "choose at least one tracking type first" end
  if not HasNativeType(types) then
    return nil, "Resource and Summon / Pet are profile-ready but are not generated as WeakAuras in beta.33"
  end

  local ok, savedOrReason = RUI:SaveTrackerSelection(item, {
    trackingTypes = types,
    unit = frame.unit,
    display = frame.display,
    iconSize = frame.iconSize,
    glow = frame.glow,
    showCooldownText = frame.cooldownText and frame.cooldownText:GetChecked() and true or false,
    showDuration = frame.duration and frame.duration:GetChecked() and true or false,
    showStacks = frame.stacks and frame.stacks:GetChecked() and true or false,
    learnedOnly = frame.learnedOnly and frame.learnedOnly:GetChecked() and true or false,
    combatOnly = frame.combatOnly and frame.combatOnly:GetChecked() and true or false,
  })
  if not ok then return nil, savedOrReason or "tracker could not be saved" end

  local saved = RUI:GetTrackerSelection(item.className, item.key)
  if not saved then return nil, "saved tracker could not be read back" end
  saved.group = frame.group
  return saved
end

local function EnsureButton(frame)
  if not frame or frame.buildWeakAura then return end

  if frame.safety then
    frame.safety:SetWidth(330)
    frame.safety:SetText("Native WA build opens WeakAuras' own import/update dialog; nothing is auto-accepted.")
  end

  local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  button:SetWidth(160); button:SetHeight(26)
  button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 48)
  button:SetText("Build WeakAura")
  button:SetScript("OnClick", function()
    if InCombatLockdown and InCombatLockdown() then
      Chat("Leave combat before building a WeakAura.")
      return
    end

    local saved, reason = SaveCurrent(frame)
    if not saved then
      Chat(reason or "Tracker could not be prepared for WeakAuras.")
      return
    end

    local builder = RUI.BuildNativeTrackerImport or RUI.BuildNativeCooldownTrackerTest
    if type(builder) ~= "function" or type(RUI.OpenWeakAurasNativeImport) ~= "function" then
      Chat("The native WeakAuras generator did not finish loading.")
      return
    end

    local envelope, buildReason = builder(RUI, saved)
    if not envelope then
      Chat(buildReason or "WeakAura data could not be built.")
      return
    end

    local ok, importReason = RUI:OpenWeakAurasNativeImport(envelope)
    if not ok then
      Chat(importReason or "WeakAuras rejected the native import.")
      return
    end

    if RUI.trackerBuilderFrame then RUI.trackerBuilderFrame:Hide() end
    frame:Hide()
    if type(RUI.RefreshTrackerBuilder) == "function" then RUI:RefreshTrackerBuilder() end
    Chat("WeakAuras native import/update opened for " .. tostring(saved.name) .. ".")
  end)

  frame.buildWeakAura = button
end

function RUI:OpenTrackerEditor(item, ...)
  local opened = originalOpen(self, item, ...)
  local frame = self.trackerEditorFrame
  if frame then EnsureButton(frame) end
  return opened
end

RUI._trackerEditorWeakAurasAction = true

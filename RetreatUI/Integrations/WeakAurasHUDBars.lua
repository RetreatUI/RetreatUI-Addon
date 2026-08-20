local RUI = RetreatUI
if not RUI then return end

local function HasType(entry, wanted)
  if type(entry) ~= "table" then return false end
  if entry.trackingType == wanted then return true end
  for _, value in ipairs(entry.trackingTypes or {}) do if value == wanted then return true end end
  return false
end

local function WeakAurasAPI(self)
  if not self.EnsureAddOnLoaded or not self:EnsureAddOnLoaded("WeakAuras") then return nil, "WeakAuras is not installed or could not be loaded" end
  local wa = _G.WeakAuras
  if type(wa) ~= "table" then return nil, "WeakAuras core object is unavailable" end
  for _, name in ipairs({"Import", "GetTriggerCategoryFor", "GenerateUniqueID", "InternalVersion"}) do
    if type(wa[name]) ~= "function" then return nil, "WeakAuras is missing required native API: " .. name end
  end
  return wa
end

local function AuraName(entry)
  if type(entry.auraName) == "string" and entry.auraName ~= "" then return entry.auraName end
  return entry.name
end

local function AppliedAuraID(entry)
  if type(entry) ~= "table" then return nil end
  if entry.effectConfidence and entry.effectConfidence ~= "high" then return nil end
  return tonumber(entry.auraID) or tonumber(entry.effectID)
end

local function BuildAuraTrigger(entry, harmful)
  local trigger = {
    unit = entry.unit or (harmful and "target" or "player"),
    type = "aura2",
    matchesShowOn = "showOnActive",
    debuffType = harmful and "HARMFUL" or "HELPFUL",
    ownOnly = true,
    unitExists = false,
  }
  local auraID = AppliedAuraID(entry)
  if auraID then
    trigger.useExactSpellId = true
    trigger.auraspellids = {tostring(auraID)}
  else
    local name = AuraName(entry)
    if not name or name == "" then return nil end
    trigger.useName = true
    trigger.auranames = {tostring(name)}
  end
  return {trigger=trigger, untrigger={}}
end

local function BuildCooldownTrigger(category, entry)
  local spellID = tonumber(entry.cooldownID) or tonumber(entry.spellID)
  if not spellID then return nil end
  local trigger = {
    type=category,
    event="Cooldown Progress (Spell)",
    spellName=spellID,
    use_exact_spellName=true,
    use_genericShowOn=true,
    genericShowOn="showAlways",
  }
  if not HasType(entry,"charges") then trigger.use_track=true; trigger.track="auto" end
  return {trigger=trigger, untrigger={}}
end

local function BuildTriggers(category, entry)
  local result = {}
  local debuff = HasType(entry,"debuff")
  local helpful = HasType(entry,"buff") or HasType(entry,"proc") or (HasType(entry,"stacks") and not debuff)
  if debuff then
    local t = BuildAuraTrigger(entry,true); if not t then return nil,"No usable debuff aura identity" end
    result[#result+1] = t
  elseif helpful then
    local t = BuildAuraTrigger(entry,false); if not t then return nil,"No usable buff/proc aura identity" end
    result[#result+1] = t
  end
  if HasType(entry,"cooldown") or HasType(entry,"charges") then
    local t = BuildCooldownTrigger(category,entry); if not t then return nil,"No usable cooldown identity" end
    result[#result+1] = t
  end
  if #result == 0 then return nil,"No native WeakAuras tracking type selected" end
  result.disjunctive = #result > 1 and "any" or "all"
  result.activeTriggerMode = -10
  return result
end

local function DummyGroupTrigger()
  return {
    [1]={trigger={type="aura2",event="Health",unit="player",debuffType="HELPFUL",names={},spellIds={}},untrigger={}},
    activeTriggerMode=-10,
    disjunctive="any",
  }
end

local function ExistingUID(wa, id)
  if type(wa.GetData) == "function" then
    local ok, data = pcall(wa.GetData, id)
    if ok and type(data) == "table" and type(data.uid) == "string" and data.uid ~= "" then return data.uid end
  end
  local ok, uid = pcall(wa.GenerateUniqueID)
  return ok and uid or nil
end

local function BuildRoot(wa, bar, childIDs, internalVersion)
  local id = bar.waID or ("RetreatUI HUD - " .. tostring(bar.id))
  return {
    id=id,
    uid=ExistingUID(wa,id),
    internalVersion=internalVersion,
    regionType="group",
    controlledChildren=childIDs,
    anchorFrameType="SCREEN",
    anchorPoint="CENTER",
    selfPoint="CENTER",
    xOffset=tonumber(bar.x) or 0,
    yOffset=tonumber(bar.y) or 0,
    scale=tonumber(bar.scale) or 1,
    subRegions={},
    triggers=DummyGroupTrigger(),
  }
end

local function SlotOffset(bar, slot, size)
  local count = math.max(1, tonumber(bar.slotCount) or 1)
  local spacing = tonumber(bar.spacing) or 0
  local step = size + spacing
  local origin = -((count - 1) * step) / 2
  if bar.orientation == "VERTICAL" then return 0, -(origin + ((slot - 1) * step)) end
  return origin + ((slot - 1) * step), 0
end

local function BuildChild(self, wa, category, internalVersion, entry, parentID, size, bar)
  local managedID, uid, _, reason = self:ResolveManagedWeakAuraIdentity(entry, wa)
  if not managedID then return nil, reason end
  local triggers, triggerReason = BuildTriggers(category,entry)
  if not triggers then return nil, triggerReason end
  local slot = math.max(1, math.floor(tonumber(entry.hudSlot) or 1))
  local x, y = SlotOffset(bar, slot, size)
  local child = {
    id=managedID,
    uid=uid,
    parent=parentID,
    internalVersion=internalVersion,
    regionType="icon",
    width=size,
    height=size,
    xOffset=x,
    yOffset=y,
    anchorFrameType="SCREEN",
    anchorPoint="CENTER",
    selfPoint="CENTER",
    triggers=triggers,
    cooldown=true,
    cooldownSwipe=true,
    cooldownEdge=HasType(entry,"charges"),
    zoom=0.08,
  }
  if HasType(entry,"stacks") or HasType(entry,"charges") then
    child.subRegions={{type="subbackground"},{type="subtext",text_text="%s",text_visible=true}}
  end
  return child
end

function RUI:BuildHUDBarWeakAurasImport(barID, className)
  local bar = self:GetHUDBar(className,barID)
  if not bar then return nil,"HUD bar not found" end
  local slots = self:GetHUDSlotAssignments(barID,className)
  local count = 0
  for _ in pairs(slots) do count = count + 1 end
  if count == 0 then return nil,"Add at least one spell to this bar first" end
  local wa, reason = WeakAurasAPI(self); if not wa then return nil,reason end
  if type(self.ResolveManagedWeakAuraIdentity) ~= "function" then return nil,"WeakAuras identity layer unavailable" end
  local okCategory, category = pcall(wa.GetTriggerCategoryFor,"Cooldown Progress (Spell)")
  if not okCategory or type(category) ~= "string" then return nil,"WeakAuras cooldown trigger category unavailable" end
  local okVersion, internalVersion = pcall(wa.InternalVersion)
  if not okVersion then return nil,"WeakAuras internal version unavailable" end

  local size = math.max(20,math.min(80,math.floor((tonumber(bar.iconSize) or 36)+0.5)))
  local children, childIDs = {}, {}
  local rootID = bar.waID or ("RetreatUI HUD - "..tostring(bar.id))
  for slot=1, math.max(1, tonumber(bar.slotCount) or 1) do
    local entry = slots[slot]
    if entry then
      local child, childReason = BuildChild(self,wa,category,internalVersion,entry,rootID,size,bar)
      if not child then return nil,tostring(entry.name or "Spell")..": "..tostring(childReason) end
      children[#children+1] = child
      childIDs[#childIDs+1] = child.id
    end
  end
  local root = BuildRoot(wa,bar,childIDs,internalVersion)
  local envelope, envelopeReason = self:BuildWeakAurasNativeImportEnvelope(root,children)
  if not envelope then return nil,envelopeReason end
  return envelope,nil,root.id,#children
end

function RUI:OpenHUDBarWeakAurasImport(barID,className)
  if InCombatLockdown and InCombatLockdown() then return false,"Leave combat before syncing WeakAuras" end
  local envelope,reason,rootID,count = self:BuildHUDBarWeakAurasImport(barID,className)
  if not envelope then return false,reason end
  local ok,message = self:OpenWeakAurasNativeImport(envelope)
  if not ok then return false,message end
  local bar = self:GetHUDBar(className,barID)
  if bar then bar.dirty=false; bar.lastSynced=time and time() or 0 end
  return true,"WeakAuras import/update opened for "..tostring(rootID).." ("..tostring(count).." spells)"
end

RUI._weakAurasHUDBarsLoaded=true
RUI.weakAurasHUDBarsSchema=2

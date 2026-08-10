local RUI = RetreatUI
if not RUI then return end

local GENERAL_ROOT = "RetreatUI - General"
local GENERAL_TRINKETS = GENERAL_ROOT .. " — Trinkets"
local GENERAL_PROCS = GENERAL_ROOT .. " — Buffs & Procs"

local RESOURCE_X, RESOURCE_Y = 0, -152
local SECONDARY_X, SECONDARY_Y = 0, -118
local MAIN_X, MAIN_Y = 0, -183
local UTILITY_X, UTILITY_Y = 0, -224
local PROC_X, PROC_Y = 0, -83
local TARGET_X, TARGET_Y = 310, -59
local RESOURCE_WIDTH, RESOURCE_HEIGHT = 360, 16
local MAIN_ICON, UTILITY_ICON = 38, 32
local PROC_ICON, TRINKET_ICON = 30, 30
local ICON_SPACING, PROC_SPACING = 1, 3
local TARGET_WIDTH, TARGET_HEIGHT, TARGET_SPACING = 180, 16, 2
local SECONDARY_BAR_WIDTH, SECONDARY_BAR_HEIGHT = 330, 10
local SEGMENT_WIDTH, SEGMENT_HEIGHT, SEGMENT_SPACING = 22, 8, 2
local STATE_ICON, STATE_SPACING = 38, 6

-- Exact CoA screenshot geometry for the General trinket row.
local TRINKET_FRAME = "ElvUF_Player"
local TRINKET_ANCHOR = "TOPRIGHT"
local TRINKET_SELF = "BOTTOMRIGHT"
local TRINKET_X, TRINKET_Y = -17, 1

-- Existing GlobalStateAnchor parity: trinket right edge is -17; first state
-- icon starts 6px to its right, vertically centered on the 30px trinket row.
local STATE_X, STATE_Y = -11, 16

local POWER_COLORS = {
  MANA = {0.10, 0.42, 0.95, 1},
  RAGE = {0.95, 0.20, 0.06, 1},
  FOCUS = {0.18, 0.78, 0.34, 1},
  ENERGY = {0.95, 0.82, 0.08, 1},
  RUNICPOWER = {0.10, 0.82, 0.95, 1},
  FURY = {0.95, 0.38, 0.05, 1},
}
local POWER_TOKENS = {"MANA", "RAGE", "FOCUS", "ENERGY", "RUNICPOWER", "FURY"}

local function InternalVersion()
  if WeakAuras and type(WeakAuras.InternalVersion) == "function" then return WeakAuras.InternalVersion() end
  return 90
end

local function TocVersion()
  local _, _, _, toc = GetBuildInfo()
  return toc or 30300
end

local function GeneralLoad()
  return { spec = {multi = {}}, use_never = false }
end

local function Base(id, parent)
  return {
    id = id,
    parent = parent,
    internalVersion = InternalVersion(),
    tocversion = TocVersion(),
    actions = {
      start = {do_custom = false},
      finish = {do_custom = false},
      init = {do_custom = false},
    },
    animation = {
      start = {type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3},
      main = {type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3},
      finish = {type = "none", duration_type = "seconds", easeType = "none", easeStrength = 3},
    },
    authorOptions = {}, conditions = {}, config = {}, information = {},
    load = GeneralLoad(), alpha = 1, frameStrata = 1,
  }
end

local function DummyTrigger()
  return {
    [1] = {
      trigger = {
        type = "aura2", event = "Health", unit = "player", debuffType = "HELPFUL",
        names = {}, spellIds = {}, subeventPrefix = "SPELL", subeventSuffix = "_CAST_START",
      },
      untrigger = {},
    },
    activeTriggerMode = -10,
    disjunctive = "any",
  }
end

local function CustomStateTrigger(code, events)
  return {
    [1] = {
      trigger = {
        type = "custom", event = "Health", check = "event", custom_type = "stateupdate",
        custom_hide = "custom", custom = code, events = events,
        unit = "player", debuffType = "HELPFUL", names = {}, spellIds = {},
        subeventPrefix = "SPELL", subeventSuffix = "_CAST_START",
      },
      untrigger = {custom = ""},
    },
    activeTriggerMode = -10,
    disjunctive = "any",
  }
end

local function StaticGroup(id, parent, children)
  local data = Base(id, parent)
  data.regionType = "group"
  data.controlledChildren = children or {}
  data.anchorFrameType = "SCREEN"
  data.anchorPoint = "CENTER"
  data.selfPoint = "CENTER"
  data.xOffset, data.yOffset = 0, 0
  data.scale = 1
  data.subRegions = {}
  data.triggers = DummyTrigger()
  return data
end

local function DynamicGroup(id, parent, children, options)
  options = options or {}
  local data = Base(id, parent)
  data.regionType = "dynamicgroup"
  data.controlledChildren = children or {}
  data.anchorFrameType = options.anchorFrameType or "SCREEN"
  data.anchorFrameFrame = options.anchorFrameFrame
  data.anchorPoint = options.anchorPoint or "CENTER"
  data.selfPoint = options.selfPoint or "CENTER"
  data.xOffset = options.x or 0
  data.yOffset = options.y or 0
  data.grow = options.grow or "HORIZONTAL"
  data.align = options.align or "CENTER"
  data.sort = "none"
  data.space = options.spacing or 0
  data.stagger = 0
  data.animate = false
  data.scale = options.scale or 1
  data.gridType = "RD"
  data.centerType = "LR"
  data.gridWidth = options.limit or 24
  data.rowSpace = options.spacing or 0
  data.columnSpace = options.spacing or 0
  data.useLimit = false
  data.limit = options.limit or 24
  data.fullCircle = true
  data.rotation = 0
  data.radius = 200
  data.stepAngle = 15
  data.constantFactor = "RADIUS"
  data.subRegions = {}
  data.triggers = DummyTrigger()
  return data
end

local function BlackBorder()
  return {
    type = "subborder", border_visible = true, border_color = {0, 0, 0, 1},
    border_edge = "Square Full White", border_offset = 0, border_size = 1,
  }
end

local function IconBase(id, parent, size)
  local data = Base(id, parent)
  data.regionType = "icon"
  data.width, data.height = size, size
  data.selfPoint, data.anchorPoint = "CENTER", "CENTER"
  data.anchorFrameType = "SCREEN"
  data.xOffset, data.yOffset = 0, 0
  data.color = {1, 1, 1, 1}
  data.icon = true
  data.iconSource = -1
  data.displayIcon = 134400
  data.progressSource = {1, ""}
  data.cooldown = true
  data.cooldownSwipe = true
  data.cooldownTextDisabled = false
  data.cooldownEdge = false
  data.zoom = 0.08
  data.subRegions = {
    {type = "subbackground"},
    BlackBorder(),
    {
      type = "subtext", text_visible = true, text_text = "%s",
      text_font = "Fira Sans Heavy", text_fontSize = math.max(9, math.floor(size * 0.28)),
      text_fontType = "OUTLINE", text_color = {1, 1, 1, 1}, text_justify = "RIGHT",
      text_selfPoint = "BOTTOMRIGHT", anchor_point = "BOTTOMRIGHT", anchorXOffset = -1, anchorYOffset = 1,
    },
  }
  return data
end

local function CopySnapshotCode(callExpression)
  return string.format([[
function(allstates, event, unit)
  if unit and unit ~= "player" and unit ~= "target" then return false end
  local state = allstates[""] or {}
  allstates[""] = state
  local snapshot = %s
  if type(snapshot) ~= "table" or snapshot.show == false then
    if state.show then state.show = false; state.changed = true; return true end
    return false
  end
  for key in pairs(state) do
    if key ~= "changed" then state[key] = nil end
  end
  for key, value in pairs(snapshot) do state[key] = value end
  state.show = true
  state.changed = true
  return true
end
]], callExpression)
end

local function CopyCloneCode(callExpression)
  return string.format([[
function(allstates, event, unit)
  if unit and unit ~= "player" and unit ~= "target" then return false end
  local snapshots = %s
  if type(snapshots) ~= "table" then snapshots = {} end
  local seen = {}
  local changed = false
  for index, snapshot in ipairs(snapshots) do
    local key = tostring(snapshot.key or string.format("%%03d", index))
    seen[key] = true
    local state = allstates[key] or {}
    allstates[key] = state
    for oldKey in pairs(state) do
      if oldKey ~= "changed" then state[oldKey] = nil end
    end
    for field, value in pairs(snapshot) do state[field] = value end
    state.show = snapshot.show ~= false
    state.changed = true
    state.index = snapshot.index or index
    changed = true
  end
  for key, state in pairs(allstates) do
    if not seen[key] and state.show then
      state.show = false
      state.changed = true
      changed = true
    end
  end
  return changed
end
]], callExpression)
end

local ROW_EVENTS = "PLAYER_ENTERING_WORLD SPELLS_CHANGED PLAYER_TALENT_UPDATE CHARACTER_POINTS_CHANGED ACTIVE_TALENT_GROUP_CHANGED ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED ASCENSION_KNOWN_ENTRIES_UPDATED SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE UNIT_AURA PLAYER_EQUIPMENT_CHANGED"
local PROC_EVENTS = "PLAYER_ENTERING_WORLD UNIT_AURA SPELLS_CHANGED PLAYER_TALENT_UPDATE CHARACTER_POINTS_CHANGED ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED ASCENSION_KNOWN_ENTRIES_UPDATED"
local TARGET_EVENTS = "PLAYER_ENTERING_WORLD PLAYER_TARGET_CHANGED UNIT_AURA"
local STATE_EVENTS = "PLAYER_ENTERING_WORLD UNIT_AURA UPDATE_SHAPESHIFT_FORM UPDATE_SHAPESHIFT_FORMS SPELLS_CHANGED PLAYER_TALENT_UPDATE"
local RESOURCE_EVENTS = "PLAYER_ENTERING_WORLD UNIT_DISPLAYPOWER UNIT_POWER UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_POWER_BAR_SHOW UNIT_POWER_BAR_HIDE SPELLS_CHANGED PLAYER_TALENT_UPDATE ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED ASCENSION_KNOWN_ENTRIES_UPDATED"
local TRINKET_EVENTS = "PLAYER_ENTERING_WORLD PLAYER_EQUIPMENT_CHANGED UNIT_INVENTORY_CHANGED BAG_UPDATE_DELAYED SPELL_UPDATE_COOLDOWN UNIT_AURA"

local function RowClone(id, parent, className, row, size)
  local data = IconBase(id, parent, size)
  local call = string.format("RetreatUI and RetreatUI.GetWeakAuraRowStates and RetreatUI:GetWeakAuraRowStates(%q, %q) or {}", className, row)
  data.triggers = CustomStateTrigger(CopyCloneCode(call), ROW_EVENTS)
  return data
end

local function ProcClone(id, parent)
  local data = IconBase(id, parent, PROC_ICON)
  data.triggers = CustomStateTrigger(CopyCloneCode("RetreatUI and RetreatUI.GetWeakAuraProcStates and RetreatUI:GetWeakAuraProcStates() or {}"), PROC_EVENTS)
  return data
end

local function StateClone(id, parent, className)
  local data = IconBase(id, parent, STATE_ICON)
  data.triggers = CustomStateTrigger(CopyCloneCode(string.format("RetreatUI and RetreatUI.GetWeakAuraClassStates and RetreatUI:GetWeakAuraClassStates(%q) or {}", className)), STATE_EVENTS)
  data.subRegions[#data.subRegions + 1] = {
    type = "subtext", text_visible = true, text_text = "%n",
    text_font = "Fira Sans Heavy", text_fontSize = 8, text_fontType = "OUTLINE",
    text_color = {1, 1, 1, 1}, text_justify = "CENTER", text_selfPoint = "BOTTOM",
    anchor_point = "TOP", anchorXOffset = 0, anchorYOffset = 3,
  }
  return data
end

local function TargetClone(id, parent, className)
  local data = Base(id, parent)
  data.regionType = "aurabar"
  data.width, data.height = TARGET_WIDTH, TARGET_HEIGHT
  data.selfPoint, data.anchorPoint = "CENTER", "CENTER"
  data.anchorFrameType = "SCREEN"
  data.xOffset, data.yOffset = 0, 0
  data.orientation = "HORIZONTAL"
  data.inverse = true
  data.icon = true
  data.icon_side = "LEFT"
  data.texture = "ElvUI Norm"
  data.textureSource = "LSM"
  data.barColor = {0.95, 0.32, 0.08, 0.82}
  data.backgroundColor = {0.015, 0.015, 0.020, 0.96}
  data.spark = false
  data.progressSource = {1, ""}
  data.triggers = CustomStateTrigger(CopyCloneCode(string.format("RetreatUI and RetreatUI.GetWeakAuraTargetStates and RetreatUI:GetWeakAuraTargetStates(%q) or {}", className)), TARGET_EVENTS)
  data.subRegions = {
    {type = "subbackground"},
    BlackBorder(),
    {
      type = "subtext", text_visible = true, text_text = "%n",
      text_font = "Fira Sans Heavy", text_fontSize = 8, text_fontType = "OUTLINE",
      text_color = {1, 1, 1, 1}, text_justify = "LEFT", text_selfPoint = "LEFT",
      anchor_point = "LEFT", anchorXOffset = 4, anchorYOffset = 0,
    },
    {
      type = "subtext", text_visible = true, text_text = "%p",
      text_font = "Fira Sans Heavy", text_fontSize = 8, text_fontType = "OUTLINE",
      text_color = {1, 0.95, 0.35, 1}, text_justify = "RIGHT", text_selfPoint = "RIGHT",
      anchor_point = "RIGHT", anchorXOffset = -4, anchorYOffset = 0,
    },
  }
  return data
end

local function PrimaryPowerBar(id, parent, className, token)
  local data = Base(id, parent)
  data.regionType = "aurabar"
  data.width, data.height = RESOURCE_WIDTH, RESOURCE_HEIGHT
  data.selfPoint, data.anchorPoint = "CENTER", "CENTER"
  data.anchorFrameType = "SCREEN"
  data.xOffset, data.yOffset = RESOURCE_X, RESOURCE_Y
  data.orientation = "HORIZONTAL"
  data.inverse = false
  data.icon = false
  data.texture = "ElvUI Norm"
  data.textureSource = "LSM"
  data.barColor = POWER_COLORS[token] or {1, 1, 1, 1}
  data.backgroundColor = {0.018, 0.018, 0.022, 0.96}
  data.spark = false
  data.progressSource = {1, ""}
  local call = string.format("RetreatUI and RetreatUI.GetWeakAuraPrimaryPowerState and RetreatUI:GetWeakAuraPrimaryPowerState(%q, %q)", className, token)
  data.triggers = CustomStateTrigger(CopySnapshotCode(call), RESOURCE_EVENTS)
  data.subRegions = {
    {type = "subbackground"},
    BlackBorder(),
    {
      type = "subtext", text_visible = true, text_text = "%p / %t",
      text_font = "Fira Sans Heavy", text_fontSize = 10, text_fontType = "OUTLINE",
      text_color = {1, 1, 1, 1}, text_justify = "CENTER", text_selfPoint = "CENTER",
      anchor_point = "CENTER", anchorXOffset = 0, anchorYOffset = 0,
    },
  }
  return data
end

local function SecondaryBar(id, parent, className)
  local data = Base(id, parent)
  data.regionType = "aurabar"
  data.width, data.height = SECONDARY_BAR_WIDTH, SECONDARY_BAR_HEIGHT
  data.selfPoint, data.anchorPoint = "CENTER", "CENTER"
  data.anchorFrameType = "SCREEN"
  data.xOffset, data.yOffset = SECONDARY_X, SECONDARY_Y
  data.orientation = "HORIZONTAL"
  data.inverse = false
  data.icon = false
  data.texture = "ElvUI Norm"
  data.textureSource = "LSM"
  local theme = RUI.GetClassTheme and RUI:GetClassTheme(className) or RUI.GetTheme and RUI:GetTheme() or nil
  data.barColor = theme and theme.accent or {0.95, 0.42, 0.08, 1}
  data.backgroundColor = {0.018, 0.018, 0.022, 0.96}
  data.spark = false
  data.progressSource = {1, ""}
  local call = string.format([[(function()
    local s = RetreatUI and RetreatUI.GetWeakAuraNativeResourceState and RetreatUI:GetWeakAuraNativeResourceState(%q, false)
    if s and s.mode == "bar" then return s end
    return nil
  end)()]], className)
  data.triggers = CustomStateTrigger(CopySnapshotCode(call), RESOURCE_EVENTS)
  data.subRegions = {
    {type = "subbackground"}, BlackBorder(),
    {
      type = "subtext", text_visible = true, text_text = "%p / %t",
      text_font = "Fira Sans Heavy", text_fontSize = 8, text_fontType = "OUTLINE",
      text_color = {1, 1, 1, 1}, text_justify = "CENTER", text_selfPoint = "CENTER",
      anchor_point = "CENTER", anchorXOffset = 0, anchorYOffset = 0,
    },
  }
  return data
end

local function SegmentClone(id, parent, callExpression, color)
  local data = Base(id, parent)
  data.regionType = "aurabar"
  data.width, data.height = SEGMENT_WIDTH, SEGMENT_HEIGHT
  data.selfPoint, data.anchorPoint = "CENTER", "CENTER"
  data.anchorFrameType = "SCREEN"
  data.xOffset, data.yOffset = 0, 0
  data.orientation = "HORIZONTAL"
  data.inverse = false
  data.icon = false
  data.texture = "ElvUI Norm"
  data.textureSource = "LSM"
  data.barColor = color or {0.95, 0.58, 0.12, 1}
  data.backgroundColor = {0.018, 0.018, 0.022, 0.96}
  data.spark = false
  data.progressSource = {1, ""}
  data.triggers = CustomStateTrigger(CopyCloneCode(callExpression), RESOURCE_EVENTS .. " UNIT_AURA COMBAT_LOG_EVENT_UNFILTERED")
  data.subRegions = {{type = "subbackground"}, BlackBorder()}
  return data
end

local function CounterIcon(id, parent, className, key, x, y)
  local data = IconBase(id, parent, 38)
  data.anchorFrameType = "SCREEN"
  data.xOffset, data.yOffset = x, y
  data.subRegions[3].text_text = "%s"
  data.subRegions[3].text_fontSize = 17
  data.subRegions[3].text_justify = "CENTER"
  data.subRegions[3].text_selfPoint = "CENTER"
  data.subRegions[3].anchor_point = "CENTER"
  data.subRegions[3].anchorXOffset, data.subRegions[3].anchorYOffset = 0, 0
  local call = string.format("RetreatUI and RetreatUI.GetWeakAuraExplicitResourceState and RetreatUI:GetWeakAuraExplicitResourceState(%q, %q)", className, key)
  data.triggers = CustomStateTrigger(CopySnapshotCode(call), RESOURCE_EVENTS .. " UNIT_AURA COMBAT_LOG_EVENT_UNFILTERED")
  return data
end

local function Trinket(id, slot)
  local data = IconBase(id, GENERAL_TRINKETS, TRINKET_ICON)
  data.subRegions[3].text_text = ""
  data.triggers = CustomStateTrigger(CopySnapshotCode(string.format("RetreatUI and RetreatUI.GetWeakAuraTrinketState and RetreatUI:GetWeakAuraTrinketState(%d)", slot)), TRINKET_EVENTS)
  return data
end

local function AddGroup(packageData, group)
  packageData.groups[#packageData.groups + 1] = group
  packageData.roots[#packageData.roots + 1] = group
end

local function AddLeaf(packageData, display)
  packageData.displays[#packageData.displays + 1] = display
end

local function BuildGeneral(packageData)
  local trinket1 = GENERAL_TRINKETS .. " — Slot 13"
  local trinket2 = GENERAL_TRINKETS .. " — Slot 14"
  local procAura = GENERAL_PROCS .. " — Active Buffs & Procs"

  local root = StaticGroup(GENERAL_ROOT, nil, {GENERAL_TRINKETS, GENERAL_PROCS})
  local trinkets = DynamicGroup(GENERAL_TRINKETS, GENERAL_ROOT, {trinket1, trinket2}, {
    anchorFrameType = "SELECTFRAME", anchorFrameFrame = TRINKET_FRAME,
    anchorPoint = TRINKET_ANCHOR, selfPoint = TRINKET_SELF,
    x = TRINKET_X, y = TRINKET_Y, grow = "HORIZONTAL", align = "RIGHT", spacing = PROC_SPACING,
  })
  local procs = DynamicGroup(GENERAL_PROCS, GENERAL_ROOT, {procAura}, {
    x = PROC_X, y = PROC_Y, grow = "HORIZONTAL", align = "CENTER", spacing = PROC_SPACING,
  })

  AddGroup(packageData, root)
  AddGroup(packageData, trinkets)
  AddGroup(packageData, procs)
  AddLeaf(packageData, Trinket(trinket1, 13))
  AddLeaf(packageData, Trinket(trinket2, 14))
  AddLeaf(packageData, ProcClone(procAura, GENERAL_PROCS))
end

local function BuildClass(packageData, className)
  local rootID = "RetreatUI - " .. className
  local resourceID = rootID .. " — Resource"
  local mainID = rootID .. " — Main"
  local utilityID = rootID .. " — Utility"
  local stateID = rootID .. " — State"
  local targetID = rootID .. " — Target"

  local resourceChildren = {}
  local primaryIDs = {}
  for _, token in ipairs(POWER_TOKENS) do
    local id = resourceID .. " — " .. token
    resourceChildren[#resourceChildren + 1] = id
    primaryIDs[#primaryIDs + 1] = id
  end

  local nativeBarID = resourceID .. " — Secondary Bar"
  local nativeSegmentsID = resourceID .. " — Secondary Segments"
  local nativeSegmentAuraID = nativeSegmentsID .. " — Segment"
  resourceChildren[#resourceChildren + 1] = nativeBarID
  resourceChildren[#resourceChildren + 1] = nativeSegmentsID

  local root = StaticGroup(rootID, nil, {resourceID, mainID, utilityID, stateID, targetID})
  local resource = StaticGroup(resourceID, rootID, resourceChildren)
  local mainAura = mainID .. " — Abilities"
  local utilityAura = utilityID .. " — Abilities"
  local stateAura = stateID .. " — Active States"
  local targetAura = targetID .. " — Active Debuffs"

  local main = DynamicGroup(mainID, rootID, {mainAura}, {x = MAIN_X, y = MAIN_Y, grow = "HORIZONTAL", align = "CENTER", spacing = ICON_SPACING})
  local utility = DynamicGroup(utilityID, rootID, {utilityAura}, {x = UTILITY_X, y = UTILITY_Y, grow = "HORIZONTAL", align = "CENTER", spacing = ICON_SPACING})
  local states = DynamicGroup(stateID, rootID, {stateAura}, {
    anchorFrameType = "SELECTFRAME", anchorFrameFrame = TRINKET_FRAME,
    anchorPoint = "TOPRIGHT", selfPoint = "LEFT", x = STATE_X, y = STATE_Y,
    grow = "HORIZONTAL", align = "LEFT", spacing = STATE_SPACING,
  })
  local targets = DynamicGroup(targetID, rootID, {targetAura}, {
    x = TARGET_X, y = TARGET_Y, grow = "UP", align = "LEFT", spacing = TARGET_SPACING,
  })
  local nativeSegments = DynamicGroup(nativeSegmentsID, resourceID, {nativeSegmentAuraID}, {
    x = SECONDARY_X, y = SECONDARY_Y, grow = "HORIZONTAL", align = "CENTER", spacing = SEGMENT_SPACING,
  })

  AddGroup(packageData, root)
  AddGroup(packageData, resource)
  AddGroup(packageData, main)
  AddGroup(packageData, utility)
  AddGroup(packageData, states)
  AddGroup(packageData, targets)
  AddGroup(packageData, nativeSegments)

  for index, token in ipairs(POWER_TOKENS) do
    AddLeaf(packageData, PrimaryPowerBar(primaryIDs[index], resourceID, className, token))
  end
  AddLeaf(packageData, SecondaryBar(nativeBarID, resourceID, className))
  AddLeaf(packageData, SegmentClone(
    nativeSegmentAuraID,
    nativeSegmentsID,
    string.format("RetreatUI and RetreatUI.GetWeakAuraNativeResourceSegments and RetreatUI:GetWeakAuraNativeResourceSegments(%q) or {}", className),
    (RUI.GetClassTheme and RUI:GetClassTheme(className) or {}).accent
  ))

  -- Explicit class resources (currently most notably Knight of Xoroth) retain
  -- their existing central Y=-118 lane and exact counter offsets.
  local counterSlot = 0
  for _, record in ipairs(RUI:GetClassResourceRecords(className) or {}) do
    if record.type ~= "primary" then
      local key = tostring(record.key or record.name or "resource")
      local maximum = tonumber(record.max) or tonumber(record.maximum)
      if record.type == "stacks" and maximum and maximum <= 12 then
        local groupID = resourceID .. " — " .. tostring(record.name or key)
        local auraID = groupID .. " — Segments"
        resource.controlledChildren[#resource.controlledChildren + 1] = groupID
        local group = DynamicGroup(groupID, resourceID, {auraID}, {
          x = SECONDARY_X, y = SECONDARY_Y, grow = "HORIZONTAL", align = "CENTER", spacing = SEGMENT_SPACING,
        })
        AddGroup(packageData, group)
        AddLeaf(packageData, SegmentClone(
          auraID, groupID,
          string.format("RetreatUI and RetreatUI.GetWeakAuraExplicitResourceSegments and RetreatUI:GetWeakAuraExplicitResourceSegments(%q, %q) or {}", className, key),
          {0.95, 0.36, 0.05, 1}
        ))
      else
        counterSlot = counterSlot + 1
        local x
        if key == "hellfireImp" then x = -105
        elseif key == "demonBlood" then x = 105
        elseif counterSlot == 1 then x = -105
        elseif counterSlot == 2 then x = 105
        else x = (counterSlot - 2) * 42 end
        local id = resourceID .. " — " .. tostring(record.name or key)
        resource.controlledChildren[#resource.controlledChildren + 1] = id
        AddLeaf(packageData, CounterIcon(id, resourceID, className, key, x, SECONDARY_Y))
      end
    end
  end

  AddLeaf(packageData, RowClone(mainAura, mainID, className, "core", MAIN_ICON))
  AddLeaf(packageData, RowClone(utilityAura, utilityID, className, "utility", UTILITY_ICON))
  AddLeaf(packageData, StateClone(stateAura, stateID, className))
  AddLeaf(packageData, TargetClone(targetAura, targetID, className))

  packageData.classRoot = rootID
  packageData.classGroups = {
    resource = resourceID, main = mainID, utility = utilityID, state = stateID, target = targetID,
  }
end

function RUI:BuildWeakAuraHUDPackage(className)
  className = self.NormalizeClassName and self:NormalizeClassName(className or self:GetDetectedClass()) or (className or self:GetDetectedClass())
  if not className or not self:GetClassSpellDatabase(className) then return nil, "No class spell database is loaded" end

  local packageData = {
    className = className,
    roots = {}, groups = {}, displays = {},
    expected = {
      general = GENERAL_ROOT,
      trinkets = GENERAL_TRINKETS,
      procs = GENERAL_PROCS,
      trinketFrame = TRINKET_FRAME,
      trinketX = TRINKET_X, trinketY = TRINKET_Y,
      resourceX = RESOURCE_X, resourceY = RESOURCE_Y,
      secondaryX = SECONDARY_X, secondaryY = SECONDARY_Y,
      mainX = MAIN_X, mainY = MAIN_Y,
      utilityX = UTILITY_X, utilityY = UTILITY_Y,
      procX = PROC_X, procY = PROC_Y,
      targetX = TARGET_X, targetY = TARGET_Y,
      resourceWidth = RESOURCE_WIDTH, resourceHeight = RESOURCE_HEIGHT,
      mainIcon = MAIN_ICON, utilityIcon = UTILITY_ICON,
    },
  }
  BuildGeneral(packageData)
  BuildClass(packageData, className)
  return packageData
end

local function WeakAurasAvailable()
  return WeakAuras and type(WeakAuras.Add) == "function" and type(WeakAuras.GetData) == "function"
end

local function PreserveUID(data)
  if WeakAuras and WeakAuras.GetData then
    local existing = WeakAuras.GetData(data.id)
    if existing and existing.uid then data.uid = existing.uid end
  end
  return data
end

local function AddWA(data)
  local ok, err = pcall(WeakAuras.Add, PreserveUID(data))
  if not ok then return false, tostring(err) end
  if not WeakAuras.GetData(data.id) then return false, data.id .. " was not present after WeakAuras.Add" end
  return true
end

function RUI:ValidateWeakAuraHUD(className, packageData)
  if not WeakAurasAvailable() then return false, "WeakAuras is not loaded" end
  className = self.NormalizeClassName and self:NormalizeClassName(className or self:GetDetectedClass()) or (className or self:GetDetectedClass())
  packageData = packageData or self:BuildWeakAuraHUDPackage(className)
  if type(packageData) ~= "table" then return false, "WeakAura package could not be built" end

  local expected = packageData.expected or {}
  for _, id in ipairs({expected.general, expected.trinkets, expected.procs, packageData.classRoot}) do
    if not id or not WeakAuras.GetData(id) then return false, tostring(id or "WeakAura root") .. " is missing" end
  end
  for _, id in pairs(packageData.classGroups or {}) do
    if not WeakAuras.GetData(id) then return false, id .. " is missing" end
  end

  local trinkets = WeakAuras.GetData(expected.trinkets)
  if not trinkets or trinkets.anchorFrameType ~= "SELECTFRAME" or trinkets.anchorFrameFrame ~= TRINKET_FRAME
    or trinkets.anchorPoint ~= TRINKET_ANCHOR or trinkets.selfPoint ~= TRINKET_SELF
    or math.abs((tonumber(trinkets.xOffset) or 0) - TRINKET_X) > 0.01
    or math.abs((tonumber(trinkets.yOffset) or 0) - TRINKET_Y) > 0.01 then
    return false, "General trinket WeakAura has the wrong CoA anchor"
  end

  local main = WeakAuras.GetData(packageData.classGroups.main)
  local utility = WeakAuras.GetData(packageData.classGroups.utility)
  if not main or (tonumber(main.xOffset) or 0) ~= MAIN_X or (tonumber(main.yOffset) or 0) ~= MAIN_Y then
    return false, "Main WeakAura row has the wrong HUD position"
  end
  if not utility or (tonumber(utility.xOffset) or 0) ~= UTILITY_X or (tonumber(utility.yOffset) or 0) ~= UTILITY_Y then
    return false, "Utility WeakAura row has the wrong HUD position"
  end
  return true, className .. " WeakAura HUD verified"
end

function RUI:IsWeakAuraHUDInstalled(className)
  local ok = self:ValidateWeakAuraHUD(className)
  return ok == true
end

function RUI:InstallWeakAuraHUD(className, force)
  if not WeakAurasAvailable() then return false, "WeakAuras is required for the RetreatUI combat HUD" end
  className = self.NormalizeClassName and self:NormalizeClassName(className or self:GetDetectedClass()) or (className or self:GetDetectedClass())
  local packageData, buildError = self:BuildWeakAuraHUDPackage(className)
  if not packageData then return false, buildError or "WeakAura package could not be built" end

  -- Seed every group without children, install leaf displays, then restore final
  -- controlledChildren ordering. This is the same deterministic path used by
  -- RetreatUI TBC and avoids half-parented WeakAuras on fresh accounts.
  for _, group in ipairs(packageData.roots) do
    local seed = self:DeepCopy(group)
    seed.controlledChildren = {}
    local ok, err = AddWA(seed)
    if not ok then return false, err end
  end
  for _, display in ipairs(packageData.displays) do
    local ok, err = AddWA(display)
    if not ok then return false, err end
  end
  for _, group in ipairs(packageData.roots) do
    local ok, err = AddWA(group)
    if not ok then return false, err end
  end

  if type(WeakAuras.ScanForLoads) == "function" then pcall(WeakAuras.ScanForLoads) end
  self:PrimeWeakAuraResourceSource(className)

  local valid, message = self:ValidateWeakAuraHUD(className, packageData)
  if not valid then return false, message end
  local db = self:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.coaWeakAuraHUD = db.integrations.coaWeakAuraHUD or {}
  db.integrations.coaWeakAuraHUD[className] = {
    installed = true, version = self.version, renderer = "WeakAuras",
    installedAt = date and date("%Y-%m-%d %H:%M:%S") or tostring(time and time() or 0),
  }
  return true, className .. " HUD moved to WeakAuras"
end

RUI.weakAuraHUDGeometry = {
  resource = {x = RESOURCE_X, y = RESOURCE_Y, width = RESOURCE_WIDTH, height = RESOURCE_HEIGHT},
  secondary = {x = SECONDARY_X, y = SECONDARY_Y},
  main = {x = MAIN_X, y = MAIN_Y, size = MAIN_ICON, spacing = ICON_SPACING},
  utility = {x = UTILITY_X, y = UTILITY_Y, size = UTILITY_ICON, spacing = ICON_SPACING},
  procs = {x = PROC_X, y = PROC_Y, size = PROC_ICON, spacing = PROC_SPACING},
  target = {x = TARGET_X, y = TARGET_Y, width = TARGET_WIDTH, height = TARGET_HEIGHT},
  trinkets = {frame = TRINKET_FRAME, selfPoint = TRINKET_SELF, anchorPoint = TRINKET_ANCHOR, x = TRINKET_X, y = TRINKET_Y},
}
RUI._weakAuraHUDPackageLoaded = true
RUI._weakAuraHUDPackageRevision = 1

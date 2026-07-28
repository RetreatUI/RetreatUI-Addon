local RUI = RetreatUI
if not RUI then return end

-- Class state tracking is intentionally strict and group-based.
-- Knight of Xoroth's Pestilence tracker is the model:
--   * each class defines explicit state groups
--   * each group can display only one active state at a time
--   * only exact class-owned states (or a class-specific prefix) are accepted
--   * no generic aura-name guessing is allowed
-- This prevents server auras such as PvE Mode, PvP Mode, Eternal Curse and
-- other unrelated buffs from ever appearing in the state row.
local W = RUI.HUDWidgets
local trackers = setmetatable({}, {__mode="k"})

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function Member(name, label, id, aliases, fallbackIcon)
  return {
    name=name,
    label=label,
    id=id,
    aliases=aliases,
    fallbackIcon=fallbackIcon,
  }
end

-- Only mechanics that genuinely behave like a stance, form, presence, vow,
-- aspect, oath, mode or another persistent/transformative class state belong
-- here. Ordinary procs and cooldown buffs remain in the normal aura tracker.
local CLASS_STATE_GROUPS = {
  ["Barbarian"] = {
    {
      key="FORM",
      members={
        Member("Brutal Form", "BRUTAL", nil, nil, "Interface\\Icons\\Ability_Warrior_InnerRage"),
      },
    },
  },

  ["Bloodmage"] = {
    {
      key="FORM",
      members={
        Member("Mortal Form", "MORTAL", nil, nil, "Interface\\Icons\\Spell_Shadow_LifeDrain"),
        Member("Cursed Form", "CURSED", nil, nil, "Interface\\Icons\\Ability_Racial_Cannibalize"),
      },
    },
  },

  ["Chronomancer"] = {
    {
      key="TEMPORAL_STANCE",
      prefixes={"Temporal Stance", "Time Stance"},
      labelFromName=true,
      members={},
    },
    {
      key="ATTUNEMENT",
      prefixes={"Attunement:"},
      labelFromName=true,
      members={},
    },
  },

  ["Cultist"] = {
    {
      key="PRESENCE",
      prefixes={"Presence of "},
      labelFromName=true,
      members={},
    },
    {
      key="TRANSFORMATION",
      members={
        Member("Dreadnought", "DREADNOUGHT"),
        Member("Herald of the Depths", "HERALD"),
        Member("Void Monstrosity", "VOID"),
        Member("Faceless Monstrosity", "FACELESS"),
      },
    },
  },

  ["Felsworn"] = {
    {
      key="DEMON_FORM",
      members={
        Member("Demon Form", "DEMON"),
        Member("Fel Form", "FEL"),
        Member("Felsworn Form", "FELSWORN"),
        Member("Metamorphosis", "META", nil, nil, "Interface\\Icons\\Spell_Shadow_DemonForm"),
      },
    },
  },

  ["Guardian"] = {
    {
      key="FORMATION",
      prefixes={"Formation: "},
      members={
        Member("Assault Formation", "ASSAULT"),
        Member("Tower Formation", "TOWER"),
        Member("Line Formation", "LINE"),
        Member("Wreck Formation", "WRECK", 803126),
      },
    },
  },

  ["Knight of Xoroth"] = {
    {
      key="PESTILENCE",
      prefixes={"Pestilence of "},
      members={
        Member("Pestilence of War", "LEECH", nil, nil, "Interface\\Icons\\Spell_Shadow_VampiricAura"),
        Member("Pestilence of Conquest", "SILENCE", 801053, nil, "Interface\\Icons\\Spell_Holy_Silence"),
        Member("Pestilence of Famine", "SLOW", nil, nil, "Interface\\Icons\\Spell_Frost_FrostShock"),
        Member("Pestilence of Death", "CRIT DMG", 801054, nil, "Interface\\Icons\\KoX_Death"),
        Member("Pestilence of Apocalypse", "FIRE DMG", 804786, nil, "Interface\\Icons\\KoX_Apoc"),
      },
    },
  },

  ["Necromancer"] = {
    {
      key="UNDEAD_MODE",
      prefixes={"Undead: "},
      members={
        Member("Undead: Assault", "ASSAULT", nil, {"Undead Assault"}),
        Member("Undead: Protect", "PROTECT", nil, {"Undead Protect"}),
        Member("Undead: Pacify", "PACIFY", nil, {"Undead Pacify"}),
      },
    },
    {
      key="FORM",
      members={
        Member("Lich Form", "LICH", 500981, nil, "Interface\\Icons\\Spell_Shadow_RaiseDead"),
      },
    },
  },

  ["Primalist"] = {
    {
      key="FORM",
      members={
        Member("Golem Form", "GOLEM"),
        Member("Unyielding Form", "UNYIELDING"),
      },
    },
  },

  ["Pyromancer"] = {
    {
      key="ASPECT",
      prefixes={"Aspect of "},
      members={
        Member("Draconic Aspect", "DRACONIC"),
        Member("Aspect of Earth", "EARTH"),
        Member("Aspect of Magic", "MAGIC"),
        Member("Aspect of Time", "TIME"),
        Member("Aspect of Eternity", "ETERNITY"),
      },
    },
  },

  ["Ranger"] = {
    {
      key="ASPECT",
      prefixes={"Aspect of "},
      labelFromName=true,
      members={},
    },
    {
      key="COMMAND_AURA",
      members={Member("Command Aura", "COMMAND")},
    },
  },

  ["Reaper"] = {
    {
      key="FORM",
      members={
        Member("Bolstered Form", "BOLSTERED", 680337),
        Member("Ghastly Form", "GHASTLY", 704357),
      },
    },
    {
      key="PRESENCE",
      members={
        Member("Death's Presence", "DEATH"),
        Member("Intimidating Presence", "INTIMIDATING"),
      },
    },
  },

  ["Runemaster"] = {
    {
      key="ATTUNEMENT",
      prefixes={"Attunement:"},
      labelFromName=true,
      members={},
    },
  },

  ["Starcaller"] = {
    {
      key="ASPECT",
      members={
        Member("Aspect of the Cosmos", "COSMOS", 801123),
        Member("Aspect of the Goddess", "GODDESS", 802203),
      },
    },
    {
      key="FORM",
      members={Member("Celestial Form", "CELESTIAL", 801231)},
    },
  },

  ["Stormbringer"] = {
    {
      key="ASCENDANCE",
      members={Member("Storm Ascendance", "ASCENDANCE")},
    },
  },

  ["Sun Cleric"] = {
    {
      key="VOW",
      prefixes={"Vow of "},
      members={
        Member("Vow of Light", "LIGHT"),
        Member("Vow of Dawn", "DAWN"),
        Member("Vow of Grace", "GRACE"),
        Member("Vow of the Eclipse", "ECLIPSE"),
        Member("Vow of the Valkyr", "VALKYR", 807749),
      },
    },
    {
      key="FORM",
      members={
        Member("Holy Form", "HOLY", 805301),
        Member("Empowered Holy Form", "EMPOWERED"),
      },
    },
  },

  ["Templar"] = {
    {
      key="OATH",
      prefixes={"Oath: ", "Oath of "},
      labelFromName=true,
      members={
        Member("Oath: Righteous Lunge", "RIGHTEOUS LUNGE", 804904),
      },
    },
    {
      key="STYLE",
      prefixes={"Style: "},
      labelFromName=true,
      members={},
    },
  },

  ["Tinker"] = {
    {
      key="MECHSUIT",
      members={
        Member("Mechsuit", "MECHSUIT"),
        Member("Build: Mechsuit", "MECHSUIT"),
      },
    },
    {
      key="MODE",
      prefixes={"Mode: "},
      labelFromName=true,
      members={},
    },
    {
      key="AUGMENTATION",
      prefixes={"Augmentation: "},
      members={
        Member("Aether Augmentation", "AETHER"),
        Member("Tracer Augmentation", "TRACER"),
        Member("Stim Augmentation", "STIM"),
        Member("Engine Augmentation", "ENGINE"),
      },
    },
  },

  ["Venomancer"] = {
    {
      key="FORM",
      members={
        Member("Beetle Form", "BEETLE"),
        Member("Spider Form", "SPIDER"),
        Member("Weaver Form", "WEAVER", 706940),
        Member("Vizier Form", "VIZIER", 504798),
      },
    },
  },

  ["Witch Doctor"] = {},

  ["Witch Hunter"] = {
    {
      key="OATH",
      members={Member("Dark Oath", "DARK OATH")},
    },
  },
}

local function CopyMember(member)
  local copy = {}
  for key, value in pairs(member or {}) do
    if type(value) == "table" then
      local list = {}
      for index, item in ipairs(value) do list[index] = item end
      copy[key] = list
    else
      copy[key] = value
    end
  end
  return copy
end

local function CopyGroup(group)
  local copy = {}
  for key, value in pairs(group or {}) do
    if key == "members" then
      copy.members = {}
      for _, member in ipairs(value or {}) do copy.members[#copy.members + 1] = CopyMember(member) end
    elseif type(value) == "table" then
      local list = {}
      for index, item in ipairs(value) do list[index] = item end
      copy[key] = list
    else
      copy[key] = value
    end
  end
  copy.members = copy.members or {}
  return copy
end

local function GroupsFor(className, options)
  className = RUI.NormalizeClassName and RUI:NormalizeClassName(className) or className
  local result = {}
  for _, group in ipairs(CLASS_STATE_GROUPS[className] or {}) do result[#result + 1] = CopyGroup(group) end

  -- Explicit caller-provided groups are allowed. Generic prefixes are not.
  for _, group in ipairs(options and options.extraGroups or {}) do result[#result + 1] = CopyGroup(group) end

  -- Legacy explicit definitions are placed in one exact-match group. This is
  -- retained for compatibility with the earlier Sun Cleric configuration.
  if options and type(options.extraDefinitions) == "table" and #options.extraDefinitions > 0 then
    local group = {key="EXTRA", members={}}
    for _, definition in ipairs(options.extraDefinitions) do
      group.members[#group.members + 1] = CopyMember(definition)
    end
    result[#result + 1] = group
  end
  return result
end

local function MatchesPrefix(name, prefixes)
  local normalized = Normalize(name)
  for _, prefix in ipairs(prefixes or {}) do
    local wanted = Normalize(prefix)
    if wanted ~= "" and string.sub(normalized, 1, #wanted) == wanted then return true end
  end
  return false
end

local function MatchesMember(name, spellID, member)
  local normalized = Normalize(name)
  if tonumber(member.id) and tonumber(spellID) and tonumber(member.id) == tonumber(spellID) then return true end
  if normalized ~= "" and normalized == Normalize(member.name) then return true end
  if normalized ~= "" and normalized == Normalize(member.buff) then return true end
  for _, alias in ipairs(member.aliases or {}) do
    if normalized == Normalize(alias) then return true end
  end
  return false
end

local function GroupMemberFor(group, name, spellID)
  for _, member in ipairs(group.members or {}) do
    if MatchesMember(name, spellID, member) then return member end
  end
  if MatchesPrefix(name, group.prefixes) then
    return {
      name=name,
      label=group.labelFromName and name or group.key,
      id=spellID,
      discovered=true,
    }
  end
  return nil
end

local function IsExcluded(options, name)
  local normalized = Normalize(name)
  for _, excluded in ipairs(options and options.excludeNames or {}) do
    if normalized == Normalize(excluded) then return true end
  end
  for _, prefix in ipairs(options and options.excludePrefixes or {}) do
    local wanted = Normalize(prefix)
    if wanted ~= "" and string.sub(normalized, 1, #wanted) == wanted then return true end
  end
  return false
end

function RUI:IsClassStateName(className, name, options)
  if not name or IsExcluded(options, name) then return false end
  for _, group in ipairs(GroupsFor(className, options)) do
    if GroupMemberFor(group, name, nil) then return true end
  end
  return false
end

function RUI:IsClassStateAuraDefinition(className, definition, options)
  if type(definition) ~= "table" then return false end
  if definition.classState == true or definition.stateTracker == true then return true end
  if definition.classState == false or definition.stateTracker == false then return false end
  local name = definition.buff or definition.name
  local spellID = tonumber(definition.auraID) or tonumber(definition.id)
  if IsExcluded(options, name) then return false end
  for _, group in ipairs(GroupsFor(className, options)) do
    if GroupMemberFor(group, name, spellID) then return true end
  end
  return false
end

local function ReadPlayerAuras()
  local state = {list={}}
  if type(UnitBuff) ~= "function" then return state end
  for index = 1, 40 do
    local values = {UnitBuff("player", index)}
    local name = values[1]
    if not name then break end
    state.list[#state.list + 1] = {
      name=name,
      icon=values[3],
      count=tonumber(values[4]) or 0,
      duration=tonumber(values[6]) or 0,
      expires=tonumber(values[7]) or 0,
      caster=values[8],
      spellID=tonumber(values[11]),
    }
  end
  return state
end

local function IsOwnAura(aura)
  local caster = aura and aura.caster
  return caster == nil or caster == "" or caster == "player" or caster == "pet" or caster == "vehicle"
end

local function ActiveShapeshifts()
  local result = {}
  if type(GetNumShapeshiftForms) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then return result end
  local current = 0
  if type(GetShapeshiftForm) == "function" then
    local ok, value = pcall(GetShapeshiftForm)
    if ok then current = tonumber(value) or 0 end
  end
  local ok, count = pcall(GetNumShapeshiftForms)
  count = ok and tonumber(count) or 0
  for index = 1, count do
    local success, texture, name, active = pcall(GetShapeshiftFormInfo, index)
    if success and name and (active == true or active == 1 or index == current) then
      result[#result + 1] = {name=name, icon=texture, source="shapeshift"}
    end
  end
  return result
end

local function ResolveFallback(options)
  local fallback = options and options.fallbackState
  if type(fallback) == "function" then
    local ok, value = pcall(fallback)
    fallback = ok and value or nil
  end
  if type(fallback) == "string" then fallback = {name=fallback} end
  return type(fallback) == "table" and fallback or nil
end

local function ShortLabel(name)
  local label = tostring(name or "STATE")
  label = label:gsub("^[Vv][Oo][Ww]%s+[Oo][Ff]%s+[Tt][Hh][Ee]%s+", "")
  label = label:gsub("^[Vv][Oo][Ww]%s+[Oo][Ff]%s+", "")
  label = label:gsub("^[Aa][Ss][Pp][Ee][Cc][Tt]%s+[Oo][Ff]%s+[Tt][Hh][Ee]%s+", "")
  label = label:gsub("^[Aa][Ss][Pp][Ee][Cc][Tt]%s+[Oo][Ff]%s+", "")
  label = label:gsub("^[Pp][Rr][Ee][Ss][Ee][Nn][Cc][Ee]%s+[Oo][Ff]%s+[Tt][Hh][Ee]%s+", "")
  label = label:gsub("^[Pp][Rr][Ee][Ss][Ee][Nn][Cc][Ee]%s+[Oo][Ff]%s+", "")
  label = label:gsub("^[Pp][Ee][Ss][Tt][Ii][Ll][Ee][Nn][Cc][Ee]%s+[Oo][Ff]%s+", "")
  label = label:gsub("^[Oo][Aa][Tt][Hh]%s+[Oo][Ff]%s+[Tt][Hh][Ee]%s+", "")
  label = label:gsub("^[Oo][Aa][Tt][Hh]%s+[Oo][Ff]%s+", "")
  label = label:gsub("^[Oo][Aa][Tt][Hh]:%s*", "")
  label = label:gsub("^[Uu][Nn][Dd][Ee][Aa][Dd]:%s*", "")
  label = label:gsub("^[Ff][Oo][Rr][Mm][Aa][Tt][Ii][Oo][Nn]:%s*", "")
  label = label:gsub("^[Aa][Tt][Tt][Uu][Nn][Ee][Mm][Ee][Nn][Tt]:%s*", "")
  label = label:gsub("^[Mm][Oo][Dd][Ee]:%s*", "")
  label = label:gsub("^[Ss][Tt][Yy][Ll][Ee]:%s*", "")
  label = label:gsub("^[Aa][Uu][Gg][Mm][Ee][Nn][Tt][Aa][Tt][Ii][Oo][Nn]:%s*", "")
  return label ~= "" and label or tostring(name or "STATE")
end

local function TextureFor(state)
  if state.icon then return state.icon end
  local member = state.member or {}
  if member.icon then return member.icon end
  if type(GetSpellInfo) == "function" then
    local reference = tonumber(member.id) or member.name or state.name
    local _, _, texture = GetSpellInfo(reference)
    if texture then return texture end
  end
  return member.fallbackIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local Tracker = {}
Tracker.__index = Tracker

local function CreateTrackerFrame(self, index)
  local size = self.options.size or ((RUI.layout.stanceTracker and RUI.layout.stanceTracker.size) or 38)
  local frame = W:CreateIcon(self.parent, size)
  frame.stateIndex = index
  if frame.cooldownShade then frame.cooldownShade:Hide() end
  frame.cooldownText:SetText("")
  frame.stackText:SetText("")

  -- Match Knight of Xoroth's Pestilence presentation: compact icon with the
  -- current state's useful label directly above it, not a large aura card.
  frame.stateText = frame:CreateFontString(nil, "OVERLAY")
  frame.stateText:SetPoint("BOTTOM", frame, "TOP", 0, 3)
  frame.stateText:SetJustifyH("CENTER")
  frame.stateText:SetWidth(self.options.labelWidth or 84)
  RUI:ApplyFont(frame.stateText, self.options.nameSize or 9, "OUTLINE")
  if self.options.consumeMouse == true then
    -- Consume hover input so an action button underneath cannot leak an
    -- unrelated spell tooltip through the state icon.
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(icon)
      local state = icon.state
      if not state or not GameTooltip then return end
      GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
      GameTooltip:SetText(tostring(state.name or "State"), 1, 1, 1)
      GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
      if GameTooltip then GameTooltip:Hide() end
    end)
  else
    frame:EnableMouse(false)
  end
  frame:Hide()
  self.frames[index] = frame
  return frame
end

function Tracker:Collect(auraState)
  auraState = auraState or ReadPlayerAuras()
  local groups = GroupsFor(self.className, self.options)
  local shapeshifts = ActiveShapeshifts()
  local active = {}

  for groupIndex, group in ipairs(groups) do
    local selected

    -- Shapeshift forms are the strongest source because the client identifies
    -- the active form directly.
    for _, shape in ipairs(shapeshifts) do
      if not IsExcluded(self.options, shape.name) then
        local member = GroupMemberFor(group, shape.name, nil)
        if member then
          selected = {
            group=group,
            groupIndex=groupIndex,
            member=member,
            name=shape.name,
            icon=shape.icon,
            count=0,
            duration=0,
            expires=0,
            source="shapeshift",
          }
          break
        end
      end
    end

    -- Ascension also exposes some stances as player auras. Only exact members
    -- of this class's current group are accepted.
    if not selected then
      for _, aura in ipairs(auraState.list or {}) do
        if IsOwnAura(aura) and not IsExcluded(self.options, aura.name) then
          local member = GroupMemberFor(group, aura.name, aura.spellID)
          if member then
            selected = {
              group=group,
              groupIndex=groupIndex,
              member=member,
              name=aura.name,
              icon=aura.icon,
              count=aura.count,
              duration=aura.duration,
              expires=aura.expires,
              spellID=aura.spellID,
              aura=aura,
              source="aura",
            }
            break
          end
        end
      end
    end

    if selected then active[#active + 1] = selected end
  end

  -- Used by Bloodmage to represent Mortal Form when no exact Cursed Form
  -- state is active. The fallback is class-specific and never scans generic auras.
  if #active == 0 or self.options.alwaysFallback == true then
    local fallback = ResolveFallback(self.options)
    if fallback and fallback.name and not IsExcluded(self.options, fallback.name) then
      for groupIndex, group in ipairs(groups) do
        local member = GroupMemberFor(group, fallback.name, fallback.spellID or fallback.id)
        if member then
          local duplicate = false
          for _, item in ipairs(active) do if item.groupIndex == groupIndex then duplicate = true break end end
          if not duplicate then
            active[#active + 1] = {
              group=group,
              groupIndex=groupIndex,
              member=member,
              name=fallback.name,
              icon=fallback.icon,
              count=fallback.count,
              duration=fallback.duration,
              expires=fallback.expires,
              spellID=fallback.spellID or fallback.id,
              source="fallback",
            }
          end
          break
        end
      end
    end
  end

  table.sort(active, function(left, right) return (left.groupIndex or 999) < (right.groupIndex or 999) end)
  return active
end

function Tracker:Position(count)
  local size = self.options.size or ((RUI.layout.stanceTracker and RUI.layout.stanceTracker.size) or 38)
  local gap = self.options.gap or ((RUI.layout.stanceTracker and RUI.layout.stanceTracker.gap) or 6)
  local startX = self.options.x or -195
  local direction = self.options.direction == "right" and 1 or -1
  local y = self.options.y or ((RUI.layout.demonfire and RUI.layout.demonfire.y) or -118)
  for index = 1, count do
    local frame = self.frames[index] or CreateTrackerFrame(self, index)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", startX + direction * (index - 1) * (size + gap), y)
  end
end

function Tracker:Update(auraState)
  local active = self:Collect(auraState)
  self.active = active
  self:Position(#active)
  local theme = RUI:GetTheme()
  for index, item in ipairs(active) do
    local frame = self.frames[index] or CreateTrackerFrame(self, index)
    frame.state = item
    frame.texture:SetTexture(TextureFor(item))
    if frame.texture.SetDesaturated then frame.texture:SetDesaturated(false) end
    W:SetBorder(frame, theme.accent2, 1)
    local label = item.member and item.member.label or nil
    if not label or label == "" or (item.member and item.member.discovered and item.group and item.group.labelFromName) then
      label = ShortLabel(item.name)
    end
    frame.stateText:SetText(string.upper(tostring(label)))
    frame.stateText:SetTextColor(1, 1, 1, 1)
    frame.stackText:SetText(item.count and tonumber(item.count) and tonumber(item.count) > 1 and tostring(item.count) or "")
    local expires = tonumber(item.expires) or 0
    local remaining = expires > 0 and math.max(0, expires - GetTime()) or 0
    frame.cooldownText:SetText(remaining > 0.05 and W:FormatCooldown(remaining) or "")
    frame.cooldownText:SetTextColor(0.72, 1.00, 0.42, 1)
    if frame.cooldownShade then frame.cooldownShade:Hide() end
    frame:Show()
  end
  for index = #active + 1, #self.frames do
    self.frames[index].state = nil
    self.frames[index]:Hide()
  end
  return #active
end

function Tracker:HasTimers()
  for _, item in ipairs(self.active or {}) do
    if tonumber(item.expires) and tonumber(item.expires) > 0 then return true end
  end
  return false
end

function Tracker:UpdateTimers()
  for _, frame in ipairs(self.frames) do
    local item = frame.state
    if frame:IsShown() and item then
      local expires = tonumber(item.expires) or 0
      if expires > 0 then
        local remaining = math.max(0, expires - GetTime())
        if remaining > 0.05 then
          frame.cooldownText:SetText(W:FormatCooldown(remaining))
        else
          frame.state = nil
          frame:Hide()
        end
      end
    end
  end
end

function Tracker:Hide()
  self.active = {}
  for _, frame in ipairs(self.frames) do
    frame.state = nil
    frame:Hide()
  end
end

function RUI:CreateClassStateTracker(parent, className, options)
  if not parent then return nil end
  local tracker = setmetatable({
    parent=parent,
    className=self:NormalizeClassName(className) or className,
    options=options or {},
    frames={},
    active={},
  }, Tracker)
  trackers[parent] = tracker
  return tracker
end

RUI.ClassStateGroups = CLASS_STATE_GROUPS
RUI.ClassStateCatalog = CLASS_STATE_GROUPS -- backwards-compatible alias
RUI._classStateTrackerLoaded = true

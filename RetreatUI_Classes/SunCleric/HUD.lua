local RUI = RetreatUI
if not RUI then return end

local CLASS_NAME = "Sun Cleric"
local W = RUI.HUDWidgets

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

-- Seraphim tank curation based on the live playtest HUD. The full class data
-- remains available for detection and future spec work, but only the abilities
-- that matter to this tank setup are rendered on the two visible HUD rows.
local function CurateSeraphimHUD()
  local database = RUI:GetClassSpellDatabase(CLASS_NAME)
  if not database or type(database.spells) ~= "table" then return end

  local recordsByName = {}
  for _, record in ipairs(database.spells) do
    if record.name then recordsByName[Normalize(record.name)] = recordsByName[Normalize(record.name)] or record end
    for _, alias in ipairs(record.aliases or {}) do
      recordsByName[Normalize(alias)] = recordsByName[Normalize(alias)] or record
    end
    if record.hudRow then record.trackHUD = false end
    if record.auraTracker then record.auraTracker = false end
    if record.targetDebuff then record.targetDebuff = false end
  end

  local function Apply(record, values)
    for key, value in pairs(values or {}) do record[key] = value end
    return record
  end

  local function Ensure(canonicalName, lookupNames, values)
    local record
    for _, name in ipairs(lookupNames or {canonicalName}) do
      record = recordsByName[Normalize(name)]
      if record then break end
    end
    if not record then
      record = {name=canonicalName}
      database.spells[#database.spells + 1] = record
    end
    record.name = canonicalName
    Apply(record, values)
    recordsByName[Normalize(canonicalName)] = record
    for _, alias in ipairs(record.aliases or {}) do recordsByName[Normalize(alias)] = record end
    return record
  end

  local dawnRecord = Ensure("Dawn", {"Dawn", "Casting Dawn"}, {
    id=804584, aliases={"Casting Dawn"}, category="resource", order=10,
    trackCooldown=false, forceHUD=false, forceMain=false, trackHUD=false, glowWhenUsable=false,
    fallbackIcon="Interface\\Icons\\Spell_Holy_SearingLight",
  })

  local core = {
    Ensure("Horusath Blast", {"Horusath Blast"}, {
      id=500154, category="rotation", hudRow="core", order=20, trackCooldown=true,
      forceHUD=true, forceMain=true, trackHUD=true, targetDebuff=true, cooldownHint=25,
      fallbackIcon="Interface\\Icons\\paladin_holy",
    }),
    Ensure("Solar Nova", {"Solar Nova"}, {
      id=680621, category="rotation", hudRow="core", order=30, trackCooldown=true,
      forceHUD=true, forceMain=true, trackHUD=true, cooldownHint=20,
      fallbackIcon="Interface\\Icons\\spell_holy_holyguidance",
    }),
    Ensure("Gavel of Light", {"Gavel of Light", "Gavel of Wrath"}, {
      id=502475, aliases={"Gavel of Wrath"}, category="rotation", hudRow="core", order=40,
      trackCooldown=true, forceHUD=true, forceMain=true, trackHUD=true, cooldownHint=5,
      fallbackIcon="Interface\\Icons\\Ability_Paladin_EnlightenedJudgements",
    }),
    Ensure("Dawnbreak", {"Dawnbreak", "Dawnbreaker"}, {
      id=502497, aliases={"Dawnbreaker"}, category="rotation", hudRow="core", order=50,
      trackCooldown=true, forceHUD=true, forceMain=true, trackHUD=true, cooldownHint=6,
      glowWhenAura={"Sun Strider", "Dawn's Arrival", "Sun Warrior's Guidance"},
      fallbackIcon="Interface\\icons\\nhi_energyshield_Border",
    }),
    Ensure("Justicar's Wrath", {"Justicar's Wrath"}, {
      id=806980, category="rotation", hudRow="core", order=60, trackCooldown=true,
      forceHUD=true, forceMain=true, trackHUD=true, targetDebuff=true, cooldownHint=6,
      fallbackIcon="Interface\\icons\\novart_weapon_(28)_Border",
    }),
    Ensure("Hammer of Kings", {"Hammer of Kings"}, {
      id=804751, category="rotation", hudRow="core", order=70, trackCooldown=true,
      forceHUD=true, forceMain=true, trackHUD=true, targetDebuff=true, cooldownHint=20,
      separateAuraTracker=true,
      fallbackIcon="Interface\\icons\\custom_T_Nhance_RPG_Icons_HolyHammer_Border",
    }),
    Ensure("Dawnfall", {"Dawnfall"}, {
      id=806118, category="offensive", hudRow="core", order=80, trackCooldown=true,
      forceHUD=true, forceMain=true, trackHUD=true,
      fallbackIcon="Interface\\Icons\\Spell_Holy_HolyNova",
    }),
    Ensure("Radiance", {"Radiance"}, {
      id=800054, category="offensive", hudRow="core", order=90, trackCooldown=true,
      forceHUD=true, forceMain=true, trackHUD=true, cooldownHint=120,
      separateAuraTracker=true,
      fallbackIcon="Interface\\Icons\\inv_ability_holyfire_nova",
    }),
  }

  local utility = {
    Ensure("Seraphic Bulwark", {"Seraphic Bulwark"}, {
      id=560095, category="defensive", hudRow="utility", order=10, trackCooldown=true,
      trackCharges=true, forceHUD=true, forceUtility=true, trackHUD=true,
      separateAuraTracker=true,
      fallbackIcon="Interface\\Icons\\inv_shield_1h_raidnazmir_d_01",
    }),
    Ensure("Chosen of the Light", {"Chosen of the Light", "Chosen of Light"}, {
      id=800622, aliases={"Chosen of Light"}, category="defensive", hudRow="utility", order=20,
      trackCooldown=true, forceHUD=true, forceUtility=true, trackHUD=true,
      separateAuraTracker=true,
      fallbackIcon="Interface\\Icons\\Spell_Holy_AuraMastery",
    }),
    Ensure("Solar Prayer", {"Solar Prayer"}, {
      id=806479, category="defensive", hudRow="utility", order=30, trackCooldown=true,
      forceHUD=true, forceUtility=true, trackHUD=true,
      fallbackIcon="Interface\\Icons\\spell_holy_devineaegis",
    }),
    Ensure("Paragon", {"Paragon"}, {
      category="defensive", hudRow="utility", order=40, trackCooldown=true,
      forceHUD=true, forceUtility=true, trackHUD=true, cooldownHint=300,
      separateAuraTracker=true,
      fallbackIcon="Interface\\Icons\\Spell_Holy_Power",
    }),
    Ensure("Solar Invocation: Conquest", {"Solar Invocation: Conquest"}, {
      id=800764, category="offensive", hudRow="utility", order=50, trackCooldown=true,
      forceHUD=true, forceUtility=true, trackHUD=true, cooldownHint=30,
      fallbackIcon="Interface\\icons\\nhi_holy_toglory_Border",
    }),
    Ensure("Solar Invocation: Resplendence", {"Solar Invocation: Resplendence", "Resplendence"}, {
      id=806159, aliases={"Resplendence"}, category="defensive", hudRow="utility", order=60,
      trackCooldown=true, forceHUD=true, forceUtility=true, trackHUD=true, cooldownHint=30,
      separateAuraTracker=true,
      fallbackIcon="Interface\\Icons\\ability_priest_rayofhope",
    }),
    Ensure("Solar Invocation: Revelation", {"Solar Invocation: Revelation", "Revelation"}, {
      id=503651, aliases={"Revelation"}, category="defensive", hudRow="utility", order=70,
      trackCooldown=true, forceHUD=true, forceUtility=true, trackHUD=true, cooldownHint=30,
      fallbackIcon="Interface\\icons\\5_priestskill07_Border",
    }),
    Ensure("Circle of Valor", {"Circle of Valor"}, {
      id=520647, category="defensive", hudRow="utility", order=80, trackCooldown=true,
      forceHUD=true, forceUtility=true, trackHUD=true, cooldownHint=180,
      fallbackIcon="Interface\\Icons\\inv_circlet_firelands_d_01",
    }),
    Ensure("Scroll of Hope", {"Scroll of Hope"}, {
      id=680646, category="defensive", hudRow="utility", order=90, trackCooldown=true,
      forceHUD=true, forceUtility=true, trackHUD=true, cooldownHint=300,
      fallbackIcon="Interface\\icons\\custom_T_Nhance_RPG_Icons_HolyScroll_Border",
    }),
    Ensure("Champion of the Sun", {"Champion of the Sun"}, {
      id=800612, category="utility", hudRow="utility", order=100, trackCooldown=true,
      forceHUD=true, forceUtility=true, trackHUD=true, cooldownHint=120,
      fallbackIcon="Interface\\Icons\\inv_ability_heraldofthesunpaladin_dawnlight",
    }),
    Ensure("Seraphim Stride", {"Seraphim Stride", "Sun Stride", "Sun Strider"}, {
      id=680700, aliases={"Sun Stride", "Sun Strider"}, category="mobility", hudRow="utility", order=110,
      trackCooldown=true, forceHUD=true, forceUtility=true, trackHUD=true, cooldownHint=19,
      glowWhenAura={"Sun Strider"}, fallbackIcon="Interface\\Icons\\ability_priest_archangel",
    }),
    Ensure("Judgement Day", {"Judgement Day", "Judgment Day"}, {
      id=806121, aliases={"Judgment Day"}, category="control", hudRow="utility", order=120,
      trackCooldown=true, forceHUD=true, forceUtility=true, trackHUD=true, cooldownHint=60,
      fallbackIcon="Interface\\Icons\\Spell_Holy_RighteousFury",
    }),
    Ensure("Glare", {"Glare"}, {
      id=805583, category="control", hudRow="utility", order=130, trackCooldown=true,
      forceHUD=true, forceUtility=true, trackHUD=true, cooldownHint=120,
      fallbackIcon="Interface\\Icons\\ability_priest_halo",
    }),
    Ensure("Calm", {"Calm"}, {
      id=804057, category="utility", hudRow="utility", order=140, trackCooldown=true,
      forceHUD=true, forceUtility=true, trackHUD=true, cooldownHint=90,
      fallbackIcon="Interface\\Icons\\spell_priest_burningwill",
    }),
    Ensure("Injunction", {"Injunction"}, {
      id=800624, category="taunt", hudRow="utility", order=150, trackCooldown=true,
      forceHUD=true, forceUtility=true, trackHUD=true,
      fallbackIcon="Interface\\Icons\\Spell_Holy_SealOfMight",
    }),
  }

  -- Exact active-only uptime/proc list requested by the Seraphim tank tester.
  -- These are deliberately separate records from the cooldown-row abilities so
  -- an active buff timer can never overwrite or flash against the spell cooldown.
  local function AddUptimeTracker(name, buff, aliases, order, fallbackIcon)
    local record = {
      name=name .. " Uptime",
      category="proc",
      auraTracker=true,
      buff=buff,
      aliases=aliases or {},
      trackDuration=true,
      trackHUD=false,
      order=order,
      fallbackIcon=fallbackIcon,
    }
    database.spells[#database.spells + 1] = record
    return record
  end

  local procRecords = {
    AddUptimeTracker("Hammer of Kings", "Hammer of Kings", {}, 10,
      "Interface\\icons\\custom_T_Nhance_RPG_Icons_HolyHammer_Border"),
    AddUptimeTracker("Seraphic Bulwark", "Seraphic Bulwark", {}, 20,
      "Interface\\Icons\\inv_shield_1h_raidnazmir_d_01"),
    AddUptimeTracker("Shining Shield", "Shining Shield", {}, 30,
      "Interface\\Icons\\INV_Shield_06"),
    AddUptimeTracker("Radiance", "Radiance", {}, 40,
      "Interface\\Icons\\inv_ability_holyfire_nova"),
    AddUptimeTracker("Chosen of the Light", "Chosen of the Light", {"Chosen of Light"}, 50,
      "Interface\\Icons\\Spell_Holy_AuraMastery"),
    AddUptimeTracker("Resplendence", "Resplendence", {"Solar Invocation: Resplendence"}, 60,
      "Interface\\Icons\\ability_priest_rayofhope"),
    AddUptimeTracker("Seraphim's Light", "Seraphim's Light", {}, 70,
      "Interface\\Icons\\Spell_Holy_DivineIllumination"),
    AddUptimeTracker("Paragon", "Paragon", {}, 80,
      "Interface\\Icons\\Spell_Holy_Power"),
    AddUptimeTracker("Angelic Presence", "Angelic Presence", {}, 90,
      "Interface\\Icons\\ability_paladin_conviction"),
  }

  -- Preserve references to avoid Lua's optimizer/linters considering these
  -- intentionally curated records unused in future generated builds.
  database.disableLiveClassCooldowns = true
  database.seraphimDawn = dawnRecord
  database.seraphimCore = core
  database.seraphimUtility = utility
  database.seraphimProcs = procRecords
  database.version = math.max(tonumber(database.version) or 1, 7)
end

CurateSeraphimHUD()

local module = RUI:RegisterAdvancedClassHUD(CLASS_NAME, {
  frameName = "RetreatUISunClericHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {BLESSINGS=true,PIETY=true,SERAPHIM=true,VALKYR=true},
  maxCore = 8,
  maxUtility = 15,
  maxProcs = 9,
  stanceAuraPrefix = "Vow of ",
  stateGlowWhenUsable = {id=804584, name="Dawn", aliases={"Casting Dawn"}},
  stateGlowGroup = "VOW",
  stateGlowResourceReady = {current=20, maximum=20},
  hudYOffset = -4,
  -- Reserve a clean state row above the player frame: Vow, optional Form,
  -- then the Sol Invictus reminder. Nothing in this row may overlap unitframes.
  stanceTracker = {anchor="player", x=-66, y=8, fallbackX=-376, fallbackY=-94, direction="right", gap=6, size=38, width=100, height=58},
})

-------------------------------------------------------------------------------
-- Seraphim tank extras: replace the native CoA orb without an OnUpdate script
-- and show a threat-aura reminder only while Sol Invictus is missing.
-------------------------------------------------------------------------------
local extra = {
  active=false,
  eventFrame=nil,
  threatFrame=nil,
  orbHooked=false,
}

local function PlayerAura(name)
  if type(UnitBuff) ~= "function" then return nil end
  local wanted = Normalize(name)
  for index = 1, 40 do
    local values = {UnitBuff("player", index)}
    if not values[1] then break end
    if Normalize(values[1]) == wanted then
      return {
        name=values[1], icon=values[3], count=tonumber(values[4]) or 0,
        duration=tonumber(values[6]) or 0, expires=tonumber(values[7]) or 0,
        spellID=tonumber(values[11]),
      }
    end
  end
  return nil
end

local function HideNativeResourceOrb()
  local orb = _G.CoAResourceOrb
  if not orb then return end
  if not extra.orbHooked and type(hooksecurefunc) == "function" and type(orb.Show) == "function" then
    extra.orbHooked = true
    hooksecurefunc(orb, "Show", function(frame)
      if extra.active and frame and frame.Hide then frame:Hide() end
    end)
  end
  if extra.active and orb.Hide then orb:Hide() end
end

local function PlayerFrameAnchor()
  local frame = _G.ElvUF_Player or _G.PlayerFrame
  if frame and type(frame) ~= "string" and frame.GetWidth and frame.SetPoint then return frame end
  return nil
end

local function PositionThreatFrame(frame)
  if not frame then return end
  frame:ClearAllPoints()
  local playerFrame = PlayerFrameAnchor()
  if playerFrame then
    -- Third reserved slot in the player-frame state row. This keeps the
    -- reminder completely away from both target and health frames.
    frame:SetPoint("BOTTOM", playerFrame, "TOP", 66, 8)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", -244, -94)
  end
end

local function CreateThreatFrame()
  if extra.threatFrame then return extra.threatFrame end
  local root = _G.RetreatUISunClericHUD
  if not root then return nil end

  local frame = W:CreateIcon(root, 38)
  PositionThreatFrame(frame)
  frame.stateText = frame:CreateFontString(nil, "OVERLAY")
  frame.stateText:SetPoint("BOTTOM", frame, "TOP", 0, 3)
  frame.stateText:SetWidth(128)
  frame.stateText:SetJustifyH("CENTER")
  RUI:ApplyFont(frame.stateText, 9, "OUTLINE")
  frame.cooldownText:SetText("")
  frame.stackText:SetText("")
  if frame.cooldownShade then frame.cooldownShade:Hide() end
  frame:EnableMouse(false)
  extra.threatFrame = frame
  return frame
end

local function IsSeraphimSetup(aura)
  if aura then return true end
  if RUI.IsSpellLearned then
    return RUI:IsSpellLearned("Seraphic Bulwark")
      or RUI:IsSpellLearned("Sol Invictus")
      or RUI:IsSpellLearned("Gavel of Light")
  end
  return false
end

local function UpdateThreatCheck()
  if not extra.active then return end
  local aura = PlayerAura("Sol Invictus")
  local frame = CreateThreatFrame()
  if not frame then return end
  PositionThreatFrame(frame)

  if not IsSeraphimSetup(aura) then
    frame:Hide()
    return
  end

  local fallback
  if type(GetSpellInfo) == "function" then
    local _, _, texture = GetSpellInfo("Sol Invictus")
    fallback = texture
  end
  frame.texture:SetTexture((aura and aura.icon) or fallback or "Interface\\Icons\\Spell_Holy_InnerFire")
  frame.cooldownText:SetText("")
  frame.stackText:SetText("")

  if aura then
    -- Sol Invictus is a maintenance reminder, not a permanent HUD element.
    frame:Hide()
    return
  end

  if frame.texture.SetDesaturated then frame.texture:SetDesaturated(true) end
  frame.stateText:SetText("SOL INVICTUS OFF")
  frame.stateText:SetTextColor(1.00, 0.30, 0.20, 1)
  W:SetBorder(frame, {1.00, 0.18, 0.10, 1}, 1)
  W:SetGlow(frame, {1.00, 0.12, 0.06, 1}, 0.65)
  frame:Show()
end

local function ActivateExtras()
  extra.active = true
  HideNativeResourceOrb()
  UpdateThreatCheck()

  if not extra.eventFrame then
    extra.eventFrame = CreateFrame("Frame")
    extra.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    extra.eventFrame:RegisterEvent("UNIT_AURA")
    extra.eventFrame:RegisterEvent("SPELLS_CHANGED")
    extra.eventFrame:RegisterEvent("ADDON_LOADED")
    extra.eventFrame:RegisterEvent("UNIT_POWER")
    extra.eventFrame:RegisterEvent("UNIT_POWER_FREQUENT")
    extra.eventFrame:SetScript("OnEvent", function(_, event, unit)
      if not extra.active then return end
      if (event == "UNIT_AURA" or event == "UNIT_POWER" or event == "UNIT_POWER_FREQUENT") and unit ~= "player" then return end
      HideNativeResourceOrb()
      UpdateThreatCheck()
    end)
  end
  extra.eventFrame:Show()
  for _, delay in ipairs({0.10, 0.50, 1.00, 2.00, 4.00, 8.00}) do
    RUI:After(delay, function()
      if extra.active then HideNativeResourceOrb(); UpdateThreatCheck() end
    end)
  end
end

local function DeactivateExtras()
  extra.active = false
  if extra.eventFrame then extra.eventFrame:Hide() end
  if extra.threatFrame then extra.threatFrame:Hide() end
  local orb = _G.CoAResourceOrb
  if orb and orb.Show then pcall(orb.Show, orb) end
end

if module then
  local baseActivate = module.activate
  local baseDeactivate = module.deactivate

  function module:activate()
    local result = baseActivate and baseActivate(self)
    ActivateExtras()
    return result
  end

  function module:deactivate()
    DeactivateExtras()
    if baseDeactivate then return baseDeactivate(self) end
  end
end

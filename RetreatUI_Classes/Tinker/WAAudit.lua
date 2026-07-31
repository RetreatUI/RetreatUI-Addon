local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

-- Native data additions from the supplied Tinker WeakAura audit. The WeakAura
-- itself is never imported. Spell/effect IDs are merged into the collector
-- database and every duplicate spell ID remains one RetreatUI tracker.

local database = RUI:GetClassSpellDatabase("Tinker")
if type(database) ~= "table" then return end
database.spells = database.spells or {}

local function Normalize(value)
  return string.lower(tostring(value or "")):gsub("’", "'"):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local byID, byName = {}, {}
for _,record in ipairs(database.spells) do
  if type(record)=="table" then
    if tonumber(record.id) then byID[tonumber(record.id)]=record end
    if record.name then byName[Normalize(record.name)]=record end
  end
end

local function MergeList(target, values)
  target=type(target)=="table" and target or {}
  local seen={}
  for _,value in ipairs(target) do seen[tostring(value)]=true end
  for _,value in ipairs(values or {}) do
    if not seen[tostring(value)] then target[#target+1]=value; seen[tostring(value)]=true end
  end
  return target
end

local function AddOrMerge(record)
  local id=tonumber(record and record.id)
  local name=Normalize(record and record.name)
  local existing=(id and byID[id]) or (name~="" and byName[name])
  if existing then
    existing.aliases=MergeList(existing.aliases,record.aliases)
    for key,value in pairs(record) do
      if key~="aliases" and existing[key]==nil then existing[key]=value end
    end
    return existing,false
  end
  database.spells[#database.spells+1]=record
  if id then byID[id]=record end
  if name~="" then byName[name]=record end
  return record,true
end

local function Existing(idOrName)
  if type(idOrName)=="number" then return byID[idOrName] end
  return byName[Normalize(idOrName)]
end

local function AddAlias(id, alias)
  local record=Existing(id)
  if record then record.aliases=MergeList(record.aliases,{alias}) end
end

-- Scrap is its own 0-100 resource. Machine Synergy remains one independent
-- active proc icon and is deliberately removed from the resource aliases.
database.nativeResource = {
  title="SCRAP",
  spellIDs={801816},
  auraNames={"Scrap"},
  keywords={"scrap"},
  maximum=100,
  maxStacks=100,
  defaultCurrent=0,
  keepVisible=true,
  mode="bar",
  showLabel=false,
  width=330,
  height=10,
  icon="Interface\\Icons\\INV_Misc_Gear_01",
}

-- Conflicting WA names are aliases/replacements, never additional icons.
AddAlias(802052,"Doomcannon MK-3")
AddAlias(806757,"Upgrade: Clockwork Titan")
AddAlias(500249,"Build: Gatling Turret")
AddAlias(806224,"Firing Cage")
AddAlias(504527,"Scrap Slam")
AddAlias(805305,"Mega Module")

local napalm=Existing(92138)
if napalm then napalm.auraID=802032 end
local mechaplating=Existing(705831)
if mechaplating then mechaplating.auraID=503535; mechaplating.buffID=503535 end

-- Existing and new beacons use one ability icon. A 15-second summon timer is
-- rendered on that same icon by Tinker/HUD.lua; no duplicate uptime bar exists.
for _,name in ipairs({"Build: Alarm Beacon","Build: Restorative Beacon"}) do
  local record=Existing(name)
  if record then record.activeDuration=15; record.trackDuration=true; record.separateAuraTracker=false end
end

local abilities = {
  {name="Overclock Weapon",id=801715,category="offensive",hudRow="core",order=22,trackCooldown=true,buffID=801715,trackDuration=true,sourceTab="Firearms"},
  {name="Activate Mechsuit: Shredder",aliases={"Mechsuit: Shredder"},id=801384,category="offensive",hudRow="core",order=24,trackCooldown=true,buffID=801384,trackDuration=true,sourceTab="Mechanics"},
  {name="Supercharge",id=801708,category="offensive",hudRow="core",order=28,trackCooldown=true,sourceTab="Invention"},
  {name="Rocket Barrage",id=805314,category="offensive",hudRow="core",order=30,trackCooldown=true,sourceTab="Firearms"},
  {name="Cannonball Launcher",id=805322,category="offensive",hudRow="core",order=32,trackCooldown=true,sourceTab="Firearms"},
  {name="Stun Grenade",id=801821,category="control",hudRow="utility",order=125,trackCooldown=true,sourceTab="Firearms"},
  {name="Build: Scraptron",id=500242,category="offensive",hudRow="core",order=42,trackCooldown=true,sourceTab="Mechanics"},
  {name="Build: Battle Turret X-13",id=504519,category="offensive",hudRow="core",order=44,trackCooldown=true,sourceTab="Firearms"},
  {name="Build: ZIGGI-6K",id=524840,category="offensive",hudRow="core",order=46,trackCooldown=true,sourceTab="Invention"},
  {name="Blasting Round",id=300070,category="rotation",hudRow="core",order=14,trackCooldown=true,buffID=804165,trackDuration=true,sourceTab="Firearms"},
  {name="Blackpowder Barrage",id=801822,aliases={"Black Powder Barrage"},category="offensive",hudRow="core",order=34,trackCooldown=true,sourceTab="Firearms"},
  {name="Ammo Clip",id=800348,category="offensive",hudRow="core",order=36,trackCooldown=true,buffID=800348,trackDuration=true,sourceTab="Firearms"},
  {name="Freeze Ray",id=806157,category="control",hudRow="utility",order=135,trackCooldown=true,sourceTab="Invention"},
  {name="Mineball",id=706833,category="offensive",hudRow="core",order=48,trackCooldown=true,sourceTab="Firearms"},
  {name="Build: Sentry Turret",id=500239,category="offensive",hudRow="core",order=40,trackCooldown=true,sourceTab="Class"},
  {name="Distracto Shot",id=560470,aliases={"Distracting Shot"},category="control",hudRow="utility",order=120,trackCooldown=true,sourceTab="Class"},
  {name="Reload",id=500237,category="utility",hudRow="utility",order=101,trackCooldown=true,sourceTab="Firearms"},
  {name="Battery Swap",id=805319,category="utility",hudRow="utility",order=104,trackCooldown=true,buffID=805319,trackDuration=true,sourceTab="Invention"},
  {name="Remote Detonation",id=801798,category="utility",hudRow="utility",order=108,trackCooldown=true,sourceTab="Firearms"},
  {name="Deploy Blast Mine",id=801718,category="control",hudRow="utility",order=112,trackCooldown=true,sourceTab="Firearms"},
  {name="Deploy Shrapnel Mine",id=706647,category="control",hudRow="utility",order=114,trackCooldown=true,sourceTab="Firearms"},
  {name="Invisibility Cloak",id=801633,category="defensive",hudRow="utility",order=150,trackCooldown=true,sourceTab="Invention"},
  {name="Arcanoreflector",id=806229,aliases={"Arcano-Reflector"},category="defensive",hudRow="utility",order=154,trackCooldown=true,sourceTab="Invention"},
  {name="Minicopter-Z",id=801626,category="mobility",hudRow="utility",order=158,trackCooldown=true,sourceTab="Mechanics"},
  {name="Nanobot Barrier",id=801709,category="defensive",hudRow="utility",order=160,trackCooldown=true,sourceTab="Invention"},
  {name="Nanobot Cleanser",id=502537,category="dispel",hudRow="utility",order=162,trackCooldown=true,dispel=true,sourceTab="Invention"},
  {name="Anti-Magic Grenades",id=804861,category="defensive",hudRow="utility",order=164,trackCooldown=true,sourceTab="Invention"},
  {name="Basic Intuition",id=504060,category="defensive",hudRow="utility",order=166,trackCooldown=true,sourceTab="Class"},
  {name="Build: Shield Beacon",aliases={"Shield Beacon"},id=801799,category="defensive",hudRow="utility",order=172,trackCooldown=true,activeDuration=15,trackDuration=true,separateAuraTracker=false,sourceTab="Invention"},
  {name="Build: Replenishment Beacon",aliases={"Replenishment Beacon"},id=560750,category="utility",hudRow="utility",order=174,trackCooldown=true,activeDuration=15,trackDuration=true,separateAuraTracker=false,sourceTab="Invention"},
  {name="Sticky Bomb",id=502516,category="debuff",order=410,targetDebuff=true,trackHUD=false,sourceTab="Firearms"},
  {name="Molotov",id=805315,category="debuff",order=420,targetDebuff=true,trackHUD=false,sourceTab="Firearms"},
}
for _,record in ipairs(abilities) do AddOrMerge(record) end

local activeAuras = {
  {name="ZIGGI-6K",id=524839,order=330},
  {name="Quick Scope",id=805663,order=332},
  {name="Pyromania",id=706378,order=334},
  {name="Holstered Cannon",id=300639,order=336},
  {name="The Big One",id=524719,order=338},
  {name="Gizmotronic Rifle",id=504511,order=340},
  {name="Conductor",id=500244,order=342},
  {name="Growth Module",id=805306,order=344},
  {name="Emergency Module",id=805304,order=346},
  {name="Flamethrower",id=801388,order=348},
  {name="Gatling",id=704437,order=350},
  {name="Arclight Adept",id=504526,order=352},
}
for _,aura in ipairs(activeAuras) do
  AddOrMerge({
    name=aura.name,id=aura.id,category="proc",order=aura.order,
    buff=aura.name,buffID=aura.id,auraID=aura.id,
    trackDuration=true,auraTracker=true,trackHUD=false,
    sourceTab="Class",
  })
end

database.tinkerWAAuditRevision=1

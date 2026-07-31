local RUI = RetreatUI
if not RUI or not RUI.HUDWidgets then return end

local W = RUI.HUDWidgets
local module = RUI:RegisterAdvancedClassHUD("Tinker", {
  frameName = "RetreatUITinkerHUD",
  usesPrimaryPower = true,
  supportedLoadouts = {FIREARMS=true,INVENTION=true,MECHANICS=true},

  maxCore = 7,
  coreIconSize = 36,
  coreSpacing = 2,
  coreOrder = {
    "Bomb Toss",
    "Blasting Round",
    "Makeshift Dynamite",
    "Blackpowder Barrage",
    "Overclock Weapon",
    "Activate Mechsuit: Shredder",
    "Supercharge",
    "Rocket Barrage",
    "Cannonball Launcher",
    "Build: Sentry Turret",
    "Build: Scraptron",
    "Build: Battle Turret X-13",
    "Build: ZIGGI-6K",
    "Zap!",
  },
  strictCoreOrder = false,

  maxUtility = 8,
  utilityIconSize = 28,
  utilitySpacing = 2,
  utilityOrder = {
    "Build: Noise Box",
    "Reload",
    "Battery Swap",
    "Remote Detonation",
    "Distracto Shot",
    "Deploy Blast Mine",
    "Deploy Shrapnel Mine",
    "Invisibility Cloak",
    "Arcanoreflector",
    "Nanobot Barrier",
    "Nanobot Cleanser",
    "Anti-Magic Grenades",
    "Minicopter-Z",
    "Build: Shield Beacon",
    "Build: Replenishment Beacon",
    "Rocket Boots",
    "Kinetic Shield",
  },
  strictUtilityOrder = false,

  maxProcs = 6,
  maxTargetDebuffs = 8,
})

if not module then return end

local AMMO_TYPES = {
  [801647] = 4,
  [801651] = 6,
  [801648] = 8,
}
local AMMO_COUNT_ID = 500238
local BIONICS_ID = 680315
local AMMO_SIZE = 21
local AMMO_SPACING = 2

local ammoFrame
local bionicsIcon
local ammoSegments = {}
local beaconTimers = {}
local driver
local elapsed = 0

local function Normalize(value)
  return string.lower(tostring(value or "")):gsub("’", "'"):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ReadPlayerAuras()
  local state={byID={},byName={}}
  if not UnitBuff then return state end
  for index=1,40 do
    local values={UnitBuff("player",index)}
    local name=values[1]
    if not name then break end
    local aura={name=name,icon=values[3],count=tonumber(values[4]) or 0,duration=tonumber(values[6]) or 0,expires=tonumber(values[7]) or 0,spellID=tonumber(values[11])}
    state.byName[Normalize(name)]=aura
    if aura.spellID then state.byID[aura.spellID]=aura end
  end
  return state
end

local function TinkerActive()
  local root=_G.RetreatUITinkerHUD
  return RUI.activeClass=="Tinker" and root and root.IsShown and root:IsShown()
end

local function EnsureAmmoFrame()
  if ammoFrame then return ammoFrame end
  local frame=CreateFrame("Frame","RetreatUITinkerAmmoTracker",UIParent)
  frame:SetSize(1,AMMO_SIZE)
  frame:SetFrameStrata("MEDIUM")
  frame:Hide()
  ammoFrame=frame

  bionicsIcon=W:CreateIcon(frame,AMMO_SIZE)
  bionicsIcon.texture:SetTexture((GetSpellInfo and select(3,GetSpellInfo(BIONICS_ID))) or "Interface\\Icons\\INV_Gizmo_02")
  bionicsIcon:EnableMouse(true)
  bionicsIcon:SetScript("OnEnter",function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self,"ANCHOR_TOP")
    local shown=false
    if GameTooltip.SetSpellByID then shown=pcall(GameTooltip.SetSpellByID,GameTooltip,BIONICS_ID) end
    if not shown then GameTooltip:SetText("Bionics missing",1,1,1) end
    GameTooltip:AddLine("The learned Bionics buff is currently missing.",1,.35,.22,true)
    GameTooltip:Show()
  end)
  bionicsIcon:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
  bionicsIcon:Hide()
  return frame
end

local function EnsureAmmoSegments(maximum)
  EnsureAmmoFrame()
  while #ammoSegments<maximum do
    local segment=W:CreateIcon(ammoFrame,AMMO_SIZE)
    segment.cooldownText:SetText("")
    segment.stackText:SetText("")
    ammoSegments[#ammoSegments+1]=segment
  end
end

local function PositionAmmo(maximum,bionicsShown)
  EnsureAmmoFrame()
  local layout=RUI.layout and RUI.layout.demonfire or {x=0,y=-118}
  local x=tonumber(layout.x) or 0
  local y=(tonumber(layout.y) or -118)+25
  local total=maximum>0 and maximum*AMMO_SIZE+math.max(0,maximum-1)*AMMO_SPACING or 1
  ammoFrame:SetSize(total,AMMO_SIZE)
  ammoFrame:ClearAllPoints()
  ammoFrame:SetPoint("CENTER",UIParent,"CENTER",x,y)
  if ammoFrame.SetScale and RUI.GetHUDScale then ammoFrame:SetScale(RUI:GetHUDScale("demonfire")) end
  for index,segment in ipairs(ammoSegments) do
    segment:ClearAllPoints()
    segment:SetPoint("LEFT",ammoFrame,"LEFT",(index-1)*(AMMO_SIZE+AMMO_SPACING),0)
  end
  if bionicsIcon then
    bionicsIcon:ClearAllPoints()
    bionicsIcon:SetPoint("RIGHT",ammoFrame,"LEFT",-(bionicsShown and 5 or 3),0)
  end
end

local function LearnedBionics()
  if RUI.IsSpellIDLearned and RUI:IsSpellIDLearned(BIONICS_ID) then return true end
  local name=GetSpellInfo and GetSpellInfo(BIONICS_ID)
  return name and RUI.IsSpellLearned and RUI:IsSpellLearned(name) or false
end

local function FindRowIconByName(name)
  local root=_G.RetreatUITinkerHUD
  if not root then return nil end
  local key=Normalize(name)
  for _,row in ipairs({root.coreRow,root.utilityRow}) do
    for _,icon in ipairs(row and row.icons or {}) do
      if icon:IsShown() and icon.definition and Normalize(icon.definition.name)==key then return icon end
    end
  end
  return nil
end

local function UpdateAmmoAndBionics()
  if not TinkerActive() then
    if ammoFrame then ammoFrame:Hide() end
    return
  end
  local auras=ReadPlayerAuras()
  local maximum,typeAura
  for spellID,maxValue in pairs(AMMO_TYPES) do
    if auras.byID[spellID] then maximum=maxValue; typeAura=auras.byID[spellID]; break end
  end
  local countAura=auras.byID[AMMO_COUNT_ID]
  local current=countAura and tonumber(countAura.count) or 0
  if maximum then current=math.max(0,math.min(maximum,current)) end
  local bionicsMissing=LearnedBionics() and not auras.byID[BIONICS_ID] and not auras.byName["bionics"]

  if not maximum then
    if ammoFrame then
      for _,segment in ipairs(ammoSegments) do segment:Hide() end
      if bionicsMissing then
        EnsureAmmoFrame(); PositionAmmo(0,true); bionicsIcon:Show(); ammoFrame:Show()
      else bionicsIcon:Hide(); ammoFrame:Hide() end
    end
    return
  end

  EnsureAmmoSegments(maximum)
  PositionAmmo(maximum,bionicsMissing)
  local texture=(countAura and countAura.icon) or (typeAura and typeAura.icon) or "Interface\\Icons\\INV_Ammo_Bullet_01"
  local theme=RUI:GetTheme()
  for index,segment in ipairs(ammoSegments) do
    if index<=maximum then
      local active=index<=current
      segment.texture:SetTexture(texture)
      if segment.texture.SetDesaturated then segment.texture:SetDesaturated(not active) end
      segment:SetAlpha(active and 1 or .25)
      W:SetBorder(segment,theme.accent2,active and 1 or .30)
      segment:Show()
    else segment:Hide() end
  end
  if bionicsMissing then
    W:SetBorder(bionicsIcon,{1,.18,.12},1)
    W:SetGlow(bionicsIcon,{1,.18,.12},.75)
    bionicsIcon:Show()
  else
    W:SetGlow(bionicsIcon,nil,0)
    bionicsIcon:Hide()
  end
  ammoFrame:Show()

  local reload=FindRowIconByName("Reload")
  if reload then
    if current<=0 then W:SetGlow(reload,theme.accent2,.90) else W:SetGlow(reload,nil,0) end
  end
end

local function UpdateBeaconTimers()
  if not TinkerActive() then return end
  local now=GetTime and GetTime() or 0
  for spellID,state in pairs(beaconTimers) do
    local remaining=math.max(0,(state.expires or 0)-now)
    if remaining<=.05 then beaconTimers[spellID]=nil
    else
      local icon=FindRowIconByName(state.name)
      if icon then
        if icon.cooldownShade then icon.cooldownShade:Hide() end
        if icon.texture and icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
        icon.cooldownText:SetText(W:FormatCooldown(remaining))
        icon.cooldownText:SetTextColor(.72,1,.42,1)
        W:SetBorder(icon,RUI:GetTheme().accent2,1)
      end
    end
  end
end

local function RecordBeaconCast(...)
  local values={...}
  local spellID
  for index=#values,1,-1 do
    local candidate=tonumber(values[index])
    if candidate and candidate>0 then spellID=candidate; break end
  end
  if not spellID then return end
  local database=RUI:GetClassSpellDatabase("Tinker")
  for _,record in ipairs(database and database.spells or {}) do
    if tonumber(record.id)==spellID and tonumber(record.activeDuration) and tonumber(record.activeDuration)>0 then
      beaconTimers[spellID]={name=record.name,expires=(GetTime and GetTime() or 0)+tonumber(record.activeDuration)}
      return
    end
  end
end

local function EnsureDriver()
  if driver then return driver end
  driver=CreateFrame("Frame","RetreatUITinkerSystemsDriver")
  for _,event in ipairs({"PLAYER_ENTERING_WORLD","UNIT_AURA","SPELLS_CHANGED","PLAYER_TALENT_UPDATE","UNIT_SPELLCAST_SUCCEEDED"}) do pcall(driver.RegisterEvent,driver,event) end
  driver:SetScript("OnEvent",function(_,event,unit,...)
    if event=="UNIT_AURA" and unit~="player" then return end
    if event=="UNIT_SPELLCAST_SUCCEEDED" and unit=="player" then RecordBeaconCast(...) end
    UpdateAmmoAndBionics(); UpdateBeaconTimers()
  end)
  driver:SetScript("OnUpdate",function(_,delta)
    elapsed=elapsed+delta
    if elapsed>=.10 then elapsed=0; UpdateAmmoAndBionics(); UpdateBeaconTimers() end
  end)
  driver:Hide()
  return driver
end

local originalActivate=module.activate
function module:activate(...)
  local result=originalActivate(self,...)
  EnsureDriver():Show()
  UpdateAmmoAndBionics(); UpdateBeaconTimers()
  return result
end

local originalDeactivate=module.deactivate
function module:deactivate(...)
  if driver then driver:Hide() end
  if ammoFrame then ammoFrame:Hide() end
  beaconTimers={}
  return originalDeactivate(self,...)
end

local originalRefreshLayout=module.refreshLayout
function module:refreshLayout(...)
  local result=originalRefreshLayout(self,...)
  UpdateAmmoAndBionics()
  return result
end

RUI._tinkerNativeSystemsLoaded=true

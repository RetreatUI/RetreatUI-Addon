local RUI = RetreatUI
if not RUI then return end

local frame
local activePage = "profiles"
local TEX = "Interface\\Buttons\\WHITE8X8"
local BG = {0.020,0.022,0.027,0.99}
local PANEL = {0.040,0.043,0.050,0.98}
local ACCENT = {1.00,0.34,0.10,1}
local TEXT = {0.95,0.95,0.97,1}
local MUTED = {0.58,0.60,0.66,1}
local GOOD = {0.20,0.85,0.55,1}
local BAD = {1.00,0.32,0.28,1}

local PAGES = {
  {key="home", label="Home", hint="Overview"},
  {key="profiles", label="Profiles", hint="Choose your UI"},
  {key="hud", label="HUD", hint="Build WeakAuras"},
  {key="settings", label="Settings", hint="Repair & reload"},
}

local function Font(fs,size,outline)
  if RUI.ApplyFont then RUI:ApplyFont(fs,size or 12,outline or "") else fs:SetFont(STANDARD_TEXT_FONT,size or 12,outline or "") end
end
local function Label(parent,text,size,color)
  local fs=parent:CreateFontString(nil,"OVERLAY"); Font(fs,size or 12); fs:SetText(text or ""); color=color or TEXT
  fs:SetTextColor(color[1],color[2],color[3],color[4] or 1); return fs
end
local function Box(parent,color)
  local f=CreateFrame("Frame",nil,parent); f:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1}); color=color or PANEL
  f:SetBackdropColor(color[1],color[2],color[3],color[4] or 1); f:SetBackdropBorderColor(.14,.15,.18,1); return f
end
local function Button(parent,text,width,callback,primary)
  local b=CreateFrame("Button",nil,parent); b:SetSize(width or 130,30); b:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  b:SetBackdropColor(primary and .12 or .06,primary and .07 or .063,primary and .045 or .072,1)
  b:SetBackdropBorderColor(primary and ACCENT[1] or .22,primary and ACCENT[2] or .23,primary and ACCENT[3] or .27,1)
  b.text=Label(b,text,11,primary and ACCENT or TEXT); b.text:SetPoint("CENTER")
  if callback then b:SetScript("OnClick",callback) end
  return b
end
local function ClearPage()
  if not frame or not frame.content then return end
  for _,child in ipairs({frame.content:GetChildren()}) do child:Hide(); child:SetParent(nil) end
  for _,region in ipairs({frame.content:GetRegions()}) do region:Hide() end
end
local function Header(title,subtitle)
  local t=Label(frame.content,title,25,TEXT); t:SetPoint("TOPLEFT",28,-22)
  local s=Label(frame.content,subtitle,11,MUTED); s:SetPoint("TOPLEFT",t,"BOTTOMLEFT",0,-5)
end
local function SetStatus(text,ok)
  if not frame or not frame.status then return end
  frame.status:SetText(text or "")
  local c=ok==true and GOOD or (ok==false and BAD or MUTED)
  frame.status:SetTextColor(c[1],c[2],c[3],1)
end
local function AddComponent(parent,label,value,y)
  local l=Label(parent,label,11,TEXT); l:SetPoint("TOPLEFT",22,y)
  local v=Label(parent,value,10,GOOD); v:SetPoint("TOPRIGHT",-22,y)
end
local function StyleCard(parent,key,x,width)
  local style=RUI:GetRetreatStyleInfo(key); if not style then return end
  local active=type(RUI.IsRetreatStyleActuallyActive)=="function" and RUI:IsRetreatStyleActuallyActive(key)
  local card=Box(parent,PANEL); card:SetSize(width,390); card:SetPoint("TOPLEFT",x,-112)
  local stripe=card:CreateTexture(nil,"ARTWORK"); stripe:SetTexture(TEX); stripe:SetVertexColor(ACCENT[1],ACCENT[2],ACCENT[3],1); stripe:SetPoint("TOPLEFT"); stripe:SetPoint("TOPRIGHT"); stripe:SetHeight(3)
  local name=Label(card,style.label,22,TEXT); name:SetPoint("TOPLEFT",22,-22)
  local sub=Label(card,style.subtitle,10,ACCENT); sub:SetPoint("TOPLEFT",name,"BOTTOMLEFT",0,-5)
  local desc=Label(card,style.description,11,MUTED); desc:SetPoint("TOPLEFT",sub,"BOTTOMLEFT",0,-22); desc:SetWidth(width-44); desc:SetJustifyH("LEFT"); desc:SetJustifyV("TOP")
  AddComponent(card,"ElvUI","PROFILE",-182); AddComponent(card,"TurboPlates","PROFILE",-210); AddComponent(card,"Details","PROFILE",-238); AddComponent(card,"WeakAuras","YOUR HUD",-266)
  local install=Button(card,active and "Reapply Profile" or "Install Profile",150,function()
    SetStatus("Applying "..style.label.."...",nil)
    local ok,msg=RUI:InstallRetreatStyle(key)
    SetStatus(msg,ok)
    if frame then frame:ShowPage("profiles") end
  end,true); install:SetPoint("BOTTOMLEFT",22,22)
  if active then local a=Label(card,"ACTIVE",9,GOOD); a:SetPoint("BOTTOMRIGHT",-22,31) end
end

local render={}
render.home=function()
  Header("RetreatUI","One installer. Two complete UI profiles. Your HUD stays completely user-built.")
  local box=Box(frame.content,PANEL); box:SetPoint("TOPLEFT",28,-110); box:SetPoint("TOPRIGHT",-28,-110); box:SetHeight(190)
  local style=RUI:GetRetreatStyleInfo(); local t=Label(box,style and style.label or "Choose a UI profile",20,style and GOOD or TEXT); t:SetPoint("TOPLEFT",22,-22)
  local d=Label(box,style and "ElvUI, TurboPlates and Details are installed by the profile. WeakAuras are only created from the HUD page." or "Start by choosing Retreat Focus or Retreat Edge. Then build your own WeakAuras HUD with the slot editor.",11,MUTED); d:SetPoint("TOPLEFT",t,"BOTTOMLEFT",0,-10); d:SetWidth(780); d:SetJustifyH("LEFT")
  local p=Button(box,"Choose Profile",140,function() frame:ShowPage("profiles") end,true); p:SetPoint("BOTTOMLEFT",22,22)
  local h=Button(box,"Build HUD",120,function() frame:ShowPage("hud") end); h:SetPoint("LEFT",p,"RIGHT",10,0)
end
render.profiles=function()
  Header("Profiles","Choose the complete UI style. WeakAuras are never prebuilt or imported by the profile.")
  local w=frame.content:GetWidth(); if w<=0 then w=1000 end
  local gap=18; local cardW=math.floor((w-56-gap)/2)
  StyleCard(frame.content,"focus",28,cardW); StyleCard(frame.content,"edge",28+cardW+gap,cardW)
end
render.hud=function()
  Header("HUD","Search a spell, choose how it should track, then drag it into an exact action-bar style slot.")
  if type(RUI.RenderHUDWorkspace)~="function" then local e=Label(frame.content,"HUD workspace failed to load.",13,BAD); e:SetPoint("TOPLEFT",28,-110); return end
  RUI:RenderHUDWorkspace(frame.content,{status=SetStatus})
end
render.settings=function()
  Header("Settings","Only maintenance tools live here. Legacy installer and legacy HUD editor are retired.")
  local box=Box(frame.content,PANEL); box:SetPoint("TOPLEFT",28,-110); box:SetPoint("TOPRIGHT",-28,-110); box:SetHeight(240)
  local t=Label(box,"Maintenance",20,TEXT); t:SetPoint("TOPLEFT",22,-22)
  local reload=Button(box,"Reload UI",110,function() ReloadUI() end,true); reload:SetPoint("TOPLEFT",22,-70)
  local reapply=Button(box,"Reapply Active Profile",175,function() local ok,msg=RUI:ReapplyRetreatStyle(); SetStatus(msg,ok) end); reapply:SetPoint("LEFT",reload,"RIGHT",10,0)
  local movers=Button(box,"Open ElvUI Movers",155,function()
    if type(E_ToggleOptions)=="function" then E_ToggleOptions() end
    if SlashCmdList and SlashCmdList.ELVUI then pcall(SlashCmdList.ELVUI,"toggle") end
  end); movers:SetPoint("TOPLEFT",22,-112)
  local reset=Button(box,"Clear RetreatUI Choice",170,function() local db=RUI:EnsureDB(); db.profileStyle={}; SetStatus("RetreatUI profile selection cleared. Existing addon profiles were not deleted.",true); frame:ShowPage("profiles") end); reset:SetPoint("LEFT",movers,"RIGHT",10,0)
  local note=Label(box,"HUD positions are moved with Unlock Mode. ElvUI frames remain owned by the selected ElvUI profile and its own mover system.",10,MUTED); note:SetPoint("TOPLEFT",22,-164); note:SetWidth(760); note:SetJustifyH("LEFT")
end

local function WorkspaceSize()
  local sw=(UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1280
  local sh=(UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 800
  return math.min(1280,math.max(900,sw-40)), math.min(800,math.max(620,sh-40))
end
local function Build()
  if frame then return frame end
  frame=CreateFrame("Frame","RetreatUIBeta50Window",UIParent)
  local w,h=WorkspaceSize(); frame:SetSize(w,h); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true); frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart",function(self) if not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end end); frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
  frame:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1}); frame:SetBackdropColor(BG[1],BG[2],BG[3],BG[4]); frame:SetBackdropBorderColor(.13,.14,.17,1)
  frame.sidebar=Box(frame,{0.016,0.018,0.022,1}); frame.sidebar:SetPoint("TOPLEFT",1,-1); frame.sidebar:SetPoint("BOTTOMLEFT",1,1); frame.sidebar:SetWidth(190)
  frame.content=CreateFrame("Frame",nil,frame); frame.content:SetPoint("TOPLEFT",frame.sidebar,"TOPRIGHT",0,0); frame.content:SetPoint("BOTTOMRIGHT",-1,43)
  local logo=Label(frame.sidebar,"RETREATUI",20,TEXT); logo:SetPoint("TOPLEFT",18,-18); local ver=Label(frame.sidebar,"v"..tostring(RUI.version or ""),9,ACCENT); ver:SetPoint("TOPLEFT",logo,"BOTTOMLEFT",0,-3)
  frame.nav={}; local last
  for _,p in ipairs(PAGES) do
    local row=CreateFrame("Button",nil,frame.sidebar); row:SetSize(166,50); if not last then row:SetPoint("TOPLEFT",12,-78) else row:SetPoint("TOPLEFT",last,"BOTTOMLEFT",0,-2) end
    row.bg=row:CreateTexture(nil,"BACKGROUND"); row.bg:SetTexture(TEX); row.bg:SetAllPoints(); row.bg:SetVertexColor(0,0,0,0)
    row.mark=row:CreateTexture(nil,"ARTWORK"); row.mark:SetTexture(TEX); row.mark:SetVertexColor(ACCENT[1],ACCENT[2],ACCENT[3],1); row.mark:SetPoint("TOPLEFT"); row.mark:SetPoint("BOTTOMLEFT"); row.mark:SetWidth(3); row.mark:Hide()
    row.title=Label(row,p.label,11,TEXT); row.title:SetPoint("TOPLEFT",13,-9); row.hint=Label(row,p.hint,9,MUTED); row.hint:SetPoint("TOPLEFT",row.title,"BOTTOMLEFT",0,-2)
    row:SetScript("OnClick",function() frame:ShowPage(p.key) end); frame.nav[p.key]=row; last=row
  end
  local unlock=Button(frame.sidebar,"Unlock HUD Bars",154,function() local ok,msg=RUI:ToggleHUDBarUnlockMode(); SetStatus(msg,ok) end,true); unlock:SetPoint("BOTTOM",0,18)
  frame.footer=CreateFrame("Frame",nil,frame); frame.footer:SetPoint("BOTTOMLEFT",frame.sidebar,"BOTTOMRIGHT",0,1); frame.footer:SetPoint("BOTTOMRIGHT",-1,1); frame.footer:SetHeight(42)
  frame.status=Label(frame.footer,"",9,MUTED); frame.status:SetPoint("LEFT",16,0); frame.status:SetPoint("RIGHT",-130,0); frame.status:SetJustifyH("LEFT")
  local close=Button(frame.footer,"Close",82,function() frame:Hide() end); close:SetPoint("RIGHT",-24,0)
  function frame:ShowPage(key)
    activePage=render[key] and key or "profiles"; ClearPage()
    for k,row in pairs(self.nav) do local active=k==activePage; row.mark:SetShown(active); row.bg:SetVertexColor(active and .07 or 0,active and .072 or 0,active and .085 or 0,active and .94 or 0) end
    render[activePage]()
  end
  frame:Hide(); return frame
end

function RUI:OpenRetreatUI(page)
  Build(); frame:ShowPage(page or activePage); frame:Show(); return true
end
function RUI:ToggleRetreatUI()
  Build(); if frame:IsShown() then frame:Hide() else self:OpenRetreatUI(activePage) end; return true
end
function RUI:ShowInstaller() return self:OpenRetreatUI("profiles") end
function RUI:HideInstaller() if frame then frame:Hide() end end
function RUI:RefreshInstallerTheme() if frame then frame:Hide(); frame=nil end end

RUI._beta50ShellLoaded=true
RUI.beta50ShellSchema=1

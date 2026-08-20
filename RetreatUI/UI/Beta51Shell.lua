local RUI = RetreatUI
if not RUI then return end

local frame
local activePage = "profiles"
local TEX = "Interface\\Buttons\\WHITE8X8"
local BG = {0.018,0.020,0.024,0.99}
local SURFACE = {0.035,0.038,0.045,0.99}
local SURFACE2 = {0.052,0.055,0.064,0.99}
local BORDER = {0.12,0.13,0.15,1}
local ACCENT = {1.00,0.34,0.10,1}
local TEXT = {0.96,0.96,0.98,1}
local MUTED = {0.60,0.62,0.68,1}
local GOOD = {0.20,0.86,0.55,1}
local BAD = {1.00,0.32,0.28,1}

local PAGES = {
  {key="home", label="Home", hint="Overview"},
  {key="profiles", label="Profiles", hint="Choose your UI"},
  {key="hud", label="HUD", hint="Build WeakAuras"},
  {key="settings", label="Settings", hint="Maintenance"},
}

local function Font(fs,size,outline)
  if RUI.ApplyFont then RUI:ApplyFont(fs,size or 12,outline or "")
  else fs:SetFont(STANDARD_TEXT_FONT,size or 12,outline or "") end
end

local function Label(parent,text,size,color)
  local fs=parent:CreateFontString(nil,"OVERLAY")
  Font(fs,size or 12)
  fs:SetText(text or "")
  color=color or TEXT
  fs:SetTextColor(color[1],color[2],color[3],color[4] or 1)
  return fs
end

local function Solid(parent,color,layer)
  local t=parent:CreateTexture(nil,layer or "BACKGROUND")
  t:SetTexture(TEX)
  t:SetVertexColor(color[1],color[2],color[3],color[4] or 1)
  return t
end

local function Box(parent,color)
  local f=CreateFrame("Frame",nil,parent)
  f:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  color=color or SURFACE
  f:SetBackdropColor(color[1],color[2],color[3],color[4] or 1)
  f:SetBackdropBorderColor(BORDER[1],BORDER[2],BORDER[3],BORDER[4])
  return f
end

local function Button(parent,text,width,callback,primary)
  local b=CreateFrame("Button",nil,parent)
  b:SetSize(width or 132,34)
  b:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  b:SetBackdropColor(primary and .13 or .055,primary and .072 or .058,primary and .042 or .066,1)
  b:SetBackdropBorderColor(primary and ACCENT[1] or .19,primary and ACCENT[2] or .20,primary and ACCENT[3] or .23,1)
  b.text=Label(b,text,11,primary and ACCENT or TEXT)
  b.text:SetPoint("CENTER")
  b:SetScript("OnEnter",function(self)
    self:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],1)
    if self.text then self.text:SetTextColor(1,.72,.54,1) end
  end)
  b:SetScript("OnLeave",function(self)
    self:SetBackdropBorderColor(primary and ACCENT[1] or .19,primary and ACCENT[2] or .20,primary and ACCENT[3] or .23,1)
    if self.text then
      local c=primary and ACCENT or TEXT
      self.text:SetTextColor(c[1],c[2],c[3],1)
    end
  end)
  if callback then b:SetScript("OnClick",callback) end
  return b
end

local function ClearPage()
  if not frame or not frame.content then return end
  for _,child in ipairs({frame.content:GetChildren()}) do child:Hide(); child:SetParent(nil) end
  for _,region in ipairs({frame.content:GetRegions()}) do region:Hide() end
end

local function ShowToast(text,ok)
  if not frame or not frame.toast then return end
  local color=ok==false and BAD or (ok==true and GOOD or MUTED)
  frame.toast.text:SetText(text or "")
  frame.toast.text:SetTextColor(color[1],color[2],color[3],1)
  frame.toast:SetBackdropBorderColor(color[1],color[2],color[3],.75)
  frame.toast:Show()
  frame.toast.expires=(GetTime and GetTime() or 0)+4.5
end

local function Header(title,subtitle)
  local t=Label(frame.content,title,27,TEXT)
  t:SetPoint("TOPLEFT",30,-26)
  local s=Label(frame.content,subtitle,11,MUTED)
  s:SetPoint("TOPLEFT",t,"BOTTOMLEFT",0,-6)
  return t,s
end

local function StatusPill(parent,text,color)
  local pill=Box(parent,{0.028,0.030,0.036,1})
  pill:SetSize(76,24)
  local label=Label(pill,text,9,color)
  label:SetPoint("CENTER")
  return pill
end

local function PreviewUnit(parent,x,y,w,h,color)
  local bar=Box(parent,{0.025,0.027,0.032,1})
  bar:SetSize(w,h)
  bar:SetPoint("TOPLEFT",x,y)
  local health=Solid(bar,color or {.35,.20,.18,1},"ARTWORK")
  health:SetPoint("TOPLEFT",2,-2)
  health:SetPoint("BOTTOMRIGHT",-2,2)
  return bar
end

local function StylePreview(parent,key)
  local preview=Box(parent,{0.022,0.024,0.030,1})
  preview:SetPoint("TOPLEFT",18,-92)
  preview:SetPoint("TOPRIGHT",-18,-92)
  preview:SetHeight(126)

  local center=preview:GetWidth()/2
  if key=="focus" then
    PreviewUnit(preview,58,-48,126,22,{.30,.16,.14,1})
    PreviewUnit(preview,230,-48,126,22,{.30,.16,.14,1})
    for i=1,8 do
      local s=Box(preview,{0.055,0.058,0.066,1})
      s:SetSize(20,20)
      s:SetPoint("BOTTOM",preview,"BOTTOM",(i-4.5)*23,16)
    end
  else
    PreviewUnit(preview,34,-36,154,28,{.22,.25,.33,1})
    PreviewUnit(preview,250,-36,154,28,{.22,.25,.33,1})
    PreviewUnit(preview,34,-79,116,18,{.18,.22,.28,1})
    for i=1,10 do
      local s=Box(preview,{0.060,0.064,0.074,1})
      s:SetSize(18,18)
      s:SetPoint("BOTTOM",preview,"BOTTOM",(i-5.5)*21,12)
    end
  end
  return preview
end

local function StyleCard(parent,key,x,width)
  local style=RUI:GetRetreatStyleInfo(key)
  if not style then return end
  local active=type(RUI.IsRetreatStyleActuallyActive)=="function" and RUI:IsRetreatStyleActuallyActive(key)
  local card=Box(parent,SURFACE)
  card:SetSize(width,430)
  card:SetPoint("TOPLEFT",x,-118)

  local stripe=Solid(card,active and GOOD or ACCENT,"ARTWORK")
  stripe:SetPoint("TOPLEFT")
  stripe:SetPoint("TOPRIGHT")
  stripe:SetHeight(3)

  local name=Label(card,style.label,21,TEXT)
  name:SetPoint("TOPLEFT",18,-18)
  local sub=Label(card,style.subtitle,10,ACCENT)
  sub:SetPoint("TOPLEFT",name,"BOTTOMLEFT",0,-4)
  if active then
    local activePill=StatusPill(card,"ACTIVE",GOOD)
    activePill:SetPoint("TOPRIGHT",-18,-18)
  end

  StylePreview(card,key)

  local desc=Label(card,style.description,10,MUTED)
  desc:SetPoint("TOPLEFT",18,-236)
  desc:SetWidth(width-36)
  desc:SetJustifyH("LEFT")
  desc:SetJustifyV("TOP")

  local compTitle=Label(card,"PROFILE INCLUDES",9,MUTED)
  compTitle:SetPoint("TOPLEFT",18,-300)
  local chips={"ElvUI","TurboPlates","Details"}
  local last
  for _,chip in ipairs(chips) do
    local p=StatusPill(card,chip,GOOD)
    p:SetWidth(chip=="TurboPlates" and 92 or 72)
    if not last then p:SetPoint("TOPLEFT",18,-322) else p:SetPoint("LEFT",last,"RIGHT",8,0) end
    last=p
  end
  local wa=StatusPill(card,"HUD: YOURS",MUTED)
  wa:SetWidth(92)
  wa:SetPoint("LEFT",last,"RIGHT",8,0)

  local install=Button(card,active and "Reapply profile" or "Install profile",158,function()
    ShowToast("Applying "..style.label.."...",nil)
    local ok,msg=RUI:InstallRetreatStyle(key)
    ShowToast(msg,ok)
    if frame then frame:ShowPage("profiles") end
  end,true)
  install:SetPoint("BOTTOMLEFT",18,18)

  local openHUD=Button(card,"Open HUD",110,function() frame:ShowPage("hud") end,false)
  openHUD:SetPoint("LEFT",install,"RIGHT",10,0)
end

local render={}

render.home=function()
  Header("RetreatUI","Profiles, HUD construction and layout tools in one place.")
  local hero=Box(frame.content,SURFACE)
  hero:SetPoint("TOPLEFT",30,-112)
  hero:SetPoint("TOPRIGHT",-30,-112)
  hero:SetHeight(205)
  local style=RUI:GetRetreatStyleInfo()
  local eyebrow=Label(hero,"CURRENT SETUP",9,ACCENT)
  eyebrow:SetPoint("TOPLEFT",22,-22)
  local title=Label(hero,style and style.label or "Choose your UI profile",24,TEXT)
  title:SetPoint("TOPLEFT",eyebrow,"BOTTOMLEFT",0,-8)
  local body=Label(hero,style and "Your selected profile controls ElvUI, TurboPlates and Details. Your WeakAuras HUD stays completely user-built." or "Pick a UI profile, then build your own HUD bars by searching spells and dragging them into slots.",12,MUTED)
  body:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-12)
  body:SetWidth(760)
  body:SetJustifyH("LEFT")
  local profiles=Button(hero,"Choose profile",142,function() frame:ShowPage("profiles") end,true)
  profiles:SetPoint("BOTTOMLEFT",22,22)
  local hud=Button(hero,"Build HUD",116,function() frame:ShowPage("hud") end,false)
  hud:SetPoint("LEFT",profiles,"RIGHT",10,0)

  local quick=Label(frame.content,"QUICK ACTIONS",9,MUTED)
  quick:SetPoint("TOPLEFT",30,-350)
  local unlock=Button(frame.content,"Unlock HUD bars",150,function()
    local ok,msg=RUI:ToggleHUDBarUnlockMode()
    ShowToast(msg,ok)
  end,true)
  unlock:SetPoint("TOPLEFT",30,-374)
  local reload=Button(frame.content,"Reload UI",110,function() ReloadUI() end,false)
  reload:SetPoint("LEFT",unlock,"RIGHT",10,0)
end

render.profiles=function()
  Header("Profiles","Choose the complete visual profile. WeakAuras remain separate and user-built.")
  local w=frame.content:GetWidth()
  if w<=0 then w=1000 end
  local gap=16
  local cardW=math.floor((w-60-gap)/2)
  StyleCard(frame.content,"focus",30,cardW)
  StyleCard(frame.content,"edge",30+cardW+gap,cardW)
end

render.hud=function()
  Header("HUD","Search a spell, choose its tracker role, then drag it into a bar slot.")
  if type(RUI.RenderHUDWorkspace)~="function" then
    local e=Label(frame.content,"HUD workspace failed to load.",13,BAD)
    e:SetPoint("TOPLEFT",30,-112)
    return
  end
  RUI:RenderHUDWorkspace(frame.content,{status=ShowToast})
end

render.settings=function()
  Header("Settings","Maintenance and recovery tools only.")
  local section=Box(frame.content,SURFACE)
  section:SetPoint("TOPLEFT",30,-112)
  section:SetPoint("TOPRIGHT",-30,-112)
  section:SetHeight(218)
  local title=Label(section,"Profile maintenance",18,TEXT)
  title:SetPoint("TOPLEFT",20,-20)
  local body=Label(section,"These actions do not change your HUD spell selections unless explicitly stated.",10,MUTED)
  body:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-6)

  local reapply=Button(section,"Reapply active profile",166,function()
    local ok,msg=RUI:ReapplyRetreatStyle()
    ShowToast(msg,ok)
  end,true)
  reapply:SetPoint("TOPLEFT",20,-72)
  local reload=Button(section,"Reload UI",104,function() ReloadUI() end,false)
  reload:SetPoint("LEFT",reapply,"RIGHT",10,0)
  local elv=Button(section,"Open ElvUI",112,function()
    if SlashCmdList and SlashCmdList.ELVUI then pcall(SlashCmdList.ELVUI,"toggle")
    elseif type(E_ToggleOptions)=="function" then E_ToggleOptions() end
  end,false)
  elv:SetPoint("LEFT",reload,"RIGHT",10,0)

  local clear=Button(section,"Clear RetreatUI choice",170,function()
    local db=RUI:EnsureDB(); db.profileStyle={}
    ShowToast("Profile selection cleared. Installed addon profiles remain intact.",true)
    frame:ShowPage("profiles")
  end,false)
  clear:SetPoint("TOPLEFT",20,-122)
end

local function WorkspaceSize()
  local sw=(UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1280
  local sh=(UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 800
  local w=math.min(1180,math.max(940,sw-80))
  local h=math.min(720,math.max(620,sh-80))
  if w>sw-28 then w=math.max(820,sw-28) end
  if h>sh-28 then h=math.max(560,sh-28) end
  return w,h
end

local function Build()
  if frame then return frame end
  frame=CreateFrame("Frame","RetreatUIBeta51Window",UIParent)
  local w,h=WorkspaceSize()
  frame:SetSize(w,h)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart",function(self)
    if not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end
  end)
  frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
  frame:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  frame:SetBackdropColor(BG[1],BG[2],BG[3],BG[4])
  frame:SetBackdropBorderColor(.10,.11,.13,1)

  frame.sidebar=Box(frame,{0.014,0.016,0.020,1})
  frame.sidebar:SetPoint("TOPLEFT",1,-1)
  frame.sidebar:SetPoint("BOTTOMLEFT",1,1)
  frame.sidebar:SetWidth(176)

  frame.top=CreateFrame("Frame",nil,frame)
  frame.top:SetPoint("TOPLEFT",frame.sidebar,"TOPRIGHT",0,-1)
  frame.top:SetPoint("TOPRIGHT",-1,-1)
  frame.top:SetHeight(58)
  local topBG=Solid(frame.top,{0.026,0.028,0.034,1})
  topBG:SetAllPoints()
  local topLine=Solid(frame.top,{0.10,0.11,0.13,1},"ARTWORK")
  topLine:SetPoint("BOTTOMLEFT")
  topLine:SetPoint("BOTTOMRIGHT")
  topLine:SetHeight(1)

  frame.content=CreateFrame("Frame",nil,frame)
  frame.content:SetPoint("TOPLEFT",frame.sidebar,"TOPRIGHT",0,-58)
  frame.content:SetPoint("BOTTOMRIGHT",-1,1)

  local logo=Label(frame.sidebar,"RETREATUI",19,TEXT)
  logo:SetPoint("TOPLEFT",18,-18)
  local ver=Label(frame.sidebar,"v"..tostring(RUI.version or ""),9,ACCENT)
  ver:SetPoint("TOPLEFT",logo,"BOTTOMLEFT",0,-3)
  local brandLine=Solid(frame.sidebar,{0.10,0.11,0.13,1},"ARTWORK")
  brandLine:SetPoint("TOPLEFT",14,-64)
  brandLine:SetPoint("TOPRIGHT",-14,-64)
  brandLine:SetHeight(1)

  local topTitle=Label(frame.top,"RetreatUI",14,TEXT)
  topTitle:SetPoint("LEFT",22,0)
  local close=Button(frame.top,"×",36,function() frame:Hide() end,false)
  close:SetPoint("RIGHT",-12,0)
  close.text:SetFont(STANDARD_TEXT_FONT,18,"")

  frame.nav={}
  local last
  for _,p in ipairs(PAGES) do
    local row=CreateFrame("Button",nil,frame.sidebar)
    row:SetSize(152,52)
    if not last then row:SetPoint("TOPLEFT",12,-86)
    else row:SetPoint("TOPLEFT",last,"BOTTOMLEFT",0,-3) end
    row.bg=Solid(row,{0,0,0,0})
    row.bg:SetAllPoints()
    row.mark=Solid(row,ACCENT,"ARTWORK")
    row.mark:SetPoint("TOPLEFT")
    row.mark:SetPoint("BOTTOMLEFT")
    row.mark:SetWidth(3)
    row.mark:Hide()
    row.title=Label(row,p.label,12,TEXT)
    row.title:SetPoint("TOPLEFT",14,-9)
    row.hint=Label(row,p.hint,9,MUTED)
    row.hint:SetPoint("TOPLEFT",row.title,"BOTTOMLEFT",0,-2)
    row:SetScript("OnEnter",function(self)
      if self.pageKey~=activePage then self.bg:SetVertexColor(.045,.048,.056,.75) end
    end)
    row:SetScript("OnLeave",function(self)
      if self.pageKey~=activePage then self.bg:SetVertexColor(0,0,0,0) end
    end)
    row.pageKey=p.key
    row:SetScript("OnClick",function() frame:ShowPage(p.key) end)
    frame.nav[p.key]=row
    last=row
  end

  local unlock=Button(frame.sidebar,"Unlock HUD bars",146,function()
    local ok,msg=RUI:ToggleHUDBarUnlockMode()
    ShowToast(msg,ok)
  end,true)
  unlock:SetPoint("BOTTOM",0,18)

  frame.toast=Box(frame,{0.020,0.022,0.027,.98})
  frame.toast:SetSize(430,44)
  frame.toast:SetPoint("BOTTOMRIGHT",-18,18)
  frame.toast:SetFrameStrata("TOOLTIP")
  frame.toast.text=Label(frame.toast,"",10,MUTED)
  frame.toast.text:SetPoint("LEFT",14,0)
  frame.toast.text:SetPoint("RIGHT",-14,0)
  frame.toast.text:SetJustifyH("LEFT")
  frame.toast:SetScript("OnUpdate",function(self)
    if self.expires and GetTime and GetTime()>self.expires then self:Hide(); self.expires=nil end
  end)
  frame.toast:Hide()

  function frame:ShowPage(key)
    activePage=render[key] and key or "profiles"
    ClearPage()
    for k,row in pairs(self.nav) do
      local active=k==activePage
      row.mark:SetShown(active)
      row.bg:SetVertexColor(active and .055 or 0,active and .058 or 0,active and .068 or 0,active and .96 or 0)
      row.title:SetTextColor(active and 1 or TEXT[1],active and .72 or TEXT[2],active and .54 or TEXT[3],1)
    end
    render[activePage]()
  end

  frame:Hide()
  return frame
end

function RUI:OpenRetreatUI(page)
  Build()
  frame:ShowPage(page or activePage)
  frame:Show()
  return true
end

function RUI:ToggleRetreatUI()
  Build()
  if frame:IsShown() then frame:Hide() else self:OpenRetreatUI(activePage) end
  return true
end

function RUI:ShowInstaller() return self:OpenRetreatUI("profiles") end
function RUI:HideInstaller() if frame then frame:Hide() end end
function RUI:RefreshInstallerTheme() if frame then frame:Hide(); frame=nil end end

RUI._beta51ShellLoaded=true
RUI.beta51ShellSchema=1

local RUI = RetreatUI
if not RUI then return end

local shell
local activePage = "profiles"
local TEX="Interface\\Buttons\\WHITE8X8"
local BG={0.025,0.027,0.032,0.985}
local PANEL={0.045,0.048,0.056,0.98}
local ACCENT={1.00,0.34,0.10,1}
local TEXT={0.94,0.94,0.96,1}
local MUTED={0.58,0.60,0.66,1}
local GOOD={0.20,0.85,0.55,1}
local BAD={1.00,0.32,0.28,1}

local PAGES={
  {key="home",label="Home",hint="Overview"},
  {key="profiles",label="Profiles",hint="Choose your UI"},
  {key="hud",label="HUD",hint="Build WeakAuras"},
  {key="unitframes",label="Unit Frames",hint="ElvUI layout"},
  {key="nameplates",label="Nameplates",hint="TurboPlates"},
  {key="details",label="Damage Meter",hint="Details"},
  {key="settings",label="Settings",hint="Repair & reload"},
}

local function Solid(parent,color,layer)
  local t=parent:CreateTexture(nil,layer or "BACKGROUND"); t:SetTexture(TEX); t:SetVertexColor(color[1],color[2],color[3],color[4] or 1); return t
end
local function Font(fs,size,outline)
  if RUI.ApplyFont then RUI:ApplyFont(fs,size or 12,outline or "") else fs:SetFont(STANDARD_TEXT_FONT,size or 12,outline or "") end
end
local function Label(parent,text,size,color)
  local fs=parent:CreateFontString(nil,"OVERLAY"); Font(fs,size or 12); fs:SetText(text or ""); color=color or TEXT
  fs:SetTextColor(color[1],color[2],color[3],color[4] or 1); return fs
end
local function FrameBox(parent,color)
  local f=CreateFrame("Frame",nil,parent); f:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1}); color=color or PANEL
  f:SetBackdropColor(color[1],color[2],color[3],color[4] or 1); f:SetBackdropBorderColor(.14,.15,.18,1); return f
end
local function Button(parent,text,width,callback,primary)
  local b=CreateFrame("Button",nil,parent); b:SetSize(width or 130,30); b:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  b:SetBackdropColor(primary and .12 or .065,primary and .07 or .068,primary and .045 or .078,1)
  b:SetBackdropBorderColor(primary and ACCENT[1] or .22,primary and ACCENT[2] or .23,primary and ACCENT[3] or .27,1)
  b.text=Label(b,text,11,primary and ACCENT or TEXT); b.text:SetPoint("CENTER")
  b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],1) end)
  b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(primary and ACCENT[1] or .22,primary and ACCENT[2] or .23,primary and ACCENT[3] or .27,1) end)
  b:SetScript("OnClick",callback); return b
end
local function ClearPage()
  if not shell or not shell.content then return end
  for _,child in ipairs({shell.content:GetChildren()}) do child:Hide(); child:SetParent(nil) end
  for _,region in ipairs({shell.content:GetRegions()}) do region:Hide() end
end
local function Header(title,subtitle)
  local titleText=Label(shell.content,title,25,TEXT); titleText:SetPoint("TOPLEFT",28,-22)
  local sub=Label(shell.content,subtitle,11,MUTED); sub:SetPoint("TOPLEFT",titleText,"BOTTOMLEFT",0,-5); return titleText,sub
end
local function SetStatus(text,ok)
  if not shell or not shell.footerStatus then return end
  shell.footerStatus:SetText(text or ""); local color=ok==true and GOOD or (ok==false and BAD or MUTED)
  shell.footerStatus:SetTextColor(color[1],color[2],color[3],1)
end
local function AddComponentLine(parent,anchor,label,value)
  local left=Label(parent,label,11,TEXT); if anchor then left:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-14) else left:SetPoint("TOPLEFT",22,-180) end
  local right=Label(parent,value,10,GOOD); right:SetPoint("RIGHT",parent,"RIGHT",-22,0); right:SetPoint("CENTER",left,"CENTER",0,0); return left
end

local render={}

local function StyleCard(parent,styleKey,x,width)
  local style=RUI:GetRetreatStyleInfo(styleKey); if not style then return end
  local current=RUI:GetRetreatStyleKey()==styleKey
  local card=FrameBox(parent,PANEL); card:SetSize(width,390); card:SetPoint("TOPLEFT",x,-112)
  local stripe=Solid(card,ACCENT,"ARTWORK"); stripe:SetPoint("TOPLEFT"); stripe:SetPoint("TOPRIGHT"); stripe:SetHeight(3)
  local name=Label(card,style.label,22,TEXT); name:SetPoint("TOPLEFT",22,-22)
  local sub=Label(card,style.subtitle,10,ACCENT); sub:SetPoint("TOPLEFT",name,"BOTTOMLEFT",0,-5)
  local desc=Label(card,style.description,11,MUTED); desc:SetPoint("TOPLEFT",sub,"BOTTOMLEFT",0,-22); desc:SetWidth(width-44); desc:SetJustifyH("LEFT"); desc:SetJustifyV("TOP")
  local l1=AddComponentLine(card,nil,"ElvUI","PROFILE"); local l2=AddComponentLine(card,l1,"TurboPlates","PROFILE"); local l3=AddComponentLine(card,l2,"Details","PROFILE"); AddComponentLine(card,l3,"WeakAuras","YOUR HUD")
  local install=Button(card,current and "Reapply Profile" or "Install Profile",150,function()
    SetStatus("Applying "..style.label.."...",nil); local ok,msg=RUI:InstallRetreatStyle(styleKey); SetStatus(msg,ok); if shell then shell:RefreshPage() end
  end,true); install:SetPoint("BOTTOMLEFT",22,22)
  if current then local active=Label(card,"ACTIVE",9,GOOD); active:SetPoint("BOTTOMRIGHT",-22,31) end
end

render.home=function()
  Header("RetreatUI","One workspace for profiles, HUD construction, movers and maintenance.")
  local box=FrameBox(shell.content,PANEL); box:SetPoint("TOPLEFT",28,-110); box:SetPoint("TOPRIGHT",-28,-110); box:SetHeight(160)
  local style=RUI:GetRetreatStyleInfo(); local title=Label(box,style and style.label or "No UI profile selected",20,style and GOOD or TEXT); title:SetPoint("TOPLEFT",22,-22)
  local desc=Label(box,style and "Your ElvUI, TurboPlates and Details profile is separate from your custom WeakAuras HUD." or "Choose a RetreatUI profile first, then build your HUD exactly the way you want it.",11,MUTED)
  desc:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-10); desc:SetWidth(760); desc:SetJustifyH("LEFT")
  local p=Button(box,"Choose Profile",140,function() shell:ShowPage("profiles") end,true); p:SetPoint("BOTTOMLEFT",22,22)
  local h=Button(box,"Open HUD Builder",150,function() shell:ShowPage("hud") end); h:SetPoint("LEFT",p,"RIGHT",10,0)
end

render.profiles=function()
  Header("Profiles","Choose the complete UI style. WeakAuras remain entirely user-built.")
  local contentWidth=shell.content:GetWidth(); if contentWidth<=0 then contentWidth=1080 end
  local gap=18; local width=math.floor((contentWidth-56-gap)/2)
  StyleCard(shell.content,"focus",28,width); StyleCard(shell.content,"edge",28+width+gap,width)
  local note=Label(shell.content,"RetreatUI-owned profile names only. Source package branding is never exposed in the installed UI.",9,MUTED); note:SetPoint("BOTTOMLEFT",28,24)
end

render.hud=function()
  Header("HUD","Search a spell, choose how it should track, then drag it into an exact action-bar style slot.")
  if type(RUI.RenderHUDWorkspace)~="function" then
    local missing=Label(shell.content,"HUD workspace did not finish loading. Reload the UI.",13,BAD); missing:SetPoint("TOPLEFT",28,-110); return
  end
  RUI:RenderHUDWorkspace(shell.content,{status=SetStatus})
end

render.unitframes=function()
  Header("Unit Frames","The selected RetreatUI profile owns ElvUI. Unlock Mode controls placement.")
  local box=FrameBox(shell.content,PANEL); box:SetPoint("TOPLEFT",28,-110); box:SetPoint("TOPRIGHT",-28,-110); box:SetHeight(190)
  local title=Label(box,"ElvUI layout",20,TEXT); title:SetPoint("TOPLEFT",22,-22)
  local desc=Label(box,"Reapply the selected RetreatUI profile for the baseline layout, or use Unlock Mode to move managed unit frames without touching your HUD spell configuration.",11,MUTED)
  desc:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-10); desc:SetWidth(780); desc:SetJustifyH("LEFT")
  local unlock=Button(box,"Unlock Frames",140,function() if RUI.OpenHUDEditor then RUI:OpenHUDEditor() end end,true); unlock:SetPoint("BOTTOMLEFT",22,22)
  local elv=Button(box,"Open ElvUI",120,function() if SlashCmdList and SlashCmdList.ELVUI then SlashCmdList.ELVUI() elseif E_ToggleOptions then E_ToggleOptions() end end); elv:SetPoint("LEFT",unlock,"RIGHT",10,0)
end

render.nameplates=function()
  Header("Nameplates","TurboPlates uses the visual density of your selected RetreatUI profile.")
  local box=FrameBox(shell.content,PANEL); box:SetPoint("TOPLEFT",28,-110); box:SetPoint("TOPRIGHT",-28,-110); box:SetHeight(190)
  local style=RUI:GetRetreatStyleInfo(); local title=Label(box,style and (style.label.." / TurboPlates") or "Choose a profile first",20,TEXT); title:SetPoint("TOPLEFT",22,-22)
  local desc=Label(box,"NPC ability tracking stays RetreatUI-managed. This page only reapplies the selected visual profile.",11,MUTED); desc:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-10)
  local apply=Button(box,"Reapply Nameplates",160,function() local key=RUI:GetRetreatStyleKey(); if not key then SetStatus("Choose a profile first",false); return end local ok,msg=RUI:InstallRetreatStyleTurboPlates(key); SetStatus(msg,ok) end,true); apply:SetPoint("BOTTOMLEFT",22,22)
end

render.details=function()
  Header("Damage Meter","Details follows the selected RetreatUI style and remains independent from the HUD.")
  local box=FrameBox(shell.content,PANEL); box:SetPoint("TOPLEFT",28,-110); box:SetPoint("TOPRIGHT",-28,-110); box:SetHeight(190)
  local style=RUI:GetRetreatStyleInfo(); local title=Label(box,style and (style.label.." / Details") or "Choose a profile first",20,TEXT); title:SetPoint("TOPLEFT",22,-22)
  local desc=Label(box,"Reapply only the Details profile without touching ElvUI, TurboPlates or your WeakAuras HUD.",11,MUTED); desc:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-10)
  local apply=Button(box,"Reapply Details",140,function() local key=RUI:GetRetreatStyleKey(); if not key then SetStatus("Choose a profile first",false); return end local ok,msg=RUI:InstallRetreatStyleDetails(key,RUI:GetRetreatStyleResolution()); SetStatus(msg,ok) end,true); apply:SetPoint("BOTTOMLEFT",22,22)
end

render.settings=function()
  Header("Settings","Profile maintenance, reload and safe repair tools.")
  local box=FrameBox(shell.content,PANEL); box:SetPoint("TOPLEFT",28,-110); box:SetPoint("TOPRIGHT",-28,-110); box:SetHeight(230)
  local title=Label(box,"Profile maintenance",20,TEXT); title:SetPoint("TOPLEFT",22,-22)
  local reapply=Button(box,"Reapply Full Profile",170,function() local ok,msg=RUI:ReapplyRetreatStyle(); SetStatus(msg,ok) end,true); reapply:SetPoint("TOPLEFT",22,-68)
  local reload=Button(box,"Reload UI",110,function() ReloadUI() end); reload:SetPoint("LEFT",reapply,"RIGHT",10,0)
  local clear=Button(box,"Clear Profile Selection",165,function() local db=RUI:EnsureDB(); db.profileStyle={}; SetStatus("Profile selection cleared. Installed addon profiles were not deleted.",true); shell:RefreshPage() end); clear:SetPoint("TOPLEFT",22,-114)
  local note=Label(box,"Clearing the selection does not erase installed ElvUI, TurboPlates or Details settings.",10,MUTED); note:SetPoint("TOPLEFT",clear,"BOTTOMLEFT",0,-10)
end

local function WorkspaceSize()
  local sw=(UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1280
  local sh=(UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 800
  local w=math.min(1280,math.max(820,sw-50)); local h=math.min(800,math.max(600,sh-50))
  if w>sw-20 then w=math.max(760,sw-20) end; if h>sh-20 then h=math.max(560,sh-20) end
  return w,h
end

local function BuildShell()
  if shell then return shell end
  shell=CreateFrame("Frame","RetreatUIMainWindow",UIParent)
  local w,h=WorkspaceSize(); shell:SetSize(w,h); shell:SetPoint("CENTER"); shell:SetFrameStrata("DIALOG"); shell:SetClampedToScreen(true)
  shell:SetMovable(true); shell:EnableMouse(true); shell:RegisterForDrag("LeftButton"); shell:SetResizable(true)
  if shell.SetMinResize then shell:SetMinResize(math.min(920,w),math.min(620,h)) end
  if shell.SetMaxResize then shell:SetMaxResize(math.max(w,1600),math.max(h,1000)) end
  shell:SetScript("OnDragStart",function(self) if not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end end)
  shell:SetScript("OnDragStop",shell.StopMovingOrSizing)
  shell:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1}); shell:SetBackdropColor(BG[1],BG[2],BG[3],BG[4]); shell:SetBackdropBorderColor(.13,.14,.17,1)

  shell.sidebar=FrameBox(shell,{0.018,0.020,0.024,1}); shell.sidebar:SetPoint("TOPLEFT",1,-1); shell.sidebar:SetPoint("BOTTOMLEFT",1,1); shell.sidebar:SetWidth(190)
  shell.content=CreateFrame("Frame",nil,shell); shell.content:SetPoint("TOPLEFT",shell.sidebar,"TOPRIGHT",0,0); shell.content:SetPoint("BOTTOMRIGHT",-1,43)
  local logo=Label(shell.sidebar,"RETREATUI",20,TEXT); logo:SetPoint("TOPLEFT",18,-18)
  local ver=Label(shell.sidebar,"v"..tostring(RUI.version or ""),9,ACCENT); ver:SetPoint("TOPLEFT",logo,"BOTTOMLEFT",0,-3)
  local divider=Solid(shell.sidebar,{.12,.13,.16,1},"ARTWORK"); divider:SetPoint("TOPLEFT",14,-62); divider:SetPoint("TOPRIGHT",-14,-62); divider:SetHeight(1)

  shell.nav={}; local last
  for _,page in ipairs(PAGES) do
    local row=CreateFrame("Button",nil,shell.sidebar); row:SetSize(166,50)
    if not last then row:SetPoint("TOPLEFT",12,-78) else row:SetPoint("TOPLEFT",last,"BOTTOMLEFT",0,-2) end
    row.bg=Solid(row,{0,0,0,0}); row.bg:SetAllPoints(); row.mark=Solid(row,ACCENT,"ARTWORK"); row.mark:SetPoint("TOPLEFT"); row.mark:SetPoint("BOTTOMLEFT"); row.mark:SetWidth(3); row.mark:Hide()
    row.title=Label(row,page.label,11,TEXT); row.title:SetPoint("TOPLEFT",13,-9); row.hint=Label(row,page.hint,9,MUTED); row.hint:SetPoint("TOPLEFT",row.title,"BOTTOMLEFT",0,-2)
    row:SetScript("OnClick",function() shell:ShowPage(page.key) end); shell.nav[page.key]=row; last=row
  end
  local unlock=Button(shell.sidebar,"Unlock Mode",154,function() if RUI.OpenHUDEditor then RUI:OpenHUDEditor() end end,true); unlock:SetPoint("BOTTOM",0,18)

  shell.footer=CreateFrame("Frame",nil,shell); shell.footer:SetPoint("BOTTOMLEFT",shell.sidebar,"BOTTOMRIGHT",0,1); shell.footer:SetPoint("BOTTOMRIGHT",-1,1); shell.footer:SetHeight(42)
  local footerBg=Solid(shell.footer,{0.028,0.030,0.036,1}); footerBg:SetAllPoints(); shell.footerStatus=Label(shell.footer,"",9,MUTED); shell.footerStatus:SetPoint("LEFT",16,0); shell.footerStatus:SetPoint("RIGHT",-190,0); shell.footerStatus:SetJustifyH("LEFT")
  local close=Button(shell.footer,"Close",82,function() shell:Hide() end); close:SetPoint("RIGHT",-32,0)

  local grip=CreateFrame("Button",nil,shell); grip:SetSize(20,20); grip:SetPoint("BOTTOMRIGHT",-2,2); grip:SetFrameLevel(shell:GetFrameLevel()+10)
  local g1=Solid(grip,{.34,.35,.40,1},"ARTWORK"); g1:SetSize(10,2); g1:SetPoint("BOTTOMRIGHT",-2,4); local g2=Solid(grip,{.34,.35,.40,1},"ARTWORK"); g2:SetSize(6,2); g2:SetPoint("BOTTOMRIGHT",-2,8)
  grip:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" and not (InCombatLockdown and InCombatLockdown()) then shell:StartSizing("BOTTOMRIGHT") end end)
  grip:SetScript("OnMouseUp",function() shell:StopMovingOrSizing(); if shell.RefreshPage then shell:RefreshPage() end end)

  function shell:ShowPage(key)
    activePage=render[key] and key or "profiles"
    for pageKey,row in pairs(self.nav) do
      local active=pageKey==activePage; row.mark:SetShown(active); row.bg:SetVertexColor(active and .07 or 0,active and .072 or 0,active and .085 or 0,active and 1 or 0)
      row.title:SetTextColor(active and ACCENT[1] or TEXT[1],active and ACCENT[2] or TEXT[2],active and ACCENT[3] or TEXT[3],1)
    end
    ClearPage(); render[activePage]()
  end
  function shell:RefreshPage() self:ShowPage(activePage) end
  shell:SetScript("OnSizeChanged",function(self) if self:IsShown() and self._sizeReady then self._sizeSerial=(self._sizeSerial or 0)+1; local serial=self._sizeSerial; if RUI.After then RUI:After(.08,function() if shell and shell._sizeSerial==serial then shell:RefreshPage() end end) end end end)
  shell._sizeReady=true; shell:Hide(); return shell
end

function RUI:OpenRetreatUI(pageKey)
  BuildShell(); shell:ShowPage(pageKey or activePage or "profiles"); shell:Show(); return true
end
function RUI:ToggleRetreatUI()
  BuildShell(); if shell:IsShown() then shell:Hide() else self:OpenRetreatUI(activePage) end; return true
end
function RUI:ShowInstaller() return self:OpenRetreatUI("profiles") end
function RUI:HideInstaller() if shell then shell:Hide() end end
function RUI:RefreshInstallerTheme() if shell then shell:Hide(); shell=nil end end

RUI._retreatShellLoaded=true
RUI.retreatShellSchema=2

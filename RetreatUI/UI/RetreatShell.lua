local RUI = RetreatUI
if not RUI then return end

local shell
local activePage = "profiles"
local TEX = "Interface\\Buttons\\WHITE8X8"
local BG = {0.025,0.027,0.032,0.985}
local PANEL = {0.045,0.048,0.056,0.98}
local PANEL2 = {0.065,0.068,0.078,0.98}
local ACCENT = {1.00,0.34,0.10,1}
local TEXT = {0.94,0.94,0.96,1}
local MUTED = {0.58,0.60,0.66,1}
local GOOD = {0.20,0.85,0.55,1}
local BAD = {1.00,0.32,0.28,1}

local PAGES = {
  {key="home", label="Home", hint="Overview"},
  {key="profiles", label="Profiles", hint="Choose your UI"},
  {key="hud", label="HUD", hint="Build WeakAuras"},
  {key="unitframes", label="Unit Frames", hint="ElvUI layout"},
  {key="nameplates", label="Nameplates", hint="TurboPlates"},
  {key="details", label="Damage Meter", hint="Details"},
  {key="settings", label="Settings", hint="Repair & reload"},
}

local function Solid(parent, color, layer)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetTexture(TEX); t:SetVertexColor(color[1],color[2],color[3],color[4] or 1)
  return t
end

local function Font(fs, size, outline)
  if RUI.ApplyFont then RUI:ApplyFont(fs, size or 12, outline or "")
  else fs:SetFont(STANDARD_TEXT_FONT, size or 12, outline or "") end
end

local function Label(parent, text, size, color)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  Font(fs, size or 12)
  fs:SetText(text or "")
  color = color or TEXT
  fs:SetTextColor(color[1],color[2],color[3],color[4] or 1)
  return fs
end

local function FrameBox(parent, color)
  local f = CreateFrame("Frame", nil, parent)
  f:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  color = color or PANEL
  f:SetBackdropColor(color[1],color[2],color[3],color[4] or 1)
  f:SetBackdropBorderColor(.14,.15,.18,1)
  return f
end

local function Button(parent, text, width, callback, primary)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 130, 30)
  b:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  b:SetBackdropColor(primary and .12 or .065, primary and .07 or .068, primary and .045 or .078, 1)
  b:SetBackdropBorderColor(primary and ACCENT[1] or .22, primary and ACCENT[2] or .23, primary and ACCENT[3] or .27, 1)
  b.text = Label(b, text, 11, primary and ACCENT or TEXT); b.text:SetPoint("CENTER")
  b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],1) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(primary and ACCENT[1] or .22, primary and ACCENT[2] or .23, primary and ACCENT[3] or .27,1) end)
  b:SetScript("OnClick", callback)
  return b
end

local function ClearPage()
  if not shell or not shell.content then return end
  for _, child in ipairs({shell.content:GetChildren()}) do child:Hide(); child:SetParent(nil) end
  for _, region in ipairs({shell.content:GetRegions()}) do region:Hide() end
end

local function Header(title, subtitle)
  local titleText = Label(shell.content, title, 24, TEXT)
  titleText:SetPoint("TOPLEFT", 28, -24)
  local sub = Label(shell.content, subtitle, 11, MUTED)
  sub:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -5)
  return titleText, sub
end

local function SetStatus(text, ok)
  if not shell or not shell.footerStatus then return end
  shell.footerStatus:SetText(text or "")
  local color = ok == true and GOOD or (ok == false and BAD or MUTED)
  shell.footerStatus:SetTextColor(color[1],color[2],color[3],1)
end

local function AddComponentLine(parent, anchor, label, value, ok)
  local left = Label(parent, label, 11, TEXT)
  if anchor then left:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12) else left:SetPoint("TOPLEFT", 18, -18) end
  local right = Label(parent, value, 10, ok == false and BAD or GOOD)
  right:SetPoint("RIGHT", parent, "RIGHT", -18, 0); right:SetPoint("CENTER", left, "CENTER", 0, 0)
  return left
end

local function StyleCard(parent, styleKey, x)
  local style = RUI:GetRetreatStyleInfo(styleKey)
  local card = FrameBox(parent, PANEL)
  card:SetSize(290, 330); card:SetPoint("TOPLEFT", x, -116)
  local stripe = Solid(card, ACCENT, "ARTWORK"); stripe:SetPoint("TOPLEFT"); stripe:SetPoint("TOPRIGHT"); stripe:SetHeight(3)
  local name = Label(card, style.label, 20, TEXT); name:SetPoint("TOPLEFT", 18, -22)
  local sub = Label(card, style.subtitle, 10, ACCENT); sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -5)
  local desc = Label(card, style.description, 11, MUTED); desc:SetWidth(252); desc:SetJustifyH("LEFT"); desc:SetJustifyV("TOP"); desc:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -18)
  local line1 = AddComponentLine(card, nil, "ElvUI", "PROFILE", true); line1:ClearAllPoints(); line1:SetPoint("TOPLEFT", 18, -152)
  local line2 = AddComponentLine(card, line1, "TurboPlates", "PROFILE", true)
  local line3 = AddComponentLine(card, line2, "Details", "PROFILE", true)
  AddComponentLine(card, line3, "WeakAuras", "YOUR HUD", true)
  local current = RUI:GetRetreatStyleKey() == styleKey
  local install = Button(card, current and "Reapply" or "Install Profile", 140, function()
    SetStatus("Applying " .. style.label .. "...", nil)
    local ok, message = RUI:InstallRetreatStyle(styleKey)
    SetStatus(message, ok)
    if shell and shell.RefreshPage then shell:RefreshPage() end
  end, true)
  install:SetPoint("BOTTOMLEFT", 18, 18)
  if current then local selected = Label(card, "ACTIVE", 9, GOOD); selected:SetPoint("BOTTOMRIGHT", -18, 26) end
  return card
end

local render = {}

render.home = function()
  Header("RetreatUI", "Choose a complete UI profile, then build only the WeakAuras you want.")
  local style = RUI:GetRetreatStyleInfo()
  local box = FrameBox(shell.content, PANEL); box:SetPoint("TOPLEFT", 28, -100); box:SetSize(610, 120)
  local title = Label(box, style and style.label or "No UI profile selected", 18, style and GOOD or TEXT); title:SetPoint("TOPLEFT", 18, -18)
  local desc = Label(box, style and "Your ElvUI, TurboPlates and Details style is installed independently from the HUD." or "Open Profiles and choose Retreat Focus or Retreat Edge.", 11, MUTED)
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8); desc:SetWidth(570); desc:SetJustifyH("LEFT")
  local profiles = Button(shell.content, "Choose Profile", 135, function() shell:ShowPage("profiles") end, true); profiles:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -18)
  local hud = Button(shell.content, "Build HUD", 120, function() shell:ShowPage("hud") end, false); hud:SetPoint("LEFT", profiles, "RIGHT", 10, 0)
end

render.profiles = function()
  Header("Profiles", "One click installs ElvUI + TurboPlates + Details. WeakAuras stay yours.")
  StyleCard(shell.content, "focus", 28)
  StyleCard(shell.content, "edge", 336)
  local note = Label(shell.content, "Profile names are RetreatUI-owned. Source package names are not exposed in the installed UI.", 9, MUTED)
  note:SetPoint("BOTTOMLEFT", 28, 22)
end

render.hud = function()
  Header("HUD", "Build your own WeakAuras from the CoA spell audit — no prebuilt class pack is installed.")
  local box = FrameBox(shell.content, PANEL); box:SetPoint("TOPLEFT", 28, -105); box:SetSize(610, 155)
  local t = Label(box, "Your HUD, your spells", 18, TEXT); t:SetPoint("TOPLEFT", 18, -18)
  local d = Label(box, "Choose a learned CoA ability. RetreatUI keeps cast/cooldown IDs separate from the real buff or debuff aura ID behind the scenes. The public HUD builder outputs native WeakAuras only.", 11, MUTED)
  d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -9); d:SetWidth(570); d:SetJustifyH("LEFT")
  local add = Button(box, "Add HUD Element", 145, function() if RUI.OpenSimpleHUDBuilder then RUI:OpenSimpleHUDBuilder() end end, true); add:SetPoint("BOTTOMLEFT", 18, 18)
  local unlock = Button(box, "Unlock HUD", 120, function() if RUI.OpenHUDEditor then RUI:OpenHUDEditor() end end); unlock:SetPoint("LEFT", add, "RIGHT", 10, 0)
  local info = FrameBox(shell.content, PANEL2); info:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -18); info:SetSize(610, 145)
  local it = Label(info, "Unlock Mode", 16, TEXT); it:SetPoint("TOPLEFT", 18, -16)
  local id = Label(info, "Drag HUD groups and managed ElvUI unit frames, use the mouse wheel to scale, then Save. This is the first beta.45 mover layer; it will be folded further into this shell as the HUD editor is polished.", 11, MUTED)
  id:SetPoint("TOPLEFT", it, "BOTTOMLEFT", 0, -8); id:SetWidth(570); id:SetJustifyH("LEFT")
end

render.unitframes = function()
  Header("Unit Frames", "The selected RetreatUI profile owns ElvUI. Use Unlock Mode for placement.")
  local box = FrameBox(shell.content, PANEL); box:SetPoint("TOPLEFT", 28, -105); box:SetSize(610, 150)
  local title = Label(box, "ElvUI layout", 18, TEXT); title:SetPoint("TOPLEFT", 18, -18)
  local desc = Label(box, "RetreatUI keeps the chosen profile as the baseline. Moving or scaling frames remains a user override until that profile is reinstalled.", 11, MUTED)
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8); desc:SetWidth(570); desc:SetJustifyH("LEFT")
  local unlock = Button(box, "Unlock Frames", 135, function() if RUI.OpenHUDEditor then RUI:OpenHUDEditor() end end, true); unlock:SetPoint("BOTTOMLEFT", 18, 18)
  local elv = Button(box, "Open ElvUI", 120, function() if SlashCmdList and SlashCmdList.ELVUI then SlashCmdList.ELVUI() elseif E_ToggleOptions then E_ToggleOptions() end end); elv:SetPoint("LEFT", unlock, "RIGHT", 10, 0)
end

render.nameplates = function()
  Header("Nameplates", "TurboPlates inherits the visual density of your selected RetreatUI profile.")
  local box = FrameBox(shell.content, PANEL); box:SetPoint("TOPLEFT", 28, -105); box:SetSize(610, 150)
  local style = RUI:GetRetreatStyleInfo()
  local title = Label(box, style and (style.label .. " / TurboPlates") or "Choose a profile first", 18, TEXT); title:SetPoint("TOPLEFT", 18, -18)
  local desc = Label(box, "NPC ability tracking and CoA compatibility remain RetreatUI-managed; profile selection controls spacing and visual density.", 11, MUTED)
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8); desc:SetWidth(570); desc:SetJustifyH("LEFT")
  local apply = Button(box, "Reapply Nameplates", 155, function()
    local key = RUI:GetRetreatStyleKey(); if not key then SetStatus("Choose a profile first", false); return end
    local ok,msg = RUI:InstallRetreatStyleTurboPlates(key); SetStatus(msg,ok)
  end, true); apply:SetPoint("BOTTOMLEFT",18,18)
end

render.details = function()
  Header("Damage Meter", "Details uses the matching RetreatUI profile and stays separate from the HUD.")
  local box = FrameBox(shell.content, PANEL); box:SetPoint("TOPLEFT", 28, -105); box:SetSize(610, 150)
  local style = RUI:GetRetreatStyleInfo(); local title = Label(box, style and (style.label .. " / Details") or "Choose a profile first", 18, TEXT); title:SetPoint("TOPLEFT",18,-18)
  local desc = Label(box, "Reapply only the damage-meter profile without touching ElvUI, TurboPlates or your WeakAuras.",11,MUTED); desc:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-8)
  local apply = Button(box,"Reapply Details",140,function()
    local key=RUI:GetRetreatStyleKey(); if not key then SetStatus("Choose a profile first",false); return end
    local ok,msg=RUI:InstallRetreatStyleDetails(key,RUI:GetRetreatStyleResolution()); SetStatus(msg,ok)
  end,true); apply:SetPoint("BOTTOMLEFT",18,18)
end

render.settings = function()
  Header("Settings", "Repair the selected profile or reload after installation.")
  local box = FrameBox(shell.content, PANEL); box:SetPoint("TOPLEFT",28,-105); box:SetSize(610,200)
  local title=Label(box,"Profile maintenance",18,TEXT); title:SetPoint("TOPLEFT",18,-18)
  local reapply=Button(box,"Reapply Full Profile",165,function() local ok,msg=RUI:ReapplyRetreatStyle(); SetStatus(msg,ok) end,true); reapply:SetPoint("TOPLEFT",18,-62)
  local reload=Button(box,"Reload UI",110,function() ReloadUI() end); reload:SetPoint("LEFT",reapply,"RIGHT",10,0)
  local reset=Button(box,"Clear Selection",130,function()
    local db=RUI:EnsureDB(); db.profileStyle={}; SetStatus("Profile selection cleared. Installed addon profiles are not deleted.",true); shell:RefreshPage()
  end); reset:SetPoint("TOPLEFT",18,-106)
  local note=Label(box,"Clearing the selection does not erase ElvUI/TurboPlates/Details settings. Reinstall either profile to replace them.",10,MUTED); note:SetPoint("TOPLEFT",reset,"BOTTOMLEFT",0,-10); note:SetWidth(560); note:SetJustifyH("LEFT")
end

local function BuildShell()
  if shell then return shell end
  shell = CreateFrame("Frame", "RetreatUIMainWindow", UIParent)
  shell:SetSize(850, 570); shell:SetPoint("CENTER"); shell:SetFrameStrata("DIALOG"); shell:SetClampedToScreen(true)
  shell:SetMovable(true); shell:EnableMouse(true); shell:RegisterForDrag("LeftButton")
  shell:SetScript("OnDragStart", function(self) if not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end end)
  shell:SetScript("OnDragStop", shell.StopMovingOrSizing)
  shell:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1}); shell:SetBackdropColor(BG[1],BG[2],BG[3],BG[4]); shell:SetBackdropBorderColor(.13,.14,.17,1)
  shell.sidebar = FrameBox(shell, {0.018,0.020,0.024,1}); shell.sidebar:SetPoint("TOPLEFT",1,-1); shell.sidebar:SetPoint("BOTTOMLEFT",1,1); shell.sidebar:SetWidth(174)
  shell.content = CreateFrame("Frame", nil, shell); shell.content:SetPoint("TOPLEFT",shell.sidebar,"TOPRIGHT",0,0); shell.content:SetPoint("BOTTOMRIGHT",-1,42)
  local logo=Label(shell.sidebar,"RETREATUI",19,TEXT); logo:SetPoint("TOPLEFT",18,-18)
  local ver=Label(shell.sidebar,"v"..tostring(RUI.version or ""),9,ACCENT); ver:SetPoint("TOPLEFT",logo,"BOTTOMLEFT",0,-3)
  local divider=Solid(shell.sidebar,{.12,.13,.16,1},"ARTWORK"); divider:SetPoint("TOPLEFT",14,-61); divider:SetPoint("TOPRIGHT",-14,-61); divider:SetHeight(1)
  shell.nav={}
  local last
  for _,page in ipairs(PAGES) do
    local row=CreateFrame("Button",nil,shell.sidebar); row:SetSize(150,48)
    if not last then row:SetPoint("TOPLEFT",12,-76) else row:SetPoint("TOPLEFT",last,"BOTTOMLEFT",0,-2) end
    row.bg=Solid(row,{0,0,0,0},"BACKGROUND"); row.bg:SetAllPoints()
    row.mark=Solid(row,ACCENT,"ARTWORK"); row.mark:SetPoint("TOPLEFT"); row.mark:SetPoint("BOTTOMLEFT"); row.mark:SetWidth(3); row.mark:Hide()
    row.title=Label(row,page.label,11,TEXT); row.title:SetPoint("TOPLEFT",12,-9)
    row.hint=Label(row,page.hint,9,MUTED); row.hint:SetPoint("TOPLEFT",row.title,"BOTTOMLEFT",0,-2)
    row:SetScript("OnClick",function() shell:ShowPage(page.key) end)
    shell.nav[page.key]=row; last=row
  end
  local unlock=Button(shell.sidebar,"Unlock Mode",142,function() if RUI.OpenHUDEditor then RUI:OpenHUDEditor() end end,true); unlock:SetPoint("BOTTOM",0,16)
  shell.footer=CreateFrame("Frame",nil,shell); shell.footer:SetPoint("BOTTOMLEFT",shell.sidebar,"BOTTOMRIGHT",0,1); shell.footer:SetPoint("BOTTOMRIGHT",-1,1); shell.footer:SetHeight(41)
  local footerBg=Solid(shell.footer,{0.028,0.030,0.036,1}); footerBg:SetAllPoints()
  shell.footerStatus=Label(shell.footer,"",9,MUTED); shell.footerStatus:SetPoint("LEFT",16,0); shell.footerStatus:SetWidth(520); shell.footerStatus:SetJustifyH("LEFT")
  local close=Button(shell.footer,"Close",80,function() shell:Hide() end); close:SetPoint("RIGHT",-10,0)
  function shell:ShowPage(key)
    activePage=render[key] and key or "profiles"
    for pageKey,row in pairs(self.nav) do
      local active=pageKey==activePage; row.mark:SetShown(active); row.bg:SetVertexColor(active and .07 or 0, active and .072 or 0, active and .085 or 0, active and 1 or 0)
      row.title:SetTextColor(active and ACCENT[1] or TEXT[1],active and ACCENT[2] or TEXT[2],active and ACCENT[3] or TEXT[3],1)
    end
    ClearPage(); render[activePage]()
  end
  function shell:RefreshPage() self:ShowPage(activePage) end
  shell:Hide(); return shell
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
RUI.retreatShellSchema=1

local RUI = RetreatUI
if not RUI then return end

-- Two-page modular installer. The legacy installer remains in the package for
-- backwards compatibility, but these public methods replace its all-or-nothing
-- workflow after every file has loaded.

local frame
local pages={}
local rows={}
local installRows={}
local currentPage=1

local function Theme() return RUI:GetTheme() end

local function Text(parent,value,size,color)
  local fs=parent:CreateFontString(nil,"OVERLAY")
  RUI:ApplyFont(fs,size or 10,"OUTLINE")
  fs:SetText(value or "")
  color=color or Theme().text
  fs:SetTextColor(color[1],color[2],color[3],color[4] or 1)
  return fs
end

local function Panel(parent,bg,border)
  local panel=CreateFrame("Frame",nil,parent)
  RUI:SkinFrame(panel,bg or Theme().panel,border or {0,0,0,1})
  return panel
end

local function Button(parent,label,width,height,callback)
  local theme=Theme()
  local button=CreateFrame("Button",nil,parent)
  button:SetSize(width or 120,height or 28)
  button:RegisterForClicks("LeftButtonUp")
  RUI:SkinFrame(button,theme.panelStrong,{theme.accent[1]*.55,theme.accent[2]*.55,theme.accent[3]*.55,1})
  button.text=Text(button,label,9)
  button.text:SetPoint("CENTER")
  button:SetScript("OnClick",function(self) if not self.disabled and callback then callback(self) end end)
  button:SetScript("OnEnter",function(self) if not self.disabled then self:SetBackdropBorderColor(theme.accent[1],theme.accent[2],theme.accent[3],1) end end)
  button:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(theme.accent[1]*.55,theme.accent[2]*.55,theme.accent[3]*.55,1) end)
  function button:SetLabel(value) self.text:SetText(value or "") end
  function button:SetEnabled(enabled) self.disabled=not enabled; self:SetAlpha(enabled and 1 or .35); self:EnableMouse(enabled) end
  return button
end

local function StatusColor(state)
  local theme=Theme()
  if state=="success" or state=="ready" then return theme.success end
  if state=="error" or state=="missing" then return theme.danger end
  if state=="running" then return theme.accent end
  return theme.muted
end

local function SetStatus(fs,state,label)
  local color=StatusColor(state)
  fs:SetTextColor(color[1],color[2],color[3],color[4] or 1)
  fs:SetText(label or "")
end

local function ResolveIcon(definition)
  local icon=definition and definition.icon
  if type(icon)=="function" then local ok,value=pcall(icon,RUI); icon=ok and value or nil end
  return type(icon)=="string" and icon~="" and icon or "Interface\\Icons\\INV_Misc_Gear_01"
end

local function SelectedCount()
  local count=0
  for _,key in ipairs(RUI.moduleOrder or {}) do if RUI:IsInstallerModuleEnabled(key) then count=count+1 end end
  return count
end

local function CreateComponentRow(parent,key,index)
  local definition=RUI.moduleInstallers[key]
  local theme=Theme()
  local row=Panel(parent,{theme.panel[1],theme.panel[2],theme.panel[3],.74},{theme.dim[1],theme.dim[2],theme.dim[3],.34})
  row:SetPoint("TOPLEFT",24,-145-((index-1)*35))
  row:SetPoint("RIGHT",-24,0)
  row:SetHeight(31)
  row.marker=row:CreateTexture(nil,"ARTWORK")
  row.marker:SetTexture("Interface\\Buttons\\WHITE8X8")
  row.marker:SetSize(3,21)
  row.marker:SetPoint("LEFT",7,0)
  row.icon=row:CreateTexture(nil,"ARTWORK")
  row.icon:SetTexture(ResolveIcon(definition))
  row.icon:SetSize(22,22)
  row.icon:SetPoint("LEFT",17,0)
  row.icon:SetTexCoord(.08,.92,.08,.92)
  row.label=Text(row,definition.label,9,theme.text)
  row.label:SetPoint("TOPLEFT",47,-5)
  row.label:SetWidth(230)
  row.label:SetJustifyH("LEFT")
  row.detail=Text(row,definition.description or "",7,theme.muted)
  row.detail:SetPoint("BOTTOMLEFT",47,4)
  row.detail:SetWidth(365)
  row.detail:SetJustifyH("LEFT")
  row.dependency=Text(row,"",7,theme.muted)
  row.dependency:SetPoint("RIGHT",-84,0)
  row.dependency:SetWidth(150)
  row.dependency:SetJustifyH("RIGHT")
  row.toggle=Button(row,"ON",58,21,function()
    RUI:SetInstallerModuleEnabled(key,not RUI:IsInstallerModuleEnabled(key))
    if pages[1] and pages[1].Refresh then pages[1].Refresh() end
  end)
  row.toggle:SetPoint("RIGHT",-8,0)
  row.key=key
  return row
end

local function CreateInstallRow(parent,key,index)
  local definition=RUI.moduleInstallers[key]
  local theme=Theme()
  local row=Panel(parent,{theme.panel[1],theme.panel[2],theme.panel[3],.74},{theme.dim[1],theme.dim[2],theme.dim[3],.34})
  row:SetPoint("TOPLEFT",24,-118-((index-1)*35))
  row:SetPoint("RIGHT",-24,0)
  row:SetHeight(31)
  row.icon=row:CreateTexture(nil,"ARTWORK")
  row.icon:SetTexture(ResolveIcon(definition))
  row.icon:SetSize(21,21)
  row.icon:SetPoint("LEFT",10,0)
  row.icon:SetTexCoord(.08,.92,.08,.92)
  row.label=Text(row,definition.label,9,theme.text)
  row.label:SetPoint("LEFT",40,0)
  row.label:SetWidth(330)
  row.label:SetJustifyH("LEFT")
  row.status=Text(row,"WAITING",8,theme.muted)
  row.status:SetPoint("RIGHT",-12,0)
  row.status:SetWidth(190)
  row.status:SetJustifyH("RIGHT")
  row.key=key
  return row
end

local function PageTitle(page,title,subtitle)
  local theme=Theme()
  local head=Text(page,title,22,theme.text); head:SetPoint("TOPLEFT",24,-20)
  local body=Text(page,subtitle,9,theme.muted); body:SetPoint("TOPLEFT",24,-52); body:SetWidth(660); body:SetJustifyH("LEFT")
end

local function BuildSelectionPage()
  local theme=Theme()
  local page=CreateFrame("Frame",nil,frame.content)
  page:SetAllPoints(); page:Hide()
  PageTitle(page,"Choose your RetreatUI components","Use a preset or build a custom setup. No class HUD, addon profile or tracker is required to use the rest.")

  page.full=Button(page,"FULL RETREATUI",130,25,function() RUI:ApplyInstallerPreset("full"); page.Refresh() end)
  page.full:SetPoint("TOPLEFT",24,-78)
  page.hud=Button(page,"RETREATUI HUD",130,25,function() RUI:ApplyInstallerPreset("hud"); page.Refresh() end)
  page.hud:SetPoint("LEFT",page.full,"RIGHT",7,0)
  page.layout=Button(page,"RETREATUI LAYOUT",142,25,function() RUI:ApplyInstallerPreset("layout"); page.Refresh() end)
  page.layout:SetPoint("LEFT",page.hud,"RIGHT",7,0)
  page.clear=Button(page,"CLEAR ALL",100,25,function() RUI:ApplyInstallerPreset("clear"); page.Refresh() end)
  page.clear:SetPoint("LEFT",page.layout,"RIGHT",7,0)

  local section=Text(page,"COMPONENTS",8,theme.accent); section:SetPoint("TOPLEFT",24,-124)
  for index,key in ipairs(RUI.moduleOrder or {}) do rows[key]=CreateComponentRow(page,key,index) end
  page.note=Text(page,"Profile modules are applied only when selected. Turning them off stops future RetreatUI writes; existing third-party profiles are not automatically deleted.",8,theme.muted)
  page.note:SetPoint("BOTTOMLEFT",24,16); page.note:SetWidth(650); page.note:SetJustifyH("LEFT")

  page.Refresh=function()
    for _,key in ipairs(RUI.moduleOrder or {}) do
      local row=rows[key]
      local enabled=RUI:IsInstallerModuleEnabled(key)
      local available,reason=RUI:GetInstallerModuleAvailability(key)
      row.toggle:SetLabel(enabled and "ON" or "OFF")
      row:SetAlpha(enabled and 1 or .58)
      if enabled and not available then
        row.marker:SetVertexColor(theme.danger[1],theme.danger[2],theme.danger[3],.95)
        SetStatus(row.dependency,"missing",string.upper(tostring(reason or "MISSING")))
      elseif enabled then
        row.marker:SetVertexColor(theme.success[1],theme.success[2],theme.success[3],.95)
        SetStatus(row.dependency,"ready","READY")
      else
        row.marker:SetVertexColor(theme.muted[1],theme.muted[2],theme.muted[3],.65)
        SetStatus(row.dependency,"disabled","DISABLED")
      end
    end
    frame.selectionText:SetText(tostring(SelectedCount()).." selected")
  end
  return page
end

local function BuildInstallPage()
  local theme=Theme()
  local page=CreateFrame("Frame",nil,frame.content)
  page:SetAllPoints(); page:Hide()
  PageTitle(page,"Install selected components","Only the chosen modules are applied. Missing optional addons are skipped without blocking the rest of the setup.")
  local section=Text(page,"INSTALLATION",8,theme.accent); section:SetPoint("TOPLEFT",24,-97)
  for index,key in ipairs(RUI.moduleOrder or {}) do installRows[key]=CreateInstallRow(page,key,index) end

  page.result=Text(page,"Ready to install.",8,theme.muted)
  page.result:SetPoint("BOTTOMLEFT",24,17); page.result:SetWidth(450); page.result:SetJustifyH("LEFT")
  page.install=Button(page,"INSTALL SELECTED",150,28,function(button)
    if InCombatLockdown and InCombatLockdown() then SetStatus(page.result,"error","Leave combat before installing."); return end
    button:SetEnabled(false); button:SetLabel("INSTALLING")
    for _,key in ipairs(RUI.moduleOrder or {}) do
      local row=installRows[key]
      if RUI:IsInstallerModuleEnabled(key) then row:Show(); SetStatus(row.status,"disabled","WAITING") else row:Hide() end
    end
    local valid,problems=RUI:InstallAllModules(function(key,state,definition,record)
      local row=installRows[key]; if not row then return end
      if not RUI:IsInstallerModuleEnabled(key) then row:Hide(); return end
      row:Show()
      local labels={running="INSTALLING",success="INSTALLED",skipped="SKIPPED",error="FAILED"}
      SetStatus(row.status,state,labels[state] or string.upper(tostring(state)))
      if record and record.message and state~="success" then row.status:SetText((labels[state] or "").." — "..tostring(record.message)) end
    end)
    local warnings=RUI:GetOptionalIntegrationWarnings()
    if valid then
      local db=RUI:EnsureDB(); db.installer.initialCompleted=true; db.installer.completedVersion=RUI.version
      if RUI.IsSupportedCharacter and RUI:IsSupportedCharacter() and RUI.IsInstallerModuleEnabled and RUI:IsInstallerModuleEnabled("classHUD") and type(RUI.MarkClassInstallCompleted)=="function" then
        pcall(RUI.MarkClassInstallCompleted,RUI)
      end
      if #warnings>0 then SetStatus(page.result,"disabled","Installed with optional skips: "..table.concat(warnings," • "))
      else SetStatus(page.result,"success","Selected components installed successfully.") end
      button:SetLabel("INSTALLED")
      page.reload:SetEnabled(true)
    else
      SetStatus(page.result,"error",table.concat(problems or {"Installation failed."}," • "))
      button:SetLabel("RETRY"); button:SetEnabled(true); page.reload:SetEnabled(false)
    end
  end)
  page.install:SetPoint("BOTTOMRIGHT",-24,12)
  page.reload=Button(page,"RELOAD UI",105,28,function() ReloadUI() end)
  page.reload:SetPoint("RIGHT",page.install,"LEFT",-8,0)
  page.reload:SetEnabled(false)

  page.Refresh=function()
    local visibleIndex=0
    for _,key in ipairs(RUI.moduleOrder or {}) do
      local row=installRows[key]
      if RUI:IsInstallerModuleEnabled(key) then
        visibleIndex=visibleIndex+1
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",24,-118-((visibleIndex-1)*35)); row:SetPoint("RIGHT",-24,0); row:Show()
        local available,reason=RUI:GetInstallerModuleAvailability(key)
        local record=RUI:GetModuleStatus(key)
        if not available then SetStatus(row.status,"missing","WILL SKIP — "..tostring(reason or "dependency missing"))
        elseif record and record.version==RUI.version then
          local labels={success="INSTALLED",skipped="SKIPPED",error="FAILED"}; SetStatus(row.status,record.state,labels[record.state] or "READY")
        else SetStatus(row.status,"ready","READY") end
      else row:Hide() end
    end
    page.result:SetText(visibleIndex>0 and "Ready to install "..visibleIndex.." selected components." or "No components selected. Disabled runtime modules will be turned off.")
    page.install:SetEnabled(true); page.install:SetLabel("INSTALL SELECTED")
  end
  return page
end

local function ShowPage(index)
  currentPage=math.max(1,math.min(2,tonumber(index) or 1))
  for i=1,2 do if pages[i] then if i==currentPage then pages[i]:Show() else pages[i]:Hide() end end end
  if pages[currentPage] and pages[currentPage].Refresh then pages[currentPage].Refresh() end
  frame.step1:SetAlpha(currentPage==1 and 1 or .46)
  frame.step2:SetAlpha(currentPage==2 and 1 or .46)
  frame.back:SetEnabled(currentPage>1)
  frame.next:SetLabel(currentPage==1 and "CONTINUE" or "BACK TO COMPONENTS")
  frame.selectionText:SetText(tostring(SelectedCount()).." selected")
end

local function BuildInstaller()
  if frame then return frame end
  local theme=Theme()
  frame=Panel(UIParent,theme.background,{theme.dim[1],theme.dim[2],theme.dim[3],.86})
  frame:SetSize(940,620); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true)
  frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart",function(self) if not InCombatLockdown or not InCombatLockdown() then self:StartMoving() end end)
  frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
  frame.accent=frame:CreateTexture(nil,"ARTWORK"); frame.accent:SetTexture("Interface\\Buttons\\WHITE8X8"); frame.accent:SetPoint("TOPLEFT",1,-1); frame.accent:SetPoint("TOPRIGHT",-1,-1); frame.accent:SetHeight(3); frame.accent:SetVertexColor(theme.accent[1],theme.accent[2],theme.accent[3],.94)

  frame.sidebar=Panel(frame,theme.sidebar,{theme.dim[1],theme.dim[2],theme.dim[3],.34})
  frame.sidebar:SetPoint("TOPLEFT",4,-4); frame.sidebar:SetPoint("BOTTOMLEFT",4,4); frame.sidebar:SetWidth(184)
  frame.content=Panel(frame,theme.background,{theme.dim[1],theme.dim[2],theme.dim[3],.28})
  frame.content:SetPoint("TOPLEFT",192,-4); frame.content:SetPoint("BOTTOMRIGHT",-4,52)
  frame.footer=Panel(frame,theme.sidebar,{theme.dim[1],theme.dim[2],theme.dim[3],.34})
  frame.footer:SetPoint("BOTTOMLEFT",192,4); frame.footer:SetPoint("BOTTOMRIGHT",-4,4); frame.footer:SetHeight(44)

  local logo=frame.sidebar:CreateTexture(nil,"ARTWORK"); logo:SetTexture("Interface\\AddOns\\RetreatUI\\Media\\RetreatUI_Logo.tga"); logo:SetSize(86,86); logo:SetPoint("TOP",0,-15)
  local title=Text(frame.sidebar,"RETREATUI",13,theme.text); title:SetPoint("TOP",0,-105)
  local version=Text(frame.sidebar,"VERSION "..tostring(RUI.version),8,theme.muted); version:SetPoint("TOP",0,-127)

  frame.step1=Panel(frame.sidebar,theme.panel,{theme.dim[1],theme.dim[2],theme.dim[3],.45}); frame.step1:SetSize(154,54); frame.step1:SetPoint("TOP",0,-170)
  local s1=Text(frame.step1,"01",11,theme.accent); s1:SetPoint("LEFT",10,0)
  local s1t=Text(frame.step1,"COMPONENTS",9,theme.text); s1t:SetPoint("TOPLEFT",40,-10)
  local s1s=Text(frame.step1,"Choose what to use",8,theme.muted); s1s:SetPoint("BOTTOMLEFT",40,10)
  frame.step2=Panel(frame.sidebar,theme.panel,{theme.dim[1],theme.dim[2],theme.dim[3],.45}); frame.step2:SetSize(154,54); frame.step2:SetPoint("TOP",0,-232)
  local s2=Text(frame.step2,"02",11,theme.accent); s2:SetPoint("LEFT",10,0)
  local s2t=Text(frame.step2,"INSTALL",9,theme.text); s2t:SetPoint("TOPLEFT",40,-10)
  local s2s=Text(frame.step2,"Apply selected modules",8,theme.muted); s2s:SetPoint("BOTTOMLEFT",40,10)
  local safety=Text(frame.sidebar,"No component is required.\nMissing addons only skip\nthe affected module.",8,theme.muted); safety:SetPoint("BOTTOM",0,24); safety:SetWidth(154); safety:SetJustifyH("CENTER")

  pages[1]=BuildSelectionPage(); pages[2]=BuildInstallPage()
  frame.back=Button(frame.footer,"BACK",82,25,function() ShowPage(1) end); frame.back:SetPoint("LEFT",12,0)
  frame.close=Button(frame.footer,"CLOSE",82,25,function() frame:Hide() end); frame.close:SetPoint("LEFT",frame.back,"RIGHT",7,0)
  frame.next=Button(frame.footer,"CONTINUE",150,25,function() if currentPage==1 then ShowPage(2) else ShowPage(1) end end); frame.next:SetPoint("RIGHT",-12,0)
  frame.selectionText=Text(frame.footer,"",8,theme.muted); frame.selectionText:SetPoint("CENTER")
  return frame
end

function RUI:HideInstaller()
  if frame then frame:Hide() end
end

function RUI:ShowInstaller()
  BuildInstaller(); frame:Show(); ShowPage(1); return true
end

function RUI:RefreshInstallerTheme()
  if frame then frame:Hide(); frame=nil; pages={}; rows={}; installRows={}; currentPage=1 end
end

-- The original slash handler blocks unsupported classes before opening the old
-- installer. Preserve every other command, but allow the modular installer on
-- any character because Class HUD is now only one optional component.
local previousSlash=SlashCmdList and SlashCmdList.RETREATUI
if SlashCmdList and type(previousSlash)=="function" then
  SlashCmdList.RETREATUI=function(message)
    local command=string.lower((message or ""):match("^%s*(.-)%s*$"))
    if command=="" or command=="install" then
      local ok,err=pcall(RUI.ShowInstaller,RUI,true)
      if not ok and RUI.Print then RUI:Print("The installer could not open: "..tostring(err)) end
      return
    end
    return previousSlash(message)
  end
end

RUI._modularInstallerLoaded=true

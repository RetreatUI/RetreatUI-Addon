local RUI = RetreatUI
if not RUI then return end

local TEX="Interface\\Buttons\\WHITE8X8"
local PANEL={0.045,0.048,0.056,0.98}
local PANEL2={0.065,0.068,0.078,0.98}
local ACCENT={1.00,0.34,0.10,1}
local TEXT={0.94,0.94,0.96,1}
local MUTED={0.58,0.60,0.66,1}
local GOOD={0.20,0.85,0.55,1}
local BAD={1.00,0.32,0.28,1}

local function Font(fs,size,outline)
  if RUI.ApplyFont then RUI:ApplyFont(fs,size or 11,outline or "") else fs:SetFont(STANDARD_TEXT_FONT,size or 11,outline or "") end
end
local function Label(parent,text,size,color)
  local fs=parent:CreateFontString(nil,"OVERLAY"); Font(fs,size or 11); fs:SetText(text or ""); color=color or TEXT
  fs:SetTextColor(color[1],color[2],color[3],color[4] or 1); return fs
end
local function Box(parent,color)
  local f=CreateFrame("Frame",nil,parent); f:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1}); color=color or PANEL
  f:SetBackdropColor(color[1],color[2],color[3],color[4] or 1); f:SetBackdropBorderColor(.14,.15,.18,1); return f
end
local function Button(parent,text,width,callback,primary)
  local b=CreateFrame("Button",nil,parent); b:SetSize(width or 100,28); b:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  b:SetBackdropColor(primary and .12 or .065,primary and .07 or .068,primary and .045 or .078,1)
  b:SetBackdropBorderColor(primary and ACCENT[1] or .22,primary and ACCENT[2] or .23,primary and ACCENT[3] or .27,1)
  b.text=Label(b,text,10,primary and ACCENT or TEXT); b.text:SetPoint("CENTER")
  if callback then b:SetScript("OnClick",callback) end
  return b
end
local function Edit(parent,width)
  local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate"); e:SetAutoFocus(false); e:SetSize(width,25); Font(e,11); return e
end
local function ActiveButton(button,active)
  if not button then return end
  if active then button:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],1); button.text:SetTextColor(ACCENT[1],ACCENT[2],ACCENT[3],1)
  else button:SetBackdropBorderColor(.22,.23,.27,1); button.text:SetTextColor(TEXT[1],TEXT[2],TEXT[3],1) end
end
local function EnableButton(button,enabled)
  if not button then return end
  if enabled then button:Enable(); button:SetAlpha(1) else button:Disable(); button:SetAlpha(.4) end
end
local function SpellMeta(item)
  if not item then return "" end
  local bits={item.specialization or "Shared",item.category or "Uncategorized","ID "..tostring(item.spellID or "?")}
  if item.auraID then bits[#bits+1]="Aura "..tostring(item.auraID) end
  return table.concat(bits,"  •  ")
end

function RUI:RenderHUDWorkspace(parent,options)
  options=type(options)=="table" and options or {}
  local setStatus=type(options.status)=="function" and options.status or function() end
  local className=self.GetDetectedClass and self:GetDetectedClass() or "Unknown"
  local selectedItem=nil
  local selectedRole="main"
  local bars=self:GetHUDBars(className)
  local selectedBarID=bars[1] and bars[1].id or nil
  local barPage,slotPage=1,1

  local root=CreateFrame("Frame",nil,parent)
  root:SetPoint("TOPLEFT",28,-84); root:SetPoint("BOTTOMRIGHT",-28,18)

  local left=Box(root,PANEL); left:SetPoint("TOPLEFT",0,0); left:SetPoint("BOTTOMLEFT",0,0); left:SetWidth(330)
  local middle=Box(root,PANEL); middle:SetPoint("TOPLEFT",left,"TOPRIGHT",14,0); middle:SetPoint("BOTTOMLEFT",left,"BOTTOMRIGHT",14,0); middle:SetWidth(300)
  local right=Box(root,PANEL); right:SetPoint("TOPLEFT",middle,"TOPRIGHT",14,0); right:SetPoint("BOTTOMRIGHT",0,0)

  local ghost=CreateFrame("Frame",nil,UIParent); ghost:SetFrameStrata("TOOLTIP"); ghost:SetSize(38,38); ghost:EnableMouse(false)
  ghost.bg=ghost:CreateTexture(nil,"BACKGROUND"); ghost.bg:SetAllPoints(); ghost.bg:SetTexture(TEX); ghost.bg:SetVertexColor(.02,.02,.025,.96)
  ghost.icon=ghost:CreateTexture(nil,"ARTWORK"); ghost.icon:SetPoint("TOPLEFT",2,-2); ghost.icon:SetPoint("BOTTOMRIGHT",-2,2); ghost.icon:SetTexCoord(.08,.92,.08,.92)
  ghost:SetScript("OnUpdate",function(self)
    local scale=UIParent:GetEffectiveScale() or 1; local x,y=GetCursorPosition(); self:ClearAllPoints(); self:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/scale,y/scale)
  end); ghost:Hide()
  local function CancelDrag() root.drag=nil; ghost:Hide() end
  local function StartDrag(payload,texture) root.drag=payload; ghost.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark"); ghost:Show() end
  root:SetScript("OnUpdate",function() if root.drag and type(IsMouseButtonDown)=="function" and not IsMouseButtonDown("LeftButton") then CancelDrag() end end)
  root:SetScript("OnHide",CancelDrag)

  -- SEARCH
  local st=Label(left,"Find a spell",18,TEXT); st:SetPoint("TOPLEFT",16,-16)
  local sh=Label(left,"Name or exact Spell ID",9,MUTED); sh:SetPoint("TOPLEFT",st,"BOTTOMLEFT",0,-4)
  local search=Edit(left,286); search:SetPoint("TOPLEFT",16,-60)
  local empty=Label(left,"Start typing. No giant spell list is shown until you search.",10,MUTED); empty:SetPoint("TOPLEFT",16,-104); empty:SetWidth(286); empty:SetJustifyH("LEFT")
  local rows={}
  for i=1,9 do
    local row=CreateFrame("Button",nil,left); row:SetSize(296,50); row:SetPoint("TOPLEFT",16,-98-((i-1)*53)); row:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
    row:SetBackdropColor(PANEL2[1],PANEL2[2],PANEL2[3],.96); row:SetBackdropBorderColor(.11,.12,.15,1)
    row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(36,36); row.icon:SetPoint("LEFT",7,0); row.icon:SetTexCoord(.08,.92,.08,.92)
    row.name=Label(row,"",11,TEXT); row.name:SetPoint("TOPLEFT",row.icon,"TOPRIGHT",8,-5); row.name:SetWidth(225); row.name:SetJustifyH("LEFT")
    row.meta=Label(row,"",8,MUTED); row.meta:SetPoint("BOTTOMLEFT",row.icon,"BOTTOMRIGHT",8,5); row.meta:SetWidth(225); row.meta:SetJustifyH("LEFT")
    row:SetScript("OnMouseDown",function(self,button)
      if button~="LeftButton" or not self.item then return end
      selectedItem=self.item; if root.RefreshSelected then root:RefreshSelected() end
      StartDrag({kind="catalog",item=self.item,role=selectedRole},self.item.icon)
    end)
    row:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],.9) end)
    row:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(.11,.12,.15,1) end)
    row:Hide(); rows[i]=row
  end
  local function RefreshSearch()
    local query=search:GetText() or ""; local results=RUI:SearchHUDSpells(query,#rows,className); empty:SetShown(query=="")
    for i,row in ipairs(rows) do
      local item=results[i]; row.item=item
      if item then row:Show(); row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); row.name:SetText(item.name or "Unknown"); row.meta:SetText("ID "..tostring(item.spellID or "?").."  •  "..tostring(item.specialization or "Shared")) else row:Hide() end
    end
  end
  search:SetScript("OnTextChanged",RefreshSearch)

  -- TRACKER TYPE
  local mt=Label(middle,"Selected spell",18,TEXT); mt:SetPoint("TOPLEFT",16,-16)
  local micon=middle:CreateTexture(nil,"ARTWORK"); micon:SetSize(44,44); micon:SetPoint("TOPLEFT",16,-52); micon:SetTexCoord(.08,.92,.08,.92); micon:Hide()
  local mname=Label(middle,"Nothing selected",14,TEXT); mname:SetPoint("TOPLEFT",16,-55); mname:SetWidth(265); mname:SetJustifyH("LEFT")
  local mmeta=Label(middle,"Search, choose a tracker type, then drag into a slot.",9,MUTED); mmeta:SetPoint("TOPLEFT",16,-78); mmeta:SetWidth(265); mmeta:SetJustifyH("LEFT")
  local roleLabel=Label(middle,"TRACK AS",9,MUTED); roleLabel:SetPoint("TOPLEFT",16,-126)
  local roleButtons={}
  for _,def in ipairs(self:GetHUDRoleDefinitions()) do roleButtons[def.key]=Button(middle,def.label,128,nil,false) end
  roleButtons.main:SetPoint("TOPLEFT",16,-148); roleButtons.proc:SetPoint("LEFT",roleButtons.main,"RIGHT",8,0)
  roleButtons.utility:SetPoint("TOPLEFT",16,-184); roleButtons.defensive:SetPoint("LEFT",roleButtons.utility,"RIGHT",8,0)
  roleButtons.target:SetPoint("TOPLEFT",16,-220)
  for key,b in pairs(roleButtons) do
    b:SetScript("OnClick",function() selectedRole=key; for k,other in pairs(roleButtons) do ActiveButton(other,k==selectedRole) end end)
    ActiveButton(b,key==selectedRole)
  end
  local explain=Label(middle,"Main / Utility / Defensive\nTracks cooldown state.\n\nBuff / Proc\nTracks the applied player aura.\n\nTarget Debuff\nTracks the applied target aura.",9,MUTED)
  explain:SetPoint("TOPLEFT",16,-272); explain:SetWidth(264); explain:SetJustifyH("LEFT"); explain:SetJustifyV("TOP")
  local guide=Box(middle,PANEL2); guide:SetPoint("TOPLEFT",16,-414); guide:SetPoint("BOTTOMRIGHT",-16,16)
  local gt=Label(guide,"Drag it where you want it",14,TEXT); gt:SetPoint("TOPLEFT",14,-14)
  local gd=Label(guide,"The HUD is slot-based like an action bar. Empty slots stay empty. Existing icons can be dragged to reorder them.",10,MUTED); gd:SetPoint("TOPLEFT",14,-40); gd:SetWidth(235); gd:SetJustifyH("LEFT")
  function root:RefreshSelected()
    if not selectedItem then micon:Hide(); mname:ClearAllPoints(); mname:SetPoint("TOPLEFT",16,-55); mname:SetText("Nothing selected"); mmeta:SetText("Search, choose a tracker type, then drag into a slot."); return end
    micon:Show(); micon:SetTexture(selectedItem.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); mname:ClearAllPoints(); mname:SetPoint("TOPLEFT",micon,"TOPRIGHT",9,-2); mname:SetWidth(205); mname:SetText(selectedItem.name or "Unknown")
    mmeta:ClearAllPoints(); mmeta:SetPoint("TOPLEFT",mname,"BOTTOMLEFT",0,-6); mmeta:SetWidth(205); mmeta:SetText(SpellMeta(selectedItem))
  end

  -- BARS
  local rt=Label(right,"HUD Bars",18,TEXT); rt:SetPoint("TOPLEFT",16,-16)
  local rh=Label(right,"Choose the number of boxes, direction and exact spell position.",9,MUTED); rh:SetPoint("TOPLEFT",rt,"BOTTOMLEFT",0,-4)
  local barPrev=Button(right,"<",28,nil); barPrev:SetPoint("TOPRIGHT",-80,-52)
  local barNext=Button(right,">",28,nil); barNext:SetPoint("LEFT",barPrev,"RIGHT",6,0)
  local addBar=Button(right,"+ New Bar",92,nil,true); addBar:SetPoint("RIGHT",barPrev,"LEFT",-8,0)
  local tabs={}
  for i=1,4 do tabs[i]=Button(right,"",108,nil,false); tabs[i]:SetPoint("TOPLEFT",16+((i-1)*116),-88) end

  local barEditor=Box(right,PANEL2); barEditor:SetPoint("TOPLEFT",16,-128); barEditor:SetPoint("BOTTOMRIGHT",-16,16)
  local createBox=Box(right,{0.075,0.078,0.090,1}); createBox:SetPoint("TOPLEFT",16,-128); createBox:SetPoint("TOPRIGHT",-16,-128); createBox:SetHeight(142); createBox:SetFrameLevel(right:GetFrameLevel()+20); createBox:Hide()
  local cn=Edit(createBox,180); cn:SetPoint("TOPLEFT",14,-30); cn:SetText("Main Rotation 2"); local cnl=Label(createBox,"BAR NAME",8,MUTED); cnl:SetPoint("BOTTOMLEFT",cn,"TOPLEFT",2,3)
  local cs=Edit(createBox,44); cs:SetPoint("LEFT",cn,"RIGHT",12,0); cs:SetText("8"); local csl=Label(createBox,"SLOTS",8,MUTED); csl:SetPoint("BOTTOMLEFT",cs,"TOPLEFT",2,3)
  local ch=Button(createBox,"Horizontal",82,nil,false); ch:SetPoint("LEFT",cs,"RIGHT",12,0); local cv=Button(createBox,"Vertical",70,nil,false); cv:SetPoint("LEFT",ch,"RIGHT",6,0)
  local createOrientation="HORIZONTAL"; ActiveButton(ch,true)
  ch:SetScript("OnClick",function() createOrientation="HORIZONTAL"; ActiveButton(ch,true); ActiveButton(cv,false) end)
  cv:SetScript("OnClick",function() createOrientation="VERTICAL"; ActiveButton(ch,false); ActiveButton(cv,true) end)
  local cc=Button(createBox,"Create Bar",100,nil,true); cc:SetPoint("BOTTOMLEFT",14,14); local cx=Button(createBox,"Cancel",72,nil,false); cx:SetPoint("LEFT",cc,"RIGHT",8,0)
  local function ShowCreate(show) createBox:SetShown(show==true); barEditor:SetShown(show~=true) end
  addBar:SetScript("OnClick",function() ShowCreate(true) end); cx:SetScript("OnClick",function() ShowCreate(false) end)
  cc:SetScript("OnClick",function()
    local bar=RUI:CreateHUDBar("custom",cn:GetText(),createOrientation,tonumber(cs:GetText()) or 8,className); selectedBarID=bar.id; slotPage=1; ShowCreate(false); setStatus(bar.name.." created",true); root:RefreshBars()
  end)

  local bn=Label(barEditor,"",17,TEXT); bn:SetPoint("TOPLEFT",14,-14); local bm=Label(barEditor,"",9,MUTED); bm:SetPoint("TOPLEFT",bn,"BOTTOMLEFT",0,-4)
  local oh=Button(barEditor,"Horizontal",86,nil,false); oh:SetPoint("TOPLEFT",14,-66); local ov=Button(barEditor,"Vertical",72,nil,false); ov:SetPoint("LEFT",oh,"RIGHT",7,0)
  local sm=Button(barEditor,"-",28,nil); sm:SetPoint("LEFT",ov,"RIGHT",16,0); local stxt=Label(barEditor,"",9,TEXT); stxt:SetPoint("LEFT",sm,"RIGHT",7,0); local sp=Button(barEditor,"+",28,nil); sp:SetPoint("LEFT",stxt,"RIGHT",7,0)
  local sync=Button(barEditor,"Sync to WeakAuras",136,nil,true); sync:SetPoint("TOPRIGHT",-14,-66)
  local im=Button(barEditor,"-",28,nil); im:SetPoint("TOPLEFT",14,-106); local itxt=Label(barEditor,"",9,TEXT); itxt:SetPoint("LEFT",im,"RIGHT",7,0); local ip=Button(barEditor,"+",28,nil); ip:SetPoint("LEFT",itxt,"RIGHT",7,0)
  local gm=Button(barEditor,"-",28,nil); gm:SetPoint("LEFT",ip,"RIGHT",20,0); local gtxt=Label(barEditor,"",9,TEXT); gtxt:SetPoint("LEFT",gm,"RIGHT",7,0); local gp=Button(barEditor,"+",28,nil); gp:SetPoint("LEFT",gtxt,"RIGHT",7,0)
  local unlock=Button(barEditor,"Unlock Position",112,nil,false); unlock:SetPoint("TOPRIGHT",-14,-106)
  local del=Button(barEditor,"Delete Bar",88,nil,false); del:SetPoint("RIGHT",unlock,"LEFT",-8,0)

  local slotsLabel=Label(barEditor,"SLOTS",9,MUTED); slotsLabel:SetPoint("TOPLEFT",14,-158)
  local slotPrev=Button(barEditor,"<",28,nil); slotPrev:SetPoint("TOPRIGHT",-78,-150); local slotNext=Button(barEditor,">",28,nil); slotNext:SetPoint("LEFT",slotPrev,"RIGHT",6,0)
  local slotPages=Label(barEditor,"",8,MUTED); slotPages:SetPoint("RIGHT",slotPrev,"LEFT",-8,0)
  local slotFrames={}
  for i=1,12 do
    local s=CreateFrame("Button",nil,barEditor); s:SetSize(42,42); s:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1}); s:SetBackdropColor(.025,.027,.032,.98); s:SetBackdropBorderColor(.22,.23,.27,1)
    s.icon=s:CreateTexture(nil,"ARTWORK"); s.icon:SetPoint("TOPLEFT",2,-2); s.icon:SetPoint("BOTTOMRIGHT",-2,2); s.icon:SetTexCoord(.08,.92,.08,.92); s.icon:Hide()
    s.num=Label(s,"",7,MUTED); s.num:SetPoint("BOTTOMLEFT",3,2); s.plus=Label(s,"+",16,MUTED); s.plus:SetPoint("CENTER")
    s:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],1) end); s:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(.22,.23,.27,1) end)
    s:SetScript("OnMouseDown",function(self,button) if button=="LeftButton" and self.tracker then StartDrag({kind="slot",tracker=self.tracker},self.tracker.icon) end end)
    s:SetScript("OnMouseUp",function(self,button)
      if button~="LeftButton" or not root.drag then return end
      local d=root.drag; local ok,msg
      if d.kind=="catalog" and d.item then ok,msg=RUI:SaveHUDWorkspaceTracker(d.item,d.role or selectedRole,selectedBarID,self.slotIndex,nil)
      elseif d.kind=="slot" and d.tracker then ok,msg=RUI:MoveHUDWorkspaceTracker(d.tracker.key,selectedBarID,self.slotIndex,className) end
      if ok then setStatus((d.item and d.item.name or d.tracker and d.tracker.name or "Spell").." placed in slot "..tostring(self.slotIndex),true) else setStatus(tostring(msg or "Drop failed"),false) end
      CancelDrag(); root:RefreshBars(); RefreshSearch()
    end)
    slotFrames[i]=s
  end

  local function CurrentBars() return RUI:GetHUDBars(className) end
  local function CurrentBar() return selectedBarID and RUI:GetHUDBar(className,selectedBarID) or nil end
  function root:RefreshSlots()
    local bar=CurrentBar(); if not bar then return end
    local assigned=RUI:GetHUDSlotAssignments(bar.id,className); local pages=math.max(1,math.ceil(bar.slotCount/12)); slotPage=math.max(1,math.min(slotPage,pages)); slotPages:SetText("Page "..slotPage.."/"..pages)
    EnableButton(slotPrev,slotPage>1); EnableButton(slotNext,slotPage<pages)
    for i,s in ipairs(slotFrames) do
      local absolute=((slotPage-1)*12)+i; s.slotIndex=absolute; s.tracker=assigned[absolute]; s:ClearAllPoints()
      if bar.orientation=="VERTICAL" then local col=math.floor((i-1)/6); local row=(i-1)%6; s:SetPoint("TOPLEFT",24+(col*56),-190-(row*50))
      else local col=(i-1)%6; local row=math.floor((i-1)/6); s:SetPoint("TOPLEFT",24+(col*50),-190-(row*52)) end
      if absolute<=bar.slotCount then s:Show(); s.num:SetText(tostring(absolute)); if s.tracker then s.icon:Show(); s.icon:SetTexture(s.tracker.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); s.plus:Hide() else s.icon:Hide(); s.plus:Show() end else s:Hide() end
    end
  end
  function root:RefreshBars()
    bars=CurrentBars(); if not selectedBarID or not RUI:GetHUDBar(className,selectedBarID) then selectedBarID=bars[1] and bars[1].id or nil end
    local pages=math.max(1,math.ceil(#bars/4)); barPage=math.max(1,math.min(barPage,pages)); EnableButton(barPrev,barPage>1); EnableButton(barNext,barPage<pages)
    for i,t in ipairs(tabs) do
      local bar=bars[((barPage-1)*4)+i]; t.barID=bar and bar.id or nil
      if bar then t:Show(); t.text:SetText(bar.name); ActiveButton(t,bar.id==selectedBarID) else t:Hide() end
    end
    local bar=CurrentBar(); if not bar then barEditor:Hide(); return end
    barEditor:Show(); bn:SetText(bar.name); bm:SetText(tostring(bar.slotCount).." slots  •  "..(bar.orientation=="VERTICAL" and "Vertical" or "Horizontal").."  •  "..tostring(RUI:GetHUDWorkspaceTrackerCount(bar.id,className)).." assigned")
    ActiveButton(oh,bar.orientation=="HORIZONTAL"); ActiveButton(ov,bar.orientation=="VERTICAL"); stxt:SetText(tostring(bar.slotCount).." slots"); itxt:SetText("Size "..tostring(math.floor(bar.iconSize or 36))); gtxt:SetText("Gap "..tostring(math.floor(bar.spacing or 0)))
    root:RefreshSlots()
  end

  barPrev:SetScript("OnClick",function() barPage=math.max(1,barPage-1); root:RefreshBars() end); barNext:SetScript("OnClick",function() barPage=barPage+1; root:RefreshBars() end)
  for i,t in ipairs(tabs) do
    t:SetScript("OnClick",function() if t.barID then selectedBarID=t.barID; slotPage=1; root:RefreshBars() end end)
    t:SetScript("OnEnter",function() if root.drag and t.barID and t.barID~=selectedBarID then selectedBarID=t.barID; slotPage=1; root:RefreshBars() end end)
  end
  oh:SetScript("OnClick",function() RUI:UpdateHUDBar(selectedBarID,{orientation="HORIZONTAL"},className); root:RefreshBars() end); ov:SetScript("OnClick",function() RUI:UpdateHUDBar(selectedBarID,{orientation="VERTICAL"},className); root:RefreshBars() end)
  sm:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{slotCount=b.slotCount-1},className); root:RefreshBars() end end); sp:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{slotCount=b.slotCount+1},className); root:RefreshBars() end end)
  im:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{iconSize=b.iconSize-2},className); root:RefreshBars() end end); ip:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{iconSize=b.iconSize+2},className); root:RefreshBars() end end)
  gm:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{spacing=b.spacing-1},className); root:RefreshBars() end end); gp:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{spacing=b.spacing+1},className); root:RefreshBars() end end)
  sync:SetScript("OnClick",function() local ok,msg=RUI:OpenHUDBarWeakAurasImport(selectedBarID,className); setStatus(msg,ok) end); unlock:SetScript("OnClick",function() if RUI.OpenHUDEditor then RUI:OpenHUDEditor() end end)
  del:SetScript("OnClick",function() local b=CurrentBar(); if not b then return end local ok,msg=RUI:DeleteHUDBar(b.id,className); if ok then selectedBarID=nil; slotPage=1; setStatus(b.name.." deleted",true); root:RefreshBars() else setStatus(msg,false) end end)
  slotPrev:SetScript("OnClick",function() slotPage=math.max(1,slotPage-1); root:RefreshSlots() end); slotNext:SetScript("OnClick",function() slotPage=slotPage+1; root:RefreshSlots() end)

  RefreshSearch(); root:RefreshSelected(); root:RefreshBars(); return root
end

RUI._hudWorkspaceUILoaded=true
RUI.hudWorkspaceUISchema=2

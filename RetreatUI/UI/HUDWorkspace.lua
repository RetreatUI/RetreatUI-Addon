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
  local fs=parent:CreateFontString(nil,"OVERLAY"); Font(fs,size or 11)
  fs:SetText(text or ""); color=color or TEXT; fs:SetTextColor(color[1],color[2],color[3],color[4] or 1); return fs
end
local function Box(parent,color)
  local f=CreateFrame("Frame",nil,parent); f:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1}); color=color or PANEL
  f:SetBackdropColor(color[1],color[2],color[3],color[4] or 1); f:SetBackdropBorderColor(.14,.15,.18,1); return f
end
local function Button(parent,text,width,callback,primary)
  local b=CreateFrame("Button",nil,parent); b:SetSize(width or 100,28); b:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  b:SetBackdropColor(primary and .12 or .065,primary and .07 or .068,primary and .045 or .078,1)
  b:SetBackdropBorderColor(primary and ACCENT[1] or .22,primary and ACCENT[2] or .23,primary and ACCENT[3] or .27,1)
  b.text=Label(b,text,10,primary and ACCENT or TEXT); b.text:SetPoint("CENTER"); b:SetScript("OnClick",callback); return b
end
local function Edit(parent,width)
  local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate"); e:SetAutoFocus(false); e:SetSize(width,25); Font(e,11); return e
end
local function ActiveButton(button,active)
  if not button then return end
  if active then button:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],1); button.text:SetTextColor(ACCENT[1],ACCENT[2],ACCENT[3],1)
  else button:SetBackdropBorderColor(.22,.23,.27,1); button.text:SetTextColor(TEXT[1],TEXT[2],TEXT[3],1) end
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
  local bars=self:GetHUDBars(className)
  local selectedItem=nil
  local selectedRole="main"
  local selectedBarID=bars[1] and bars[1].id or nil
  local barListPage=1
  local slotPage=1

  local root=CreateFrame("Frame",nil,parent)
  root:SetPoint("TOPLEFT",28,-84); root:SetPoint("BOTTOMRIGHT",-28,18)

  local searchPanel=Box(root,PANEL); searchPanel:SetPoint("TOPLEFT",0,0); searchPanel:SetPoint("BOTTOMLEFT",0,0); searchPanel:SetWidth(335)
  local editorPanel=Box(root,PANEL); editorPanel:SetPoint("TOPLEFT",searchPanel,"TOPRIGHT",14,0); editorPanel:SetPoint("BOTTOMLEFT",searchPanel,"BOTTOMRIGHT",14,0); editorPanel:SetWidth(330)
  local barsPanel=Box(root,PANEL); barsPanel:SetPoint("TOPLEFT",editorPanel,"TOPRIGHT",14,0); barsPanel:SetPoint("BOTTOMRIGHT",0,0)

  local dragGhost=CreateFrame("Frame",nil,UIParent); dragGhost:SetFrameStrata("TOOLTIP"); dragGhost:SetSize(38,38); dragGhost:EnableMouse(false)
  dragGhost.bg=dragGhost:CreateTexture(nil,"BACKGROUND"); dragGhost.bg:SetAllPoints(); dragGhost.bg:SetTexture(TEX); dragGhost.bg:SetVertexColor(.02,.02,.025,.95)
  dragGhost.icon=dragGhost:CreateTexture(nil,"ARTWORK"); dragGhost.icon:SetPoint("TOPLEFT",2,-2); dragGhost.icon:SetPoint("BOTTOMRIGHT",-2,2); dragGhost.icon:SetTexCoord(.08,.92,.08,.92)
  dragGhost:SetScript("OnUpdate",function(self)
    local scale=UIParent:GetEffectiveScale() or 1; local x,y=GetCursorPosition(); x=x/scale; y=y/scale
    self:ClearAllPoints(); self:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
  end)
  dragGhost:Hide()

  local function CancelDrag()
    root.drag=nil; dragGhost:Hide()
  end
  local function StartDrag(payload,texture)
    root.drag=payload; dragGhost.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark"); dragGhost:Show()
  end
  root:SetScript("OnUpdate",function()
    if root.drag and type(IsMouseButtonDown)=="function" and not IsMouseButtonDown("LeftButton") then CancelDrag() end
  end)
  root:SetScript("OnHide",CancelDrag)

  local searchTitle=Label(searchPanel,"Find a spell",18,TEXT); searchTitle:SetPoint("TOPLEFT",16,-16)
  local searchHint=Label(searchPanel,"Search by name or exact Spell ID",10,MUTED); searchHint:SetPoint("TOPLEFT",searchTitle,"BOTTOMLEFT",0,-4)
  local search=Edit(searchPanel,292); search:SetPoint("TOPLEFT",16,-62)
  local searchEmpty=Label(searchPanel,"Start typing. RetreatUI only shows results after you search, so the HUD page stays clean.",10,MUTED)
  searchEmpty:SetPoint("TOPLEFT",16,-106); searchEmpty:SetWidth(292); searchEmpty:SetJustifyH("LEFT")

  local resultRows={}
  for index=1,9 do
    local row=CreateFrame("Button",nil,searchPanel); row:SetSize(302,50); row:SetPoint("TOPLEFT",16,-98-((index-1)*53))
    row:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1}); row:SetBackdropColor(PANEL2[1],PANEL2[2],PANEL2[3],.95); row:SetBackdropBorderColor(.11,.12,.15,1)
    row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(36,36); row.icon:SetPoint("LEFT",7,0); row.icon:SetTexCoord(.08,.92,.08,.92)
    row.name=Label(row,"",11,TEXT); row.name:SetPoint("TOPLEFT",row.icon,"TOPRIGHT",8,-5); row.name:SetWidth(235); row.name:SetJustifyH("LEFT")
    row.meta=Label(row,"",8,MUTED); row.meta:SetPoint("BOTTOMLEFT",row.icon,"BOTTOMRIGHT",8,5); row.meta:SetWidth(235); row.meta:SetJustifyH("LEFT")
    row:SetScript("OnMouseDown",function(self,button)
      if button~="LeftButton" or not self.item then return end
      selectedItem=self.item
      if root.RefreshSelected then root:RefreshSelected() end
      StartDrag({kind="catalog",item=self.item,role=selectedRole},self.item.icon)
    end)
    row:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],.85) end)
    row:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(.11,.12,.15,1) end)
    row:Hide(); resultRows[index]=row
  end

  local function RefreshSearch()
    local query=search:GetText() or ""
    local results=RUI:SearchHUDSpells(query,#resultRows,className)
    searchEmpty:SetShown(query=="")
    for index,row in ipairs(resultRows) do
      local item=results[index]; row.item=item
      if item then
        row:Show(); row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); row.name:SetText(item.name or "Unknown")
        row.meta:SetText("ID "..tostring(item.spellID or "?").."  •  "..tostring(item.specialization or "Shared"))
      else row:Hide() end
    end
  end
  search:SetScript("OnTextChanged",RefreshSearch)

  local selectedTitle=Label(editorPanel,"Selected spell",18,TEXT); selectedTitle:SetPoint("TOPLEFT",16,-16)
  local selectedIcon=editorPanel:CreateTexture(nil,"ARTWORK"); selectedIcon:SetSize(46,46); selectedIcon:SetPoint("TOPLEFT",16,-52); selectedIcon:SetTexCoord(.08,.92,.08,.92); selectedIcon:Hide()
  local selectedName=Label(editorPanel,"Nothing selected",15,TEXT); selectedName:SetPoint("TOPLEFT",16,-55); selectedName:SetWidth(295); selectedName:SetJustifyH("LEFT")
  local selectedMeta=Label(editorPanel,"Search on the left, then drag a spell into a slot.",9,MUTED); selectedMeta:SetPoint("TOPLEFT",16,-78); selectedMeta:SetWidth(295); selectedMeta:SetJustifyH("LEFT")

  local roleLabel=Label(editorPanel,"TRACK AS",9,MUTED); roleLabel:SetPoint("TOPLEFT",16,-126)
  local roleButtons={}
  local roleY=-148
  for _,definition in ipairs(self:GetHUDRoleDefinitions()) do
    local button=Button(editorPanel,definition.label,142,function()
      selectedRole=definition.key
      for key,b in pairs(roleButtons) do ActiveButton(b,key==selectedRole) end
    end,false)
    local position=#roleButtons
    roleButtons[definition.key]=button
  end
  roleButtons.main:SetPoint("TOPLEFT",16,roleY); roleButtons.proc:SetPoint("LEFT",roleButtons.main,"RIGHT",10,0)
  roleButtons.utility:SetPoint("TOPLEFT",16,roleY-38); roleButtons.defensive:SetPoint("LEFT",roleButtons.utility,"RIGHT",10,0)
  roleButtons.target:SetPoint("TOPLEFT",16,roleY-76)
  for key,b in pairs(roleButtons) do ActiveButton(b,key==selectedRole) end

  local roleHelp=Label(editorPanel,"Choose what RetreatUI should watch for this spell. Main/Utility/Defensive use cooldown state. Buff/Proc uses the applied player aura. Target Debuff uses the applied target aura.",9,MUTED)
  roleHelp:SetPoint("TOPLEFT",16,-258); roleHelp:SetWidth(295); roleHelp:SetJustifyH("LEFT"); roleHelp:SetJustifyV("TOP")

  local dragHelp=Box(editorPanel,PANEL2); dragHelp:SetPoint("TOPLEFT",16,-344); dragHelp:SetPoint("BOTTOMRIGHT",-16,16)
  local dragTitle=Label(dragHelp,"Drag & drop",15,TEXT); dragTitle:SetPoint("TOPLEFT",14,-14)
  local dragText=Label(dragHelp,"1. Search a spell\n2. Choose its tracker type\n3. Drag it onto the exact slot you want\n\nYou can also drag an existing HUD icon between slots. Dropping onto an occupied slot swaps positions.",10,MUTED)
  dragText:SetPoint("TOPLEFT",14,-42); dragText:SetWidth(270); dragText:SetJustifyH("LEFT"); dragText:SetJustifyV("TOP")

  function root:RefreshSelected()
    if not selectedItem then
      selectedIcon:Hide(); selectedName:ClearAllPoints(); selectedName:SetPoint("TOPLEFT",16,-55); selectedName:SetText("Nothing selected")
      selectedMeta:SetText("Search on the left, then drag a spell into a slot."); return
    end
    selectedIcon:Show(); selectedIcon:SetTexture(selectedItem.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    selectedName:ClearAllPoints(); selectedName:SetPoint("TOPLEFT",selectedIcon,"TOPRIGHT",10,-2); selectedName:SetWidth(235); selectedName:SetText(selectedItem.name or "Unknown")
    selectedMeta:SetText(SpellMeta(selectedItem)); selectedMeta:ClearAllPoints(); selectedMeta:SetPoint("TOPLEFT",selectedName,"BOTTOMLEFT",0,-6); selectedMeta:SetWidth(235)
  end

  local barsTitle=Label(barsPanel,"HUD Bars",18,TEXT); barsTitle:SetPoint("TOPLEFT",16,-16)
  local barsHint=Label(barsPanel,"Action-bar style slots. Empty positions stay empty in the final HUD.",9,MUTED); barsHint:SetPoint("TOPLEFT",barsTitle,"BOTTOMLEFT",0,-4)

  local barTabs={}
  local function CurrentBars() return RUI:GetHUDBars(className) end
  local function CurrentBar() return selectedBarID and RUI:GetHUDBar(className,selectedBarID) or nil end

  local barPrev=Button(barsPanel,"<",28,function() barListPage=math.max(1,barListPage-1); if root.RefreshBars then root:RefreshBars() end end)
  barPrev:SetPoint("TOPRIGHT",-82,-54)
  local barNext=Button(barsPanel,">",28,function() barListPage=barListPage+1; if root.RefreshBars then root:RefreshBars() end end)
  barNext:SetPoint("LEFT",barPrev,"RIGHT",6,0)
  local newBar=Button(barsPanel,"+ New Bar",92,function() if root.ShowCreate then root:ShowCreate(true) end end,true); newBar:SetPoint("RIGHT",barPrev,"LEFT",-8,0)

  for index=1,4 do
    local tab=Button(barsPanel,"",110,function()
      if not barTabs[index].barID then return end
      selectedBarID=barTabs[index].barID; slotPage=1; root:RefreshBars()
    end,false)
    tab:SetPoint("TOPLEFT",16+((index-1)*118),-92); barTabs[index]=tab
  end

  local createBox=Box(barsPanel,PANEL2); createBox:SetPoint("TOPLEFT",16,-132); createBox:SetPoint("TOPRIGHT",-16,-132); createBox:SetHeight(128); createBox:Hide()
  local createName=Edit(createBox,175); createName:SetPoint("TOPLEFT",14,-28); createName:SetText("Main Rotation 2")
  local createNameLabel=Label(createBox,"Name",8,MUTED); createNameLabel:SetPoint("BOTTOMLEFT",createName,"TOPLEFT",2,3)
  local createSlots=Edit(createBox,45); createSlots:SetPoint("LEFT",createName,"RIGHT",12,0); createSlots:SetText("8")
  local createSlotsLabel=Label(createBox,"Slots",8,MUTED); createSlotsLabel:SetPoint("BOTTOMLEFT",createSlots,"TOPLEFT",2,3)
  local createHorizontal=Button(createBox,"Horizontal",82,nil,false); createHorizontal:SetPoint("LEFT",createSlots,"RIGHT",12,0)
  local createVertical=Button(createBox,"Vertical",72,nil,false); createVertical:SetPoint("LEFT",createHorizontal,"RIGHT",6,0)
  local createOrientation="HORIZONTAL"
  createHorizontal:SetScript("OnClick",function() createOrientation="HORIZONTAL"; ActiveButton(createHorizontal,true); ActiveButton(createVertical,false) end)
  createVertical:SetScript("OnClick",function() createOrientation="VERTICAL"; ActiveButton(createHorizontal,false); ActiveButton(createVertical,true) end)
  ActiveButton(createHorizontal,true)
  local createConfirm=Button(createBox,"Create Bar",100,function()
    local bar=RUI:CreateHUDBar("custom",createName:GetText(),createOrientation,tonumber(createSlots:GetText()) or 8,className)
    selectedBarID=bar.id; createBox:Hide(); root:RefreshBars(); setStatus(bar.name.." created",true)
  end,true); createConfirm:SetPoint("BOTTOMLEFT",14,12)
  local createCancel=Button(createBox,"Cancel",76,function() createBox:Hide() end); createCancel:SetPoint("LEFT",createConfirm,"RIGHT",8,0)
  function root:ShowCreate(show) createBox:SetShown(show==true) end

  local barEditor=Box(barsPanel,PANEL2); barEditor:SetPoint("TOPLEFT",16,-132); barEditor:SetPoint("BOTTOMRIGHT",-16,16)
  local barName=Label(barEditor,"",17,TEXT); barName:SetPoint("TOPLEFT",14,-14)
  local barMeta=Label(barEditor,"",9,MUTED); barMeta:SetPoint("TOPLEFT",barName,"BOTTOMLEFT",0,-4)
  local orientationH=Button(barEditor,"Horizontal",86,nil,false); orientationH:SetPoint("TOPLEFT",14,-68)
  local orientationV=Button(barEditor,"Vertical",74,nil,false); orientationV:SetPoint("LEFT",orientationH,"RIGHT",7,0)
  local minusSlot=Button(barEditor,"-",28,nil); minusSlot:SetPoint("LEFT",orientationV,"RIGHT",18,0)
  local slotText=Label(barEditor,"",10,TEXT); slotText:SetPoint("LEFT",minusSlot,"RIGHT",8,0)
  local plusSlot=Button(barEditor,"+",28,nil); plusSlot:SetPoint("LEFT",slotText,"RIGHT",8,0)
  local sync=Button(barEditor,"Sync to WeakAuras",135,function()
    local ok,msg=RUI:OpenHUDBarWeakAurasImport(selectedBarID,className); setStatus(msg,ok)
  end,true); sync:SetPoint("TOPRIGHT",-14,-68)

  local sizeMinus=Button(barEditor,"-",28,nil); sizeMinus:SetPoint("TOPLEFT",14,-108)
  local sizeText=Label(barEditor,"",9,TEXT); sizeText:SetPoint("LEFT",sizeMinus,"RIGHT",8,0)
  local sizePlus=Button(barEditor,"+",28,nil); sizePlus:SetPoint("LEFT",sizeText,"RIGHT",8,0)
  local spacingMinus=Button(barEditor,"-",28,nil); spacingMinus:SetPoint("LEFT",sizePlus,"RIGHT",24,0)
  local spacingText=Label(barEditor,"",9,TEXT); spacingText:SetPoint("LEFT",spacingMinus,"RIGHT",8,0)
  local spacingPlus=Button(barEditor,"+",28,nil); spacingPlus:SetPoint("LEFT",spacingText,"RIGHT",8,0)
  local unlock=Button(barEditor,"Unlock Position",112,function() if RUI.OpenHUDEditor then RUI:OpenHUDEditor() end end); unlock:SetPoint("TOPRIGHT",-14,-108)

  local slotHeader=Label(barEditor,"SLOTS",9,MUTED); slotHeader:SetPoint("TOPLEFT",14,-158)
  local slotPrev=Button(barEditor,"<",28,function() slotPage=math.max(1,slotPage-1); root:RefreshSlots() end); slotPrev:SetPoint("TOPRIGHT",-78,-150)
  local slotNext=Button(barEditor,">",28,function() slotPage=slotPage+1; root:RefreshSlots() end); slotNext:SetPoint("LEFT",slotPrev,"RIGHT",6,0)
  local slotPageText=Label(barEditor,"",8,MUTED); slotPageText:SetPoint("RIGHT",slotPrev,"LEFT",-8,0)

  local slotFrames={}
  for index=1,12 do
    local slot=CreateFrame("Button",nil,barEditor); slot:SetSize(42,42); slot:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1}); slot:SetBackdropColor(.025,.027,.032,.98); slot:SetBackdropBorderColor(.22,.23,.27,1)
    slot.icon=slot:CreateTexture(nil,"ARTWORK"); slot.icon:SetPoint("TOPLEFT",2,-2); slot.icon:SetPoint("BOTTOMRIGHT",-2,2); slot.icon:SetTexCoord(.08,.92,.08,.92); slot.icon:Hide()
    slot.number=Label(slot,tostring(index),7,MUTED); slot.number:SetPoint("BOTTOMLEFT",3,2)
    slot.empty=Label(slot,"+",16,MUTED); slot.empty:SetPoint("CENTER")
    slot:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],1) end)
    slot:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(.22,.23,.27,1) end)
    slot:SetScript("OnMouseDown",function(self,button)
      if button~="LeftButton" or not self.tracker then return end
      StartDrag({kind="slot",tracker=self.tracker,fromBarID=selectedBarID,fromSlot=self.slotIndex},self.tracker.icon)
    end)
    slot:SetScript("OnMouseUp",function(self,button)
      if button~="LeftButton" or not root.drag then return end
      local drag=root.drag
      if drag.kind=="catalog" and drag.item then
        local ok,msg=RUI:SaveHUDWorkspaceTracker(drag.item,drag.role or selectedRole,selectedBarID,self.slotIndex,nil)
        setStatus(ok and ((drag.item.name or "Spell").." added to slot "..tostring(self.slotIndex)) or tostring(msg),ok)
      elseif drag.kind=="slot" and drag.tracker then
        local ok,msg=RUI:MoveHUDWorkspaceTracker(drag.tracker.key,selectedBarID,self.slotIndex,className)
        setStatus(ok and ((drag.tracker.name or "Spell").." moved to slot "..tostring(self.slotIndex)) or tostring(msg),ok)
      end
      CancelDrag(); root:RefreshBars(); RefreshSearch()
    end)
    slotFrames[index]=slot
  end

  function root:RefreshSlots()
    local bar=CurrentBar(); if not bar then return end
    local assignments=RUI:GetHUDSlotAssignments(bar.id,className)
    local pages=math.max(1,math.ceil(bar.slotCount/12)); slotPage=math.max(1,math.min(slotPage,pages)); slotPageText:SetText("Page "..slotPage.."/"..pages)
    slotPrev:SetEnabled(slotPage>1); slotNext:SetEnabled(slotPage<pages)
    local editorWidth=barEditor:GetWidth(); if editorWidth<=0 then editorWidth=470 end
    for index,slot in ipairs(slotFrames) do
      local absolute=((slotPage-1)*12)+index; slot.slotIndex=absolute; slot.tracker=assignments[absolute]
      slot:ClearAllPoints()
      if bar.orientation=="VERTICAL" then
        local col=math.floor((index-1)/6); local row=(index-1)%6
        slot:SetPoint("TOPLEFT",24+(col*56),-190-(row*50))
      else
        local col=(index-1)%6; local row=math.floor((index-1)/6)
        slot:SetPoint("TOPLEFT",24+(col*50),-190-(row*52))
      end
      if absolute<=bar.slotCount then
        slot:Show(); slot.number:SetText(tostring(absolute))
        if slot.tracker then slot.icon:Show(); slot.icon:SetTexture(slot.tracker.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); slot.empty:Hide()
        else slot.icon:Hide(); slot.empty:Show() end
      else slot:Hide() end
    end
  end

  function root:RefreshBars()
    bars=CurrentBars()
    if not selectedBarID or not RUI:GetHUDBar(className,selectedBarID) then selectedBarID=bars[1] and bars[1].id or nil end
    local pages=math.max(1,math.ceil(#bars/4)); barListPage=math.max(1,math.min(barListPage,pages))
    barPrev:SetEnabled(barListPage>1); barNext:SetEnabled(barListPage<pages)
    for index,tab in ipairs(barTabs) do
      local bar=bars[((barListPage-1)*4)+index]; tab.barID=bar and bar.id or nil
      if bar then tab:Show(); tab.text:SetText(bar.name); ActiveButton(tab,bar.id==selectedBarID) else tab:Hide() end
    end
    local bar=CurrentBar(); if not bar then barEditor:Hide(); return end
    barEditor:Show(); barName:SetText(bar.name); barMeta:SetText(tostring(bar.slotCount).." slots  •  "..(bar.orientation=="VERTICAL" and "Vertical" or "Horizontal").."  •  "..tostring(RUI:GetHUDWorkspaceTrackerCount(bar.id,className)).." assigned")
    ActiveButton(orientationH,bar.orientation=="HORIZONTAL"); ActiveButton(orientationV,bar.orientation=="VERTICAL")
    slotText:SetText(tostring(bar.slotCount).." slots"); sizeText:SetText("Size "..tostring(math.floor(bar.iconSize or 36))); spacingText:SetText("Gap "..tostring(math.floor(bar.spacing or 0)))
    root:RefreshSlots()
  end

  orientationH:SetScript("OnClick",function() RUI:UpdateHUDBar(selectedBarID,{orientation="HORIZONTAL"},className); root:RefreshBars() end)
  orientationV:SetScript("OnClick",function() RUI:UpdateHUDBar(selectedBarID,{orientation="VERTICAL"},className); root:RefreshBars() end)
  minusSlot:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{slotCount=b.slotCount-1},className); root:RefreshBars() end end)
  plusSlot:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{slotCount=b.slotCount+1},className); root:RefreshBars() end end)
  sizeMinus:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{iconSize=b.iconSize-2},className); root:RefreshBars() end end)
  sizePlus:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{iconSize=b.iconSize+2},className); root:RefreshBars() end end)
  spacingMinus:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{spacing=b.spacing-1},className); root:RefreshBars() end end)
  spacingPlus:SetScript("OnClick",function() local b=CurrentBar(); if b then RUI:UpdateHUDBar(b.id,{spacing=b.spacing+1},className); root:RefreshBars() end end)

  RefreshSearch(); root:RefreshSelected(); root:RefreshBars()
  return root
end

RUI._hudWorkspaceUILoaded=true
RUI.hudWorkspaceUISchema=1

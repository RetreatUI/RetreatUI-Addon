local RUI = RetreatUI
if not RUI then return end

local TEX = "Interface\\Buttons\\WHITE8X8"
local BG = {0.025,0.027,0.032,1}
local SURFACE = {0.038,0.041,0.048,1}
local SURFACE2 = {0.055,0.058,0.068,1}
local ACCENT = {1.00,0.34,0.10,1}
local TEXT = {0.95,0.95,0.97,1}
local MUTED = {0.57,0.60,0.66,1}
local GOOD = {0.20,0.85,0.55,1}
local BAD = {1.00,0.32,0.28,1}

local function Font(fs,size,outline)
  if RUI.ApplyFont then RUI:ApplyFont(fs,size or 11,outline or "")
  else fs:SetFont(STANDARD_TEXT_FONT,size or 11,outline or "") end
end

local function Label(parent,text,size,color)
  local fs = parent:CreateFontString(nil,"OVERLAY")
  Font(fs,size or 11)
  fs:SetText(text or "")
  color = color or TEXT
  fs:SetTextColor(color[1],color[2],color[3],color[4] or 1)
  return fs
end

local function Box(parent,color)
  local f = CreateFrame("Frame",nil,parent)
  f:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  color = color or SURFACE
  f:SetBackdropColor(color[1],color[2],color[3],color[4] or 1)
  f:SetBackdropBorderColor(.13,.14,.17,1)
  return f
end

local function Button(parent,text,width,callback,primary)
  local b = CreateFrame("Button",nil,parent)
  b:SetSize(width or 96,30)
  b:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  b:SetBackdropColor(primary and .13 or .055,primary and .07 or .058,primary and .04 or .068,1)
  b:SetBackdropBorderColor(primary and ACCENT[1] or .20,primary and ACCENT[2] or .21,primary and ACCENT[3] or .25,1)
  b.text = Label(b,text,10,primary and ACCENT or TEXT)
  b.text:SetPoint("CENTER")
  if callback then b:SetScript("OnClick",callback) end
  b:SetScript("OnEnter",function(self)
    if self:IsEnabled() then self:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],.85) end
  end)
  b:SetScript("OnLeave",function(self)
    if self._active then self:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],1)
    else self:SetBackdropBorderColor(primary and ACCENT[1] or .20,primary and ACCENT[2] or .21,primary and ACCENT[3] or .25,1) end
  end)
  return b
end

local function SetActive(button,active)
  if not button then return end
  button._active = active == true
  if active then
    button:SetBackdropColor(.13,.07,.04,1)
    button:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],1)
    button.text:SetTextColor(ACCENT[1],ACCENT[2],ACCENT[3],1)
  else
    button:SetBackdropColor(.055,.058,.068,1)
    button:SetBackdropBorderColor(.20,.21,.25,1)
    button.text:SetTextColor(TEXT[1],TEXT[2],TEXT[3],1)
  end
end

local function Edit(parent,width,height)
  local e = CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
  e:SetAutoFocus(false)
  e:SetSize(width or 240,height or 28)
  Font(e,11)
  return e
end

local function SpellMeta(item)
  if not item then return "" end
  local bits = {"ID "..tostring(item.spellID or "?"), tostring(item.specialization or "Shared")}
  if item.auraID then bits[#bits+1] = "Aura "..tostring(item.auraID) end
  return table.concat(bits,"  •  ")
end

local function TrackerTexture(tracker)
  if not tracker then return nil end
  local id = tonumber(tracker.spellID)
  if id and type(GetSpellTexture) == "function" then
    local ok, texture = pcall(GetSpellTexture,id)
    if ok and texture then return texture end
  end
  return tracker.icon
end

function RUI:RenderHUDWorkspace(parent,options)
  options = type(options)=="table" and options or {}
  local setStatus = type(options.status)=="function" and options.status or function() end
  local className = self.GetDetectedClass and self:GetDetectedClass() or "Unknown"
  local selectedItem = nil
  local selectedRole = "main"
  local bars = self:GetHUDBars(className)
  local selectedBarID = bars[1] and bars[1].id or nil
  local barPage = 1

  local root = CreateFrame("Frame",nil,parent)
  root:SetPoint("TOPLEFT",24,-82)
  root:SetPoint("BOTTOMRIGHT",-24,18)

  -- drag ghost
  local ghost = CreateFrame("Frame",nil,UIParent)
  ghost:SetFrameStrata("TOOLTIP")
  ghost:SetSize(46,46)
  ghost:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
  ghost:SetBackdropColor(.02,.02,.025,.96)
  ghost:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],1)
  ghost.icon = ghost:CreateTexture(nil,"ARTWORK")
  ghost.icon:SetPoint("TOPLEFT",3,-3)
  ghost.icon:SetPoint("BOTTOMRIGHT",-3,3)
  ghost.icon:SetTexCoord(.08,.92,.08,.92)
  ghost:EnableMouse(false)
  ghost:SetScript("OnUpdate",function(self)
    local scale = UIParent:GetEffectiveScale() or 1
    local x,y = GetCursorPosition()
    self:ClearAllPoints()
    self:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/scale,y/scale)
  end)
  ghost:Hide()

  local function CancelDrag()
    root.drag = nil
    ghost:Hide()
  end
  local function StartDrag(payload,texture)
    root.drag = payload
    ghost.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    ghost:Show()
  end
  root:SetScript("OnUpdate",function()
    if root.drag and type(IsMouseButtonDown)=="function" and not IsMouseButtonDown("LeftButton") then CancelDrag() end
  end)
  root:SetScript("OnHide",CancelDrag)

  -- top search / role toolbar
  local toolbar = Box(root,BG)
  toolbar:SetPoint("TOPLEFT",0,0)
  toolbar:SetPoint("TOPRIGHT",0,0)
  toolbar:SetHeight(82)

  local searchLabel = Label(toolbar,"FIND A SPELL",9,MUTED)
  searchLabel:SetPoint("TOPLEFT",16,-12)
  local search = Edit(toolbar,330,30)
  search:SetPoint("TOPLEFT",16,-34)

  local rolesLabel = Label(toolbar,"TRACK AS",9,MUTED)
  rolesLabel:SetPoint("TOPLEFT",search,"TOPRIGHT",24,22)
  local roleButtons = {}
  local roleDefs = self:GetHUDRoleDefinitions()
  local previous
  for _,def in ipairs(roleDefs) do
    local b = Button(toolbar,def.label,108,nil,false)
    if not previous then b:SetPoint("LEFT",search,"RIGHT",24,0)
    else b:SetPoint("LEFT",previous,"RIGHT",6,0) end
    b:SetScript("OnClick",function()
      selectedRole = def.key
      for key,button in pairs(roleButtons) do SetActive(button,key==selectedRole) end
    end)
    roleButtons[def.key] = b
    SetActive(b,def.key==selectedRole)
    previous = b
  end

  -- search results rail
  local results = Box(root,SURFACE)
  results:SetPoint("TOPLEFT",toolbar,"BOTTOMLEFT",0,-12)
  results:SetPoint("BOTTOMLEFT",0,0)
  results:SetWidth(300)

  local rtitle = Label(results,"Search results",15,TEXT)
  rtitle:SetPoint("TOPLEFT",14,-14)
  local rhint = Label(results,"Type a spell name or exact Spell ID.",9,MUTED)
  rhint:SetPoint("TOPLEFT",rtitle,"BOTTOMLEFT",0,-4)

  local empty = Label(results,"Start typing above.\n\nOnly matching spells appear here.",10,MUTED)
  empty:SetPoint("TOPLEFT",14,-72)
  empty:SetWidth(270)
  empty:SetJustifyH("LEFT")

  local rows = {}
  for i=1,8 do
    local row = CreateFrame("Button",nil,results)
    row:SetSize(272,52)
    row:SetPoint("TOPLEFT",14,-70-((i-1)*56))
    row:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
    row:SetBackdropColor(SURFACE2[1],SURFACE2[2],SURFACE2[3],.94)
    row:SetBackdropBorderColor(.12,.13,.16,1)
    row.icon = row:CreateTexture(nil,"ARTWORK")
    row.icon:SetSize(38,38)
    row.icon:SetPoint("LEFT",7,0)
    row.icon:SetTexCoord(.08,.92,.08,.92)
    row.name = Label(row,"",11,TEXT)
    row.name:SetPoint("TOPLEFT",row.icon,"TOPRIGHT",9,-5)
    row.name:SetWidth(207)
    row.name:SetJustifyH("LEFT")
    row.meta = Label(row,"",8,MUTED)
    row.meta:SetPoint("BOTTOMLEFT",row.icon,"BOTTOMRIGHT",9,5)
    row.meta:SetWidth(207)
    row.meta:SetJustifyH("LEFT")
    row:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],.9) end)
    row:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(.12,.13,.16,1) end)
    row:SetScript("OnMouseDown",function(self,button)
      if button~="LeftButton" or not self.item then return end
      selectedItem = self.item
      if root.RefreshSelected then root:RefreshSelected() end
      StartDrag({kind="catalog",item=self.item,role=selectedRole},self.item.icon)
    end)
    row:Hide()
    rows[i] = row
  end

  local function RefreshSearch()
    local query = search:GetText() or ""
    local matches = RUI:SearchHUDSpells(query,#rows,className)
    empty:SetShown(query=="")
    for i,row in ipairs(rows) do
      local item = matches[i]
      row.item = item
      if item then
        row:Show()
        row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.name:SetText(item.name or "Unknown")
        row.meta:SetText("ID "..tostring(item.spellID or "?").."  •  "..tostring(item.specialization or "Shared"))
      else row:Hide() end
    end
    if query~="" and #matches==0 then
      empty:SetText("No matching spell found.")
      empty:Show()
    else
      empty:SetText("Start typing above.\n\nOnly matching spells appear here.")
    end
  end
  search:SetScript("OnTextChanged",RefreshSearch)

  -- main workspace
  local workspace = Box(root,SURFACE)
  workspace:SetPoint("TOPLEFT",results,"TOPRIGHT",12,0)
  workspace:SetPoint("BOTTOMRIGHT",0,0)

  local barHeader = CreateFrame("Frame",nil,workspace)
  barHeader:SetPoint("TOPLEFT",0,0)
  barHeader:SetPoint("TOPRIGHT",0,0)
  barHeader:SetHeight(54)

  local tabs = {}
  for i=1,5 do
    local tab = Button(barHeader,"",126,nil,false)
    tab:SetPoint("LEFT",14+((i-1)*132),0)
    tab:Hide()
    tabs[i] = tab
  end
  local prev = Button(barHeader,"‹",32,nil,false)
  prev:SetPoint("RIGHT",-142,0)
  local nextb = Button(barHeader,"›",32,nil,false)
  nextb:SetPoint("LEFT",prev,"RIGHT",5,0)
  local newBar = Button(barHeader,"+ New Bar",96,nil,true)
  newBar:SetPoint("RIGHT",-12,0)

  local selectedStrip = Box(workspace,BG)
  selectedStrip:SetPoint("TOPLEFT",14,-60)
  selectedStrip:SetPoint("TOPRIGHT",-14,-60)
  selectedStrip:SetHeight(64)
  local selIcon = selectedStrip:CreateTexture(nil,"ARTWORK")
  selIcon:SetSize(44,44)
  selIcon:SetPoint("LEFT",10,0)
  selIcon:SetTexCoord(.08,.92,.08,.92)
  selIcon:Hide()
  local selName = Label(selectedStrip,"No spell selected",13,TEXT)
  selName:SetPoint("LEFT",16,10)
  local selMeta = Label(selectedStrip,"Search on the left, choose a tracker type, then drag it into a slot.",9,MUTED)
  selMeta:SetPoint("LEFT",16,-10)
  local dragHint = Label(selectedStrip,"DRAG TO SLOT →",9,ACCENT)
  dragHint:SetPoint("RIGHT",-16,0)
  dragHint:Hide()

  function root:RefreshSelected()
    if not selectedItem then
      selIcon:Hide()
      selName:ClearAllPoints(); selName:SetPoint("LEFT",16,10)
      selName:SetText("No spell selected")
      selMeta:ClearAllPoints(); selMeta:SetPoint("LEFT",16,-10)
      selMeta:SetText("Search on the left, choose a tracker type, then drag it into a slot.")
      dragHint:Hide()
      return
    end
    selIcon:Show()
    selIcon:SetTexture(selectedItem.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    selName:ClearAllPoints(); selName:SetPoint("TOPLEFT",selIcon,"TOPRIGHT",10,-3)
    selName:SetText(selectedItem.name or "Unknown")
    selMeta:ClearAllPoints(); selMeta:SetPoint("TOPLEFT",selName,"BOTTOMLEFT",0,-5)
    selMeta:SetText(SpellMeta(selectedItem).."  •  "..tostring((roleButtons[selectedRole] and roleButtons[selectedRole].text:GetText()) or selectedRole))
    dragHint:Show()
  end

  selectedStrip:EnableMouse(true)
  selectedStrip:SetScript("OnMouseDown",function(_,button)
    if button=="LeftButton" and selectedItem then StartDrag({kind="catalog",item=selectedItem,role=selectedRole},selectedItem.icon) end
  end)

  local settings = CreateFrame("Frame",nil,workspace)
  settings:SetPoint("TOPLEFT",14,-136)
  settings:SetPoint("TOPRIGHT",-14,-136)
  settings:SetHeight(42)

  local barName = Label(settings,"",15,TEXT)
  barName:SetPoint("LEFT",0,0)
  local orientation = Button(settings,"Horizontal",92,nil,false)
  orientation:SetPoint("LEFT",barName,"RIGHT",18,0)
  local slotsMinus = Button(settings,"−",30,nil,false)
  local slotsText = Label(settings,"8 slots",9,MUTED)
  local slotsPlus = Button(settings,"+",30,nil,false)
  slotsMinus:SetPoint("LEFT",orientation,"RIGHT",10,0)
  slotsText:SetPoint("LEFT",slotsMinus,"RIGHT",7,0)
  slotsPlus:SetPoint("LEFT",slotsText,"RIGHT",7,0)
  local sizeMinus = Button(settings,"−",30,nil,false)
  local sizeText = Label(settings,"38 px",9,MUTED)
  local sizePlus = Button(settings,"+",30,nil,false)
  sizeMinus:SetPoint("LEFT",slotsPlus,"RIGHT",16,0)
  sizeText:SetPoint("LEFT",sizeMinus,"RIGHT",7,0)
  sizePlus:SetPoint("LEFT",sizeText,"RIGHT",7,0)
  local unlock = Button(settings,"Unlock",72,nil,false)
  unlock:SetPoint("RIGHT",-144,0)
  local sync = Button(settings,"Apply HUD",126,nil,true)
  sync:SetPoint("RIGHT",0,0)

  local canvas = Box(workspace,BG)
  canvas:SetPoint("TOPLEFT",14,-184)
  canvas:SetPoint("BOTTOMRIGHT",-14,14)
  local canvasTitle = Label(canvas,"HUD BAR PREVIEW",9,MUTED)
  canvasTitle:SetPoint("TOPLEFT",14,-12)
  local canvasHint = Label(canvas,"Drop abilities into exact slots. Drag existing icons to reorder. Right-click removes.",9,MUTED)
  canvasHint:SetPoint("TOPRIGHT",-14,-12)
  canvasHint:SetJustifyH("RIGHT")

  local slotFrames = {}
  for i=1,24 do
    local slot = CreateFrame("Button",nil,canvas)
    slot:SetSize(48,48)
    slot:SetBackdrop({bgFile=TEX,edgeFile=TEX,edgeSize=1})
    slot:SetBackdropColor(.028,.030,.036,1)
    slot:SetBackdropBorderColor(.20,.21,.25,1)
    slot.icon = slot:CreateTexture(nil,"ARTWORK")
    slot.icon:SetPoint("TOPLEFT",3,-3)
    slot.icon:SetPoint("BOTTOMRIGHT",-3,3)
    slot.icon:SetTexCoord(.08,.92,.08,.92)
    slot.icon:Hide()
    slot.num = Label(slot,tostring(i),9,MUTED)
    slot.num:SetPoint("CENTER")
    slot.index = i
    slot:SetScript("OnEnter",function(self)
      if root.drag then self:SetBackdropBorderColor(ACCENT[1],ACCENT[2],ACCENT[3],1)
      else self:SetBackdropBorderColor(.36,.37,.42,1) end
    end)
    slot:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(.20,.21,.25,1) end)
    slot:SetScript("OnMouseDown",function(self,button)
      if button=="RightButton" and self.tracker then
        local ok = RUI:RemoveHUDWorkspaceTracker(self.tracker.key,className)
        if ok then setStatus("Removed "..tostring(self.tracker.name or "spell"),true); root:RefreshSlots() end
        return
      end
      if button=="LeftButton" and self.tracker then
        StartDrag({kind="existing",key=self.tracker.key},TrackerTexture(self.tracker))
      end
    end)
    slot:SetScript("OnMouseUp",function(self,button)
      if button~="LeftButton" or not root.drag then return end
      local bar = RUI:GetHUDBar(className,selectedBarID)
      if not bar then CancelDrag(); return end
      local ok,message
      if root.drag.kind=="catalog" then
        ok,message = RUI:SaveHUDWorkspaceTracker(root.drag.item,root.drag.role or selectedRole,bar.id,self.index)
      elseif root.drag.kind=="existing" then
        ok,message = RUI:MoveHUDWorkspaceTracker(root.drag.key,bar.id,self.index,className)
      end
      CancelDrag()
      if ok then setStatus("HUD slot updated",true); root:RefreshSlots()
      else setStatus(tostring(message or "HUD slot update failed"),false) end
    end)
    slot:Hide()
    slotFrames[i] = slot
  end

  local function CurrentBars() return RUI:GetHUDBars(className) end
  local function CurrentBar() return selectedBarID and RUI:GetHUDBar(className,selectedBarID) or nil end

  function root:RefreshSlots()
    local bar = CurrentBar()
    if not bar then return end
    local assigned = RUI:GetHUDSlotAssignments(bar.id,className)
    local count = math.max(1,tonumber(bar.slotCount) or 1)
    local iconSize = math.max(36,math.min(56,tonumber(bar.iconSize) or 40))
    local gap = 6
    local visible = math.min(count,24)
    local columns
    if bar.orientation=="VERTICAL" then columns = math.ceil(visible/12) else columns = math.min(visible,12) end
    local rowsCount
    if bar.orientation=="VERTICAL" then rowsCount = math.min(visible,12) else rowsCount = math.ceil(visible/12) end
    local totalW = (columns*iconSize)+((columns-1)*gap)
    local totalH = (rowsCount*iconSize)+((rowsCount-1)*gap)
    local startX = -totalW/2
    local startY = totalH/2
    for i,slot in ipairs(slotFrames) do
      slot.index = i
      slot.tracker = assigned[i]
      if i<=visible then
        slot:Show()
        slot:SetSize(iconSize,iconSize)
        slot:ClearAllPoints()
        local col,row
        if bar.orientation=="VERTICAL" then col=math.floor((i-1)/12); row=(i-1)%12
        else col=(i-1)%12; row=math.floor((i-1)/12) end
        slot:SetPoint("CENTER",canvas,"CENTER",startX+(col*(iconSize+gap))+(iconSize/2),startY-(row*(iconSize+gap))-(iconSize/2))
        if slot.tracker then
          slot.icon:SetTexture(TrackerTexture(slot.tracker) or "Interface\\Icons\\INV_Misc_QuestionMark")
          slot.icon:Show(); slot.num:Hide()
        else
          slot.icon:Hide(); slot.num:SetText(tostring(i)); slot.num:Show()
        end
      else slot:Hide() end
    end
  end

  function root:RefreshBarSettings()
    local bar = CurrentBar()
    if not bar then return end
    barName:SetText(bar.name or "HUD Bar")
    orientation.text:SetText(bar.orientation=="VERTICAL" and "Vertical" or "Horizontal")
    slotsText:SetText(tostring(bar.slotCount or 1).." slots")
    sizeText:SetText(tostring(bar.iconSize or 36).." px")
  end

  function root:RefreshBars()
    local list = CurrentBars()
    if #list==0 then return end
    local pages = math.max(1,math.ceil(#list/5))
    if barPage>pages then barPage=pages end
    if barPage<1 then barPage=1 end
    local first = ((barPage-1)*5)+1
    local selectedExists = false
    for _,bar in ipairs(list) do if bar.id==selectedBarID then selectedExists=true break end end
    if not selectedExists then selectedBarID=list[1].id end
    for i,tab in ipairs(tabs) do
      local bar = list[first+i-1]
      if bar then
        tab:Show(); tab.text:SetText(bar.name or "HUD Bar"); SetActive(tab,bar.id==selectedBarID)
        tab:SetScript("OnClick",function() selectedBarID=bar.id; root:RefreshBars(); root:RefreshBarSettings(); root:RefreshSlots() end)
      else tab:Hide() end
    end
    prev:SetEnabled(barPage>1); prev:SetAlpha(barPage>1 and 1 or .35)
    nextb:SetEnabled(barPage<pages); nextb:SetAlpha(barPage<pages and 1 or .35)
    root:RefreshBarSettings(); root:RefreshSlots()
  end

  prev:SetScript("OnClick",function() if barPage>1 then barPage=barPage-1; root:RefreshBars() end end)
  nextb:SetScript("OnClick",function() local p=math.max(1,math.ceil(#CurrentBars()/5)); if barPage<p then barPage=barPage+1; root:RefreshBars() end end)

  orientation:SetScript("OnClick",function()
    local bar=CurrentBar(); if not bar then return end
    local nextOrientation = bar.orientation=="VERTICAL" and "HORIZONTAL" or "VERTICAL"
    RUI:UpdateHUDBar(bar.id,{orientation=nextOrientation},className)
    root:RefreshBarSettings(); root:RefreshSlots()
  end)
  slotsMinus:SetScript("OnClick",function() local bar=CurrentBar(); if bar then RUI:UpdateHUDBar(bar.id,{slotCount=(bar.slotCount or 1)-1},className); root:RefreshBarSettings(); root:RefreshSlots() end end)
  slotsPlus:SetScript("OnClick",function() local bar=CurrentBar(); if bar then RUI:UpdateHUDBar(bar.id,{slotCount=(bar.slotCount or 1)+1},className); root:RefreshBarSettings(); root:RefreshSlots() end end)
  sizeMinus:SetScript("OnClick",function() local bar=CurrentBar(); if bar then RUI:UpdateHUDBar(bar.id,{iconSize=(bar.iconSize or 36)-2},className); root:RefreshBarSettings(); root:RefreshSlots() end end)
  sizePlus:SetScript("OnClick",function() local bar=CurrentBar(); if bar then RUI:UpdateHUDBar(bar.id,{iconSize=(bar.iconSize or 36)+2},className); root:RefreshBarSettings(); root:RefreshSlots() end end)
  unlock:SetScript("OnClick",function()
    local bar=CurrentBar(); if not bar then return end
    local ok,msg=RUI:OpenHUDBarUnlockMode(className,bar.id); setStatus(msg,ok)
  end)
  sync:SetScript("OnClick",function()
    local bar=CurrentBar(); if not bar then return end
    local ok,msg=RUI:OpenHUDBarWeakAurasImport(bar.id,className); setStatus(msg,ok)
  end)

  -- new bar modal
  local modal = Box(workspace,{0.045,0.047,0.055,1})
  modal:SetSize(430,245)
  modal:SetPoint("CENTER")
  modal:SetFrameLevel(workspace:GetFrameLevel()+50)
  modal:Hide()
  local mtitle = Label(modal,"Create HUD Bar",19,TEXT); mtitle:SetPoint("TOPLEFT",20,-18)
  local msub = Label(modal,"Create an action-bar style group and choose its slot count.",9,MUTED); msub:SetPoint("TOPLEFT",mtitle,"BOTTOMLEFT",0,-5)
  local nameLabel=Label(modal,"BAR NAME",8,MUTED); nameLabel:SetPoint("TOPLEFT",20,-72)
  local nameEdit=Edit(modal,245,28); nameEdit:SetPoint("TOPLEFT",20,-88); nameEdit:SetText("Main Rotation 2")
  local countLabel=Label(modal,"SLOTS",8,MUTED); countLabel:SetPoint("TOPLEFT",285,-72)
  local countEdit=Edit(modal,50,28); countEdit:SetPoint("TOPLEFT",285,-88); countEdit:SetText("8")
  local h=Button(modal,"Horizontal",104,nil,false); h:SetPoint("TOPLEFT",20,-132)
  local v=Button(modal,"Vertical",90,nil,false); v:SetPoint("LEFT",h,"RIGHT",8,0)
  local createOrientation="HORIZONTAL"; SetActive(h,true)
  h:SetScript("OnClick",function() createOrientation="HORIZONTAL"; SetActive(h,true); SetActive(v,false) end)
  v:SetScript("OnClick",function() createOrientation="VERTICAL"; SetActive(h,false); SetActive(v,true) end)
  local create=Button(modal,"Create Bar",110,nil,true); create:SetPoint("BOTTOMLEFT",20,18)
  local cancel=Button(modal,"Cancel",80,function() modal:Hide() end,false); cancel:SetPoint("LEFT",create,"RIGHT",8,0)
  create:SetScript("OnClick",function()
    local bar=RUI:CreateHUDBar("custom",nameEdit:GetText(),createOrientation,tonumber(countEdit:GetText()) or 8,className)
    selectedBarID=bar.id; modal:Hide(); setStatus(bar.name.." created",true); root:RefreshBars()
  end)
  newBar:SetScript("OnClick",function() modal:Show() end)

  root:RefreshSelected()
  root:RefreshBars()
  return root
end

RUI._beta52HUDWorkspaceLoaded = true
RUI.beta52HUDWorkspaceSchema = 1

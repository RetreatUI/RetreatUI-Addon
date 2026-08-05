local RUI = RetreatUI
if not RUI then return end

local _, playerClass = UnitClass("player")
if playerClass ~= "DRUID" then return end

local Feral = {
    initialized = false,
    forceShown = false,
    lastEnergy = 0,
    lastEnergyTick = nil,
    mainSpells = {
        "Mangle (Cat)",
        "Shred",
        "Rake",
        "Rip",
        "Ferocious Bite",
        "Tiger's Fury",
    },
    utilitySpells = {
        "Barkskin",
        "Dash",
        "Feral Charge",
        "Faerie Fire (Feral)",
        "Innervate",
        "Rebirth",
        "Remove Curse",
        "Abolish Poison",
    },
    auraDefinitions = {
        { name = "Rake", unit = "target", filter = "HARMFUL", ownOnly = true },
        { name = "Rip", unit = "target", filter = "HARMFUL", ownOnly = true },
        { name = "Mangle", unit = "target", filter = "HARMFUL", ownOnly = false },
        { name = "Faerie Fire", unit = "target", filter = "HARMFUL", ownOnly = false },
        { name = "Clearcasting", unit = "player", filter = "HELPFUL", ownOnly = false },
        { name = "Tiger's Fury", unit = "player", filter = "HELPFUL", ownOnly = false },
    },
}

local function AuraMatches(definition, auraName, source)
    if not auraName then return false end

    local expected = string.lower(definition.name)
    local actual = string.lower(auraName)
    if actual ~= expected and not string.find(actual, expected, 1, true) then
        return false
    end

    if definition.ownOnly and source and source ~= "player" and source ~= "pet" then
        return false
    end

    return true
end

local function FindAura(definition)
    local scanner
    if definition.filter == "HELPFUL" then
        scanner = UnitBuff
    else
        scanner = UnitDebuff
    end

    if type(scanner) ~= "function" then
        scanner = UnitAura
    end
    if type(scanner) ~= "function" then
        return nil
    end

    for index = 1, 40 do
        local name, icon, count, _, duration, expirationTime, source
        if scanner == UnitAura then
            name, icon, count, _, duration, expirationTime, source = scanner(
                definition.unit,
                index,
                definition.filter
            )
        else
            name, icon, count, _, duration, expirationTime, source = scanner(definition.unit, index)
        end

        if not name then break end
        if AuraMatches(definition, name, source) then
            return {
                name = name,
                icon = icon,
                count = count,
                duration = duration,
                expirationTime = expirationTime,
                source = source,
            }
        end
    end

    return nil
end

local function CreateAuraIcon(parent, definition)
    local frame = RUI:CreateBackdropFrame(parent)
    frame:SetSize(30, 30)
    frame.definition = definition

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", 1, -1)
    frame.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.timer = frame:CreateFontString(nil, "OVERLAY")
    RUI:ApplyFont(frame.timer, 10, "OUTLINE")
    frame.timer:SetPoint("CENTER")

    frame.stack = frame:CreateFontString(nil, "OVERLAY")
    RUI:ApplyFont(frame.stack, 9, "OUTLINE")
    frame.stack:SetPoint("BOTTOMRIGHT", -2, 2)

    frame:Hide()
    return frame
end

local function LayoutVisibleIcons(row, icons, size, spacing)
    local visible = {}
    for _, icon in ipairs(icons) do
        if icon:IsShown() then
            visible[#visible + 1] = icon
        end
    end

    if #visible == 0 then
        row:Hide()
        return
    end

    row:Show()
    local width = #visible * size + math.max(0, #visible - 1) * spacing
    local firstX = -width / 2 + size / 2
    for index, icon in ipairs(visible) do
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", row, "CENTER", firstX + (index - 1) * (size + spacing), 0)
    end
end

function Feral:CreateComboPoints()
    self.comboPoints = {}
    local holder = CreateFrame("Frame", nil, self.energyHolder)
    holder:SetSize(300, 8)
    holder:SetPoint("BOTTOM", self.energyHolder, "TOP", 0, 5)
    self.comboHolder = holder

    local width = 34
    local spacing = 5
    local total = 5 * width + 4 * spacing
    local firstX = -total / 2 + width / 2

    for index = 1, 5 do
        local point = RUI:CreateBackdropFrame(holder)
        point:SetSize(width, 6)
        point:SetPoint("CENTER", holder, "CENTER", firstX + (index - 1) * (width + spacing), 0)
        point.fill = point:CreateTexture(nil, "ARTWORK")
        point.fill:SetPoint("TOPLEFT", 1, -1)
        point.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        point.fill:SetColorTexture(
            RUI.theme.combo[1],
            RUI.theme.combo[2],
            RUI.theme.combo[3],
            RUI.theme.combo[4] or 1
        )
        self.comboPoints[index] = point
    end
end

function Feral:CreateEnergyTick()
    local tick = CreateFrame("StatusBar", nil, self.energyHolder)
    tick:SetPoint("BOTTOMLEFT", self.energyHolder, "BOTTOMLEFT", 1, 1)
    tick:SetPoint("BOTTOMRIGHT", self.energyHolder, "BOTTOMRIGHT", -1, 1)
    tick:SetHeight(2)
    tick:SetMinMaxValues(0, 2)
    tick:SetStatusBarTexture(RUI.theme.texture)
    tick:SetStatusBarColor(
        RUI.theme.accent[1],
        RUI.theme.accent[2],
        RUI.theme.accent[3],
        0.95
    )
    tick:SetValue(0)
    self.energyTick = tick
end

function Feral:Initialize()
    if self.initialized then return end
    self.initialized = true

    self.root = CreateFrame("Frame", "RetreatUITBCFeralHUD", UIParent)
    self.root:SetSize(1, 1)
    self.root:SetPoint("CENTER", UIParent, "CENTER", 0, 27)

    self.auraRow = CreateFrame("Frame", nil, self.root)
    self.auraRow:SetSize(1, 30)
    self.auraRow:SetPoint("CENTER", self.root, "CENTER", 0, -139)
    self.auraIcons = {}
    for _, definition in ipairs(self.auraDefinitions) do
        self.auraIcons[#self.auraIcons + 1] = CreateAuraIcon(self.auraRow, definition)
    end

    self.energyHolder = RUI:CreateResourceBar(self.root, 300, 18)
    self.energyHolder:SetPoint("CENTER", self.root, "CENTER", 0, -180)
    self:CreateComboPoints()
    self:CreateEnergyTick()

    self.mainRow = RUI:CreateSpellRow(self.root, self.mainSpells)
    self.mainRow:SetPoint("CENTER", self.root, "CENTER", 0, -221)

    self.utilityRow = RUI:CreateSpellRow(self.root, self.utilitySpells)
    self.utilityRow:SetPoint("CENTER", self.root, "CENTER", 0, -263)

    self:UpdateAll()
    self:UpdateVisibility()
end

function Feral:IsCatFormActive()
    local powerType = UnitPowerType("player")
    return powerType == 3
end

function Feral:UpdateVisibility()
    if not self.root then return end

    if self.forceShown or self:IsCatFormActive() then
        self.root:Show()
    else
        self.root:Hide()
    end
end

function Feral:UpdateResources()
    if not self.energyHolder then return end

    local energy = UnitPower("player", 3) or 0
    local maximum = UnitPowerMax("player", 3) or 100
    if maximum <= 0 then maximum = 100 end

    self.energyHolder.bar:SetMinMaxValues(0, maximum)
    self.energyHolder.bar:SetValue(energy)
    self.energyHolder.bar.value:SetText(string.format("%d / %d", energy, maximum))

    local mana = UnitPower("player", 0) or 0
    self.energyHolder.bar.mana:SetText(string.format("Mana %d", mana))

    local gain = energy - (self.lastEnergy or energy)
    if gain >= 10 and gain <= 25 then
        self.lastEnergyTick = GetTime()
    end
    self.lastEnergy = energy

    if self.lastEnergyTick then
        local progress = GetTime() - self.lastEnergyTick
        if progress <= 2 then
            self.energyTick:SetValue(progress)
        else
            self.energyTick:SetValue(0)
        end
    end

    local comboPoints = GetComboPoints("player", "target") or 0
    for index, point in ipairs(self.comboPoints or {}) do
        point.fill:SetShown(index <= comboPoints)
    end
end

function Feral:UpdateAuras()
    if not self.auraIcons then return end

    local now = GetTime()
    for _, frame in ipairs(self.auraIcons) do
        local aura = FindAura(frame.definition)
        if aura then
            frame.icon:SetTexture(aura.icon)
            local remaining = 0
            if aura.expirationTime and aura.expirationTime > 0 then
                remaining = math.max(0, aura.expirationTime - now)
            end

            if remaining > 0 then
                frame.timer:SetText(remaining < 10 and string.format("%.1f", remaining) or string.format("%d", remaining))
            else
                frame.timer:SetText("")
            end
            frame.stack:SetText((aura.count or 0) > 1 and tostring(aura.count) or "")
            frame:Show()
        else
            frame:Hide()
        end
    end

    LayoutVisibleIcons(self.auraRow, self.auraIcons, 30, 4)
end

function Feral:UpdateRows()
    if not self.mainRow or not self.utilityRow then return end

    local mainLines = RUI:UpdateSpellRow(self.mainRow, 9)
    RUI:UpdateSpellRow(self.utilityRow, 100)

    self.utilityRow:ClearAllPoints()
    self.utilityRow:SetPoint(
        "CENTER",
        self.root,
        "CENTER",
        0,
        mainLines > 1 and -303 or -263
    )
end

function Feral:UpdateAll()
    if not self.initialized then return end
    self:UpdateResources()
    self:UpdateAuras()
    self:UpdateRows()
end

function Feral:OnEvent(event, unit)
    if not self.initialized then return end

    if event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_ENTERING_WORLD" then
        self:UpdateVisibility()
    end

    if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        self:UpdateRows()
        return
    end

    if event == "UNIT_AURA" and unit ~= "player" and unit ~= "target" then
        return
    end

    if event == "UNIT_POWER_UPDATE" and unit ~= "player" then
        return
    end

    self:UpdateAll()
end

function Feral:OnUpdate()
    if not self.initialized or not self.root:IsShown() then return end
    self:UpdateResources()
    self:UpdateAuras()
    self:UpdateRows()
end

RUI:RegisterModule("FeralDruid", Feral)

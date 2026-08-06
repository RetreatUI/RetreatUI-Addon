local RUI = RetreatUI
if not RUI then return end

local TRACKER_SIZE = 36
local TRACKER_SPACING = 4
local TRINKET_SLOTS = { 13, 14 }

local function Lower(value)
    return string.lower(tostring(value or ""))
end

local function GetPlayerRaceToken()
    local localizedRace, englishRace = UnitRace("player")
    return Lower(englishRace or localizedRace)
end

local function RaceMatches(sourceRace, playerRace)
    sourceRace = Lower(sourceRace)
    playerRace = Lower(playerRace)
    return playerRace ~= "" and string.find(sourceRace, playerRace, 1, true) ~= nil
end

local function AppendUnique(target, seen, value)
    if type(value) ~= "string" or value == "" or seen[value] then
        return
    end

    seen[value] = true
    target[#target + 1] = value
end

function RUI:GetPlayerRacialSpellNames()
    local main = {}
    local utility = {}
    local seen = {}
    local playerRace = GetPlayerRaceToken()
    local generated = self.generatedTBCData or {}

    for _, racial in ipairs(generated.racials or {}) do
        if RaceMatches(racial.race, playerRace)
            and self:IsSpellLearned(racial.name) then
            if racial.hudRow == "Main" then
                AppendUnique(main, seen, racial.name)
            elseif racial.hudRow == "Utility" then
                AppendUnique(utility, seen, racial.name)
            end
        end
    end

    return main, utility
end

local function SetCooldown(cooldown, startTime, duration, enabled)
    if not cooldown then return end

    startTime = tonumber(startTime) or 0
    duration = tonumber(duration) or 0
    enabled = enabled == nil and 1 or enabled

    if duration > 1.5 and enabled ~= 0 then
        cooldown:Show()
        if type(cooldown.SetCooldown) == "function" then
            cooldown:SetCooldown(startTime, duration)
        elseif type(CooldownFrame_Set) == "function" then
            CooldownFrame_Set(cooldown, startTime, duration, enabled)
        end
    else
        cooldown:Hide()
    end
end

local function GetAura(unit, filter, spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 or not UnitExists(unit) then
        return nil
    end

    local expectedName = GetSpellInfo(spellID)
    local scanner = filter == "HARMFUL" and UnitDebuff or UnitBuff
    if type(scanner) ~= "function" then
        scanner = UnitAura
    end
    if type(scanner) ~= "function" then
        return nil
    end

    for index = 1, 40 do
        local name, rank, icon, count, debuffType, duration, expirationTime,
            source, isStealable, shouldConsolidate, auraSpellID

        if scanner == UnitAura then
            name, rank, icon, count, debuffType, duration, expirationTime,
                source, isStealable, shouldConsolidate, auraSpellID = scanner(unit, index, filter)
        else
            name, rank, icon, count, debuffType, duration, expirationTime,
                source, isStealable, shouldConsolidate, auraSpellID = scanner(unit, index)
        end

        if not name then break end
        if tonumber(auraSpellID) == spellID or (expectedName and name == expectedName) then
            return {
                name = name,
                icon = icon,
                count = tonumber(count) or 0,
                duration = tonumber(duration) or 0,
                expirationTime = tonumber(expirationTime) or 0,
                source = source,
            }
        end
    end

    return nil
end

local function FormatRemaining(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then return "" end
    if seconds < 10 then
        return string.format("%.1f", seconds)
    end
    return string.format("%d", math.ceil(seconds))
end

local function CreateTrinketIcon(parent, slot)
    local frame = RUI:CreateBackdropFrame(parent)
    frame:SetSize(TRACKER_SIZE, TRACKER_SIZE)
    frame.slot = slot
    frame.itemID = nil
    frame.wasProcActive = false
    frame.lastProcAt = nil

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", 1, -1)
    frame.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints(frame.icon)
    if type(frame.cooldown.SetDrawEdge) == "function" then
        frame.cooldown:SetDrawEdge(false)
    end

    frame.timer = frame:CreateFontString(nil, "OVERLAY")
    RUI:ApplyFont(frame.timer, 11, "OUTLINE")
    frame.timer:SetPoint("CENTER")

    frame.stack = frame:CreateFontString(nil, "OVERLAY")
    RUI:ApplyFont(frame.stack, 9, "OUTLINE")
    frame.stack:SetPoint("BOTTOMRIGHT", -2, 2)

    frame:SetScript("OnEnter", function(selfFrame)
        if not GameTooltip or not selfFrame.itemID then return end
        GameTooltip:SetOwner(selfFrame, "ANCHOR_RIGHT")
        if type(GameTooltip.SetInventoryItem) == "function" then
            GameTooltip:SetInventoryItem("player", selfFrame.slot)
        elseif type(GameTooltip.SetHyperlink) == "function" then
            GameTooltip:SetHyperlink("item:" .. tostring(selfFrame.itemID))
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    frame:Hide()
    return frame
end

function RUI:CreateTrinketTracker(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(TRACKER_SIZE * 2 + TRACKER_SPACING, TRACKER_SIZE)
    row.icons = {}

    local totalWidth = TRACKER_SIZE * #TRINKET_SLOTS + TRACKER_SPACING * (#TRINKET_SLOTS - 1)
    local firstX = -totalWidth / 2 + TRACKER_SIZE / 2

    for index, slot in ipairs(TRINKET_SLOTS) do
        local icon = CreateTrinketIcon(row, slot)
        icon:SetPoint(
            "CENTER",
            row,
            "CENTER",
            firstX + (index - 1) * (TRACKER_SIZE + TRACKER_SPACING),
            0
        )
        row.icons[#row.icons + 1] = icon
    end

    return row
end

local function GetInventoryCooldown(slot, itemID)
    local startTime, duration, enabled
    if type(GetInventoryItemCooldown) == "function" then
        startTime, duration, enabled = GetInventoryItemCooldown("player", slot)
    end
    if (not duration or duration <= 0) and itemID and type(GetItemCooldown) == "function" then
        startTime, duration, enabled = GetItemCooldown(itemID)
    end
    return tonumber(startTime) or 0, tonumber(duration) or 0, enabled
end

local function UpdateTrinketIcon(frame)
    local itemID = GetInventoryItemID("player", frame.slot)
    if not itemID then
        frame.itemID = nil
        frame.mapping = nil
        frame.wasProcActive = false
        frame.lastProcAt = nil
        frame.timer:SetText("")
        frame.stack:SetText("")
        frame.cooldown:Hide()
        frame:Hide()
        return false
    end

    if frame.itemID ~= itemID then
        frame.itemID = itemID
        frame.wasProcActive = false
        frame.lastProcAt = nil
    end

    local generated = RUI.generatedTBCData or {}
    frame.mapping = generated.trinkets and generated.trinkets[itemID] or nil

    local texture
    if type(GetInventoryItemTexture) == "function" then
        texture = GetInventoryItemTexture("player", frame.slot)
    end
    if not texture and type(GetItemIcon) == "function" then
        texture = GetItemIcon(itemID)
    end
    frame.icon:SetTexture(texture)

    local itemSpellName, itemSpellID
    if type(GetItemSpell) == "function" then
        itemSpellName, itemSpellID = GetItemSpell(itemID)
    end

    local mapping = frame.mapping
    local auraSpellID = mapping and tonumber(mapping.onUseBuffID) or 0
    if not auraSpellID or auraSpellID <= 0 then
        auraSpellID = mapping and tonumber(mapping.procBuffID) or 0
    end
    if (not auraSpellID or auraSpellID <= 0) and itemSpellID then
        auraSpellID = tonumber(itemSpellID) or 0
    end

    local aura
    if mapping and mapping.onTarget then
        aura = GetAura("target", "HARMFUL", auraSpellID)
    else
        aura = GetAura("player", "HELPFUL", auraSpellID)
    end

    local now = GetTime()
    if aura and not frame.wasProcActive then
        frame.lastProcAt = now
    end
    frame.wasProcActive = aura ~= nil

    local cooldownStart, cooldownDuration, cooldownEnabled = GetInventoryCooldown(frame.slot, itemID)
    local cooldownIsActive = cooldownDuration > 1.5 and cooldownStart > 0

    if cooldownIsActive then
        SetCooldown(frame.cooldown, cooldownStart, cooldownDuration, cooldownEnabled)
    elseif frame.lastProcAt and mapping and tonumber(mapping.icd) and tonumber(mapping.icd) > 1.5 then
        local icd = tonumber(mapping.icd)
        local elapsed = now - frame.lastProcAt
        if elapsed < icd then
            SetCooldown(frame.cooldown, frame.lastProcAt, icd, 1)
        else
            frame.cooldown:Hide()
        end
    else
        frame.cooldown:Hide()
    end

    if aura then
        local remaining = aura.expirationTime > 0 and math.max(0, aura.expirationTime - now) or 0
        frame.timer:SetText(FormatRemaining(remaining))
        frame.stack:SetText(aura.count > 1 and tostring(aura.count) or "")
        frame.icon:SetVertexColor(1, 1, 1, 1)
    elseif frame.lastProcAt and mapping and tonumber(mapping.icd) and tonumber(mapping.icd) > 0 then
        local remaining = math.max(0, tonumber(mapping.icd) - (now - frame.lastProcAt))
        frame.timer:SetText(remaining > 0 and FormatRemaining(remaining) or "")
        frame.stack:SetText("")
        frame.icon:SetVertexColor(0.7, 0.7, 0.7, 1)
    else
        frame.timer:SetText("")
        frame.stack:SetText("")
        frame.icon:SetVertexColor(1, 1, 1, 1)
    end

    frame.hasOnUse = itemSpellName ~= nil
    frame:Show()
    return true
end

function RUI:UpdateTrinketTracker(row)
    if not row or not row.icons then return end

    local visible = 0
    for _, icon in ipairs(row.icons) do
        if UpdateTrinketIcon(icon) then
            visible = visible + 1
        end
    end

    if visible > 0 then
        row:Show()
    else
        row:Hide()
    end
end

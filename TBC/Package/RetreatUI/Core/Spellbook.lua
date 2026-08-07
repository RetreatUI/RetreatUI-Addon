local RUI = RetreatUI
if not RUI then return end

local function NormalizeName(value)
    return string.lower(tostring(value or ""))
end

local function AddSpell(name, spellID, texture, bookIndex)
    if not name or name == "" then return end

    local record = {
        name = name,
        spellID = tonumber(spellID),
        texture = texture,
        bookIndex = bookIndex,
    }

    RUI.spellbook.byName[NormalizeName(name)] = record
    if record.spellID then
        RUI.spellbook.byID[record.spellID] = record
    end
end

local function ScanLegacySpellbook()
    if type(GetNumSpellTabs) ~= "function"
        or type(GetSpellTabInfo) ~= "function"
        or type(GetSpellBookItemName) ~= "function" then
        return false
    end

    local tabs = GetNumSpellTabs() or 0
    for tabIndex = 1, tabs do
        local _, _, offset, count = GetSpellTabInfo(tabIndex)
        offset = tonumber(offset) or 0
        count = tonumber(count) or 0

        for slot = offset + 1, offset + count do
            local name = GetSpellBookItemName(slot, BOOKTYPE_SPELL)
            local itemType, actionID = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL)
            if name and itemType ~= "FUTURESPELL" then
                local texture = GetSpellBookItemTexture and GetSpellBookItemTexture(slot, BOOKTYPE_SPELL)
                AddSpell(name, actionID, texture, slot)
            end
        end
    end

    return true
end

local function ScanModernSpellbook()
    local api = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if not api or not bank
        or type(api.GetNumSpellBookSkillLines) ~= "function"
        or type(api.GetSpellBookSkillLineInfo) ~= "function"
        or type(api.GetSpellBookItemName) ~= "function" then
        return false
    end

    local lines = api.GetNumSpellBookSkillLines() or 0
    for lineIndex = 1, lines do
        local info = api.GetSpellBookSkillLineInfo(lineIndex)
        if info then
            local offset = tonumber(info.itemIndexOffset) or 0
            local count = tonumber(info.numSpellBookItems) or 0
            for slot = offset + 1, offset + count do
                local name = api.GetSpellBookItemName(slot, bank)
                local itemType, actionID
                if type(api.GetSpellBookItemType) == "function" then
                    itemType, actionID = api.GetSpellBookItemType(slot, bank)
                end
                if name and itemType ~= "FUTURESPELL" then
                    local texture
                    if type(api.GetSpellBookItemTexture) == "function" then
                        texture = api.GetSpellBookItemTexture(slot, bank)
                    end
                    AddSpell(name, actionID, texture, slot)
                end
            end
        end
    end

    return true
end

function RUI:ScanSpellbook()
    self.spellbook.byName = {}
    self.spellbook.byID = {}

    if not ScanLegacySpellbook() then
        ScanModernSpellbook()
    end
end

function RUI:GetLearnedSpell(name)
    return self.spellbook.byName[NormalizeName(name)]
end

function RUI:IsSpellLearned(name)
    return self:GetLearnedSpell(name) ~= nil
end

function RUI:GetSpellTextureSafe(name)
    local record = self:GetLearnedSpell(name)
    if record and record.texture then
        return record.texture
    end

    if type(GetSpellTexture) == "function" then
        return GetSpellTexture(name)
    end

    local _, _, texture = GetSpellInfo(name)
    return texture
end

-- Bloodmage proc tracking: Vanthir's Gift.
local RUI = _G.RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then
    return
end

local database = RUI:GetClassSpellDatabase("Bloodmage")
database.spells = database.spells or {}

local spellID = 1219817
for _, record in ipairs(database.spells) do
    if tonumber(record.id) == spellID then
        record.name = "Vanthir's Gift"
        record.auraTracker = true
        record.targetDebuff = nil
        record.targetResource = nil
        record.category = "Procs/Buffs"
        return
    end
end

table.insert(database.spells, {
    name = "Vanthir's Gift",
    id = spellID,
    auraTracker = true,
    category = "Procs/Buffs",
})

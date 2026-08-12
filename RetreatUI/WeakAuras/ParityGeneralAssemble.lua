local RUI = RetreatUI
if not RUI then return end
RUI.parityWeakAuras = RUI.parityWeakAuras or {}
local chunks = RUI.parityWeakAuraChunks or {}
RUI.parityWeakAuras.core = table.concat(chunks, "")
RUI.parityWeakAuraChunks = nil

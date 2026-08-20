local RUI = RetreatUI
if not RUI then return end

-- beta.43: source -> applied effect identities are generated from the
-- Professional Audit catalog. Keep this compatibility file intentionally
-- data-free so older load orders do not reintroduce handwritten mappings.
RUI._trackerMetadataOverrides = true

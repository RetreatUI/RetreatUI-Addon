# RetreatUI v1.1.7-beta.28 - Ascension Profile Adapter Audit

This prerelease switches RetreatUI's profile integration assumptions to the exact Project Ascension addon builds supplied from the launcher environment.

## Audited addon builds

- WeakAuras 5.21.2 (`X-Flavor: 3.3.5`)
- ElvUI 7.27
- Details `#Details.20240508.12893.160`
- TurboPlates 1.4.5
- DBM 5.21 / revision 5021

## What changed

- Adds a shared Ascension profile adapter layer for ElvUI, Details, TurboPlates, WeakAuras and DBM.
- Adds `/rui compat` as a read-only in-game capability check.
- ElvUI capture/import now targets its native Distributor `!E1!` profile format.
- Details capture/import now targets `ExportCurrentProfile` / `ImportProfile` directly and no longer assumes a `D!ProfileV2` prefix.
- TurboPlates profile capture uses validated data-only `TurboPlatesDB` snapshots because the supplied 1.4.5 build keeps its native `!TP1!` import/export API private inside the addon namespace.
- TurboPlates automatic apply is version-gated to the exact audited 1.4.5 build and backs up the previous DB first.
- DBM core capture targets the actual Ascension variables `DBM_SavedOptions` and `DBT_SavedOptions`.
- The separately supplied DBM SavedVariables update package is explicitly not used because it targets the newer `DBM_AllSavedOptions` / `DBT_AllPersistentOptions` model and does not match Ascension DBM 5.21.
- Adds a native WeakAuras import-envelope bridge which uses `WeakAuras.Import` and never calls `WeakAuras.Add` for Tracker Builder generated content.
- Removes the old bundled per-class WeakAura payloads and direct Add installer from the RetreatUI TOC load path.
- Legacy installer WeakAura steps now safely tell the user to use `/rui tracker` instead of installing a bundled class package.
- Adds a data-only unified profile snapshot API containing current tracker data plus native ElvUI and Details exports, TurboPlates data, and DBM core data.

## WeakAuras safety rule

Tracker Builder generated WeakAuras will use the supplied Ascension WeakAuras 5.21.2 native import/update window. RetreatUI does not decode WA transmissions itself, does not call `WeakAuras.Add`, and does not generate custom trigger Lua for the basic tracker templates.

## First in-game test

1. Update to beta.28 through the Beta launcher channel.
2. Log into CoA normally.
3. Run `/rui compat`.
4. Confirm the five addon lines show the expected versions and APIs.
5. Open `/rui tracker` and confirm beta.27 selections/layout still work unchanged.
6. Do not run a generated WeakAura import yet; beta.28 is the adapter/capability verification pass.

Stable remains untouched.

Author: Retreat

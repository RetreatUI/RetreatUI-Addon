from pathlib import Path

ROOTS = (Path('RetreatUI'), Path('RetreatUI_Classes'))
FORBIDDEN = (
    'IsSpellKnown',
    'GetInspectSpecialization',
    'NotifyInspect',
    'INSPECT_TALENT_READY',
    'C_CharacterAdvancement',
    'UnitTalentRankByID',
    'UnitKnownID',
    'GetNumTalentTabs',
    'GetTalentTabInfo',
    'GetActiveTalentGroup',
    'SpecializationUtil',
    'GetUnitSpecialization',
    'GetUnitSpec',
    'UnitSpec(',
)

violations = []
for root in ROOTS:
    for path in root.rglob('*.lua'):
        text = path.read_text(encoding='utf-8')
        for token in FORBIDDEN:
            if token in text:
                violations.append(f'{path}: {token}')
if violations:
    raise SystemExit('Unsafe Ascension learned-state/inspect APIs remain:\n' + '\n'.join(violations))

for removed in (
    Path('RetreatUI/Core/PartyInterruptCuration.lua'),
    Path('RetreatUI/Core/PartyUtilityCombatLogHotfix.lua'),
):
    if removed.exists():
        raise SystemExit(f'Retired tracker file still exists: {removed}')

buff = Path('RetreatUI/Core/BuffManager.lua').read_text(encoding='utf-8')
if 'Interface\\Buttons\\WHITE8X8' in buff:
    raise SystemExit('Malformed BuffManager texture path still exists')
if 'Interface\\\\Buttons\\\\WHITE8X8' not in buff:
    raise SystemExit('Correct BuffManager texture path missing')

spell_db = Path('RetreatUI/Data/SpellDatabase.lua').read_text(encoding='utf-8')
if 'function RUI:IsAdvancementEntryLearned(_)\n  return nil\nend' not in spell_db:
    raise SystemExit('SpellDatabase must keep Character Advancement learned-state disabled')

registry = Path('RetreatUI/Core/ClassRegistry.lua').read_text(encoding='utf-8')
if 'self.spellbook.idSet[spellID] == true' not in registry:
    raise SystemExit('ClassRegistry must resolve spell IDs from the live spellbook only')

toc = Path('RetreatUI/RetreatUI.toc').read_text(encoding='utf-8')
if 'Core\\ReleaseChangelog113Beta2.lua' not in toc:
    raise SystemExit('beta.2 changelog is not loaded by the core TOC')
if toc.index('Core\\ReleaseChangelog112.lua') > toc.index('Core\\ReleaseChangelog113Beta2.lua'):
    raise SystemExit('beta.2 changelog must load after the stable 1.1.2 changelog')

print('RetreatUI Ascension crash-safety checks passed')

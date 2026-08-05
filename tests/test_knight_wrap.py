from pathlib import Path

path = Path('RetreatUI_Classes/KnightOfXoroth/HUD.lua')
text = path.read_text(encoding='utf-8')
checks = {
    'nine-icon main limit': 'local MAIN_FIRST_LINE_MAXIMUM = 9',
    'overflow vertical placement': 'y = -(size + MAIN_WRAP_GAP)',
    'wrapped state': 'row.__ruiMainBarWrapped = overflowCount > 0',
    'first-line count': 'row.__ruiMainBarFirstLineCount = firstCount',
    'overflow count': 'row.__ruiMainBarOverflowCount = overflowCount',
    'utility reposition': 'PositionUtilityRow()',
    'utility shift': 'shift = -((38 + MAIN_WRAP_GAP) * MainRowScale())',
    'runtime marker': 'RUI._knightCustomMainWrapInstalled = true',
}
missing = [name for name, needle in checks.items() if needle not in text]
if missing:
    raise SystemExit('Knight of Xoroth wrap checks missing: ' + ', '.join(missing))
if text.count('BuildRow(root.coreRow') < 1 or text.count('BuildRow(root.utilityRow') < 1:
    raise SystemExit('Knight HUD no longer builds both action rows')
print('Knight of Xoroth 9-plus-rest wrapping checks passed')

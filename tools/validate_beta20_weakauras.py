#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / "RetreatUI" / "Data" / "WeakAurasBeta20"
files = sorted(folder.glob("*.lua"))
assert len(files) == 11, f"expected 11 shard files, found {len(files)}"

expected = {
    "Barbarian", "Bloodmage", "Chronomancer", "Cultist", "Felsworn", "Guardian",
    "Knight of Xoroth", "Necromancer", "Primalist", "Pyromancer", "Ranger", "Reaper",
    "Runemaster", "Starcaller", "Stormbringer", "Sun Cleric", "Templar", "Tinker",
    "Venomancer", "Witch Doctor", "Witch Hunter",
}
seen = set()
for path in files:
    text = path.read_text(encoding="utf-8")
    assert "!WA:2!" in text, f"missing WeakAuras export in {path.name}"
    for name in re.findall(r'classes\["([^"]+)"\]\s*=', text):
        assert name not in seen, f"duplicate class payload: {name}"
        seen.add(name)

assert seen == expected, f"class mismatch: missing={sorted(expected-seen)} extra={sorted(seen-expected)}"
print("beta.20 WeakAuras: 21/21 unique CoA class payloads present")

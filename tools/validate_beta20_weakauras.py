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

finalizer = (ROOT / "RetreatUI" / "Data" / "WeakAurasBeta20Finalize.lua").read_text(encoding="utf-8")
assert "count == 21" in finalizer

toc = (ROOT / "RetreatUI" / "RetreatUI.toc").read_text(encoding="utf-8")
for path in files:
    assert "Data\\WeakAurasBeta20\\" + path.name in toc, f"TOC does not load {path.name}"
assert toc.index("Data\\WeakAurasBeta20ShardBridge.lua") < toc.index("Data\\WeakAurasBeta20\\01_Barbarian_Bloodmage.lua")
assert toc.index("Data\\WeakAurasBeta20\\11_WitchHunter.lua") < toc.index("Data\\WeakAurasBeta20Finalize.lua")
assert toc.index("Data\\WeakAurasBeta20Finalize.lua") < toc.index("Integrations\\WeakAurasBeta20.lua")

print("beta.20 WeakAuras validation passed: 21/21 unique CoA payloads and canonical load order")

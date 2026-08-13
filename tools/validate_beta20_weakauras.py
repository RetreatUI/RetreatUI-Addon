#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "tools/generate_beta20_weakauras.py"
OUTPUT = ROOT / "RetreatUI/Data/WeakAurasBeta20Payloads.lua"
TOC = ROOT / "RetreatUI/RetreatUI.toc"
EXPECTED = {
    "Barbarian", "Bloodmage", "Chronomancer", "Cultist", "Felsworn", "Guardian",
    "Knight of Xoroth", "Necromancer", "Primalist", "Pyromancer", "Ranger", "Reaper",
    "Runemaster", "Starcaller", "Stormbringer", "Sun Cleric", "Templar", "Tinker",
    "Venomancer", "Witch Doctor", "Witch Hunter",
}

committed = OUTPUT.read_text(encoding="utf-8")
try:
    subprocess.run(["python3", str(GENERATOR)], cwd=ROOT, check=True)
    regenerated = OUTPUT.read_text(encoding="utf-8")
finally:
    OUTPUT.write_text(committed, encoding="utf-8")

assert committed == regenerated, "committed beta.20 WeakAuras registry differs from generator output"
assert 'weakAurasVersion = "5.21.2"' in committed
assert 'generatedFor = "1.1.7-beta.20"' in committed
assert 'classPayloadCount = 21' in committed
assert 'general = "!WA:2!' in committed

classes = re.findall(r'^    \["([^"]+)"\] = "!WA:2!', committed, re.MULTILINE)
assert len(classes) == 21, f"expected 21 class payloads, found {len(classes)}"
assert len(classes) == len(set(classes)), "duplicate class payload registration"
assert set(classes) == EXPECTED, f"class mismatch: missing={sorted(EXPECTED-set(classes))} extra={sorted(set(classes)-EXPECTED)}"

source = GENERATOR.read_text(encoding="utf-8")
assert "use_spellknown" not in source.lower()
assert "Spell Known load condition" in source
assert '"yOffset": -189' in source
assert "y=47" in source and "y=-17" in source and "y=-239" in source

toc = TOC.read_text(encoding="utf-8")
assert "Data\\WeakAurasBeta20Payloads.lua" in toc
assert "Data\\WeakAurasBeta20\\" not in toc
assert "WeakAurasBeta20ShardBridge.lua" not in toc
assert "WeakAurasBeta20Finalize.lua" not in toc
assert toc.index("Data\\WeakAurasBeta20Payloads.lua") < toc.index("Integrations\\WeakAurasBeta20.lua")

assert not (ROOT / "RetreatUI/Data/WeakAurasBeta20").exists()
assert not (ROOT / "RetreatUI/Data/WeakAurasBeta20Finalize.lua").exists()
assert not (ROOT / "RetreatUI/Data/WeakAurasBeta20ShardBridge.lua").exists()

print("beta.20 WeakAuras validation passed: generator-exact General + 21/21 CoA payloads")

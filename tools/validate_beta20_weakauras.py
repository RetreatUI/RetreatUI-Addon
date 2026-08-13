#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / "RetreatUI" / "Data" / "WeakAurasBeta20"
files = sorted(folder.glob("*.lua"))
assert len(files) == 11, f"expected 11 shard files, found {len(files)}"

class_entries = 0
for path in files:
    text = path.read_text(encoding="utf-8")
    assert "!WA:2!" in text, f"missing WeakAuras export in {path.name}"
    class_entries += text.count('classes["')

assert class_entries == 21, f"expected 21 class payloads, found {class_entries}"
print("beta.20 WeakAuras: 21/21 physical class payloads present")

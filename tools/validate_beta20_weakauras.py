#!/usr/bin/env python3
"""Hard validation for the beta.20 CoA WeakAuras generator.

This validator executes the build-time generator in-memory and inspects the
actual WeakAuras transmission tables before they are serialized. It prevents
regressions that caused the beta.20 test failures: missing class payloads,
unsafe Spell Known load filters, wrong WeakAuras metadata, and drift from the
reference HUD coordinates.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GEN_PATH = ROOT / "tools" / "generate_beta20_weakauras.py"
CLASS_ROOT = ROOT / "RetreatUI_Classes"

spec = importlib.util.spec_from_file_location("beta20_generator", GEN_PATH)
if not spec or not spec.loader:
    raise SystemExit("Could not load beta.20 WeakAuras generator")
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)

EXPECTED_CLASSES = set(g.CLASS_NAMES)
EXPECTED_COUNT = 21
transmissions: list[dict] = []
original_export = g.export_wa


def walk(value, path="root"):
    if isinstance(value, dict):
        if "use_spellknown" in value or "spellknown" in value:
            raise AssertionError(f"Unsafe Spell Known load key found at {path}")
        for key, child in value.items():
            walk(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            walk(child, f"{path}[{index}]")


def find_display(tx: dict, display_id: str):
    root = tx.get("d")
    if isinstance(root, dict) and root.get("id") == display_id:
        return root
    for child in tx.get("c") or []:
        if isinstance(child, dict) and child.get("id") == display_id:
            return child
    return None


def validate_transmission(tx: dict):
    assert tx.get("s") == "5.21.2", f"Wrong WeakAuras version metadata: {tx.get('s')}"
    assert tx.get("v") == 2000, f"Wrong transmission version: {tx.get('v')}"
    walk(tx)

    for display in [tx.get("d")] + list(tx.get("c") or []):
        if isinstance(display, dict):
            assert display.get("internalVersion") == 90, (
                display.get("id"), display.get("internalVersion")
            )

    root_id = (tx.get("d") or {}).get("id")
    if root_id == "Core & Essentials":
        anchor = find_display(tx, "Class Power Bar")
        assert anchor, "General payload is missing Class Power Bar"
        assert anchor.get("xOffset") == 0
        assert anchor.get("yOffset") == -189
        assert anchor.get("width") == 348
        assert anchor.get("height") == 4
    elif isinstance(root_id, str) and root_id.endswith(" Class Pack"):
        class_name = root_id[:-11]
        main = find_display(tx, f"Main - {class_name}")
        aura = find_display(tx, f"Aura Bar - {class_name}")
        bars = find_display(tx, f"Dynamic Bars - {class_name}")
        assert main and aura and bars, f"Missing required HUD groups for {class_name}"
        assert main.get("yOffset") == -17
        assert main.get("grow") == "CUSTOM"
        grow = main.get("customGrow") or ""
        assert "firstRowLimit = 9" in grow
        assert "secondRowLimit = 9" in grow
        assert "lastRowLimit = 8" in grow
        assert aura.get("yOffset") == 47
        assert bars.get("yOffset") == 0
        aux = find_display(tx, f"Aux Bar - {class_name}")
        if aux:
            assert aux.get("yOffset") == -239


def capture_export(tx: dict):
    validate_transmission(tx)
    transmissions.append(tx)
    return original_export(tx)


g.export_wa = capture_export

# The generator's canonical source is RetreatUI_Classes/*/Data.lua. Validate
# the exact same files here; SpellDatabase.lua is runtime glue and is not the
# beta.20 payload source of truth.
parsed = []
for path in sorted(CLASS_ROOT.glob("*/Data.lua")):
    entry = g.parse_class(path)
    if entry:
        parsed.append(entry)

actual_classes = {name for name, _, _ in parsed}
assert actual_classes == EXPECTED_CLASSES, (
    f"Class mismatch. Missing={sorted(EXPECTED_CLASSES - actual_classes)} "
    f"Extra={sorted(actual_classes - EXPECTED_CLASSES)}"
)
assert len(parsed) == EXPECTED_COUNT

general = g.build_general()
assert general.startswith("!WA:2!")

for class_name, resources, spells in parsed:
    payload = g.build_class(class_name, resources, spells)
    assert payload.startswith("!WA:2!"), class_name

assert len(transmissions) == EXPECTED_COUNT + 1

registry_path = ROOT / "RetreatUI" / "Data" / "WeakAurasBeta20Payloads.lua"
registry = registry_path.read_text(encoding="utf-8")
assert 'weakAurasVersion = "5.21.2"' in registry
assert "classPayloadCount = 21" in registry
for class_name in sorted(EXPECTED_CLASSES):
    assert f'["{class_name}"] = "!WA:2!' in registry, class_name

print("beta.20 WeakAuras validation passed")
print("- General payload: present")
print("- CoA class payloads: 21/21")
print("- WeakAuras schema: 5.21.2 / internalVersion 90")
print("- Spell Known load filters: none")
print("- HUD geometry: reference coordinates verified")

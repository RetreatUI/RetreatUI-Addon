#!/usr/bin/env python3
"""Generate the compact CoA Tracker Builder catalog from the Professional Audit workbook.

Usage:
  python tools/generate_tracker_catalog.py "RetreatUI Spell Database — Professional Audit.xlsx"

Output:
  RetreatUI/Data/GeneratedSpellAuditCatalog.lua

The generated file intentionally does not embed descriptions or spell names.
The 3.3.5 client resolves names/icons from the spell ID. This keeps the full
21-class audit catalog small while preserving spec/category/cooldown/duration/
charge/stack/related-aura hints used by RetreatUI.
"""
from __future__ import annotations

import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
RID = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
OUTPUT = Path("RetreatUI/Data/GeneratedSpellAuditCatalog.lua")
SHEET_NAME = "CoA • All Spells"
CATEGORY_CODE = {"Utility": "U", "Offensive": "O", "Defensive": "D", "Interrupts": "I"}


def shared_strings(zf: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in zf.namelist():
        return []
    root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
    return [
        "".join((node.text or "") for node in si.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t"))
        for si in root.findall("m:si", NS)
    ]


def sheet_path(zf: zipfile.ZipFile, name: str) -> str:
    workbook = ET.fromstring(zf.read("xl/workbook.xml"))
    rid = None
    for sheet in workbook.find("m:sheets", NS):
        if sheet.attrib.get("name") == name:
            rid = sheet.attrib[RID]
            break
    if not rid:
        raise RuntimeError(f"Sheet not found: {name}")
    rels = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
    for rel in rels:
        if rel.attrib.get("Id") == rid:
            target = rel.attrib["Target"]
            return target if target.startswith("xl/") else "xl/" + target
    raise RuntimeError(f"Relationship not found for: {name}")


def cell_value(cell, shared: list[str]) -> str:
    ctype = cell.attrib.get("t")
    if ctype == "inlineStr":
        inline = cell.find("m:is", NS)
        return "" if inline is None else "".join((n.text or "") for n in inline.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t"))
    value = cell.find("m:v", NS)
    if value is None:
        return ""
    raw = value.text or ""
    return shared[int(raw)] if ctype == "s" else raw


def workbook_rows(path: Path):
    with zipfile.ZipFile(path) as zf:
        shared = shared_strings(zf)
        root = ET.fromstring(zf.read(sheet_path(zf, SHEET_NAME)))
        for row in root.findall(".//m:sheetData/m:row", NS):
            values = {}
            for cell in row.findall("m:c", NS):
                match = re.match(r"([A-Z]+)", cell.attrib.get("r", ""))
                if match:
                    values[match.group(1)] = cell_value(cell, shared)
            yield int(row.attrib.get("r", 0)), values


def seconds_from(description: str, keyword: str) -> float:
    text = description.lower()
    patterns = (
        (r"([\d.]+)\s*(?:hr|hour)s?\s+" + keyword, 3600),
        (r"([\d.]+)\s*mins?\s+" + keyword, 60),
        (r"([\d.]+)\s*secs?\s+" + keyword, 1),
    )
    for pattern, multiplier in patterns:
        match = re.search(pattern, text)
        if match:
            return float(match.group(1)) * multiplier
    return 0


def hints(name: str, description: str, category: str, interrupt: str):
    low = description.lower()
    lname = name.lower()
    cooldown = seconds_from(description, "cooldown")
    recharge = seconds_from(description, "recharge")
    charge_match = re.search(r"(\d+)\s+charges?", low)
    charges = int(charge_match.group(1)) if charge_match else 0

    duration = 0.0
    duration_match = re.search(r"\bfor\s+([\d.]+)\s*(sec|secs|second|seconds|min|mins|minute|minutes)\b", low)
    if duration_match:
        duration = float(duration_match.group(1)) * (60 if duration_match.group(2).startswith("min") else 1)

    stacks = 0
    for pattern in (r"stacking\s+(?:up\s+to\s+)?(\d+)\s+times?", r"stacking\s+(?:up\s+to\s+)?(\d+)\s+stacks?"):
        match = re.search(pattern, low)
        if match:
            stacks = int(match.group(1))
            break

    related = sorted({int(value) for value in re.findall(r"\[Spell ID\s+(\d+)\]", description, re.I)})
    passive = "passive" in low
    advanced_words = (
        "visual", " trigger", "trigger ", "dummy", "test ", " test", "reset ", "remove ",
        " check", "check ", "applier", "proc source", "internal", "debug", "placeholder",
    )
    advanced = any(word in lname for word in advanced_words)

    flags = ""
    if cooldown: flags += "C"
    if charges: flags += "H"
    if recharge: flags += "R"
    if duration: flags += "D"
    if stacks: flags += "S"
    if related: flags += "L"
    if passive: flags += "P"
    if category == "Interrupts" or interrupt == "Confirmed": flags += "I"
    if advanced: flags += "A"
    return cooldown, duration, charges, recharge, stacks, related, flags


def field(value) -> str:
    if value in (None, "", 0, 0.0):
        return ""
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value)


def lua_long_string(text: str) -> str:
    level = ""
    while f"]{level}]" in text:
        level += "="
    return f"[{level}[{text}]{level}]"


def main() -> int:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("RetreatUI Spell Database — Professional Audit.xlsx")
    classes: dict[str, dict] = {}
    total = 0

    for row_number, row in workbook_rows(source):
        if row_number < 5:
            continue
        class_name, spec, name = row.get("A", ""), row.get("B", ""), row.get("C", "")
        raw_id = row.get("D", "")
        if not class_name or not spec or not name or not raw_id:
            continue
        try:
            spell_id = int(float(raw_id))
        except ValueError:
            continue

        description, category = row.get("E", ""), row.get("F", "")
        cooldown, duration, charges, recharge, stacks, related, flags = hints(name, description, category, row.get("H", ""))
        bucket = classes.setdefault(class_name, {"specs": [], "spec_index": {}, "rows": []})
        if spec not in bucket["spec_index"]:
            bucket["specs"].append(spec)
            bucket["spec_index"][spec] = len(bucket["specs"])

        values = [
            spell_id,
            bucket["spec_index"][spec],
            CATEGORY_CODE.get(category, "X"),
            flags,
            cooldown,
            duration,
            charges,
            recharge,
            stacks,
            ",".join(map(str, related)),
        ]
        bucket["rows"].append("|".join(field(value) for value in values))
        total += 1

    lines = [
        "local RUI = RetreatUI",
        "if not RUI then return end",
        "",
        "-- AUTO-GENERATED. Do not edit by hand.",
        "-- Source: RetreatUI Spell Database - Professional Audit.xlsx",
    ]
    for class_name in sorted(classes):
        bucket = classes[class_name]
        specs = "{" + ",".join(json.dumps(value, ensure_ascii=False) for value in bucket["specs"]) + "}"
        raw = "\n".join(bucket["rows"])
        lines.append(
            "RUI:RegisterCompactAuditSpellCatalog("
            + json.dumps(class_name, ensure_ascii=False)
            + ", " + specs + ", " + lua_long_string(raw) + ")"
        )
    lines.append("")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    size_kib = OUTPUT.stat().st_size / 1024
    print(f"Generated {total} CoA spell rows across {len(classes)} classes -> {OUTPUT} ({size_kib:.1f} KiB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Generate RetreatUI CoA Professional Audit schema v4.

The source spell ID is always preserved. Secondary [Spell ID ...] tooltip
references are classified, and only conservative high-confidence applied
buff/debuff/aura relationships are emitted as automatic runtime effects.

Usage:
  python tools/generate_tracker_catalog.py "RetreatUI Spell Database — Professional Audit.xlsx"

Output:
  RetreatUI/Data/AuditCatalog/Schema4_01.lua ... Schema4_21.lua
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
SHEET_NAME = "CoA • All Spells"
OUTPUT_DIR = Path("RetreatUI/Data/AuditCatalog")
CATEGORY_CODE = {"Utility": "U", "Offensive": "O", "Defensive": "D", "Interrupts": "I"}


def shared_strings(zf):
    if "xl/sharedStrings.xml" not in zf.namelist(): return []
    root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
    return ["".join((n.text or "") for n in si.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t")) for si in root.findall("m:si", NS)]


def sheet_path(zf, name):
    workbook = ET.fromstring(zf.read("xl/workbook.xml"))
    rid = next((s.attrib[RID] for s in workbook.find("m:sheets", NS) if s.attrib.get("name") == name), None)
    if not rid: raise RuntimeError(f"Sheet not found: {name}")
    rels = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
    target = next((r.attrib["Target"] for r in rels if r.attrib.get("Id") == rid), None)
    if not target: raise RuntimeError(f"Relationship not found: {name}")
    return target if target.startswith("xl/") else "xl/" + target


def cell_value(cell, shared):
    ctype = cell.attrib.get("t")
    if ctype == "inlineStr":
        node = cell.find("m:is", NS)
        return "" if node is None else "".join((n.text or "") for n in node.iter("{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t"))
    value = cell.find("m:v", NS)
    if value is None: return ""
    raw = value.text or ""
    return shared[int(raw)] if ctype == "s" else raw


def workbook_rows(path):
    with zipfile.ZipFile(path) as zf:
        shared = shared_strings(zf)
        root = ET.fromstring(zf.read(sheet_path(zf, SHEET_NAME)))
        for row in root.findall(".//m:sheetData/m:row", NS):
            values = {}
            for cell in row.findall("m:c", NS):
                match = re.match(r"([A-Z]+)", cell.attrib.get("r", ""))
                if match: values[match.group(1)] = cell_value(cell, shared)
            yield int(row.attrib.get("r", 0)), values


def seconds_from(text, keyword):
    for pattern, mult in ((rf"([\d.]+)\s*(?:hr|hour)s?\s+{keyword}",3600),(rf"([\d.]+)\s*mins?\s+{keyword}",60),(rf"([\d.]+)\s*secs?\s+{keyword}",1)):
        match = re.search(pattern, text.lower())
        if match: return float(match.group(1)) * mult
    return 0


def base_hints(name, description, category, interrupt):
    low, lname = description.lower(), name.lower()
    cooldown, recharge = seconds_from(description,"cooldown"), seconds_from(description,"recharge")
    charge = re.search(r"(\d+)\s+charges?", low)
    duration = re.search(r"\bfor\s+([\d.]+)\s*(sec|secs|second|seconds|min|mins|minute|minutes)\b", low)
    stack = re.search(r"stacking\s+(?:up\s+to\s+)?(\d+)\s+(?:times?|stacks?)", low)
    charges = int(charge.group(1)) if charge else 0
    duration_s = float(duration.group(1)) * (60 if duration and duration.group(2).startswith("min") else 1) if duration else 0
    stacks = int(stack.group(1)) if stack else 0
    passive = "passive" in low
    advanced = any(w in lname for w in ("visual"," trigger","trigger ","dummy","test "," test","reset ","remove "," check","check ","applier","internal","debug","placeholder"))
    flags = ("C" if cooldown else "") + ("H" if charges else "") + ("R" if recharge else "") + ("D" if duration_s else "") + ("S" if stacks else "")
    if passive: flags += "P"
    if category == "Interrupts" or interrupt == "Confirmed": flags += "I"
    if advanced: flags += "A"
    return cooldown, duration_s, charges, recharge, stacks, flags


def reference_windows(description):
    matches = list(re.finditer(r"\[Spell ID\s+(\d+)\]", description, re.I))
    for match in matches:
        start = max(0, match.start() - 150)
        end = min(len(description), match.end() + 70)
        yield int(match.group(1)), description[start:end], description[max(0, match.start()-80):match.start()]


def relation_code(context):
    low = context.lower()
    if re.search(r"\bteach(?:es|ing)?\b|\blearn(?:s|ed|ing)?\b", low): return "E"
    if re.search(r"\btransform(?:s|ed|ing)?\b|\breplace(?:s|d|ment)?\b|\bbecome(?:s)?\b", low): return "T"
    if re.search(r"\bsummon(?:s|ed|ing)?\b|\bspawn(?:s|ed|ing)?\b|\bconstruct(?:s|ed|ing)?\b", low): return "S"
    if re.search(r"\btrigger(?:s|ed|ing)?\b|\bcasts?\b", low): return "T"
    if re.search(r"\bapply|applies|applied|inflict|inflicts|afflict|afflicts\b", low): return "A"
    if re.search(r"\bgain|gains|grant|grants|receive|receives\b", low): return "G"
    if re.search(r"\bcreate|creates|created\b", low): return "C"
    return "X"


def high_conf_effect(description, ref_id, window, prefix):
    low, before = window.lower(), prefix.lower()
    # These relationship families are never automatically treated as auras.
    if re.search(r"\bteach|\blearn|\btransform|\breplace|\bsummon|\bspawn|\btrigger", before): return None
    # A direct cast reference is a triggered spell, not proof of an aura.
    if re.search(r"\bcasts?\s+[^.]{0,50}$", before): return None

    applied = bool(re.search(r"\b(apply|applies|applied|inflict|inflicts|afflict|afflicts|gain|gains|grant|grants|receive|receives)\b", before))
    created_state = bool(re.search(r"\b(create|creates|created)\b", before) and re.search(r"\b(debuff|buff|wound|poison|disease|bleed|curse|mark|effect|aura)\b", low))
    if not (applied or created_state): return None

    harmful = bool(re.search(r"\b(enemy|enemies|target|victim|debuff|damage over time|poison|disease|bleed|curse|wound)\b", low))
    helpful = bool(re.search(r"\b(you gain|gain a|grant|ally|allies|buff|beneficial|yourself)\b", low))
    kind = "D" if harmful and not helpful else ("B" if helpful and not harmful else "A")
    return ref_id, kind


def audit_relations(description):
    relations, effects = [], []
    for ref_id, window, prefix in reference_windows(description):
        code = relation_code(window)
        relations.append((ref_id, code, "H", ""))
        effect = high_conf_effect(description, ref_id, window, prefix)
        if effect: effects.append(effect)
    unique_effects = list(dict.fromkeys(effects))
    return relations, unique_effects[0] if len(unique_effects) == 1 else None


def number(value):
    if not value: return ""
    value = float(value)
    return str(int(value)) if value.is_integer() else str(value)


def sparse_extras(cooldown,duration,charges,recharge,stacks,relations,effect):
    values = []
    if cooldown: values.append("c"+number(cooldown))
    if duration: values.append("d"+number(duration))
    if charges: values.append("h"+number(charges))
    if recharge: values.append("r"+number(recharge))
    if stacks: values.append("s"+str(stacks))
    if effect: values.append(f"e{effect[0]}{effect[1]}")
    if relations: values.append("l" + ",".join(f"{rid}:{code}:{conf}:{src}" for rid,code,conf,src in relations))
    return ";".join(values)


def lua_string(text):
    level = ""
    while f"]{level}]" in text: level += "="
    return f"[{level}[{text}]{level}]"


def main():
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("RetreatUI Spell Database — Professional Audit.xlsx")
    classes, total, secondary, effects = {}, 0, 0, 0
    for row_number, row in workbook_rows(source):
        if row_number < 5: continue
        class_name, spec, name, raw_id = row.get("A",""), row.get("B",""), row.get("C",""), row.get("D","")
        if not class_name or not spec or not name or not raw_id: continue
        try: spell_id = int(float(raw_id))
        except ValueError: continue
        description, category = row.get("E",""), row.get("F","")
        cooldown,duration,charges,recharge,stacks,flags = base_hints(name,description,category,row.get("H",""))
        relations, effect = audit_relations(description)
        secondary += len(relations)
        if relations: flags += "L"
        if effect: flags += "E"; effects += 1
        bucket = classes.setdefault(class_name,{"specs":[],"spec_index":{},"rows":[]})
        if spec not in bucket["spec_index"]:
            bucket["specs"].append(spec); bucket["spec_index"][spec]=len(bucket["specs"])
        extras = sparse_extras(cooldown,duration,charges,recharge,stacks,relations,effect)
        bucket["rows"].append(f"{spell_id}|{bucket['spec_index'][spec]}|{CATEGORY_CODE.get(category,'X')}|{flags}|{extras}")
        total += 1

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUTPUT_DIR.glob("Schema4_*.lua"): old.unlink()
    for index, class_name in enumerate(sorted(classes), 1):
        bucket = classes[class_name]
        specs = "{" + ",".join(json.dumps(x,ensure_ascii=False) for x in bucket["specs"]) + "}"
        raw = "\n".join(bucket["rows"])
        text = "\n".join([
            "local RUI = RetreatUI", "if not RUI then return end", "",
            "-- AUTO-GENERATED. Do not edit by hand.", "-- Source: RetreatUI Spell Database - Professional Audit.xlsx",
            f"RUI:RegisterCompactAuditSpellCatalogChunk({json.dumps(class_name,ensure_ascii=False)}, {specs}, {lua_string(raw)})", ""
        ])
        (OUTPUT_DIR / f"Schema4_{index:02d}.lua").write_text(text, encoding="utf-8")
    print(f"Generated {total} rows across {len(classes)} classes; classified {secondary} secondary references; {effects} high-confidence applied effects")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

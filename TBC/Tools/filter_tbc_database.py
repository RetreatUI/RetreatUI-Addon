#!/usr/bin/env python3
"""Remove source candidates that do not exist in Wowhead's TBC dataset.

LibSpellDB intentionally serves multiple Classic flavours. The Wowhead TBC
endpoint is the final availability gate for RetreatUI's TBC catalog. Missing
Talent rows are treated as fatal because WoWSims should enumerate only genuine
TBC talent ranks; missing Era/SoD ability candidates are retained only in the
Missing Data audit CSV.
"""

from __future__ import annotations

import csv
import json
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path("TBC/Data/generated")
RUNTIME_LUA = Path("TBC/Package/RetreatUI/Core/GeneratedTBCData.lua")
CLASSES = ["Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior"]


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def lua_quote(value: str) -> str:
    return "[=[" + value.replace("]=]", "] =]") + "]=]"


def as_number(value: str) -> str:
    value = str(value or "").strip()
    return value if value else "0"


def write_runtime_lua(racials: list[dict[str, str]], trinkets: list[dict[str, str]], manifest: dict[str, Any]) -> None:
    lines = [
        "-- Generated from Wowhead TBC data. Do not edit by hand.",
        "local RUI = RetreatUI",
        "if not RUI then return end",
        "",
        "RUI.generatedTBCData = RUI.generatedTBCData or {}",
        f"RUI.generatedTBCData.generatedAt = {lua_quote(manifest['generated_at'])}",
        f"RUI.generatedTBCData.libSpellDBRevision = {lua_quote(manifest['sources']['libspelldb']['sha'])}",
        f"RUI.generatedTBCData.wowSimsRevision = {lua_quote(manifest['sources']['wowsims_tbc_new']['sha'])}",
        "",
        "RUI.generatedTBCData.racials = {",
    ]
    for row in racials:
        if row.get("Type") != "Racial":
            continue
        lines.extend([
            "    {",
            f"        race = {lua_quote(row.get('Race', ''))},",
            f"        name = {lua_quote(row.get('Name', ''))},",
            f"        spellID = {int(row['Spell ID'])},",
            f"        canonicalID = {int(row['Canonical ID'])},",
            f"        category = {lua_quote(row.get('Category', ''))},",
            f"        hudRow = {lua_quote(row.get('HUD Row', ''))},",
            f"        cooldown = {as_number(row.get('Cooldown', ''))},",
            f"        duration = {as_number(row.get('Duration', ''))},",
            "    },",
        ])
    lines.extend(["}", "", "RUI.generatedTBCData.trinkets = {"])
    for row in trinkets:
        lines.extend([
            f"    [{int(row['Item ID'])}] = {{",
            f"        name = {lua_quote(row.get('Item Name', ''))},",
            f"        procBuffID = {int(row['Proc Buff ID']) if row.get('Proc Buff ID') else 0},",
            f"        onUseBuffID = {int(row['On-use Buff ID']) if row.get('On-use Buff ID') else 0},",
            f"        icd = {as_number(row.get('Internal Cooldown', ''))},",
            f"        onTarget = {'true' if row.get('On Target') == 'Yes' else 'false'},",
            "    },",
        ])
    lines.extend(["}", ""])
    RUNTIME_LUA.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def main() -> None:
    _, missing_rows = read_csv(ROOT / "missing_data.csv")
    missing_talents = [row for row in missing_rows if row.get("Entity Type") == "Talent"]
    if missing_talents:
        details = ", ".join(f"{row['Class/Race']}:{row['ID']}" for row in missing_talents[:20])
        raise SystemExit(f"Wowhead TBC did not resolve talent ranks: {details}")

    missing_spell_ids = {
        int(row["ID"])
        for row in missing_rows
        if row.get("Entity Type") in {"Spell", "Racial/Shared spell"}
    }
    missing_item_ids = {
        int(row["ID"])
        for row in missing_rows
        if row.get("Entity Type") == "Trinket item"
    }
    missing_proc_ids = {
        int(row["ID"])
        for row in missing_rows
        if row.get("Entity Type") == "Trinket proc buff"
    }

    all_fields, all_rows = read_csv(ROOT / "all_spells.csv")
    filtered_all = [row for row in all_rows if int(row["Spell ID"]) not in missing_spell_ids]
    write_csv(ROOT / "all_spells.csv", all_fields, filtered_all)

    for class_name in CLASSES:
        path = ROOT / f"{class_name.lower()}.csv"
        fields, rows = read_csv(path)
        rows = [row for row in rows if int(row["Spell ID"]) not in missing_spell_ids]
        write_csv(path, fields, rows)

    racial_fields, racials = read_csv(ROOT / "racials.csv")
    racials = [row for row in racials if int(row["Spell ID"]) not in missing_spell_ids]
    write_csv(ROOT / "racials.csv", racial_fields, racials)

    trinket_fields, trinkets = read_csv(ROOT / "trinkets.csv")
    filtered_trinkets = []
    for row in trinkets:
        item_id = int(row["Item ID"])
        proc_id = int(row["Proc Buff ID"]) if row.get("Proc Buff ID") else 0
        if item_id in missing_item_ids or proc_id in missing_proc_ids:
            continue
        filtered_trinkets.append(row)
    write_csv(ROOT / "trinkets.csv", trinket_fields, filtered_trinkets)

    manifest_path = ROOT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    class_counts: dict[str, dict[str, int]] = defaultdict(lambda: {"rows": 0, "ability_rows": 0, "talent_rows": 0})
    for row in filtered_all:
        details = class_counts[row["Class"]]
        details["rows"] += 1
        if row["Type"] in {"Ability", "Talent Ability"}:
            details["ability_rows"] += 1
        if row["Type"] in {"Talent", "Talent Ability"}:
            details["talent_rows"] += 1

    manifest["counts"].update({
        "all_spell_rows": len(filtered_all),
        "unique_spell_ids": len({int(row["Spell ID"]) for row in filtered_all}),
        "racial_shared_rows": len(racials),
        "racial_rows": sum(1 for row in racials if row.get("Type") == "Racial"),
        "trinket_proc_mappings": len(filtered_trinkets),
        "excluded_non_tbc_candidates": len(missing_rows),
        "unresolved_included_rows": 0,
        "by_class": {class_name: class_counts[class_name] for class_name in CLASSES},
    })
    manifest["coverage_note"] = (
        "Rows unavailable from the Wowhead TBC tooltip endpoint are excluded from the canonical catalog and retained in missing_data.csv as an audit trail."
    )
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    write_runtime_lua(racials, filtered_trinkets, manifest)

    print(json.dumps(manifest["counts"], indent=2))


if __name__ == "__main__":
    main()

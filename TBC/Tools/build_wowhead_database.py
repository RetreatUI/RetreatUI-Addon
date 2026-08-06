#!/usr/bin/env python3
"""Build RetreatUI's TBC spell reference.

The generated catalog combines three source layers:

1. Wowhead TBC tooltip JSON is canonical for spell/item names, descriptions,
   ranks, requirements, and direct source URLs.
2. LibSpellDB enumerates curated player abilities and provides rank mappings,
   cooldowns, durations, aura relationships, tags, racials, and passive trinket
   proc mappings.
3. WoWSims TBC talent-tree JSON enumerates every talent node and every talent
   rank spell ID for all nine classes.

The script writes CSV files that can be imported into the RetreatUI Google
Sheet and a manifest documenting exact upstream revisions and coverage.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import csv
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import requests
from bs4 import BeautifulSoup

LIBSPELLDB_REPO = "veev-code/LibSpellDB"
WOWSIMS_REPO = "wowsims/tbc-new"
WOWHEAD_TOOLTIP_ROOT = "https://nether.wowhead.com/tbc/tooltip"
WOWHEAD_PAGE_ROOT = "https://www.wowhead.com/tbc"

CLASS_FILES: dict[str, str] = {
    "Druid": "Druid.lua",
    "Hunter": "Hunter.lua",
    "Mage": "Mage.lua",
    "Paladin": "Paladin.lua",
    "Priest": "Priest.lua",
    "Rogue": "Rogue.lua",
    "Shaman": "Shaman.lua",
    "Warlock": "Warlock.lua",
    "Warrior": "Warrior.lua",
}

TALENT_FILES: dict[str, str] = {
    class_name: f"ui/core/talents/trees/{class_name.lower()}.json"
    for class_name in CLASS_FILES
}

CLASS_SPEC_NAMES: dict[str, list[str]] = {
    "Druid": ["Balance", "Feral", "Restoration"],
    "Hunter": ["Beast Mastery", "Marksmanship", "Survival"],
    "Mage": ["Arcane", "Fire", "Frost"],
    "Paladin": ["Holy", "Protection", "Retribution"],
    "Priest": ["Discipline", "Holy", "Shadow"],
    "Rogue": ["Assassination", "Combat", "Subtlety"],
    "Shaman": ["Elemental", "Enhancement", "Restoration"],
    "Warlock": ["Affliction", "Demonology", "Destruction"],
    "Warrior": ["Arms", "Fury", "Protection"],
}

SPEC_DISPLAY = {
    "BALANCE": "Balance",
    "FERAL": "Feral",
    "RESTORATION": "Restoration",
    "BEAST_MASTERY": "Beast Mastery",
    "MARKSMANSHIP": "Marksmanship",
    "SURVIVAL": "Survival",
    "ARCANE": "Arcane",
    "FIRE": "Fire",
    "FROST": "Frost",
    "HOLY": "Holy",
    "PROTECTION": "Protection",
    "RETRIBUTION": "Retribution",
    "DISCIPLINE": "Discipline",
    "SHADOW": "Shadow",
    "ASSASSINATION": "Assassination",
    "COMBAT": "Combat",
    "SUBTLETY": "Subtlety",
    "ELEMENTAL": "Elemental",
    "ENHANCEMENT": "Enhancement",
    "AFFLICTION": "Affliction",
    "DEMONOLOGY": "Demonology",
    "DESTRUCTION": "Destruction",
    "ARMS": "Arms",
    "FURY": "Fury",
}

ALL_SPELL_COLUMNS = [
    "Class",
    "Specialization",
    "Type",
    "Name",
    "Spell ID",
    "Canonical ID",
    "Rank",
    "Learned Level",
    "Description",
    "Category",
    "HUD Row",
    "Cooldown",
    "Duration",
    "Resource Cost",
    "Aura ID",
    "Track Mode",
    "Tags",
    "Wowhead Source",
    "Notes",
]

CLASS_COLUMNS = ALL_SPELL_COLUMNS[1:]

RACIAL_COLUMNS = [
    "Race",
    "Type",
    "Name",
    "Spell ID",
    "Canonical ID",
    "Rank",
    "Description",
    "Category",
    "HUD Row",
    "Cooldown",
    "Duration",
    "Aura ID",
    "Track Mode",
    "Tags",
    "Wowhead Source",
    "Notes",
]

TRINKET_COLUMNS = [
    "Item Name",
    "Item ID",
    "Tracking Type",
    "Trigger Spell ID",
    "Proc Buff Name",
    "Proc Buff ID",
    "On-use Buff ID",
    "Internal Cooldown",
    "Buff Duration",
    "On Target",
    "Wowhead Source",
    "Notes",
]

MISSING_COLUMNS = ["Entity Type", "ID", "Class/Race", "Expected Name", "Source", "Reason"]

HEADERS = {
    "User-Agent": "RetreatUI-TBC-Database/1.0 (+https://github.com/RetreatUI/RetreatUI-Addon)",
    "Accept": "application/json,text/plain,*/*",
    "Accept-Language": "en-US,en;q=0.9",
}


@dataclass
class Tooltip:
    entity_type: str
    entity_id: int
    ok: bool
    name: str = ""
    icon: str = ""
    description: str = ""
    rank: str = ""
    learned_level: str = ""
    resource_cost: str = ""
    cooldown: float | None = None
    duration: float | None = None
    linked_spell_ids: tuple[int, ...] = ()
    raw_text: str = ""
    error: str = ""


def request_json(session: requests.Session, url: str, attempts: int = 4) -> dict[str, Any]:
    last_error = ""
    for attempt in range(1, attempts + 1):
        try:
            response = session.get(url, headers=HEADERS, timeout=40)
            if response.status_code == 200:
                return response.json()
            last_error = f"HTTP {response.status_code}"
            if response.status_code == 404:
                break
        except Exception as exc:  # pragma: no cover - network failure path
            last_error = repr(exc)
        time.sleep(min(5.0, 0.7 * attempt))
    raise RuntimeError(f"Could not fetch {url}: {last_error}")


def github_head_sha(session: requests.Session, repo: str, ref: str = "master") -> str:
    payload = request_json(session, f"https://api.github.com/repos/{repo}/commits/{ref}")
    return str(payload["sha"])


def download_raw(session: requests.Session, repo: str, sha: str, path: str) -> str:
    url = f"https://raw.githubusercontent.com/{repo}/{sha}/{path}"
    response = session.get(url, headers=HEADERS, timeout=60)
    response.raise_for_status()
    return response.text


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def run_lua_extractor(lua_files: list[Path], output_path: Path) -> dict[str, Any]:
    lua_executable = shutil.which("lua5.1") or shutil.which("lua")
    if not lua_executable:
        raise RuntimeError("Lua 5.1 is required to evaluate LibSpellDB data files")

    extractor = r'''
local outputPath = arg[1]

local spells = {}
local trinkets = {}

local function enumTable()
    return setmetatable({}, {
        __index = function(t, key)
            rawset(t, key, key)
            return key
        end,
    })
end

local lib = {
    Categories = enumTable(),
    Specs = enumTable(),
    AuraTarget = enumTable(),
}

function lib:RegisterSpells(entries, classToken)
    for _, entry in ipairs(entries or {}) do
        entry.__class = classToken or entry.class or "UNKNOWN"
        table.insert(spells, entry)
    end
end

function lib:RegisterTrinkets(entries)
    for _, entry in ipairs(entries or {}) do
        table.insert(trinkets, entry)
    end
end

LIBSPELLDB_REGISTRATION = lib

for index = 2, #arg do
    dofile(arg[index])
end

local function escapeString(value)
    value = string.gsub(value, "\\", "\\\\")
    value = string.gsub(value, '"', '\\"')
    value = string.gsub(value, "\b", "\\b")
    value = string.gsub(value, "\f", "\\f")
    value = string.gsub(value, "\n", "\\n")
    value = string.gsub(value, "\r", "\\r")
    value = string.gsub(value, "\t", "\\t")
    return value
end

local function isArray(value)
    local count = 0
    local maximum = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or math.floor(key) ~= key then
            return false, 0
        end
        count = count + 1
        if key > maximum then maximum = key end
    end
    return maximum == count, maximum
end

local function encode(value, seen)
    local valueType = type(value)
    if valueType == "nil" then return "null" end
    if valueType == "boolean" then return value and "true" or "false" end
    if valueType == "number" then return tostring(value) end
    if valueType == "string" then return '"' .. escapeString(value) .. '"' end
    if valueType ~= "table" then return "null" end

    seen = seen or {}
    if seen[value] then return "null" end
    seen[value] = true

    local array, length = isArray(value)
    local parts = {}
    if array then
        for index = 1, length do
            parts[#parts + 1] = encode(value[index], seen)
        end
        seen[value] = nil
        return "[" .. table.concat(parts, ",") .. "]"
    end

    local keys = {}
    for key, _ in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(keys) do
        parts[#parts + 1] = encode(tostring(key), seen) .. ":" .. encode(value[key], seen)
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

local output = assert(io.open(outputPath, "w"))
output:write(encode({ spells = spells, trinkets = trinkets }))
output:close()
'''

    with tempfile.TemporaryDirectory(prefix="ruitbc-lua-") as temp_dir:
        extractor_path = Path(temp_dir) / "extract.lua"
        write_text(extractor_path, extractor)
        command = [lua_executable, str(extractor_path), str(output_path)] + [str(path) for path in lua_files]
        completed = subprocess.run(command, check=False, text=True, capture_output=True)
        if completed.returncode != 0:
            raise RuntimeError(
                "LibSpellDB extraction failed\n"
                f"stdout:\n{completed.stdout}\n"
                f"stderr:\n{completed.stderr}"
            )
    return json.loads(output_path.read_text(encoding="utf-8"))


def clean_text(value: str) -> str:
    value = html.unescape(value or "")
    value = value.replace("\xa0", " ")
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\n[ \t]+", "\n", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()


def seconds_from_match(amount: str, unit: str) -> float:
    value = float(amount)
    unit = unit.lower()
    if unit.startswith("min"):
        return value * 60
    if unit.startswith("hour"):
        return value * 3600
    return value


def parse_tooltip(entity_type: str, entity_id: int, payload: dict[str, Any]) -> Tooltip:
    tooltip_html = str(payload.get("tooltip") or "")
    soup = BeautifulSoup(tooltip_html, "html.parser")
    raw_text = clean_text(soup.get_text("\n"))
    name = clean_text(str(payload.get("name") or ""))
    icon = clean_text(str(payload.get("icon") or ""))

    description = ""
    description_node = soup.find("div", class_="q")
    if description_node:
        description = clean_text(description_node.get_text("\n"))

    rank_match = re.search(r"\bRank\s+(\d+)\b", raw_text, re.IGNORECASE)
    rank = f"Rank {rank_match.group(1)}" if rank_match else ""

    level_match = re.search(r"Requires level\s+(\d+)", raw_text, re.IGNORECASE)
    learned_level = level_match.group(1) if level_match else ""

    resource_cost = ""
    resource_patterns = [
        r"^\d+(?:\.\d+)?% of base mana$",
        r"^\d+(?:\.\d+)? Mana$",
        r"^\d+(?:\.\d+)? Energy$",
        r"^\d+(?:\.\d+)? Rage$",
        r"^\d+(?:\.\d+)? Health$",
        r"^\d+(?:\.\d+)? Focus$",
        r"^Requires \d+(?:\.\d+)? Rage$",
    ]
    for line in (part.strip() for part in raw_text.splitlines()):
        if any(re.match(pattern, line, re.IGNORECASE) for pattern in resource_patterns):
            resource_cost = line
            break

    cooldown = None
    cooldown_match = re.search(
        r"(\d+(?:\.\d+)?)\s*(sec(?:ond)?s?|mins?|minutes?|hours?)\s+cooldown",
        raw_text,
        re.IGNORECASE,
    )
    if cooldown_match:
        cooldown = seconds_from_match(cooldown_match.group(1), cooldown_match.group(2))

    duration = None
    duration_matches = re.findall(
        r"(?:Lasts|for)\s+(\d+(?:\.\d+)?)\s*(sec(?:ond)?s?|mins?|minutes?|hours?)",
        description,
        re.IGNORECASE,
    )
    if duration_matches:
        duration = seconds_from_match(*duration_matches[-1])

    linked_ids = tuple(
        sorted(
            {
                int(value)
                for value in re.findall(r"/tbc/spell=(\d+)", tooltip_html)
            }
        )
    )

    return Tooltip(
        entity_type=entity_type,
        entity_id=entity_id,
        ok=True,
        name=name,
        icon=icon,
        description=description,
        rank=rank,
        learned_level=learned_level,
        resource_cost=resource_cost,
        cooldown=cooldown,
        duration=duration,
        linked_spell_ids=linked_ids,
        raw_text=raw_text,
    )


def fetch_tooltip(session: requests.Session, entity_type: str, entity_id: int) -> Tooltip:
    url = f"{WOWHEAD_TOOLTIP_ROOT}/{entity_type}/{entity_id}"
    try:
        payload = request_json(session, url)
        return parse_tooltip(entity_type, entity_id, payload)
    except Exception as exc:
        return Tooltip(entity_type=entity_type, entity_id=entity_id, ok=False, error=str(exc))


def fetch_tooltips(entity_type: str, ids: Iterable[int], workers: int = 12) -> dict[int, Tooltip]:
    unique_ids = sorted({int(value) for value in ids if int(value) > 0})
    results: dict[int, Tooltip] = {}

    def task(entity_id: int) -> Tooltip:
        with requests.Session() as session:
            return fetch_tooltip(session, entity_type, entity_id)

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        future_to_id = {executor.submit(task, entity_id): entity_id for entity_id in unique_ids}
        completed = 0
        for future in concurrent.futures.as_completed(future_to_id):
            entity_id = future_to_id[future]
            try:
                results[entity_id] = future.result()
            except Exception as exc:  # pragma: no cover
                results[entity_id] = Tooltip(entity_type, entity_id, False, error=repr(exc))
            completed += 1
            if completed % 100 == 0 or completed == len(unique_ids):
                print(f"Fetched {completed}/{len(unique_ids)} {entity_type} tooltips", flush=True)
    return results


def number_or_blank(value: Any) -> float | int | str:
    if value is None or value == "":
        return ""
    try:
        number = float(value)
    except (TypeError, ValueError):
        return str(value)
    if number.is_integer():
        return int(number)
    return round(number, 3)


def tag_set(entry: dict[str, Any]) -> set[str]:
    return {str(tag).upper() for tag in entry.get("tags") or [] if tag}


def category_from_tags(tags: set[str], record_type: str) -> str:
    if "INTERRUPT" in tags or "SILENCE" in tags:
        return "Interrupt"
    if tags & {
        "DEFENSIVE",
        "PERSONAL_DEFENSIVE",
        "EXTERNAL_DEFENSIVE",
        "IMMUNITY",
        "DAMAGE_REDUCTION",
        "CC_BREAK",
        "CC_IMMUNITY",
    }:
        return "Defensive"
    if tags & {"CC_HARD", "CC_SOFT", "ROOT", "FEAR", "DISORIENT", "KNOCKBACK"}:
        return "Crowd Control"
    if tags & {"MOVEMENT", "MOVEMENT_GAP_CLOSE", "MOVEMENT_ESCAPE", "MOVEMENT_SPEED"}:
        return "Mobility"
    if tags & {"DISPEL_MAGIC", "DISPEL_CURSE", "DISPEL_POISON", "DISPEL_DISEASE", "PURGE", "TAUNT", "UTILITY", "RESURRECT", "BATTLE_REZ"}:
        return "Utility"
    if tags & {"HEAL", "HEAL_SINGLE", "HEAL_AOE", "HOT", "HAS_HOT"}:
        return "Healing"
    if "RESOURCE" in tags:
        return "Resource"
    if tags & {"SHAPESHIFT", "CAT_FORM", "BEAR_FORM"}:
        return "Form"
    if tags & {"PET_SUMMON", "PET_SUMMON_TEMP", "PET_CONTROL", "REQUIRES_PET"}:
        return "Pet"
    if tags & {"DPS", "ROTATIONAL", "FINISHER", "REACTIVE", "MAINTENANCE", "HAS_DOT"}:
        return "Offensive"
    if record_type == "Talent":
        return "Talent Passive"
    return "Ability"


def hud_row(category: str, tags: set[str], record_type: str) -> str:
    if record_type == "Talent" and not tags:
        return "Data only"
    if category in {"Offensive", "Resource", "Pet"}:
        return "Main"
    if category in {
        "Interrupt",
        "Defensive",
        "Crowd Control",
        "Mobility",
        "Utility",
        "Healing",
        "Form",
    }:
        return "Utility"
    return "Data only"


def track_mode(entry: dict[str, Any], tags: set[str], category: str, record_type: str) -> str:
    if record_type == "Talent" and not tags:
        return "Data only"
    cooldown = number_or_blank(entry.get("cooldown"))
    duration = number_or_blank(entry.get("duration"))
    has_aura = bool(entry.get("triggersAuras") or entry.get("appliesBuff")) or bool(
        tags & {"HAS_BUFF", "HAS_DEBUFF", "HAS_DOT", "HAS_HOT", "PROC", "MAINTENANCE"}
    )
    if cooldown != "" and has_aura:
        return "Cooldown + aura"
    if cooldown != "":
        return "Cooldown"
    if has_aura or duration != "":
        return "Aura"
    if category in {"Form", "Resource"}:
        return "State"
    return "Spellbook"


def friendly_specs(class_name: str, values: Any) -> str:
    specs = [SPEC_DISPLAY.get(str(value).upper(), str(value).replace("_", " ").title()) for value in (values or [])]
    specs = list(dict.fromkeys(specs))
    class_specs = CLASS_SPEC_NAMES[class_name]
    if not specs or set(specs) == set(class_specs):
        return "Class-wide / Shared"
    return ", ".join(specs)


def aura_ids(entry: dict[str, Any]) -> list[int]:
    values: list[int] = []
    for aura in entry.get("triggersAuras") or []:
        if isinstance(aura, dict) and aura.get("spellID"):
            values.append(int(aura["spellID"]))
    for value in entry.get("appliesBuff") or []:
        if value:
            values.append(int(value))
    for key in ("targetLockoutDebuff",):
        if entry.get(key):
            values.append(int(entry[key]))
    return list(dict.fromkeys(values))


def merge_notes(*parts: Any) -> str:
    cleaned = []
    for part in parts:
        text = clean_text(str(part or ""))
        if text and text not in cleaned:
            cleaned.append(text)
    return " | ".join(cleaned)


def build_records(
    extracted: dict[str, Any],
    talents: dict[str, list[dict[str, Any]]],
    spell_tooltips: dict[int, Tooltip],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    records: dict[tuple[str, int], dict[str, Any]] = {}
    racial_records: list[dict[str, Any]] = []
    missing: list[dict[str, Any]] = []

    for entry in extracted.get("spells") or []:
        class_token = str(entry.get("__class") or "").upper()
        race = clean_text(str(entry.get("race") or ""))
        canonical_id = int(entry.get("spellID") or 0)
        rank_ids = [int(value) for value in (entry.get("ranks") or [canonical_id]) if int(value) > 0]
        if canonical_id and canonical_id not in rank_ids:
            rank_ids.insert(0, canonical_id)
        tags = tag_set(entry)
        category = category_from_tags(tags, "Talent Ability" if entry.get("talent") else "Ability")
        row = hud_row(category, tags, "Talent Ability" if entry.get("talent") else "Ability")
        mode = track_mode(entry, tags, category, "Talent Ability" if entry.get("talent") else "Ability")
        related_auras = aura_ids(entry)

        if class_token == "SHARED" or race:
            for index, spell_id in enumerate(rank_ids, start=1):
                tooltip = spell_tooltips.get(spell_id)
                if not tooltip or not tooltip.ok:
                    missing.append(
                        {
                            "Entity Type": "Racial/Shared spell",
                            "ID": spell_id,
                            "Class/Race": race or "Shared",
                            "Expected Name": entry.get("name") or "",
                            "Source": f"{WOWHEAD_PAGE_ROOT}/spell={spell_id}",
                            "Reason": tooltip.error if tooltip else "Tooltip not fetched",
                        }
                    )
                racial_records.append(
                    {
                        "Race": race or "Shared",
                        "Type": "Racial" if race else "Shared ability",
                        "Name": (tooltip.name if tooltip and tooltip.ok else clean_text(str(entry.get("name") or ""))),
                        "Spell ID": spell_id,
                        "Canonical ID": canonical_id,
                        "Rank": (tooltip.rank if tooltip and tooltip.rank else (f"Rank {index}" if len(rank_ids) > 1 else "")),
                        "Description": (tooltip.description if tooltip and tooltip.description else clean_text(str(entry.get("description") or ""))),
                        "Category": category,
                        "HUD Row": row,
                        "Cooldown": number_or_blank(entry.get("cooldown") if entry.get("cooldown") is not None else (tooltip.cooldown if tooltip else None)),
                        "Duration": number_or_blank(entry.get("duration") if entry.get("duration") is not None else (tooltip.duration if tooltip else None)),
                        "Aura ID": ", ".join(str(value) for value in related_auras),
                        "Track Mode": mode,
                        "Tags": ", ".join(sorted(tags)),
                        "Wowhead Source": f"{WOWHEAD_PAGE_ROOT}/spell={spell_id}",
                        "Notes": merge_notes(entry.get("notes"), "Race-filtered at runtime" if race else "Available to all classes when learned"),
                    }
                )
            continue

        class_name = next((name for name in CLASS_FILES if name.upper().replace(" ", "_") == class_token), class_token.title())
        if class_name not in CLASS_FILES:
            continue
        specialization = friendly_specs(class_name, entry.get("specs"))
        record_type = "Talent Ability" if entry.get("talent") else "Ability"

        for index, spell_id in enumerate(rank_ids, start=1):
            tooltip = spell_tooltips.get(spell_id)
            if not tooltip or not tooltip.ok:
                missing.append(
                    {
                        "Entity Type": "Spell",
                        "ID": spell_id,
                        "Class/Race": class_name,
                        "Expected Name": entry.get("name") or "",
                        "Source": f"{WOWHEAD_PAGE_ROOT}/spell={spell_id}",
                        "Reason": tooltip.error if tooltip else "Tooltip not fetched",
                    }
                )
            records[(class_name, spell_id)] = {
                "Class": class_name,
                "Specialization": specialization,
                "Type": record_type,
                "Name": tooltip.name if tooltip and tooltip.ok else clean_text(str(entry.get("name") or "")),
                "Spell ID": spell_id,
                "Canonical ID": canonical_id,
                "Rank": tooltip.rank if tooltip and tooltip.rank else (f"Rank {index}" if len(rank_ids) > 1 else ""),
                "Learned Level": tooltip.learned_level if tooltip else "",
                "Description": tooltip.description if tooltip and tooltip.description else clean_text(str(entry.get("description") or "")),
                "Category": category,
                "HUD Row": row,
                "Cooldown": number_or_blank(entry.get("cooldown") if entry.get("cooldown") is not None else (tooltip.cooldown if tooltip else None)),
                "Duration": number_or_blank(entry.get("duration") if entry.get("duration") is not None else (tooltip.duration if tooltip else None)),
                "Resource Cost": tooltip.resource_cost if tooltip else "",
                "Aura ID": ", ".join(str(value) for value in related_auras),
                "Track Mode": mode,
                "Tags": ", ".join(sorted(tags)),
                "Wowhead Source": f"{WOWHEAD_PAGE_ROOT}/spell={spell_id}",
                "Notes": merge_notes(entry.get("notes"), "Talent-required" if entry.get("talent") else ""),
            }

    for class_name, trees in talents.items():
        for tree in trees:
            tree_name = clean_text(str(tree.get("name") or ""))
            for talent in tree.get("talents") or []:
                talent_name = clean_text(str(talent.get("fancyName") or talent.get("fieldName") or "Talent"))
                spell_ids = [int(value) for value in (talent.get("spellIds") or []) if int(value) > 0]
                canonical_id = spell_ids[0] if spell_ids else 0
                for rank_index, spell_id in enumerate(spell_ids, start=1):
                    tooltip = spell_tooltips.get(spell_id)
                    key = (class_name, spell_id)
                    if not tooltip or not tooltip.ok:
                        missing.append(
                            {
                                "Entity Type": "Talent",
                                "ID": spell_id,
                                "Class/Race": f"{class_name} — {tree_name}",
                                "Expected Name": talent_name,
                                "Source": f"{WOWHEAD_PAGE_ROOT}/spell={spell_id}",
                                "Reason": tooltip.error if tooltip else "Tooltip not fetched",
                            }
                        )
                    if key in records:
                        record = records[key]
                        record["Type"] = "Talent Ability"
                        record["Specialization"] = tree_name
                        record["Canonical ID"] = canonical_id
                        record["Rank"] = tooltip.rank if tooltip and tooltip.rank else f"Rank {rank_index}/{len(spell_ids)}"
                        record["Notes"] = merge_notes(record.get("Notes"), f"Talent: {talent_name}")
                        continue

                    records[key] = {
                        "Class": class_name,
                        "Specialization": tree_name,
                        "Type": "Talent",
                        "Name": tooltip.name if tooltip and tooltip.ok else talent_name,
                        "Spell ID": spell_id,
                        "Canonical ID": canonical_id,
                        "Rank": tooltip.rank if tooltip and tooltip.rank else f"Rank {rank_index}/{len(spell_ids)}",
                        "Learned Level": tooltip.learned_level if tooltip else "",
                        "Description": tooltip.description if tooltip and tooltip.description else "",
                        "Category": "Talent Passive",
                        "HUD Row": "Data only",
                        "Cooldown": number_or_blank(tooltip.cooldown if tooltip else None),
                        "Duration": number_or_blank(tooltip.duration if tooltip else None),
                        "Resource Cost": tooltip.resource_cost if tooltip else "",
                        "Aura ID": "",
                        "Track Mode": "Data only",
                        "Tags": "TALENT",
                        "Wowhead Source": f"{WOWHEAD_PAGE_ROOT}/spell={spell_id}",
                        "Notes": f"Talent: {talent_name}; tree row {int((talent.get('location') or {}).get('rowIdx', 0)) + 1}",
                    }

    all_records = sorted(
        records.values(),
        key=lambda row: (
            row["Class"],
            row["Specialization"],
            0 if row["Type"] == "Ability" else 1,
            row["Name"],
            int(row["Spell ID"]),
        ),
    )
    racial_records.sort(key=lambda row: (row["Race"], row["Name"], int(row["Spell ID"])))
    missing = list({(row["Entity Type"], int(row["ID"]), row["Class/Race"]): row for row in missing}.values())
    missing.sort(key=lambda row: (row["Entity Type"], row["Class/Race"], int(row["ID"])))
    return all_records, racial_records, missing


def build_trinkets(
    entries: list[dict[str, Any]],
    item_tooltips: dict[int, Tooltip],
    spell_tooltips: dict[int, Tooltip],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    rows: list[dict[str, Any]] = []
    missing: list[dict[str, Any]] = []
    for entry in entries:
        item_id = int(entry.get("itemID") or 0)
        proc_buff_id = int(entry.get("procBuffID") or 0)
        on_use_buff_id = int(entry.get("onUseBuffID") or 0)
        item = item_tooltips.get(item_id)
        proc = spell_tooltips.get(proc_buff_id)

        if not item or not item.ok:
            missing.append(
                {
                    "Entity Type": "Trinket item",
                    "ID": item_id,
                    "Class/Race": "Trinket",
                    "Expected Name": "",
                    "Source": f"{WOWHEAD_PAGE_ROOT}/item={item_id}",
                    "Reason": item.error if item else "Tooltip not fetched",
                }
            )
        if proc_buff_id and (not proc or not proc.ok):
            missing.append(
                {
                    "Entity Type": "Trinket proc buff",
                    "ID": proc_buff_id,
                    "Class/Race": str(item_id),
                    "Expected Name": "",
                    "Source": f"{WOWHEAD_PAGE_ROOT}/spell={proc_buff_id}",
                    "Reason": proc.error if proc else "Tooltip not fetched",
                }
            )

        linked = list(item.linked_spell_ids if item and item.ok else ())
        trigger_ids = [value for value in linked if value not in {proc_buff_id, on_use_buff_id}]
        tracking_type = "Passive proc"
        if on_use_buff_id:
            tracking_type += " + on-use override"

        rows.append(
            {
                "Item Name": item.name if item and item.ok else f"Item {item_id}",
                "Item ID": item_id,
                "Tracking Type": tracking_type,
                "Trigger Spell ID": ", ".join(str(value) for value in trigger_ids),
                "Proc Buff Name": proc.name if proc and proc.ok else "",
                "Proc Buff ID": proc_buff_id or "",
                "On-use Buff ID": on_use_buff_id or "",
                "Internal Cooldown": number_or_blank(entry.get("icd")),
                "Buff Duration": number_or_blank(proc.duration if proc else None),
                "On Target": "Yes" if entry.get("onTarget") else "No",
                "Wowhead Source": f"{WOWHEAD_PAGE_ROOT}/item={item_id}",
                "Notes": "All on-use trinkets are also detected dynamically in-game with GetItemSpell().",
            }
        )
    rows.sort(key=lambda row: (row["Item Name"], int(row["Item ID"])))
    return rows, missing


def write_csv(path: Path, columns: list[str], rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow({column: row.get(column, "") for column in columns})


def lua_quote(value: str) -> str:
    return "[=[" + value.replace("]=]", "] =]") + "]=]"


def write_runtime_lua(
    output_path: Path,
    racial_rows: list[dict[str, Any]],
    trinket_rows: list[dict[str, Any]],
    source_manifest: dict[str, Any],
) -> None:
    lines = [
        "-- Generated by TBC/Tools/build_wowhead_database.py. Do not edit by hand.",
        "local RUI = RetreatUI",
        "if not RUI then return end",
        "",
        "RUI.generatedTBCData = RUI.generatedTBCData or {}",
        f"RUI.generatedTBCData.generatedAt = {lua_quote(source_manifest['generated_at'])}",
        f"RUI.generatedTBCData.libSpellDBRevision = {lua_quote(source_manifest['sources']['libspelldb']['sha'])}",
        f"RUI.generatedTBCData.wowSimsRevision = {lua_quote(source_manifest['sources']['wowsims_tbc_new']['sha'])}",
        "",
        "RUI.generatedTBCData.racials = {",
    ]
    for row in racial_rows:
        if row["Type"] != "Racial":
            continue
        lines.extend(
            [
                "    {",
                f"        race = {lua_quote(str(row['Race']))},",
                f"        name = {lua_quote(str(row['Name']))},",
                f"        spellID = {int(row['Spell ID'])},",
                f"        canonicalID = {int(row['Canonical ID'])},",
                f"        category = {lua_quote(str(row['Category']))},",
                f"        hudRow = {lua_quote(str(row['HUD Row']))},",
                f"        cooldown = {float(row['Cooldown']) if row['Cooldown'] != '' else 0},",
                f"        duration = {float(row['Duration']) if row['Duration'] != '' else 0},",
                "    },",
            ]
        )
    lines.extend(["}", "", "RUI.generatedTBCData.trinkets = {"])
    for row in trinket_rows:
        lines.extend(
            [
                f"    [{int(row['Item ID'])}] = {{",
                f"        name = {lua_quote(str(row['Item Name']))},",
                f"        procBuffID = {int(row['Proc Buff ID']) if row['Proc Buff ID'] != '' else 0},",
                f"        onUseBuffID = {int(row['On-use Buff ID']) if row['On-use Buff ID'] != '' else 0},",
                f"        icd = {float(row['Internal Cooldown']) if row['Internal Cooldown'] != '' else 0},",
                f"        onTarget = {'true' if row['On Target'] == 'Yes' else 'false'},",
                "    },",
            ]
        )
    lines.extend(["}", ""])
    write_text(output_path, "\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="TBC/Data/generated", help="Generated CSV/JSON directory")
    parser.add_argument(
        "--runtime-lua",
        default="TBC/Package/RetreatUI/Core/GeneratedTBCData.lua",
        help="Generated runtime racial/trinket data",
    )
    parser.add_argument("--workers", type=int, default=12)
    args = parser.parse_args()

    output_dir = Path(args.output)
    runtime_lua = Path(args.runtime_lua)
    output_dir.mkdir(parents=True, exist_ok=True)

    with requests.Session() as session:
        lib_sha = github_head_sha(session, LIBSPELLDB_REPO)
        wowsims_sha = github_head_sha(session, WOWSIMS_REPO)
        print(f"LibSpellDB revision: {lib_sha}")
        print(f"WoWSims TBC revision: {wowsims_sha}")

        with tempfile.TemporaryDirectory(prefix="ruitbc-source-") as temp_dir_name:
            temp_dir = Path(temp_dir_name)
            lua_files: list[Path] = []
            for filename in list(CLASS_FILES.values()) + ["Racials.lua", "Trinkets.lua"]:
                destination = temp_dir / filename
                write_text(destination, download_raw(session, LIBSPELLDB_REPO, lib_sha, f"Data/{filename}"))
                lua_files.append(destination)

            extracted_path = temp_dir / "libspelldb.json"
            extracted = run_lua_extractor(lua_files, extracted_path)

            talent_data: dict[str, list[dict[str, Any]]] = {}
            for class_name, path in TALENT_FILES.items():
                talent_data[class_name] = json.loads(download_raw(session, WOWSIMS_REPO, wowsims_sha, path))

    spell_ids: set[int] = set()
    for entry in extracted.get("spells") or []:
        if entry.get("spellID"):
            spell_ids.add(int(entry["spellID"]))
        spell_ids.update(int(value) for value in (entry.get("ranks") or []) if value)
        spell_ids.update(aura_ids(entry))
    for trees in talent_data.values():
        for tree in trees:
            for talent in tree.get("talents") or []:
                spell_ids.update(int(value) for value in (talent.get("spellIds") or []) if value)
    for entry in extracted.get("trinkets") or []:
        if entry.get("procBuffID"):
            spell_ids.add(int(entry["procBuffID"]))
        if entry.get("onUseBuffID"):
            spell_ids.add(int(entry["onUseBuffID"]))

    item_ids = {int(entry["itemID"]) for entry in (extracted.get("trinkets") or []) if entry.get("itemID")}
    print(f"Candidate spell IDs: {len(spell_ids)}")
    print(f"Trackable passive-proc trinkets: {len(item_ids)}")

    spell_tooltips = fetch_tooltips("spell", spell_ids, workers=args.workers)
    item_tooltips = fetch_tooltips("item", item_ids, workers=min(args.workers, 8))

    all_records, racial_rows, missing = build_records(extracted, talent_data, spell_tooltips)
    trinket_rows, trinket_missing = build_trinkets(
        extracted.get("trinkets") or [], item_tooltips, spell_tooltips
    )
    missing.extend(trinket_missing)
    missing = list({(row["Entity Type"], int(row["ID"]), row["Class/Race"]): row for row in missing}.values())
    missing.sort(key=lambda row: (row["Entity Type"], row["Class/Race"], int(row["ID"])))

    class_counts: dict[str, int] = defaultdict(int)
    talent_counts: dict[str, int] = defaultdict(int)
    ability_counts: dict[str, int] = defaultdict(int)
    for row in all_records:
        class_counts[row["Class"]] += 1
        if row["Type"] in {"Talent", "Talent Ability"}:
            talent_counts[row["Class"]] += 1
        if row["Type"] in {"Ability", "Talent Ability"}:
            ability_counts[row["Class"]] += 1

    write_csv(output_dir / "all_spells.csv", ALL_SPELL_COLUMNS, all_records)
    for class_name in CLASS_FILES:
        class_rows = [row for row in all_records if row["Class"] == class_name]
        write_csv(
            output_dir / f"{class_name.lower().replace(' ', '_')}.csv",
            CLASS_COLUMNS,
            [{key: value for key, value in row.items() if key != "Class"} for row in class_rows],
        )
    write_csv(output_dir / "racials.csv", RACIAL_COLUMNS, racial_rows)
    write_csv(output_dir / "trinkets.csv", TRINKET_COLUMNS, trinket_rows)
    write_csv(output_dir / "missing_data.csv", MISSING_COLUMNS, missing)

    generated_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    manifest = {
        "generated_at": generated_at,
        "canonical_source": "Wowhead TBC tooltip JSON",
        "wowhead_tooltip_endpoint": f"{WOWHEAD_TOOLTIP_ROOT}/<spell|item>/<id>",
        "sources": {
            "wowhead": {"url": f"{WOWHEAD_PAGE_ROOT}/"},
            "libspelldb": {
                "repository": f"https://github.com/{LIBSPELLDB_REPO}",
                "sha": lib_sha,
                "purpose": "Ability enumeration, ranks, cooldowns, auras, tags, racials, passive trinket proc mappings",
            },
            "wowsims_tbc_new": {
                "repository": f"https://github.com/{WOWSIMS_REPO}",
                "sha": wowsims_sha,
                "purpose": "Complete TBC talent trees and every talent-rank spell ID",
            },
        },
        "counts": {
            "all_spell_rows": len(all_records),
            "unique_spell_ids": len({int(row["Spell ID"]) for row in all_records}),
            "racial_shared_rows": len(racial_rows),
            "racial_rows": sum(1 for row in racial_rows if row["Type"] == "Racial"),
            "trinket_proc_mappings": len(trinket_rows),
            "missing_tooltips": len(missing),
            "by_class": {
                class_name: {
                    "rows": class_counts[class_name],
                    "ability_rows": ability_counts[class_name],
                    "talent_rows": talent_counts[class_name],
                }
                for class_name in CLASS_FILES
            },
        },
        "tracking_policy": {
            "on_use_trinkets": "Detected dynamically in-game through GetItemSpell(); no static row required.",
            "passive_proc_trinkets": "Static item-to-visible-buff mapping generated from LibSpellDB and verified through Wowhead tooltips.",
            "racials": "Filtered at runtime by UnitRace and categorized into Main/Utility/Data only.",
        },
    }
    write_text(output_dir / "manifest.json", json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    write_runtime_lua(runtime_lua, racial_rows, trinket_rows, manifest)

    print(json.dumps(manifest["counts"], indent=2))
    if missing:
        print(f"WARNING: {len(missing)} tooltip records need review; see missing_data.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())

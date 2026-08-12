#!/usr/bin/env python3
"""Generate static beta.20 CoA WeakAuras exports.

The runtime addon never builds aura tables. This script runs at build time and
turns the curated CoA Data.lua catalogues into ordinary !WA:2! payloads using
only standard WeakAuras triggers. Layout geometry mirrors the user-supplied
NaowhUI TBC class packs while avoiding their custom-grow Lua by using three
normal dynamic groups for the Main rows.
"""
from __future__ import annotations

import hashlib
import re
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLASS_ROOT = ROOT / "RetreatUI_Classes"
OUTPUT = ROOT / "RetreatUI" / "Data" / "WeakAurasBeta20Payloads.lua"

ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789()"
FONT = "Fira Sans Heavy"
TEXTURE = "ElvUI Norm"
TOC = 30300
INTERNAL = 90


def bint(value: int, size: int) -> bytes:
    return int(value).to_bytes(size, "big", signed=False)


def serialize_value(value):
    if value is None:
        return bytes([0])
    if value is True:
        return bytes([12 * 8])
    if value is False:
        return bytes([13 * 8])
    if isinstance(value, int):
        negative = value < 0
        absolute = abs(value)
        if absolute <= 0xFFFF:
            return bytes([(2 if negative else 1) * 8]) + bint(absolute, 2)
        if absolute <= 0xFFFFFF:
            return bytes([(4 if negative else 3) * 8]) + bint(absolute, 3)
        if absolute <= 0xFFFFFFFF:
            return bytes([(6 if negative else 5) * 8]) + bint(absolute, 4)
        if absolute <= 0xFFFFFFFFFFFFFF:
            return bytes([(8 if negative else 7) * 8]) + bint(absolute, 7)
        return bytes([9 * 8]) + struct.pack(">d", float(value))
    if isinstance(value, float):
        if value.is_integer() and abs(value) <= 0xFFFFFFFF:
            return serialize_value(int(value))
        return bytes([9 * 8]) + struct.pack(">d", value)
    if isinstance(value, str):
        raw = value.encode("utf-8")
        length = len(raw)
        if length <= 0xFF:
            return bytes([14 * 8]) + bint(length, 1) + raw
        if length <= 0xFFFF:
            return bytes([15 * 8]) + bint(length, 2) + raw
        if length <= 0xFFFFFF:
            return bytes([16 * 8]) + bint(length, 3) + raw
        raise ValueError("String too large for LibSerialize")
    if isinstance(value, (list, tuple)):
        length = len(value)
        if length <= 0xFF:
            head = bytes([20 * 8]) + bint(length, 1)
        elif length <= 0xFFFF:
            head = bytes([21 * 8]) + bint(length, 2)
        else:
            head = bytes([22 * 8]) + bint(length, 3)
        return head + b"".join(serialize_value(item) for item in value)
    if isinstance(value, dict):
        items = list(value.items())
        length = len(items)
        if length <= 0xFF:
            head = bytes([17 * 8]) + bint(length, 1)
        elif length <= 0xFFFF:
            head = bytes([18 * 8]) + bint(length, 2)
        else:
            head = bytes([19 * 8]) + bint(length, 3)
        return head + b"".join(serialize_value(key) + serialize_value(item) for key, item in items)
    raise TypeError(type(value))


def encode_for_print(data: bytes) -> str:
    output = []
    bitfield = 0
    bitlen = 0
    for byte in data:
        bitfield |= byte << bitlen
        bitlen += 8
        while bitlen >= 6:
            output.append(ALPHABET[bitfield & 0x3F])
            bitfield >>= 6
            bitlen -= 6
    if bitlen:
        output.append(ALPHABET[bitfield & 0x3F])
    return "".join(output)


def export_wa(transmission: dict) -> str:
    serialized = bytes([1]) + serialize_value(transmission)
    compressor = zlib.compressobj(9, zlib.DEFLATED, -15)
    compressed = compressor.compress(serialized) + compressor.flush()
    return "!WA:2!" + encode_for_print(compressed)


def uid(text: str) -> str:
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
    return "R" + digest[:15]


def animation():
    none = {"type": "none", "duration_type": "seconds", "easeType": "none", "easeStrength": 3}
    return {"start": dict(none), "main": dict(none), "finish": dict(none)}


def dummy_trigger():
    return {
        1: {"trigger": {"type": "aura2", "event": "Health", "unit": "player", "debuffType": "HELPFUL", "names": {}, "spellIds": {}, "subeventPrefix": "SPELL", "subeventSuffix": "_CAST_START"}, "untrigger": {}},
        "activeTriggerMode": -10,
        "disjunctive": "any",
    }


def base(aura_id: str, parent: str | None = None):
    data = {
        "id": aura_id,
        "uid": uid(aura_id),
        "internalVersion": INTERNAL,
        "tocversion": TOC,
        "actions": {"start": {"do_custom": False}, "finish": {"do_custom": False}, "init": {"do_custom": False}},
        "animation": animation(),
        "authorOptions": [],
        "conditions": [],
        "config": [],
        "information": [],
        "load": {"spec": {"multi": {}}, "use_never": False},
        "alpha": 1,
        "frameStrata": 1,
    }
    if parent:
        data["parent"] = parent
    return data


def static_group(aura_id: str, parent: str | None, children: list[str], x=0, y=0):
    data = base(aura_id, parent)
    data.update({
        "regionType": "group", "controlledChildren": children,
        "anchorFrameType": "SCREEN", "anchorPoint": "CENTER", "selfPoint": "CENTER",
        "xOffset": x, "yOffset": y, "scale": 1, "subRegions": [], "triggers": dummy_trigger(),
    })
    return data


def dynamic_group(aura_id: str, parent: str, children: list[str], y: int, spacing: int, max_per_row: int, icon_height: int):
    data = base(aura_id, parent)
    data.update({
        "regionType": "dynamicgroup", "controlledChildren": children,
        "anchorFrameType": "SCREEN", "anchorPoint": "CENTER", "selfPoint": "CENTER",
        "xOffset": 0, "yOffset": y, "grow": "HORIZONTAL", "align": "CENTER", "sort": "none",
        "space": spacing, "stagger": 0, "animate": False, "scale": 1,
        "gridType": "RD", "centerType": "LR", "gridWidth": max_per_row,
        "rowSpace": spacing, "columnSpace": spacing, "useLimit": True, "limit": max_per_row,
        "fullCircle": True, "rotation": 0, "radius": 200, "stepAngle": 15,
        "constantFactor": "RADIUS", "subRegions": [], "triggers": dummy_trigger(),
        "height": icon_height,
    })
    return data


def border():
    return {"type": "subborder", "border_visible": True, "border_color": [0, 0, 0, 1], "border_edge": "Square Full White", "border_offset": 1, "border_size": 1}


def timer_text():
    return {
        "type": "subtext", "text_visible": True, "text_text": "%p", "text_font": FONT,
        "text_fontSize": 14, "text_fontType": "OUTLINE", "text_color": [1, 1, 1, 1],
        "text_justify": "CENTER", "text_selfPoint": "AUTO", "anchor_point": "CENTER",
        "anchorXOffset": 0, "anchorYOffset": 0,
        "text_text_format_p_format": "timed", "text_text_format_p_time_precision": 1,
        "text_text_format_p_time_legacy_floor": True, "text_text_format_p_time_mod_rate": True,
    }


def glow(enabled: bool):
    return {
        "type": "subglow", "glow": enabled, "glowType": "Pixel", "glowColor": [1, 1, 1, 1],
        "useGlowColor": enabled, "glowThickness": 1, "glowScale": 1, "glowLines": 8,
        "glowLength": 10, "glowFrequency": 0.25, "glowDuration": 1,
        "glowXOffset": 0, "glowYOffset": 0, "glowBorder": False,
    }


def spell_trigger(name: str, spell_id: int | None):
    spell = spell_id if spell_id else name
    return {
        "type": "spell", "event": "Cooldown Progress (Spell)", "unit": "player", "debuffType": "HELPFUL",
        "use_spellName": True, "spellName": spell, "realSpellName": name,
        "use_genericShowOn": True, "genericShowOn": "showAlways", "use_track": True,
        "names": {}, "spellIds": {}, "subeventPrefix": "SPELL", "subeventSuffix": "_CAST_START",
    }


def aura_trigger(name: str, spell_id: int | None, target=False):
    aura_name = str(spell_id) if spell_id else name
    trigger = {
        "type": "aura2", "event": "Health", "unit": "target" if target else "player",
        "debuffType": "HARMFUL" if target else "HELPFUL", "useName": True,
        "auranames": [aura_name], "names": {}, "spellIds": {},
        "matchesShowOn": "showOnActive", "subeventPrefix": "SPELL", "subeventSuffix": "_CAST_START",
    }
    if target:
        trigger["ownOnly"] = True
    return trigger


def load_for_spell(spell_id: int | None):
    load = {"spec": {"multi": {}}, "use_never": False}
    if spell_id:
        load["use_spellknown"] = True
        load["spellknown"] = spell_id
    return load


def icon(aura_id: str, parent: str, name: str, spell_id: int | None, width: int, height: int, active=False, target=False):
    data = base(aura_id, parent)
    data.update({
        "regionType": "icon", "width": width, "height": height,
        "anchorFrameType": "SCREEN", "anchorPoint": "CENTER", "selfPoint": "CENTER",
        "xOffset": 0, "yOffset": 0, "color": [1, 1, 1, 1], "icon": True,
        "iconSource": -1, "displayIcon": spell_id or 134400, "progressSource": [-1, ""],
        "cooldown": True, "cooldownSwipe": not active, "cooldownTextDisabled": False,
        "cooldownEdge": False, "zoom": 0.30, "keepAspectRatio": False,
        "subRegions": [{"type": "subbackground"}, border(), glow(active), timer_text()],
    })
    if active:
        data["triggers"] = {1: {"trigger": aura_trigger(name, spell_id, target), "untrigger": {}}, "activeTriggerMode": -10, "disjunctive": "any"}
        data["load"] = {"spec": {"multi": {}}, "use_never": False}
    else:
        triggers = {1: {"trigger": spell_trigger(name, spell_id), "untrigger": {}}, "activeTriggerMode": -10, "disjunctive": "any"}
        if target:
            triggers[1] = {"trigger": aura_trigger(name, spell_id, True), "untrigger": {}}
            triggers[2] = {"trigger": spell_trigger(name, spell_id), "untrigger": {}}
        data["triggers"] = triggers
        data["load"] = load_for_spell(spell_id)
    return data


def power_bar(aura_id: str, parent: str):
    data = base(aura_id, parent)
    data.update({
        "regionType": "aurabar", "width": 348, "height": 4,
        "anchorFrameType": "SCREEN", "anchorPoint": "CENTER", "selfPoint": "CENTER",
        "xOffset": 0, "yOffset": -189, "orientation": "HORIZONTAL", "inverse": False,
        "icon": False, "texture": TEXTURE, "textureSource": "LSM",
        "barColor": [0.78, 0.61, 0.43, 1], "backgroundColor": [0, 0, 0, 0.60],
        "spark": False, "progressSource": [1, ""],
        "triggers": {1: {"trigger": {"type": "unit", "event": "Power", "unit": "player", "use_unit": True, "debuffType": "HELPFUL", "use_percentpower": False, "use_requirePowerType": False, "genericShowOn": "showAlways", "names": {}, "spellIds": {}, "subeventPrefix": "SPELL", "subeventSuffix": "_CAST_START"}, "untrigger": {}}, "activeTriggerMode": -10, "disjunctive": "any"},
        "subRegions": [{"type": "subbackground"}, border()],
    })
    return data


def stack_resource_bar(aura_id: str, parent: str, name: str, spell_id: int | None, y: int):
    data = base(aura_id, parent)
    data.update({
        "regionType": "aurabar", "width": 348, "height": 4,
        "anchorFrameType": "SCREEN", "anchorPoint": "CENTER", "selfPoint": "CENTER",
        "xOffset": 0, "yOffset": y, "orientation": "HORIZONTAL", "inverse": False,
        "icon": False, "texture": TEXTURE, "textureSource": "LSM",
        "barColor": [0.95, 0.31, 0.08, 1], "backgroundColor": [0, 0, 0, 0.60], "spark": False,
        "progressSource": [1, ""],
        "triggers": {1: {"trigger": aura_trigger(name, spell_id, False), "untrigger": {}}, "activeTriggerMode": -10, "disjunctive": "any"},
        "subRegions": [
            {"type": "subbackground"}, border(),
            {"type": "subtext", "text_visible": True, "text_text": "%s", "text_font": FONT, "text_fontSize": 10, "text_fontType": "OUTLINE", "text_color": [1, 1, 1, 1], "text_justify": "CENTER", "text_selfPoint": "CENTER", "anchor_point": "CENTER", "anchorXOffset": 0, "anchorYOffset": 0},
        ],
    })
    return data


def parse_string(line: str, key: str):
    match = re.search(rf'\b{re.escape(key)}\s*=\s*"((?:\\.|[^"\\])*)"', line)
    if not match:
        return None
    return bytes(match.group(1), "utf-8").decode("unicode_escape")


def parse_number(line: str, key: str):
    match = re.search(rf'\b{re.escape(key)}\s*=\s*(-?\d+(?:\.\d+)?)', line)
    if not match:
        return None
    value = float(match.group(1))
    return int(value) if value.is_integer() else value


def parse_bool(line: str, key: str):
    match = re.search(rf'\b{re.escape(key)}\s*=\s*(true|false)', line)
    if not match:
        return None
    return match.group(1) == "true"


def parse_class(path: Path):
    text = path.read_text(encoding="utf-8")
    match = re.search(r'RegisterClassSpellDatabase\("([^"]+)"', text)
    if not match:
        return None
    class_name = match.group(1)
    pre_spells = text.split("spells = {", 1)[0]
    resources = []
    for chunk in re.findall(r'\{key="[^"]+"[^{}]*\}', pre_spells):
        resources.append({
            "name": parse_string(chunk, "name"),
            "key": parse_string(chunk, "key"),
            "type": parse_string(chunk, "type"),
            "max": parse_number(chunk, "max"),
        })

    native_match = re.search(r'nativeResource\s*=\s*\{([^\n]+)\}', pre_spells)
    if native_match:
        native = native_match.group(1)
        aura_match = re.search(r'auraNames\s*=\s*\{"([^"]+)"', native)
        resources.append({
            "name": parse_string(native, "title") or (aura_match.group(1) if aura_match else "Class Resource"),
            "key": "native", "type": "stacks",
            "max": parse_number(native, "maxStacks"),
            "id": parse_number(native, "spellID"),
            "aura": aura_match.group(1) if aura_match else None,
        })

    spells = []
    for line in text.splitlines():
        if not re.match(r'^\s*\{name="', line):
            continue
        name = parse_string(line, "name")
        if not name:
            continue
        spells.append({
            "name": name,
            "id": parse_number(line, "id"),
            "category": parse_string(line, "category"),
            "row": parse_string(line, "hudRow"),
            "order": parse_number(line, "order") or 9999,
            "cooldown": parse_bool(line, "trackCooldown") is True,
            "aura": parse_bool(line, "auraTracker") is True,
            "target": parse_bool(line, "targetDebuff") is True,
            "review": parse_bool(line, "review") is True,
            "trackHUD": parse_bool(line, "trackHUD"),
            "buff": parse_string(line, "buff"),
            "maxStacks": parse_number(line, "maxStacks"),
        })
    return class_name, resources, spells


def build_class(class_name: str, resources: list[dict], spells: list[dict]):
    safe = class_name
    root_id = f"{safe} Class Pack"
    aura_id = f"Aura Bar - {safe}"
    main_id = f"Main - {safe}"
    resource_id = f"Resources - {safe}"
    aux_id = f"Aux Bar - {safe}"

    main = sorted((s for s in spells if s["row"] == "core" and s["cooldown"] and not s["review"]), key=lambda s: (s["order"], s["name"]))[:26]
    utility = sorted((s for s in spells if s["row"] == "utility" and s["cooldown"] and not s["review"]), key=lambda s: (s["order"], s["name"]))[:18]
    active = sorted((s for s in spells if not s["review"] and (s["aura"] or (s["target"] and s["row"] not in {"core", "utility"})) and s["trackHUD"] is not False), key=lambda s: (s["order"], s["name"]))[:24]
    # Proc records were historically marked trackHUD=false because the old addon
    # rendered them itself. In beta.20 WeakAuras owns them, so include curated
    # proc/buff aura records even when that old runtime marker is false.
    proc_candidates = sorted((s for s in spells if not s["review"] and s["aura"] and s["category"] in {"proc", "buff"}), key=lambda s: (s["order"], s["name"]))
    seen = {s["name"] for s in active}
    for record in proc_candidates:
        if record["name"] not in seen and len(active) < 24:
            active.append(record); seen.add(record["name"])

    children = []
    aura_children = []
    row_children = [[], [], []]
    aux_children = []
    resource_children = []

    for record in active:
        child_id = f"{record['name']} (Active) - {safe}"
        aura_children.append(child_id)
        children.append(icon(child_id, aura_id, record.get("buff") or record["name"], record["id"], 34, 26, active=True, target=record["target"]))

    for index, record in enumerate(main):
        row = 0 if index < 9 else 1 if index < 18 else 2
        child_id = f"{record['name']} - {safe}"
        row_children[row].append(child_id)
        width, height = (36, 28) if row == 0 else (34, 26)
        children.append(icon(child_id, f"Main Row {row + 1} - {safe}", record["name"], record["id"], width, height, active=False, target=record["target"]))

    for record in utility:
        child_id = f"{record['name']} - {safe} Aux"
        aux_children.append(child_id)
        children.append(icon(child_id, aux_id, record["name"], record["id"], 36, 28, active=False, target=record["target"]))

    primary_id = f"{safe} - Primary Power"
    resource_children.append(primary_id)
    children.append(power_bar(primary_id, resource_id))
    resource_y = -194
    for resource in resources:
        if resource.get("type") != "stacks":
            continue
        resource_name = resource.get("aura") or resource.get("name") or resource.get("key")
        if not resource_name:
            continue
        child_id = f"{safe} - {resource_name}"
        resource_children.append(child_id)
        children.append(stack_resource_bar(child_id, resource_id, resource_name, resource.get("id"), resource_y))
        resource_y -= 5

    row_group_ids = [f"Main Row {index} - {safe}" for index in (1, 2, 3)]
    root_children = [aura_id, main_id, resource_id, aux_id]
    class_nodes = [
        static_group(root_id, None, root_children),
        dynamic_group(aura_id, root_id, aura_children, 47, 4, 24, 26),
        static_group(main_id, root_id, row_group_ids),
        dynamic_group(row_group_ids[0], main_id, row_children[0], -17, 3, 9, 28),
        dynamic_group(row_group_ids[1], main_id, row_children[1], -47, 3, 9, 26),
        dynamic_group(row_group_ids[2], main_id, row_children[2], -76, 3, 8, 26),
        static_group(resource_id, root_id, resource_children),
        dynamic_group(aux_id, root_id, aux_children, -239, 3, 18, 28),
    ]
    class_nodes.extend(children)
    transmission = {"s": "5.21.2", "m": "d", "d": class_nodes[0], "c": class_nodes[1:], "v": 2000}
    return export_wa(transmission)


def trinket_icon(slot: int, parent: str):
    aura_id = f"Trinket {1 if slot == 13 else 2}"
    data = base(aura_id, parent)
    data.update({
        "regionType": "icon", "width": 34, "height": 26,
        "anchorFrameType": "SCREEN", "anchorPoint": "CENTER", "selfPoint": "CENTER",
        "xOffset": 0, "yOffset": 0, "icon": True, "iconSource": -1, "displayIcon": 134400,
        "progressSource": [-1, ""], "cooldown": True, "cooldownSwipe": True, "cooldownEdge": False,
        "zoom": 0.30, "subRegions": [{"type": "subbackground"}, border(), glow(False), timer_text()],
        "triggers": {1: {"trigger": {"type": "item", "event": "Cooldown Progress (Equipment Slot)", "unit": "player", "use_unit": True, "itemSlot": slot, "use_itemSlot": True, "use_testForCooldown": True, "use_genericShowOn": True, "genericShowOn": "showAlways", "debuffType": "HELPFUL", "names": {}, "spellIds": {}, "subeventPrefix": "SPELL", "subeventSuffix": "_CAST_START"}, "untrigger": {}}, "activeTriggerMode": -10, "disjunctive": "any"},
    })
    return data


def build_general():
    root = "RetreatUI - General"
    group = "Aura bar (Player buffs)"
    children = ["Trinket 1", "Trinket 2"]
    root_node = static_group(root, None, [group])
    group_node = dynamic_group(group, root, children, 2, 4, 24, 26)
    group_node["xOffset"] = -1
    nodes = [group_node, trinket_icon(13, group), trinket_icon(14, group)]
    return export_wa({"s": "5.21.2", "m": "d", "d": root_node, "c": nodes, "v": 2000})


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    classes = []
    for path in sorted(CLASS_ROOT.glob("*/Data.lua")):
        parsed = parse_class(path)
        if parsed:
            classes.append(parsed)
    if len(classes) != 21:
        raise SystemExit(f"Expected 21 CoA class databases, found {len(classes)}")

    lines = [
        "local RUI = RetreatUI",
        "if not RUI then return end",
        "RUI.NaowhCoAWeakAuras = RUI.NaowhCoAWeakAuras or {classes = {}}",
        "RUI.NaowhCoAWeakAuras.classes = RUI.NaowhCoAWeakAuras.classes or {}",
        f"RUI.NaowhCoAWeakAuras.general = {lua_quote(build_general())}",
    ]
    for class_name, resources, spells in classes:
        payload = build_class(class_name, resources, spells)
        lines.append(f"RUI.NaowhCoAWeakAuras.classes[{lua_quote(class_name)}] = {lua_quote(payload)}")
    lines.extend([
        "RUI.NaowhCoAWeakAuras.generatedFor = \"1.1.7-beta.20\"",
        "RUI.NaowhCoAWeakAuras.weakAurasVersion = \"5.21.2\"",
        "RUI._beta20StaticWeakAuraPayloadsLoaded = true",
        "",
    ])
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated {len(classes)} class payloads -> {OUTPUT}")


if __name__ == "__main__":
    main()

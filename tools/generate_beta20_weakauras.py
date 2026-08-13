#!/usr/bin/env python3
"""Generate the static RetreatUI beta.20 CoA WeakAuras registry.

The generator runs at build time only. The addon ships normal !WA:2! payloads;
RetreatUI does not build triggers, layouts or synthetic WeakAuras events at
runtime.
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
WA_VERSION = "5.21.2"
CLASS_ANCHOR = "WeakAuras:Class Power Bar"

CLASS_NAMES = [
    "Barbarian", "Bloodmage", "Chronomancer", "Cultist", "Felsworn", "Guardian",
    "Knight of Xoroth", "Necromancer", "Primalist", "Pyromancer", "Ranger", "Reaper",
    "Runemaster", "Starcaller", "Stormbringer", "Sun Cleric", "Templar", "Tinker",
    "Venomancer", "Witch Doctor", "Witch Hunter",
]

REFERENCE_MAIN_GROW = r'''function(newPositions, activeRegions)
    local firstRowLimit = 9
    local wFR = 36
    local hFR = 28
    local fsFR = "LOW"
    local secondRowLimit = 9
    local wSR = 34
    local hSR = 26
    local fsSR = "BACKGROUND"
    local lastRowLimit = 8
    local wLR = 34
    local hLR = 26
    local fsLR = "BACKGROUND"
    local spacing = 3
    local correctionYspacing = -1
    local xCount = 0
    local xOffset = 0
    local yOffset = 0
    local total = #activeRegions
    for i, regionData in ipairs(activeRegions) do
        local region = regionData.region
        local rowTotal = 1
        local localWidth = 1
        local localHeight = 1
        local currentRow = 0
        if i <= firstRowLimit then
            localWidth = wFR
            localHeight = hFR
            localFrameStrata = fsFR
            if total <= firstRowLimit then rowTotal = total else rowTotal = firstRowLimit end
        elseif i <= secondRowLimit + firstRowLimit then
            localWidth = wSR
            localHeight = hSR
            localFrameStrata = fsSR
            currentRow = 1
            if total <= firstRowLimit + secondRowLimit then
                rowTotal = total - firstRowLimit
            else
                rowTotal = secondRowLimit
            end
        else
            localWidth = wLR
            localHeight = hLR
            localFrameStrata = fsLR
            currentRow = 2
            rowTotal = total - firstRowLimit - secondRowLimit
        end
        region:SetRegionWidth(localWidth)
        region:SetRegionHeight(localHeight)
        region:SetFrameStrata(localFrameStrata)
        xOffset = 0 - (region.width + spacing) / 2 * (rowTotal - 1) + (xCount * (region.width + spacing))
        if currentRow == 1 then
            yOffset = 0 - hFR - spacing - correctionYspacing
        elseif currentRow == 2 then
            yOffset = 0 - (hFR + hSR) - spacing * 2 - correctionYspacing
        end
        xCount = xCount + 1
        if xCount >= rowTotal then xCount = 0 end
        newPositions[i] = {xOffset, yOffset}
    end
end'''


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
        size = 1 if length <= 0xFF else 2 if length <= 0xFFFF else 3
        marker = 20 if size == 1 else 21 if size == 2 else 22
        return bytes([marker * 8]) + bint(length, size) + b"".join(serialize_value(v) for v in value)
    if isinstance(value, dict):
        items = list(value.items())
        length = len(items)
        size = 1 if length <= 0xFF else 2 if length <= 0xFFFF else 3
        marker = 17 if size == 1 else 18 if size == 2 else 19
        return bytes([marker * 8]) + bint(length, size) + b"".join(
            serialize_value(k) + serialize_value(v) for k, v in items
        )
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
    return "R" + hashlib.sha256(text.encode("utf-8")).hexdigest()[:15]


def animation():
    none = {"type": "none", "duration_type": "seconds", "easeType": "none", "easeStrength": 3}
    return {"start": dict(none), "main": dict(none), "finish": dict(none)}


def dummy_trigger():
    return {
        1: {"trigger": {"type": "aura2", "event": "Health", "unit": "player", "debuffType": "HELPFUL", "names": [], "spellIds": [], "subeventPrefix": "SPELL", "subeventSuffix": "_CAST_START"}, "untrigger": {}},
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
        "authorOptions": [], "conditions": [], "config": [], "information": [],
        "load": {"spec": {"multi": {}}, "use_never": False},
        "alpha": 1, "frameStrata": 1,
    }
    if parent:
        data["parent"] = parent
    return data


def static_group(aura_id: str, parent: str | None, children: list[str]):
    data = base(aura_id, parent)
    data.update({
        "regionType": "group", "controlledChildren": children,
        "anchorFrameType": "SCREEN", "anchorPoint": "CENTER", "selfPoint": "CENTER",
        "xOffset": 0, "yOffset": 0, "scale": 1, "subRegions": [], "triggers": dummy_trigger(),
    })
    return data


def dynamic_group(aura_id: str, parent: str, children: list[str], *, anchor: str,
                  self_point: str, y: int, grow: str, spacing: int,
                  frame: str = CLASS_ANCHOR, align: str = "CENTER"):
    data = base(aura_id, parent)
    data.update({
        "regionType": "dynamicgroup", "controlledChildren": children,
        "anchorFrameType": "SELECTFRAME" if frame else "SCREEN",
        "anchorPoint": anchor, "selfPoint": self_point, "xOffset": 0, "yOffset": y,
        "grow": grow, "align": align, "sort": "none", "space": spacing,
        "stagger": 0, "animate": False, "scale": 1, "gridType": "RD",
        "centerType": "LR", "gridWidth": 26, "rowSpace": spacing,
        "columnSpace": spacing, "useLimit": False, "limit": 26,
        "fullCircle": True, "rotation": 0, "radius": 200, "stepAngle": 15,
        "constantFactor": "RADIUS", "subRegions": [], "triggers": dummy_trigger(),
    })
    if frame:
        data["anchorFrameFrame"] = frame
    if grow == "CUSTOM":
        data["customGrow"] = REFERENCE_MAIN_GROW
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
    return {"type": "subglow", "glow": enabled, "glowType": "Pixel", "glowColor": [1, 1, 1, 1], "useGlowColor": enabled, "glowThickness": 1, "glowScale": 1, "glowLines": 8, "glowLength": 10, "glowFrequency": 0.25, "glowDuration": 1, "glowXOffset": 0, "glowYOffset": 0, "glowBorder": False}


def spell_trigger(name: str, spell_id: int | None):
    return {
        "type": "spell", "event": "Cooldown Progress (Spell)", "unit": "player",
        "debuffType": "HELPFUL", "use_spellName": True,
        "spellName": spell_id if spell_id else name, "realSpellName": name,
        "use_genericShowOn": True, "genericShowOn": "showAlways", "use_track": True,
        "names": [], "spellIds": [], "subeventPrefix": "SPELL", "subeventSuffix": "_CAST_START",
    }


def aura_trigger(name: str, spell_id: int | None, target: bool = False):
    trigger = {
        "type": "aura2", "event": "Health", "unit": "target" if target else "player",
        "debuffType": "HARMFUL" if target else "HELPFUL", "useName": True,
        "auranames": [str(spell_id) if spell_id else name], "names": [], "spellIds": [],
        "matchesShowOn": "showOnActive", "subeventPrefix": "SPELL", "subeventSuffix": "_CAST_START",
    }
    if target:
        trigger["ownOnly"] = True
    return trigger


def icon(aura_id: str, parent: str, name: str, spell_id: int | None,
         width: int, height: int, *, active: bool = False, target: bool = False):
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
    else:
        data["triggers"] = {1: {"trigger": spell_trigger(name, spell_id), "untrigger": {}}, "activeTriggerMode": -10, "disjunctive": "any"}

    # Deliberately no Spell Known load condition. CoA custom numeric IDs can
    # reach GetSpellInfo's legacy slot path while the load function is scanned.
    data["load"] = {"spec": {"multi": {}}, "use_never": False}
    return data


def power_bar(aura_id: str, parent: str):
    data = base(aura_id, parent)
    data.update({
        "regionType": "aurabar", "width": 348, "height": 4,
        "anchorFrameType": "SELECTFRAME", "anchorFrameFrame": CLASS_ANCHOR,
        "anchorPoint": "CENTER", "selfPoint": "CENTER", "xOffset": 0, "yOffset": 0,
        "orientation": "HORIZONTAL", "inverse": False, "icon": False,
        "texture": TEXTURE, "textureSource": "LSM", "barColor": [0.78, 0.61, 0.43, 1],
        "backgroundColor": [0, 0, 0, 0.60], "spark": False, "progressSource": [1, ""],
        "triggers": {1: {"trigger": {"type": "unit", "event": "Power", "unit": "player", "use_unit": True, "debuffType": "HELPFUL", "use_percentpower": False, "use_requirePowerType": False, "genericShowOn": "showAlways", "names": [], "spellIds": [], "subeventPrefix": "SPELL", "subeventSuffix": "_CAST_START"}, "untrigger": {}}, "activeTriggerMode": -10, "disjunctive": "any"},
        "subRegions": [{"type": "subbackground"}, border()],
    })
    return data


def stack_resource_bar(aura_id: str, parent: str, name: str, spell_id: int | None):
    data = base(aura_id, parent)
    data.update({
        "regionType": "aurabar", "width": 348, "height": 4,
        "anchorFrameType": "SELECTFRAME", "anchorFrameFrame": CLASS_ANCHOR,
        "anchorPoint": "CENTER", "selfPoint": "CENTER", "xOffset": 0, "yOffset": 0,
        "orientation": "HORIZONTAL", "inverse": False, "icon": False,
        "texture": TEXTURE, "textureSource": "LSM", "barColor": [0.95, 0.31, 0.08, 1],
        "backgroundColor": [0, 0, 0, 0.60], "spark": False, "progressSource": [1, ""],
        "triggers": {1: {"trigger": aura_trigger(name, spell_id, False), "untrigger": {}}, "activeTriggerMode": -10, "disjunctive": "any"},
        "subRegions": [{"type": "subbackground"}, border(), {"type": "subtext", "text_visible": True, "text_text": "%s", "text_font": FONT, "text_fontSize": 10, "text_fontType": "OUTLINE", "text_color": [1, 1, 1, 1], "text_justify": "CENTER", "text_selfPoint": "CENTER", "anchor_point": "CENTER", "anchorXOffset": 0, "anchorYOffset": 0}],
    })
    return data


def trinket_icon(slot: int, parent: str):
    aura_id = f"Trinket {1 if slot == 13 else 2}"
    data = base(aura_id, parent)
    data.update({
        "regionType": "icon", "width": 34, "height": 26,
        "anchorFrameType": "SCREEN", "anchorPoint": "CENTER", "selfPoint": "CENTER",
        "xOffset": 0, "yOffset": 0, "icon": True, "iconSource": -1,
        "displayIcon": 134400, "progressSource": [-1, ""], "cooldown": True,
        "cooldownSwipe": True, "cooldownEdge": False, "zoom": 0.30,
        "subRegions": [{"type": "subbackground"}, border(), glow(False), timer_text()],
        "triggers": {1: {"trigger": {"type": "item", "event": "Cooldown Progress (Equipment Slot)", "unit": "player", "use_unit": True, "itemSlot": slot, "use_itemSlot": True, "use_testForCooldown": True, "use_genericShowOn": True, "genericShowOn": "showAlways", "debuffType": "HELPFUL", "names": [], "spellIds": [], "subeventPrefix": "SPELL", "subeventSuffix": "_CAST_START"}, "untrigger": {}}, "activeTriggerMode": -10, "disjunctive": "any"},
    })
    return data


def class_power_anchor():
    data = base("Class Power Bar", "Anchors")
    data.update({
        "regionType": "aurabar", "width": 348, "height": 4,
        "anchorFrameType": "SCREEN", "anchorPoint": "CENTER", "selfPoint": "CENTER",
        "xOffset": 0, "yOffset": -189, "orientation": "HORIZONTAL", "inverse": False,
        "icon": False, "texture": TEXTURE, "textureSource": "LSM",
        "barColor": [0, 0, 0, 0], "backgroundColor": [0, 0, 0, 0], "spark": False,
        "progressSource": [1, ""], "triggers": dummy_trigger(),
        "subRegions": [{"type": "subbackground"}, border()],
    })
    data["load"]["use_never"] = True
    return data


def build_general():
    root_id = "Core & Essentials"
    anchors_id = "Anchors"
    ui_id = "UI Elements"
    buffs_id = "Aura bar (Player buffs)"
    root = static_group(root_id, None, [anchors_id, ui_id])
    anchors = static_group(anchors_id, root_id, ["Class Power Bar"])
    ui = static_group(ui_id, root_id, [buffs_id])
    buffs = dynamic_group(buffs_id, ui_id, ["Trinket 1", "Trinket 2"], anchor="TOPRIGHT", self_point="BOTTOMRIGHT", y=2, grow="GRID", spacing=3, frame="ElvUF_Player", align="RIGHT")
    buffs["xOffset"] = -1
    buffs["gridType"] = "LU"
    buffs["gridWidth"] = 6
    buffs["rowSpace"] = 3
    buffs["columnSpace"] = 3
    return export_wa({"s": WA_VERSION, "m": "d", "d": root, "c": [anchors, class_power_anchor(), ui, buffs, trinket_icon(13, buffs_id), trinket_icon(14, buffs_id)], "v": 2000})


def parse_string(line: str, key: str):
    match = re.search(rf'\b{re.escape(key)}\s*=\s*"((?:\\.|[^"\\])*)"', line)
    return bytes(match.group(1), "utf-8").decode("unicode_escape") if match else None


def parse_number(line: str, key: str):
    match = re.search(rf'\b{re.escape(key)}\s*=\s*(-?\d+(?:\.\d+)?)', line)
    if not match:
        return None
    value = float(match.group(1))
    return int(value) if value.is_integer() else value


def parse_bool(line: str, key: str):
    match = re.search(rf'\b{re.escape(key)}\s*=\s*(true|false)', line)
    return None if not match else match.group(1) == "true"


def parse_class(path: Path):
    text = path.read_text(encoding="utf-8")
    match = re.search(r'RegisterClassSpellDatabase\("([^"]+)"', text)
    if not match:
        return None
    class_name = match.group(1)
    before_spells = text.split("spells = {", 1)[0]
    resources = []
    for chunk in re.findall(r'\{key="[^"]+"[^{}]*\}', before_spells):
        resources.append({"name": parse_string(chunk, "name"), "key": parse_string(chunk, "key"), "type": parse_string(chunk, "type"), "max": parse_number(chunk, "max")})
    native = re.search(r'nativeResource\s*=\s*\{([^\n]+)\}', before_spells)
    if native:
        chunk = native.group(1)
        aura = re.search(r'auraNames\s*=\s*\{"([^"]+)"', chunk)
        resources.append({"name": parse_string(chunk, "title") or (aura.group(1) if aura else "Class Resource"), "key": "native", "type": "stacks", "max": parse_number(chunk, "maxStacks"), "id": parse_number(chunk, "spellID"), "aura": aura.group(1) if aura else None})
    spells = []
    for line in text.splitlines():
        if not re.match(r'^\s*\{name="', line):
            continue
        name = parse_string(line, "name")
        if not name:
            continue
        spells.append({
            "name": name, "id": parse_number(line, "id"), "category": parse_string(line, "category"),
            "row": parse_string(line, "hudRow"), "order": parse_number(line, "order") or 9999,
            "cooldown": parse_bool(line, "trackCooldown") is True,
            "aura": parse_bool(line, "auraTracker") is True,
            "target": parse_bool(line, "targetDebuff") is True,
            "review": parse_bool(line, "review") is True,
            "trackHUD": parse_bool(line, "trackHUD"), "buff": parse_string(line, "buff"),
        })
    return class_name, resources, spells


def build_class(class_name: str, resources: list[dict], spells: list[dict]):
    root_id = f"{class_name} Class Pack"
    aura_id = f"Aura Bar - {class_name}"
    main_id = f"Main - {class_name}"
    resource_id = f"Resources - {class_name}"
    bars_id = f"Bars - {class_name}"
    dynamic_bars_id = f"Dynamic Bars - {class_name}"
    aux_id = f"Aux Bar - {class_name}"

    main = sorted((s for s in spells if s["row"] == "core" and s["cooldown"] and not s["review"]), key=lambda s: (s["order"], s["name"]))[:26]
    utility = sorted((s for s in spells if s["row"] == "utility" and s["cooldown"] and not s["review"]), key=lambda s: (s["order"], s["name"]))[:18]
    active = sorted((s for s in spells if s["aura"] and not s["review"] and not s["target"] and s["trackHUD"] is not False), key=lambda s: (s["order"], s["name"]))[:24]
    seen = {s["name"] for s in active}
    for record in sorted((s for s in spells if s["aura"] and not s["review"] and not s["target"] and s["category"] in {"proc", "buff", "defensive", "offensive"}), key=lambda s: (s["order"], s["name"])):
        if record["name"] not in seen and len(active) < 24:
            active.append(record)
            seen.add(record["name"])

    aura_children = [f"{s['name']} (Active) - {class_name}" for s in active]
    main_children = [f"{s['name']} - {class_name}" for s in main]
    aux_children = [f"{s['name']} - {class_name} Aux" for s in utility]
    root_children = [aura_id, main_id, resource_id] + ([aux_id] if aux_children else [])
    root = static_group(root_id, None, root_children)

    nodes = [
        dynamic_group(aura_id, root_id, aura_children, anchor="TOP", self_point="CENTER", y=47, grow="HORIZONTAL", spacing=4),
        dynamic_group(main_id, root_id, main_children, anchor="BOTTOM", self_point="CENTER", y=-17, grow="CUSTOM", spacing=2),
        static_group(resource_id, root_id, [bars_id]),
        static_group(bars_id, resource_id, [dynamic_bars_id]),
    ]

    resource_ids = [f"{class_name} - Primary Power"]
    dynamic_bars = dynamic_group(dynamic_bars_id, bars_id, resource_ids, anchor="BOTTOM", self_point="BOTTOM", y=0, grow="UP", spacing=1)
    nodes.append(dynamic_bars)
    nodes.append(power_bar(resource_ids[0], dynamic_bars_id))

    for resource in resources:
        if resource.get("type") != "stacks":
            continue
        name = resource.get("aura") or resource.get("name") or resource.get("key")
        if not name:
            continue
        child_id = f"{class_name} - {name}"
        resource_ids.append(child_id)
        nodes.append(stack_resource_bar(child_id, dynamic_bars_id, name, resource.get("id")))
    dynamic_bars["controlledChildren"] = resource_ids

    if aux_children:
        nodes.append(dynamic_group(aux_id, root_id, aux_children, anchor="BOTTOM", self_point="CENTER", y=-239, grow="HORIZONTAL", spacing=3))

    for child_id, record in zip(aura_children, active):
        nodes.append(icon(child_id, aura_id, record.get("buff") or record["name"], record.get("id"), 34, 26, active=True))
    for child_id, record in zip(main_children, main):
        nodes.append(icon(child_id, main_id, record["name"], record.get("id"), 36, 28))
    for child_id, record in zip(aux_children, utility):
        nodes.append(icon(child_id, aux_id, record["name"], record.get("id"), 36, 28))

    return export_wa({"s": WA_VERSION, "m": "d", "d": root, "c": nodes, "v": 2000})


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    parsed = []
    for path in sorted(CLASS_ROOT.glob("*/Data.lua")):
        entry = parse_class(path)
        if entry:
            parsed.append(entry)

    actual = sorted(name for name, _, _ in parsed)
    expected = sorted(CLASS_NAMES)
    if actual != expected:
        missing = sorted(set(expected) - set(actual))
        extra = sorted(set(actual) - set(expected))
        raise SystemExit(f"CoA class database mismatch. Missing={missing}; Extra={extra}")

    lines = [
        "local RUI = RetreatUI",
        "if not RUI then return end",
        "",
        "RUI.Beta20WeakAuras = {",
        f"  general = {lua_quote(build_general())},",
        "  classes = {",
    ]
    for class_name, resources, spells in parsed:
        lines.append(f"    [{lua_quote(class_name)}] = {lua_quote(build_class(class_name, resources, spells))},")
    lines.extend([
        "  },",
        '  generatedFor = "1.1.7-beta.20",',
        f'  weakAurasVersion = "{WA_VERSION}",',
        f"  classPayloadCount = {len(parsed)},",
        "}",
        "RUI._beta20StaticWeakAuraPayloadsLoaded = true",
        "",
    ])
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated General + {len(parsed)} CoA class payloads -> {OUTPUT}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate beta.20 CoA payloads with the exact Naowh TBC layout skeleton.

This remains a build-time tool. The shipped addon receives ordinary static
!WA:2! imports; RetreatUI does not create or reposition WeakAuras at runtime.
"""
from __future__ import annotations

import generate_beta20_weakauras as generator

CLASS_ANCHOR = "WeakAuras:Class Power Bar"

# Verbatim custom-grow geometry from the user-supplied NaowhUI TBC class packs.
# It is part of the imported WeakAura data, not RetreatUI runtime Lua.
NAOWH_MAIN_GROW = '''function(newPositions, activeRegions)
    --First row variables
    local firstRowLimit = 9 -- limit of icons in first row
    local wFR = 36 -- width of first row icons
    local hFR = 28 -- height of first row icons
    local fsFR = "LOW" -- frame strata of first row icons
    
    --Second row variables
    local secondRowLimit = 9 -- limit of icons in second row
    local wSR = 34 -- width of second row icons
    local hSR = 26 -- height of second row icons
    local fsSR = "BACKGROUND" -- frame strata of second row icons
    
    --last row variables
    local lastRowLimit = 8 -- limit of icons in last row
    local wLR = 34 -- width of last row icons
    local hLR = 26 -- height of last row icons
    local fsLR = "BACKGROUND" -- frame strata of last row icons
    
    local spacing = 3 -- spacing between icons
    local correctionYspacing = -1
    ----------------------
    
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
            
            if total <= firstRowLimit then
                rowTotal = total
            else
                rowTotal = firstRowLimit
            end
            
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
        
        
        xOffset = 0 - (region.width + spacing) / 2 * (rowTotal-1) + (xCount * (region.width + spacing))
        
        if currentRow == 1 then
            yOffset = 0 - hFR - spacing - correctionYspacing
        elseif currentRow == 2 then
            yOffset =  0 - (hFR + hSR) - spacing * 2 - correctionYspacing
        end
        
        xCount = xCount + 1
        
        if xCount >= rowTotal then
            xCount = 0
        end
        
        newPositions[i] = {xOffset, yOffset}
    end
end'''


def naowh_dynamic(aura_id: str, parent: str, children: list[str], *, anchor: str,
                  self_point: str, y: int, grow: str, spacing: int,
                  frame: str = CLASS_ANCHOR, align: str = "CENTER"):
    data = generator.dynamic_group(aura_id, parent, children, y, spacing, 26, 28)
    data["anchorFrameType"] = "SELECTFRAME" if frame else "SCREEN"
    if frame:
        data["anchorFrameFrame"] = frame
    else:
        data.pop("anchorFrameFrame", None)
    data["anchorPoint"] = anchor
    data["selfPoint"] = self_point
    data["xOffset"] = 0
    data["yOffset"] = y
    data["grow"] = grow
    data["align"] = align
    data["sort"] = "none"
    data["space"] = spacing
    data["useLimit"] = False
    data["limit"] = 26
    data["gridType"] = "RD"
    data["centerType"] = "LR"
    data.pop("height", None)
    if grow == "CUSTOM":
        data["customGrow"] = NAOWH_MAIN_GROW
    return data


def class_power_anchor():
    data = generator.base("Class Power Bar", "Anchors")
    data.update({
        "regionType": "aurabar", "width": 348, "height": 4,
        "anchorFrameType": "SCREEN", "anchorPoint": "CENTER", "selfPoint": "CENTER",
        "xOffset": 0, "yOffset": -189, "orientation": "HORIZONTAL", "inverse": False,
        "icon": False, "texture": generator.TEXTURE, "textureSource": "LSM",
        "barColor": [0, 0, 0, 0], "backgroundColor": [0, 0, 0, 0],
        "spark": False, "progressSource": [1, ""], "triggers": generator.dummy_trigger(),
        "subRegions": [{"type": "subbackground"}, generator.border()],
    })
    data["load"]["use_never"] = True
    return data


def build_general():
    root_id = "Core & Essentials"
    anchors_id = "Anchors"
    ui_id = "UI Elements"
    buffs_id = "Aura bar (Player buffs)"
    trinkets = ["Trinket 1", "Trinket 2"]

    root = generator.static_group(root_id, None, [anchors_id, ui_id])
    anchors = generator.static_group(anchors_id, root_id, ["Class Power Bar"])
    ui = generator.static_group(ui_id, root_id, [buffs_id])
    buffs = naowh_dynamic(
        buffs_id, ui_id, trinkets, anchor="TOPRIGHT", self_point="BOTTOMRIGHT",
        y=2, grow="GRID", spacing=3, frame="ElvUF_Player", align="RIGHT",
    )
    buffs["xOffset"] = -1
    buffs["gridType"] = "LU"
    buffs["gridWidth"] = 6
    buffs["rowSpace"] = 3
    buffs["columnSpace"] = 3

    t1 = generator.trinket_icon(13, buffs_id)
    t2 = generator.trinket_icon(14, buffs_id)
    transmission = {
        "s": "5.21.2", "m": "d", "d": root,
        "c": [anchors, class_power_anchor(), ui, buffs, t1, t2], "v": 2000,
    }
    return generator.export_wa(transmission)


def learned_icon(aura_id: str, parent: str, record: dict, width: int, height: int, *, active=False):
    name = record.get("buff") or record["name"] if active else record["name"]
    data = generator.icon(aura_id, parent, name, record.get("id"), width, height,
                          active=active, target=False if active else record.get("target", False))
    if not active and not record.get("id"):
        data["load"]["use_spellknown"] = True
        data["load"]["spellknown"] = record["name"]
    return data


def build_class(class_name: str, resources: list[dict], spells: list[dict]):
    root_id = f"{class_name} Class Pack"
    aura_id = f"Aura Bar - {class_name}"
    main_id = f"Main - {class_name}"
    resource_id = f"Resources - {class_name}"
    bars_id = f"Bars - {class_name}"
    dynamic_bars_id = f"Dynamic Bars - {class_name}"
    aux_id = f"Aux Bar - {class_name}"

    main = sorted(
        (s for s in spells if s["row"] == "core" and s["cooldown"] and not s["review"]),
        key=lambda s: (s["order"], s["name"]),
    )[:26]
    utility = sorted(
        (s for s in spells if s["row"] == "utility" and s["cooldown"] and not s["review"]),
        key=lambda s: (s["order"], s["name"]),
    )[:18]
    active = sorted(
        (s for s in spells if s["aura"] and not s["review"] and not s["target"] and s["trackHUD"] is not False),
        key=lambda s: (s["order"], s["name"]),
    )[:24]

    # Records previously hidden only because RetreatUI's native HUD rendered
    # them are legitimate static WA aura trackers in beta.20.
    seen = {s["name"] for s in active}
    for record in sorted(
        (s for s in spells if s["aura"] and not s["review"] and not s["target"] and s["category"] in {"proc", "buff", "defensive", "offensive"}),
        key=lambda s: (s["order"], s["name"]),
    ):
        if record["name"] not in seen and len(active) < 24:
            active.append(record)
            seen.add(record["name"])

    aura_children = [f"{s['name']} (Active) - {class_name}" for s in active]
    main_children = [f"{s['name']} - {class_name}" for s in main]
    aux_children = [f"{s['name']} - {class_name} Aux" for s in utility]

    root_children = [aura_id, main_id, resource_id]
    if aux_children:
        root_children.append(aux_id)
    root = generator.static_group(root_id, None, root_children)

    nodes = [
        naowh_dynamic(aura_id, root_id, aura_children, anchor="TOP", self_point="CENTER", y=47, grow="HORIZONTAL", spacing=4),
        naowh_dynamic(main_id, root_id, main_children, anchor="BOTTOM", self_point="CENTER", y=-17, grow="CUSTOM", spacing=2),
        generator.static_group(resource_id, root_id, [bars_id]),
        generator.static_group(bars_id, resource_id, [dynamic_bars_id]),
    ]

    resource_bar_ids = [f"{class_name} - Primary Power"]
    dynamic_bars = naowh_dynamic(
        dynamic_bars_id, bars_id, resource_bar_ids, anchor="BOTTOM", self_point="BOTTOM",
        y=0, grow="UP", spacing=1,
    )
    nodes.append(dynamic_bars)

    primary = generator.power_bar(resource_bar_ids[0], dynamic_bars_id)
    primary["parent"] = dynamic_bars_id
    primary["anchorFrameType"] = "SELECTFRAME"
    primary["anchorFrameFrame"] = CLASS_ANCHOR
    primary["anchorPoint"] = "CENTER"
    primary["selfPoint"] = "CENTER"
    primary["xOffset"] = 0
    primary["yOffset"] = 0
    nodes.append(primary)

    # Standard aura-trigger stack resources are placed in Naowh's Dynamic Bars
    # stack. Bespoke summon/counter resources are deliberately not recreated as
    # custom runtime WA code.
    for resource in resources:
        if resource.get("type") != "stacks":
            continue
        resource_name = resource.get("aura") or resource.get("name") or resource.get("key")
        if not resource_name:
            continue
        child_id = f"{class_name} - {resource_name}"
        resource_bar_ids.append(child_id)
        bar = generator.stack_resource_bar(child_id, dynamic_bars_id, resource_name, resource.get("id"), 0)
        bar["parent"] = dynamic_bars_id
        bar["anchorFrameType"] = "SELECTFRAME"
        bar["anchorFrameFrame"] = CLASS_ANCHOR
        bar["anchorPoint"] = "CENTER"
        bar["selfPoint"] = "CENTER"
        bar["xOffset"] = 0
        bar["yOffset"] = 0
        nodes.append(bar)
    dynamic_bars["controlledChildren"] = resource_bar_ids

    if aux_children:
        nodes.append(naowh_dynamic(
            aux_id, root_id, aux_children, anchor="BOTTOM", self_point="CENTER",
            y=-239, grow="HORIZONTAL", spacing=3,
        ))

    for child_id, record in zip(aura_children, active):
        nodes.append(learned_icon(child_id, aura_id, record, 34, 26, active=True))
    for child_id, record in zip(main_children, main):
        nodes.append(learned_icon(child_id, main_id, record, 36, 28))
    for child_id, record in zip(aux_children, utility):
        nodes.append(learned_icon(child_id, aux_id, record, 36, 28))

    return generator.export_wa({"s": "5.21.2", "m": "d", "d": root, "c": nodes, "v": 2000})


generator.build_general = build_general
generator.build_class = build_class

if __name__ == "__main__":
    generator.main()

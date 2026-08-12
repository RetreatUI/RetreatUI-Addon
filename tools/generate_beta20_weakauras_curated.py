#!/usr/bin/env python3
"""Run the beta.20 static WA generator with class-specific curated contracts."""
from __future__ import annotations

import generate_beta20_weakauras as generator

KNIGHT_CORE = {"unleash pestilence"}
KNIGHT_UTILITY = {"chainwhip", "snarl"}
KNIGHT_AURAS = {"suffuse", "hellrider", "black shield"}

_original_build_class = generator.build_class


def _normalized(value: object) -> str:
    return str(value or "").strip().lower()


def _curate_knight(spells: list[dict]) -> list[dict]:
    curated: list[dict] = []
    for record in spells:
        name = _normalized(record.get("name"))
        if name in KNIGHT_CORE:
            item = dict(record)
            item["row"] = "core"
            item["cooldown"] = True
            item["target"] = False
            curated.append(item)
        elif name in KNIGHT_UTILITY:
            item = dict(record)
            item["row"] = "utility"
            item["cooldown"] = True
            item["target"] = False
            curated.append(item)
        elif name in KNIGHT_AURAS:
            item = dict(record)
            item["row"] = None
            item["aura"] = True
            item["trackHUD"] = True
            item["target"] = False
            item["category"] = "buff"
            curated.append(item)
    return curated


def build_class(class_name: str, resources: list[dict], spells: list[dict]):
    if class_name == "Knight of Xoroth":
        spells = _curate_knight(spells)
        # Rage is represented by the standard primary power bar. The legacy
        # bespoke Demonfire/Imp/Demon's Blood counters are intentionally not
        # rebuilt as beta.20 WA runtime logic; only native stack resources that
        # have an exact ordinary aura trigger may be emitted by the base generator.
    return _original_build_class(class_name, resources, spells)


generator.build_class = build_class

if __name__ == "__main__":
    generator.main()

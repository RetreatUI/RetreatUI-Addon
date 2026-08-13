#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
core_toc = (ROOT / "RetreatUI/RetreatUI.toc").read_text(encoding="utf-8")
classes_toc = (ROOT / "RetreatUI_Classes/RetreatUI_Classes.toc").read_text(encoding="utf-8")
buff_toc = (ROOT / "RetreatUI_BuffManager/RetreatUI_BuffManager.toc").read_text(encoding="utf-8")
publish = (ROOT / ".github/workflows/publish-release.yml").read_text(encoding="utf-8")

expected_version = "1.1.7-beta.20"
for name, toc in (("core", core_toc), ("classes", classes_toc), ("buff", buff_toc)):
    assert f"## Version: {expected_version}" in toc, f"{name} version mismatch"

assert "## Title: RetreatUI Buff Manager" in buff_toc
assert "## Author: Retreat" in buff_toc
assert "## Dependencies: RetreatUI" in buff_toc
assert "## DefaultState: Disabled" in buff_toc
assert "BuffManager.lua" not in core_toc
assert "cp -a RetreatUI_BuffManager dist/buff/RetreatUI_BuffManager" in publish
assert '(cd dist/buff && zip -r "../$BUFF_ASSET" RetreatUI_BuffManager)' in publish

print("beta.20 Buff Manager validation passed: separate optional package and synchronized version")

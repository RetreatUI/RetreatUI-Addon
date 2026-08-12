#!/usr/bin/env python3
"""Assert that beta.20 ships the exact user-supplied Naowh layout payloads."""
from __future__ import annotations

import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXPECTED = {
    "details": (12460, "39e101eb07f739af90e2b4ccbd6fb10c011b5cbfae9b5557e86f09732daaf5c5"),
    "elvui_1440p": (7838, "fd646a3c74fc18967e505bced5827dd289f419047838697e5ef076c9c7617705"),
    "elvui_1080p": (7703, "3ad5f7b3c42263c177db3e833b17a94cf037334d9c3ed51a8568d9203f1618b8"),
}


def check(label: str, payload: str) -> None:
    expected_len, expected_sha = EXPECTED[label]
    actual_sha = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    assert len(payload) == expected_len, (label, len(payload), expected_len)
    assert actual_sha == expected_sha, (label, actual_sha, expected_sha)
    print(f"{label}: exact reference payload verified ({expected_len} bytes)")


def details_payload() -> str:
    text = (ROOT / "RetreatUI/Profiles/NaowhDetailsExport.lua").read_text(encoding="utf-8")
    chunks = []
    for key in ("p1", "p2", "p3", "p4"):
        match = re.search(rf"local {key} = \[=\[(.*?)\]=\]", text, re.S)
        assert match, key
        chunks.append(match.group(1))
    assert "RUI.DetailsProfileString = p1 .. p2 .. p3 .. p4" in text
    return "".join(chunks)


def elvui_payloads() -> tuple[str, str]:
    text = (ROOT / "RetreatUI/Profiles/NaowhElvUIExports.lua").read_text(encoding="utf-8")
    payloads = {}
    for resolution in ("1440p", "1080p"):
        match = re.search(rf'\["{resolution}"\]\s*=\s*\[=\[(.*?)\]=\]', text, re.S)
        assert match, resolution
        payloads[resolution] = match.group(1)
    return payloads["1440p"], payloads["1080p"]


def main() -> None:
    check("details", details_payload())
    elv_1440, elv_1080 = elvui_payloads()
    check("elvui_1440p", elv_1440)
    check("elvui_1080p", elv_1080)


if __name__ == "__main__":
    main()

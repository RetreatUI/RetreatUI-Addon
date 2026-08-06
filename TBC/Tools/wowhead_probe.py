from __future__ import annotations

import re
import requests

URLS = [
    "https://www.wowhead.com/tbc/spells/abilities/druid",
    "https://www.wowhead.com/tbc/spells/talents/druid",
    "https://www.wowhead.com/tbc/spells/racial-traits",
    "https://www.wowhead.com/tbc/items/armor/trinkets",
    "https://nether.wowhead.com/tbc/tooltip/spell/768",
    "https://nether.wowhead.com/tbc/tooltip/item/28830",
]

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept": "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8",
}

for url in URLS:
    print("=" * 100)
    print(url)
    response = requests.get(url, headers=HEADERS, timeout=45)
    print("status", response.status_code, "length", len(response.content), "type", response.headers.get("content-type"))
    text = response.text
    print("listview count", len(re.findall(r"new\\s+Listview\\s*\\(", text)))
    print("data markers", len(re.findall(r"\\bdata\\s*:\\s*\\[", text)))
    print("spell links", len(re.findall(r"/tbc/spell[=/]", text)))
    print("item links", len(re.findall(r"/tbc/item[=/]", text)))
    print(text[:2000].replace("\n", "\\n"))

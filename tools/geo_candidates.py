#!/usr/bin/env python3
"""Generate review-only coordinate candidates from OpenStreetMap.

This tool never edits content. It writes a JSON report for a human to review,
then reviewed rows can be copied into content/en/places.json separately.

Run from the project root:

    python tools/geo_candidates.py

Requests are limited to one per second and are cached for the duration of the
run. The search is restricted to a Vraja bounding box to avoid matching names
in other parts of India.
"""

import argparse
import json
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLACES = ROOT / "content/en/places.json"
DEFAULT_OUTPUT = ROOT / "tools/geo_candidates.json"

USER_AGENT = "VrajaMandala/0.1 (offline content curation)"
NOMINATIM = "https://nominatim.openstreetmap.org/search"
VIEWBOX = "77.1,27.2,78.1,28.0"
MIN_DELAY = 1.2

TRANS = {
    "ā": "a", "ē": "e", "ī": "i", "ō": "o", "ū": "u",
    "ṛ": "ri", "ṝ": "ri", "ḷ": "li", "ḹ": "li",
    "ṅ": "n", "ñ": "n", "ṭ": "t", "ḍ": "d", "ṇ": "n",
    "ś": "sh", "ṣ": "sh", "ḥ": "h", "ṃ": "m", "ṁ": "m",
    "ṟ": "r", "ṉ": "n", "ô": "o", "ê": "e",
}

SUFFIXES = [
    (r"\bkundas?\b", "kund"),
    (r"\bsarovaras?\b", "sarovar"),
    (r"\btirthas?\b", "tirth"),
    (r"\bghatas?\b", "ghat"),
    (r"\bmandiras?\b", "mandir"),
    (r"\bmathas?\b", "math"),
    (r"\bgramas?\b", "gram"),
    (r"\bvatas?\b", "vat"),
    (r"\bvanas?\b", "van"),
    (r"\bpuras?\b", "pur"),
    (r"\bnagaras?\b", "nagar"),
]

SPECIAL = {
    "vrindavana": "vrindavan",
    "vrndavana": "vrindavan",
    "govardhana": "govardhan",
    "kuruksetra": "kurukshetra",
    "barsana": "barsana",
    "varsana": "varsana",
    "radhakunda": "radha kund",
}

FOLD_MAP = {
    "ā": "a", "ē": "e", "ī": "i", "ō": "o", "ū": "u", "ṛ": "r", "ṝ": "r",
    "ḷ": "l", "ṅ": "n", "ñ": "n", "ṭ": "t", "ḍ": "d", "ṇ": "n", "ś": "s",
    "ṣ": "s", "ḥ": "h", "ṃ": "m", "ṁ": "m", "ṟ": "r", "ô": "o", "ê": "e",
}

CATEGORY_RULES = [
    ("Sacred waters", [
        "kunda", "kund", "sarovara", "sarovar", "sagara", "sagar", "tirtha",
        "tirth", "kupa", "kup", "daha", "pokhara", "jhil", "talab", "lake",
        "well", "sarasi",
    ]),
    ("Trees", [
        "vata", "vat", "kadamba", "banyan", "imli", "tamarind", "tamala",
        "peepal", "neem", "asoka",
    ]),
    ("Hills & caves", [
        "giri", "pahar", "pahadi", "hill", "saila", "parvata", "mountain",
        "cave", "gufa", "rock", "sikhara",
    ]),
    ("Ghāṭas", ["ghata", "ghat", "ghati", "riverbank", "yamuna", "tira"]),
    ("Temples & deities", [
        "mandir", "temple", "devi", "siva", "mahadeva", "isvara", "govinda",
        "radha", "krsna", "balarama", "hanuman", "ganesa", "asrama", "ashram",
        "matha", "samadhi", "bhavana", "bhawan", "kutira", "mandapa", "natha",
    ]),
    ("Towns & regions", [
        "mathura", "vrndavana", "vrindavana", "govardhana", "kuruksetra",
        "barsana", "varsana", "gokula", "vraja", "dhama", "dham", "ayodhya",
        "kasi", "prayaga",
    ]),
    ("Forests & groves", [
        "vana", "van", "kunj", "grove", "forest", "upavana", "adhivana",
        "prativana", "khandi",
    ]),
    ("Villages", [
        "grama", "gram", "pura", "pur", "nagara", "nagar", "gaon", "village",
        "town", "bazar", "colony",
    ]),
]

EXPECTED_TYPES = {
    "Temples & deities": {"place_of_worship", "temple", "monastery"},
    "Villages": {"village", "hamlet", "suburb", "neighbourhood"},
    "Towns & regions": {"town", "city", "village", "suburb"},
    "Hills & caves": {"peak", "hill", "cave_entrance"},
}

ALIAS_PATTERNS = [
    r"(?i)\b(?:also spelled|also called|known as)\s+([^\n.;]+)",
    r"(?i)\bSaved in Google Maps as\s+([^\n,.]+)",
]

REGIONS = {"vrindavan", "mathura", "govardhan", "barsana", "varsana", "gokul"}


def fold(text):
    text = "".join(FOLD_MAP.get(c.lower(), c.lower()) if c.isupper() or c in FOLD_MAP else c
                   for c in text)
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c)).lower()
    return " ".join(re.sub(r"[^a-z0-9]+", " ", text).split())


def translit(text):
    text = text.lower()
    for source, target in TRANS.items():
        text = text.replace(source, target)
        text = text.replace(source.upper(), target)
    text = "".join(c for c in unicodedata.normalize("NFKD", text)
                   if not unicodedata.combining(c))
    text = re.sub(r"[^a-z0-9]+", " ", text).strip()
    for pattern, replacement in SUFFIXES:
        text = re.sub(pattern, replacement, text)
    words = [SPECIAL.get(word, word) for word in text.split()]
    return " ".join(words)


def category_for(title):
    name = fold(title)
    tokens = set(name.split())
    for label, words in CATEGORY_RULES:
        if label == "Trees" and "parvata" in tokens:
            continue
        if any(word in tokens or name.endswith(word) for word in words):
            return label
    return "Other places"


def aliases_for(body):
    found = []
    for pattern in ALIAS_PATTERNS:
        for match in re.findall(pattern, body):
            alias = translit(match)
            if 2 <= len(alias.split()) <= 5 and alias not in found:
                found.append(alias)
    return found


def queries_for(place):
    queries = []
    primary = translit(place["title"])
    if primary:
        queries.append(primary)
    alias = next((a for a in aliases_for(place["body"]) if a != primary), None)
    if alias:
        queries.append(alias)
    if primary:
        queries.append(f"{primary}, Mathura, Uttar Pradesh, India")
    deduped = []
    for query in queries:
        if query not in deduped:
            deduped.append(query)
    return deduped[:2]


def name_part(display_name):
    return display_name.split(",")[0].strip()


def score_candidate(place, candidate, query, query_index):
    category = category_for(place["title"])
    candidate_name = fold(name_part(candidate.get("display_name", "")))
    query_key = fold(query)
    base_query = query_key.split(" mathura uttar prades")[0]

    score = 0
    if candidate_name == base_query:
        score += 6
    elif base_query and (base_query in candidate_name or candidate_name in base_query):
        score += 3

    if candidate.get("type") in EXPECTED_TYPES.get(category, set()):
        score += 2
    elif candidate.get("class") in EXPECTED_TYPES.get(category, set()):
        score += 2

    address = candidate.get("address", {})
    if any(value.lower() in REGIONS for value in address.values() if isinstance(value, str)):
        score += 1
    if any(region in fold(candidate.get("display_name", "")) for region in REGIONS):
        score += 1
    if query_index == 0:
        score += 1

    score = min(score, 10)
    if score >= 8:
        confidence = "high"
    elif score >= 5:
        confidence = "medium"
    else:
        confidence = "low"
    return score, confidence


class Nominatim:
    def __init__(self):
        self.cache = {}
        self.last_request = 0.0

    def search(self, query):
        if query in self.cache:
            return self.cache[query]
        params = {
            "format": "jsonv2",
            "q": query,
            "limit": "5",
            "addressdetails": "1",
            "bounded": "1",
            "viewbox": VIEWBOX,
            "accept-language": "en",
        }
        url = NOMINATIM + "?" + urllib.parse.urlencode(params)
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})

        for attempt in range(3):
            wait = MIN_DELAY - (time.monotonic() - self.last_request)
            if wait > 0:
                time.sleep(wait)
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    data = json.load(response)
                self.last_request = time.monotonic()
                self.cache[query] = data
                return data
            except urllib.error.HTTPError as error:
                self.last_request = time.monotonic()
                if error.code in {429, 503} and attempt < 2:
                    time.sleep(5 * (attempt + 1))
                    continue
                raise
        return []

    def candidates(self, place):
        results = []
        seen = set()
        for index, query in enumerate(queries_for(place)):
            found_high = False
            for item in self.search(query):
                key = (item.get("osm_type"), item.get("osm_id"))
                if key in seen:
                    continue
                seen.add(key)
                try:
                    lat = float(item["lat"])
                    lng = float(item["lon"])
                except (KeyError, TypeError, ValueError):
                    continue
                score, confidence = score_candidate(place, item, query, index)
                results.append({
                    "latitude": lat,
                    "longitude": lng,
                    "display_name": item.get("display_name", ""),
                    "osm_type": item.get("osm_type"),
                    "osm_id": item.get("osm_id"),
                    "category": item.get("category"),
                    "type": item.get("type"),
                    "query": query,
                    "score": score,
                    "confidence": confidence,
                })
                if index == 0 and confidence == "high":
                    found_high = True
            if found_high:
                break
        results.sort(key=lambda item: (-item["score"], item["display_name"]))
        return results[:5]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--categories",
        default="Temples & deities,Villages,Towns & regions,Hills & caves,Ghāṭas",
        help="comma-separated categories to include",
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    wanted = {c.strip() for c in args.categories.split(",") if c.strip()}

    places = json.loads(PLACES.read_text(encoding="utf-8"))
    targets = [
        p for p in places
        if p.get("latitude") is None
        and p.get("longitude") is None
        and category_for(p["title"]) in wanted
    ]

    client = Nominatim()
    entries = []
    for number, place in enumerate(targets, 1):
        print(f"[{number}/{len(targets)}] {place['id']} {place['title']}", flush=True)
        try:
            candidates = client.candidates(place)
        except Exception as error:  # keep going; the report records the failure
            print(f"  lookup failed: {error}", file=sys.stderr, flush=True)
            candidates = []
        entries.append({
            "id": place["id"],
            "title": place["title"],
            "category": category_for(place["title"]),
            "queries": queries_for(place),
            "candidates": candidates,
        })

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source": "OpenStreetMap Nominatim",
        "bbox_lon_lat": [77.1, 27.2, 78.1, 28.0],
        "categories": sorted(wanted),
        "review_status": "unreviewed",
        "note": "Candidates only. Do not apply without human review.",
        "entries": entries,
    }
    args.output.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    with_candidates = sum(1 for e in entries if e["candidates"])
    high = sum(1 for e in entries if any(c["confidence"] == "high" for c in e["candidates"]))
    print(f"Report: {args.output.relative_to(ROOT)}")
    print(f"Places checked: {len(entries)}")
    print(f"Places with candidates: {with_candidates}")
    print(f"Places with a high-confidence candidate: {high}")


if __name__ == "__main__":
    main()

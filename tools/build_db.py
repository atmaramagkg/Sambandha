#!/usr/bin/env python3
"""Build the app's SQLite database from the JSON files in content/<lang>/.

Run from the project root:

    python tools/build_db.py

Output:
    assets/db/vrajamandala.db  the database shipped inside the app
    assets/db/version.txt      content hash; the app re-copies the db when it changes

Content rules enforced here (the build fails if one is broken):
  * every record has a unique integer id, a unique slug and a unique title
  * every record has a non-empty body and a source_ref
  * status is "draft" or "reviewed"
  * user-facing text contains no attribution to the source book used for notes
  * every slug used in a link, relation or route stop exists
"""

import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
OUT_DIR = ROOT / "assets" / "db"
BASE_LANG = "en"
STATUSES = {"draft", "reviewed"}

# User-facing text must never name or point back to the source book used to
# prepare the notes. Keep descriptions in the app's own words instead.
FORBIDDEN_SOURCE = re.compile(
    r"(?i)\b(?:śivarāma|sivarama|nava[- ]vraja[- ]mahimā|nvm)\b"
    r"|\b(?:book|excerpts?|chapter|author)\b"
    r"|\bthe text\b"
)

SCHEMA = """
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);

CREATE TABLE person (
  id INTEGER NOT NULL, slug TEXT NOT NULL, lang TEXT NOT NULL,
  title TEXT NOT NULL, title_deva TEXT, summary TEXT NOT NULL,
  body TEXT NOT NULL, source_ref TEXT NOT NULL, status TEXT NOT NULL,
  PRIMARY KEY (id, lang)
);
CREATE TABLE place (
  id INTEGER NOT NULL, slug TEXT NOT NULL, lang TEXT NOT NULL,
  title TEXT NOT NULL, title_deva TEXT, summary TEXT NOT NULL,
  body TEXT NOT NULL, source_ref TEXT NOT NULL, status TEXT NOT NULL,
  latitude REAL, longitude REAL,
  PRIMARY KEY (id, lang)
);
CREATE TABLE story (
  id INTEGER NOT NULL, slug TEXT NOT NULL, lang TEXT NOT NULL,
  title TEXT NOT NULL, title_deva TEXT, summary TEXT NOT NULL,
  body TEXT NOT NULL, source_ref TEXT NOT NULL, status TEXT NOT NULL,
  PRIMARY KEY (id, lang)
);
CREATE TABLE route (
  id INTEGER NOT NULL, slug TEXT NOT NULL, lang TEXT NOT NULL,
  title TEXT NOT NULL, title_deva TEXT, summary TEXT NOT NULL,
  body TEXT NOT NULL, source_ref TEXT NOT NULL, status TEXT NOT NULL,
  PRIMARY KEY (id, lang)
);

CREATE TABLE story_person (
  story_id INTEGER NOT NULL, person_id INTEGER NOT NULL,
  PRIMARY KEY (story_id, person_id)
);
CREATE TABLE story_place (
  story_id INTEGER NOT NULL, place_id INTEGER NOT NULL,
  PRIMARY KEY (story_id, place_id)
);
CREATE TABLE route_story (
  route_id INTEGER NOT NULL, story_id INTEGER NOT NULL,
  PRIMARY KEY (route_id, story_id)
);
-- position is the walking order, starting at 1
CREATE TABLE route_stop (
  route_id INTEGER NOT NULL, position INTEGER NOT NULL,
  place_id INTEGER NOT NULL, note TEXT,
  PRIMARY KEY (route_id, position)
);
-- role describes the OTHER person, as seen from person_id
CREATE TABLE person_relation (
  person_id INTEGER NOT NULL, other_id INTEGER NOT NULL, lang TEXT NOT NULL,
  role TEXT NOT NULL,
  PRIMARY KEY (person_id, other_id, lang)
);

CREATE INDEX idx_person_lang ON person(lang);
CREATE INDEX idx_place_lang ON place(lang);
CREATE INDEX idx_story_lang ON story(lang);
CREATE INDEX idx_route_lang ON route(lang);
"""

KINDS = {
    "person": "people.json",
    "place": "places.json",
    "story": "stories.json",
    "route": "routes.json",
}


def fail(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def load(lang, kind):
    path = CONTENT / lang / KINDS[kind]
    if not path.exists():
        return []
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def check_record(lang, kind, rec):
    where = f"{lang}/{kind} id={rec.get('id')} slug={rec.get('slug')}"
    for field in ("id", "slug", "title", "summary", "body", "source_ref", "status"):
        if field not in rec or rec[field] in ("", None):
            fail(f"{where}: missing '{field}'")
    if not isinstance(rec["id"], int):
        fail(f"{where}: id must be an integer")
    if rec["status"] not in STATUSES:
        fail(f"{where}: status must be one of {sorted(STATUSES)}")
    for field in ("summary", "body", "source_ref"):
        if FORBIDDEN_SOURCE.search(str(rec[field])):
            fail(f"{where}: contains a source-attribution phrase in '{field}'")


def main():
    langs = sorted(p.name for p in CONTENT.iterdir() if p.is_dir())
    if BASE_LANG not in langs:
        fail(f"content/{BASE_LANG}/ is required")

    data = {lang: {k: load(lang, k) for k in KINDS} for lang in langs}

    # slug -> id maps come from the base language
    ids = {}
    for kind in KINDS:
        seen_ids, seen_slugs, seen_titles = set(), {}, set()
        for rec in data[BASE_LANG][kind]:
            check_record(BASE_LANG, kind, rec)
            if rec["id"] in seen_ids:
                fail(f"{BASE_LANG}/{kind}: duplicate id {rec['id']}")
            if rec["slug"] in seen_slugs:
                fail(f"{BASE_LANG}/{kind}: duplicate slug {rec['slug']}")
            if rec["title"] in seen_titles:
                fail(f"{BASE_LANG}/{kind}: duplicate title {rec['title']!r}")
            seen_ids.add(rec["id"])
            seen_slugs[rec["slug"]] = rec["id"]
            seen_titles.add(rec["title"])
        ids[kind] = seen_slugs

    # other languages must reuse the base slugs
    for lang in langs:
        if lang == BASE_LANG:
            continue
        for kind in KINDS:
            for rec in data[lang][kind]:
                check_record(lang, kind, rec)
                if rec["slug"] not in ids[kind]:
                    fail(f"{lang}/{kind}: slug '{rec['slug']}' not in {BASE_LANG}")
                rec["id"] = ids[kind][rec["slug"]]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    db_path = OUT_DIR / "vrajamandala.db"
    if db_path.exists():
        db_path.unlink()

    con = sqlite3.connect(db_path)
    con.executescript(SCHEMA)

    for lang in langs:
        for kind in KINDS:
            for rec in data[lang][kind]:
                if kind == "place":
                    lat, lng = rec.get("latitude"), rec.get("longitude")
                    if (lat is None) != (lng is None):
                        fail(f"{lang}/{kind} '{rec['slug']}': latitude and longitude must be set together")
                    if lat is not None and not isinstance(lat, (int, float)):
                        fail(f"{lang}/{kind} '{rec['slug']}': latitude must be a number")
                    if lng is not None and not isinstance(lng, (int, float)):
                        fail(f"{lang}/{kind} '{rec['slug']}': longitude must be a number")
                    con.execute(
                        "INSERT INTO place (id, slug, lang, title, title_deva, summary, "
                        "body, source_ref, status, latitude, longitude) "
                        "VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                        (rec["id"], rec["slug"], lang, rec["title"], rec.get("title_deva"),
                         rec["summary"], rec["body"], rec["source_ref"], rec["status"],
                         lat, lng),
                    )
                else:
                    con.execute(
                        f"INSERT INTO {kind} (id, slug, lang, title, title_deva, summary, "
                        "body, source_ref, status) VALUES (?,?,?,?,?,?,?,?,?)",
                        (rec["id"], rec["slug"], lang, rec["title"], rec.get("title_deva"),
                         rec["summary"], rec["body"], rec["source_ref"], rec["status"]),
                    )

    # links are language independent: taken from the base language only
    for story in data[BASE_LANG]["story"]:
        for slug in story.get("people", []):
            if slug not in ids["person"]:
                fail(f"story '{story['slug']}': unknown person '{slug}'")
            con.execute("INSERT INTO story_person VALUES (?,?)",
                        (story["id"], ids["person"][slug]))
        for slug in story.get("places", []):
            if slug not in ids["place"]:
                fail(f"story '{story['slug']}': unknown place '{slug}'")
            con.execute("INSERT INTO story_place VALUES (?,?)",
                        (story["id"], ids["place"][slug]))

    for route in data[BASE_LANG]["route"]:
        stories = route.get("stories", [])
        if not isinstance(stories, list):
            fail(f"route '{route['slug']}': stories must be a list")
        for slug in stories:
            if slug not in ids["story"]:
                fail(f"route '{route['slug']}': unknown story '{slug}'")
            con.execute("INSERT INTO route_story VALUES (?,?)",
                        (route["id"], ids["story"][slug]))

        stops = route.get("stops", [])
        if not isinstance(stops, list) or not stops:
            fail(f"route '{route['slug']}': at least one stop is required")
        seen_places = set()
        for position, stop in enumerate(stops, start=1):
            if isinstance(stop, str):
                place_slug, note = stop, None
            elif isinstance(stop, dict) and isinstance(stop.get("place"), str):
                place_slug, note = stop["place"], stop.get("note")
            else:
                fail(f"route '{route['slug']}': stop {position} needs a place slug")
            if note is not None and not isinstance(note, str):
                fail(f"route '{route['slug']}': stop {position} note must be text")
            if note and FORBIDDEN_SOURCE.search(note):
                fail(f"route '{route['slug']}': stop {position} note contains a source-attribution phrase")
            if place_slug not in ids["place"]:
                fail(f"route '{route['slug']}': unknown place '{place_slug}'")
            if place_slug in seen_places:
                fail(f"route '{route['slug']}': duplicate stop '{place_slug}'")
            seen_places.add(place_slug)
            con.execute("INSERT INTO route_stop VALUES (?,?,?,?)",
                        (route["id"], position, ids["place"][place_slug], note))

    # person relations: role text is per language
    for lang in langs:
        for person in data[lang]["person"]:
            for rel in person.get("relations", []):
                if rel["person"] not in ids["person"]:
                    fail(f"{lang}/person '{person['slug']}': unknown relation '{rel['person']}'")
                con.execute("INSERT INTO person_relation VALUES (?,?,?,?)",
                            (person["id"], ids["person"][rel["person"]], lang, rel["role"]))

    digest = hashlib.sha256()
    for path in sorted(CONTENT.rglob("*.json")):
        digest.update(path.relative_to(CONTENT).as_posix().encode())
        digest.update(path.read_bytes())
    version = digest.hexdigest()[:16]
    con.execute("INSERT INTO meta VALUES ('content_version', ?)", (version,))

    con.commit()
    check = con.execute("PRAGMA integrity_check").fetchone()[0]
    con.execute("VACUUM")
    con.close()
    if check != "ok":
        fail(f"integrity_check: {check}")

    (OUT_DIR / "version.txt").write_text(version + "\n", encoding="utf-8")

    summary = ", ".join(f"{len(data[BASE_LANG][k])} {k}" for k in KINDS)
    print(f"Built {db_path.relative_to(ROOT)} ({summary}); languages: {', '.join(langs)}")
    print(f"Content version: {version}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Sync app place data into the Excel workbook.

The app is the source of truth. This tool updates title, coordinates,
coordinate confidence, coordinate provenance, description and app ID for every
matching place row. Existing spreadsheet-only columns (mentions, pastime flag,
Google match and Google address) are preserved.

Six spreadsheet spellings are kept as variant rows rather than separate app
places. They are linked to their app ID and receive the same reviewed wording,
but their existing coordinates are left alone.

Run from the project root:

    python tools/sync_app_to_xlsx.py            # dry run
    python tools/sync_app_to_xlsx.py --apply    # write the workbook
"""

import json
import re
import shutil
import sys
import unicodedata
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
PLACES = ROOT / "content/en/places.json"
XLSX = Path(r"C:\Users\austr\OneDrive\Documents\holy_places.xlsx")
BACKUP = Path(r"C:\Users\austr\AppData\Local\Temp\opencode\holy_places-before-app-sync.xlsx")
SHEET = "xl/worksheets/sheet1.xml"
TABLE = "xl/tables/table1.xml"
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}

# Spreadsheet spelling variant -> app place ID. Coordinates are not replaced
# for these rows because the variant is not an exact app title.
VARIANTS = {
    215: 52,   # Khelanavana -> Khelanvana
    290: 39,   # Manaḥ-sarovara -> Mana-sarovara
    326: 20,   # Nandagrāma -> Nanda-grāma
    469: 110,  # Sūrya-kuṇḍa -> Suryakunda
    490: 40,   # Vaṁśīvaṭa -> Vamsivat
    509: 267,  # Viśrāma-ghāṭa -> Vishram Ghat
}


def norm(text):
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c)).lower()
    return " ".join(re.sub(r"[^a-z0-9]+", " ", text).split())


def col_of(ref):
    return re.match(r"[A-Z]+", ref).group(0)


def col_num(letters):
    number = 0
    for char in letters:
        number = number * 26 + ord(char) - 64
    return number


def style_of(raw):
    match = re.search(r'\bs="(\d+)"', raw)
    return match.group(1) if match else None


def inline(ref, text, style=None):
    attrs = f' s="{style}"' if style else ""
    value = escape(str(text))
    return f'<c r="{ref}"{attrs} t="inlineStr"><is><t xml:space="preserve">{value}</t></is></c>'


def number(ref, value, style=None):
    attrs = f' s="{style}"' if style else ""
    return f'<c r="{ref}"{attrs} t="n"><v>{format(float(value), ".10g")}</v></c>'


def shared_strings(archive):
    if "xl/sharedStrings.xml" not in archive.namelist():
        return []
    root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    return [
        "".join(t.text or "" for t in item.iterfind(".//m:t", NS))
        for item in root.findall("m:si", NS)
    ]


def cell_text(cell, strings):
    value = cell.find("m:v", NS)
    if cell.attrib.get("t") == "inlineStr":
        return "".join(t.text or "" for t in cell.iterfind(".//m:t", NS))
    if cell.attrib.get("t") == "s" and value is not None:
        return strings[int(value.text)]
    return value.text if value is not None else ""


def row_cells(row_xml):
    raw = {}
    for match in re.finditer(r'<c r="([A-Z]+\d+)"[^>]*(?:/>|>.*?</c>)', row_xml):
        raw[col_of(match.group(1))] = match.group(0)
    wrapped = (
        '<root xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        + row_xml
        + "</root>"
    )
    parsed = ET.fromstring(wrapped)
    cells = {
        col_of(cell.attrib["r"]): cell
        for cell in parsed.findall("m:row/m:c", NS)
    }
    return raw, cells


def clean_description(body):
    return body.replace("\r\n", "\n").replace("\n\n", "\n")


def main():
    apply = "--apply" in sys.argv
    places = json.loads(PLACES.read_text(encoding="utf-8"))
    by_key = {norm(place["title"]): place for place in places}
    by_id = {place["id"]: place for place in places}
    if len(by_key) != len(places):
        raise SystemExit("App titles are not unique after normalization")

    with zipfile.ZipFile(XLSX) as archive:
        entries = [(info, archive.read(info.filename)) for info in archive.infolist()]
        sheet = archive.read(SHEET).decode("utf-8")
        table = archive.read(TABLE).decode("utf-8")
        strings = shared_strings(archive)

    root = ET.fromstring(sheet)
    rows = root.findall("m:sheetData/m:row", NS)
    last_row = int(rows[-1].attrib["r"])
    stats = {"matched": 0, "variants": 0, "coords": 0, "descriptions": 0}

    def replace_row(match):
        row_xml = match.group(0)
        row_num = int(re.search(r'<row r="(\d+)"', row_xml).group(1))
        raw, cells = row_cells(row_xml)

        if row_num == 1:
            for column, label in (("K", "Coordinate source"), ("L", "App ID")):
                if column not in raw:
                    raw[column] = inline(f"{column}1", label, style_of(raw.get("J", "")))
            ordered = sorted(raw.items(), key=lambda item: col_num(item[0]))
            return '<row r="1">' + "".join(xml for _, xml in ordered) + "</row>"

        title = cell_text(cells.get("B"), strings) if "B" in cells else ""
        exact = by_key.get(norm(title))
        place = exact or by_id.get(VARIANTS.get(row_num))
        if place is None:
            return row_xml

        if exact:
            stats["matched"] += 1
            raw["B"] = inline(f"B{row_num}", place["title"], style_of(raw.get("B", "")))
            latitude, longitude = place.get("latitude"), place.get("longitude")
            if latitude is not None and longitude is not None:
                raw["E"] = number(f"E{row_num}", latitude, style_of(raw.get("E", "")))
                raw["F"] = number(f"F{row_num}", longitude, style_of(raw.get("F", "")))
                confidence = place.get("coordinate_confidence") or "from app"
                raw["G"] = inline(f"G{row_num}", confidence, style_of(raw.get("G", "")))
                stats["coords"] += 1
                source = place.get("coordinate_source", "")
                if source:
                    raw["K"] = inline(f"K{row_num}", source)
                else:
                    raw.pop("K", None)
            else:
                raw.pop("E", None)
                raw.pop("F", None)
                raw["G"] = inline(f"G{row_num}", "none", style_of(raw.get("G", "")))
                raw.pop("K", None)
        else:
            stats["variants"] += 1
            raw["K"] = inline(f"K{row_num}", "Spreadsheet spelling variant mapped to app place")

        old_description = cell_text(cells.get("J"), strings) if "J" in cells else ""
        description = clean_description(place["body"])
        if old_description != description:
            stats["descriptions"] += 1
        raw["J"] = inline(f"J{row_num}", description, style_of(raw.get("J", "")) or "2")
        raw["L"] = inline(f"L{row_num}", place["id"])

        ordered = sorted(raw.items(), key=lambda item: col_num(item[0]))
        return f'<row r="{row_num}">' + "".join(xml for _, xml in ordered) + "</row>"

    new_sheet = re.sub(r'<row r="\d+"[^>]*>.*?</row>', replace_row, sheet, flags=re.S)
    new_sheet = new_sheet.replace(
        f'<dimension ref="A1:J{last_row}"/>',
        f'<dimension ref="A1:L{last_row}"/>',
        1,
    )

    new_table = table
    new_table = new_table.replace(f'ref="A1:J{last_row}"', f'ref="A1:L{last_row}"')
    new_table = new_table.replace(
        f'<autoFilter ref="A1:J{last_row}"/>',
        f'<autoFilter ref="A1:L{last_row}"/>',
    )
    if '<tableColumns count="10">' in new_table:
        new_table = new_table.replace('<tableColumns count="10">', '<tableColumns count="12">')
        new_table = new_table.replace(
            "</tableColumns>",
            '<tableColumn id="11" name="Coordinate source"/>'
            '<tableColumn id="12" name="App ID"/></tableColumns>',
            1,
        )

    print("exact app rows:", stats["matched"])
    print("spelling variants linked:", stats["variants"])
    print("rows with app coordinates:", stats["coords"])
    print("descriptions changed:", stats["descriptions"])
    if not apply:
        print("dry run; pass --apply to write")
        return

    if not BACKUP.exists():
        shutil.copy2(XLSX, BACKUP)
        print("backup:", BACKUP)

    updates = {SHEET: new_sheet.encode("utf-8"), TABLE: new_table.encode("utf-8")}
    temporary = XLSX.with_suffix(".tmp.xlsx")
    with zipfile.ZipFile(temporary, "w") as output:
        for info, data in entries:
            output.writestr(info, updates.get(info.filename, data))
    temporary.replace(XLSX)
    print("updated:", XLSX)


if __name__ == "__main__":
    main()

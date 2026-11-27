#!/usr/bin/env python3
"""Sync app place data into the Excel workbook.

The app is the source of truth. This tool updates title, coordinates,
coordinate confidence, description and app ID for every matching place row.
The old Google match/address and coordinate-source columns are replaced by a
single Google Maps link column: a clickable link is written only when a place
has both coordinates.

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
SHEET2 = "xl/worksheets/sheet2.xml"
RELS = "xl/worksheets/_rels/sheet1.xml.rels"
TABLE = "xl/tables/table1.xml"
SHARED = "xl/sharedStrings.xml"
STYLES = "xl/styles.xml"
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
OFFICE_REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

NOTES = [
    "Place names are working matches from the app, merged across spelling variants; not a verified index.",
    "Mentions: occurrences recorded in the app data.",
    "Latitude/longitude: coordinates recorded in the app, with a confidence value where available.",
    "Google Maps link: opens the coordinate in Google Maps; blank when no coordinate is available.",
    "Descriptions are editorial summaries; consult the precise shastra reference for verification.",
    "This workbook is regenerated from the app; app content is the source of truth.",
]

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


def coordinate_text(value):
    return format(float(value), ".10g")


def maps_link(latitude, longitude):
    if latitude is None or longitude is None or str(latitude).strip() == "" or str(longitude).strip() == "":
        return ""
    return (
        "https://www.google.com/maps/search/?api=1&query="
        f"{coordinate_text(latitude)},{coordinate_text(longitude)}"
    )


def shared_strings(archive):
    if SHARED not in archive.namelist():
        return []
    root = ET.fromstring(archive.read(SHARED))
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


def strip_prefixed_attrs(xml):
    """Drop Excel revision attributes whose namespace is declared only on root."""
    return re.sub(r'\s+[\w-]+:[\w-]+="[^"]*"', "", xml)


def row_cells(row_xml):
    raw = {}
    for match in re.finditer(r'<c r="([A-Z]+\d+)"[^>]*(?:/>|>.*?</c>)', row_xml):
        raw[col_of(match.group(1))] = match.group(0)
    wrapped = (
        '<root xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        + strip_prefixed_attrs(row_xml)
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


def compact_shared_strings(shared_xml, sheet_xmls):
    """Remove unused strings so no legacy addresses survive inside the workbook."""
    used = sorted(
        {
            int(index)
            for sheet_xml in sheet_xmls
            for index in re.findall(r'<c\b[^>]*\bt="s"[^>]*><v>(\d+)</v></c>', sheet_xml)
        }
    )
    remap = {old: new for new, old in enumerate(used)}

    def rewrite_cell(match):
        return (
            f"{match.group(1)}<v>{remap[int(match.group(2))]}</v>{match.group(3)}"
        )

    rewritten = [
        re.sub(r'(<c\b[^>]*\bt="s"[^>]*>)<v>(\d+)</v>(</c>)', rewrite_cell, sheet_xml)
        for sheet_xml in sheet_xmls
    ]
    items = re.findall(r"<si>.*?</si>", shared_xml, flags=re.S)
    new_shared = re.sub(
        r"<sst\b([^>]*)>",
        lambda match: "<sst"
        + re.sub(r'\s+(?:count|uniqueCount)="\d+"', "", match.group(1))
        + f' count="{len(used)}" uniqueCount="{len(used)}">',
        shared_xml,
        count=1,
    )
    new_shared = re.sub(r"<si>.*?</si>", "", new_shared, flags=re.S)
    new_shared = new_shared.replace(
        "</sst>", "".join(items[index] for index in used) + "</sst>", 1
    )
    return rewritten, new_shared


def clean_notes_sheet(sheet_xml):
    """Replace legacy provenance notes with clean, app-derived notes."""
    rows = "".join(
        f'<row r="{index}"><c r="A{index}" t="inlineStr">'
        f'<is><t xml:space="preserve">{escape(note)}</t></is></c></row>'
        for index, note in enumerate(NOTES, start=1)
    )
    return re.sub(
        r"<sheetData\b[^>]*>.*?</sheetData>",
        f'<sheetData>{rows}</sheetData>',
        sheet_xml,
        count=1,
        flags=re.S,
    )


def add_hyperlink_style(styles_xml):
    """Add a blue underlined cell style for clickable map links."""
    font = (
        '<font><u/><sz val="11"/><color rgb="FF0563C1"/>'
        '<name val="Calibri"/><family val="2"/><scheme val="minor"/></font>'
    )
    fonts = re.search(r"(<fonts\b[^>]*>)(.*?)(</fonts>)", styles_xml, flags=re.S)
    xfs = re.search(r"(<cellXfs\b[^>]*>)(.*?)(</cellXfs>)", styles_xml, flags=re.S)
    if fonts is None or xfs is None:
        raise SystemExit("Workbook styles are missing fonts or cellXfs")

    font_items = re.findall(r"<font>.*?</font>", fonts.group(2), flags=re.S)
    if font not in font_items:
        font_items.append(font)
    font_id = font_items.index(font)
    fonts_open = re.sub(
        r'\bcount="\d+"', f'count="{len(font_items)}"', fonts.group(1), count=1
    )
    styles_xml = (
        styles_xml[: fonts.start()]
        + fonts_open
        + "".join(font_items)
        + fonts.group(3)
        + styles_xml[fonts.end() :]
    )

    xfs = re.search(r"(<cellXfs\b[^>]*>)(.*?)(</cellXfs>)", styles_xml, flags=re.S)
    xf_items = re.findall(
        r'<xf\b[^>]*?/>|<xf\b[^>]*>.*?</xf>', xfs.group(2), flags=re.S
    )
    xf = (
        f'<xf numFmtId="0" fontId="{font_id}" fillId="0" borderId="0" xfId="0"'
        ' applyFont="1" applyAlignment="1">'
        '<alignment horizontal="center" vertical="center"/></xf>'
    )
    if xf not in xf_items:
        xf_items.append(xf)
    style_index = xf_items.index(xf)
    xfs_open = re.sub(
        r'\bcount="\d+"', f'count="{len(xf_items)}"', xfs.group(1), count=1
    )
    styles_xml = (
        styles_xml[: xfs.start()]
        + xfs_open
        + "".join(xf_items)
        + xfs.group(3)
        + styles_xml[xfs.end() :]
    )
    return styles_xml, str(style_index)


def add_hyperlinks(sheet_xml, rels_xml, links):
    """Write external hyperlink relationships for the Google Maps cells."""
    if not links:
        return sheet_xml, rels_xml.encode("utf-8")

    rels = re.sub(
        r'<Relationship\b[^>]*Type="[^"]*/hyperlink"[^>]*/>', "", rels_xml
    )
    used_ids = [int(value) for value in re.findall(r'Id="rId(\d+)"', rels)]
    next_id = max(used_ids, default=0) + 1
    hyperlink_items = []
    relationship_items = []
    for ref in sorted(links, key=lambda value: int(re.search(r"\d+", value).group())):
        rid = f"rId{next_id}"
        next_id += 1
        hyperlink_items.append(f'<hyperlink ref="{ref}" r:id="{rid}"/>')
        target = escape(links[ref], {'"': "&quot;"})
        relationship_items.append(
            f'<Relationship Id="{rid}" Type="{OFFICE_REL_NS}/hyperlink"'
            f' Target="{target}" TargetMode="External"/>'
        )

    sheet_xml = re.sub(r"<hyperlinks\b.*?</hyperlinks>", "", sheet_xml, flags=re.S)
    if "xmlns:r=" not in sheet_xml[:1200]:
        sheet_xml = re.sub(
            r"<worksheet\b",
            f'<worksheet xmlns:r="{OFFICE_REL_NS}"',
            sheet_xml,
            count=1,
        )
    block = "<hyperlinks>" + "".join(hyperlink_items) + "</hyperlinks>"
    insertion = re.search(
        r"<(?:pageMargins|pageSetup|printOptions|headerFooter|drawing|tableParts|extLst)\b",
        sheet_xml,
    )
    if insertion:
        sheet_xml = sheet_xml[: insertion.start()] + block + sheet_xml[insertion.start() :]
    else:
        sheet_xml = sheet_xml.replace("</worksheet>", block + "</worksheet>", 1)

    rels = rels.replace(
        "</Relationships>", "".join(relationship_items) + "</Relationships>", 1
    )
    return sheet_xml, rels.encode("utf-8")


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
        sheet2 = archive.read(SHEET2).decode("utf-8")
        rels = (
            archive.read(RELS).decode("utf-8")
            if RELS in archive.namelist()
            else f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            f'<Relationships xmlns="{REL_NS}"/>'
        )
        table = archive.read(TABLE).decode("utf-8")
        shared_xml = archive.read(SHARED).decode("utf-8")
        styles = archive.read(STYLES).decode("utf-8")
        strings = shared_strings(archive)

    styles, link_style = add_hyperlink_style(styles)
    root = ET.fromstring(sheet)
    rows = root.findall("m:sheetData/m:row", NS)
    last_row = int(rows[-1].attrib["r"])
    stats = {
        "matched": 0,
        "variants": 0,
        "coords": 0,
        "links": 0,
        "hyperlinks": 0,
        "descriptions": 0,
    }
    hyperlinks = {}

    def replace_row(match):
        row_xml = match.group(0)
        row_num = int(re.search(r'<row r="(\d+)"', row_xml).group(1))
        raw, cells = row_cells(row_xml)

        if row_num == 1:
            headings = {
                "H": ("Google Maps link", raw.get("H", "")),
                "I": ("Description", raw.get("J", "")),
                "J": ("Notes", raw.get("K", "")),
                "K": ("App ID", raw.get("L", "")),
            }
            for column, (label, old_cell) in headings.items():
                raw[column] = inline(f"{column}1", label, style_of(old_cell))
            raw.pop("L", None)
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
            else:
                raw.pop("E", None)
                raw.pop("F", None)
                raw["G"] = inline(f"G{row_num}", "none", style_of(raw.get("G", "")))
        else:
            stats["variants"] += 1
            latitude = cell_text(cells.get("E"), strings) if "E" in cells else ""
            longitude = cell_text(cells.get("F"), strings) if "F" in cells else ""

        link = maps_link(latitude, longitude)
        link_cell_style = style_of(raw.get("H", ""))
        if link:
            stats["links"] += 1
            stats["hyperlinks"] += 1
            hyperlinks[f"H{row_num}"] = link
            link_cell_style = link_style
        raw["H"] = inline(f"H{row_num}", link, link_cell_style)

        description = clean_description(place["body"])
        old_description = cell_text(cells.get("I"), strings) if "I" in cells else ""
        if old_description != description:
            old_description = cell_text(cells.get("J"), strings) if "J" in cells else ""
        if old_description != description:
            stats["descriptions"] += 1
        raw["I"] = inline(f"I{row_num}", description, style_of(raw.get("J", "")) or "2")
        raw["J"] = inline(f"J{row_num}", "", style_of(raw.get("K", "")))
        raw["K"] = inline(f"K{row_num}", place["id"], style_of(raw.get("L", "")))
        raw.pop("L", None)

        ordered = sorted(raw.items(), key=lambda item: col_num(item[0]))
        return f'<row r="{row_num}">' + "".join(xml for _, xml in ordered) + "</row>"

    new_sheet = re.sub(r'<row r="\d+"[^>]*>.*?</row>', replace_row, sheet, flags=re.S)
    new_sheet = re.sub(
        r'<dimension ref="A1:[A-Z]+\d+"/>',
        f'<dimension ref="A1:K{last_row}"/>',
        new_sheet,
        count=1,
    )
    new_sheet, new_rels = add_hyperlinks(new_sheet, rels, hyperlinks)
    new_sheet2 = clean_notes_sheet(sheet2)
    rewritten, new_shared = compact_shared_strings(
        shared_xml, [new_sheet, new_sheet2]
    )
    new_sheet, new_sheet2 = rewritten

    new_table = table
    new_table = re.sub(r'ref="A1:[A-Z]+\d+"', f'ref="A1:K{last_row}"', new_table)
    names = [
        "#",
        "Place",
        "Mentions",
        "Pastime/description",
        "Latitude",
        "Longitude",
        "Coordinate confidence",
        "Google Maps link",
        "Description",
        "Notes",
        "App ID",
    ]
    columns = "".join(
        f'<tableColumn id="{index}" name="{escape(name)}"/>'
        for index, name in enumerate(names, start=1)
    )
    new_table = re.sub(
        r"<tableColumns\b[^>]*>.*?</tableColumns>",
        f'<tableColumns count="{len(names)}">{columns}</tableColumns>',
        new_table,
        count=1,
        flags=re.S,
    )

    print("exact app rows:", stats["matched"])
    print("spelling variants linked:", stats["variants"])
    print("rows with app coordinates:", stats["coords"])
    print("rows with Google Maps links:", stats["links"])
    print("clickable Google Maps hyperlinks:", stats["hyperlinks"])
    print("descriptions changed:", stats["descriptions"])
    if not apply:
        print("dry run; pass --apply to write")
        return

    if not BACKUP.exists():
        shutil.copy2(XLSX, BACKUP)
        print("backup:", BACKUP)

    updates = {
        SHEET: new_sheet.encode("utf-8"),
        SHEET2: new_sheet2.encode("utf-8"),
        RELS: new_rels,
        TABLE: new_table.encode("utf-8"),
        SHARED: new_shared.encode("utf-8"),
        STYLES: styles.encode("utf-8"),
    }
    temporary = XLSX.with_suffix(".tmp.xlsx")
    with zipfile.ZipFile(temporary, "w") as output:
        for info, data in entries:
            output.writestr(info, updates.get(info.filename, data))
    temporary.replace(XLSX)
    print("updated:", XLSX)


if __name__ == "__main__":
    main()

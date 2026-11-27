# Vraja Mandala

An offline-first Flutter app for browsing the stories of holy personalities and
places of Vraja. Every page links to related pages (people ↔ stories ↔ places),
so you can wander from one to the next.

## First-time setup

This folder contains the app code, content, database, and Windows and Android
platform files.

1. Put the contents of this folder in your project folder.
2. `flutter pub get`
3. `flutter run`

The Android application ID is `com.vrajamandala.vraja_mandala`. Release APKs
currently use Flutter's generated debug signing key; configure your own
keystore before publishing to Google Play.

## Adding or editing content

Content lives in `content/en/` as three JSON files: `people.json`,
`places.json`, `stories.json`.

- Each record needs a unique integer `id`, a unique `slug`, `title`, `summary`,
  `body` (paragraphs separated by a blank line), `source_ref` and `status`.
- Never reuse or renumber an `id`: saved items on users' phones refer to it.
- `status` is `draft` until a knowledgeable reader has checked the entry; then
  change it to `reviewed` and the draft notice disappears from that page.
- A story lists the `people` and `places` it involves by slug. A person lists
  `relations` to other people (`role` describes the *other* person).
- A route in `routes.json` lists `stops` by place slug in walking order, with an
  optional note on each stop. It may also list related `stories` by slug.
- A place may include optional `latitude` and `longitude` numbers. Set both
  together; they are stored in the database and are used by the map's
  1/3/5/10/20 km radius filter and by guided-route distances. A place can also
  carry `coordinate_confidence` (`high` or `approximate`) and
  `coordinate_source` so later reviews know where a pin came from.
- Rebuild the database after any change:

  ```
  python tools/build_db.py
  ```

  The script checks the rules above and fails if a link points to a slug that
  does not exist. It writes `assets/db/vrajamandala.db` and
  `assets/db/version.txt`; the app picks up the new database automatically on
  next launch.

### Finding missing coordinates

For places that still lack pins, `tools/geo_candidates.py` can generate a
review-only report from OpenStreetMap:

```
python tools/geo_candidates.py
```

It writes `tools/geo_candidates.json`. The search is rate-limited and bounded
to the Vraja region, and it needs an internet connection. **Do not apply
candidates automatically**: compare the candidate name, place type, address and
the content description first. Clear matches can then be copied into
`content/en/places.json` with `latitude`, `longitude`,
`coordinate_confidence` and `coordinate_source`.

The Excel workbook is a downstream copy of the app data. After content or
coordinate changes, sync it with:

```
python tools/sync_app_to_xlsx.py --apply
```

This overwrites `C:\Users\austr\OneDrive\Documents\holy_places.xlsx`, updates
coordinates, confidence, provenance, descriptions and app IDs, and keeps a
backup in the temporary folder. Run without `--apply` for a dry run.

## Map

The **Map of holy places** screen starts at central Vṛndāvana. Tap the map to
move the centre, then choose a 1, 3, 5, 10 or 20 km radius. Markers and the
nearby list include only places with coordinates; the list is sorted by
distance.

Place data and the radius calculation are local and work offline. Both map
screens share `lib/maps/basemap_layer.dart`: it uses a bundled BBBike raster
MBTiles extract when one is available, and otherwise falls back to online
OpenStreetMap tiles. Android release builds include the `INTERNET` permission
for that fallback.

### Offline Vraja basemap (BBBike extract)

The free BBBike extract service has no API, so the extract must be requested
interactively in a browser (do not automate or scrape it):

1. Open https://extract.bbbike.org/ and draw or enter a bounding box covering
   Vraja Mandala. A suitable box is west `77.1`, south `27.2`, east `78.1`,
   north `28.0`.
2. Choose the raster **MBTiles** output format (PNG/JPEG/WebP tiles, not the
   vector Shortbread format), enter your email and submit the request.
3. When the download link arrives, save the extract as
   `assets/maps/vraja-mandala.mbtiles`.
4. Rebuild the app. On first launch the app copies the extract into its support
   folder and uses it for both screens, with no network connection needed.

Keep the extract's zoom range modest so the app package stays small. BBBike
extracts are generated from OpenStreetMap data (© OpenStreetMap contributors,
ODbL 1.0) and may expire; request a fresh extract when needed. Attribution is
shown on both maps.

## Guided parikrama routes

The **Guided parikrama routes** screen offers curated walks such as
"Vṛndāvana: seven temples", "Govardhana half-day" and "Rādhā-kuṇḍa circuit".
Each route shows its stops in order on a small map and in a list, with
straight-line distances between mapped stops. Use **Next stop** to advance;
**Open place** takes you to the current stop's full entry. Routes may also link
to related stories.

Stops without coordinates remain in the sequence, but no distance is shown for
those legs. Route distances are straight-line estimates, not measured walking
paths.

### Adding a language later

Create `content/hi/` (for example) with the same three files, reusing the same
`slug` values. The build script gives each translation the same ids. The app
currently reads `en` only (`Repository.lang`).

## Changing the icon

The launcher icon source is `assets/icon/app_icon.png`. After replacing it, run:

```
dart run flutter_launcher_icons
```

The config in `pubspec.yaml` currently generates the Windows icon. Enable the
`android` and `ios` entries there after adding those platform folders.

## Project layout

```
content/en/*.json         source of truth for all content, including routes
tools/build_db.py         validates content, builds the SQLite database
assets/db/                generated database (committed so the app can run)
assets/icon/              launcher icon source
lib/data/                 models, database opening, queries
lib/maps/                 shared basemap layer and configuration
lib/providers.dart        Riverpod providers (content, routes, search, saved)
lib/screens/              home, lists, entry, map, routes, search, saved, about
lib/utils/geo.dart        haversine distance for radius and route legs
assets/maps/              optional BBBike raster MBTiles extract
lib/widgets/common.dart   shared tiles and related-links section
```

## Content and rights

The retellings here are original summaries with the scripture reference given
for each. Before releasing, check any quoted text, translation, image or audio
you add, since many published editions are under copyright. All entries start
as `draft`.

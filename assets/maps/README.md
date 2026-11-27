# Offline map extracts

Place a **vector PBF** MBTiles extract from https://extract.bbbike.org/ here as
`vraja-mandala.mbtiles`. BBBike's "MBTiles Basic" output uses the OpenMapTiles
schema, which `openmaptiles-style.json` renders.

The folder is declared as an app asset in `pubspec.yaml`; on first launch the
app copies the extract into its application support folder and opens it for the
map and route screens. The `.mbtiles` file is gitignored because it is large:
keep a local copy if you want offline maps in your builds. If it is absent, the
app falls back to online OpenStreetMap tiles.

See the "Offline Vraja basemap (BBBike extract)" section of the project README
for the recommended bounding box and request steps.

Map data © OpenStreetMap contributors (ODbL 1.0).

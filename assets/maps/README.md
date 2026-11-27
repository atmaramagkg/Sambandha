# Offline map extracts

Place a **raster** MBTiles extract from https://extract.bbbike.org/ here as
`vraja-mandala.mbtiles`. The folder is declared as an app asset in
`pubspec.yaml`; on first launch the app copies the extract into its application
support folder and opens it for the map and route screens.

See the "Offline Vraja basemap (BBBike extract)" section of the project README
for the recommended bounding box and request steps. If this file is absent, the
app falls back to online OpenStreetMap tiles.

Map data © OpenStreetMap contributors (ODbL 1.0).

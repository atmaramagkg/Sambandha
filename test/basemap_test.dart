import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter_test/flutter_test.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

class _RecordingLogger implements vtr.Logger {
  final warnings = <String>[];

  @override
  void log(vtr.MessageFunction message) {}

  @override
  void warn(vtr.MessageFunction message) => warnings.add(message());
}

Map<String, dynamic> _readStyle() => jsonDecode(
      File('assets/maps/openmaptiles-style.json').readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  test('offline style uses the OpenMapTiles source', () {
    final theme = vtr.ThemeReader().read(_readStyle());
    expect(theme.tileSources, contains('openmaptiles'));
  });

  test('offline style filters use syntax supported by the renderer', () {
    final logger = _RecordingLogger();
    vtr.ThemeReader(logger: logger).read(_readStyle());
    expect(logger.warnings, isEmpty);
  });

  test('bundled BBBike extract renders a visible Vraja tile', () async {
    const extractPath = 'assets/maps/vraja-mandala.mbtiles';
    if (!File(extractPath).existsSync()) {
      // The large extract is kept locally and is not committed.
      return;
    }

    final mbtiles = MbTiles(path: extractPath);
    addTearDown(mbtiles.close);
    expect(mbtiles.getMetadata().format, 'pbf');

    final theme = vtr.ThemeReader().read(_readStyle());
    final provider = MbTilesVectorTileProvider(mbtiles: mbtiles);
    // XYZ tile covering central Vṛndāvana at zoom 13.
    final bytes = await provider.provide(TileIdentity(13, 5863, 3442));
    final vectorTile = vtr.VectorTileReader().read(bytes);
    final tile = vtr.TileFactory(theme, const vtr.Logger.noop()).create(
      vectorTile,
    );
    final image = await vtr.ImageRenderer(theme: theme, scale: 1).render(
      vtr.TileSource(tileset: vtr.Tileset({'openmaptiles': tile})),
      zoom: 13,
    );
    final pixels = await image.toByteData(format: ImageByteFormat.rawRgba);
    final bytesArgb = pixels!.buffer.asUint8List(
      pixels.offsetInBytes,
      pixels.lengthInBytes,
    );

    const background = [247, 243, 238];
    var featurePixels = 0;
    for (var i = 0; i < bytesArgb.length; i += 4) {
      if (bytesArgb[i] != background[0] ||
          bytesArgb[i + 1] != background[1] ||
          bytesArgb[i + 2] != background[2]) {
        featurePixels++;
      }
    }

    expect(featurePixels, greaterThan(5000));
  });
}

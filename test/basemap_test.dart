import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

void main() {
  test('offline style uses the OpenMapTiles source', () {
    final style = jsonDecode(
      File('assets/maps/openmaptiles-style.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final theme = vtr.ThemeReader().read(style);
    expect(theme.tileSources, contains('openmaptiles'));
  });

  test('bundled BBBike extract can serve a Vraja tile', () {
    const extractPath = 'assets/maps/vraja-mandala.mbtiles';
    if (!File(extractPath).existsSync()) {
      // The large extract is kept locally and is not committed.
      return;
    }
    final mbtiles = MbTiles(path: extractPath);
    addTearDown(mbtiles.close);
    expect(mbtiles.getMetadata().format, 'pbf');
    // TMS row for the tile covering central Vṛndāvana at zoom 12.
    final tile = mbtiles.getTile(z: 12, x: 2931, y: 2374);
    expect(tile, isNotNull);
    expect(tile!.isNotEmpty, isTrue);
  });
}

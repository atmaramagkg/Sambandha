import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'map_config.dart';

const _mapVersionPrefKey = 'basemap_version';

/// Basemap layer that uses the bundled BBBike vector MBTiles extract when
/// present.
///
/// The extract cannot be opened directly from assets, so it is copied into the
/// app support directory on first launch (or after the bundled file changes).
/// If no extract has been bundled, the layer falls back to online tiles so the
/// maps still work on connected devices.
class BasemapLayer extends StatefulWidget {
  const BasemapLayer({super.key});

  @override
  State<BasemapLayer> createState() => _BasemapLayerState();
}

class _BasemapLayerState extends State<BasemapLayer> {
  MbTiles? _mbtiles;
  vtr.Theme? _theme;
  TileProviders? _tileProviders;
  Directory? _cacheFolder;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _prepareOfflineMap();
  }

  Future<void> _prepareOfflineMap() async {
    try {
      final asset = await rootBundle.load(MapConfig.offlineMbtilesAsset);
      final bytes = asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      );

      final support = await getApplicationSupportDirectory();
      final dir = p.join(support.path, 'maps');
      final dest = p.join(dir, MapConfig.offlineMbtilesFileName);
      final prefs = await SharedPreferences.getInstance();
      final version = bytes.length.toString();

      if (!File(dest).existsSync() ||
          prefs.getString(_mapVersionPrefKey) != version) {
        await Directory(dir).create(recursive: true);
        await File(dest).writeAsBytes(bytes, flush: true);
        await prefs.setString(_mapVersionPrefKey, version);
      }

      final styleText = await rootBundle.loadString(MapConfig.offlineStyleAsset);
      final style = jsonDecode(styleText) as Map<String, dynamic>;
      final styleVersion =
          (style['metadata'] as Map?)?['version']?.toString() ?? '0';
      // Rendered tiles are cached by theme version. Keep our cache outside the
      // OS temp folder so an old style version can never be reused silently.
      _cacheFolder = Directory(p.join(dir, 'tile-cache', styleVersion));
      final mbtiles = MbTiles(path: dest);
      _theme = vtr.ThemeReader(logger: const vtr.Logger.console()).read(style);
      _tileProviders = TileProviders({
        MapConfig.offlineTileSource: MbTilesVectorTileProvider(
          mbtiles: mbtiles,
        ),
      });
      _mbtiles = mbtiles;
    } catch (error, stack) {
      // No extract bundled, or it could not be opened: use online tiles, but
      // make the reason visible in the console instead of failing silently.
      debugPrint('Offline basemap unavailable; using online tiles: $error');
      debugPrint('$stack');
      _mbtiles?.close();
      _mbtiles = null;
      _theme = null;
      _tileProviders = null;
      _cacheFolder = null;
    }
    if (mounted) setState(() => _checked = true);
  }

  @override
  void dispose() {
    _mbtiles?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final providers = _tileProviders;
    if (!_checked || theme == null || providers == null) {
      return TileLayer(
        urlTemplate: MapConfig.onlineTileUrl,
        userAgentPackageName: MapConfig.userAgentPackageName,
        minZoom: MapConfig.minZoom,
        maxZoom: MapConfig.maxZoom,
        maxNativeZoom: MapConfig.maxNativeZoom,
      );
    }
    return VectorTileLayer(
      theme: theme,
      tileProviders: providers,
      maximumZoom: MapConfig.maxZoom,
      // vector_map_tiles resolves this type to dart:io at runtime, but the
      // analyzer sees its web stub (String). Returning dynamic satisfies both.
      cacheFolder: () async {
        final folder = _cacheFolder;
        if (folder == null) throw StateError('Offline basemap is not ready');
        return folder as dynamic;
      },
    );
  }
}

/// Attribution shared by both map screens.
class BasemapAttribution extends StatelessWidget {
  const BasemapAttribution({super.key});

  @override
  Widget build(BuildContext context) => const SimpleAttributionWidget(
        source: Text(MapConfig.attribution),
      );
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'map_config.dart';

const _mapVersionPrefKey = 'basemap_version';

/// Basemap layer that uses the bundled BBBike MBTiles extract when present.
///
/// The extract cannot be opened directly from assets, so it is copied into the
/// app support directory on first launch (or after the bundled file changes).
/// If no extract has been bundled yet, the layer falls back to online tiles so
/// the maps still work on connected devices.
class BasemapLayer extends StatefulWidget {
  const BasemapLayer({super.key});

  @override
  State<BasemapLayer> createState() => _BasemapLayerState();
}

class _BasemapLayerState extends State<BasemapLayer> {
  MbTilesTileProvider? _offlineProvider;
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

      _offlineProvider = MbTilesTileProvider.fromPath(path: dest);
    } catch (_) {
      // No extract bundled, or it could not be opened: use online tiles.
      _offlineProvider?.dispose();
      _offlineProvider = null;
    }
    if (mounted) setState(() => _checked = true);
  }

  @override
  void dispose() {
    _offlineProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _offlineProvider;
    if (!_checked || provider == null) {
      return TileLayer(
        urlTemplate: MapConfig.onlineTileUrl,
        userAgentPackageName: MapConfig.userAgentPackageName,
        minZoom: MapConfig.minZoom,
        maxZoom: MapConfig.maxZoom,
        maxNativeZoom: MapConfig.maxNativeZoom,
      );
    }
    return TileLayer(
      tileProvider: provider,
      minZoom: MapConfig.minZoom,
      maxZoom: MapConfig.maxZoom,
      maxNativeZoom: MapConfig.maxNativeZoom,
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

/// Shared basemap configuration for the map and guided-route screens.
class MapConfig {
  const MapConfig._();

  /// Online fallback, used only when no local extract is bundled/available.
  static const onlineTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Identifies requests to the public OpenStreetMap tile server.
  static const userAgentPackageName = 'com.vrajamandala.vraja_mandala';

  /// A BBBike raster MBTiles extract copied into the app's support folder.
  static const offlineMbtilesAsset = 'assets/maps/vraja-mandala.mbtiles';
  static const offlineMbtilesFileName = 'vraja-mandala.mbtiles';

  static const minZoom = 8.0;
  static const maxZoom = 18.0;
  static const maxNativeZoom = 19;

  static const attribution =
      '© OpenStreetMap contributors · extract by BBBike';
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../data/models.dart';
import '../maps/basemap_layer.dart';
import '../providers.dart';
import '../utils/geo.dart';

/// Map of located holy places, with a 1/3/5/10/20 km radius around a centre.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  /// Central Vṛndāvana, used as the starting centre.
  static const LatLng vrindavanCenter = LatLng(27.572242, 77.6775);

  static const List<int> radiusOptions = [1000, 3000, 5000, 10000, 20000];

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  LatLng _center = MapScreen.vrindavanCenter;
  int _radiusMeters = 3000;

  void _resetCenter() {
    setState(() => _center = MapScreen.vrindavanCenter);
  }

  /// Zoom out as the circle grows so the whole radius stays visible.
  double _zoomForRadius(int meters) => switch (meters) {
        >= 20000 => 10.5,
        >= 10000 => 11.5,
        >= 5000 => 12.5,
        _ => 13,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final places = ref.watch(entriesProvider(EntityKind.place));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map of holy places'),
        actions: [
          IconButton(
            tooltip: 'Reset centre to Vṛndāvana',
            icon: const Icon(Icons.my_location),
            onPressed: _resetCenter,
          ),
        ],
      ),
      body: places.when(
        data: (entries) {
          final located = entries.where((e) => e.hasCoordinates).toList();
          final nearby = <({Entry entry, double distance})>[];
          for (final entry in located) {
            final distance = haversineMeters(
              _center.latitude,
              _center.longitude,
              entry.latitude!,
              entry.longitude!,
            );
            if (distance <= _radiusMeters) {
              nearby.add((entry: entry, distance: distance));
            }
          }
          nearby.sort((a, b) => a.distance.compareTo(b.distance));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: [
                            for (final radius in MapScreen.radiusOptions)
                              ButtonSegment(
                                value: radius,
                                label: Text('${radius ~/ 1000} km'),
                              ),
                          ],
                          selected: {_radiusMeters},
                          onSelectionChanged: (selection) {
                            if (selection.isEmpty) return;
                            setState(() => _radiusMeters = selection.first);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${nearby.length} ${nearby.length == 1 ? 'place' : 'places'} '
                  'within ${_radiusMeters ~/ 1000} km · '
                  '${located.length} of ${entries.length} places on the map',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                flex: 3,
                child: Stack(
                  children: [
                    // Rebuild when the centre or radius changes so the map
                    // recentres and zooms out far enough to show the circle.
                    FlutterMap(
                      key: ValueKey('$_center-$_radiusMeters'),
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _zoomForRadius(_radiusMeters),
                        minZoom: 8,
                        maxZoom: 18,
                        onTap: (_, latLng) {
                          setState(() => _center = latLng);
                        },
                      ),
                      children: [
                        const BasemapLayer(),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _center,
                              radius: _radiusMeters.toDouble(),
                              useRadiusInMeter: true,
                              color: const Color(0x33E08A1E),
                              borderColor: const Color(0xFFE08A1E),
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            for (final item in nearby)
                              Marker(
                                point: LatLng(
                                  item.entry.latitude!,
                                  item.entry.longitude!,
                                ),
                                width: 32,
                                height: 32,
                                child: GestureDetector(
                                  onTap: () => context.push(item.entry.path),
                                  child: CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary,
                                    child: const Icon(
                                      Icons.place,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const BasemapAttribution(),
                      ],
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: IgnorePointer(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              'Tap the map to move the centre',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                flex: 2,
                child: nearby.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No located places within ${_radiusMeters ~/ 1000} km '
                            'of this centre. Try a larger radius or tap elsewhere '
                            'on the map.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: nearby.length,
                        itemBuilder: (context, index) {
                          final item = nearby[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(item.entry.title),
                            subtitle: Text(
                              formatDistance(item.distance),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(item.entry.path),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load places.\n$error',
                textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

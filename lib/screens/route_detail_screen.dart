import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../data/models.dart';
import '../providers.dart';
import '../utils/geo.dart';
import '../widgets/common.dart';

/// One guided walk, with an ordered stop list and a Next stop control.
class RouteDetailScreen extends ConsumerStatefulWidget {
  const RouteDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  int _current = 0;

  void _select(int index) => setState(() => _current = index);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final routeValue = ref.watch(parikramaRouteProvider(widget.slug));

    return Scaffold(
      appBar: AppBar(title: const Text('Guided parikrama')),
      body: AsyncBody<ParikramaRoute?>(
        value: routeValue,
        builder: (route) {
          if (route == null || route.stops.isEmpty) {
            return const Center(child: Text('This route is not available.'));
          }

          final index = _current.clamp(0, route.stops.length - 1);
          final current = route.stops[index];
          final isLast = index == route.stops.length - 1;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route.title, style: theme.textTheme.titleLarge),
                      if (route.titleDeva != null) ...[
                        const SizedBox(height: 4),
                        Text(route.titleDeva!,
                            style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 8),
                      Text(route.summary),
                      const SizedBox(height: 12),
                      _RouteStats(route: route),
                      const SizedBox(height: 12),
                      _CurrentStopBanner(
                        stop: current,
                        total: route.stops.length,
                        onOpen: () => context.push(current.place.path),
                      ),
                      const SizedBox(height: 12),
                      _RouteMap(
                        route: route,
                        currentIndex: index,
                        onSelectStop: _select,
                      ),
                      if (route.stories.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Read with the walk',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final story in route.stories)
                              ActionChip(
                                avatar: Icon(iconForKind(story.kind), size: 18),
                                label: Text(story.title),
                                onPressed: () => context.push(story.path),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text('Stops in order',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (var i = 0; i < route.stops.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _StopCard(
                            stop: route.stops[i],
                            isCurrent: i == index,
                            onTap: () => _select(i),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ExpansionTile(
                        title: const Text('About this route'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final paragraph in route.paragraphs) ...[
                                  Text(paragraph),
                                  const SizedBox(height: 8),
                                ],
                                Text(route.sourceRef,
                                    style: theme.textTheme.bodySmall),
                                if (!route.isReviewed) ...[
                                  const SizedBox(height: 8),
                                  Text('Draft · not yet reviewed',
                                      style: theme.textTheme.bodySmall),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    if (index > 0)
                      TextButton.icon(
                        onPressed: () => _select(index - 1),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Previous'),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: isLast ? null : () => _select(index + 1),
                      icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
                      label: Text(isLast ? 'Route complete' : 'Next stop'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RouteStats extends StatelessWidget {
  const _RouteStats({required this.route});

  final ParikramaRoute route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <(IconData, String)>[
      (Icons.straighten, formatDistance(route.totalMeters)),
      (Icons.place_outlined, '${route.stops.length} stops'),
      if (route.unmappedStops > 0)
        (Icons.info_outline, '${route.unmappedStops} need pins'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final (icon, label) in items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(label, style: theme.textTheme.bodySmall),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Straight-line distance between mapped stops; walking paths may be longer.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CurrentStopBanner extends StatelessWidget {
  const _CurrentStopBanner({
    required this.stop,
    required this.total,
    required this.onOpen,
  });

  final ParikramaStop stop;
  final int total;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      'Stop ${stop.position} of $total',
      if (stop.hasLegDistance)
        '${formatDistance(stop.distanceFromPreviousMeters!)} from previous',
      if (!stop.place.hasCoordinates) 'Coordinates not added yet',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.flag, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stop.place.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(details.join(' · '), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: onOpen, child: const Text('Open place')),
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.isCurrent,
    required this.onTap,
  });

  final ParikramaStop stop;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      if (stop.note != null && stop.note!.isNotEmpty) stop.note!,
      if (stop.hasLegDistance)
        '${formatDistance(stop.distanceFromPreviousMeters!)} from previous'
      else if (stop.position > 1)
        'Distance unavailable',
    ];
    return Card(
      color: isCurrent ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isCurrent ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          foregroundColor: isCurrent ? Colors.white : theme.colorScheme.onSurface,
          child: Text('${stop.position}'),
        ),
        title: Text(stop.place.title),
        subtitle: details.isEmpty ? null : Text(details.join(' · ')),
        trailing: isCurrent
            ? Icon(Icons.flag, color: theme.colorScheme.primary)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.route,
    required this.currentIndex,
    required this.onSelectStop,
  });

  final ParikramaRoute route;
  final int currentIndex;
  final void Function(int index) onSelectStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final located = <({int index, LatLng point})>[];
    for (var i = 0; i < route.stops.length; i++) {
      final place = route.stops[i].place;
      if (place.hasCoordinates) {
        located.add((index: i, point: LatLng(place.latitude!, place.longitude!)));
      }
    }

    if (located.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No stops on this route have coordinates yet.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final center = LatLng(
      located.map((s) => s.point.latitude).reduce((a, b) => a + b) /
          located.length,
      located.map((s) => s.point.longitude).reduce((a, b) => a + b) /
          located.length,
    );
    final zoom = switch (route.totalMeters) {
      >= 8000 => 11.5,
      >= 4000 => 12.5,
      _ => 13.5,
    };
    final points = located.map((s) => s.point).toList();
    final cameraFit = points.length > 1
        ? CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.all(28),
            maxZoom: 14.5,
            minZoom: 8,
          )
        : null;
    final currentPoint = located
        .where((s) => s.index == currentIndex)
        .map((s) => s.point)
        .firstOrNull;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 240,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            initialCameraFit: cameraFit,
            minZoom: 8,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'vraja_mandala',
              maxNativeZoom: 19,
            ),
            if (currentPoint != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: currentPoint,
                    radius: 90,
                    useRadiusInMeter: true,
                    color: const Color(0x33E08A1E),
                    borderColor: const Color(0xFFE08A1E),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            if (points.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    color: const Color(0xFFE08A1E),
                    strokeWidth: 4,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final stop in located)
                  Marker(
                    point: stop.point,
                    width: 34,
                    height: 34,
                    child: GestureDetector(
                      onTap: () => onSelectStop(stop.index),
                      child: CircleAvatar(
                        backgroundColor: stop.index == currentIndex
                            ? theme.colorScheme.primary
                            : Colors.white,
                        foregroundColor: stop.index == currentIndex
                            ? Colors.white
                            : theme.colorScheme.primary,
                        child: Text(
                          '${stop.index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('© OpenStreetMap contributors'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../providers.dart';
import '../utils/geo.dart';
import '../widgets/common.dart';

/// List of curated guided walks.
class RoutesScreen extends ConsumerWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final routes = ref.watch(parikramaRoutesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Guided parikrama routes')),
      body: AsyncBody<List<ParikramaRoute>>(
        value: routes,
        builder: (list) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final route = list[index];
            final details = <String>[
              '${route.stops.length} stops',
              formatDistance(route.totalMeters),
              if (route.unmappedStops > 0)
                '${route.unmappedStops} need coordinates',
            ];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.route, color: theme.colorScheme.primary),
                ),
                title: Text(route.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      route.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details.join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(route.path),
              ),
            );
          },
        ),
      ),
    );
  }
}

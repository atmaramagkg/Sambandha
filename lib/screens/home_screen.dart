import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../providers.dart';
import '../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final featured = ref.watch(storyOfTheDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vraja Mandala'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: 'Saved',
            icon: const Icon(Icons.bookmark_border),
            onPressed: () => context.push('/saved'),
          ),
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push('/about'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Story of the day', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          featured.when(
            data: (story) => story == null
                ? const SizedBox.shrink()
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.push(story.path),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(story.title,
                                style: theme.textTheme.titleLarge),
                            if (story.titleDeva != null) ...[
                              const SizedBox(height: 4),
                              Text(story.titleDeva!,
                                  style: theme.textTheme.bodyMedium),
                            ],
                            const SizedBox(height: 8),
                            Text(story.summary),
                            const SizedBox(height: 8),
                            Text(story.sourceRef,
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Could not load content.\n$e'),
          ),
          const SizedBox(height: 24),
          Text('Explore', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Map of holy places'),
              subtitle: const Text('Find places within 1, 3, 5, 10 or 20 km'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/map'),
            ),
          ),
          const SizedBox(height: 8),
          const _RouteCard(),
          const SizedBox(height: 24),
          Text('Browse', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final kind in EntityKind.values)
            _BrowseCard(kind: kind),
        ],
      ),
    );
  }
}

class _RouteCard extends ConsumerWidget {
  const _RouteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(parikramaRoutesProvider).maybeWhen(
          data: (routes) => '${routes.length}',
          orElse: () => '',
        );
    return Card(
      child: ListTile(
        leading: const Icon(Icons.route),
        title: const Text('Guided parikrama routes'),
        subtitle: const Text('Seven temples, Govardhana, Rādhā-kuṇḍa'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(count),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push('/routes'),
      ),
    );
  }
}

class _BrowseCard extends ConsumerWidget {
  const _BrowseCard({required this.kind});

  final EntityKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(entriesProvider(kind)).maybeWhen(
          data: (list) => '${list.length}',
          orElse: () => '',
        );
    return Card(
      child: ListTile(
        leading: Icon(iconForKind(kind)),
        title: Text(kind.plural),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(count),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push('/list/${kind.key}'),
      ),
    );
  }
}

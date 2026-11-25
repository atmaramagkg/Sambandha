import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// The page for one personality, place or story.
class EntryScreen extends ConsumerWidget {
  const EntryScreen({super.key, required this.kind, required this.id});

  final EntityKind kind;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(entryProvider((kind, id)));
    final saved = ref.watch(savedProvider).contains(SavedNotifier.keyFor(kind, id));

    return Scaffold(
      appBar: AppBar(
        title: Text(kind.label),
        actions: [
          IconButton(
            tooltip: saved ? 'Remove from saved' : 'Save',
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => ref.read(savedProvider.notifier).toggle(kind, id),
          ),
        ],
      ),
      body: AsyncBody<Entry?>(
        value: entry,
        builder: (e) {
          if (e == null) {
            return const Center(child: Text('This page was not found.'));
          }
          return _EntryBody(entry: e);
        },
      ),
    );
  }
}

class _EntryBody extends StatelessWidget {
  const _EntryBody({required this.entry});

  final Entry entry;

  /// What an entry links to, by kind.
  List<EntityKind> get _targets => switch (entry.kind) {
        EntityKind.person => [
            EntityKind.person,
            EntityKind.story,
            EntityKind.place,
          ],
        EntityKind.place => [EntityKind.story, EntityKind.person],
        EntityKind.story => [EntityKind.person, EntityKind.place],
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.title, style: theme.textTheme.headlineSmall),
          if (entry.titleDeva != null) ...[
            const SizedBox(height: 4),
            Text(entry.titleDeva!, style: theme.textTheme.titleMedium),
          ],
          const SizedBox(height: 12),
          Text(
            entry.summary,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          for (final paragraph in entry.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(paragraph,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
            ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.menu_book_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Source: ${entry.sourceRef}',
                    style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
          if (!entry.isReviewed) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Draft retelling, not yet reviewed. Please check it against '
                'the source cited above.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          for (final target in _targets)
            RelatedSection(from: entry.kind, id: entry.id, target: target),
        ],
      ),
    );
  }
}

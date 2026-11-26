import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../providers.dart';

IconData iconForKind(EntityKind kind) => switch (kind) {
      EntityKind.person => Icons.person_outline,
      EntityKind.place => Icons.place_outlined,
      EntityKind.story => Icons.auto_stories_outlined,
    };

/// Keeps Android's three-button navigation strip from covering app controls.
///
/// Applied around the whole app so every route inherits the inset. The top,
/// left and right insets are left to each Scaffold/AppBar.
class BottomSafeArea extends StatelessWidget {
  const BottomSafeArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: child,
    );
  }
}

/// Shows loading and error states around an [AsyncValue].
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Something went wrong.\n$error',
              textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// A list row for an entry; tapping opens its page.
class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, this.showKind = false});

  final Entry entry;
  final bool showKind;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(iconForKind(entry.kind)),
      title: Text(entry.title),
      subtitle: Text(
        showKind ? '${entry.kind.label} · ${entry.summary}' : entry.summary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => context.push(entry.path),
    );
  }
}

/// A heading and a row of chips linking to related entries.
/// Shows nothing when there are no related entries.
class RelatedSection extends ConsumerWidget {
  const RelatedSection({
    super.key,
    required this.from,
    required this.id,
    required this.target,
  });

  final EntityKind from;
  final int id;
  final EntityKind target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(relatedProvider((from, id, target)));
    return related.maybeWhen(
      data: (entries) {
        if (entries.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(target.plural,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in entries)
                    ActionChip(
                      avatar: Icon(iconForKind(e.kind), size: 18),
                      label: Text(
                          e.extra == null ? e.title : '${e.title} · ${e.extra}'),
                      onPressed: () => context.push(e.path),
                    ),
                ],
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

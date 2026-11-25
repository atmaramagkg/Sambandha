import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../providers.dart';
import '../widgets/common.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: AsyncBody<List<Entry>>(
        value: saved,
        builder: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing saved yet. Tap the bookmark on any page to keep it here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) =>
                EntryTile(entry: entries[i], showKind: true),
          );
        },
      ),
    );
  }
}

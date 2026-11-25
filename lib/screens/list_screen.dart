import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../providers.dart';
import '../widgets/common.dart';

class ListScreen extends ConsumerWidget {
  const ListScreen({super.key, required this.kind});

  final EntityKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider(kind));
    return Scaffold(
      appBar: AppBar(
        title: Text(kind.plural),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: AsyncBody<List<Entry>>(
        value: entries,
        builder: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) => EntryTile(entry: list[i]),
        ),
      ),
    );
  }
}

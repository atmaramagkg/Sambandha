import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'data/content_database.dart';
import 'data/models.dart';
import 'data/repository.dart';

final databaseProvider = FutureProvider<Database>((ref) => openContentDatabase());

final repositoryProvider = FutureProvider<Repository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return Repository(db);
});

final entriesProvider =
    FutureProvider.family<List<Entry>, EntityKind>((ref, kind) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.list(kind);
});

/// Key is (kind, id).
final entryProvider =
    FutureProvider.family<Entry?, (EntityKind, int)>((ref, key) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.get(key.$1, key.$2);
});

/// Key is (fromKind, fromId, targetKind).
final relatedProvider = FutureProvider.family<List<Entry>,
    (EntityKind, int, EntityKind)>((ref, key) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.related(key.$1, key.$2, key.$3);
});

final parikramaRoutesProvider = FutureProvider<List<ParikramaRoute>>((ref) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.listParikramaRoutes();
});

/// Key is the route slug.
final parikramaRouteProvider =
    FutureProvider.family<ParikramaRoute?, String>((ref, slug) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.getParikramaRoute(slug);
});

final searchProvider =
    FutureProvider.family<List<Entry>, String>((ref, query) async {
  final repo = await ref.watch(repositoryProvider.future);
  return repo.search(query);
});

/// A different story each day, the same one for everybody on that day.
final storyOfTheDayProvider = FutureProvider<Entry?>((ref) async {
  final stories = await ref.watch(entriesProvider(EntityKind.story).future);
  if (stories.isEmpty) return null;
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
  return stories[dayOfYear % stories.length];
});

/// Saved items, stored on the device as "kind:id" strings.
class SavedNotifier extends Notifier<List<String>> {
  static const _prefKey = 'saved_items';

  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_prefKey) ?? const [];
  }

  static String keyFor(EntityKind kind, int id) => '${kind.key}:$id';

  bool isSaved(EntityKind kind, int id) => state.contains(keyFor(kind, id));

  Future<void> toggle(EntityKind kind, int id) async {
    final key = keyFor(kind, id);
    final next = [...state];
    if (!next.remove(key)) next.add(key);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, next);
  }
}

final savedProvider =
    NotifierProvider<SavedNotifier, List<String>>(SavedNotifier.new);

/// The saved items, loaded as entries (newest first).
final savedEntriesProvider = FutureProvider<List<Entry>>((ref) async {
  final keys = ref.watch(savedProvider);
  final repo = await ref.watch(repositoryProvider.future);
  final entries = <Entry>[];
  for (final key in keys.reversed) {
    final parts = key.split(':');
    if (parts.length != 2) continue;
    final kind = entityKindFromKey(parts[0]);
    final id = int.tryParse(parts[1]);
    if (kind == null || id == null) continue;
    final entry = await repo.get(kind, id);
    if (entry != null) entries.add(entry);
  }
  return entries;
});

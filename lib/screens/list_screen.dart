import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../providers.dart';
import '../utils/place_categories.dart';
import '../widgets/common.dart';

enum _PlaceGroup { all, mapped, unmapped }

extension _PlaceGroupX on _PlaceGroup {
  String get label => switch (this) {
        _PlaceGroup.all => 'All',
        _PlaceGroup.mapped => 'On map',
        _PlaceGroup.unmapped => 'Unmapped',
      };

  IconData get icon => switch (this) {
        _PlaceGroup.all => Icons.list_alt_outlined,
        _PlaceGroup.mapped => Icons.map_outlined,
        _PlaceGroup.unmapped => Icons.place_outlined,
      };

  String get emptyMessage => switch (this) {
        _PlaceGroup.all => 'No places available yet.',
        _PlaceGroup.mapped => 'No places are on the map yet.',
        _PlaceGroup.unmapped => 'Every place is on the map.',
      };
}

class ListScreen extends ConsumerStatefulWidget {
  const ListScreen({super.key, required this.kind});

  final EntityKind kind;

  @override
  ConsumerState<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends ConsumerState<ListScreen> {
  _PlaceGroup _group = _PlaceGroup.all;
  PlaceCategory _category = PlaceCategory.all;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(entriesProvider(widget.kind));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind.plural),
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
        builder: (list) {
          if (widget.kind != EntityKind.place) {
            return _EntryList(entries: list);
          }

          final groupCounts = {
            _PlaceGroup.all: list.length,
            _PlaceGroup.mapped: list.where((e) => e.hasCoordinates).length,
            _PlaceGroup.unmapped: list.where((e) => !e.hasCoordinates).length,
          };
          final inGroup = switch (_group) {
            _PlaceGroup.all => list,
            _PlaceGroup.mapped =>
              list.where((e) => e.hasCoordinates).toList(),
            _PlaceGroup.unmapped =>
              list.where((e) => !e.hasCoordinates).toList(),
          };
          final categoryCounts = {
            for (final category in PlaceCategory.values)
              category: category == PlaceCategory.all
                  ? inGroup.length
                  : inGroup
                      .where((e) => categoryForTitle(e.title) == category)
                      .length,
          };
          final visible = _category == PlaceCategory.all
              ? inGroup
              : inGroup
                  .where((e) => categoryForTitle(e.title) == _category)
                  .toList();
          final emptyMessage = inGroup.isEmpty
              ? _group.emptyMessage
              : 'No ${_category.label.toLowerCase()} in this group.';

          return Column(
            children: [
              _PlaceGroupBar(
                group: _group,
                counts: groupCounts,
                onChanged: (group) => setState(() {
                  _group = group;
                  _category = PlaceCategory.all;
                }),
              ),
              _CategoryBar(
                selected: _category,
                counts: categoryCounts,
                onChanged: (category) => setState(() => _category = category),
              ),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            emptyMessage,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _EntryList(entries: visible),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlaceGroupBar extends StatelessWidget {
  const _PlaceGroupBar({
    required this.group,
    required this.counts,
    required this.onChanged,
  });

  final _PlaceGroup group;
  final Map<_PlaceGroup, int> counts;
  final ValueChanged<_PlaceGroup> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Group',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            for (final option in _PlaceGroup.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(option.icon, size: 16),
                  label: Text('${option.label} (${counts[option] ?? 0})'),
                  selected: option == group,
                  onSelected: (_) => onChanged(option),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final PlaceCategory selected;
  final Map<PlaceCategory, int> counts;
  final ValueChanged<PlaceCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Category',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            for (final option in PlaceCategory.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(option.icon, size: 16),
                  label: Text('${option.label} (${counts[option] ?? 0})'),
                  selected: option == selected,
                  onSelected: (_) => onChanged(option),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});

  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final items = <_ListItem>[];
    String? currentLetter;
    for (final entry in entries) {
      final letter = _initial(entry.title);
      if (letter != currentLetter) {
        items.add(_ListItem(letter: letter));
        currentLetter = letter;
      }
      items.add(_ListItem(entry: entry));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, index) => items[index].entry == null
          ? const SizedBox(height: 4)
          : const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.entry == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              item.letter!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          );
        }
        return EntryTile(entry: item.entry!);
      },
    );
  }
}

class _ListItem {
  const _ListItem({this.letter, this.entry});

  final String? letter;
  final Entry? entry;
}

String _initial(String title) {
  final trimmed = title.trimLeft();
  if (trimmed.isEmpty) return '#';
  final first = trimmed.runes.first;
  if (first >= 48 && first <= 57) return '0-9';
  return String.fromCharCode(first).toUpperCase();
}

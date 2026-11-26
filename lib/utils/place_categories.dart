import 'package:flutter/material.dart';

/// Broad, title-based groups for the Places list.
///
/// These are navigation aids, not scholarly classifications. A place appears
/// in one group so the filters stay predictable.
enum PlaceCategory {
  all,
  water,
  trees,
  hills,
  ghats,
  temples,
  towns,
  forests,
  villages,
  other,
}

extension PlaceCategoryX on PlaceCategory {
  String get label => switch (this) {
        PlaceCategory.all => 'All',
        PlaceCategory.water => 'Sacred waters',
        PlaceCategory.trees => 'Trees',
        PlaceCategory.hills => 'Hills & caves',
        PlaceCategory.ghats => 'Ghāṭas',
        PlaceCategory.temples => 'Temples & deities',
        PlaceCategory.towns => 'Towns & regions',
        PlaceCategory.forests => 'Forests & groves',
        PlaceCategory.villages => 'Villages',
        PlaceCategory.other => 'Other places',
      };

  IconData get icon => switch (this) {
        PlaceCategory.all => Icons.apps_outlined,
        PlaceCategory.water => Icons.water_drop_outlined,
        PlaceCategory.trees => Icons.park_outlined,
        PlaceCategory.hills => Icons.terrain_outlined,
        PlaceCategory.ghats => Icons.waves_outlined,
        PlaceCategory.temples => Icons.account_balance_outlined,
        PlaceCategory.towns => Icons.location_city_outlined,
        PlaceCategory.forests => Icons.nature_outlined,
        PlaceCategory.villages => Icons.home_outlined,
        PlaceCategory.other => Icons.place_outlined,
      };
}

const Map<String, String> _foldMap = {
  'ā': 'a', 'Ā': 'a', 'ē': 'e', 'Ē': 'e', 'ī': 'i', 'Ī': 'i',
  'ō': 'o', 'Ō': 'o', 'ū': 'u', 'Ū': 'u', 'ṛ': 'r', 'Ṛ': 'r',
  'ṝ': 'r', 'Ṝ': 'r', 'ḷ': 'l', 'Ḷ': 'l', 'ṅ': 'n', 'Ṅ': 'n',
  'ñ': 'n', 'Ñ': 'n', 'ṭ': 't', 'Ṭ': 't', 'ḍ': 'd', 'Ḍ': 'd',
  'ṇ': 'n', 'Ṇ': 'n', 'ś': 's', 'Ś': 's', 'ṣ': 's', 'Ṣ': 's',
  'ḥ': 'h', 'Ḥ': 'h', 'ṃ': 'm', 'Ṃ': 'm', 'ṁ': 'm', 'Ṁ': 'm',
  'ṟ': 'r', 'Ṉ': 'r', 'ṉ': 'n', 'Ṋ': 'n', 'ô': 'o', 'ê': 'e',
};

String _fold(String title) {
  final buffer = StringBuffer();
  for (final rune in title.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_foldMap[char] ?? char);
  }
  return buffer.toString().toLowerCase();
}

bool _has(String folded, List<String> words) {
  final compact = folded.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  if (compact.isEmpty) return false;
  final tokens = compact.split(' ');
  return words.any((word) => tokens.contains(word) || compact.endsWith(word));
}

/// Chooses one category for [title] using its name only.
PlaceCategory categoryForTitle(String title) {
  final name = _fold(title);

  if (_has(name, const [
    'kunda', 'kund', 'sarovara', 'sarovar', 'sagara', 'sagar', 'tirtha',
    'tirth', 'kupa', 'kup', 'daha', 'pokhara', 'jhil', 'talab', 'lake',
    'well', 'sarasi',
  ])) {
    return PlaceCategory.water;
  }

  // "parvata" ends in "vata"; let it belong to the hills instead.
  if (!_has(name, const ['parvata']) &&
      _has(name, const [
        'vata', 'vat', 'kadamba', 'banyan', 'imli', 'tamarind', 'tamala',
        'peepal', 'neem', 'asoka',
      ])) {
    return PlaceCategory.trees;
  }

  if (_has(name, const [
    'giri', 'pahar', 'pahadi', 'hill', 'saila', 'parvata', 'mountain',
    'cave', 'gufa', 'rock', 'sikhara',
  ])) {
    return PlaceCategory.hills;
  }

  if (_has(name, const [
    'ghata', 'ghat', 'ghati', 'riverbank', 'yamuna', 'tira',
  ])) {
    return PlaceCategory.ghats;
  }

  if (_has(name, const [
    'mandir', 'temple', 'devi', 'siva', 'mahadeva', 'isvara', 'govinda',
    'radha', 'krsna', 'balarama', 'hanuman', 'ganesa', 'asrama', 'ashram',
    'matha', 'samadhi', 'bhavana', 'bhawan', 'kutira', 'mandapa', 'natha',
  ])) {
    return PlaceCategory.temples;
  }

  if (_has(name, const [
    'mathura', 'vrndavana', 'vrindavana', 'govardhana', 'kuruksetra',
    'barsana', 'varsana', 'gokula', 'vraja', 'dhama', 'dham', 'ayodhya',
    'kasi', 'prayaga',
  ])) {
    return PlaceCategory.towns;
  }

  if (_has(name, const [
    'vana', 'van', 'kunj', 'grove', 'forest', 'upavana', 'adhivana',
    'prativana', 'khandi',
  ])) {
    return PlaceCategory.forests;
  }

  if (_has(name, const [
    'grama', 'gram', 'pura', 'pur', 'nagara', 'nagar', 'gaon', 'village',
    'town', 'bazar', 'colony',
  ])) {
    return PlaceCategory.villages;
  }

  return PlaceCategory.other;
}

/// The three kinds of pages in the app.
enum EntityKind { person, place, story }

extension EntityKindX on EntityKind {
  /// Singular label.
  String get label => switch (this) {
        EntityKind.person => 'Personality',
        EntityKind.place => 'Place',
        EntityKind.story => 'Story',
      };

  /// Plural label, used for list screens and section headings.
  String get plural => switch (this) {
        EntityKind.person => 'Personalities',
        EntityKind.place => 'Places',
        EntityKind.story => 'Stories',
      };

  /// Database table name and route segment.
  String get key => name;
}

EntityKind? entityKindFromKey(String key) {
  for (final k in EntityKind.values) {
    if (k.name == key) return k;
  }
  return null;
}

/// One page of content: a personality, a place or a story.
class Entry {
  const Entry({
    required this.kind,
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.sourceRef,
    required this.status,
    this.titleDeva,
    this.extra,
    this.latitude,
    this.longitude,
  });

  final EntityKind kind;
  final int id;
  final String title;
  final String? titleDeva;
  final String summary;
  final String body;
  final String sourceRef;

  /// "draft" or "reviewed".
  final String status;

  /// Optional note shown with a link, e.g. a relationship such as "Disciple".
  final String? extra;

  /// Present for places that have been located on a map.
  final double? latitude;
  final double? longitude;

  bool get isReviewed => status == 'reviewed';

  /// True when this page has usable coordinates for map/radius features.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Route of this entry's page.
  String get path => '/entry/${kind.key}/$id';

  List<String> get paragraphs => body
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  factory Entry.fromMap(EntityKind kind, Map<String, Object?> map) {
    return Entry(
      kind: kind,
      id: map['id'] as int,
      title: map['title'] as String,
      titleDeva: map['title_deva'] as String?,
      summary: map['summary'] as String,
      body: map['body'] as String,
      sourceRef: map['source_ref'] as String,
      status: map['status'] as String,
      extra: map['role'] as String?,
      latitude: _asDouble(map['latitude']),
      longitude: _asDouble(map['longitude']),
    );
  }

  static double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }
}

/// One ordered stop on a guided parikrama route.
class ParikramaStop {
  const ParikramaStop({
    required this.position,
    required this.place,
    this.note,
    this.distanceFromPreviousMeters,
  });

  final int position;
  final Entry place;
  final String? note;

  /// Straight-line distance from the previous stop, when both are mapped.
  final double? distanceFromPreviousMeters;

  bool get hasLegDistance => distanceFromPreviousMeters != null;
}

/// A curated walk made from existing places and stories.
class ParikramaRoute {
  const ParikramaRoute({
    required this.id,
    required this.slug,
    required this.title,
    required this.titleDeva,
    required this.summary,
    required this.body,
    required this.sourceRef,
    required this.status,
    required this.stops,
    required this.stories,
  });

  final int id;
  final String slug;
  final String title;
  final String? titleDeva;
  final String summary;
  final String body;
  final String sourceRef;
  final String status;
  final List<ParikramaStop> stops;
  final List<Entry> stories;

  String get path => '/route/$slug';

  List<String> get paragraphs => body
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  /// Sum of the mapped legs. Stops without coordinates contribute zero.
  double get totalMeters => stops.fold(
        0.0,
        (sum, stop) => sum + (stop.distanceFromPreviousMeters ?? 0),
      );

  int get mappedLegs => stops.where((s) => s.hasLegDistance).length;

  int get unmappedStops =>
      stops.where((s) => !s.place.hasCoordinates).length;

  bool get isReviewed => status == 'reviewed';
}

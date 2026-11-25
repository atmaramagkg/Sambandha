import 'package:sqflite/sqflite.dart';

import '../utils/geo.dart';
import 'models.dart';

/// Reads content from the bundled database.
class Repository {
  Repository(this._db, {this.lang = 'en'});

  final Database _db;

  /// Content language. Only English is bundled for now.
  final String lang;

  Future<List<Entry>> list(EntityKind kind) async {
    final rows = await _db.query(
      kind.key,
      where: 'lang = ?',
      whereArgs: [lang],
      orderBy: 'title COLLATE NOCASE',
    );
    return rows.map((r) => Entry.fromMap(kind, r)).toList();
  }

  Future<Entry?> get(EntityKind kind, int id) async {
    final rows = await _db.query(
      kind.key,
      where: 'id = ? AND lang = ?',
      whereArgs: [id, lang],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Entry.fromMap(kind, rows.first);
  }

  /// Curated guided walks, with straight-line distances between mapped stops.
  Future<List<ParikramaRoute>> listParikramaRoutes() async {
    final rows = await _db.query(
      'route',
      where: 'lang = ?',
      whereArgs: [lang],
      orderBy: 'id',
    );

    final routes = <ParikramaRoute>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final stops = await _parikramaStops(id);
      final storyRows = await _db.rawQuery(
        'SELECT s.* FROM story s '
            'JOIN route_story rs ON rs.story_id = s.id '
            'WHERE rs.route_id = ? AND s.lang = ? ORDER BY s.id',
        [id, lang],
      );
      routes.add(ParikramaRoute(
        id: id,
        slug: row['slug'] as String,
        title: row['title'] as String,
        titleDeva: row['title_deva'] as String?,
        summary: row['summary'] as String,
        body: row['body'] as String,
        sourceRef: row['source_ref'] as String,
        status: row['status'] as String,
        stops: stops,
        stories: storyRows
            .map((r) => Entry.fromMap(EntityKind.story, r))
            .toList(),
      ));
    }
    return routes;
  }

  Future<ParikramaRoute?> getParikramaRoute(String slug) async {
    final routes = await listParikramaRoutes();
    for (final route in routes) {
      if (route.slug == slug) return route;
    }
    return null;
  }

  Future<List<ParikramaStop>> _parikramaStops(int routeId) async {
    final rows = await _db.rawQuery(
      'SELECT rs.position AS position, rs.note AS note, p.* '
          'FROM route_stop rs JOIN place p ON p.id = rs.place_id '
          'WHERE rs.route_id = ? AND p.lang = ? ORDER BY rs.position',
      [routeId, lang],
    );

    final stops = <ParikramaStop>[];
    Entry? previous;
    for (final row in rows) {
      final place = Entry.fromMap(EntityKind.place, row);
      double? leg;
      if (previous != null && previous.hasCoordinates && place.hasCoordinates) {
        leg = haversineMeters(
          previous.latitude!,
          previous.longitude!,
          place.latitude!,
          place.longitude!,
        );
      }
      stops.add(ParikramaStop(
        position: (row['position'] as int?) ?? stops.length + 1,
        place: place,
        note: row['note'] as String?,
        distanceFromPreviousMeters: leg,
      ));
      previous = place;
    }
    return stops;
  }

  /// Entries of [target] kind that are connected to [from] #[id].
  ///
  /// People and places are connected through the stories they share.
  /// People are also connected to each other through explicit relations.
  Future<List<Entry>> related(
    EntityKind from,
    int id,
    EntityKind target,
  ) async {
    final (sql, args) = _relatedQuery(from, id, target);
    if (sql == null) return const [];
    final rows = await _db.rawQuery(sql, args);
    return rows.map((r) => Entry.fromMap(target, r)).toList();
  }

  (String?, List<Object?>) _relatedQuery(
    EntityKind from,
    int id,
    EntityKind target,
  ) {
    switch ((from, target)) {
      case (EntityKind.person, EntityKind.story):
        return (
          'SELECT s.* FROM story s '
              'JOIN story_person sp ON sp.story_id = s.id '
              'WHERE sp.person_id = ? AND s.lang = ? ORDER BY s.title',
          [id, lang]
        );
      case (EntityKind.place, EntityKind.story):
        return (
          'SELECT s.* FROM story s '
              'JOIN story_place sp ON sp.story_id = s.id '
              'WHERE sp.place_id = ? AND s.lang = ? ORDER BY s.title',
          [id, lang]
        );
      case (EntityKind.story, EntityKind.person):
        return (
          'SELECT p.* FROM person p '
              'JOIN story_person sp ON sp.person_id = p.id '
              'WHERE sp.story_id = ? AND p.lang = ? ORDER BY p.title',
          [id, lang]
        );
      case (EntityKind.story, EntityKind.place):
        return (
          'SELECT p.* FROM place p '
              'JOIN story_place sp ON sp.place_id = p.id '
              'WHERE sp.story_id = ? AND p.lang = ? ORDER BY p.title',
          [id, lang]
        );
      case (EntityKind.person, EntityKind.place):
        return (
          'SELECT DISTINCT pl.* FROM place pl '
              'JOIN story_place spl ON spl.place_id = pl.id '
              'JOIN story_person sp ON sp.story_id = spl.story_id '
              'WHERE sp.person_id = ? AND pl.lang = ? ORDER BY pl.title',
          [id, lang]
        );
      case (EntityKind.place, EntityKind.person):
        return (
          'SELECT DISTINCT p.* FROM person p '
              'JOIN story_person sp ON sp.person_id = p.id '
              'JOIN story_place spl ON spl.story_id = sp.story_id '
              'WHERE spl.place_id = ? AND p.lang = ? ORDER BY p.title',
          [id, lang]
        );
      case (EntityKind.person, EntityKind.person):
        return (
          'SELECT p.*, r.role AS role FROM person_relation r '
              'JOIN person p ON p.id = r.other_id '
              'WHERE r.person_id = ? AND r.lang = ? AND p.lang = ? '
              'ORDER BY p.title',
          [id, lang, lang]
        );
      default:
        return (null, const []);
    }
  }

  /// Simple text search over titles, summaries and bodies.
  Future<List<Entry>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final escaped =
        q.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
    final pattern = '%$escaped%';

    final results = <Entry>[];
    for (final kind in EntityKind.values) {
      final rows = await _db.query(
        kind.key,
        where: "lang = ? AND (title LIKE ? ESCAPE '\\' "
            "OR summary LIKE ? ESCAPE '\\' OR body LIKE ? ESCAPE '\\')",
        whereArgs: [lang, pattern, pattern, pattern],
        orderBy: 'title COLLATE NOCASE',
        limit: 30,
      );
      results.addAll(rows.map((r) => Entry.fromMap(kind, r)));
    }
    return results;
  }
}

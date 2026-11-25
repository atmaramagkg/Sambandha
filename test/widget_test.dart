import 'package:flutter_test/flutter_test.dart';
import 'package:vraja_mandala/data/models.dart';

void main() {
  test('entity kind round-trips through its route key', () {
    for (final kind in EntityKind.values) {
      expect(entityKindFromKey(kind.key), kind);
    }
    expect(entityKindFromKey('nonsense'), isNull);
  });

  test('Entry.fromMap reads a database row', () {
    final entry = Entry.fromMap(EntityKind.person, {
      'id': 3,
      'title': 'Dhruva Mahārāja',
      'title_deva': null,
      'summary': 'A young prince.',
      'body': 'First paragraph.\n\nSecond paragraph.',
      'source_ref': 'Śrīmad-Bhāgavatam 4.8–4.12',
      'status': 'draft',
      'role': 'Disciple',
    });
    expect(entry.path, '/entry/person/3');
    expect(entry.paragraphs, ['First paragraph.', 'Second paragraph.']);
    expect(entry.isReviewed, isFalse);
    expect(entry.extra, 'Disciple');
  });

  test('Entry.fromMap reads place coordinates', () {
    final entry = Entry.fromMap(EntityKind.place, {
      'id': 17,
      'title': 'Rādhā-kuṇḍa',
      'summary': 'A sacred lake.',
      'body': 'Paragraph.',
      'source_ref': 'Google Maps saved places export',
      'status': 'draft',
      'latitude': 27.509,
      'longitude': 77.479,
    });
    expect(entry.latitude, 27.509);
    expect(entry.longitude, 77.479);
    expect(entry.hasCoordinates, isTrue);
  });
}

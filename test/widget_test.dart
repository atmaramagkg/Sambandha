import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vraja_mandala/data/models.dart';
import 'package:vraja_mandala/widgets/common.dart';

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
      'source_ref': '',
      'status': 'draft',
      'latitude': 27.509,
      'longitude': 77.479,
    });
    expect(entry.latitude, 27.509);
    expect(entry.longitude, 77.479);
    expect(entry.hasCoordinates, isTrue);
    expect(
      entry.googleMapsUrl,
      'https://www.google.com/maps/search/?api=1&query=27.509,77.479',
    );
    expect(entry.shastraReference, isNull);
  });

  test('only precise shastra references are shown', () {
    expect(
      preciseShastraReference('Śrīmad-Bhāgavatam 4.8–4.12'),
      'Śrīmad-Bhāgavatam 4.8–4.12',
    );
    expect(preciseShastraReference('Bhagavad-gītā 1–2'), 'Bhagavad-gītā 1–2');
    expect(
      preciseShastraReference('Caitanya-caritāmṛta Ādi-līlā 1; 7.18–19'),
      'Caitanya-caritāmṛta Ādi-līlā 1; 7.18–19',
    );
    expect(preciseShastraReference('User-provided notes'), isNull);
    expect(preciseShastraReference(''), isNull);
  });

  testWidgets('BottomSafeArea reserves only the bottom system inset',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.fromLTRB(10, 24, 10, 48),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: BottomSafeArea(
            child: Container(
              key: const Key('safe-content'),
              width: double.infinity,
              height: double.infinity,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(const Key('safe-content')));
    expect(rect.top, 0);
    expect(rect.left, 0);
    expect(rect.right, 400);
    expect(rect.bottom, 800 - 48);
  });
}

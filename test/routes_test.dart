import 'package:flutter_test/flutter_test.dart';
import 'package:vraja_mandala/data/models.dart';
import 'package:vraja_mandala/utils/geo.dart';

Entry _place(int id, String title, double? latitude, double? longitude) {
  return Entry(
    kind: EntityKind.place,
    id: id,
    title: title,
    summary: '',
    body: '',
    sourceRef: '',
    status: 'draft',
    latitude: latitude,
    longitude: longitude,
  );
}

void main() {
  test('a route totals mapped legs and counts stops without coordinates', () {
    final first = _place(1, 'First', 27.0, 77.0);
    final second = _place(2, 'Second', 27.01, 77.0);
    final third = _place(3, 'Third', null, null);
    final leg = haversineMeters(27.0, 77.0, 27.01, 77.0);

    final route = ParikramaRoute(
      id: 1,
      slug: 'test-route',
      title: 'Test route',
      titleDeva: null,
      summary: 'Summary',
      body: 'Paragraph one.\n\nParagraph two.',
      sourceRef: '',
      status: 'draft',
      stories: const [],
      stops: [
        ParikramaStop(position: 1, place: first),
        ParikramaStop(
          position: 2,
          place: second,
          distanceFromPreviousMeters: leg,
        ),
        ParikramaStop(position: 3, place: third),
      ],
    );

    expect(route.path, '/route/test-route');
    expect(route.totalMeters, closeTo(1112, 5));
    expect(route.mappedLegs, 1);
    expect(route.unmappedStops, 1);
    expect(route.paragraphs, ['Paragraph one.', 'Paragraph two.']);
  });
}

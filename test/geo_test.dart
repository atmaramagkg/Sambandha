import 'package:flutter_test/flutter_test.dart';
import 'package:vraja_mandala/utils/geo.dart';

void main() {
  test('haversine distance is zero for the same point', () {
    expect(
      haversineMeters(27.572242, 77.6775, 27.572242, 77.6775),
      0,
    );
  });

  test('haversine distance is symmetric and roughly correct', () {
    final there = haversineMeters(27.572242, 77.6775, 27.582242, 77.6775);
    final back = haversineMeters(27.582242, 77.6775, 27.572242, 77.6775);

    expect(there, back);
    expect(there, closeTo(1112, 5));
  });

  test('formatDistance uses metres then kilometres', () {
    expect(formatDistance(250), '250 m');
    expect(formatDistance(1250), '1.3 km');
    expect(formatDistance(20000), '20.0 km');
  });
}

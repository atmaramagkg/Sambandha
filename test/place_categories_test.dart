import 'package:flutter_test/flutter_test.dart';
import 'package:vraja_mandala/utils/place_categories.dart';

void main() {
  test('place titles map to predictable categories', () {
    final cases = {
      'Rādhā-kuṇḍa': PlaceCategory.water,
      'Madhuvana': PlaceCategory.forests,
      'Bhāṇḍīra-vaṭa': PlaceCategory.trees,
      'Vyomasura\'s cave': PlaceCategory.hills,
      'Akrūra-ghāṭa': PlaceCategory.ghats,
      'Kṛṣṇa-Balarāma Mandira': PlaceCategory.temples,
      'Mathurā': PlaceCategory.towns,
      'Nanda-grāma': PlaceCategory.villages,
      'Dana-gali': PlaceCategory.other,
    };
    for (final entry in cases.entries) {
      expect(categoryForTitle(entry.key), entry.value, reason: entry.key);
    }
  });

  test('parvata is a hill, not a tree', () {
    expect(categoryForTitle('Sakhigiri-parvata'), PlaceCategory.hills);
    expect(categoryForTitle('Pichala-pahadi'), PlaceCategory.hills);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:geoflutterfire2/src/utils.dart';

void main() {
  test('whereNotNull should remove correct elements', () {
    final param = [
      1,
      2,
      null,
      null,
      3,
      null,
      3,
    ];

    final expected = [1, 2, 3, 3];

    final got = param.whereNotNull();
    expect(expected, got);
  });
}

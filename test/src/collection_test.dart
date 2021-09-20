import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';

void main() {
  test('geopointFromMap should return correct point', () {
    const field = 'sub.location';
    final snapData = {
      'var': 1,
      'other': 2,
      'sub': {
        'location': {
          'hash': '1231231',
          'geopoint': const GeoPoint(10, 10),
        }
      },
    };
    final got = GeoFireCollectionRef.geopointFromMap(
      field: field,
      snapData: snapData,
    );
    const expected = GeoPoint(10, 10);
    expect(got, expected);
  });
}

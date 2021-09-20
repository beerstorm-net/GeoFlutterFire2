import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire2/src/collection/base.dart';
import 'package:geoflutterfire2/src/collection/with_converter.dart';

import 'collection/default.dart';
import 'models/point.dart';

class GeoFlutterFire {
  GeoFlutterFire();

  GeoFireCollectionRef collection({
    required Query<Map<String, dynamic>> collectionRef,
  }) {
    return GeoFireCollectionRef(collectionRef);
  }

  GeoFireCollectionWithConverterRef<T> collectionWithConverter<T>({
    required Query<T> collectionRef,
  }) {
    return GeoFireCollectionWithConverterRef<T>(collectionRef);
  }

  GeoFireCollectionRef customCollection({
    required Query<Map<String, dynamic>> collectionRef,
  }) {
    return GeoFireCollectionRef(collectionRef);
  }

  GeoFirePoint point({required double latitude, required double longitude}) {
    return GeoFirePoint(latitude, longitude);
  }
}

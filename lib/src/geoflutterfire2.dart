import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire2/src/base_collection.dart';

import 'collection.dart';
import 'point.dart';

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

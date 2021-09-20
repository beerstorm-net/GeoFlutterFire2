import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'base.dart';
import '../models/point.dart';

class GeoFireCollectionWithConverterRef<T> extends BaseGeoFireCollectionRef<T> {
  GeoFireCollectionWithConverterRef(Query<T> collectionReference)
      : super(collectionReference);

  Stream<List<DocumentSnapshot<T>>> within({
    required GeoFirePoint center,
    required double radius,
    required String field,
    required GeoPoint Function(T) geopointFrom,
    bool strictMode = false,
  }) {
    return protectedWithin(
      center: center,
      radius: radius,
      field: field,
      geopointFrom: geopointFrom,
    );
  }
}

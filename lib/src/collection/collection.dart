import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'collection_with_converter.dart';
import '../models/point.dart';

class GeoFireCollectionRef
    extends GeoFireCollectionWithConverterRef<Map<String, dynamic>> {
  GeoFireCollectionRef(Query<Map<String, dynamic>> collectionReference)
      : super(collectionReference);

  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> within({
    required GeoFirePoint center,
    required double radius,
    required String field,
    bool strictMode = false,
  }) {
    return withinWithConverter(
      center: center,
      radius: radius,
      field: field,
      geopointFrom: (snapData) => geopointFromMap(
        field: field,
        snapData: snapData,
      ),
    );
  }

  @visibleForTesting
  static GeoPoint geopointFromMap({
    required String field,
    required Map<String, dynamic> snapData,
  }) {
    // split and fetch geoPoint from the nested Map
    final fieldList = field.split('.');
    var geoPointField = snapData[fieldList[0]];
    if (fieldList.length > 1) {
      for (int i = 1; i < fieldList.length; i++) {
        geoPointField = geoPointField[fieldList[i]];
      }
    }
    return geoPointField['geopoint'] as GeoPoint;
  }
}

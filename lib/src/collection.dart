import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import 'models/DistanceDocSnapshot.dart';
import 'point.dart';
import 'util.dart';

class GeoFireCollectionRef {
  final Query<Map<String, dynamic>> _collectionReference;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  GeoFireCollectionRef(this._collectionReference) {
    _stream = _createStream(_collectionReference)!.shareReplay(maxSize: 1);
  }

  /// return QuerySnapshot stream
  Stream<QuerySnapshot<Map<String, dynamic>>>? snapshot() {
    return _stream;
  }

  /// return the Document mapped to the [id]
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> data(String id) {
    return _stream!.map((querySnapshot) {
      querySnapshot.docs.where((documentSnapshot) {
        return documentSnapshot.id == id;
      });
      return querySnapshot.docs;
    });
  }

  /// add a document to collection with [data]
  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) {
    try {
      final colRef =
          _collectionReference as CollectionReference<Map<String, dynamic>>;
      return colRef.add(data);
    } catch (e) {
      throw Exception(
          'cannot call add on Query, use collection reference instead');
    }
  }

  /// delete document with [id] from the collection
  Future<void> delete(id) {
    try {
      CollectionReference colRef = _collectionReference as CollectionReference;
      return colRef.doc(id).delete();
    } catch (e) {
      throw Exception(
          'cannot call delete on Query, use collection reference instead');
    }
  }

  /// create or update a document with [id], [merge] defines whether the document should overwrite
  Future<void> setDoc(String id, Object? data, {bool merge = false}) {
    try {
      CollectionReference colRef = _collectionReference as CollectionReference;
      return colRef.doc(id).set(data, SetOptions(merge: merge));
    } catch (e) {
      throw Exception(
          'cannot call set on Query, use collection reference instead');
    }
  }

  /// set a geo point with [latitude] and [longitude] using [field] as the object key to the document with [id]
  Future<void> setPoint(
    String id,
    String field,
    double latitude,
    double longitude,
  ) {
    try {
      CollectionReference colRef = _collectionReference as CollectionReference;
      var point = GeoFirePoint(latitude, longitude).data;
      return colRef.doc(id).set({'$field': point}, SetOptions(merge: true));
    } catch (e) {
      throw Exception(
          'cannot call set on Query, use collection reference instead');
    }
  }

  /// query firestore documents based on geographic [radius] from geoFirePoint [center]
  /// [field] specifies the name of the key in the document
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>> within({
    required GeoFirePoint center,
    required double radius,
    required String field,
    bool strictMode = false,
  }) {
    final precision = Util.setPrecision(radius);
    final centerHash = center.hash.substring(0, precision);
    final area = GeoFirePoint.neighborsOf(hash: centerHash)..add(centerHash);

    final queries = area.map((hash) {
      final tempQuery = _queryPoint(hash, field);
      return _createStream(tempQuery)!.map((querySnapshot) {
        return querySnapshot.docs
            .map((element) => DistanceDocSnapshot(element, null))
            .toList();
      });
    });

    final mergedObservable = mergeObservable(queries);

    final filtered = mergedObservable.map((list) {
      final mappedList = list.map((distanceDocSnapshot) {
        // split and fetch geoPoint from the nested Map
        final fieldList = field.split('.');
        final snapData = distanceDocSnapshot.documentSnapshot.exists
            ? distanceDocSnapshot.documentSnapshot.data()
            : {};
        var geoPointField = snapData?[fieldList[0]] as Map<String, dynamic>;
        //distanceDocSnapshot.documentSnapshot.data()![fieldList[0]];
        if (fieldList.length > 1) {
          for (int i = 1; i < fieldList.length; i++) {
            geoPointField = geoPointField[fieldList[i]];
          }
        }
        final GeoPoint geoPoint = geoPointField['geopoint'];
        distanceDocSnapshot.distance = center.distance(
          lat: geoPoint.latitude,
          lng: geoPoint.longitude,
        );
        return distanceDocSnapshot;
      });

      final filteredList = strictMode
          ? mappedList
              .where((doc) =>
                      doc.distance! <=
                      radius * 1.02 // buffer for edge distances;
                  )
              .toList()
          : mappedList.toList();
      filteredList.sort((a, b) {
        final distA = a.distance!;
        final distB = b.distance!;
        final val = (distA * 1000).toInt() - (distB * 1000).toInt();
        return val;
      });
      return filteredList.map((element) => element.documentSnapshot).toList();
    });
    return filtered.asBroadcastStream();
  }

  Stream<List<DistanceDocSnapshot>> mergeObservable(
    Iterable<Stream<List<DistanceDocSnapshot>>> queries,
  ) {
    final mergedObservable =
        Rx.combineLatest<List<DistanceDocSnapshot>, List<DistanceDocSnapshot>>(
            queries, (originalList) {
      final reducedList = <DistanceDocSnapshot>[];
      for (final t in originalList) {
        reducedList.addAll(t);
      }
      return reducedList;
    });
    return mergedObservable;
  }

  /// INTERNAL FUNCTIONS

  /// construct a query for the [geoHash] and [field]
  Query<Map<String, dynamic>> _queryPoint(String geoHash, String field) {
    final end = '$geoHash~';
    final temp = _collectionReference;
    return temp.orderBy('$field.geohash').startAt([geoHash]).endAt([end]);
  }

  /// create an observable for [ref], [ref] can be [Query] or [CollectionReference]
  Stream<QuerySnapshot<Map<String, dynamic>>>? _createStream(
    Query<Map<String, dynamic>> ref,
  ) {
    return ref.snapshots();
  }
}

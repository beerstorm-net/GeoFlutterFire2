import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import 'models/DistanceDocSnapshot.dart';
import 'point.dart';
import 'util.dart';

class GeoFireCollectionRef {
  Query _collectionReference;
  Stream<QuerySnapshot>? _stream;

  GeoFireCollectionRef(this._collectionReference) {
    // : assert(_collectionReference != null)
    _stream = _createStream(_collectionReference)!.shareReplay(maxSize: 1);
  }

  /// return QuerySnapshot stream
  Stream<QuerySnapshot>? snapshot() {
    return _stream;
  }

  /// return the Document mapped to the [id]
  Stream<List<DocumentSnapshot>> data(String id) {
    return _stream!.map((QuerySnapshot querySnapshot) {
      querySnapshot.docs.where((DocumentSnapshot documentSnapshot) {
        return documentSnapshot.id == id;
      });
      return querySnapshot.docs;
    });
  }

  /// add a document to collection with [data]
  Future<DocumentReference> add(Map<String, dynamic> data) {
    try {
      CollectionReference colRef = _collectionReference as CollectionReference;
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
  Future<void> setDoc(String id, var data, {bool merge = false}) {
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
      String id, String field, double latitude, double longitude) {
    try {
      CollectionReference colRef = _collectionReference as CollectionReference;
      var point = GeoFirePoint(latitude, longitude).data;
      return colRef.doc(id).set({'$field': point}, SetOptions(merge: true));
    } catch (e) {
      throw Exception(
          'cannot call set on Query, use collection reference instead');
    }
  }

  /// Create combined stream listeners for each geo hash around (including) central point.
  /// It creates 9 listeners and the hood.
  ///
  /// Returns [StreamController.stream] instance from rxdart, which is combined stream,
  /// for all 9 listeners.
  Stream<List<DocumentSnapshot>> _buildQueryStream({
    required GeoFirePoint center,
    required double radius,
    required String field,
    bool strictMode = false,
  }) {
    final precision = Util.setPrecision(radius);
    final centerHash = center.hash.substring(0, precision);
    final area = Set<String>.from(
      GeoFirePoint.neighborsOf(hash: centerHash)..add(centerHash),
    ).toList();

    Iterable<Stream<List<DistanceDocSnapshot>>> queries = area.map((hash) {
      final tempQuery = _queryPoint(hash, field);
      return _createStream(tempQuery)!.map((QuerySnapshot querySnapshot) {
        return querySnapshot.docs
            .map((element) => DistanceDocSnapshot(element, null))
            .toList();
      });
    });

    Stream<List<DistanceDocSnapshot>> mergedObservable =
        mergeObservable(queries);

    var filtered = mergedObservable.map((List<DistanceDocSnapshot> list) {
      var mappedList = list.map((DistanceDocSnapshot distanceDocSnapshot) {
        // split and fetch geoPoint from the nested Map
        final fieldList = field.split('.');
        Map<dynamic, dynamic> snapData =
            distanceDocSnapshot.documentSnapshot.exists
                ? distanceDocSnapshot.documentSnapshot.data() as Map
                : Map();
        var geoPointField = snapData[fieldList[0]];
        //distanceDocSnapshot.documentSnapshot.data()![fieldList[0]];
        if (fieldList.length > 1) {
          for (int i = 1; i < fieldList.length; i++) {
            geoPointField = geoPointField[fieldList[i]];
          }
        }
        final GeoPoint geoPoint = geoPointField['geopoint'];
        distanceDocSnapshot.distance =
            center.distance(lat: geoPoint.latitude, lng: geoPoint.longitude);
        return distanceDocSnapshot;
      });

      final filteredList = strictMode
          ? mappedList
              .where((DistanceDocSnapshot doc) =>
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
    return filtered;
  }

  Future<List<DocumentSnapshot>> _buildQueryFuture({
    required GeoFirePoint center,
    required double radius,
    required String field,
    bool strictMode = false,
  }) async {
    final precision = Util.setPrecision(radius);
    final centerHash = center.hash.substring(0, precision);
    final area = Set<String>.from(
      GeoFirePoint.neighborsOf(hash: centerHash)..add(centerHash),
    ).toList();

    Iterable<Future<List<DistanceDocSnapshot>>> queries =
        area.map((hash) async {
      final tempQuery = _queryPoint(hash, field);
      QuerySnapshot snap = await _createFuture(tempQuery);
      return snap.docs.map((e) => DistanceDocSnapshot(e, null)).toList();
    });

    Future<List<DistanceDocSnapshot>> mergedFutures = mergeFutures(queries);
    final snaps = await mergedFutures;
    var mappedList = snaps.map((DistanceDocSnapshot distanceDocSnapshot) {
      // split and fetch geoPoint from the nested Map
      final fieldList = field.split('.');
      Map<dynamic, dynamic> snapData =
          distanceDocSnapshot.documentSnapshot.exists
              ? distanceDocSnapshot.documentSnapshot.data() as Map
              : Map();
      var geoPointField = snapData[fieldList[0]];
      //distanceDocSnapshot.documentSnapshot.data()![fieldList[0]];
      if (fieldList.length > 1) {
        for (int i = 1; i < fieldList.length; i++) {
          geoPointField = geoPointField[fieldList[i]];
        }
      }
      final GeoPoint geoPoint = geoPointField['geopoint'];
      distanceDocSnapshot.distance =
          center.distance(lat: geoPoint.latitude, lng: geoPoint.longitude);
      return distanceDocSnapshot;
    });

    final filteredList = strictMode
        ? mappedList
            .where((DistanceDocSnapshot doc) =>
                    doc.distance! <= radius * 1.02 // buffer for edge distances;
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
  }

  /// Query firestore documents based on geographic [radius] from geoFirePoint [center]
  /// [field] specifies the name of the key in the document
  /// returns merged stream as broadcast stream.
  ///
  /// Returns original stream from the underlying rxdart implementation, which
  /// could be safely cancelled without memory leaks. It's single stream subscription,
  /// so only single listener could be created at a time.
  ///
  /// This works the best if you have central point of listening for locations,
  /// not per widget.
  Stream<List<DocumentSnapshot>> withinAsSingleStreamSubscription({
    required GeoFirePoint center,
    required double radius,
    required String field,
    bool strictMode = false,
  }) {
    return _buildQueryStream(
      center: center,
      radius: radius,
      field: field,
      strictMode: strictMode,
    );
  }

  /// Query firestore documents based on geographic [radius] from geoFirePoint [center]
  /// [field] specifies the name of the key in the document
  /// returns merged stream as broadcast stream.
  ///
  /// !WARNING! This causes memory leaks because under the hood rxdart StreamController
  /// never causes it's subscriptions to be cancelled. So, even you cancel stream
  /// subscription created from this method, under the hood listeners are still working.
  ///
  /// More at: https://github.com/dart-lang/sdk/issues/26686#issuecomment-225346901
  Stream<List<DocumentSnapshot>> within({
    required GeoFirePoint center,
    required double radius,
    required String field,
    bool strictMode = false,
  }) {
    return _buildQueryStream(
      center: center,
      radius: radius,
      field: field,
      strictMode: strictMode,
    ).asBroadcastStream();
  }

  /// Query firestore documents based on geographic [radius] from geoFirePoint [center]
  /// [field] specifies the name of the key in the document
  /// returns merged future.
  Future<List<DocumentSnapshot>> singleWithin({
    required GeoFirePoint center,
    required double radius,
    required String field,
    bool strictMode = false,
  }) {
    return _buildQueryFuture(
        center: center, radius: radius, field: field, strictMode: strictMode);
  }

  Stream<List<DistanceDocSnapshot>> mergeObservable(
      Iterable<Stream<List<DistanceDocSnapshot>>> queries) {
    Stream<List<DistanceDocSnapshot>> mergedObservable = Rx.combineLatest(
        queries, (List<List<DistanceDocSnapshot>> originalList) {
      final reducedList = <DistanceDocSnapshot>[];
      originalList.forEach((t) {
        reducedList.addAll(t);
      });
      return reducedList;
    });
    return mergedObservable;
  }

  Future<List<DistanceDocSnapshot>> mergeFutures(
      Iterable<Future<List<DistanceDocSnapshot>>> queries) async {
    final mergedObservable = await Future.wait(queries);
    final combinedList = mergedObservable.expand((e) => e).toList();
    return combinedList;
  }

  /// INTERNAL FUNCTIONS

  /// construct a query for the [geoHash] and [field]
  Query _queryPoint(String geoHash, String field) {
    final end = '$geoHash~';
    final temp = _collectionReference;
    return temp.orderBy('$field.geohash').startAt([geoHash]).endAt([end]);
  }

  /// create an observable for [ref], [ref] can be [Query] or [CollectionReference]
  Stream<QuerySnapshot>? _createStream(var ref) {
    return ref.snapshots();
  }

  /// create a future for [ref], [ref] can be [Query] or [CollectionReference]
  Future<QuerySnapshot> _createFuture(Query ref) {
    return ref.get();
  }
}

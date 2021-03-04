import 'package:cloud_firestore/cloud_firestore.dart';

import 'collection.dart';
import 'point.dart';

class GeoFlutterFire {
  GeoFlutterFire();

  GeoFireCollectionRef collection({required Query collectionRef}) {
    return GeoFireCollectionRef(collectionRef);
  }

  GeoFirePoint point({required double latitude, required double longitude}) {
    return GeoFirePoint(latitude, longitude);
  }
}

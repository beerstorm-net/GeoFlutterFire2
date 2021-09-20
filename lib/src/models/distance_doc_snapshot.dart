import 'package:cloud_firestore/cloud_firestore.dart';

class DistanceDocSnapshot<T> {
  final DocumentSnapshot<T> documentSnapshot;
  final double distance;

  DistanceDocSnapshot(this.documentSnapshot, this.distance);
}

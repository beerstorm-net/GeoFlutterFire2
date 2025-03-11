import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:rxdart/rxdart.dart';

class StreamTestWidget extends StatefulWidget {
  @override
  _StreamTestWidgetState createState() => _StreamTestWidgetState();
}

class _StreamTestWidgetState extends State<StreamTestWidget> {
  late Stream<List<DocumentSnapshot<Map<String, dynamic>>>> stream;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeoFlutterFire geo = GeoFlutterFire();

  // ignore: close_sinks
  final BehaviorSubject<double> radius = BehaviorSubject<double>.seeded(1.0);

  double _value = 20.0;
  String _label = '';

  @override
  void initState() {
    super.initState();
    final center = geo.point(latitude: 12.960632, longitude: 77.641603);
    stream = radius.switchMap((double rad) {
      var collectionReference = _firestore.collection('locations').withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data() ?? {},
        toFirestore: (value, _) => value,
      );
      // GeoFlutterFire returns a stream of List<DocumentSnapshot<Object?>>.
      // Map each document to the correct type.
      return geo.collection(collectionRef: collectionReference).within(
        center: center,
        radius: rad,
        field: 'position',
        strictMode: true,
      ).map((docs) => docs.map((doc) => doc as DocumentSnapshot<Map<String, dynamic>>).toList());
    });
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    radius.close();
    super.dispose();
  }

  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
              stream: stream,
              builder: (BuildContext context,
                  AsyncSnapshot<List<DocumentSnapshot<Map<String, dynamic>>>> snapshots) {
                if (snapshots.connectionState == ConnectionState.active && snapshots.hasData) {
                  print('data ${snapshots.data}');
                  return Container(
                    height: MediaQuery.of(context).size.height * 2 / 3,
                    child: ListView.builder(
                      itemCount: snapshots.data!.length,
                      itemBuilder: (context, index) {
                        final doc = snapshots.data![index];
                        // Force non-null since we expect documents to contain data.
                        final Map<String, dynamic> data = doc.data()!;
                        print('doc with id ${doc.id} distance ${data['distance']}');
                        // Assume that data['position'] is a Map with a 'geopoint' key.
                        final GeoPoint point = (data['position'] as Map<String, dynamic>)['geopoint'] as GeoPoint;
                        return ListTile(
                          title: Text(
                            doc.id,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${point.latitude}, ${point.longitude}'),
                          trailing: Text(
                            data['documentType'] == DocumentChangeType.added ? 'Added' : 'Modified',
                          ),
                        );
                      },
                    ),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Slider(
              min: 1,
              max: 200,
              divisions: 4,
              value: _value,
              label: _label,
              activeColor: Colors.blue,
              inactiveColor: Colors.blue.withValues(alpha: 0.2),
              onChanged: (double value) => changed(value),
            ),
          ),
        ],
      ),
    );
  }

  void changed(double value) {
    setState(() {
      _value = value;
      print(_value);
      _label = '${_value.toInt()} kms';
    });
    radius.add(value);
  }
}

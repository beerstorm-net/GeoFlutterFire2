import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rxdart/rxdart.dart';

import 'streambuilder_test.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    title: 'Geo Flutter Fire example',
    home: MyApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoogleMapController? _mapController;
  late TextEditingController _latitudeController, _longitudeController;

  // Firestore initialization
  final _firestore = FirebaseFirestore.instance;
  late GeoFlutterFire geo;
  late Stream<List<DocumentSnapshot<Map<String, dynamic>>>> stream;
  final radius = BehaviorSubject<double>.seeded(1.0);
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};

  double _value = 20.0;
  String _label = '';

  @override
  void initState() {
    super.initState();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();

    geo = GeoFlutterFire();
    GeoFirePoint center = geo.point(latitude: 12.960632, longitude: 77.641603);
    stream = radius.switchMap((rad) {
      var collectionReference = _firestore
          .collection('locations')
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (value, _) => value,
      );
      return geo
          .collection(collectionRef: collectionReference)
          .within(
        center: center,
        radius: rad,
        field: 'position',
        strictMode: true,
      )
          .map((docs) => docs
          .map((doc) => doc as DocumentSnapshot<Map<String, dynamic>>)
          .toList());
    });

  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    radius.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('GeoFlutterFire'),
          actions: <Widget>[
            IconButton(
              onPressed: _mapController == null ? null : _showHome,
              icon: Icon(Icons.home),
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (context) => StreamTestWidget()));
          },
          child: Icon(Icons.navigate_next),
        ),
        body: Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Center(
                child: Card(
                  elevation: 4,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: mediaQuery.size.width - 30,
                    height: mediaQuery.size.height * (1 / 3),
                    child: GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(12.960632, 77.641603),
                        zoom: 15.0,
                      ),
                      markers: Set<Marker>.of(markers.values),
                    ),
                  ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Container(
                    width: 100,
                    child: TextField(
                      controller: _latitudeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                          labelText: 'lat',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          )),
                    ),
                  ),
                  Container(
                    width: 100,
                    child: TextField(
                      controller: _longitudeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'lng',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          )),
                    ),
                  ),
                  MaterialButton(
                    color: Colors.blue,
                    onPressed: () {
                      final lat = double.parse(_latitudeController.text);
                      final lng = double.parse(_longitudeController.text);
                      _addPoint(lat, lng);
                    },
                    child: const Text(
                      'ADD',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                ],
              ),
              MaterialButton(
                color: Colors.amber,
                child: const Text(
                  'Add nested',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  final lat = double.parse(_latitudeController.text);
                  final lng = double.parse(_longitudeController.text);
                  _addNestedPoint(lat, lng);
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      _mapController = controller;
      // Start listening after map is created
      stream.listen((List<DocumentSnapshot<Map<String, dynamic>>> documentList) {
        _updateMarkers(documentList);
      });
    });
  }

  void _showHome() {
    _mapController?.animateCamera(CameraUpdate.newCameraPosition(
      const CameraPosition(
        target: LatLng(12.960632, 77.641603),
        zoom: 15.0,
      ),
    ));
  }

  void _addPoint(double lat, double lng) {
    GeoFirePoint geoFirePoint = geo.point(latitude: lat, longitude: lng);
    _firestore.collection('locations').add({
      'name': 'random name',
      'position': geoFirePoint.data,
    }).then((_) {
      print('added ${geoFirePoint.hash} successfully');
    });
  }

  // Example to add GeoFirePoint inside a nested object
  void _addNestedPoint(double lat, double lng) {
    GeoFirePoint geoFirePoint = geo.point(latitude: lat, longitude: lng);
    _firestore.collection('nestedLocations').add({
      'name': 'random name',
      'address': {
        'location': {'position': geoFirePoint.data}
      }
    }).then((_) {
      print('added ${geoFirePoint.hash} successfully');
    });
  }

  void _addMarker(double lat, double lng) {
    final id = MarkerId(lat.toString() + lng.toString());
    final _marker = Marker(
      markerId: id,
      position: LatLng(lat, lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      infoWindow: InfoWindow(title: 'latLng', snippet: '$lat,$lng'),
    );
    setState(() {
      markers[id] = _marker;
    });
  }

  void _updateMarkers(List<DocumentSnapshot<Map<String, dynamic>>> documentList) {
    for (var document in documentList) {
      final data = document.data();
      if (data != null) {
        final positionData = data['position'] as Map<String, dynamic>?;
        if (positionData != null) {
          final geoPoint = positionData['geopoint'] as GeoPoint?;
          if (geoPoint != null) {
            _addMarker(geoPoint.latitude, geoPoint.longitude);
          }
        }
      }
    }
  }

  void changed(double value) {
    setState(() {
      _value = value;
      _label = '${_value.toInt()} kms';
      markers.clear();
    });
    radius.add(value);
  }
}

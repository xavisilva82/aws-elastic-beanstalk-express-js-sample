import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';

class TrackingPage extends StatefulWidget {
  final User user;
  const TrackingPage({Key? key, required this.user}) : super(key: key);

  @override
  _TrackingPageState createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final Location _location = Location();
  StreamSubscription<LocationData>? _sub;
  bool _tracking = false;
  LocationData? _lastLocation;
  double _speed = 0.0;
  late DatabaseReference _dbRef;

  @override
  void initState() {
    super.initState();
    _dbRef = FirebaseDatabase.instance.ref();
  }

  Future<void> _startTracking() async {
    final hasPermission = await _location.requestPermission();
    final serviceEnabled = await _location.serviceEnabled() || await _location.requestService();
    if (hasPermission != PermissionStatus.granted || !serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied or GPS off')),
      );
      return;
    }

    setState(() => _tracking = true);
    final trackingId = DateTime.now().millisecondsSinceEpoch.toString();
    _sub = _location.onLocationChanged.listen((location) {
      setState(() {
        _lastLocation = location;
        _speed = (location.speed ?? 0) * 3.6; // m/s to km/h
      });
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _dbRef.child('cargas/${widget.user.uid}/$trackingId/$timestamp').set({
        'lat': location.latitude,
        'lng': location.longitude,
        'speed': _speed,
        'timestamp': timestamp,
      });
    });
  }

  void _stopTracking() {
    _sub?.cancel();
    setState(() => _tracking = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _tracking ? _stopTracking : _startTracking,
              child: Text(_tracking ? 'Stop Tracking' : 'Start Tracking'),
            ),
            const SizedBox(height: 20),
            if (_lastLocation != null) ...[
              Text('Lat: ${_lastLocation!.latitude}'),
              Text('Lng: ${_lastLocation!.longitude}'),
              Text('Speed: ${_speed.toStringAsFixed(2)} km/h'),
            ] else ...[
              const Text('No location data'),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                _stopTracking();
                Navigator.of(context).pop();
              },
              child: const Text('Finish Tracking'),
            ),
          ],
        ),
      ),
    );
  }
}

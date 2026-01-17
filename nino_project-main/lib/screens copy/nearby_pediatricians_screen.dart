import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/pediatricians_data.dart';
import '../models/pediatrician.dart';
import '../widgets copy/doctor_card.dart';

class NearbyPediatriciansScreen extends StatefulWidget {
  const NearbyPediatriciansScreen({super.key});

  @override
  State<NearbyPediatriciansScreen> createState() =>
      _NearbyPediatriciansScreenState();
}

class _NearbyPediatriciansScreenState extends State<NearbyPediatriciansScreen> {
  LatLng? _user;
  String? _error;

  // nearest 5 results with distance
  List<_Nearest> _nearest = [];

  @override
  void initState() {
    super.initState();
    _loadLocationAndCompute();
  }

  Future<void> _loadLocationAndCompute() async {
    try {
      // 1) Ensure location services are ON
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error = 'Location services are off');
        return;
      }

      // 2) Permissions
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission denied');
        return;
      }

      // 3) Get current position
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final user = LatLng(pos.latitude, pos.longitude);

      // 4) Compute nearest 5 from local dataset
      final all = PediatriciansData.all;
      final nearest = all.map((p) {
        final meters = Geolocator.distanceBetween(
          user.latitude,
          user.longitude,
          p.latitude,
          p.longitude,
        );
        final km = meters / 1000.0;
        return _Nearest(p, km);
      }).toList();

      nearest.sort((a, b) => a.km.compareTo(b.km));

      setState(() {
        _user = user;
        _nearest = nearest.take(5).toList();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Pediatricians'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocationAndCompute,
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : user == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    SizedBox(
                      height: 280,
                      width: double.infinity,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: user,
                          initialZoom: 14,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.nino_peds_map',
                          ),
                          MarkerLayer(
                            markers: [
                              // user marker
                              Marker(
                                point: user,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.my_location,
                                  size: 34,
                                ),
                              ),

                              // pediatrician markers
                              ..._nearest.map((n) {
                                final p = n.p;
                                return Marker(
                                  point: LatLng(p.latitude, p.longitude),
                                  width: 44,
                                  height: 44,
                                  child: const Icon(
                                    Icons.location_on,
                                    size: 38,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _nearest.length,
                        itemBuilder: (context, i) {
                          return DoctorCard(
                            pediatrician: _nearest[i].p,
                            distanceKm: _nearest[i].km,
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Nearest {
  final Pediatrician p;
  final double km;
  _Nearest(this.p, this.km);
}

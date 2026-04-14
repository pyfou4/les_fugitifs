import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapWebView extends StatefulWidget {
  const MapWebView({super.key});

  @override
  State<MapWebView> createState() => _MapWebViewState();
}

class _MapWebViewState extends State<MapWebView> {
  final MapController _mapController = MapController();
  LatLng? _current;
  bool _loading = false;
  String? _error;

  Future<void> _determinePositionAndCenter() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Service de localisation désactivé';
          _loading = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _error = 'Permission de localisation refusée';
          _loading = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('La récupération a expiré');
        },
      );

      final latlng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _current = latlng;
        _loading = false;
      });

      _mapController.move(latlng, 15.0);
    } on TimeoutException {
      setState(() {
        _error = "Délai d'attente dépassé pour obtenir la position";
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur localisation: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackCenter = _current ?? const LatLng(48.8566, 2.3522);

    return Scaffold(
      appBar: AppBar(title: const Text('Carte')),
      body: Stack(
        children: [
          GestureDetector(
            onTap: _determinePositionAndCenter,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: fallbackCenter,
                initialZoom: 5.0,
                minZoom: 2.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.intenebrisuno',
                ),
                if (_current != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _current!,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null && !_loading)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton(
              heroTag: 'locBtn',
              onPressed: _determinePositionAndCenter,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
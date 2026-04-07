import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/place_node.dart';

class MapScreen extends StatefulWidget {
  final VoidCallback onBack;
  final List<PlaceNode> places;
  final ValueChanged<String> onPlaceVisited;
  final ValueChanged<PlaceNode> onOpenPlaceMedia;
  final ValueChanged<PlaceNode>? onPlaceSelected;

  const MapScreen({
    super.key,
    required this.onBack,
    required this.places,
    required this.onPlaceVisited,
    required this.onOpenPlaceMedia,
    this.onPlaceSelected,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class RouteInfo {
  final int distanceMeters;
  final String durationText;
  final List<LatLng> points;

  const RouteInfo({
    required this.distanceMeters,
    required this.durationText,
    required this.points,
  });
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  StreamSubscription<Position>? _positionSubscription;
  Marker? _userMarker;

  bool _locationPermissionGranted = false;
  bool _isLoadingLocation = true;
  bool _hasCenteredOnUser = false;
  bool _isListening = false;
  bool _isLoadingRoute = false;

  String? _locationError;
  String _lastWords = '';

  bool _showHeardBanner = false;
  bool _showRouteBanner = false;

  PlaceNode? _selectedPlace;
  RouteInfo? _currentRoute;

  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(10.3910, -75.4794),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâäãå]'), 'a')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôöõ]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll('œ', 'oe')
        .replaceAll('æ', 'ae')
        .replaceAll("'", ' ')
        .replaceAll('’', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _clearBothTextBanners() {
    setState(() {
      _showHeardBanner = false;
      _showRouteBanner = false;
    });
  }

  void _clearRouteCompletely() {
    setState(() {
      _currentRoute = null;
      _showRouteBanner = false;
    });
  }

  void _setSelectedPlace(PlaceNode place) {
    setState(() {
      _selectedPlace = place;
    });
    widget.onPlaceSelected?.call(place);
  }

  Future<void> _initLocationTracking() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final permission = await Permission.locationWhenInUse.request();

      if (!permission.isGranted) {
        if (!mounted) return;
        setState(() {
          _locationPermissionGranted = false;
          _isLoadingLocation = false;
          _locationError = 'Permission de localisation refusée.';
        });
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationPermissionGranted = false;
          _isLoadingLocation = false;
          _locationError = 'Le GPS du téléphone est désactivé.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _locationPermissionGranted = true;
      });

      Position? initialPosition;

      try {
        initialPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        initialPosition = await Geolocator.getLastKnownPosition();
      }

      if (initialPosition != null) {
        await _handleNewPosition(initialPosition, shouldCenter: true);
      }

      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
        (position) async {
          await _handleNewPosition(
            position,
            shouldCenter: !_hasCenteredOnUser,
          );
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _locationError = 'Erreur GPS: $error';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'Erreur de localisation: $e';
      });
    }
  }

  Future<void> _handleNewPosition(
    Position position, {
    required bool shouldCenter,
  }) async {
    final userLatLng = LatLng(position.latitude, position.longitude);

    if (!mounted) return;

    setState(() {
      _userMarker = Marker(
        markerId: const MarkerId('user_marker'),
        position: userLatLng,
        infoWindow: const InfoWindow(title: 'Ma position'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
      );
    });

    if (shouldCenter) {
      await _moveCameraTo(userLatLng, zoom: 16);
      _hasCenteredOnUser = true;
    }

    _checkProximity(userLatLng);
  }

  Future<void> _moveCameraTo(
    LatLng target, {
    double zoom = 16,
  }) async {
    if (!_controller.isCompleted) return;

    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(target, zoom),
    );
  }

  Future<void> _fitCameraToBounds({
    required List<LatLng> routePoints,
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (!_controller.isCompleted) return;

    final allPoints = <LatLng>[
      origin,
      destination,
      ...routePoints,
    ];

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latPadding = (maxLat - minLat).abs() * 0.25;
    final lngPadding = (maxLng - minLng).abs() * 0.25;

    minLat -= latPadding == 0 ? 0.002 : latPadding;
    maxLat += latPadding == 0 ? 0.002 : latPadding;
    minLng -= lngPadding == 0 ? 0.002 : lngPadding;
    maxLng += lngPadding == 0 ? 0.002 : lngPadding;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    final controller = await _controller.future;

    await Future.delayed(const Duration(milliseconds: 300));
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 160),
    );

    await Future.delayed(const Duration(milliseconds: 250));
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 160),
    );
  }

  void _checkProximity(LatLng userPos) {
    for (final place in widget.places.where((p) => !p.isVisited)) {
      final distance = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        place.lat,
        place.lng,
      );

      if (_selectedPlace?.id == place.id && distance < 20) {
        widget.onPlaceVisited(place.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lieu visité : ${place.name}'),
          ),
        );

        widget.onOpenPlaceMedia(place);

        setState(() {
          _selectedPlace = null;
          _currentRoute = null;
          _lastWords = '';
          _showHeardBanner = false;
          _showRouteBanner = false;
        });
      }
    }
  }

  Future<void> _recenterOnUser() async {
    if (_userMarker == null) return;
    await _moveCameraTo(_userMarker!.position, zoom: 16);
  }

  Future<bool> _requestMicrophonePermission() async {
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    final hasMic = await _requestMicrophonePermission();
    if (!hasMic) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission microphone refusée')),
      );
      return;
    }

    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vocale: $error')),
        );
      },
    );

    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconnaissance vocale indisponible')),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _lastWords = '';
      _showHeardBanner = false;
    });

    await _speechToText.listen(
      localeId: 'fr_FR',
      listenMode: stt.ListenMode.confirmation,
      onResult: (result) async {
        if (!mounted) return;

        setState(() {
          _lastWords = result.recognizedWords;
          _showHeardBanner = _lastWords.trim().isNotEmpty;
        });

        if (result.finalResult) {
          await _speechToText.stop();
          if (!mounted) return;
          setState(() {
            _isListening = false;
          });
          await _handleVoiceCommand(_lastWords);
        }
      },
    );
  }

  Future<void> _handleVoiceCommand(String spokenText) async {
    final normalized = _normalize(spokenText);

    if (normalized.isEmpty) return;

    PlaceNode? matchedPlace;

    for (final place in widget.places) {
      for (final keyword in place.keywords) {
        final cleanKeyword = _normalize(keyword);

        if (cleanKeyword.isNotEmpty && normalized.contains(cleanKeyword)) {
          matchedPlace = place;
          break;
        }
      }
      if (matchedPlace != null) break;
    }

    if (matchedPlace == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun lieu reconnu dans : "$spokenText"')),
      );
      return;
    }

    _setSelectedPlace(matchedPlace);

    setState(() {
      _currentRoute = null;
      _showRouteBanner = false;
      _showHeardBanner = true;
    });

    await _moveCameraTo(matchedPlace.latLng, zoom: 17);

    if (!mounted) return;

    final wantsRoute = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(matchedPlace!.name),
          content: Text(
            'Lieu reconnu à partir de : "$spokenText"\n\nVoulez-vous calculer un itinéraire dans l’application ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Non'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Oui'),
            ),
          ],
        );
      },
    );

    if (wantsRoute == true) {
      await _computeInAppRoute(matchedPlace);
    }
  }

  Future<void> _computeInAppRoute(PlaceNode place) async {
    if (_userMarker == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Position utilisateur indisponible')),
      );
      return;
    }

    _setSelectedPlace(place);

    setState(() {
      _isLoadingRoute = true;
      _currentRoute = null;
      _showRouteBanner = false;
    });

    try {
      final uri = Uri.parse(
        'https://routes.googleapis.com/directions/v2:computeRoutes',
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': kGoogleMapsApiKey,
          'X-Goog-FieldMask':
              'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
        },
        body: jsonEncode({
          'origin': {
            'location': {
              'latLng': {
                'latitude': _userMarker!.position.latitude,
                'longitude': _userMarker!.position.longitude,
              }
            }
          },
          'destination': {
            'location': {
              'latLng': {
                'latitude': place.lat,
                'longitude': place.lng,
              }
            }
          },
          'travelMode': 'WALK',
          'languageCode': 'fr-FR',
          'units': 'METRIC',
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Erreur Routes API ${response.statusCode}: ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;

      if (routes == null || routes.isEmpty) {
        throw Exception('Aucun itinéraire retourné');
      }

      final route = routes.first as Map<String, dynamic>;
      final encodedPolyline =
          ((route['polyline'] as Map<String, dynamic>)['encodedPolyline'])
              as String;
      final distanceMeters = (route['distanceMeters'] as num).toInt();
      final durationText = route['duration'] as String;

      final decodedPoints = _decodePolyline(encodedPolyline);

      setState(() {
        _currentRoute = RouteInfo(
          distanceMeters: distanceMeters,
          durationText: durationText,
          points: decodedPoints,
        );
        _showRouteBanner = true;
      });

      await _fitCameraToBounds(
        routePoints: decodedPoints,
        origin: _userMarker!.position,
        destination: place.latLng,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de calculer l’itinéraire : $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      result = 0;
      shift = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(
        LatLng(
          lat / 1e5,
          lng / 1e5,
        ),
      );
    }

    return points;
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_userMarker != null) {
      markers.add(_userMarker!);
    }

    for (final place in widget.places.where((p) => p.isVisited)) {
      markers.add(
        Marker(
          markerId: MarkerId(place.id),
          position: place.latLng,
          infoWindow: InfoWindow(
            title: place.name,
            snippet: 'Visité',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          onTap: () {
            _setSelectedPlace(place);
            widget.onOpenPlaceMedia(place);
          },
        ),
      );
    }

    if (_selectedPlace != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected_place_marker'),
          position: _selectedPlace!.latLng,
          infoWindow: InfoWindow(title: _selectedPlace!.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet,
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    if (_currentRoute == null || _currentRoute!.points.isEmpty) {
      return {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('active_route'),
        points: _currentRoute!.points,
        width: 6,
        color: Colors.blue,
        consumeTapEvents: true,
        onTap: _clearRouteCompletely,
      ),
    };
  }

  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '$meters m';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatDuration(String raw) {
    final cleaned = raw.replaceAll('s', '');
    final totalSeconds = int.tryParse(cleaned);
    if (totalSeconds == null) return raw;

    final minutes = totalSeconds ~/ 60;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0) {
      return '${hours}h ${remainingMinutes}min';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _fallbackCamera,
            myLocationEnabled: _locationPermissionGranted,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            padding: EdgeInsets.only(
              top: 90,
              bottom: 110,
              right: safePadding.right + 16,
              left: safePadding.left + 16,
            ),
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            onMapCreated: (controller) {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
              }

              if (_userMarker != null && !_hasCenteredOnUser) {
                _moveCameraTo(_userMarker!.position, zoom: 16);
                _hasCenteredOnUser = true;
              }
            },
          ),
          if (_isLoadingLocation || _isLoadingRoute)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (_locationError != null)
            Positioned(
              left: safePadding.left + 16,
              right: 16,
              bottom: 24,
              child: Card(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _locationError!,
                    style: const TextStyle(color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          Positioned(
            right: safePadding.right + 16,
            bottom: 88,
            child: FloatingActionButton(
              heroTag: 'map_voice_fab',
              backgroundColor: _isListening ? Colors.red : null,
              onPressed: _startListening,
              child: Icon(_isListening ? Icons.mic : Icons.mic_none),
            ),
          ),
          Positioned(
            right: safePadding.right + 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'map_recenter_fab',
              onPressed: _recenterOnUser,
              child: const Icon(Icons.my_location),
            ),
          ),
          if (_showHeardBanner && _lastWords.isNotEmpty)
            Positioned(
              left: safePadding.left + 16,
              right: safePadding.right + 90,
              bottom: 16,
              child: GestureDetector(
                onTap: _clearBothTextBanners,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      _isListening
                          ? 'Écoute : $_lastWords'
                          : 'Entendu : $_lastWords',
                    ),
                  ),
                ),
              ),
            ),
          if (_currentRoute != null && _showRouteBanner)
            Positioned(
              left: safePadding.left + 16,
              right: safePadding.right + 90,
              top: 16,
              child: GestureDetector(
                onTap: _clearBothTextBanners,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Itinéraire : ${_formatDistance(_currentRoute!.distanceMeters)} • ${_formatDuration(_currentRoute!.durationText)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _speechToText.stop();
    super.dispose();
  }
}

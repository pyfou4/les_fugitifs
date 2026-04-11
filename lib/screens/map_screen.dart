import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/place_node.dart';
import 'incoming_call_screen.dart';
import 'final_quiz_test_screen.dart';

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  String? _currentSessionId;
  String? _currentSiteId;
  Map<String, int> _placeOccupancy = const <String, int>{};
  Timer? _heardBannerTimer;
  Timer? _incomingCallRecallTimer;

  static const CameraPosition _fallbackCamera = CameraPosition(
    target: LatLng(10.3910, -75.4794),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _bootstrapMapState();
  }

  Future<void> _bootstrapMapState() async {
    await _ensureSessionContextLoaded();
    await _refreshPlaceOccupancy();
    await _initLocationTracking();
  }

  Future<void> _ensureSessionContextLoaded() async {
    if ((_currentSessionId ?? '').trim().isNotEmpty &&
        (_currentSiteId ?? '').trim().isNotEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedSessionId = (prefs.getString('active_game_session_id') ??
            prefs.getString('game_session_id') ??
            '')
        .trim();

    if (storedSessionId.isEmpty) {
      return;
    }

    final sessionSnapshot =
        await _firestore.collection('gameSessions').doc(storedSessionId).get();
    final sessionData = sessionSnapshot.data();
    final siteId = (sessionData?['siteId'] ?? '').toString().trim();

    _currentSessionId = storedSessionId;
    _currentSiteId = siteId.isEmpty ? null : siteId;
  }

  DateTime? _readUtcDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toUtc();
  }

  Future<void> _refreshPlaceOccupancy() async {
    await _ensureSessionContextLoaded();

    final siteId = (_currentSiteId ?? '').trim();
    if (siteId.isEmpty) {
      return;
    }

    final snapshot = await _firestore
        .collection('gameSessions')
        .where('siteId', isEqualTo: siteId)
        .get();

    final now = DateTime.now().toUtc();
    final counts = <String, int>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status.isNotEmpty && status != 'active') {
        continue;
      }

      final occupiedIds = <String>{};

      final currentNodeId = (data['currentNodeId'] ?? '').toString().trim();
      if (currentNodeId.isNotEmpty) {
        occupiedIds.add(currentNodeId);
      }

      final targetPlaceId = (data['mapTargetPlaceId'] ?? '').toString().trim();
      final targetUpdatedAt = _readUtcDate(data['mapTargetUpdatedAt']);
      final targetIsFresh = targetPlaceId.isNotEmpty &&
          targetUpdatedAt != null &&
          now.difference(targetUpdatedAt) <= const Duration(minutes: 15);

      if (targetIsFresh) {
        occupiedIds.add(targetPlaceId);
      }

      for (final placeId in occupiedIds) {
        counts.update(placeId, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    if (!mounted) {
      _placeOccupancy = counts;
      return;
    }

    setState(() {
      _placeOccupancy = counts;
    });
  }

  Future<void> _updateMapTargetPlace(String? placeId) async {
    await _ensureSessionContextLoaded();

    final sessionId = (_currentSessionId ?? '').trim();
    if (sessionId.isEmpty) {
      return;
    }

    await _firestore.collection('gameSessions').doc(sessionId).set({
      'mapTargetPlaceId': (placeId ?? '').trim(),
      'mapTargetUpdatedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  bool _isPivot(PlaceNode place) {
    switch (place.id) {
      case 'A0':
      case 'B0':
      case 'C0':
      case 'D0':
        return true;
      default:
        return false;
    }
  }

  bool _hasVisited(String placeId) {
    return widget.places.any((place) => place.id == placeId && place.isVisited);
  }

  bool _allVisited(Iterable<String> placeIds) {
    for (final placeId in placeIds) {
      if (!_hasVisited(placeId)) {
        return false;
      }
    }
    return true;
  }

  bool _isPlaceAccessible(PlaceNode place) {
    final id = place.id.trim().toUpperCase();

    if (id == 'A0') {
      return true;
    }

    if (RegExp(r'^A[1-9]$').hasMatch(id)) {
      if (!_hasVisited('A0')) {
        return false;
      }
    }

    if (id == 'B0') {
      if (!_allVisited(const <String>['A1', 'A2', 'A3', 'A4', 'A5', 'A6'])) {
        return false;
      }
    }

    if (RegExp(r'^B[1-9]$').hasMatch(id)) {
      if (!_hasVisited('B0')) {
        return false;
      }
    }

    if (id == 'C0') {
      if (!_allVisited(const <String>['B1', 'B2', 'B3', 'B4', 'B5'])) {
        return false;
      }
    }

    if (RegExp(r'^C[1-9]$').hasMatch(id)) {
      if (!_hasVisited('C0')) {
        return false;
      }
    }

    if (id == 'D0') {
      if (!_allVisited(const <String>['C1', 'C2', 'C3', 'C4'])) {
        return false;
      }
    }

    for (final requiredId in place.requiresAllVisited) {
      if (!_hasVisited(requiredId)) {
        return false;
      }
    }

    if (place.requiresAnyVisited.isNotEmpty &&
        !place.requiresAnyVisited.any(_hasVisited)) {
      return false;
    }

    return true;
  }

  bool _hasUnsaturatedAlternative() {
    for (final place in widget.places) {
      if (_isPivot(place)) {
        continue;
      }
      if (!_isPlaceAccessible(place)) {
        continue;
      }
      if ((_placeOccupancy[place.id] ?? 0) < 3) {
        return true;
      }
    }
    return false;
  }

  bool _isPlaceSaturated(PlaceNode place) {
    if (_isPivot(place)) {
      return false;
    }

    final teamsOnPlace = _placeOccupancy[place.id] ?? 0;
    if (teamsOnPlace < 3) {
      return false;
    }

    return _hasUnsaturatedAlternative();
  }

  void _showTemporarilyClosedMessage() {
    unawaited(HapticFeedback.vibrate());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Le site ne semble pas accessible pour le moment. Mieux vaut revenir plus tard.',
        ),
      ),
    );
  }

  double? _distanceToSelectedPlaceMeters() {
    final place = _selectedPlace;
    final userMarker = _userMarker;
    if (place == null || userMarker == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      userMarker.position.latitude,
      userMarker.position.longitude,
      place.lat,
      place.lng,
    );
  }

  String _immersiveBannerTitle() {
    final place = _selectedPlace;
    if (place == null) {
      return 'Repérage terrain';
    }
    return '📍 ${place.name}';
  }

  String _immersiveBannerBody() {
    final place = _selectedPlace;
    if (place == null) {
      return 'Analyse la zone, puis active une piste quand un lieu devient pertinent.';
    }

    final distance = _distanceToSelectedPlaceMeters();

    if (distance != null && distance < 20) {
      return 'Zone atteinte. Regarde autour de toi, quelque chose peut s’activer ici.';
    }

    if (_currentRoute != null) {
      return 'Dirige-toi vers la zone. Un détail du dossier semble mener ici.';
    }

    return 'Une piste mérite d’être vérifiée ici.';
  }

  String? _immersiveBannerMeta() {
    final distance = _distanceToSelectedPlaceMeters();
    if (_currentRoute != null) {
      return 'Itinéraire • ${_formatDistance(_currentRoute!.distanceMeters)} • ${_formatDuration(_currentRoute!.durationText)}';
    }
    if (distance != null) {
      final rounded = distance.round();
      if (rounded > 0) {
        return 'Repérage • environ ${_formatDistance(rounded)}';
      }
    }
    return null;
  }

  bool get _shouldShowImmersiveBanner =>
      _selectedPlace != null || (_currentRoute != null && _showRouteBanner);

  void _scheduleHeardBannerAutoHide() {
    _heardBannerTimer?.cancel();
    _incomingCallRecallTimer?.cancel();
    if (!_showHeardBanner) {
      return;
    }
    _heardBannerTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showHeardBanner = false;
      });
    });
  }

  void _dismissHeardBanner() {
    _heardBannerTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _showHeardBanner = false;
    });
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
    _heardBannerTimer?.cancel();
    setState(() {
      _showHeardBanner = false;
      _showRouteBanner = false;
    });
  }

  void _clearImmersiveSelection() {
    _heardBannerTimer?.cancel();
    setState(() {
      _selectedPlace = null;
      _currentRoute = null;
      _showRouteBanner = false;
      _showHeardBanner = false;
    });
    unawaited(_updateMapTargetPlace(null));
    unawaited(_refreshPlaceOccupancy());
  }

  void _clearRouteCompletely() {
    setState(() {
      _currentRoute = null;
      _showRouteBanner = false;
    });
    unawaited(_updateMapTargetPlace(null));
    unawaited(_refreshPlaceOccupancy());
  }

  void _setSelectedPlace(PlaceNode place) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _selectedPlace = place;
    });
    widget.onPlaceSelected?.call(place);
    unawaited(_updateMapTargetPlace(place.id));
    unawaited(_refreshPlaceOccupancy());
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
        unawaited(HapticFeedback.mediumImpact());
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
        unawaited(_updateMapTargetPlace(null));
        unawaited(_refreshPlaceOccupancy());
      }
    }
  }

  Future<void> _openIncomingCallFlow() async {
    _incomingCallRecallTimer?.cancel();
    await _ensureSessionContextLoaded();

    final sessionId = (_currentSessionId ?? '').trim();
    if (sessionId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session introuvable pour l’appel entrant.'),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          sessionId: sessionId,
          onAccepted: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const FinalQuizTestScreen(),
              ),
            );
          },
          onRejected: _scheduleIncomingCallRecall,
        ),
      ),
    );
  }

  void _scheduleIncomingCallRecall() {
    _incomingCallRecallTimer?.cancel();
    _incomingCallRecallTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      _openIncomingCallFlow();
    });
  }

  Future<void> _launchIncomingCallTest() async {
    await _openIncomingCallFlow();
  }

  Future<void> _recenterOnUser() async {
    if (_userMarker == null) return;
    unawaited(HapticFeedback.selectionClick());
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

    await _refreshPlaceOccupancy();

    PlaceNode? matchedPlace;

    for (final place in widget.places.where(_isPlaceAccessible)) {
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

    if (_isPlaceSaturated(matchedPlace)) {
      _showTemporarilyClosedMessage();
      return;
    }

    unawaited(HapticFeedback.lightImpact());
    _setSelectedPlace(matchedPlace);

    setState(() {
      _currentRoute = null;
      _showRouteBanner = false;
      _showHeardBanner = true;
    });
    _scheduleHeardBannerAutoHide();

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
    await _refreshPlaceOccupancy();

    if (!_isPlaceAccessible(place)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun itinéraire exploitable pour le moment.')),
      );
      return;
    }

    if (_isPlaceSaturated(place)) {
      _showTemporarilyClosedMessage();
      return;
    }

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
          'https://europe-west1-les-fugitifs.cloudfunctions.net/computeRoute'
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'originLat': _userMarker!.position.latitude,
          'originLng': _userMarker!.position.longitude,
          'destinationLat': place.lat,
          'destinationLng': place.lng,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Erreur Cloud Function ${response.statusCode}: ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final encodedPolyline = data['encodedPolyline'] as String;
      final distanceMeters = (data['distanceMeters'] as num).toInt();
      final durationText = data['duration'] as String;

      final decodedPoints = _decodePolyline(encodedPolyline);

      unawaited(HapticFeedback.selectionClick());
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

  Future<void> _handleBack() async {
    await _updateMapTargetPlace(null);
    if (!mounted) return;
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;

    return Scaffold(
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
              top: safePadding.top + 100,
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
            top: safePadding.top + 12,
            left: safePadding.left + 16,
            child: _MapActionButton(
              heroTag: 'map_back_fab',
              icon: Icons.arrow_back_rounded,
              onTap: _handleBack,
              size: 52,
              backgroundColor: const Color(0xDD111111),
            ),
          ),
          Positioned(
            right: safePadding.right + 16,
            bottom: 92,
            child: _MapActionButton(
              heroTag: 'map_voice_fab',
              icon: _isListening ? Icons.mic : Icons.mic_none_rounded,
              onTap: _startListening,
              backgroundColor: _isListening
                  ? const Color(0xFF8B2C2C)
                  : const Color(0xDD1A2230),
            ),
          ),
          Positioned(
            right: safePadding.right + 16,
            bottom: 16,
            child: _MapActionButton(
              heroTag: 'map_recenter_fab',
              icon: Icons.my_location_rounded,
              onTap: _recenterOnUser,
              size: 58,
              backgroundColor: const Color(0xDD1A2230),
            ),
          ),
          Positioned(
            left: safePadding.left + 16,
            right: safePadding.right + 140,
            bottom: 16,
            child: IgnorePointer(
              ignoring: !_showHeardBanner || _lastWords.isEmpty,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: (_showHeardBanner && _lastWords.isNotEmpty)
                    ? Offset.zero
                    : const Offset(0, 0.24),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: (_showHeardBanner && _lastWords.isNotEmpty) ? 1 : 0,
                  child: GestureDetector(
                    onTap: _dismissHeardBanner,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xD910161F),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF2C3A4D)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          _isListening
                              ? 'Écoute : $_lastWords'
                              : 'Entendu : $_lastWords',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: safePadding.left + 16,
            right: safePadding.right + 120,
            top: safePadding.top + 12,
            child: IgnorePointer(
              ignoring: !_shouldShowImmersiveBanner,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                offset: _shouldShowImmersiveBanner
                    ? Offset.zero
                    : const Offset(0, -0.08),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _shouldShowImmersiveBanner ? 1 : 0,
                  child: _ImmersiveMapBanner(
                    title: _immersiveBannerTitle(),
                    body: _immersiveBannerBody(),
                    meta: _immersiveBannerMeta(),
                    onTap: _clearImmersiveSelection,
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
    _heardBannerTimer?.cancel();
    unawaited(_updateMapTargetPlace(null));
    _positionSubscription?.cancel();
    _speechToText.stop();
    super.dispose();
  }
}

class _ImmersiveMapBanner extends StatelessWidget {
  final String title;
  final String body;
  final String? meta;
  final VoidCallback onTap;

  const _ImmersiveMapBanner({
    required this.title,
    required this.body,
    required this.meta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xA6111111),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2B3746)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF4F1EB),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              if ((meta ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  meta!,
                  style: const TextStyle(
                    color: Color(0xFFA9B5C4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final Future<void> Function() onTap;
  final Color backgroundColor;
  final double size;

  const _MapActionButton({
    required this.heroTag,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FloatingActionButton(
        heroTag: heroTag,
        elevation: 8,
        highlightElevation: 10,
        backgroundColor: backgroundColor,
        foregroundColor: const Color(0xFFF7F7F7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: Color(0xFF344154),
            width: 1.1,
          ),
        ),
        onPressed: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: Icon(icon, size: size >= 64 ? 30 : 26),
      ),
    );
  }
}

import 'package:google_maps_flutter/google_maps_flutter.dart';

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
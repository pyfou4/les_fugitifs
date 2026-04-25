import 'dart:math';

class Place {
  final String id;
  final double lat;
  final double lng;

  Place({
    required this.id,
    required this.lat,
    required this.lng,
  });
}

class RouteAnalysisResult {
  final double minDistance;
  final double maxDistance;
  final double avgDistance;

  final double minSegment;
  final double maxSegment;
  final double avgSegment;
  final double medianSegment;

  final int totalRoutes;

  RouteAnalysisResult({
    required this.minDistance,
    required this.maxDistance,
    required this.avgDistance,
    required this.minSegment,
    required this.maxSegment,
    required this.avgSegment,
    required this.medianSegment,
    required this.totalRoutes,
  });
}

class SiteRouteAnalyzer {
  static RouteAnalysisResult analyze(List<Place> places) {
    // --- 1. CLASSIFICATION ---
    Place? A0;
    Place? B0;
    Place? C0;
    Place? D0;

    final List<Place> A = [];
    final List<Place> B = [];
    final List<Place> C = [];

    for (final p in places) {
      if (p.id == 'A0') A0 = p;
      else if (p.id == 'B0') B0 = p;
      else if (p.id == 'C0') C0 = p;
      else if (p.id == 'D0') D0 = p;
      else if (p.id.startsWith('A')) A.add(p);
      else if (p.id.startsWith('B')) B.add(p);
      else if (p.id.startsWith('C')) C.add(p);
    }

    if (A0 == null || B0 == null || C0 == null || D0 == null) {
      throw Exception('Points pivots manquants (A0, B0, C0, D0)');
    }

    if (A.length < 2 || B.length < 2 || C.length < 1) {
      throw Exception('Pas assez de postes annexes pour calculer');
    }

    // --- 2. GÉNÉRATION DES COMBINAISONS ---
    final aCombos = _combinations(A, 2);
    final bCombos = _combinations(B, 2);
    final cCombos = C.map((c) => [c]).toList();

    final List<double> routeDistances = [];
    final List<double> segmentDistances = [];

    // --- 3. CONSTRUCTION DES PARCOURS ---
    for (final aPair in aCombos) {
      for (final bPair in bCombos) {
        for (final cSingle in cCombos) {
          final route = [
            A0,
            aPair[0],
            aPair[1],
            B0,
            bPair[0],
            bPair[1],
            C0,
            cSingle[0],
            D0,
          ];

          double total = 0;

          for (int i = 0; i < route.length - 1; i++) {
            final d = _distance(route[i], route[i + 1]);
            total += d;
            segmentDistances.add(d);
          }

          routeDistances.add(total);
        }
      }
    }

    // --- 4. STATS ---
    routeDistances.sort();
    segmentDistances.sort();

    double avg(List<double> list) =>
        list.reduce((a, b) => a + b) / list.length;

    double median(List<double> list) {
      final mid = list.length ~/ 2;
      if (list.length % 2 == 0) {
        return (list[mid - 1] + list[mid]) / 2;
      }
      return list[mid];
    }

    return RouteAnalysisResult(
      minDistance: routeDistances.first,
      maxDistance: routeDistances.last,
      avgDistance: avg(routeDistances),
      minSegment: segmentDistances.first,
      maxSegment: segmentDistances.last,
      avgSegment: avg(segmentDistances),
      medianSegment: median(segmentDistances),
      totalRoutes: routeDistances.length,
    );
  }

  // --- UTIL : combinaisons ---
  static List<List<Place>> _combinations(List<Place> items, int k) {
    final List<List<Place>> result = [];

    void combine(int start, List<Place> current) {
      if (current.length == k) {
        result.add(List.from(current));
        return;
      }
      for (int i = start; i < items.length; i++) {
        current.add(items[i]);
        combine(i + 1, current);
        current.removeLast();
      }
    }

    combine(0, []);
    return result;
  }

  // --- UTIL : distance Haversine ---
  static double _distance(Place a, Place b) {
    const R = 6371000; // mètres
    final dLat = _toRad(b.lat - a.lat);
    final dLon = _toRad(b.lng - a.lng);

    final lat1 = _toRad(a.lat);
    final lat2 = _toRad(b.lat);

    final h = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) *
            sin(dLon / 2) *
            cos(lat1) *
            cos(lat2);

    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return R * c;
  }

  static double _toRad(double deg) => deg * pi / 180;
}
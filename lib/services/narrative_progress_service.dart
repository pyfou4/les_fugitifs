import '../models/place_node.dart';

class NarrativeProgressService {
  static const Map<String, int> weightedProgressByPlaceId = {
    'A0': 18,
    'B0': 18,
    'C0': 18,
    'D0': 18,
    'A1': 6,
    'A2': 6,
    'B1': 5,
    'B2': 5,
    'C1': 6,
  };

  static const List<String> requiredMainPlaceIds = [
    'A0',
    'B0',
    'C0',
    'D0',
  ];

  static Set<String> visitedPlaceIds(List<PlaceNode> places) {
    return places.where((p) => p.isVisited).map((p) => p.id).toSet();
  }

  static int narrativeProgressScore(List<PlaceNode> places) {
    int score = 0;
    final visitedIds = visitedPlaceIds(places);

    for (final entry in weightedProgressByPlaceId.entries) {
      if (visitedIds.contains(entry.key)) {
        score += entry.value;
      }
    }

    return score.clamp(0, 100);
  }

  static double progressRatio(List<PlaceNode> places) {
    return (narrativeProgressScore(places) / 100).clamp(0.0, 1.0);
  }

  static bool canExitNarrative(List<PlaceNode> places) {
    final visitedIds = visitedPlaceIds(places);
    return requiredMainPlaceIds.every(visitedIds.contains);
  }

  static List<String> missingMainPlaceIds(List<PlaceNode> places) {
    final visitedIds = visitedPlaceIds(places);
    return requiredMainPlaceIds
        .where((id) => !visitedIds.contains(id))
        .toList();
  }
}
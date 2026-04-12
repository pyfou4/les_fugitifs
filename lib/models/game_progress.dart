import 'package:flutter/foundation.dart';

class GameProgress extends ChangeNotifier {
  static const int totalPlaces = 19;

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

  static const Set<String> requiredMainPlaceIds = {
    'A0',
    'B0',
    'C0',
    'D0',
  };

  final Set<String> visitedPlaceIds = {};
  final List<String> foundClues = [];

  bool get canExit {
    return requiredMainPlaceIds.every(visitedPlaceIds.contains);
  }

  int get visitedCount => visitedPlaceIds.length;

  int get narrativeProgressScore {
    int score = 0;

    for (final entry in weightedProgressByPlaceId.entries) {
      if (visitedPlaceIds.contains(entry.key)) {
        score += entry.value;
      }
    }

    return score.clamp(0, 100);
  }

  double get progressRatio {
    return (narrativeProgressScore / 100).clamp(0.0, 1.0);
  }

  bool isPlaceCountedInNarrativeProgress(String placeId) {
    return weightedProgressByPlaceId.containsKey(placeId);
  }

  int progressWeightForPlace(String placeId) {
    return weightedProgressByPlaceId[placeId] ?? 0;
  }

  void markPlaceVisited(String placeId) {
    final before = visitedPlaceIds.length;
    visitedPlaceIds.add(placeId);

    if (visitedPlaceIds.length != before) {
      notifyListeners();
    }
  }

  void addClue(String clue) {
    foundClues.add(clue);
    notifyListeners();
  }

  void resetGame() {
    visitedPlaceIds.clear();
    foundClues.clear();
    notifyListeners();
  }
}

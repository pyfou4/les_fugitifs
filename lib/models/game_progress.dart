import 'package:flutter/foundation.dart';

class GameProgress extends ChangeNotifier {
  static const int totalPlaces = 9;

  final Set<String> visitedPlaceIds = {};
  final List<String> foundClues = [];

  bool get canExit => visitedPlaceIds.length >= totalPlaces;

  double get progressRatio {
    return (visitedPlaceIds.length / totalPlaces).clamp(0.0, 1.0);
  }

  int get visitedCount => visitedPlaceIds.length;

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
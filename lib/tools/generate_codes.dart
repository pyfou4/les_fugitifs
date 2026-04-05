import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class CodeGenerator {
  static const String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  /// Génère un code aléatoire
  static String _generateCode(int length) {
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
            (_) => _chars.codeUnitAt(random.nextInt(_chars.length)),
      ),
    );
  }

  /// Génère plusieurs codes dans Firestore
  static Future<void> generateCodes({
    required int count,
    int codeLength = 6,
    int durationHours = 5,
    String scenarioId = "test_scenario",
  }) async {
    final firestore = FirebaseFirestore.instance;

    for (int i = 0; i < count; i++) {
      final code = _generateCode(codeLength);

      await firestore.collection('activationCodes').doc(code).set({
        'code': code,
        'scenarioId': scenarioId,
        'durationHours': durationHours,
        'status': 'unused',
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }
}
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

class ImportData {
  static Future<void> run() async {
    final firestore = FirebaseFirestore.instance;

    const scenarioId = "test_scenario";

    print("🚀 Début import...");

    // =========================
    // IMPORT PLACES
    // =========================
    final placesRaw =
    await rootBundle.loadString('assets/data/places.json');
    final placesData = jsonDecode(placesRaw);

    for (var place in placesData['places']) {
      final docId = place['id'];

      final data = Map<String, dynamic>.from(place);

      await firestore
          .collection('scenarios')
          .doc(scenarioId)
          .collection('places')
          .doc(docId)
          .set(data);

      print("✔ Place importée: $docId");
    }

    // =========================
    // IMPORT SUSPECTS
    // =========================
    final suspectsRaw =
    await rootBundle.loadString('assets/data/suspects.json');
    final suspectsData = jsonDecode(suspectsRaw);

    for (var suspect in suspectsData['suspects']) {
      final docId = suspect['id'];

      final data = Map<String, dynamic>.from(suspect);

      await firestore
          .collection('scenarios')
          .doc(scenarioId)
          .collection('suspects')
          .doc(docId)
          .set(data);

      print("✔ Suspect importé: $docId");
    }

    // =========================
    // IMPORT MOTIVES
    // =========================
    final motivesRaw =
    await rootBundle.loadString('assets/data/motives.json');
    final motivesData = jsonDecode(motivesRaw);

    for (var motive in motivesData['motives']) {
      final docId = motive['id'];

      final data = Map<String, dynamic>.from(motive);

      await firestore
          .collection('scenarios')
          .doc(scenarioId)
          .collection('motives')
          .doc(docId)
          .set(data);

      print("✔ Motive importé: $docId");
    }

    print("🎉 Import terminé !");
  }
}
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PublishLockedVersion {
  static Future<void> run({
    String scenarioId = 'test_scenario',
    String versionId = 'v1',
  }) async {
    final firestore = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;

    final scenarioRef = firestore.collection('scenarios').doc(scenarioId);
    final versionRef = scenarioRef.collection('versions').doc(versionId);

    print('🚀 Début publication version verrouillée...');
    print('📚 Scenario: $scenarioId');
    print('🏷️ Version: $versionId');

    final placesSnapshot = await scenarioRef.collection('places').get();
    final suspectsSnapshot = await scenarioRef.collection('suspects').get();
    final motivesSnapshot = await scenarioRef.collection('motives').get();

    if (placesSnapshot.docs.isEmpty) {
      throw Exception('Aucun lieu trouvé pour le scénario $scenarioId');
    }
    if (suspectsSnapshot.docs.isEmpty) {
      throw Exception('Aucun suspect trouvé pour le scénario $scenarioId');
    }
    if (motivesSnapshot.docs.isEmpty) {
      throw Exception('Aucun mobile trouvé pour le scénario $scenarioId');
    }

    final placesDocs = placesSnapshot.docs..sort((a, b) => a.id.compareTo(b.id));
    final suspectsDocs = suspectsSnapshot.docs
      ..sort((a, b) => a.id.compareTo(b.id));
    final motivesDocs = motivesSnapshot.docs..sort((a, b) => a.id.compareTo(b.id));

    final places = placesDocs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = data['id'] ?? doc.id;
      data['keywords'] = List<String>.from(data['keywords'] ?? []);
      data['media'] = List<String>.from(data['media'] ?? []);
      data['requiresAllVisited'] =
      List<String>.from(data['requiresAllVisited'] ?? []);
      data['requiresAnyVisited'] =
      List<String>.from(data['requiresAnyVisited'] ?? []);
      data['revealSuspect'] = data['revealSuspect'] ?? false;
      data['revealMotive'] = data['revealMotive'] ?? false;
      return data;
    }).toList();

    final suspects = suspectsDocs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = data['id'] ?? doc.id;
      return data;
    }).toList();

    final motives = motivesDocs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = data['id'] ?? doc.id;
      return data;
    }).toList();

    final placesJson = const JsonEncoder.withIndent('  ').convert({
      'places': places,
    });
    final suspectsJson = const JsonEncoder.withIndent('  ').convert({
      'suspects': suspects,
    });
    final motivesJson = const JsonEncoder.withIndent('  ').convert({
      'motives': motives,
    });

    final basePath = 'scenario_versions/$scenarioId/$versionId';

    final placesRef = storage.ref().child('$basePath/places.json');
    final suspectsRef = storage.ref().child('$basePath/suspects.json');
    final motivesRef = storage.ref().child('$basePath/motives.json');

    print('☁️ Upload places.json...');
    await placesRef.putString(
      placesJson,
      format: PutStringFormat.raw,
      metadata: SettableMetadata(contentType: 'application/json'),
    );

    print('☁️ Upload suspects.json...');
    await suspectsRef.putString(
      suspectsJson,
      format: PutStringFormat.raw,
      metadata: SettableMetadata(contentType: 'application/json'),
    );

    print('☁️ Upload motives.json...');
    await motivesRef.putString(
      motivesJson,
      format: PutStringFormat.raw,
      metadata: SettableMetadata(contentType: 'application/json'),
    );

    final placesUrl = await placesRef.getDownloadURL();
    final suspectsUrl = await suspectsRef.getDownloadURL();
    final motivesUrl = await motivesRef.getDownloadURL();

    await versionRef.set({
      'version': int.tryParse(versionId.replaceFirst('v', '')) ?? 1,
      'status': 'published',
      'lockedAt': FieldValue.serverTimestamp(),
      'lockedBy': 'admin_manual',
      'placesJsonUrl': placesUrl,
      'suspectsJsonUrl': suspectsUrl,
      'motivesJsonUrl': motivesUrl,
      'publishedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await scenarioRef.set({
      'status': 'published',
      'structureLocked': true,
      'publishedVersionId': versionId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('✅ Publication terminée');
    print('🔗 places.json: $placesUrl');
    print('🔗 suspects.json: $suspectsUrl');
    print('🔗 motives.json: $motivesUrl');
  }
}
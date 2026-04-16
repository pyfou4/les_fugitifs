import 'package:cloud_firestore/cloud_firestore.dart';

class ImportData {
  static Future<void> run() async {
    final firestore = FirebaseFirestore.instance;

    const sourceScenarioId = 'test_scenario';
    const targetScenarioId = 'les_fugitifs';

    print('🚀 Début migration scénario...');
    print('📦 Source: $sourceScenarioId');
    print('🎯 Cible: $targetScenarioId');

    final sourceRef = firestore.collection('scenarios').doc(sourceScenarioId);
    final targetRef = firestore.collection('scenarios').doc(targetScenarioId);

    final sourceSnap = await sourceRef.get();
    if (!sourceSnap.exists) {
      throw Exception('Scenario source introuvable: $sourceScenarioId');
    }

    final sourceData = Map<String, dynamic>.from(sourceSnap.data() ?? <String, dynamic>{});
    sourceData['id'] = targetScenarioId;
    sourceData['title'] = sourceData['title'] ?? 'Les Fugitifs';
    sourceData['updatedAt'] = DateTime.now().toIso8601String();

    await targetRef.set(sourceData, SetOptions(merge: true));
    print('✔ Document scénario copié');

    await _copyCollection(
      sourceRef.collection('places'),
      targetRef.collection('places'),
      label: 'place',
    );
    await _copyCollection(
      sourceRef.collection('suspects'),
      targetRef.collection('suspects'),
      label: 'suspect',
    );
    await _copyCollection(
      sourceRef.collection('motives'),
      targetRef.collection('motives'),
      label: 'motive',
    );

    final versionsSnap = await sourceRef.collection('versions').get();
    for (final versionDoc in versionsSnap.docs) {
      final versionData = Map<String, dynamic>.from(versionDoc.data());
      await targetRef.collection('versions').doc(versionDoc.id).set(versionData, SetOptions(merge: true));
      print('✔ Version copiée: ${versionDoc.id}');
    }

    print('🎉 Migration terminée');
  }

  static Future<void> _copyCollection(
    CollectionReference<Map<String, dynamic>> source,
    CollectionReference<Map<String, dynamic>> target, {
    required String label,
  }) async {
    final snap = await source.get();
    for (final doc in snap.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      await target.doc(doc.id).set(data, SetOptions(merge: true));
      print('✔ ${label} copié: ${doc.id}');
    }
  }
}

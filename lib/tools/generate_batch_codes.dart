import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../firebase_options.dart';

class BatchCodeGenerator {
  static const String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  static String _generateCode(int length) {
    final Random rand = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
            (_) => _chars.codeUnitAt(rand.nextInt(_chars.length)),
      ),
    );
  }

  static Future<void> generateBatch({
    required String scenarioId,
    required String createdBy,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final String batchId =
        'batch_${DateTime.now().millisecondsSinceEpoch}';

    final DocumentReference<Map<String, dynamic>> batchRef =
    firestore.collection('activationBatches').doc(batchId);

    final now = DateTime.now();

    debugPrint('Création du batch $batchId...');

    // 🔥 NOUVELLE STRUCTURE COMPLETE
    await batchRef.set({
      'createdAt': now.toIso8601String(),
      'createdBy': createdBy,
      'scenarioId': scenarioId,
      'siteId': 'sion',

      // 👇 nouveaux champs
      'label': 'Batch ${now.day}/${now.month} ${now.hour}:${now.minute}',
      'status': 'active',

      'countTotal': 1000,
      'countUnused': 1000,
      'countReserved': 0,
      'countUsed': 0,
    });

    final CollectionReference<Map<String, dynamic>> codesCollection =
    batchRef.collection('codes');

    WriteBatch batch = firestore.batch();
    int operationCount = 0;
    final Set<String> usedCodes = <String>{};

    for (int i = 0; i < 1000; i++) {
      String code;
      do {
        code = _generateCode(6);
      } while (usedCodes.contains(code));

      usedCodes.add(code);

      final DocumentReference<Map<String, dynamic>> docRef =
      codesCollection.doc(code);

      batch.set(docRef, {
        'code': code,
        'status': 'unused',
        'durationHours': 5,
        'createdAt': now.toIso8601String(),
        'reservedAt': null,
        'reservedBy': null,
        'usedAt': null,
        'usedByDeviceId': null,
        'expiresAt': null,
      });

      operationCount++;

      if (operationCount == 500) {
        await batch.commit();
        debugPrint('500 codes envoyés...');
        batch = firestore.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
    }

    debugPrint('✅ Batch $batchId généré avec 1000 codes');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const _BatchGeneratorApp());
}

class _BatchGeneratorApp extends StatefulWidget {
  const _BatchGeneratorApp();

  @override
  State<_BatchGeneratorApp> createState() =>
      _BatchGeneratorAppState();
}

class _BatchGeneratorAppState extends State<_BatchGeneratorApp> {
  String _status = 'Initialisation...';

  @override
  void initState() {
    super.initState();
    _runGeneration();
  }

  Future<void> _runGeneration() async {
    try {
      setState(() {
        _status = 'Génération du lot de 1000 codes...';
      });

      await BatchCodeGenerator.generateBatch(
        scenarioId: 'test_scenario',
        createdBy: 'admin',
      );

      setState(() {
        _status = '✅ Terminé — fermeture...';
      });

      await Future.delayed(const Duration(seconds: 2));

      SystemNavigator.pop();
    } catch (e) {
      setState(() {
        _status = '❌ Erreur : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "Génération en cours...",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }
}
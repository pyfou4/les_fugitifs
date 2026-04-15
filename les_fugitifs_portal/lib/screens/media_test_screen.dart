import 'package:flutter/material.dart';
import 'package:les_fugitifs_portal/core/media/repository/firestore_media_repository.dart';
import 'package:les_fugitifs_portal/screens/media_video_screen.dart';

class MediaTestScreen extends StatefulWidget {
  const MediaTestScreen({super.key});

  @override
  State<MediaTestScreen> createState() => _MediaTestScreenState();
}

class _MediaTestScreenState extends State<MediaTestScreen> {
  String result = 'Chargement...';

  @override
  void initState() {
    super.initState();
    _test();
  }

  Future<void> _test() async {
    try {
      final repository = FirestoreMediaRepository();

      final media = await repository.getActiveMediaForSlot(
        scenarioId: 'scenario_001',
        slotKey: 'intro_rules',
      );

      if (!mounted) return;

      if (media == null) {
        setState(() {
          result = 'Aucun média trouvé';
        });
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MediaVideoScreen(
            media: media,
            config: const MediaVideoScreenConfig(
              completionBehavior: MediaVideoCompletionBehavior.stay,
              autoPlay: true,
              loop: false,
              startMuted: true,
              showTapToPlayOverlay: true,
              allowUnmuteButton: true,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        result = 'Erreur: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test médias')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(result),
      ),
    );
  }
}

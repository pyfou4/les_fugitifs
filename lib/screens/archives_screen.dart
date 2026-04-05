import 'package:flutter/material.dart';

import '../models/place_node.dart';

class ArchivesScreen extends StatelessWidget {
  final VoidCallback onBack;
  final List<PlaceNode> places;
  final ValueChanged<PlaceNode> onOpenPlaceMedia;

  const ArchivesScreen({
    super.key,
    required this.onBack,
    required this.places,
    required this.onOpenPlaceMedia,
  });

  @override
  Widget build(BuildContext context) {
    final visitedPlaces = places.where((p) => p.isVisited).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archives'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: visitedPlaces.isEmpty
          ? const Center(
        child: Text(
          'Aucun lieu visité',
          style: TextStyle(fontSize: 20),
        ),
      )
          : ListView.builder(
        itemCount: visitedPlaces.length,
        itemBuilder: (_, i) {
          final place = visitedPlaces[i];

          return ListTile(
            title: Text(place.name),
            trailing: ElevatedButton(
              onPressed: () => onOpenPlaceMedia(place),
              child: const Text('Voir'),
            ),
          );
        },
      ),
    );
  }
}
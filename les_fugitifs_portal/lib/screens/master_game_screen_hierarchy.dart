import 'package:flutter/material.dart';

import '../services/portal_access_service.dart';
import '../widgets/header_brand.dart';

class MasterGameScreen extends StatelessWidget {
  final PortalAccessProfile profile;

  const MasterGameScreen({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const HeaderBrand(),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Menu Maître de jeu\n\nConnecté comme ${profile.displayName}.\n\nLa salle de contrôle MJ sera branchée ici ensuite.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              height: 1.45,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

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
      appBar: AppBar(
        title: const HeaderBrand(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                profile.role.label,
                style: const TextStyle(
                  color: Color(0xFFFFD7B8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Le menu Maître de jeu sera branché ici.\n\nLa porte existe déjà, la salle d’orchestration arrive ensuite.',
            textAlign: TextAlign.center,
            style: TextStyle(
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

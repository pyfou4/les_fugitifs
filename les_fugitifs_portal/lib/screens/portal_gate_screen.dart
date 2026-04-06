import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/portal_access_service.dart';
import 'portal_login_screen.dart';
import 'portal_shell_screen.dart';

class PortalGateScreen extends StatefulWidget {
  const PortalGateScreen({super.key});

  @override
  State<PortalGateScreen> createState() => _PortalGateScreenState();
}

class _PortalGateScreenState extends State<PortalGateScreen> {
  final PortalAccessService _portalAccessService = PortalAccessService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _portalAccessService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _PortalLoadingScaffold(
            label: 'Connexion au portail...',
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const PortalLoginScreen();
        }

        return FutureBuilder<PortalAccessProfile?>(
          future: _portalAccessService.readCurrentProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _PortalLoadingScaffold(
                label: 'Lecture du rôle utilisateur...',
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null || !profile.isActive) {
              return _PortalAccessDeniedScreen(
                message:
                    'Ce compte est connecté, mais aucun rôle actif n’est associé dans portalUsers.',
                onSignOut: _portalAccessService.signOut,
              );
            }

            return PortalShellScreen(profile: profile);
          },
        );
      },
    );
  }
}

class _PortalLoadingScaffold extends StatelessWidget {
  final String label;

  const _PortalLoadingScaffold({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              label,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalAccessDeniedScreen extends StatelessWidget {
  final String message;
  final Future<void> Function() onSignOut;

  const _PortalAccessDeniedScreen({
    required this.message,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.no_accounts_outlined,
                    size: 60,
                    color: Color(0xFFFFB4AB),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Accès refusé',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF9AA7BC),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onSignOut,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD65A00),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Se déconnecter'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

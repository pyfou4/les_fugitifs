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

            if (profile.mustChangePassword) {
              return _PortalForcePasswordChangeScreen(
                profile: profile,
                portalAccessService: _portalAccessService,
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

class _PortalForcePasswordChangeScreen extends StatefulWidget {
  final PortalAccessProfile profile;
  final PortalAccessService portalAccessService;

  const _PortalForcePasswordChangeScreen({
    required this.profile,
    required this.portalAccessService,
  });

  @override
  State<_PortalForcePasswordChangeScreen> createState() =>
      _PortalForcePasswordChangeScreenState();
}

class _PortalForcePasswordChangeScreenState
    extends State<_PortalForcePasswordChangeScreen> {
  final TextEditingController _currentPasswordCtrl = TextEditingController();
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorText;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final currentPassword = _currentPasswordCtrl.text;
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() {
        _errorText = 'Tous les champs sont obligatoires.';
      });
      return;
    }

    if (newPassword.length < 8) {
      setState(() {
        _errorText = 'Le nouveau mot de passe doit contenir au moins 8 caractères.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorText = 'La confirmation ne correspond pas au nouveau mot de passe.';
      });
      return;
    }

    if (currentPassword == newPassword) {
      setState(() {
        _errorText = 'Choisis un nouveau mot de passe différent de l’actuel.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await widget.portalAccessService.updateCurrentPasswordAndClearFirstAccess(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Impossible de changer le mot de passe : $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _passwordDecoration({
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      suffixIcon: IconButton(
        tooltip: obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
        onPressed: onToggle,
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Changement de mot de passe requis',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Le compte ${widget.profile.displayName} doit changer son mot de passe avant d’accéder au portail.',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Color(0xFF9AA7BC),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _currentPasswordCtrl,
                    obscureText: _obscureCurrent,
                    style: const TextStyle(color: Colors.white),
                    decoration: _passwordDecoration(
                      label: 'Mot de passe actuel',
                      obscure: _obscureCurrent,
                      onToggle: () {
                        setState(() {
                          _obscureCurrent = !_obscureCurrent;
                        });
                      },
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _newPasswordCtrl,
                    obscureText: _obscureNew,
                    style: const TextStyle(color: Colors.white),
                    decoration: _passwordDecoration(
                      label: 'Nouveau mot de passe',
                      obscure: _obscureNew,
                      onToggle: () {
                        setState(() {
                          _obscureNew = !_obscureNew;
                        });
                      },
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscureConfirm,
                    style: const TextStyle(color: Colors.white),
                    decoration: _passwordDecoration(
                      label: 'Confirmer le nouveau mot de passe',
                      obscure: _obscureConfirm,
                      onToggle: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Ce blocage est volontaire: tant que le mot de passe provisoire n’a pas été remplacé, l’accès au portail reste verrouillé.',
                    style: TextStyle(
                      color: Color(0xFFAED0FF),
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFFFB4AB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => widget.portalAccessService.signOut(),
                          icon: const Icon(Icons.logout),
                          label: const Text('Se déconnecter'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD65A00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.lock_reset),
                          label: Text(
                            _isLoading
                                ? 'Mise à jour...'
                                : 'Changer le mot de passe',
                          ),
                        ),
                      ),
                    ],
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

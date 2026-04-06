import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/portal_access_service.dart';

class PortalLoginScreen extends StatefulWidget {
  const PortalLoginScreen({super.key});

  @override
  State<PortalLoginScreen> createState() => _PortalLoginScreenState();
}

class _PortalLoginScreenState extends State<PortalLoginScreen> {
  static const String _lastEmailKey = 'portal_last_email';

  final PortalAccessService _portalAccessService = PortalAccessService();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLastEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastEmail = prefs.getString(_lastEmailKey) ?? '';

      if (!mounted) return;

      _emailCtrl.text = lastEmail;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _persistLastEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastEmailKey, email.trim());
    } catch (_) {
      // On n’empêche jamais la connexion si le stockage local échoue.
    }
  }

  Future<void> _signIn() async {
    if (_isLoading) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Email et mot de passe obligatoires.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await _portalAccessService.signIn(email: email, password: password);
      await _persistLastEmail(email);

      if (!mounted) return;

      final profile = await _portalAccessService.readCurrentProfile();
      if (profile == null || !profile.isActive) {
        await _portalAccessService.signOut();
        if (!mounted) return;
        setState(() {
          _errorText =
          'Compte authentifié, mais aucun rôle portail actif n’a été trouvé.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Connexion refusée : $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connexion au portail',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Connecte-toi avec un compte Firebase Auth autorisé. Ensuite, le portail affichera toutes les zones permises par ton rôle.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Color(0xFF9AA7BC),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      helperText:
                      'Le dernier email utilisé est mémorisé sur ce navigateur.',
                    ),
                    onSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                    ),
                    onSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 14),
                  if (_errorText != null)
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFFFB4AB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _signIn,
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
                          : const Icon(Icons.login),
                      label: Text(
                        _isLoading ? 'Connexion...' : 'Se connecter',
                      ),
                    ),
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
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
  static const String _rememberPasswordKey = 'portal_remember_password';
  static const String _savedPasswordKey = 'portal_saved_password';

  final PortalAccessService _portalAccessService = PortalAccessService();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberPassword = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastEmail = prefs.getString(_lastEmailKey) ?? '';
      final rememberPassword = prefs.getBool(_rememberPasswordKey) ?? false;
      final savedPassword =
          rememberPassword ? (prefs.getString(_savedPasswordKey) ?? '') : '';

      if (!mounted) return;

      _emailCtrl.text = lastEmail;
      _passwordCtrl.text = savedPassword;
      setState(() {
        _rememberPassword = rememberPassword;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _persistCredentials({
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastEmailKey, email.trim());

      if (_rememberPassword) {
        await prefs.setBool(_rememberPasswordKey, true);
        await prefs.setString(_savedPasswordKey, password);
      } else {
        await prefs.setBool(_rememberPasswordKey, false);
        await prefs.remove(_savedPasswordKey);
      }
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
      await _persistCredentials(email: email, password: password);

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
                          'Le dernier email utilisé est mémorisé sur cet appareil.',
                    ),
                    onSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    value: _rememberPassword,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFFD65A00),
                    title: const Text(
                      'Mémoriser le mot de passe sur cet appareil',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'À réserver à un poste de travail de confiance.',
                      style: TextStyle(
                        color: Color(0xFF9AA7BC),
                        height: 1.35,
                      ),
                    ),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() {
                              _rememberPassword = value ?? false;
                            });
                          },
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFFFB4AB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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

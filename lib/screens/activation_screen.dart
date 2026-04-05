import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/firebase_media.dart';
import '../services/session_service.dart';

class ActivationScreen extends StatefulWidget {
  final Widget nextScreen;

  const ActivationScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _activate() async {
    final code = _controller.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() {
        _error = "Entre un code d'activation";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await SessionService.activateCode(code);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.nextScreen),
      );
    } else {
      setState(() {
        _error = "Accès refusé — code invalide, expiré ou session introuvable";
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final compact = media.size.height < 420;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: FirebaseMedia.bgActivation,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.black),
              errorWidget: (_, __, ___) => Container(color: Colors.black),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.32),
            ),
          ),
          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: Container(
                      width: compact ? 280 : 300,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFFB347).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "ACCÈS\nÀ LA BRÈCHE",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.marcellusSc(
                              color: Colors.white,
                              fontSize: compact ? 24 : 26,
                              letterSpacing: 2.0,
                              height: 1.08,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFFFFA84B)
                                      .withOpacity(0.45),
                                  blurRadius: 18,
                                ),
                                Shadow(
                                  color: Colors.black.withOpacity(0.8),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Code d'autorisation requis",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: compact ? 220 : 240,
                            child: TextField(
                              controller: _controller,
                              textAlign: TextAlign.center,
                              textCapitalization: TextCapitalization.characters,
                              onSubmitted: (_) => _isLoading ? null : _activate(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                letterSpacing: 4,
                              ),
                              decoration: InputDecoration(
                                hintText: "CODE",
                                hintStyle: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.35),
                                  letterSpacing: 2,
                                ),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.35),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: const Color(0xFFFFB347)
                                        .withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFFB347),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _error == null
                                ? const SizedBox(height: 8)
                                : Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFFF5A4F),
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: compact ? 230 : 250,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _activate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF120703).withOpacity(0.95),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: const Color(0xFFFFA84B)
                                        .withOpacity(0.3),
                                  ),
                                ),
                                textStyle: GoogleFonts.marcellusSc(
                                  fontSize: 18,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text("ACTIVER"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

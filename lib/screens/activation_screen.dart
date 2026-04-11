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

    FocusScope.of(context).unfocus();

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
    final size = media.size;
    final keyboardHeight = media.viewInsets.bottom;
    final keyboardVisible = keyboardHeight > 0;
    final isLandscape = size.width > size.height;
    final isTabletLike = size.shortestSide >= 600;
    final compact = size.height < 420 || size.width < 700;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
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
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  left: compact ? 12 : 20,
                  right: compact ? 12 : 20,
                  top: keyboardVisible ? 12 : 24,
                  bottom: keyboardVisible ? keyboardHeight + 8 : 24,
                ),
                child: Align(
                  alignment: keyboardVisible
                      ? Alignment.bottomCenter
                      : Alignment.center,
                  child: SingleChildScrollView(
                    reverse: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _ActivationCard(
                      controller: _controller,
                      isLoading: _isLoading,
                      error: _error,
                      compact: compact,
                      keyboardVisible: keyboardVisible,
                      isTabletLike: isTabletLike,
                      isLandscape: isLandscape,
                      onActivate: _activate,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivationCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final String? error;
  final bool compact;
  final bool keyboardVisible;
  final bool isTabletLike;
  final bool isLandscape;
  final VoidCallback onActivate;

  const _ActivationCard({
    required this.controller,
    required this.isLoading,
    required this.error,
    required this.compact,
    required this.keyboardVisible,
    required this.isTabletLike,
    required this.isLandscape,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final ultraCompact = keyboardVisible;

    final double cardWidth;
    if (ultraCompact) {
      cardWidth = compact ? 280.0 : 300.0;
    } else if (isTabletLike && isLandscape) {
      cardWidth = 380.0;
    } else if (compact) {
      cardWidth = 300.0;
    } else {
      cardWidth = 340.0;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.symmetric(
          horizontal: ultraCompact ? 16 : (isTabletLike ? 22 : 18),
          vertical: ultraCompact ? 14 : (isTabletLike ? 22 : 20),
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFFB347).withOpacity(0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 22,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "ACCÈS\nÀ LA BRÈCHE",
              textAlign: TextAlign.center,
              style: GoogleFonts.marcellusSc(
                color: Colors.white,
                fontSize: ultraCompact
                    ? 18
                    : (isTabletLike ? 28 : (compact ? 24 : 26)),
                letterSpacing: ultraCompact ? 1.2 : 2.0,
                height: ultraCompact ? 1.0 : 1.08,
                shadows: [
                  Shadow(
                    color: const Color(0xFFFFA84B).withOpacity(0.45),
                    blurRadius: 18,
                  ),
                  Shadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            SizedBox(height: ultraCompact ? 4 : 8),
            Text(
              "Code d'autorisation requis",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.62),
                fontSize: ultraCompact ? 11 : 12,
              ),
            ),
            SizedBox(height: ultraCompact ? 10 : 18),
            TextField(
              controller: controller,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              enableSuggestions: false,
              autocorrect: false,
              onSubmitted: (_) => isLoading ? null : onActivate(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: ultraCompact ? 16 : 18,
                letterSpacing: ultraCompact ? 3 : 4,
              ),
              decoration: InputDecoration(
                hintText: "CODE",
                hintStyle: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.35),
                  letterSpacing: 2,
                ),
                filled: true,
                fillColor: Colors.black.withOpacity(0.38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: const Color(0xFFFFB347).withOpacity(0.22),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFFFB347),
                  ),
                ),
                isDense: ultraCompact,
                contentPadding: EdgeInsets.symmetric(
                  vertical: ultraCompact ? 10 : 14,
                  horizontal: 12,
                ),
              ),
            ),
            SizedBox(height: ultraCompact ? 6 : 10),
            SizedBox(
              height: ultraCompact ? 28 : 36,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: error == null
                      ? const SizedBox.shrink()
                      : Text(
                          error!,
                          key: ValueKey(error),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF5A4F),
                            fontSize: ultraCompact ? 12 : 13,
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(height: ultraCompact ? 4 : 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onActivate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF120703).withOpacity(0.95),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    vertical: ultraCompact ? 10 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: const Color(0xFFFFA84B).withOpacity(0.3),
                    ),
                  ),
                  textStyle: GoogleFonts.marcellusSc(
                    fontSize: ultraCompact ? 15 : 18,
                    letterSpacing: ultraCompact ? 1.4 : 2.0,
                  ),
                ),
                child: isLoading
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
    );
  }
}

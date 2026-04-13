
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Team setup screen for Les Fugitifs.
///
/// Purpose:
/// - Collect the team name
/// - Collect the player count
/// - Block vulgar / sexual / explicit team names
/// - Keep the UI as an independent layer above a decorative background
///
/// Integration notes:
/// - Replace the background asset path if needed
/// - Wire [onValidated] to save the data in your session/backend
/// - Navigate to the briefing screen after successful validation
class TeamSetupScreen extends StatefulWidget {
  const TeamSetupScreen({
    super.key,
    this.backgroundImagePath = 'assets/images/team_setup_portal.png',
    this.onValidated,
  });

  final String backgroundImagePath;

  /// Called after local validation succeeds.
  /// Return true to continue the transition, false to stay on screen.
  final Future<bool> Function(TeamSetupResult result)? onValidated;

  @override
  State<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends State<TeamSetupScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _teamNameController = TextEditingController();
  final FocusNode _teamNameFocusNode = FocusNode();

  static const int _minNameLength = 3;
  static const int _maxNameLength = 24;

  static const List<int> _playerOptions = <int>[1, 2, 3, 4];
  int _selectedPlayerCount = 2;

  bool _isSubmitting = false;
  String? _errorMessage;

  late final AnimationController _animationController;
  late final Animation<double> _panelOpacity;
  late final Animation<Offset> _panelOffset;
  late final Animation<double> _portalScale;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _panelOpacity = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.05, 0.60, curve: Curves.easeOut),
    );

    _panelOffset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.10, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _portalScale = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.40, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _teamNameFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _saveTeamSetupToFirebase({
    required TeamSetupResult result,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? activeSessionId = prefs.getString('active_game_session_id');

    if (activeSessionId == null || activeSessionId.trim().isEmpty) {
      throw Exception('Session active introuvable');
    }

    await FirebaseFirestore.instance
        .collection('gameSessions')
        .doc(activeSessionId)
        .set(
      <String, dynamic>{
        'teamName': result.teamName,
        'playerCount': result.playerCount,
        'teamSetupCompletedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await prefs.setString('active_team_name', result.teamName);
    await prefs.setInt('active_player_count', result.playerCount);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final String rawName = _teamNameController.text.trim();
    final String cleanedName = _sanitizeVisibleName(rawName);
    final String? validationError = _validateTeamName(cleanedName);

    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _teamNameController.text = cleanedName;
      _teamNameController.selection = TextSelection.collapsed(
        offset: cleanedName.length,
      );
    });

    final TeamSetupResult result = TeamSetupResult(
      teamName: cleanedName,
      playerCount: _selectedPlayerCount,
      createdAt: DateTime.now(),
    );

    try {
      await _saveTeamSetupToFirebase(result: result);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorMessage =
            'Enregistrement impossible pour le moment. Veuillez réessayer.';
      });
      return;
    }

    bool canContinue = true;

    if (widget.onValidated != null) {
      try {
        canContinue = await widget.onValidated!(result);
      } catch (_) {
        canContinue = false;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      if (!canContinue) {
        _errorMessage =
            'Enregistrement impossible pour le moment. Veuillez réessayer.';
      }
    });

    if (!canContinue) {
      return;
    }

    await _playExitTransition();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(result);
  }

  Future<void> _playExitTransition() async {
    await _animationController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  String? _validateTeamName(String name) {
    if (name.isEmpty) {
      return 'Veuillez enregistrer une désignation d’unité.';
    }

    if (name.length < _minNameLength) {
      return 'La désignation doit contenir au moins $_minNameLength caractères.';
    }

    if (name.length > _maxNameLength) {
      return 'La désignation ne peut pas dépasser $_maxNameLength caractères.';
    }

    if (!_containsVisibleLettersOrDigits(name)) {
      return 'Veuillez choisir une désignation exploitable par le système.';
    }

    final String normalized = _normalizeForModeration(name);

    if (_looksLikeOnlyRepeatedCharacters(normalized)) {
      return 'Veuillez choisir une désignation plus crédible.';
    }

    if (_containsForbiddenContent(normalized)) {
      return 'Désignation refusée par le système. Veuillez enregistrer un nom d’unité valide.';
    }

    return null;
  }

  bool _containsVisibleLettersOrDigits(String value) {
    return RegExp(r'[A-Za-zÀ-ÿ0-9]').hasMatch(value);
  }

  bool _looksLikeOnlyRepeatedCharacters(String normalized) {
    if (normalized.length < 3) {
      return false;
    }
    final Set<String> uniqueChars = normalized.split('').toSet();
    return uniqueChars.length <= 2;
  }

  bool _containsForbiddenContent(String normalized) {
    for (final String term in _forbiddenTerms) {
      if (normalized.contains(term)) {
        return true;
      }
    }
    return false;
  }

  String _sanitizeVisibleName(String input) {
    String value = input.trim();

    value = value.replaceAll(RegExp(r'\s+'), ' ');
    value = value.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9 _\-]'), '');

    if (value.length > _maxNameLength) {
      value = value.substring(0, _maxNameLength).trim();
    }

    return value;
  }

  String _normalizeForModeration(String input) {
    String value = input.toLowerCase().trim();

    const Map<String, String> substitutions = <String, String>{
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '7': 't',
      '@': 'a',
      r'$': 's',
      '!': 'i',
    };

    substitutions.forEach((String key, String replacement) {
      value = value.replaceAll(key, replacement);
    });

    value = _stripDiacritics(value);
    value = value.replaceAll(RegExp(r'[\s_\-\.]+'), '');
    value = value.replaceAll(RegExp(r'(.)\1{2,}'), r'$1');

    return value;
  }

  String _stripDiacritics(String value) {
    const Map<String, String> accents = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'œ': 'oe',
      'æ': 'ae',
    };

    String output = value;
    accents.forEach((String key, String replacement) {
      output = output.replaceAll(key, replacement);
    });
    return output;
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    final bool isTablet = screenSize.shortestSide >= 700;
    final bool lowHeight = screenSize.height < 500;
    final bool keyboardVisible = mediaQuery.viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AnimatedBuilder(
            animation: _portalScale,
            builder: (BuildContext context, Widget? child) {
              return Transform.scale(
                scale: _portalScale.value,
                child: child,
              );
            },
            child: _BackgroundLayer(imagePath: widget.backgroundImagePath),
          ),
          const _AtmosphereOverlay(),
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _panelOpacity,
                child: SlideTransition(
                  position: _panelOffset,
                  child: Transform.translate(
                    offset: Offset(0, keyboardVisible ? -28 : 0),
                    child: _SetupPanel(
                      isTablet: isTablet,
                      lowHeight: lowHeight,
                      keyboardVisible: keyboardVisible,
                      teamNameController: _teamNameController,
                    teamNameFocusNode: _teamNameFocusNode,
                    selectedPlayerCount: _selectedPlayerCount,
                    playerOptions: _playerOptions,
                    isSubmitting: _isSubmitting,
                    errorMessage: _errorMessage,
                    onPlayerCountSelected: (int value) {
                      setState(() {
                        _selectedPlayerCount = value;
                      });
                    },
                      onSubmit: _submit,
                    ),
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

class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer({
    required this.imagePath,
  });

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF050A12),
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          onError: (_, __) {},
        ),
      ),
      child: Container(
        color: const Color(0xFF050A12).withOpacity(0.20),
      ),
    );
  }
}

class _AtmosphereOverlay extends StatelessWidget {
  const _AtmosphereOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withOpacity(0.46),
                  Colors.black.withOpacity(0.22),
                  Colors.black.withOpacity(0.38),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 720,
              height: 420,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.62,
                  colors: <Color>[
                    Colors.white.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({
    required this.isTablet,
    required this.lowHeight,
    required this.keyboardVisible,
    required this.teamNameController,
    required this.teamNameFocusNode,
    required this.selectedPlayerCount,
    required this.playerOptions,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onPlayerCountSelected,
    required this.onSubmit,
  });

  final bool isTablet;
  final bool lowHeight;
  final bool keyboardVisible;
  final TextEditingController teamNameController;
  final FocusNode teamNameFocusNode;
  final int selectedPlayerCount;
  final List<int> playerOptions;
  final bool isSubmitting;
  final String? errorMessage;
  final ValueChanged<int> onPlayerCountSelected;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final bool ultraCompact = lowHeight || keyboardVisible;

    final double horizontalPadding = ultraCompact
        ? (isTablet ? 16 : 10)
        : (isTablet ? 36 : 22);
    final double titleSize = ultraCompact
        ? (isTablet ? 19 : 15)
        : (isTablet ? 28 : 22);
    final double bodySize = ultraCompact
        ? (isTablet ? 11.8 : 10.8)
        : (isTablet ? 15.5 : 14.2);
    final double fieldFontSize = ultraCompact ? 12.4 : 15.5;
    final double labelSize = ultraCompact ? 11.6 : 14.2;
    final double captionSize = ultraCompact ? 10.2 : 12.8;
    final double verticalOuterPadding = ultraCompact ? 4 : 20;
    final double titleSpacing = ultraCompact ? 4 : 14;
    final double sectionSpacing = ultraCompact ? 8 : 24;
    final double inputSpacing = ultraCompact ? 4 : 10;
    final double afterInputSpacing = ultraCompact ? 2 : 8;
    final double wrapSpacing = ultraCompact ? 5 : 10;
    final double errorSpacing = ultraCompact ? 6 : 18;
    final double buttonTopSpacing = ultraCompact ? 8 : 24;
    final EdgeInsets panelPadding = EdgeInsets.fromLTRB(
      ultraCompact ? (isTablet ? 16 : 10) : (isTablet ? 34 : 22),
      ultraCompact ? (isTablet ? 12 : 8) : (isTablet ? 30 : 20),
      ultraCompact ? (isTablet ? 16 : 10) : (isTablet ? 34 : 22),
      ultraCompact ? (isTablet ? 10 : 8) : (isTablet ? 28 : 20),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isTablet ? 620 : (ultraCompact ? 420 : 460),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalOuterPadding,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: panelPadding,
              decoration: BoxDecoration(
                color: const Color(0xFF08101E).withOpacity(0.62),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1.1,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Identification de la cellule',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      height: ultraCompact ? 1.0 : 1.05,
                    ),
                  ),
                  SizedBox(height: titleSpacing),
                  Text(
                    'Nouvelle cellule détectée.\nVeuillez enregistrer votre unité avant accès au dossier.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: bodySize,
                      height: ultraCompact ? 1.12 : 1.22,
                    ),
                  ),
                  SizedBox(height: sectionSpacing),
                  _SectionLabel(
                    label: 'Nom de l’unité',
                    caption: 'Visible dans le classement final',
                    labelSize: labelSize,
                    captionSize: captionSize,
                    compact: lowHeight,
                  ),
                  SizedBox(height: inputSpacing),
                  TextField(
                    controller: teamNameController,
                    focusNode: teamNameFocusNode,
                    textInputAction: TextInputAction.done,
                    maxLength: 24,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fieldFontSize,
                    ),
                    cursorColor: Colors.white,
                    onSubmitted: (_) => onSubmit(),
                    buildCounter: (
                      BuildContext context, {
                      required int currentLength,
                      required bool isFocused,
                      required int? maxLength,
                    }) {
                      if (ultraCompact) {
                        return const SizedBox.shrink();
                      }
                      return null;
                    },
                    decoration: _buildInputDecoration(
                      hintText: 'Ex. Les Ombres du Quai',
                      lowHeight: lowHeight,
                      ultraCompact: ultraCompact,
                    ),
                  ),
                  SizedBox(height: afterInputSpacing),
                  _SectionLabel(
                    label: 'Effectif opérationnel',
                    caption: 'Utilisé pour adapter certaines épreuves',
                    labelSize: labelSize,
                    captionSize: captionSize,
                    compact: lowHeight,
                  ),
                  SizedBox(height: inputSpacing),
                  Wrap(
                    spacing: wrapSpacing,
                    runSpacing: wrapSpacing,
                    children: playerOptions.map((int value) {
                      final bool isSelected = selectedPlayerCount == value;
                      final String label = value == 6 ? '6+' : '$value';

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: isSubmitting
                            ? null
                            : () => onPlayerCountSelected(value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(
                            horizontal: ultraCompact ? 10 : 18,
                            vertical: ultraCompact ? 5 : 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isSelected
                                ? Colors.white.withOpacity(0.18)
                                : Colors.white.withOpacity(0.06),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.78)
                                  : Colors.white.withOpacity(0.18),
                              width: isSelected ? 1.4 : 1,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: Colors.white.withOpacity(
                                isSelected ? 1 : 0.88,
                              ),
                              fontSize: ultraCompact ? 12.0 : 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (errorMessage != null) ...<Widget>[
                    SizedBox(height: errorSpacing),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: ultraCompact ? 7 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF571B1B).withOpacity(0.60),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.14),
                        ),
                      ),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.96),
                          fontSize: ultraCompact ? 11.8 : 13.8,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: buttonTopSpacing),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isSubmitting ? null : onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF09101C),
                        padding: EdgeInsets.symmetric(
                          vertical: ultraCompact ? 8 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: TextStyle(
                          fontSize: ultraCompact ? 12.0 : 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Text('Enregistrer l’unité'),
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

  InputDecoration _buildInputDecoration({
    required String hintText,
    required bool lowHeight,
    required bool ultraCompact,
  }) {
    return InputDecoration(
      counterStyle: TextStyle(
        color: Colors.white.withOpacity(0.55),
        fontSize: lowHeight ? 10.5 : 12,
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.white.withOpacity(0.45),
        fontSize: lowHeight ? 13 : 14.5,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: ultraCompact ? 7 : 16,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.16),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.70),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.redAccent.withOpacity(0.70),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.caption,
    required this.labelSize,
    required this.captionSize,
    required this.compact,
  });

  final String label;
  final String caption;
  final double labelSize;
  final double captionSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.96),
            fontSize: labelSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: compact ? 2 : 3),
        Text(
          caption,
          style: TextStyle(
            color: Colors.white.withOpacity(0.58),
            fontSize: captionSize,
            height: compact ? 1.05 : 1.3,
          ),
        ),
      ],
    );
  }
}

class TeamSetupResult {
  const TeamSetupResult({
    required this.teamName,
    required this.playerCount,
    required this.createdAt,
  });

  final String teamName;
  final int playerCount;
  final DateTime createdAt;
}

const Set<String> _forbiddenTerms = <String>{
  'pute',
  'putain',
  'salope',
  'encule',
  'enculer',
  'enculee',
  'encules',
  'connard',
  'connasse',
  'bite',
  'bites',
  'chatte',
  'chattes',
  'nichon',
  'nichons',
  'sein',
  'seins',
  'cul',
  'culs',
  'teub',
  'teubs',
  'sexe',
  'sexeoral',
  'porno',
  'porn',
  'pornographie',
  'branlette',
  'branler',
  'branle',
  'gode',
  'godemichet',
  'fellation',
  'sodomie',
  'sodomiser',
  'nudite',
  'nuintegral',
  'boobs',
  'teton',
  'tetons',
  'vagin',
  'vulve',
  'penis',
  'zizi',
  'queue',
  'queues',
  'couilles',
  'couille',
  'foutre',
  'baise',
  'baiser',
  'baisee',
  'niquer',
  'nique',
  'niker',
  'bordel',
  'merde',
  'fdp',
  'tg',
  'tagueule',
  'fuck',
  'fucking',
  'motherfucker',
  'bitch',
  'asshole',
  'dick',
  'cock',
  'pussy',
  'tits',
  'boob',
  'nude',
  'naked',
  'sex',
  'sexy',
  'slut',
  'whore',
  'cum',
  'cumming',
  'blowjob',
  'handjob',
  'boner',
  'wank',
  'bastard',
  'shit',
  'bullshit',
  'damn',
};


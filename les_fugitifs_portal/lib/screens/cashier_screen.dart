import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../services/activation_session_service.dart';
import '../services/browser_site_preference.dart';
import '../widgets/header_brand.dart';
import 'admin_screen.dart';
import 'creator_screen.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen>
    with TickerProviderStateMixin {
  final ActivationSessionService _activationSessionService =
      ActivationSessionService(
    firestore: FirebaseFirestore.instance,
  );

  String? _currentCode;
  bool _loading = false;
  String? _message;
  String? _currentGameSessionId;

  String? _selectedScenarioId;
  String? _selectedSiteId;
  String? _defaultSiteId;
  bool _siteLocked = false;

  late final AnimationController _logoController;
  late final AnimationController _portalController;

  @override
  void initState() {
    super.initState();

    _defaultSiteId = BrowserSitePreference.getDefaultSiteId();
    _siteLocked = BrowserSitePreference.isLocked();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _portalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _portalController.dispose();
    super.dispose();
  }

  void _syncSelectedSiteWithPreferences(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> siteDocs,
  ) {
    final availableSiteIds = siteDocs.map((doc) => doc.id).toSet();
    final latestDefaultSiteId = BrowserSitePreference.getDefaultSiteId();
    final latestSiteLocked = BrowserSitePreference.isLocked();

    if (_defaultSiteId != latestDefaultSiteId ||
        _siteLocked != latestSiteLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _defaultSiteId = latestDefaultSiteId;
          _siteLocked = latestSiteLocked;
        });
      });
    }

    if (_selectedSiteId != null && !availableSiteIds.contains(_selectedSiteId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedSiteId = null;
        });
      });
      return;
    }

    if ((_selectedSiteId == null || _selectedSiteId!.isEmpty) &&
        _defaultSiteId != null &&
        availableSiteIds.contains(_defaultSiteId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedSiteId = _defaultSiteId;
        });
      });
    }

    if (_siteLocked &&
        _defaultSiteId != null &&
        _selectedSiteId != _defaultSiteId &&
        availableSiteIds.contains(_defaultSiteId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedSiteId = _defaultSiteId;
          _currentCode = null;
          _currentGameSessionId = null;
          _message = null;
        });
      });
    }
  }

  Future<void> _openAdminAccess() async {
    final controller = TextEditingController();
    String? errorText;

    final bool? granted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151B25),
              title: const Text(
                'Accès admin',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Saisis le mot de passe administrateur pour accéder au dashboard.',
                    style: TextStyle(color: Color(0xFFB8C3D6)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      errorText: errorText,
                    ),
                    onSubmitted: (_) {
                      if (controller.text == App.adminPassword) {
                        Navigator.of(context).pop(true);
                      } else {
                        setLocalState(() {
                          errorText = 'Mot de passe incorrect';
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text == App.adminPassword) {
                      Navigator.of(context).pop(true);
                    } else {
                      setLocalState(() {
                        errorText = 'Mot de passe incorrect';
                      });
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD65A00),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Entrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (granted == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminScreen(),
        ),
      );

      if (!mounted) return;

      setState(() {
        _defaultSiteId = BrowserSitePreference.getDefaultSiteId();
        _siteLocked = BrowserSitePreference.isLocked();

        if (_siteLocked &&
            _defaultSiteId != null &&
            _selectedSiteId != _defaultSiteId) {
          _selectedSiteId = _defaultSiteId;
          _currentCode = null;
          _currentGameSessionId = null;
          _message = null;
        }
      });
    }
  }

  Future<void> _openCreatorAccess() async {
    final controller = TextEditingController();
    String? errorText;

    final bool? granted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151B25),
              title: const Text(
                'Accès scénariste',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Saisis le mot de passe scénariste pour accéder au créateur de scénario.',
                    style: TextStyle(color: Color(0xFFB8C3D6)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      errorText: errorText,
                    ),
                    onSubmitted: (_) {
                      if (controller.text == App.adminPassword) {
                        Navigator.of(context).pop(true);
                      } else {
                        setLocalState(() {
                          errorText = 'Mot de passe incorrect';
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text == App.adminPassword) {
                      Navigator.of(context).pop(true);
                    } else {
                      setLocalState(() {
                        errorText = 'Mot de passe incorrect';
                      });
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD65A00),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Entrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (granted == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CreatorScreen(),
        ),
      );
    }
  }

  Future<void> _getCode() async {
    if (_loading) return;

    if (_selectedScenarioId == null || _selectedSiteId == null) {
      setState(() {
        _message = 'Choisis d’abord un scénario verrouillé et un site.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final result = await _activationSessionService.assignCodeAndCreateSession(
        lockedScenarioId: _selectedScenarioId!,
        siteId: _selectedSiteId!,
        cashierUserId: 'cashier_portal',
      );

      if (!mounted) return;

      if (result.success) {
        _portalController
          ..reset()
          ..repeat(reverse: true);

        setState(() {
          _currentCode = result.code;
          _currentGameSessionId = result.gameSessionId;
          _message = result.message;
        });
      } else {
        setState(() {
          _currentCode = null;
          _currentGameSessionId = null;
          _message = result.message;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentCode = null;
        _currentGameSessionId = null;
        _message = 'Erreur pendant l’attribution.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _prepareNextCode() {
    _portalController.stop();
    _portalController.reset();

    setState(() {
      _currentCode = null;
      _currentGameSessionId = null;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCode = _currentCode != null && _currentCode!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const HeaderBrand(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _openCreatorAccess,
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('Accès scénariste'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFD7B8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _openAdminAccess,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Accès admin'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFD7B8),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      final glow = 18 + (_logoController.value * 18);
                      return Container(
                        padding: const EdgeInsets.all(36),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF7A1F00),
                              Color(0xFFD65A00),
                              Color(0xFF28110A),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x33D65A00),
                              blurRadius: glow,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0x55FFD1A3),
                                    blurRadius:
                                        14 + (_logoController.value * 8),
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 74,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            const Text(
                              'HENIGMA GRID',
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFFFFD7B8),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Ouvrez la brèche.\nLe voyage commence ici.',
                              style: TextStyle(
                                fontSize: 50,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Chaque code remis entre les bonnes mains peut devenir le seuil d’un passage vers une autre réalité.',
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.55,
                                color: Color(0xFFFFE4CF),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  flex: 6,
                  child: Card(
                    color: const Color(0xFF131A24),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Attribution de code',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Choisis un scénario verrouillé et un site prêt, puis ouvre la porte au prochain voyageur.',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Color(0xFF9AA7BC),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              Expanded(
                                child: StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>>(
                                  stream: FirebaseFirestore.instance
                                      .collection('lockedScenarios')
                                      .where('status', isEqualTo: 'locked')
                                      .orderBy('lockedAt', descending: true)
                                      .snapshots(),
                                  builder: (context, scenarioSnapshot) {
                                    final scenarioDocs =
                                        scenarioSnapshot.data?.docs ?? [];

                                    final scenarioItems = scenarioDocs
                                        .map(
                                          (doc) => DropdownMenuItem<String>(
                                            value: doc.id,
                                            child: Text(
                                              '${(doc.data()['title'] ?? doc.id).toString()}'
                                              ' • ${doc.id}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList();

                                    return DropdownButtonFormField<String>(
                                      value: scenarioDocs.any(
                                        (d) => d.id == _selectedScenarioId,
                                      )
                                          ? _selectedScenarioId
                                          : null,
                                      dropdownColor: const Color(0xFF171E2A),
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Choisir le scénario verrouillé',
                                      ),
                                      items: scenarioItems,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedScenarioId = value;
                                          _currentCode = null;
                                          _currentGameSessionId = null;
                                          _message = null;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>>(
                                  stream: FirebaseFirestore.instance
                                      .collection('sites')
                                      .snapshots(),
                                  builder: (context, siteSnapshot) {
                                    if (siteSnapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        !siteSnapshot.hasData) {
                                      return DropdownButtonFormField<String>(
                                        value: null,
                                        dropdownColor: const Color(0xFF171E2A),
                                        decoration: InputDecoration(
                                          labelText: 'Choisir le site',
                                          helperText:
                                              'Chargement des sites...',
                                          prefixIcon: _siteLocked
                                              ? const Icon(Icons.lock_outline)
                                              : null,
                                        ),
                                        items: const [],
                                        onChanged: null,
                                      );
                                    }

                                    final rawSiteDocs =
                                        siteSnapshot.data?.docs ?? [];
                                    final siteDocs = [...rawSiteDocs]
                                      ..retainWhere(
                                        (doc) =>
                                            (doc.data()['active'] ?? true) !=
                                            false,
                                      )
                                      ..sort((a, b) {
                                        final aTitle =
                                            (a.data()['title'] ?? a.id)
                                                .toString()
                                                .toLowerCase();
                                        final bTitle =
                                            (b.data()['title'] ?? b.id)
                                                .toString()
                                                .toLowerCase();
                                        return aTitle.compareTo(bTitle);
                                      });

                                    _syncSelectedSiteWithPreferences(siteDocs);

                                    final siteItems = siteDocs
                                        .map(
                                          (doc) => DropdownMenuItem<String>(
                                            value: doc.id,
                                            child: Text(
                                              (doc.data()['title'] ?? doc.id)
                                                  .toString(),
                                            ),
                                          ),
                                        )
                                        .toList();

                                    final defaultExists = _defaultSiteId == null
                                        ? true
                                        : siteDocs.any(
                                            (d) => d.id == _defaultSiteId,
                                          );

                                    if (siteDocs.isEmpty) {
                                      return DropdownButtonFormField<String>(
                                        value: null,
                                        dropdownColor: const Color(0xFF171E2A),
                                        decoration: const InputDecoration(
                                          labelText: 'Choisir le site',
                                          helperText:
                                              'Aucun site disponible dans Firestore.',
                                        ),
                                        items: const [],
                                        onChanged: null,
                                      );
                                    }

                                    return DropdownButtonFormField<String>(
                                      value: siteDocs.any(
                                        (d) => d.id == _selectedSiteId,
                                      )
                                          ? _selectedSiteId
                                          : null,
                                      dropdownColor: const Color(0xFF171E2A),
                                      decoration: InputDecoration(
                                        labelText: 'Choisir le site',
                                        helperText: _siteLocked
                                            ? defaultExists
                                                ? 'Site verrouillé sur ce poste'
                                                : 'Site verrouillé, mais le site par défaut mémorisé n’est plus actif'
                                            : _defaultSiteId != null
                                                ? defaultExists
                                                    ? 'Site prérempli pour ce poste'
                                                    : 'Le site par défaut mémorisé n’est plus actif'
                                                : null,
                                        prefixIcon: _siteLocked
                                            ? const Icon(Icons.lock_outline)
                                            : null,
                                      ),
                                      items: siteItems,
                                      onChanged: _siteLocked
                                          ? null
                                          : (value) {
                                              setState(() {
                                                _selectedSiteId = value;
                                                _currentCode = null;
                                                _currentGameSessionId = null;
                                                _message = null;
                                              });
                                            },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _portalController,
                              builder: (context, child) {
                                final portalGlow = hasCode
                                    ? 14 + (_portalController.value * 22)
                                    : 0.0;

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: hasCode
                                        ? const Color(0xFF1A2435)
                                        : const Color(0xFF101722),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: hasCode
                                          ? const Color(0xFFD65A00)
                                          : const Color(0xFF263243),
                                      width: hasCode ? 1.6 : 1,
                                    ),
                                    boxShadow: hasCode
                                        ? [
                                            BoxShadow(
                                              color: const Color(0x44D65A00),
                                              blurRadius: portalGlow,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : const [],
                                  ),
                                  child: Center(
                                    child: _loading
                                        ? const Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                color: Color(0xFFD65A00),
                                              ),
                                              SizedBox(height: 18),
                                              Text(
                                                'Création de la session en cours...',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          )
                                        : hasCode
                                            ? Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Text(
                                                    'Code à donner au client',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFFFFD7B8),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 22),
                                                  SelectableText(
                                                    _currentCode!,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 82,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      letterSpacing: 3,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  if (_currentGameSessionId != null)
                                                    SelectableText(
                                                      'Session: $_currentGameSessionId',
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Color(0xFFAED0FF),
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  if (_message != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                      child: Text(
                                                        _message!,
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 3,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 17,
                                                          color:
                                                              Color(0xFFFFB24A),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              )
                                            : Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .confirmation_number_outlined,
                                                    size: 72,
                                                    color: Color(0xFF9AA7BC),
                                                  ),
                                                  const SizedBox(height: 18),
                                                  const Text(
                                                    'Prêt à attribuer un code',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 38,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  if (_message != null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                      child: Text(
                                                        _message!,
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 3,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 17,
                                                          color:
                                                              Color(0xFF9AA7BC),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (hasCode)
                            FilledButton.icon(
                              onPressed: _prepareNextCode,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFD65A00),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(Icons.refresh),
                              label: const Text(
                                'Attribuer un autre code',
                                style: TextStyle(fontSize: 16),
                              ),
                            )
                          else
                            FilledButton.icon(
                              onPressed: _getCode,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFD65A00),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(Icons.confirmation_number),
                              label: const Text(
                                'Attribuer un code',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

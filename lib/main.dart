import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'firebase_options.dart';
import 'constants/app_constants.dart';
import 'screens/home_screen.dart'; // 🔥 IMPORTANT
import 'screens/activation_screen.dart';
import 'services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _hasValidSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final isValid = await SessionService.isSessionValid();

    setState(() {
      _hasValidSession = isValid;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kScenarioName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: _isLoading
          ? const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      )
          : _hasValidSession
          ? const HomeScreen() // ✅ RETOUR AU JEU NORMAL
          : ActivationScreen(
        nextScreen: const HomeScreen(), // ✅ idem ici
      ),
    );
  }
}
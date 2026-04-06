import 'package:flutter/material.dart';

import 'screens/portal_gate_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portail HENIGMA Grid',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD65A00),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0D14),
        cardTheme: CardThemeData(
          color: const Color(0xFF131A24),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: Color(0xFF222B38)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F141D),
          surfaceTintColor: Color(0xFF0F141D),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF171E2A),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF2A3443)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF2A3443)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFFD65A00),
              width: 1.6,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF233041)),
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF9AA7BC),
            fontWeight: FontWeight.w600,
          ),
          helperStyle: const TextStyle(
            color: Color(0xFF6F7C90),
            fontSize: 12,
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFD65A00);
            }
            return const Color(0xFF9AA7BC);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF6A3410);
            }
            return const Color(0xFF253142);
          }),
        ),
      ),
      home: const PortalGateScreen(),
    );
  }
}

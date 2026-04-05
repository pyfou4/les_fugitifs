import 'package:flutter/material.dart';

class AdminIntroSection extends StatelessWidget {
  const AdminIntroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenue sur le portail HENIGMA Grid',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Le stock de codes est pensé comme un pool global.\nLe site et le jeu sont enregistrés au moment de l’émission en caisse.',
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Color(0xFF9AA7BC),
          ),
        ),
        SizedBox(height: 28),
        Text(
          'Dashboard activations',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Suivi du pool global, génération des lots et configuration du poste caissier.',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF9AA7BC),
          ),
        ),
      ],
    );
  }
}

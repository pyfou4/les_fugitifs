import 'package:flutter/material.dart';

class LampScreen extends StatefulWidget {
  const LampScreen({super.key});
  @override
  State<LampScreen> createState() => _LampScreenState();
}

class _LampScreenState extends State<LampScreen> {
  bool on = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lampe')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => setState(() => on = !on),
          child: Text(on ? 'Éteindre' : 'Allumer'),
        ),
      ),
    );
  }
}

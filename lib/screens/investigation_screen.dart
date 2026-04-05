import 'package:flutter/material.dart';

import '../models/suspect_model.dart';
import '../models/motive_model.dart';

class InvestigationScreen extends StatelessWidget {
  final VoidCallback onBack;

  final List<SuspectModel> suspects;
  final List<MotiveModel> motives;

  final Set<String> markedSuspectIds;
  final Set<String> markedMotiveIds;

  final ValueChanged<String> onToggleSuspect;
  final ValueChanged<String> onToggleMotive;

  const InvestigationScreen({
    super.key,
    required this.onBack,
    required this.suspects,
    required this.motives,
    required this.markedSuspectIds,
    required this.markedMotiveIds,
    required this.onToggleSuspect,
    required this.onToggleMotive,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enquête'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: Row(
        children: [
          // 👤 SUSPECTS
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Suspects',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: suspects.length,
                    itemBuilder: (_, index) {
                      final suspect = suspects[index];
                      final isMarked =
                      markedSuspectIds.contains(suspect.id);

                      return CheckboxListTile(
                        value: isMarked,
                        onChanged: (_) =>
                            onToggleSuspect(suspect.id),
                        title: Text(
                          suspect.name,
                          style: TextStyle(
                            color: isMarked
                                ? Colors.grey
                                : Colors.black,
                            decoration: isMarked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          '${suspect.age} ans • ${suspect.profession}',
                          style: TextStyle(
                            color: isMarked
                                ? Colors.grey
                                : Colors.black,
                            decoration: isMarked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 1),

          // ⚖️ MOTIVES
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Mobiles',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: motives.length,
                    itemBuilder: (_, index) {
                      final motive = motives[index];
                      final isMarked =
                      markedMotiveIds.contains(motive.id);

                      return CheckboxListTile(
                        value: isMarked,
                        onChanged: (_) =>
                            onToggleMotive(motive.id),
                        title: Text(
                          motive.name,
                          style: TextStyle(
                            color: isMarked
                                ? Colors.grey
                                : Colors.black,
                            decoration: isMarked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          '${motive.preparations} • ${motive.violence}',
                          style: TextStyle(
                            color: isMarked
                                ? Colors.grey
                                : Colors.black,
                            decoration: isMarked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
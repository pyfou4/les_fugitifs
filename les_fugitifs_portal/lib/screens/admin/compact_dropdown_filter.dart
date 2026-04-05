import 'package:flutter/material.dart';

class CompactDropdownFilter extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final List<DropdownMenuItem<String?>> items;
  final String allLabel;
  final ValueChanged<String?> onChanged;

  const CompactDropdownFilter({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.allLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF171E2A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF2A3443),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF9AA7BC),
          ),
          const SizedBox(width: 8),
          Text(
            '$label : ',
            style: const TextStyle(
              color: Color(0xFF9AA7BC),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: value,
              dropdownColor: const Color(0xFF171E2A),
              borderRadius: BorderRadius.circular(18),
              iconEnabledColor: const Color(0xFFFFD7B8),
              style: const TextStyle(
                color: Color(0xFFFFD7B8),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(allLabel),
                ),
                ...items,
              ],
              onChanged: (newValue) {
                onChanged(newValue);
              },
            ),
          ),
        ],
      ),
    );
  }
}

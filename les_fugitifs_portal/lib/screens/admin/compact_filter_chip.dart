import 'package:flutter/material.dart';

class CompactFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPassive;

  const CompactFilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPassive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Material(
      color: isPassive
          ? const Color(0xFF171E2A)
          : enabled
              ? const Color(0xFF171E2A)
              : const Color(0xFF111722),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isPassive
                  ? const Color(0xFF2A3443)
                  : enabled
                      ? const Color(0xFF4A2B1D)
                      : const Color(0xFF222B38),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isPassive
                    ? const Color(0xFF9AA7BC)
                    : enabled
                        ? const Color(0xFFFFD7B8)
                        : const Color(0xFF586478),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPassive
                      ? const Color(0xFF9AA7BC)
                      : enabled
                          ? const Color(0xFFFFD7B8)
                          : const Color(0xFF586478),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

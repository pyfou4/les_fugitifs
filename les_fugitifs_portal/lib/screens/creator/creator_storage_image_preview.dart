import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class CreatorStorageImagePreview extends StatelessWidget {
  final String? storagePath;
  final double width;
  final double height;
  final double borderRadius;
  final String emptyLabel;

  const CreatorStorageImagePreview({
    super.key,
    required this.storagePath,
    required this.width,
    required this.height,
    this.borderRadius = 16,
    this.emptyLabel = 'PNG',
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = storagePath?.trim() ?? '';

    if (trimmed.isEmpty) {
      return _placeholder(
        icon: Icons.image_not_supported_outlined,
        label: emptyLabel,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: FutureBuilder<Uint8List?>(
        future: FirebaseStorage.instance.ref(trimmed).getData(2 * 1024 * 1024),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: width,
              height: height,
              color: const Color(0xFF0F1A2A),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
            return _placeholder(
              icon: Icons.broken_image_outlined,
              label: 'Introuvable',
            );
          }

          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _placeholder(
                icon: Icons.broken_image_outlined,
                label: 'Introuvable',
              );
            },
          );
        },
      ),
    );
  }

  Widget _placeholder({required IconData icon, required String label}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A2A),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFF223250)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFAAB7C8), size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFAAB7C8),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:typed_data';

class PickedCreatorImage {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const PickedCreatorImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
}

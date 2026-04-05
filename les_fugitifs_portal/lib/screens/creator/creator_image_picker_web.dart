import 'dart:html' as html;
import 'dart:typed_data';

import 'creator_image_picker_model.dart';

Future<PickedCreatorImage?> pickPngImageImpl() async {
  final input = html.FileUploadInputElement()
    ..accept = '.png,image/png';

  input.click();
  await input.onChange.first;

  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;

  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoadEnd.first;

  final result = reader.result;
  Uint8List? bytes;

  if (result is ByteBuffer) {
    bytes = Uint8List.view(result);
  } else if (result is Uint8List) {
    bytes = result;
  }

  if (bytes == null || bytes.isEmpty) return null;

  return PickedCreatorImage(
    bytes: bytes,
    fileName: file.name,
    mimeType: file.type.isNotEmpty ? file.type : 'image/png',
  );
}

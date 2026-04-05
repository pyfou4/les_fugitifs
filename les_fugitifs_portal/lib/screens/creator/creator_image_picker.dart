import 'creator_image_picker_model.dart';
import 'creator_image_picker_stub.dart'
    if (dart.library.html) 'creator_image_picker_web.dart' as impl;

Future<PickedCreatorImage?> pickPngImage() {
  return impl.pickPngImageImpl();
}

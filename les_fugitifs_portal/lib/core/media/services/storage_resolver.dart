import 'package:firebase_storage/firebase_storage.dart';

class StorageResolver {
  final FirebaseStorage storage;

  StorageResolver({
    FirebaseStorage? storage,
  }) : storage = storage ?? FirebaseStorage.instance;

  Reference referenceFromPath(String storagePath) {
    return storage.ref().child(storagePath);
  }

  Future<String> resolveDownloadUrl(String storagePath) async {
    return referenceFromPath(storagePath).getDownloadURL();
  }
}

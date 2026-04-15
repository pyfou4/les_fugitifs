import 'package:firebase_storage/firebase_storage.dart';

class StorageUrlResolver {
  StorageUrlResolver(this._storage);

  final FirebaseStorage _storage;

  Future<String> resolveDownloadUrl(String storagePath) {
    return _storage.ref(storagePath).getDownloadURL();
  }
}

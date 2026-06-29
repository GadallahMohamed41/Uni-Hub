import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadPdf({
    required Uint8List bytes,
    required String storagePath,
  }) async {
    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(contentType: 'application/pdf');
    await ref.putData(bytes, metadata);
    return ref.getDownloadURL();
  }

  Future<void> deleteByPath(String storagePath) async {
    final ref = _storage.ref(storagePath);
    await ref.delete();
  }
}


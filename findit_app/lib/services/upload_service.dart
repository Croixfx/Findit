import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class UploadService {
  static final _storage = FirebaseStorage.instance;

  static Future<String?> uploadFile(String localPath, String storagePath) async {
    try {
      final file = File(localPath);
      final ref = _storage.ref().child(storagePath);
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> uploadItemPhoto(String localPath) {
    final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    return uploadFile(localPath, 'items/$name');
  }

  static Future<String?> uploadClaimProof(String localPath) {
    final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    return uploadFile(localPath, 'claims/$name');
  }
}

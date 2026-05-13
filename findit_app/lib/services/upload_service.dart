import 'dart:io';
import 'cloudinary_service.dart';

class UploadService {
  static Future<String> uploadItemPhoto(String localPath) =>
      CloudinaryService.uploadImage(File(localPath));

  static Future<String> uploadClaimProof(String localPath) =>
      CloudinaryService.uploadImage(File(localPath));
}

import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import 'auth_service.dart';

class UploadService {
  static final _authService = AuthService();

  static Future<String> uploadFile(String localPath, String folder) async {
    final token = await _authService.getIdToken();
    if (token == null) throw Exception('Not authenticated');

    final file = File(localPath);
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['folder'] = folder;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      final json = jsonDecode(body);
      final url = json['url'] as String?;
      if (url == null || url.isEmpty) throw Exception('Upload succeeded but no URL returned');
      return url;
    }

    String message = 'Upload failed';
    try {
      final json = jsonDecode(body);
      message = json['message'] ?? message;
    } catch (_) {}
    throw Exception(message);
  }

  static Future<String> uploadItemPhoto(String localPath) =>
      uploadFile(localPath, 'items');

  static Future<String> uploadClaimProof(String localPath) =>
      uploadFile(localPath, 'claims');
}

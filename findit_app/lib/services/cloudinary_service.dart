import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CloudinaryService {
  static const String _cloudName = 'dwjvtxwsu';
  static const String _uploadPreset = 'findit_uploads';

  static Future<String> uploadImage(File imageFile) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final ext = imageFile.path.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? MediaType('image', 'png') : MediaType('image', 'jpeg');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: contentType,
      ));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final url = json['secure_url'] as String?;
      if (url == null || url.isEmpty) throw Exception('No URL in Cloudinary response');
      return url;
    }

    String message = 'Upload failed (${streamed.statusCode})';
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      message = json['error']?['message'] ?? message;
    } catch (_) {}
    throw Exception(message);
  }
}

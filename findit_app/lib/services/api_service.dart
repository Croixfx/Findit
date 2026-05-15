import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';
import 'cache_service.dart';

class ApiService {
  final _authService = AuthService();

  Future<Map<String, String>> getHeaders() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String endpoint, {bool useCache = true}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: await getHeaders())
          .timeout(const Duration(seconds: 12));
      final data = _decode(response);
      if (useCache) await CacheService.set(endpoint, data);
      return data;
    } on SocketException {
      return _fallbackToCache(endpoint, 'No internet — showing saved data');
    } on TimeoutException {
      return _fallbackToCache(endpoint, 'Network is slow — showing saved data');
    } on http.ClientException {
      return _fallbackToCache(endpoint, 'Network error — showing saved data');
    }
  }

  Future<dynamic> _fallbackToCache(String endpoint, String message) async {
    final cached = await CacheService.get(endpoint);
    throw NetworkException(message, cachedData: cached);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await getHeaders(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: await getHeaders(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: await getHeaders(),
    );
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body.isNotEmpty ? jsonDecode(body) : null;
    }
    final message = _extractError(body);
    throw ApiException(response.statusCode, message);
  }

  String _extractError(String body) {
    try {
      final json = jsonDecode(body);
      return json['message'] ?? json['error'] ?? 'Request failed';
    } catch (_) {
      return body.isNotEmpty ? body : 'Request failed';
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException implements Exception {
  final String message;
  final dynamic cachedData;
  const NetworkException(this.message, {this.cachedData});
  bool get hasCache => cachedData != null;
  @override
  String toString() => message;
}

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../authentication service/auth_store.dart';

class HttpClient {
  static String? _token;

  /// This method will be called from AuthStore to initialize or update the token
  static void setup(AuthStore authStore) {
    _token = authStore.token;
  }

  /// Generic GET request
  static Future<http.Response> get(String url) async {
    final headers = _buildHeaders();
    return await http.get(Uri.parse(url), headers: headers);
  }

  /// Generic POST request
  static Future<http.Response> post(String url, Map<String, dynamic> body) async {
    final headers = _buildHeaders();
    return await http.post(Uri.parse(url),
        headers: headers, body: jsonEncode(body));
  }

  /// Build headers (adds Authorization if token is available)
  static Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token!',
    };
  }
}

// utils/network.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class Api {
  final String baseUrl;
  final String token;
  Api(this.baseUrl, this.token);

  Future<http.Response> post(String path, Map body) {
    final url = Uri.parse('$baseUrl$path');
    return http.post(url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: json.encode(body)
    );
  }

  Future<http.Response> get(String path) {
    final url = Uri.parse('$baseUrl$path');
    return http.get(url, headers: {'Authorization':'Bearer $token'});
  }
}

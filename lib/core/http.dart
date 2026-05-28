// lib/core/http.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../authentication service/api_services.dart';
import '../authentication service/auth_store.dart';
import 'config.dart';

class HttpClient {
  static String? _token;
  static bool _isRefreshing = false;

  static String get baseUrl => AppConfig.apiBaseUrl;
  static Duration get timeout => Duration(milliseconds: AppConfig.apiTimeout);

  /// Called from AuthStore to initialize or update the current token.
  static void setup(AuthStore authStore) {
    _token = authStore.token;
  }

  /// Force reload token from SharedPreferences.
  static Future<void> reloadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AuthService.kAccessToken);
  }

  /// Generic GET request.
  static Future<http.Response> get(
      String url, {
        Map<String, String>? headers,
        Map<String, String>? queryParams,
        bool auth = true,
        bool retryOnUnauthorized = true,
      }) async {
    return _send(
      method: 'GET',
      url: url,
      headers: headers,
      queryParams: queryParams,
      auth: auth,
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }

  /// Generic POST request.
  static Future<http.Response> post(
      String url,
      Map<String, dynamic> body, {
        Map<String, String>? headers,
        Map<String, String>? queryParams,
        bool auth = true,
        bool retryOnUnauthorized = true,
      }) async {
    return _send(
      method: 'POST',
      url: url,
      body: body,
      headers: headers,
      queryParams: queryParams,
      auth: auth,
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }

  /// Generic PUT request.
  static Future<http.Response> put(
      String url,
      Map<String, dynamic> body, {
        Map<String, String>? headers,
        Map<String, String>? queryParams,
        bool auth = true,
        bool retryOnUnauthorized = true,
      }) async {
    return _send(
      method: 'PUT',
      url: url,
      body: body,
      headers: headers,
      queryParams: queryParams,
      auth: auth,
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }

  /// Generic PATCH request.
  static Future<http.Response> patch(
      String url,
      Map<String, dynamic> body, {
        Map<String, String>? headers,
        Map<String, String>? queryParams,
        bool auth = true,
        bool retryOnUnauthorized = true,
      }) async {
    return _send(
      method: 'PATCH',
      url: url,
      body: body,
      headers: headers,
      queryParams: queryParams,
      auth: auth,
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }

  /// Generic DELETE request.
  static Future<http.Response> delete(
      String url, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
        Map<String, String>? queryParams,
        bool auth = true,
        bool retryOnUnauthorized = true,
      }) async {
    return _send(
      method: 'DELETE',
      url: url,
      body: body,
      headers: headers,
      queryParams: queryParams,
      auth: auth,
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }

  /// JSON helper for GET.
  static Future<Map<String, dynamic>> getJson(
      String url, {
        Map<String, String>? headers,
        Map<String, String>? queryParams,
        bool auth = true,
      }) async {
    final response = await get(
      url,
      headers: headers,
      queryParams: queryParams,
      auth: auth,
    );

    return _decodeOrThrow(response);
  }

  /// JSON helper for POST.
  static Future<Map<String, dynamic>> postJson(
      String url,
      Map<String, dynamic> body, {
        Map<String, String>? headers,
        Map<String, String>? queryParams,
        bool auth = true,
      }) async {
    final response = await post(
      url,
      body,
      headers: headers,
      queryParams: queryParams,
      auth: auth,
    );

    return _decodeOrThrow(response);
  }

  /// JSON helper for PUT.
  static Future<Map<String, dynamic>> putJson(
      String url,
      Map<String, dynamic> body, {
        Map<String, String>? headers,
        Map<String, String>? queryParams,
        bool auth = true,
      }) async {
    final response = await put(
      url,
      body,
      headers: headers,
      queryParams: queryParams,
      auth: auth,
    );

    return _decodeOrThrow(response);
  }

  /// JSON helper for PATCH.
  static Future<Map<String, dynamic>> patchJson(
      String url,
      Map<String, dynamic> body, {
        Map<String, String>? headers,
        Map<String, String>? queryParams,
        bool auth = true,
      }) async {
    final response = await patch(
      url,
      body,
      headers: headers,
      queryParams: queryParams,
      auth: auth,
    );

    return _decodeOrThrow(response);
  }

  /// JSON helper for DELETE.
  static Future<Map<String, dynamic>> deleteJson(
      String url, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
        Map<String, String>? queryParams,
        bool auth = true,
      }) async {
    final response = await delete(
      url,
      body: body,
      headers: headers,
      queryParams: queryParams,
      auth: auth,
    );

    return _decodeOrThrow(response);
  }

  // ═══════════════════════════════════════════════════════════════
  // CORE REQUEST SENDER
  // ═══════════════════════════════════════════════════════════════

  static Future<http.Response> _send({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    bool auth = true,
    bool retryOnUnauthorized = true,
  }) async {
    await reloadToken();

    final uri = _buildUri(url, queryParams);

    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🌐 [HTTP] $method $uri');
    debugPrint('   auth: $auth');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    var response = await _rawRequest(
      method: method,
      uri: uri,
      body: body,
      headers: headers,
      auth: auth,
    );

    debugPrint('📥 [HTTP] Response status: ${response.statusCode}');

    if (
    auth &&
        retryOnUnauthorized &&
        _shouldRefresh(response) &&
        !_isAuthEndpoint(uri)
    ) {
      debugPrint('⚠️ [HTTP] Access token expired/stale. Trying refresh...');

      final refreshed = await _refreshTokenSafely();

      if (refreshed) {
        await reloadToken();

        debugPrint('✅ [HTTP] Token refreshed. Retrying original request...');

        response = await _rawRequest(
          method: method,
          uri: uri,
          body: body,
          headers: headers,
          auth: auth,
        );

        debugPrint('📥 [HTTP] Retry response status: ${response.statusCode}');
      } else {
        debugPrint('❌ [HTTP] Refresh failed. Returning original 401 response.');
      }
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    return response;
  }

  static Future<http.Response> _rawRequest({
    required String method,
    required Uri uri,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool auth = true,
  }) async {
    final requestHeaders = await _buildHeaders(
      extraHeaders: headers,
      auth: auth,
    );

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          return await http
              .get(uri, headers: requestHeaders)
              .timeout(timeout);

        case 'POST':
          return await http
              .post(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
              .timeout(timeout);

        case 'PUT':
          return await http
              .put(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
              .timeout(timeout);

        case 'PATCH':
          return await http
              .patch(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
              .timeout(timeout);

        case 'DELETE':
          return await http
              .delete(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
              .timeout(timeout);

        default:
          throw HttpClientException(
            message: 'Unsupported HTTP method: $method',
            statusCode: 0,
            code: 'UNSUPPORTED_METHOD',
          );
      }
    } on SocketException {
      throw HttpClientException(
        message: 'No internet connection',
        statusCode: 0,
        code: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      throw HttpClientException(
        message: 'Request timeout',
        statusCode: 0,
        code: 'TIMEOUT',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TOKEN REFRESH
  // ═══════════════════════════════════════════════════════════════

  static Future<bool> _refreshTokenSafely() async {
    if (_isRefreshing) {
      debugPrint('⏳ [HTTP] Refresh already in progress. Waiting...');
      await Future.delayed(const Duration(milliseconds: 600));
      await reloadToken();
      return _token != null && _token!.isNotEmpty;
    }

    _isRefreshing = true;

    try {
      final ok = await AuthService().refreshAccessToken();

      if (ok) {
        await reloadToken();
      }

      return ok;
    } finally {
      _isRefreshing = false;
    }
  }

  static bool _shouldRefresh(http.Response response) {
    if (response.statusCode != 401) return false;

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map) return true;

      final code = decoded['code']?.toString();

      if (decoded['shouldRefresh'] == true) return true;

      return code == 'TOKEN_EXPIRED' ||
          code == 'MODE_TOKEN_STALE' ||
          code == 'STATUS_TOKEN_STALE';
    } catch (_) {
      return true;
    }
  }

  static bool _isAuthEndpoint(Uri uri) {
    final path = uri.path;

    return path.contains('/auth/login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/logout') ||
        path.contains('/auth/signup') ||
        path.contains('/auth/otp');
  }

  // ═══════════════════════════════════════════════════════════════
  // HEADERS / URI / RESPONSE
  // ═══════════════════════════════════════════════════════════════

  static Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool auth = true,
  }) async {
    await reloadToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?extraHeaders,
    };

    if (auth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  static Uri _buildUri(String url, Map<String, String>? queryParams) {
    final cleanUrl = url.trim();

    Uri uri;

    if (
    cleanUrl.startsWith('http://') ||
        cleanUrl.startsWith('https://')
    ) {
      uri = Uri.parse(cleanUrl);
    } else {
      final normalizedBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      final normalizedPath = cleanUrl.startsWith('/')
          ? cleanUrl
          : '/$cleanUrl';

      uri = Uri.parse('$normalizedBase$normalizedPath');
    }

    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    return uri;
  }

  static Map<String, dynamic> _decodeOrThrow(http.Response response) {
    Map<String, dynamic> decoded;

    try {
      final raw = jsonDecode(response.body);

      if (raw is Map<String, dynamic>) {
        decoded = raw;
      } else if (raw is Map) {
        decoded = Map<String, dynamic>.from(raw);
      } else {
        decoded = {
          'success': false,
          'message': 'Invalid response format',
          'data': raw,
        };
      }
    } catch (_) {
      decoded = {
        'success': false,
        'message': response.body,
      };
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw HttpClientException(
      message: decoded['message']?.toString() ?? 'Request failed',
      statusCode: response.statusCode,
      code: decoded['code']?.toString(),
      response: decoded,
    );
  }
}

class HttpClientException implements Exception {
  final String message;
  final int statusCode;
  final String? code;
  final Map<String, dynamic>? response;

  HttpClientException({
    required this.message,
    required this.statusCode,
    this.code,
    this.response,
  });

  @override
  String toString() {
    return 'HttpClientException($statusCode, $code): $message';
  }
}
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';

enum GoogleAuthRole {
  passenger,
  driver,
}

extension GoogleAuthRoleValue on GoogleAuthRole {
  String get apiValue {
    switch (this) {
      case GoogleAuthRole.passenger:
        return 'passenger';
      case GoogleAuthRole.driver:
        return 'driver';
    }
  }
}

class GoogleAuthResult {
  final bool success;
  final String? idToken;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? photoUrl;
  final Map<String, dynamic>? data;
  final String? message;
  final String? code;

  const GoogleAuthResult({
    required this.success,
    this.idToken,
    this.email,
    this.firstName,
    this.lastName,
    this.photoUrl,
    this.data,
    this.message,
    this.code,
  });
}

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  static const String _serverClientId =
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  Future<void> initialize() async {
    if (_initialized) return;

    await _googleSignIn.initialize(
      serverClientId: _serverClientId,
    );

    _initialized = true;
  }

  Future<GoogleAuthResult> pickGoogleAccountOnly() async {
    await initialize();

    try {
      final account = await _googleSignIn.authenticate();
      final authentication = account.authentication;
      final idToken = authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        return const GoogleAuthResult(
          success: false,
          message: 'Google ID token not received.',
          code: 'NO_GOOGLE_ID_TOKEN',
        );
      }

      final names = account.displayName?.trim().split(RegExp(r'\s+')) ?? [];

      return GoogleAuthResult(
        success: true,
        idToken: idToken,
        email: account.email,
        firstName: names.isNotEmpty ? names.first : '',
        lastName: names.length > 1 ? names.sublist(1).join(' ') : '',
        photoUrl: account.photoUrl,
      );
    } catch (e) {
      debugPrint('❌ [GOOGLE] Account picker failed: $e');
      return GoogleAuthResult(
        success: false,
        message: 'Google Sign-In cancelled or failed.',
        code: 'GOOGLE_SIGNIN_FAILED',
      );
    }
  }

  // The backend exposes a single endpoint: POST /auth/google.
  //   • LOGIN  → omit user_type; the existing account's role is used.
  //   • SIGNUP → send user_type PASSENGER or DRIVER to create that account.

  /// Role-agnostic login for a returning user (passenger OR driver).
  /// If no account is linked yet, the backend returns GOOGLE_ACCOUNT_NOT_FOUND
  /// so the UI can prompt the user to sign up and choose a role.
  Future<GoogleAuthResult> loginWithGoogle() async {
    final picked = await pickGoogleAccountOnly();
    if (!picked.success || picked.idToken == null) return picked;

    return _sendGoogleToken(
      payload: {'id_token': picked.idToken},
    );
  }

  /// Create (or link) a PASSENGER account with Google.
  Future<GoogleAuthResult> registerPassengerWithGoogle() async {
    final picked = await pickGoogleAccountOnly();
    if (!picked.success || picked.idToken == null) return picked;

    return _sendGoogleToken(
      payload: {'id_token': picked.idToken, 'user_type': 'PASSENGER'},
    );
  }

  /// Create (or link) a DRIVER account with Google. The driver still has to
  /// complete their profile/documents and be approved before they can work.
  Future<GoogleAuthResult> registerDriverWithGoogle() async {
    final picked = await pickGoogleAccountOnly();
    if (!picked.success || picked.idToken == null) return picked;

    return _sendGoogleToken(
      payload: {'id_token': picked.idToken, 'user_type': 'DRIVER'},
    );
  }

  Future<GoogleAuthResult> _sendGoogleToken({
    required Map<String, dynamic> payload,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/google');

      final response = await http.post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final body = jsonDecode(response.body);

      if (body is! Map<String, dynamic>) {
        return const GoogleAuthResult(
          success: false,
          message: 'Invalid response from server.',
          code: 'INVALID_RESPONSE',
        );
      }

      return GoogleAuthResult(
        success: response.statusCode >= 200 &&
            response.statusCode < 300 &&
            body['success'] == true,
        data: body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : null,
        message: body['message']?.toString(),
        code: body['code']?.toString(),
      );
    } catch (e) {
      debugPrint('❌ [GOOGLE] Backend auth failed: $e');
      return GoogleAuthResult(
        success: false,
        message: 'Google authentication failed. Please try again.',
        code: 'GOOGLE_AUTH_FAILED',
      );
    }
  }
}
// lib/services/google_auth_service.dart

import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

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

class GoogleAuthResponse {
  final bool success;
  final String? token;
  final Map<String, dynamic>? user;
  final String? message;

  GoogleAuthResponse({
    required this.success,
    this.token,
    this.user,
    this.message,
  });

  factory GoogleAuthResponse.fromJson(Map<String, dynamic> json) {
    return GoogleAuthResponse(
      success: json['success'] == true,
      token: json['token']?.toString(),
      user: json['user'] is Map<String, dynamic>
          ? json['user'] as Map<String, dynamic>
          : null,
      message: json['message']?.toString(),
    );
  }
}

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _initialized = false;

  // Replace this with your real backend base URL.
  static const String _baseUrl = 'https://your-api-domain.com/api';

  // This must be the Web OAuth Client ID from Google Cloud Console.
  static const String _serverClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  Future<void> initialize() async {
    if (_initialized) return;

    await _googleSignIn.initialize(
      serverClientId: _serverClientId,
    );

    _initialized = true;
  }

  Future<GoogleAuthResponse> continueWithGoogle({
    required GoogleAuthRole role,
  }) async {
    await initialize();

    if (!_googleSignIn.supportsAuthenticate()) {
      return GoogleAuthResponse(
        success: false,
        message: 'Google Sign-In is not supported on this platform.',
      );
    }

    try {
      final GoogleSignInAccount account =
      await _googleSignIn.authenticate();

      final GoogleSignInAuthentication authentication =
          account.authentication;

      final String? idToken = authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        return GoogleAuthResponse(
          success: false,
          message: 'Google ID token not received.',
        );
      }

      final Uri url = Uri.parse('$_baseUrl/auth/google');

      final http.Response response = await http.post(
        url,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id_token': idToken,
          'role': role.apiValue,
        }),
      );

      final Map<String, dynamic> body =
      jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return GoogleAuthResponse.fromJson(body);
      }

      return GoogleAuthResponse(
        success: false,
        message: body['message']?.toString() ?? 'Google authentication failed.',
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return GoogleAuthResponse(
          success: false,
          message: 'Google sign-in cancelled.',
        );
      }

      return GoogleAuthResponse(
        success: false,
        message: e.description ?? 'Google sign-in failed.',
      );
    } catch (e) {
      return GoogleAuthResponse(
        success: false,
        message: 'Unexpected Google authentication error.',
      );
    }
  }

  Future<void> signOutFromGoogle() async {
    await initialize();
    await _googleSignIn.signOut();
  }
}
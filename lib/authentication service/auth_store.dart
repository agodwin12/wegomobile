// lib/authentication service/auth_store.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wego_v1/authentication%20service/api_services.dart';

import '../core/http.dart';

class AuthStore extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user;

  String? get token => _accessToken; // Backward compatibility
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  Map<String, dynamic>? get user => _user;

  bool get hasToken => (_accessToken ?? '').isNotEmpty;
  bool get hasRefreshToken => (_refreshToken ?? '').isNotEmpty;
  bool get isAuthenticated => hasRefreshToken;

  String get userType => (_user?['user_type'] ?? '').toString();
  String get activeMode {
    final mode = (_user?['active_mode'] ?? '').toString();

    if (mode.isNotEmpty) return mode;

    switch (userType) {
      case 'PASSENGER':
        return 'PASSENGER';
      case 'DRIVER':
        return 'DRIVER';
      case 'DELIVERY_AGENT':
        return 'DELIVERY_AGENT';
      default:
        return '';
    }
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();

    _accessToken = sp.getString(AuthService.kAccessToken);
    _refreshToken = sp.getString(AuthService.kRefreshToken);

    final userJson = sp.getString(AuthService.kUserData);
    _user = _decodeUser(userJson);

    HttpClient.setup(this);
    notifyListeners();
  }

  Future<void> reload() async {
    await load();
  }

  Future<void> setToken(String token) async {
    final sp = await SharedPreferences.getInstance();

    await sp.setString(AuthService.kAccessToken, token);
    _accessToken = token;

    HttpClient.setup(this);
    notifyListeners();
  }

  Future<void> setSession({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? user,
  }) async {
    final sp = await SharedPreferences.getInstance();

    await sp.setString(AuthService.kAccessToken, accessToken);
    await sp.setString(AuthService.kRefreshToken, refreshToken);

    if (user != null) {
      await sp.setString(AuthService.kUserData, jsonEncode(user));
      _user = user;
    }

    _accessToken = accessToken;
    _refreshToken = refreshToken;

    HttpClient.setup(this);
    notifyListeners();
  }

  Future<bool> restoreSession() async {
    final restored = await AuthService().restoreSession();
    await load();
    return restored;
  }

  Future<bool> refresh() async {
    final refreshed = await AuthService().refreshAccessToken();
    await load();
    return refreshed;
  }

  Future<void> clear() async {
    await AuthService().clearSession();

    _accessToken = null;
    _refreshToken = null;
    _user = null;

    HttpClient.setup(this);
    notifyListeners();
  }

  Future<void> logout({
    bool logoutAll = false,
    bool callBackend = true,
  }) async {
    await AuthService().logout(
      logoutAll: logoutAll,
      callBackend: callBackend,
    );

    _accessToken = null;
    _refreshToken = null;
    _user = null;

    HttpClient.setup(this);
    notifyListeners();
  }

  Map<String, dynamic>? _decodeUser(String? userJson) {
    if (userJson == null || userJson.isEmpty) return null;

    try {
      final decoded = jsonDecode(userJson);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
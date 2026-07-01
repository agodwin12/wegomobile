// lib/services/auth_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';

// ── Socket services — imported so we can push the new token to them
// immediately after a refresh, before any retry happens.
import '../service/api/service_socket_listener.dart';
import '../service/driverSocketService.dart';

class AuthService {
  // ═══════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════════

  static String get baseUrl => AppConfig.apiBaseUrl;
  static Duration get timeout => Duration(milliseconds: AppConfig.apiTimeout);

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  // ═══════════════════════════════════════════════════════════════
  // STORAGE KEYS
  // ═══════════════════════════════════════════════════════════════

  static const String kAccessToken  = 'access_token';
  static const String kRefreshToken = 'refresh_token';
  static const String kUserData     = 'user_data';

  static const String kUserUuid    = 'user_uuid';
  static const String kUserType    = 'user_type';
  static const String kUserEmail   = 'user_email';
  static const String kUserPhone   = 'user_phone';
  static const String kFirstName   = 'first_name';
  static const String kLastName    = 'last_name';
  static const String kCivility    = 'civility';
  static const String kBirthDate   = 'birth_date';
  static const String kStatus      = 'status';
  static const String kAvatarUrl   = 'avatar_url';
  static const String kActiveMode  = 'active_mode';

  static const String kEmailVerified = 'email_verified';
  static const String kPhoneVerified = 'phone_verified';

  static const String kProfileData  = 'profile_data';
  static const String kAddressText  = 'address_text';
  static const String kNotes        = 'notes';

  static const String kCniNumber        = 'cni_number';
  static const String kLicenseNumber    = 'license_number';
  static const String kLicenseExpiry    = 'license_expiry';
  static const String kInsuranceNumber  = 'insurance_number';
  static const String kInsuranceExpiry  = 'insurance_expiry';
  static const String kVehicleType      = 'vehicle_type';
  static const String kVehicleMakeModel = 'vehicle_make_model';
  static const String kVehicleColor     = 'vehicle_color';
  static const String kVehicleYear      = 'vehicle_year';
  static const String kVehiclePlate     = 'vehicle_plate';
  static const String kVerificationState = 'verification_state';
  static const String kIsOnline     = 'is_online';
  static const String kIsAvailable  = 'is_available';

  static const String kDriverId    = 'driver_id';
  static const String kCurrentMode = 'current_mode';
  static const String kWalletData  = 'wallet_data';
  static const String kWalletBalance = 'wallet_balance';

  static const String kLegacyJwtToken = 'jwt_token';

  // ═══════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════

  String _normalizeEndpoint(String endpoint) {
    var clean = endpoint.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;
    if (clean.startsWith('/')) clean = clean.substring(1);
    return '$baseUrl/$clean';
  }

  String _modeFromUserType(String userType) {
    switch (userType) {
      case 'PASSENGER':       return 'PASSENGER';
      case 'DRIVER':          return 'DRIVER';
      case 'DELIVERY_AGENT':  return 'DELIVERY_AGENT';
      default:                return userType;
    }
  }

  bool _shouldRefreshFromResponse(http.Response response) {
    if (response.statusCode != 401) return false;
    try {
      final decoded = jsonDecode(response.body);
      final code    = decoded['code']?.toString();
      if (decoded['shouldRefresh'] == true) return true;
      return code == 'TOKEN_EXPIRED'     ||
          code == 'MODE_TOKEN_STALE'  ||
          code == 'STATUS_TOKEN_STALE';
    } catch (_) {
      return true;
    }
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': false, 'message': 'Invalid response format', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Invalid JSON response from server', 'raw': response.body};
    }
  }

  AuthException _exceptionFromResponse(http.Response response) {
    final data = _decodeJsonResponse(response);
    return AuthException(
      message:    data['message']?.toString() ?? 'Request failed',
      statusCode: response.statusCode,
      errorCode:  data['code']?.toString(),
    );
  }

  Future<void> _saveStringIfNotNull(SharedPreferences prefs, String key, dynamic value) async {
    if (value == null) return;
    await prefs.setString(key, value.toString());
  }

  Future<void> _saveBoolIfNotNull(SharedPreferences prefs, String key, dynamic value) async {
    if (value == null) return;
    if (value is bool)   { await prefs.setBool(key, value); return; }
    if (value is String) { await prefs.setBool(key, value.toLowerCase() == 'true'); return; }
  }

  Future<void> _saveDoubleIfNotNull(SharedPreferences prefs, String key, dynamic value) async {
    if (value == null) return;
    if (value is num)  { await prefs.setDouble(key, value.toDouble()); return; }
    final parsed = double.tryParse(value.toString());
    if (parsed != null) await prefs.setDouble(key, parsed);
  }

  // ═══════════════════════════════════════════════════════════════
  // SESSION STORAGE
  // ═══════════════════════════════════════════════════════════════

  Future<void> saveSessionFromAuthData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    final accessToken  = data['access_token']?.toString();
    final refreshToken = data['refresh_token']?.toString();

    if (accessToken == null || accessToken.isEmpty) {
      throw AuthException(message: 'No access token received from server', statusCode: 500, errorCode: 'NO_ACCESS_TOKEN');
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      throw AuthException(message: 'No refresh token received from server', statusCode: 500, errorCode: 'NO_REFRESH_TOKEN');
    }

    final rawUser = data['user'];
    final Map<String, dynamic> user = rawUser is Map ? Map<String, dynamic>.from(rawUser) : {};

    _accessToken  = accessToken;
    _refreshToken = refreshToken;

    await prefs.setString(kAccessToken,  accessToken);
    await prefs.setString(kRefreshToken, refreshToken);
    await prefs.setString(kUserData,     jsonEncode(user));

    final userType    = (user['user_type']   ?? '').toString().trim();
    final activeMode  = (user['active_mode'] ?? '').toString().trim();
    final resolvedMode = activeMode.isNotEmpty ? activeMode : _modeFromUserType(userType);

    await _saveStringIfNotNull(prefs, kUserUuid,   user['uuid']);
    await _saveStringIfNotNull(prefs, kUserType,   userType);
    await _saveStringIfNotNull(prefs, kUserEmail,  user['email']);
    await _saveStringIfNotNull(prefs, kUserPhone,  user['phone_e164']);
    await _saveStringIfNotNull(prefs, kFirstName,  user['first_name']);
    await _saveStringIfNotNull(prefs, kLastName,   user['last_name']);
    await _saveStringIfNotNull(prefs, kCivility,   user['civility']);
    await _saveStringIfNotNull(prefs, kBirthDate,  user['birth_date']);
    await _saveStringIfNotNull(prefs, kStatus,     user['status']);
    await _saveStringIfNotNull(prefs, kAvatarUrl,  user['avatar_url']);

    if (resolvedMode.isNotEmpty) await prefs.setString(kActiveMode, resolvedMode);

    await _saveBoolIfNotNull(prefs, kEmailVerified, user['email_verified']);
    await _saveBoolIfNotNull(prefs, kPhoneVerified, user['phone_verified']);

    final profileRaw = user['profile'];
    if (profileRaw is Map) {
      final profile = Map<String, dynamic>.from(profileRaw);
      await prefs.setString(kProfileData, jsonEncode(profile));

      if (userType == 'PASSENGER') {
        await _saveStringIfNotNull(prefs, kAddressText, profile['address_text']);
        await _saveStringIfNotNull(prefs, kNotes,       profile['notes']);
      }

      if (userType == 'DRIVER') {
        await _saveStringIfNotNull(prefs, kCniNumber,         profile['cni_number']);
        await _saveStringIfNotNull(prefs, kLicenseNumber,     profile['license_number']);
        await _saveStringIfNotNull(prefs, kLicenseExpiry,     profile['license_expiry']);
        await _saveStringIfNotNull(prefs, kInsuranceNumber,   profile['insurance_number']);
        await _saveStringIfNotNull(prefs, kInsuranceExpiry,   profile['insurance_expiry']);
        await _saveStringIfNotNull(prefs, kVehicleType,       profile['vehicle_type']);
        await _saveStringIfNotNull(prefs, kVehicleMakeModel,  profile['vehicle_make_model']);
        await _saveStringIfNotNull(prefs, kVehicleColor,      profile['vehicle_color']);
        await _saveStringIfNotNull(prefs, kVehicleYear,       profile['vehicle_year']);
        await _saveStringIfNotNull(prefs, kVehiclePlate,      profile['vehicle_plate']);
        await _saveStringIfNotNull(prefs, kVerificationState, profile['verification_state']);
        await _saveBoolIfNotNull(prefs, kIsOnline,    profile['is_online']);
        await _saveBoolIfNotNull(prefs, kIsAvailable, profile['is_available']);
      }
    }

    final dynamic agentRaw = user['delivery_agent'] ?? user['driver_record'];
    if (userType == 'DELIVERY_AGENT' && agentRaw is Map) {
      final agent = Map<String, dynamic>.from(agentRaw);
      await _saveStringIfNotNull(prefs, kDriverId,        agent['driver_id'] ?? agent['id']);
      await _saveStringIfNotNull(prefs, kVehicleMakeModel, agent['vehicle_make_model']);
      await _saveStringIfNotNull(prefs, kCurrentMode,     agent['current_mode'] ?? 'delivery');
      final driverStatus = (agent['status'] ?? 'offline').toString();
      await prefs.setBool(kIsOnline, driverStatus == 'online');
      final walletRaw = agent['wallet'] ?? agent['delivery_wallet'];
      if (walletRaw is Map) {
        final wallet = Map<String, dynamic>.from(walletRaw);
        await prefs.setString(kWalletData, jsonEncode(wallet));
        await _saveDoubleIfNotNull(prefs, kWalletBalance, wallet['balance']);
      }
    }

    // ── FIX: push the new token to ALL active socket connections ─────────
    // This must happen AFTER the token is saved to prefs so that any
    // socket reconnect that reads from prefs also gets the fresh value.
    _notifySocketsOfNewToken(accessToken);
    // ─────────────────────────────────────────────────────────────────────

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('💾 [AUTH SERVICE] Session saved');
    debugPrint('   user_type   : $userType');
    debugPrint('   active_mode : $resolvedMode');
    debugPrint('   access      : ✅');
    debugPrint('   refresh     : ✅');
    debugPrint('   sockets     : notified ✅');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  /// Pushes the new token to every socket singleton that is currently alive.
  /// Each service decides whether to update auth headers in-place or
  /// reconnect — the caller doesn't need to know the details.
  void _notifySocketsOfNewToken(String newToken) {
    try {
      // Driver socket (ride-hailing)
      DriverSocketService().updateAuthToken(newToken);
      debugPrint('🔑 [AUTH SERVICE] DriverSocketService token updated');
    } catch (e) {
      debugPrint('⚠️ [AUTH SERVICE] DriverSocketService update failed: $e');
    }

    try {
      // Services marketplace socket
      ServiceSocketListener.instance.updateAuthToken(newToken);
      debugPrint('🔑 [AUTH SERVICE] ServiceSocketListener token updated');
    } catch (e) {
      debugPrint('⚠️ [AUTH SERVICE] ServiceSocketListener update failed: $e');
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    final keys = <String>[
      kAccessToken, kRefreshToken, kUserData,
      kUserUuid, kUserType, kUserEmail, kUserPhone,
      kFirstName, kLastName, kCivility, kBirthDate,
      kStatus, kAvatarUrl, kActiveMode,
      kEmailVerified, kPhoneVerified,
      kProfileData, kAddressText, kNotes,
      kCniNumber, kLicenseNumber, kLicenseExpiry,
      kInsuranceNumber, kInsuranceExpiry,
      kVehicleType, kVehicleMakeModel, kVehicleColor,
      kVehicleYear, kVehiclePlate, kVerificationState,
      kIsOnline, kIsAvailable,
      kDriverId, kCurrentMode, kWalletData, kWalletBalance,
      kLegacyJwtToken,
    ];

    for (final key in keys) await prefs.remove(key);

    _accessToken  = null;
    _refreshToken = null;

    debugPrint('✅ [AUTH SERVICE] Local session cleared');
  }

  // ═══════════════════════════════════════════════════════════════
  // PASSENGER SIGNUP
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> signupPassenger({
    required Map<String, dynamic> data,
    File? avatarFile,
  }) async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚖 [AUTH SERVICE] Passenger Signup Request');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final uri     = Uri.parse('$baseUrl/auth/signup/passenger');
      final request = http.MultipartRequest('POST', uri);

      data.forEach((key, value) {
        if (value != null) request.fields[key] = value.toString();
      });

      if (avatarFile != null) {
        final fileSize = await avatarFile.length();
        if (fileSize > 5 * 1024 * 1024) {
          throw AuthException(message: 'Image file is too large. Maximum size is 5MB.', statusCode: 400, errorCode: 'FILE_TOO_LARGE');
        }
        request.files.add(await http.MultipartFile.fromPath('avatar', avatarFile.path));
      }

      final streamedResponse = await request.send().timeout(timeout);
      final response         = await http.Response.fromStream(streamedResponse);
      final jsonResponse     = _decodeJsonResponse(response);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        debugPrint('✅ [AUTH SERVICE] Passenger signup successful');
        return jsonResponse;
      }

      throw AuthException(
        message: jsonResponse['message']?.toString() ?? 'Signup failed',
        statusCode: response.statusCode,
        errorCode:  jsonResponse['code']?.toString(),
      );
    } on SocketException {
      throw AuthException(message: 'No internet connection. Please check your network.', statusCode: 0, errorCode: 'NETWORK_ERROR');
    } on TimeoutException {
      throw AuthException(message: 'Request timeout. Please try again.', statusCode: 0, errorCode: 'TIMEOUT');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString(), statusCode: 0, errorCode: 'UNKNOWN_ERROR');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // DRIVER SIGNUP
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> signupDriver({
    required Map<String, dynamic> data,
    File? avatarFile,
    File? licenseFile,
    File? insuranceFile,
    File? vehiclePhotoFile,
  }) async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚗 [AUTH SERVICE] Driver Signup Request');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      if (licenseFile == null) {
        throw AuthException(message: 'Driver license document is required', statusCode: 400, errorCode: 'MISSING_LICENSE_DOCUMENT');
      }

      final uri     = Uri.parse('$baseUrl/auth/signup/driver');
      final request = http.MultipartRequest('POST', uri);

      data.forEach((key, value) {
        if (value != null) request.fields[key] = value.toString();
      });

      if (avatarFile != null)      await _addFileToRequest(request, avatarFile,      'avatar');
      await _addFileToRequest(request, licenseFile, 'license');
      if (insuranceFile != null)   await _addFileToRequest(request, insuranceFile,   'insurance');
      if (vehiclePhotoFile != null) await _addFileToRequest(request, vehiclePhotoFile, 'vehicle_photo');

      final streamedResponse = await request.send().timeout(timeout);
      final response         = await http.Response.fromStream(streamedResponse);
      final jsonResponse     = _decodeJsonResponse(response);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        debugPrint('✅ [AUTH SERVICE] Driver signup successful');
        return jsonResponse;
      }

      throw AuthException(
        message: jsonResponse['message']?.toString() ?? 'Signup failed',
        statusCode: response.statusCode,
        errorCode:  jsonResponse['code']?.toString(),
      );
    } on SocketException {
      throw AuthException(message: 'No internet connection. Please check your network.', statusCode: 0, errorCode: 'NETWORK_ERROR');
    } on TimeoutException {
      throw AuthException(message: 'Request timeout. Please try again.', statusCode: 0, errorCode: 'TIMEOUT');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString(), statusCode: 0, errorCode: 'UNKNOWN_ERROR');
    }
  }

  Future<void> _addFileToRequest(http.MultipartRequest request, File file, String fieldName) async {
    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) {
      throw AuthException(message: 'File is too large. Maximum size is 10MB.', statusCode: 400, errorCode: 'FILE_TOO_LARGE');
    }
    request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
  }

  // ═══════════════════════════════════════════════════════════════
  // OTP
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> sendOtp({
    required String identifier,
    required String channel,
    required String purpose,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/otp/send'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'identifier': identifier, 'channel': channel, 'purpose': purpose}),
      ).timeout(timeout);

      final jsonResponse = _decodeJsonResponse(response);
      if (response.statusCode == 200 && jsonResponse['success'] == true) return jsonResponse;

      throw AuthException(message: jsonResponse['message']?.toString() ?? 'Failed to send OTP', statusCode: response.statusCode, errorCode: jsonResponse['code']?.toString());
    } on SocketException {
      throw AuthException(message: 'No internet connection', statusCode: 0, errorCode: 'NETWORK_ERROR');
    } on TimeoutException {
      throw AuthException(message: 'Request timeout', statusCode: 0, errorCode: 'TIMEOUT');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString(), statusCode: 0, errorCode: 'UNKNOWN_ERROR');
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String identifier,
    required String purpose,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/otp/verify'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'identifier': identifier, 'purpose': purpose, 'code': code}),
      ).timeout(timeout);

      final jsonResponse = _decodeJsonResponse(response);
      if (response.statusCode == 200 && jsonResponse['success'] == true) return jsonResponse;

      throw AuthException(message: jsonResponse['message']?.toString() ?? 'Invalid OTP code', statusCode: response.statusCode, errorCode: jsonResponse['code']?.toString());
    } on SocketException {
      throw AuthException(message: 'No internet connection', statusCode: 0, errorCode: 'NETWORK_ERROR');
    } on TimeoutException {
      throw AuthException(message: 'Request timeout', statusCode: 0, errorCode: 'TIMEOUT');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(message: e.toString(), statusCode: 0, errorCode: 'UNKNOWN_ERROR');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGIN
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔐 [AUTH SERVICE] Login started');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📍 API URL: $baseUrl/auth/login');
    debugPrint('📧 Identifier: $identifier');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'identifier': identifier, 'password': password}),
      ).timeout(timeout);

      final responseData = _decodeJsonResponse(response);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final rawData = responseData['data'];
        if (rawData is! Map) {
          throw AuthException(message: 'Invalid login response from server', statusCode: response.statusCode, errorCode: 'INVALID_LOGIN_RESPONSE');
        }
        await saveSessionFromAuthData(Map<String, dynamic>.from(rawData));
        debugPrint('✅ [AUTH SERVICE] Login completed successfully');
        return responseData;
      }

      throw AuthException(message: responseData['message']?.toString() ?? 'Login failed', statusCode: response.statusCode, errorCode: responseData['code']?.toString());
    } on SocketException {
      throw AuthException(message: 'No internet connection', statusCode: 0, errorCode: 'NETWORK_ERROR');
    } on TimeoutException {
      throw AuthException(message: 'Request timeout. Please try again.', statusCode: 0, errorCode: 'TIMEOUT');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(message: 'Login failed: ${e.toString()}', statusCode: 0, errorCode: 'UNKNOWN_ERROR');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // REFRESH TOKEN / RESTORE SESSION
  // ═══════════════════════════════════════════════════════════════

  Future<bool> refreshAccessToken() async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔄 [AUTH SERVICE] Refresh token process started');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final prefs        = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(kRefreshToken);

      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('❌ [AUTH SERVICE] No refresh token found');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(timeout);

      final responseData = _decodeJsonResponse(response);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final rawData = responseData['data'];
        if (rawData is! Map) {
          debugPrint('❌ [AUTH SERVICE] Invalid refresh response shape');
          return false;
        }

        // saveSessionFromAuthData saves tokens to prefs AND calls
        // _notifySocketsOfNewToken — so sockets get the new token
        // before this function returns true.
        await saveSessionFromAuthData(Map<String, dynamic>.from(rawData));

        debugPrint('✅ [AUTH SERVICE] Refresh successful — sockets updated');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        return true;
      }

      debugPrint('❌ [AUTH SERVICE] Refresh failed');
      debugPrint('   Status : ${response.statusCode}');
      debugPrint('   Code   : ${responseData['code']}');
      debugPrint('   Message: ${responseData['message']}');

      final shouldRelogin = responseData['shouldRelogin'] == true      ||
          responseData['code'] == 'INVALID_REFRESH_TOKEN' ||
          responseData['code'] == 'ACCOUNT_NOT_FOUND'     ||
          responseData['code'] == 'ACCOUNT_DELETED';

      if (shouldRelogin) await clearSession();

      return false;
    } on SocketException {
      debugPrint('❌ [AUTH SERVICE] No internet during refresh');
      return false;
    } on TimeoutException {
      debugPrint('❌ [AUTH SERVICE] Refresh timeout');
      return false;
    } catch (e) {
      debugPrint('❌ [AUTH SERVICE] Refresh error: $e');
      return false;
    }
  }

  Future<bool> restoreSession() async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚀 [AUTH SERVICE] Restoring session');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final prefs        = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(kRefreshToken);

    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint('❌ [AUTH SERVICE] No refresh token saved');
      await clearSession();
      return false;
    }

    final refreshed = await refreshAccessToken();
    if (!refreshed) {
      debugPrint('❌ [AUTH SERVICE] Restore failed');
      return false;
    }

    debugPrint('✅ [AUTH SERVICE] Session restored');
    return true;
  }

  // ═══════════════════════════════════════════════════════════════
  // USER DATA / TOKENS
  // ═══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final userJson = prefs.getString(kUserData);
      if (userJson == null || userJson.isEmpty) return null;
      final decoded = jsonDecode(userJson);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (e) {
      debugPrint('❌ [AUTH SERVICE] Error getting user data: $e');
      return null;
    }
  }

  Future<bool>    isLoggedIn()      async { final p = await SharedPreferences.getInstance(); final t = p.getString(kRefreshToken); return t != null && t.isNotEmpty; }
  Future<String?> getAccessToken()  async { final p = await SharedPreferences.getInstance(); _accessToken  = p.getString(kAccessToken);  return _accessToken; }
  Future<String?> getRefreshToken() async { final p = await SharedPreferences.getInstance(); _refreshToken = p.getString(kRefreshToken); return _refreshToken; }

  Future<String?> getActiveMode() async {
    final prefs      = await SharedPreferences.getInstance();
    final activeMode = prefs.getString(kActiveMode);
    if (activeMode != null && activeMode.isNotEmpty) return activeMode;
    final userType = prefs.getString(kUserType) ?? '';
    if (userType.isEmpty) return null;
    return _modeFromUserType(userType);
  }

  Future<String?> getUserType() async { final p = await SharedPreferences.getInstance(); return p.getString(kUserType); }
  Future<String?> getUserUuid() async { final p = await SharedPreferences.getInstance(); return p.getString(kUserUuid); }

  // ═══════════════════════════════════════════════════════════════
  // AUTHENTICATED REQUEST WITH AUTO REFRESH
  // ═══════════════════════════════════════════════════════════════

  Future<http.Response> authenticatedRequest(
      String method,
      String endpoint, {
        Map<String, dynamic>? body,
        Map<String, String>? queryParams,
        bool retryOnUnauthorized = true,
      }) async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔐 [AUTH SERVICE] Authenticated request');
    debugPrint('📡 $method $endpoint');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(kAccessToken);

    var response = await _makeRequest(method, endpoint, token, body, queryParams: queryParams);

    if (retryOnUnauthorized && _shouldRefreshFromResponse(response)) {
      debugPrint('⚠️ [AUTH SERVICE] Token stale/expired, refreshing...');
      final refreshed = await refreshAccessToken();

      if (!refreshed) {
        throw AuthException(message: 'Session expired. Please login again.', statusCode: 401, errorCode: 'SESSION_EXPIRED');
      }

      // refreshAccessToken() → saveSessionFromAuthData() → sockets notified.
      // Now re-read the fresh token from prefs for the retry.
      token    = prefs.getString(kAccessToken);
      response = await _makeRequest(method, endpoint, token, body, queryParams: queryParams);
    }

    return response;
  }

  Future<http.Response> _makeRequest(
      String method,
      String endpoint,
      String? token,
      Map<String, dynamic>? body, {
        Map<String, String>? queryParams,
      }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept':        'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    var uri = Uri.parse(_normalizeEndpoint(endpoint));
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    try {
      switch (method.toUpperCase()) {
        case 'GET':    return await http.get(uri, headers: headers).timeout(timeout);
        case 'POST':   return await http.post(uri,  headers: headers, body: body != null ? jsonEncode(body) : null).timeout(timeout);
        case 'PUT':    return await http.put(uri,   headers: headers, body: body != null ? jsonEncode(body) : null).timeout(timeout);
        case 'PATCH':  return await http.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(timeout);
        case 'DELETE': return await http.delete(uri, headers: headers).timeout(timeout);
        default:
          throw AuthException(message: 'Unsupported HTTP method: $method', statusCode: 0, errorCode: 'UNSUPPORTED_METHOD');
      }
    } on SocketException {
      throw AuthException(message: 'No internet connection', statusCode: 0, errorCode: 'NETWORK_ERROR');
    } on TimeoutException {
      throw AuthException(message: 'Request timeout', statusCode: 0, errorCode: 'TIMEOUT');
    }
  }

  Future<Map<String, dynamic>> authenticatedJsonRequest(
      String method,
      String endpoint, {
        Map<String, dynamic>? body,
        Map<String, String>? queryParams,
      }) async {
    final response = await authenticatedRequest(method, endpoint, body: body, queryParams: queryParams);
    final decoded  = _decodeJsonResponse(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    throw AuthException(message: decoded['message']?.toString() ?? 'Request failed', statusCode: response.statusCode, errorCode: decoded['code']?.toString());
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGOUT
  // ═══════════════════════════════════════════════════════════════

  Future<void> logout({bool logoutAll = false, bool callBackend = true}) async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚪 [AUTH SERVICE] Logging out...');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final prefs        = await SharedPreferences.getInstance();
    final accessToken  = prefs.getString(kAccessToken);
    final refreshToken = prefs.getString(kRefreshToken);

    if (callBackend && accessToken != null && accessToken.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type':  'application/json',
            'Accept':        'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            if (refreshToken != null && refreshToken.isNotEmpty) 'refresh_token': refreshToken,
            'logout_all': logoutAll,
          }),
        ).timeout(timeout);
      } catch (e) {
        debugPrint('⚠️ [AUTH SERVICE] Backend logout failed, clearing local session anyway: $e');
      }
    }

    // Disconnect sockets cleanly on logout
    try { DriverSocketService().disconnect(); } catch (_) {}
    try { ServiceSocketListener.instance.disconnect(); } catch (_) {}

    await clearSession();

    debugPrint('✅ [AUTH SERVICE] Logged out successfully');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
}

// ═══════════════════════════════════════════════════════════════
// CUSTOM EXCEPTION CLASS
// ═══════════════════════════════════════════════════════════════

class AuthException implements Exception {
  final String  message;
  final int?    statusCode;
  final String? errorCode;

  AuthException({required this.message, this.statusCode, this.errorCode});

  @override
  String toString() => message;
}
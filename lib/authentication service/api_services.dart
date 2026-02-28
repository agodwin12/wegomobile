// lib/services/auth_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../core/config.dart';

class AuthService {
  // ═══════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════════════════════════
  static String get baseUrl => AppConfig.apiBaseUrl;
  static Duration get timeout => Duration(milliseconds: AppConfig.apiTimeout);

  String? _accessToken;
  String? _refreshToken;

  // ═══════════════════════════════════════════════════════════════
  // PASSENGER SIGNUP (with optional profile photo)
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> signupPassenger({
    required Map<String, dynamic> data,
    File? avatarFile,
  }) async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚖 [AUTH SERVICE] Passenger Signup Request');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📧 Email: ${data['email'] ?? "N/A"}');
    debugPrint('📱 Phone: ${data['phone_e164'] ?? "N/A"}');
    debugPrint('👤 Name: ${data['first_name']} ${data['last_name']}');
    debugPrint('📸 Avatar: ${avatarFile != null ? "YES" : "NO"}');

    try {
      final uri = Uri.parse('$baseUrl/auth/signup/passenger');

      // ─────────────────────────────────────────────────────────
      // CREATE MULTIPART REQUEST
      // ─────────────────────────────────────────────────────────
      var request = http.MultipartRequest('POST', uri);

      // Add text fields
      data.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      debugPrint('📋 [AUTH SERVICE] Text fields added: ${request.fields.keys.join(", ")}');

      // Add avatar file if provided
      if (avatarFile != null) {
        debugPrint('📸 [AUTH SERVICE] Adding avatar file...');

        // Check file size (max 5MB)
        final fileSize = await avatarFile.length();
        debugPrint('   File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

        if (fileSize > 5 * 1024 * 1024) {
          throw AuthException(
            message: 'Image file is too large. Maximum size is 5MB.',
            statusCode: 400,
            errorCode: 'FILE_TOO_LARGE',
          );
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            avatarFile.path,
          ),
        );

        debugPrint('   ✅ Avatar file added');
      }

      // ─────────────────────────────────────────────────────────
      // SEND REQUEST
      // ─────────────────────────────────────────────────────────
      debugPrint('📤 [AUTH SERVICE] Sending request...');

      final streamedResponse = await request.send().timeout(
        timeout,
        onTimeout: () {
          throw AuthException(
            message: 'Request timeout. Please check your internet connection.',
            statusCode: 0,
            errorCode: 'TIMEOUT',
          );
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 [AUTH SERVICE] Response received');
      debugPrint('   Status: ${response.statusCode}');

      final jsonResponse = json.decode(response.body);

      debugPrint('   Success: ${jsonResponse['success']}');
      debugPrint('   Message: ${jsonResponse['message']}');

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        debugPrint('✅ [AUTH SERVICE] Passenger signup successful!');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        return jsonResponse;
      } else {
        debugPrint('❌ [AUTH SERVICE] Signup failed');
        debugPrint('   Error: ${jsonResponse['message']}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        throw AuthException(
          message: jsonResponse['message'] ?? 'Signup failed',
          statusCode: response.statusCode,
          errorCode: jsonResponse['code'],
        );
      }
    } on SocketException {
      debugPrint('❌ [AUTH SERVICE] No internet connection');
      throw AuthException(
        message: 'No internet connection. Please check your network.',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      debugPrint('❌ [AUTH SERVICE] Request timeout');
      throw AuthException(
        message: 'Request timeout. Please try again.',
        statusCode: 0,
        errorCode: 'TIMEOUT',
      );
    } catch (e) {
      debugPrint('❌ [AUTH SERVICE] Exception: $e\n');
      if (e is AuthException) rethrow;
      throw AuthException(
        message: e.toString(),
        statusCode: 0,
        errorCode: 'UNKNOWN_ERROR',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // DRIVER SIGNUP (with multiple file uploads)
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
    debugPrint('📧 Email: ${data['email'] ?? "N/A"}');
    debugPrint('📱 Phone: ${data['phone_e164'] ?? "N/A"}');
    debugPrint('👤 Name: ${data['first_name']} ${data['last_name']}');
    debugPrint('📸 Avatar: ${avatarFile != null ? "YES" : "NO"}');
    debugPrint('📄 License: ${licenseFile != null ? "YES" : "NO"}');
    debugPrint('📄 Insurance: ${insuranceFile != null ? "YES" : "NO"}');
    debugPrint('🚗 Vehicle Photo: ${vehiclePhotoFile != null ? "YES" : "NO"}');

    try {
      // Validate required files
      if (licenseFile == null) {
        throw AuthException(
          message: 'Driver license document is required',
          statusCode: 400,
          errorCode: 'MISSING_LICENSE_DOCUMENT',
        );
      }

      final uri = Uri.parse('$baseUrl/auth/signup/driver');

      // ─────────────────────────────────────────────────────────
      // CREATE MULTIPART REQUEST
      // ─────────────────────────────────────────────────────────
      var request = http.MultipartRequest('POST', uri);

      // Add text fields
      data.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      debugPrint('📋 [AUTH SERVICE] Text fields added: ${request.fields.keys.join(", ")}');

      // ─────────────────────────────────────────────────────────
      // ADD FILES
      // ─────────────────────────────────────────────────────────

      // Avatar (optional)
      if (avatarFile != null) {
        debugPrint('📸 [AUTH SERVICE] Adding avatar...');
        await _addFileToRequest(request, avatarFile, 'avatar');
        debugPrint('   ✅ Avatar added');
      }

      // License document (REQUIRED)
      debugPrint('📄 [AUTH SERVICE] Adding license document...');
      await _addFileToRequest(request, licenseFile, 'license');
      debugPrint('   ✅ License document added');

      // Insurance document (optional)
      if (insuranceFile != null) {
        debugPrint('📄 [AUTH SERVICE] Adding insurance document...');
        await _addFileToRequest(request, insuranceFile, 'insurance');
        debugPrint('   ✅ Insurance document added');
      }

      // Vehicle photo (optional)
      if (vehiclePhotoFile != null) {
        debugPrint('🚗 [AUTH SERVICE] Adding vehicle photo...');
        await _addFileToRequest(request, vehiclePhotoFile, 'vehicle_photo');
        debugPrint('   ✅ Vehicle photo added');
      }

      // ─────────────────────────────────────────────────────────
      // SEND REQUEST
      // ─────────────────────────────────────────────────────────
      debugPrint('📤 [AUTH SERVICE] Sending request...');

      final streamedResponse = await request.send().timeout(
        timeout,
        onTimeout: () {
          throw AuthException(
            message: 'Request timeout. Please check your internet connection.',
            statusCode: 0,
            errorCode: 'TIMEOUT',
          );
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 [AUTH SERVICE] Response received');
      debugPrint('   Status: ${response.statusCode}');

      final jsonResponse = json.decode(response.body);

      debugPrint('   Success: ${jsonResponse['success']}');
      debugPrint('   Message: ${jsonResponse['message']}');

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        debugPrint('✅ [AUTH SERVICE] Driver signup successful!');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        return jsonResponse;
      } else {
        debugPrint('❌ [AUTH SERVICE] Signup failed');
        debugPrint('   Error: ${jsonResponse['message']}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        throw AuthException(
          message: jsonResponse['message'] ?? 'Signup failed',
          statusCode: response.statusCode,
          errorCode: jsonResponse['code'],
        );
      }
    } on SocketException {
      debugPrint('❌ [AUTH SERVICE] No internet connection');
      throw AuthException(
        message: 'No internet connection. Please check your network.',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      debugPrint('❌ [AUTH SERVICE] Request timeout');
      throw AuthException(
        message: 'Request timeout. Please try again.',
        statusCode: 0,
        errorCode: 'TIMEOUT',
      );
    } catch (e) {
      debugPrint('❌ [AUTH SERVICE] Exception: $e\n');
      if (e is AuthException) rethrow;
      throw AuthException(
        message: e.toString(),
        statusCode: 0,
        errorCode: 'UNKNOWN_ERROR',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER: Add file to multipart request with validation
  // ═══════════════════════════════════════════════════════════════
  Future<void> _addFileToRequest(
      http.MultipartRequest request,
      File file,
      String fieldName,
      ) async {
    // Check file size (max 10MB)
    final fileSize = await file.length();
    debugPrint('   File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

    if (fileSize > 10 * 1024 * 1024) {
      throw AuthException(
        message: 'File is too large. Maximum size is 10MB.',
        statusCode: 400,
        errorCode: 'FILE_TOO_LARGE',
      );
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        file.path,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SEND OTP
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendOtp({
    required String identifier,
    required String channel,
    required String purpose,
  }) async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📨 [AUTH SERVICE] Send OTP Request');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📧 Identifier: $identifier');
    debugPrint('📡 Channel: $channel');
    debugPrint('🎯 Purpose: $purpose');

    try {
      // ✅ FIX: Changed from /auth/send-otp to /auth/otp/send
      final url = Uri.parse('$baseUrl/auth/otp/send');
      debugPrint('🌐 [AUTH SERVICE] Endpoint: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier,
          'channel': channel,
          'purpose': purpose,
        }),
      ).timeout(timeout);

      debugPrint('📥 [AUTH SERVICE] Response status: ${response.statusCode}');
      debugPrint('📦 [AUTH SERVICE] Response body: ${response.body}');

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        debugPrint('✅ [AUTH SERVICE] OTP sent successfully');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        return jsonResponse;
      } else {
        debugPrint('❌ [AUTH SERVICE] Send OTP failed');
        debugPrint('   Error: ${jsonResponse['message']}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        throw AuthException(
          message: jsonResponse['message'] ?? 'Failed to send OTP',
          statusCode: response.statusCode,
          errorCode: jsonResponse['code'],
        );
      }
    } on SocketException {
      debugPrint('❌ [AUTH SERVICE] No internet connection');
      throw AuthException(
        message: 'No internet connection',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      debugPrint('❌ [AUTH SERVICE] Request timeout');
      throw AuthException(
        message: 'Request timeout',
        statusCode: 0,
        errorCode: 'TIMEOUT',
      );
    } catch (e) {
      debugPrint('❌ [AUTH SERVICE] Exception: $e\n');
      if (e is AuthException) rethrow;
      throw AuthException(
        message: e.toString(),
        statusCode: 0,
        errorCode: 'UNKNOWN_ERROR',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // VERIFY OTP
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> verifyOtp({
    required String identifier,
    required String purpose,
    required String code,
  }) async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔍 [AUTH SERVICE] Verify OTP Request');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📧 Identifier: $identifier');
    debugPrint('🎯 Purpose: $purpose');
    debugPrint('🔢 Code: $code');

    try {
      // ✅ FIX: Changed from /auth/verify-otp to /auth/otp/verify
      final url = Uri.parse('$baseUrl/auth/otp/verify');
      debugPrint('🌐 [AUTH SERVICE] Endpoint: $url');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier,
          'purpose': purpose,
          'code': code,
        }),
      ).timeout(timeout);

      debugPrint('📥 [AUTH SERVICE] Response status: ${response.statusCode}');
      debugPrint('📦 [AUTH SERVICE] Response body: ${response.body}');

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        debugPrint('✅ [AUTH SERVICE] OTP verified successfully');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        return jsonResponse;
      } else {
        debugPrint('❌ [AUTH SERVICE] OTP verification failed');
        debugPrint('   Error: ${jsonResponse['message']}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        throw AuthException(
          message: jsonResponse['message'] ?? 'Invalid OTP code',
          statusCode: response.statusCode,
          errorCode: jsonResponse['code'],
        );
      }
    } on SocketException {
      debugPrint('❌ [AUTH SERVICE] No internet connection');
      throw AuthException(
        message: 'No internet connection',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      debugPrint('❌ [AUTH SERVICE] Request timeout');
      throw AuthException(
        message: 'Request timeout',
        statusCode: 0,
        errorCode: 'TIMEOUT',
      );
    } catch (e) {
      debugPrint('❌ [AUTH SERVICE] Exception: $e\n');
      if (e is AuthException) rethrow;
      throw AuthException(
        message: e.toString(),
        statusCode: 0,
        errorCode: 'UNKNOWN_ERROR',
      );
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
    debugPrint('⏱️  Timeout: ${timeout.inSeconds}s');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      ).timeout(timeout);

      debugPrint('📡 [AUTH SERVICE] Response status: ${response.statusCode}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        debugPrint('✅ [AUTH SERVICE] Login API call successful');

        final data = responseData['data'];

        // Store both tokens
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        debugPrint('🎫 [AUTH SERVICE] Tokens extracted');

        // Save to storage
        debugPrint('💾 [AUTH SERVICE] Saving tokens to SharedPreferences...');
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('access_token', _accessToken!);
        debugPrint('   ✅ Access token saved');

        await prefs.setString('refresh_token', _refreshToken!);
        debugPrint('   ✅ Refresh token saved');

        // Save user data
        final userJson = jsonEncode(data['user']);
        await prefs.setString('user_data', userJson);
        debugPrint('   ✅ User data saved');

        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('✅ [AUTH SERVICE] Login completed successfully');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        return responseData;
      } else {
        debugPrint('❌ [AUTH SERVICE] Login failed with status: ${response.statusCode}');
        debugPrint('   Error: ${responseData['message']}');
        debugPrint('   Code: ${responseData['code']}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        throw AuthException(
          message: responseData['message'] ?? 'Login failed',
          statusCode: response.statusCode,
          errorCode: responseData['code'],
        );
      }
    } on SocketException {
      debugPrint('❌ [AUTH SERVICE] Network error - No internet connection');
      throw AuthException(
        message: 'No internet connection',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      debugPrint('❌ [AUTH SERVICE] Request timeout');
      throw AuthException(
        message: 'Request timeout. Please try again.',
        statusCode: 0,
        errorCode: 'TIMEOUT',
      );
    } catch (e) {
      debugPrint('❌ [AUTH SERVICE] Unexpected error: $e\n');
      if (e is AuthException) rethrow;
      throw AuthException(
        message: 'Login failed: ${e.toString()}',
        statusCode: 0,
        errorCode: 'UNKNOWN_ERROR',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // REFRESH TOKEN
  // ═══════════════════════════════════════════════════════════════
  Future<bool> refreshAccessToken() async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔄 [AUTH SERVICE] Refresh token process started');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null) {
        debugPrint('❌ [AUTH SERVICE] No refresh token found');
        return false;
      }

      debugPrint('✅ [AUTH SERVICE] Refresh token found');
      debugPrint('📡 [AUTH SERVICE] Calling refresh token API...');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(timeout);

      debugPrint('📡 [AUTH SERVICE] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ [AUTH SERVICE] Refresh successful');

        final data = jsonDecode(response.body)['data'];

        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        // Update storage
        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);

        debugPrint('✅ [AUTH SERVICE] Tokens updated');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        return true;
      } else {
        debugPrint('❌ [AUTH SERVICE] Refresh failed: ${response.statusCode}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [AUTH SERVICE] Refresh error: $e');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // GET USER DATA FROM STORAGE
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');

      if (userJson != null) {
        return jsonDecode(userJson) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ [AUTH SERVICE] Error getting user data: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CHECK IF USER IS LOGGED IN
  // ═══════════════════════════════════════════════════════════════
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') != null;
  }

  // ═══════════════════════════════════════════════════════════════
  // GET ACCESS TOKEN
  // ═══════════════════════════════════════════════════════════════
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // ═══════════════════════════════════════════════════════════════
  // AUTHENTICATED REQUEST
  // ═══════════════════════════════════════════════════════════════
  Future<http.Response> authenticatedRequest(
      String method,
      String endpoint, {
        Map<String, dynamic>? body,
      }) async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔐 [AUTH SERVICE] Authenticated request');
    debugPrint('📡 $method $endpoint');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');

    if (token != null) {
      debugPrint('✅ [AUTH SERVICE] Access token found');
    } else {
      debugPrint('⚠️ [AUTH SERVICE] No access token');
    }

    var response = await _makeRequest(method, endpoint, token, body);
    debugPrint('📡 [AUTH SERVICE] Response: ${response.statusCode}');

    // If token expired, refresh and retry
    if (response.statusCode == 401) {
      debugPrint('⚠️ [AUTH SERVICE] Token expired, refreshing...');
      final refreshed = await refreshAccessToken();

      if (refreshed) {
        debugPrint('✅ [AUTH SERVICE] Retrying with new token...');
        token = prefs.getString('access_token');
        response = await _makeRequest(method, endpoint, token, body);
      } else {
        debugPrint('❌ [AUTH SERVICE] Refresh failed');
        throw AuthException(
          message: 'Session expired. Please login again.',
          statusCode: 401,
          errorCode: 'SESSION_EXPIRED',
        );
      }
    }

    debugPrint('✅ [AUTH SERVICE] Request completed');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    return response;
  }

  Future<http.Response> _makeRequest(
      String method,
      String endpoint,
      String? token,
      Map<String, dynamic>? body,
      ) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final uri = Uri.parse('$baseUrl/$endpoint');

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          return await http.get(uri, headers: headers).timeout(timeout);

        case 'POST':
          return await http.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);

        case 'PATCH':
          return await http.patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);

        case 'DELETE':
          return await http.delete(uri, headers: headers).timeout(timeout);

        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } on SocketException {
      throw AuthException(
        message: 'No internet connection',
        statusCode: 0,
        errorCode: 'NETWORK_ERROR',
      );
    } on TimeoutException {
      throw AuthException(
        message: 'Request timeout',
        statusCode: 0,
        errorCode: 'TIMEOUT',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGOUT
  // ═══════════════════════════════════════════════════════════════
  Future<void> logout() async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚪 [AUTH SERVICE] Logging out...');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');

    _accessToken = null;
    _refreshToken = null;

    debugPrint('✅ [AUTH SERVICE] Logged out successfully');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
}

// ═══════════════════════════════════════════════════════════════
// CUSTOM EXCEPTION CLASS
// ═══════════════════════════════════════════════════════════════
class AuthException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  AuthException({
    required this.message,
    this.statusCode,
    this.errorCode,
  });

  @override
  String toString() => message;
}
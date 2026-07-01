import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart';
import 'dart:async';  // ✅ For TimeoutException
import 'package:http_parser/http_parser.dart';  // ✅ For MediaType




class ApiService {
  // Get base URL from .env file
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static String get apiTimeout => dotenv.env['API_TIMEOUT'] ?? '30000';



  static Future<Map<String, dynamic>> get(
      String endpoint, {
        String? accessToken,
        Map<String, String>? queryParams,
      }) async {
    // Build URL with query params
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    print('\n📥 [GET] $uri');

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await http.get(uri, headers: headers).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [GET ERROR] $e');
      rethrow;
    }
  }

  /// Generic POST request
  static Future<Map<String, dynamic>> post(
      String endpoint,
      Map<String, dynamic> body, {
        String? accessToken,
      }) async {
    print('\n📤 [POST] $baseUrl$endpoint');
    print('Body: ${json.encode(body)}');

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await http
          .post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      )
          .timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [POST] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [POST ERROR] $e');
      rethrow;
    }
  }

  /// Generic PUT request
  static Future<Map<String, dynamic>> put(
      String endpoint,
      Map<String, dynamic> body, {
        String? accessToken,
      }) async {
    print('\n✏️ [PUT] $baseUrl$endpoint');
    print('Body: ${json.encode(body)}');

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await http
          .put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      )
          .timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [PUT] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [PUT ERROR] $e');
      rethrow;
    }
  }

  /// Generic DELETE request
  static Future<Map<String, dynamic>> delete(
      String endpoint, {
        String? accessToken,
      }) async {
    print('\n🗑️ [DELETE] $baseUrl$endpoint');

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await http
          .delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      )
          .timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [DELETE] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [DELETE ERROR] $e');
      rethrow;
    }
  }

  // Helper method to handle API responses
  static Map<String, dynamic> _handleResponse(http.Response response) {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📥 [API RESPONSE]');
    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return json.decode(response.body);
      } catch (e) {
        print('❌ [PARSE ERROR] Failed to parse response: $e');
        throw Exception('Failed to parse response: $e');
      }
    } else if (response.statusCode == 400) {
      final error = json.decode(response.body);
      print('❌ [BAD REQUEST] ${error['message']}');
      throw Exception(error['message'] ?? 'Bad request');
    } else if (response.statusCode == 401) {
      print('❌ [UNAUTHORIZED] Authentication required');
      throw Exception('Unauthorized. Please login again.');
    } else if (response.statusCode == 403) {
      print('❌ [FORBIDDEN] Access denied');
      throw Exception('Access denied');
    } else if (response.statusCode == 404) {
      print('❌ [NOT FOUND] Resource not found');
      throw Exception('Resource not found');
    } else if (response.statusCode == 409) {
      final error = json.decode(response.body);
      print('❌ [CONFLICT] ${error['message']}');
      throw Exception(error['message'] ?? 'Conflict');
    } else if (response.statusCode == 500) {
      print('❌ [SERVER ERROR] Internal server error');
      throw Exception('Server error. Please try again later.');
    } else {
      print('❌ [HTTP ERROR] Status: ${response.statusCode}');
      throw Exception('Request failed with status: ${response.statusCode}');
    }
  }

  // ==================== AUTHENTICATION ====================

  /// Login user (passenger or driver)
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    print('\n🔐 [LOGIN] Starting login request...');
    print('Identifier: $identifier');
    print('URL: $baseUrl/auth/login');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'identifier': identifier,
          'password': password,
        }),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
        onTimeout: () {
          print('⏱️ [TIMEOUT] Login request timed out');
          throw Exception('Request timeout. Please check your connection.');
        },
      );

      print('✅ [LOGIN] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [LOGIN ERROR] $e');
      rethrow;
    }
  }

  /// Signup passenger with optional avatar
  static Future<Map<String, dynamic>> signupPassenger(
      Map<String, dynamic> payload, {
        File? avatar,
      }) async {
    print('\n📝 [SIGNUP PASSENGER] Starting signup (multipart)...');
    print('URL: $baseUrl/auth/signup/passenger');
    print('Payload: ${json.encode(payload)}');
    print('Avatar: ${avatar != null ? avatar.path : "No image"}');

    try {
      final uri = Uri.parse('$baseUrl/auth/signup/passenger');
      final request = http.MultipartRequest('POST', uri);

      // Add text fields
      payload.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      print('📋 [SIGNUP] Fields added: ${request.fields.keys.join(", ")}');

      // Add avatar if provided
      if (avatar != null) {
        try {
          // ✅ Sanitize filename - remove special characters and spaces
          final originalFileName = basename(avatar.path);
          final extension = originalFileName.split('.').last.toLowerCase();

          // Create clean filename with timestamp
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final sanitizedFileName = 'avatar_$timestamp.$extension';

          print('📸 [SIGNUP] Original filename: $originalFileName');
          print('📸 [SIGNUP] Sanitized filename: $sanitizedFileName');

          // ✅ Read file as bytes to ensure complete upload
          final bytes = await avatar.readAsBytes();
          final fileSizeKB = (bytes.length / 1024).toStringAsFixed(2);
          print('📸 [SIGNUP] File size: $fileSizeKB KB (${bytes.length} bytes)');

          // Validate file size (max 5MB)
          if (bytes.length > 5 * 1024 * 1024) {
            throw Exception('Image is too large. Maximum size is 5MB.');
          }

          // Detect MIME type
          String mimeType = 'image/jpeg'; // default
          if (extension == 'png') {
            mimeType = 'image/png';
          } else if (extension == 'jpg' || extension == 'jpeg') {
            mimeType = 'image/jpeg';
          } else if (extension == 'webp') {
            mimeType = 'image/webp';
          }

          print('📸 [SIGNUP] MIME type: $mimeType');

          // Add file to request
          request.files.add(
            http.MultipartFile.fromBytes(
              'avatar', // Must match backend field name
              bytes,
              filename: sanitizedFileName,
              contentType: MediaType.parse(mimeType),
            ),
          );

          print('✅ [SIGNUP] Avatar file added successfully');
        } catch (e) {
          print('❌ [SIGNUP] Error adding avatar: $e');
          throw Exception('Failed to process avatar image: $e');
        }
      }

      // Send request
      print('📤 [SIGNUP] Sending request...');
      final streamedResponse = await request.send().timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
        onTimeout: () {
          print('⏱️ [TIMEOUT] Request timed out');
          throw Exception('Request timeout. Please check your connection.');
        },
      );

      print('📡 [SIGNUP] Receiving response...');
      final response = await http.Response.fromStream(streamedResponse);

      print('✅ [SIGNUP PASSENGER] Upload completed');
      print('📊 [SIGNUP] Response status: ${response.statusCode}');

      return _handleResponse(response);
    } on SocketException {
      print('❌ [NETWORK ERROR] No internet connection');
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      print('❌ [TIMEOUT] Request timed out');
      throw Exception('Request timeout. Please try again.');
    } catch (e) {
      print('❌ [SIGNUP PASSENGER ERROR] $e');
      rethrow;
    }
  }

  /// Signup driver with multiple file uploads
  static Future<Map<String, dynamic>> signupDriver(
      Map<String, dynamic> payload, {
        File? avatar,
        File? license,
        File? insurance,
        File? vehiclePhoto,
      }) async {
    print('\n🚗 [SIGNUP DRIVER] Starting signup (multipart)...');
    print('URL: $baseUrl/auth/signup/driver');
    print('Payload: ${json.encode(payload)}');
    print('Avatar: ${avatar != null ? "YES" : "NO"}');
    print('License: ${license != null ? "YES" : "NO"}');
    print('Insurance: ${insurance != null ? "YES" : "NO"}');
    print('Vehicle Photo: ${vehiclePhoto != null ? "YES" : "NO"}');

    try {
      // Validate required files
      if (license == null) {
        throw Exception('Driver license document is required');
      }

      final uri = Uri.parse('$baseUrl/auth/signup/driver');
      final request = http.MultipartRequest('POST', uri);

      // Add text fields
      payload.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      print('📋 [SIGNUP DRIVER] Fields added: ${request.fields.keys.join(", ")}');

      // Helper function to add file
      Future<void> addFile(File file, String fieldName, String label) async {
        try {
          // Sanitize filename
          final originalFileName = basename(file.path);
          final extension = originalFileName.split('.').last.toLowerCase();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final sanitizedFileName = '${fieldName}_$timestamp.$extension';

          print('📎 [SIGNUP DRIVER] Adding $label...');
          print('   Original: $originalFileName');
          print('   Sanitized: $sanitizedFileName');

          // Read file as bytes
          final bytes = await file.readAsBytes();
          final fileSizeKB = (bytes.length / 1024).toStringAsFixed(2);
          print('   Size: $fileSizeKB KB');

          // Validate file size (max 10MB)
          if (bytes.length > 10 * 1024 * 1024) {
            throw Exception('$label is too large. Maximum size is 10MB.');
          }

          // Detect MIME type
          String mimeType;
          if (extension == 'pdf') {
            mimeType = 'application/pdf';
          } else if (extension == 'png') {
            mimeType = 'image/png';
          } else if (extension == 'jpg' || extension == 'jpeg') {
            mimeType = 'image/jpeg';
          } else if (extension == 'webp') {
            mimeType = 'image/webp';
          } else {
            mimeType = 'application/octet-stream';
          }

          print('   MIME: $mimeType');

          // Add to request
          request.files.add(
            http.MultipartFile.fromBytes(
              fieldName,
              bytes,
              filename: sanitizedFileName,
              contentType: MediaType.parse(mimeType),
            ),
          );

          print('   ✅ $label added successfully');
        } catch (e) {
          print('   ❌ Error adding $label: $e');
          throw Exception('Failed to process $label: $e');
        }
      }

      // Add files
      if (avatar != null) {
        await addFile(avatar, 'avatar', 'Avatar');
      }

      // License (REQUIRED)
      await addFile(license, 'license', 'License Document');

      if (insurance != null) {
        await addFile(insurance, 'insurance', 'Insurance Document');
      }

      if (vehiclePhoto != null) {
        await addFile(vehiclePhoto, 'vehicle_photo', 'Vehicle Photo');
      }

      // Send request
      print('📤 [SIGNUP DRIVER] Sending request...');
      final streamedResponse = await request.send().timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
        onTimeout: () {
          print('⏱️ [TIMEOUT] Request timed out');
          throw Exception('Request timeout. Please check your connection.');
        },
      );

      print('📡 [SIGNUP DRIVER] Receiving response...');
      final response = await http.Response.fromStream(streamedResponse);

      print('✅ [SIGNUP DRIVER] Upload completed');
      print('📊 [SIGNUP DRIVER] Response status: ${response.statusCode}');

      return _handleResponse(response);
    } on SocketException {
      print('❌ [NETWORK ERROR] No internet connection');
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      print('❌ [TIMEOUT] Request timed out');
      throw Exception('Request timeout. Please try again.');
    } catch (e) {
      print('❌ [SIGNUP DRIVER ERROR] $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> validateCoupon({
    required String token,
    required String code,
    required double fareEstimate,
  }) async {
    debugPrint('\n🎟️ [VALIDATE COUPON] Code: $code | Fare: $fareEstimate XAF');
    debugPrint('URL: $baseUrl/promotions/validate');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/promotions/validate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
        body: json.encode({
          'code':          code,
          'fare_estimate': fareEstimate,
        }),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
        onTimeout: () {
          debugPrint('⏱️ [VALIDATE COUPON] Timed out');
          throw Exception('Request timeout. Please try again.');
        },
      );

      debugPrint('✅ [VALIDATE COUPON] Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      // _handleResponse throws on 4xx/5xx — caller catches and shows error
      return _handleResponse(response);
    } on SocketException {
      debugPrint('❌ [VALIDATE COUPON] No internet');
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      debugPrint('❌ [VALIDATE COUPON ERROR] $e');
      rethrow;
    }
  }



  // ==================== TRIPS ====================

  static Future<Map<String, dynamic>> createTrip({
    required String accessToken,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required String paymentMethod,
    String? vehicleType,   // ← NEW
    String? promoCode,     // ← NEW
  }) async {
    debugPrint('🚕 [CREATE TRIP] Starting trip creation...');
    debugPrint('Pickup: ($pickupLat, $pickupLng) - $pickupAddress');
    debugPrint('Dropoff: ($dropoffLat, $dropoffLng) - $dropoffAddress');
    debugPrint('Payment: $paymentMethod | Vehicle: $vehicleType | Promo: $promoCode');

    final payload = <String, dynamic>{
      'pickupLat':       pickupLat,
      'pickupLng':       pickupLng,
      'pickupAddress':   pickupAddress,
      'dropoffLat':      dropoffLat,
      'dropoffLng':      dropoffLng,
      'dropoffAddress':  dropoffAddress,
      'payment_method':  paymentMethod,
      if (vehicleType != null && vehicleType.isNotEmpty)
        'vehicle_type': vehicleType,
      if (promoCode != null && promoCode.isNotEmpty)
        'promo_code': promoCode,
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
        onTimeout: () {
          debugPrint('⏱️ [CREATE TRIP] Timed out');
          throw Exception('Request timeout. Please check your connection.');
        },
      );

      debugPrint('✅ [CREATE TRIP] Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['error'] == true) {
          throw Exception(data['message'] ?? 'Request failed');
        }
        return data;
      }

      if (response.statusCode >= 400 && response.statusCode < 500) {
        throw Exception(data['message'] ?? data['error'] ?? 'Bad request');
      }

      if (response.statusCode >= 500) {
        throw Exception(data['message'] ?? 'Server error. Please try again later.');
      }

      throw Exception('Unexpected error occurred');
    } catch (e) {
      debugPrint('❌ [CREATE TRIP ERROR] $e');
      rethrow;
    }
  }

  /// Example usage for other API methods:
  static Future<Map<String, dynamic>> getTripDetails({
    required String accessToken,
    required String tripId,
  }) async {
    print('\n🔍 [GET TRIP] Fetching trip details...');
    print('Trip ID: $tripId');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/$tripId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
        onTimeout: () {
          print('⏱️ [TIMEOUT] Get trip request timed out');
          throw Exception('Request timeout. Please try again.');
        },
      );

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      print('❌ [NETWORK ERROR] $e');
      throw Exception('Network error. Please check your connection.');
    }
  }

  /// Cancel trip example
  static Future<Map<String, dynamic>> cancelTrip({
    required String accessToken,
    required String tripId,
    String? reason,
  }) async {
    print('\n❌ [CANCEL TRIP] Canceling trip...');
    print('Trip ID: $tripId');
    print('Reason: ${reason ?? "Not specified"}');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          if (reason != null) 'reason': reason,
        }),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
        onTimeout: () {
          print('⏱️ [TIMEOUT] Cancel trip request timed out');
          throw Exception('Request timeout. Please try again.');
        },
      );

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      print('❌ [NETWORK ERROR] $e');
      throw Exception('Network error. Please check your connection.');
    }
  }

  /// Get active trip
  static Future<Map<String, dynamic>> getActiveTrip({
    required String accessToken,
  }) async {
    print('\n🔍 [GET ACTIVE TRIP] Fetching active trip...');
    print('URL: $baseUrl/trips/active');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/active'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET ACTIVE TRIP] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [GET ACTIVE TRIP ERROR] $e');
      rethrow;
    }
  }



  /// Get trip history
  static Future<Map<String, dynamic>> getTripHistory({
    required String accessToken,
    int page = 1,
    int limit = 20,
  }) async {
    print('\n📜 [GET TRIP HISTORY] Fetching history...');
    print('URL: $baseUrl/trips/history?page=$page&limit=$limit');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/history?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET TRIP HISTORY] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [GET TRIP HISTORY ERROR] $e');
      // Return empty history if fails
      return {
        'success': true,
        'data': {
          'trips': [],
          'pagination': {
            'total': 0,
            'page': page,
            'limit': limit,
            'totalPages': 0,
          }
        }
      };
    }
  }

  /// Get trip events
  static Future<Map<String, dynamic>> getTripEvents({
    required String accessToken,
    required String tripId,
  }) async {
    print('\n📊 [GET TRIP EVENTS] Fetching events for trip: $tripId');
    print('URL: $baseUrl/trips/$tripId/events');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/$tripId/events'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET TRIP EVENTS] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [GET TRIP EVENTS ERROR] $e');
      rethrow;
    }
  }



  // ==================== USER PROFILE ====================

  /// Get user profile
  static Future<Map<String, dynamic>> getUserProfile(String token) async {
    print('\n👤 [GET USER PROFILE] Fetching profile...');
    print('URL: $baseUrl/user/profile');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET USER PROFILE] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [GET USER PROFILE ERROR] $e');
      rethrow;
    }
  }

  /// Update user profile
  static Future<Map<String, dynamic>> updateUserProfile(
      String token,
      Map<String, dynamic> data,
      ) async {
    print('\n✏️ [UPDATE USER PROFILE] Updating profile...');
    print('Data: ${json.encode(data)}');
    print('URL: $baseUrl/user/profile');

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(data),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [UPDATE USER PROFILE] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [UPDATE USER PROFILE ERROR] $e');
      rethrow;
    }
  }

  /// Get user statistics
  static Future<Map<String, dynamic>> getUserStats(String token) async {
    print('\n📊 [GET USER STATS] Fetching statistics...');
    print('URL: $baseUrl/user/stats');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET USER STATS] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('⚠️ [GET USER STATS] Failed, returning default stats: $e');
      return {
        'success': true,
        'data': {
          'total_trips': 0,
          'rating': 0.0,
          'points': 0,
        }
      };
    }
  }

  // ==================== RECENT TRIPS ====================

  /// Get recent trips
  static Future<Map<String, dynamic>> getRecentTrips(String token, {int limit = 10}) async {
    print('\n🕐 [GET RECENT TRIPS] Fetching recent trips...');
    print('URL: $baseUrl/trips/recent?limit=$limit');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trips/recent?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET RECENT TRIPS] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('⚠️ [GET RECENT TRIPS] Failed, returning empty list: $e');
      return {
        'success': true,
        'data': {
          'trips': []
        }
      };
    }
  }

  // ==================== SAVED PLACES ====================

  /// Get saved places
  static Future<Map<String, dynamic>> getSavedPlaces(String token) async {
    print('\n📍 [GET SAVED PLACES] Fetching saved places...');
    print('URL: $baseUrl/places/saved');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/places/saved'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET SAVED PLACES] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('⚠️ [GET SAVED PLACES] Failed, returning empty list: $e');
      return {
        'success': true,
        'data': {
          'places': []
        }
      };
    }
  }

  /// Add saved place
  static Future<Map<String, dynamic>> addSavedPlace(
      String token,
      Map<String, dynamic> placeData,
      ) async {
    print('\n➕ [ADD SAVED PLACE] Adding place...');
    print('Data: ${json.encode(placeData)}');
    print('URL: $baseUrl/places/saved');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/places/saved'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(placeData),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [ADD SAVED PLACE] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [ADD SAVED PLACE ERROR] $e');
      rethrow;
    }
  }

  /// Delete saved place
  static Future<Map<String, dynamic>> deleteSavedPlace(
      String token,
      String placeId,
      ) async {
    print('\n🗑️ [DELETE SAVED PLACE] Deleting place: $placeId');
    print('URL: $baseUrl/places/saved/$placeId');

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/places/saved/$placeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [DELETE SAVED PLACE] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [DELETE SAVED PLACE ERROR] $e');
      rethrow;
    }
  }

  // ==================== PROMOTIONS ====================

  /// Get active promotions
  static Future<Map<String, dynamic>> getActivePromotions(String token) async {
    print('\n🎁 [GET PROMOTIONS] Fetching active promotions...');
    print('URL: $baseUrl/promotions/active');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/promotions/active'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET PROMOTIONS] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('⚠️ [GET PROMOTIONS] Failed, returning empty list: $e');
      return {
        'success': true,
        'data': {
          'promotions': []
        }
      };
    }
  }

  /// Apply promo code
  static Future<Map<String, dynamic>> applyPromoCode(
      String token,
      String promoCode,
      ) async {
    print('\n💰 [APPLY PROMO CODE] Applying code: $promoCode');
    print('URL: $baseUrl/promotions/apply');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/promotions/apply'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'promo_code': promoCode,
        }),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [APPLY PROMO CODE] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [APPLY PROMO CODE ERROR] $e');
      rethrow;
    }
  }

  // ==================== RATINGS & REVIEWS ====================

  /// Rate a trip
  static Future<Map<String, dynamic>> rateTrip(
      String token,
      String tripId,
      int rating,
      String? comment,
      ) async {
    print('\n⭐ [RATE TRIP] Rating trip: $tripId');
    print('Rating: $rating/5');
    print('Comment: ${comment ?? "No comment"}');
    print('URL: $baseUrl/trips/$tripId/rate');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/$tripId/rate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'rating': rating,
          'comment': comment,
        }),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [RATE TRIP] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [RATE TRIP ERROR] $e');
      rethrow;
    }
  }

  // ==================== OTP ====================

  /// Send OTP
  static Future<Map<String, dynamic>> sendOtp({
    required String identifier,
    required String channel,
    required String purpose,
  }) async {
    print('\n📧 [SEND OTP] Sending OTP...');
    print('Identifier: $identifier');
    print('Channel: $channel');
    print('Purpose: $purpose');
    print('URL: $baseUrl/auth/otp/send');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'identifier': identifier,
          'channel': channel,
          'purpose': purpose,
        }),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [SEND OTP] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [SEND OTP ERROR] $e');
      rethrow;
    }
  }

  /// Verify OTP
  static Future<Map<String, dynamic>> verifyOtp({
    required String identifier,
    required String purpose,
    required String code,
  }) async {
    print('\n✅ [VERIFY OTP] Verifying OTP...');
    print('Identifier: $identifier');
    print('Purpose: $purpose');
    print('Code: $code');
    print('URL: $baseUrl/auth/otp/verify');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'identifier': identifier,
          'purpose': purpose,
          'code': code,
        }),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [VERIFY OTP] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [VERIFY OTP ERROR] $e');
      rethrow;
    }
  }

  /// Reset password
  static Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String newPassword,
    required String otpCode,
  }) async {
    print('\n🔑 [RESET PASSWORD] Resetting password...');
    print('Identifier: $identifier');
    print('URL: $baseUrl/auth/password/reset');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'identifier': identifier,
          'new_password': newPassword,
          'otp_code': otpCode,
        }),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [RESET PASSWORD] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [RESET PASSWORD ERROR] $e');
      rethrow;
    }
  }

  /// Refresh token
  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    print('\n🔄 [REFRESH TOKEN] Refreshing access token...');
    print('URL: $baseUrl/auth/refresh');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'refresh_token': refreshToken,
        }),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [REFRESH TOKEN] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [REFRESH TOKEN ERROR] $e');
      rethrow;
    }
  }

  // ==================== WALLET ====================

  /// Get wallet balance
  static Future<Map<String, dynamic>> getWalletBalance(String token) async {
    print('\n💳 [GET WALLET BALANCE] Fetching balance...');
    print('URL: $baseUrl/wallet/balance');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/balance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET WALLET BALANCE] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [GET WALLET BALANCE ERROR] $e');
      rethrow;
    }
  }

  /// Add funds to wallet
  static Future<Map<String, dynamic>> addFunds(
      String token,
      double amount,
      String paymentMethod,
      ) async {
    print('\n💰 [ADD FUNDS] Adding funds to wallet...');
    print('Amount: $amount');
    print('Payment Method: $paymentMethod');
    print('URL: $baseUrl/wallet/add-funds');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/add-funds'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'amount': amount,
          'payment_method': paymentMethod,
        }),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [ADD FUNDS] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [ADD FUNDS ERROR] $e');
      rethrow;
    }
  }

  /// Get wallet transactions
  static Future<Map<String, dynamic>> getWalletTransactions(
      String token,
      {int limit = 20}
      ) async {
    print('\n📊 [GET WALLET TRANSACTIONS] Fetching transactions...');
    print('Limit: $limit');
    print('URL: $baseUrl/wallet/transactions?limit=$limit');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/wallet/transactions?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET WALLET TRANSACTIONS] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [GET WALLET TRANSACTIONS ERROR] $e');
      rethrow;
    }
  }

  // ==================== PAYMENT METHODS ====================

  /// Get payment methods
  static Future<Map<String, dynamic>> getPaymentMethods(String token) async {
    print('\n💳 [GET PAYMENT METHODS] Fetching payment methods...');
    print('URL: $baseUrl/payment/methods');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/methods'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET PAYMENT METHODS] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [GET PAYMENT METHODS ERROR] $e');
      rethrow;
    }
  }

  /// Add payment method
  static Future<Map<String, dynamic>> addPaymentMethod(
      String token,
      Map<String, dynamic> paymentData,
      ) async {
    print('\n➕ [ADD PAYMENT METHOD] Adding payment method...');
    print('Data: ${json.encode(paymentData)}');
    print('URL: $baseUrl/payment/methods');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/methods'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(paymentData),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [ADD PAYMENT METHOD] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [ADD PAYMENT METHOD ERROR] $e');
      rethrow;
    }
  }

  // ==================== SUPPORT ====================

  /// Submit support ticket
  static Future<Map<String, dynamic>> submitSupportTicket(
      String token,
      Map<String, dynamic> ticketData,
      ) async {
    print('\n🎫 [SUBMIT SUPPORT TICKET] Creating ticket...');
    print('Data: ${json.encode(ticketData)}');
    print('URL: $baseUrl/support/tickets');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/support/tickets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(ticketData),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [SUBMIT SUPPORT TICKET] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [SUBMIT SUPPORT TICKET ERROR] $e');
      rethrow;
    }
  }

  /// Get support tickets
  static Future<Map<String, dynamic>> getSupportTickets(String token) async {
    print('\n📋 [GET SUPPORT TICKETS] Fetching tickets...');
    print('URL: $baseUrl/support/tickets');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/support/tickets'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET SUPPORT TICKETS] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [GET SUPPORT TICKETS ERROR] $e');
      rethrow;
    }
  }

  // ==================== NOTIFICATIONS ====================

  /// Get notifications
  static Future<Map<String, dynamic>> getNotifications(
      String token,
      {int limit = 20}
      ) async {
    print('\n🔔 [GET NOTIFICATIONS] Fetching notifications...');
    print('Limit: $limit');
    print('URL: $baseUrl/notifications?limit=$limit');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET NOTIFICATIONS] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [GET NOTIFICATIONS ERROR] $e');
      rethrow;
    }
  }

  /// Get current user's rating (passenger)
  static Future<Map<String, dynamic>> getUserRating(String token) async {
    print('\n⭐ [GET USER RATING] Fetching rating...');
    print('URL: $baseUrl/user/rating');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/rating'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [GET USER RATING] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('⚠️ [GET USER RATING] Failed, returning default: $e');
      // Return default so dashboard doesn't crash if endpoint doesn't exist yet
      return {
        'success': true,
        'data': {
          'average_rating': 5.0,
          'total_ratings': 0,
        }
      };
    }
  }

  /// Get fare estimates for all vehicle types
  static Future<Map<String, dynamic>> getRideFareEstimates({
    required String token,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    print('\n💰 [GET FARE ESTIMATES] Fetching prices...');
    print('URL: $baseUrl/trips/fare-estimates');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trips/fare-estimates'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'pickupLat': pickupLat,
          'pickupLng': pickupLng,
          'dropoffLat': dropoffLat,
          'dropoffLng': dropoffLng,
        }),
      ).timeout(Duration(milliseconds: int.parse(apiTimeout)));

      print('✅ [GET FARE ESTIMATES] Completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [GET FARE ESTIMATES ERROR] $e');
      rethrow;
    }
  }

  /// Mark notification as read
  static Future<Map<String, dynamic>> markNotificationAsRead(
      String token,
      String notificationId,
      ) async {
    print('\n✔️ [MARK NOTIFICATION READ] Marking notification: $notificationId');
    print('URL: $baseUrl/notifications/$notificationId/read');

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
      );

      print('✅ [MARK NOTIFICATION READ] Request completed');
      return _handleResponse(response);
    } catch (e) {
      print('❌ [MARK NOTIFICATION READ ERROR] $e');
      rethrow;
    }
  }
  // ==================== CAMPAY PAYMENTS ====================

  /// POST /api/payments/initiate
  /// Initiates a CamPay mobile money collection for any WeGo vertical.
  /// Phone should be 9 digits e.g. '670000000' (no country code).
  static Future<Map<String, dynamic>> initiatePayment({
    required String accessToken,
    required String vertical,    // 'trip' | 'delivery' | 'service_request' | 'rental'
    required String verticalId,  // trip ID / delivery ID / etc.
    required String phone,       // 9-digit number e.g. '670000000'
  }) async {
    debugPrint('\n💳 [INITIATE PAYMENT] vertical=$vertical id=$verticalId phone=$phone');
    debugPrint('URL: $baseUrl/payments/initiate');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/initiate'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'vertical':    vertical,
          'vertical_id': verticalId,
          'phone':       phone,
        }),
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
        onTimeout: () => throw Exception('Payment request timed out. Please try again.'),
      );
      debugPrint('✅ [INITIATE PAYMENT] Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      // Parse manually — CamPay error codes (ER101, ER301 etc.) come back
      // as 400/503 with a meaningful message we need to surface to Flutter.
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }
      throw Exception(data['message'] ?? 'Payment initiation failed');
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } catch (e) {
      debugPrint('❌ [INITIATE PAYMENT ERROR] $e');
      rethrow;
    }
  }

  /// GET /api/payments/:campayRef/status
  /// Polls the current status of a pending payment.
  /// Used as a fallback when the socket event is missed
  /// (app backgrounded, brief disconnect, etc.).
  static Future<Map<String, dynamic>> checkPaymentStatus({
    required String accessToken,
    required String campayRef,
  }) async {
    debugPrint('\n🔄 [CHECK PAYMENT STATUS] campayRef=$campayRef');
    debugPrint('URL: $baseUrl/payments/$campayRef/status');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payments/$campayRef/status'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type':  'application/json',
        },
      ).timeout(
        Duration(milliseconds: int.parse(apiTimeout)),
        onTimeout: () => throw Exception('Status check timed out.'),
      );
      debugPrint('✅ [CHECK PAYMENT STATUS] Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }
      throw Exception(data['message'] ?? 'Could not check payment status');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      debugPrint('❌ [CHECK PAYMENT STATUS ERROR] $e');
      rethrow;
    }
  }

  /// GET /api/payments/history
  /// Returns paginated WegoPayment records for the authenticated user.
  static Future<Map<String, dynamic>> getPaymentHistory({
    required String accessToken,
    int     page     = 1,
    int     limit    = 20,
    String? vertical,
    String? status,
  }) async {
    debugPrint('\n📋 [GET PAYMENT HISTORY] page=$page limit=$limit');
    try {
      final params = <String, String>{
        'page':  page.toString(),
        'limit': limit.toString(),
        if (vertical != null) 'vertical': vertical,
        if (status   != null) 'status':   status,
      };
      final uri = Uri.parse('$baseUrl/payments/history')
          .replace(queryParameters: params);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type':  'application/json',
        },
      ).timeout(Duration(milliseconds: int.parse(apiTimeout)));
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ [GET PAYMENT HISTORY ERROR] $e');
      return {
        'success': true,
        'data':    [],
        'meta': {
          'total': 0, 'page': page,
          'limit': limit, 'totalPages': 0,
        },
      };
    }
  }

}
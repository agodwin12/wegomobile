// lib/service/rental_api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';

/// Rental API Service
/// Handles all backend communication for vehicle rentals
/// Uses .env configuration for base URL
class RentalApiService {
  // ═══════════════════════════════════════════════════════════════
  // API CONFIGURATION - LOADED FROM .ENV
  // ═══════════════════════════════════════════════════════════════
  static String get baseUrl => AppConfig.apiBaseUrl;
  static Duration get timeoutDuration => Duration(milliseconds: AppConfig.apiTimeout);

  // ═══════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Build standardized API response
  static Map<String, dynamic> _buildResponse({
    required bool success,
    dynamic data,
    String? message,
    String? error,
    int? statusCode,
  }) {
    return {
      'success': success,
      'data': data,
      'message': message,
      'error': error,
      'statusCode': statusCode,
    };
  }

  /// Log API calls in development mode
  static void _logRequest(String method, String endpoint, {Map<String, dynamic>? body}) {
    if (AppConfig.isDevelopment) {
      debugPrint('\n🌐 [$method] $endpoint');
      if (body != null) {
        debugPrint('📦 Body: ${json.encode(body)}');
      }
    }
  }

  /// Log API responses in development mode
  static void _logResponse(int statusCode, dynamic data) {
    if (AppConfig.isDevelopment) {
      debugPrint('✅ Response [$statusCode]: ${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HTTP REQUEST METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Generic GET request
  static Future<Map<String, dynamic>> _get(
      String endpoint,
      String accessToken,
      ) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      _logRequest('GET', endpoint);

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(timeoutDuration);

      _logResponse(response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _buildResponse(
          success: true,
          data: data,
          message: data['message'],
          statusCode: response.statusCode,
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('❌ GET Error: $e');
      return _buildResponse(
        success: false,
        error: 'Connection error: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Generic POST request
  static Future<Map<String, dynamic>> _post(
      String endpoint,
      String accessToken,
      Map<String, dynamic> body,
      ) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      _logRequest('POST', endpoint, body: body);

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(timeoutDuration);

      _logResponse(response.statusCode, response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return _buildResponse(
          success: true,
          data: data,
          message: data['message'],
          statusCode: response.statusCode,
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('❌ POST Error: $e');
      return _buildResponse(
        success: false,
        error: 'Connection error: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Generic PATCH request
  static Future<Map<String, dynamic>> _patch(
      String endpoint,
      String accessToken,
      Map<String, dynamic> body,
      ) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      _logRequest('PATCH', endpoint, body: body);

      final response = await http.patch(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(timeoutDuration);

      _logResponse(response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _buildResponse(
          success: true,
          data: data,
          message: data['message'],
          statusCode: response.statusCode,
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('❌ PATCH Error: $e');
      return _buildResponse(
        success: false,
        error: 'Connection error: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Generic DELETE request
  static Future<Map<String, dynamic>> _delete(
      String endpoint,
      String accessToken,
      ) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      _logRequest('DELETE', endpoint);

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(timeoutDuration);

      _logResponse(response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _buildResponse(
          success: true,
          data: data,
          message: data['message'],
          statusCode: response.statusCode,
        );
      } else {
        return _handleError(response);
      }
    } catch (e) {
      debugPrint('❌ DELETE Error: $e');
      return _buildResponse(
        success: false,
        error: 'Connection error: ${e.toString()}',
        statusCode: 0,
      );
    }
  }

  /// Handle error responses
  static Map<String, dynamic> _handleError(http.Response response) {
    try {
      final errorData = json.decode(response.body);
      debugPrint('❌ Error Response: ${response.statusCode} - ${errorData['error'] ?? errorData['message']}');

      return _buildResponse(
        success: false,
        error: errorData['error'] ?? errorData['message'] ?? 'An error occurred',
        data: errorData,
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('❌ Error Parsing: $e');
      return _buildResponse(
        success: false,
        error: 'Server error: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // VEHICLE ENDPOINTS
  // ═══════════════════════════════════════════════════════════════

  /// Fetch all available vehicles for rent
  /// GET /api/rentals/vehicles/available
  static Future<Map<String, dynamic>> fetchAvailableVehicles(
      String accessToken, {
        String? region,
        String? categoryId,
        double? minPrice,
        double? maxPrice,
        int? seats,
      }) async {
    String endpoint = '/rentals/vehicles/available';

    // Build query parameters
    List<String> queryParams = [];
    if (region != null && region.isNotEmpty) {
      queryParams.add('region=${Uri.encodeComponent(region)}');
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      queryParams.add('categoryId=${Uri.encodeComponent(categoryId)}');
    }
    if (minPrice != null) {
      queryParams.add('minPrice=$minPrice');
    }
    if (maxPrice != null) {
      queryParams.add('maxPrice=$maxPrice');
    }
    if (seats != null) {
      queryParams.add('seats=$seats');
    }

    if (queryParams.isNotEmpty) {
      endpoint += '?${queryParams.join('&')}';
    }

    return await _get(endpoint, accessToken);
  }

  /// Fetch vehicle categories
  /// GET /api/rentals/categories
  static Future<Map<String, dynamic>> fetchCategories(String accessToken) async {
    return await _get('/rentals/categories', accessToken);
  }

  /// Toggle vehicle availability
  /// PATCH /api/rentals/vehicles/:id/availability
  static Future<Map<String, dynamic>> updateVehicleAvailability({
    required String accessToken,
    required String vehicleId,
    required bool availableForRent,
  }) async {
    final body = {'availableForRent': availableForRent};
    return await _patch('/rentals/vehicles/$vehicleId/availability', accessToken, body);
  }

  // ═══════════════════════════════════════════════════════════════
  // RENTAL BOOKING ENDPOINTS
  // ═══════════════════════════════════════════════════════════════

  /// Calculate rental price (before booking)
  /// GET /api/rentals/calculate-price
  static Future<Map<String, dynamic>> calculatePrice({
    required String accessToken,
    required String vehicleId,
    required String rentalType,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final queryParams = [
      'vehicleId=${Uri.encodeComponent(vehicleId)}',
      'rentalType=${Uri.encodeComponent(rentalType)}',
      'startDate=${Uri.encodeComponent(startDate.toIso8601String())}',
      'endDate=${Uri.encodeComponent(endDate.toIso8601String())}',
    ].join('&');

    return await _get('/rentals/calculate-price?$queryParams', accessToken);
  }

  /// Create a new rental booking
  /// POST /api/rentals
  /// Creates rental with PENDING status (requires admin approval)
  static Future<Map<String, dynamic>> createRental({
    required String accessToken,
    required String userId,
    required String vehicleId,
    required String rentalRegion,
    required String rentalType, // HOUR, DAY, WEEK, MONTH
    required DateTime startDate,
    required DateTime endDate,
    String? userNotes,
  }) async {
    final body = {
      'userId': userId,
      'vehicleId': vehicleId,
      'rentalRegion': rentalRegion,
      'rentalType': rentalType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'userNotes': userNotes ?? '',
    };

    return await _post('/rentals', accessToken, body);
  }

  // ═══════════════════════════════════════════════════════════════
  // RENTAL RETRIEVAL ENDPOINTS
  // ═══════════════════════════════════════════════════════════════

  /// Fetch single rental by ID
  /// GET /api/rentals/:id
  static Future<Map<String, dynamic>> fetchRentalById(
      String accessToken,
      String rentalId,
      ) async {
    return await _get('/rentals/$rentalId', accessToken);
  }

  /// Fetch user's rental history
  /// GET /api/rentals/user/:userId
  static Future<Map<String, dynamic>> fetchUserRentals(
      String accessToken,
      String userId,
      ) async {
    return await _get('/rentals/user/$userId', accessToken);
  }

  /// Fetch all rentals (Admin/Employee only)
  /// GET /api/rentals/all
  static Future<Map<String, dynamic>> fetchAllRentals(
      String accessToken, {
        String? status,
        String? contactStatus,
        String? paymentStatus,
      }) async {
    String endpoint = '/rentals/all';

    List<String> queryParams = [];
    if (status != null && status.isNotEmpty) {
      queryParams.add('status=${Uri.encodeComponent(status)}');
    }
    if (contactStatus != null && contactStatus.isNotEmpty) {
      queryParams.add('contactStatus=${Uri.encodeComponent(contactStatus)}');
    }
    if (paymentStatus != null && paymentStatus.isNotEmpty) {
      queryParams.add('paymentStatus=${Uri.encodeComponent(paymentStatus)}');
    }

    if (queryParams.isNotEmpty) {
      endpoint += '?${queryParams.join('&')}';
    }

    return await _get(endpoint, accessToken);
  }

  // ═══════════════════════════════════════════════════════════════
  // RENTAL MANAGEMENT ENDPOINTS (USER)
  // ═══════════════════════════════════════════════════════════════

  /// Cancel rental by user (must be 24+ hours before start)
  /// PATCH /api/rentals/:id/cancel-by-user
  static Future<Map<String, dynamic>> cancelRentalByUser({
    required String accessToken,
    required String rentalId,
    required String reason,
  }) async {
    final body = {'reason': reason};
    return await _patch('/rentals/$rentalId/cancel-by-user', accessToken, body);
  }

  /// Update payment information (on pickup)
  /// PATCH /api/rentals/:id/payment
  static Future<Map<String, dynamic>> updatePayment({
    required String accessToken,
    required String rentalId,
    required String paymentMethod, // cash, orange_money, mtn_momo
    String? transactionRef,
  }) async {
    final body = {
      'paymentMethod': paymentMethod,
      if (transactionRef != null) 'transactionRef': transactionRef,
    };
    return await _patch('/rentals/$rentalId/payment', accessToken, body);
  }

  // ═══════════════════════════════════════════════════════════════
  // RENTAL MANAGEMENT ENDPOINTS (ADMIN/EMPLOYEE)
  // ═══════════════════════════════════════════════════════════════

  /// Update rental contact status (Admin/Employee)
  /// PATCH /api/rentals/:id/contact-status
  static Future<Map<String, dynamic>> updateContactStatus({
    required String accessToken,
    required String rentalId,
    required String contactStatus, // PENDING, CONTACTED, CONFIRMED
  }) async {
    final body = {'contactStatus': contactStatus};
    return await _patch('/rentals/$rentalId/contact-status', accessToken, body);
  }

  /// Mark rental as completed (Admin/Employee)
  /// PATCH /api/rentals/:id/complete
  static Future<Map<String, dynamic>> completeRental(
      String accessToken,
      String rentalId,
      ) async {
    return await _patch('/rentals/$rentalId/complete', accessToken, {});
  }

  /// Cancel rental (Admin/Employee)
  /// DELETE /api/rentals/:id
  static Future<Map<String, dynamic>> cancelRental(
      String accessToken,
      String rentalId,
      ) async {
    return await _delete('/rentals/$rentalId', accessToken);
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Format date for API
  static String formatDateForApi(DateTime date) {
    return date.toIso8601String();
  }

  /// Parse date from API
  static DateTime? parseDateFromApi(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      debugPrint('❌ Date Parse Error: $e');
      return null;
    }
  }

  /// Format price for display
  static String formatPrice(dynamic price) {
    if (price == null) return '0';
    final priceValue = price is String ? double.tryParse(price) ?? 0 : price.toDouble();
    return priceValue.toStringAsFixed(0);
  }

  /// Get rental status color
  static String getRentalStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return 'gold';
      case 'CONFIRMED':
        return 'blue';
      case 'COMPLETED':
        return 'green';
      case 'CANCELLED':
        return 'red';
      default:
        return 'grey';
    }
  }

  /// Get rental status label
  static String getRentalStatusLabel(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return 'Pending Approval';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  /// Check if rental can be cancelled by user
  static bool canCancelRental(DateTime startDate, String status) {
    final now = DateTime.now();
    final hoursUntilStart = startDate.difference(now).inHours;
    final validStatus = status.toUpperCase() == 'PENDING' || status.toUpperCase() == 'CONFIRMED';
    return hoursUntilStart >= 24 && validStatus;
  }

  /// Calculate rental duration in days
  static int calculateRentalDays(DateTime startDate, DateTime endDate) {
    return endDate.difference(startDate).inDays;
  }

  /// Validate rental dates
  static Map<String, dynamic> validateRentalDates(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();

    if (startDate.isBefore(now)) {
      return {
        'valid': false,
        'error': 'Start date cannot be in the past',
      };
    }

    if (endDate.isBefore(startDate)) {
      return {
        'valid': false,
        'error': 'End date must be after start date',
      };
    }

    final duration = endDate.difference(startDate);
    if (duration.inMinutes < 60) {
      return {
        'valid': false,
        'error': 'Rental duration must be at least 1 hour',
      };
    }

    return {
      'valid': true,
      'duration': duration,
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // DEBUG HELPERS
  // ═══════════════════════════════════════════════════════════════

  /// Print service configuration
  static void printConfig() {
    if (!AppConfig.isDevelopment) return;

    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚗 [RENTAL API] Service Initialized');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔗 Base URL: $baseUrl');
    debugPrint('⏱️  Timeout: ${timeoutDuration.inSeconds}s');
    debugPrint('🌍 Environment: ${AppConfig.environment}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
}
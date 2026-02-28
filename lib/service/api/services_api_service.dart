// lib/services/api/services_api_service.dart
// Services Marketplace API Service - Production Ready

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// SERVICES MARKETPLACE API SERVICE
/// Handles all HTTP requests for the services marketplace feature
/// ═══════════════════════════════════════════════════════════════════════

class ServicesApiService {
  // Singleton pattern
  static final ServicesApiService _instance = ServicesApiService._internal();
  factory ServicesApiService() => _instance;
  ServicesApiService._internal();

  // Base configuration from .env
  static final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:4000/api';
  static final int _timeout = int.parse(dotenv.env['API_TIMEOUT'] ?? '30000');

  // API endpoints
  static const String _categoriesEndpoint = '/services/categories';
  static const String _listingsEndpoint = '/services/listings';
  static const String _requestsEndpoint = '/services/requests';
  static const String _ratingsEndpoint = '/services/ratings';
  static const String _disputesEndpoint = '/services/disputes';

  /// ═══════════════════════════════════════════════════════════════════════
  /// HELPER: GET AUTH TOKEN
  /// ═══════════════════════════════════════════════════════════════════════
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    } catch (e) {
      print('❌ [SERVICES_API] Error getting token: $e');
      return null;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// HELPER: GET HEADERS
  /// ═══════════════════════════════════════════════════════════════════════
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _getAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// HELPER: HANDLE RESPONSE
  /// ═══════════════════════════════════════════════════════════════════════
  Map<String, dynamic> _handleResponse(http.Response response) {
    print('🔵 [SERVICES_API] Response Status: ${response.statusCode}');
    print('🔵 [SERVICES_API] Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Request failed');
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// HELPER: HANDLE ERROR
  /// ═══════════════════════════════════════════════════════════════════════
  void _handleError(dynamic error, String context) {
    print('❌ [SERVICES_API] Error in $context: $error');
    if (error is SocketException) {
      throw Exception('No internet connection. Please check your network.');
    } else if (error is http.ClientException) {
      throw Exception('Connection error. Please try again.');
    } else if (error is FormatException) {
      throw Exception('Invalid response format from server.');
    } else {
      throw Exception(error.toString());
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// CATEGORIES API
  /// ═══════════════════════════════════════════════════════════════════════

  /// Get all categories (with subcategories)
  Future<Map<String, dynamic>> getCategories({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$_categoriesEndpoint')
          .replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      });

      print('🔵 [SERVICES_API] GET Categories: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getCategories');
      rethrow;
    }
  }

  /// Get parent categories only
  Future<Map<String, dynamic>> getParentCategories({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$_categoriesEndpoint/parents')
          .replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      });

      print('🔵 [SERVICES_API] GET Parent Categories: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getParentCategories');
      rethrow;
    }
  }

  /// Get subcategories for a parent
  Future<Map<String, dynamic>> getSubcategories(
      int parentId, {
        int page = 1,
        int limit = 20,
      }) async {
    try {
      final uri = Uri.parse('$_baseUrl$_categoriesEndpoint/$parentId/subcategories')
          .replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      });

      print('🔵 [SERVICES_API] GET Subcategories: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getSubcategories');
      rethrow;
    }
  }

  /// Get category by ID
  Future<Map<String, dynamic>> getCategoryById(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl$_categoriesEndpoint/$id');

      print('🔵 [SERVICES_API] GET Category by ID: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getCategoryById');
      rethrow;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// LISTINGS API
  /// ═══════════════════════════════════════════════════════════════════════

  /// Get all active listings (with filters)
  Future<Map<String, dynamic>> getListings({
    int page = 1,
    int limit = 20,
    int? categoryId,
    String? city,
    String? pricingType,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? search,
    String sortBy = 'created_at',
    String sortOrder = 'desc', // ✅ FIX: Changed from 'DESC' to 'desc' (lowercase)
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'sort_by': sortBy,
        'sort_order': sortOrder.toLowerCase(), // ✅ FIX: Ensure always lowercase
      };

      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      if (city != null) queryParams['city'] = city;
      if (pricingType != null) queryParams['pricing_type'] = pricingType;
      if (minPrice != null) queryParams['min_price'] = minPrice.toString();
      if (maxPrice != null) queryParams['max_price'] = maxPrice.toString();
      if (minRating != null) queryParams['min_rating'] = minRating.toString();
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$_baseUrl$_listingsEndpoint')
          .replace(queryParameters: queryParams);

      print('🔵 [SERVICES_API] GET Listings: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getListings');
      rethrow;
    }
  }

  /// Get single listing by ID
  Future<Map<String, dynamic>> getListingById(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl$_listingsEndpoint/$id');

      print('🔵 [SERVICES_API] GET Listing by ID: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getListingById');
      rethrow;
    }
  }

  /// Get my listings (Provider)
  Future<Map<String, dynamic>> getMyListings({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('$_baseUrl$_listingsEndpoint/my/listings')
          .replace(queryParameters: queryParams);

      print('🔵 [SERVICES_API] GET My Listings: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getMyListings');
      rethrow;
    }
  }

  /// Create new listing
  Future<Map<String, dynamic>> createListing({
    required int categoryId,
    required String title,
    required String description,
    required String pricingType,
    double? hourlyRate,
    double? minimumCharge,
    double? fixedPrice,
    required String city,
    List<String>? neighborhoods,
    double? serviceRadiusKm,
    List<File>? photos,
    List<String>? availableDays,
    String? availableHours,
    bool emergencyService = false,
    int? yearsExperience,
    String? certifications,
    List<String>? portfolioLinks,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$_listingsEndpoint');
      final token = await _getAuthToken();

      print('🔵 [SERVICES_API] POST Create Listing: $uri');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add fields
      request.fields['category_id'] = categoryId.toString();
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['pricing_type'] = pricingType;
      request.fields['city'] = city;
      request.fields['emergency_service'] = emergencyService.toString();

      if (hourlyRate != null) request.fields['hourly_rate'] = hourlyRate.toString();
      if (minimumCharge != null) request.fields['minimum_charge'] = minimumCharge.toString();
      if (fixedPrice != null) request.fields['fixed_price'] = fixedPrice.toString();
      if (serviceRadiusKm != null) request.fields['service_radius_km'] = serviceRadiusKm.toString();
      if (neighborhoods != null) request.fields['neighborhoods'] = json.encode(neighborhoods);
      if (availableDays != null) request.fields['available_days'] = json.encode(availableDays);
      if (availableHours != null) request.fields['available_hours'] = availableHours;
      if (yearsExperience != null) request.fields['years_experience'] = yearsExperience.toString();
      if (certifications != null) request.fields['certifications'] = certifications;
      if (portfolioLinks != null) request.fields['portfolio_links'] = json.encode(portfolioLinks);

      // Add photos
      if (photos != null && photos.isNotEmpty) {
        for (var photo in photos) {
          request.files.add(await http.MultipartFile.fromPath('photos', photo.path));
        }
      }

      final streamedResponse = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'createListing');
      rethrow;
    }
  }

  /// Update listing
  Future<Map<String, dynamic>> updateListing({
    required int id,
    String? title,
    String? description,
    String? pricingType,
    double? hourlyRate,
    double? minimumCharge,
    double? fixedPrice,
    String? city,
    List<String>? neighborhoods,
    double? serviceRadiusKm,
    List<File>? photos,
    List<String>? availableDays,
    String? availableHours,
    bool? emergencyService,
    int? yearsExperience,
    String? certifications,
    List<String>? portfolioLinks,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$_listingsEndpoint/$id');
      final token = await _getAuthToken();

      print('🔵 [SERVICES_API] PUT Update Listing: $uri');

      var request = http.MultipartRequest('PUT', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add only provided fields
      if (title != null) request.fields['title'] = title;
      if (description != null) request.fields['description'] = description;
      if (pricingType != null) request.fields['pricing_type'] = pricingType;
      if (city != null) request.fields['city'] = city;
      if (hourlyRate != null) request.fields['hourly_rate'] = hourlyRate.toString();
      if (minimumCharge != null) request.fields['minimum_charge'] = minimumCharge.toString();
      if (fixedPrice != null) request.fields['fixed_price'] = fixedPrice.toString();
      if (serviceRadiusKm != null) request.fields['service_radius_km'] = serviceRadiusKm.toString();
      if (neighborhoods != null) request.fields['neighborhoods'] = json.encode(neighborhoods);
      if (availableDays != null) request.fields['available_days'] = json.encode(availableDays);
      if (availableHours != null) request.fields['available_hours'] = availableHours;
      if (emergencyService != null) request.fields['emergency_service'] = emergencyService.toString();
      if (yearsExperience != null) request.fields['years_experience'] = yearsExperience.toString();
      if (certifications != null) request.fields['certifications'] = certifications;
      if (portfolioLinks != null) request.fields['portfolio_links'] = json.encode(portfolioLinks);

      // Add new photos
      if (photos != null && photos.isNotEmpty) {
        for (var photo in photos) {
          request.files.add(await http.MultipartFile.fromPath('photos', photo.path));
        }
      }

      final streamedResponse = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'updateListing');
      rethrow;
    }
  }

  /// Delete listing
  Future<Map<String, dynamic>> deleteListing(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl$_listingsEndpoint/$id');

      print('🔵 [SERVICES_API] DELETE Listing: $uri');

      final response = await http
          .delete(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'deleteListing');
      rethrow;
    }
  }

  /// Activate listing
  Future<Map<String, dynamic>> activateListing(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl$_listingsEndpoint/$id/activate');

      print('🔵 [SERVICES_API] POST Activate Listing: $uri');

      final response = await http
          .post(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'activateListing');
      rethrow;
    }
  }

  /// Deactivate listing
  Future<Map<String, dynamic>> deactivateListing(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl$_listingsEndpoint/$id/deactivate');

      print('🔵 [SERVICES_API] POST Deactivate Listing: $uri');

      final response = await http
          .post(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'deactivateListing');
      rethrow;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// SERVICE REQUESTS API
  /// ═══════════════════════════════════════════════════════════════════════

  /// Create service request (Customer contacts provider)
  Future<Map<String, dynamic>> createRequest({
    required int listingId,
    required String description,
    required String neededWhen,
    String? scheduledDate,
    String? scheduledTime,
    required String serviceLocation,
    double? latitude,
    double? longitude,
    double? customerBudget,
    List<File>? photos,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint');
      final token = await _getAuthToken();

      print('🔵 [SERVICES_API] POST Create Request: $uri');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add fields
      request.fields['listing_id'] = listingId.toString();
      request.fields['description'] = description;
      request.fields['needed_when'] = neededWhen;
      request.fields['service_location'] = serviceLocation;

      if (scheduledDate != null) request.fields['scheduled_date'] = scheduledDate;
      if (scheduledTime != null) request.fields['scheduled_time'] = scheduledTime;
      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) request.fields['longitude'] = longitude.toString();
      if (customerBudget != null) request.fields['customer_budget'] = customerBudget.toString();

      // Add photos
      if (photos != null && photos.isNotEmpty) {
        for (var photo in photos) {
          request.files.add(await http.MultipartFile.fromPath('photos', photo.path));
        }
      }

      final streamedResponse = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'createRequest');
      rethrow;
    }
  }

  /// Get my requests (Customer)
  Future<Map<String, dynamic>> getMyRequests({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/my-requests')
          .replace(queryParameters: queryParams);

      print('🔵 [SERVICES_API] GET My Requests: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getMyRequests');
      rethrow;
    }
  }

  /// Get incoming requests (Provider)
  Future<Map<String, dynamic>> getIncomingRequests({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/incoming')
          .replace(queryParameters: queryParams);

      print('🔵 [SERVICES_API] GET Incoming Requests: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getIncomingRequests');
      rethrow;
    }
  }

  /// Get request by ID
  Future<Map<String, dynamic>> getRequestById(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/$id');

      print('🔵 [SERVICES_API] GET Request by ID: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getRequestById');
      rethrow;
    }
  }

  /// Accept request (Provider)
  Future<Map<String, dynamic>> acceptRequest(int id, {String? providerResponse}) async {
    try {
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/$id/accept');

      print('🔵 [SERVICES_API] POST Accept Request: $uri');

      final body = <String, dynamic>{};
      if (providerResponse != null) body['provider_response'] = providerResponse;

      final response = await http
          .post(
        uri,
        headers: await _getHeaders(),
        body: json.encode(body),
      )
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'acceptRequest');
      rethrow;
    }
  }

  /// Reject request (Provider)
  Future<Map<String, dynamic>> rejectRequest(int id, String rejectionReason) async {
    try {
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/$id/reject');

      print('🔵 [SERVICES_API] POST Reject Request: $uri');

      final response = await http
          .post(
        uri,
        headers: await _getHeaders(),
        body: json.encode({'rejection_reason': rejectionReason}),
      )
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'rejectRequest');
      rethrow;
    }
  }

  /// Start service (Provider)
  Future<Map<String, dynamic>> startService(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/$id/start');

      print('🔵 [SERVICES_API] POST Start Service: $uri');

      final response = await http
          .post(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'startService');
      rethrow;
    }
  }

  /// Complete service (Provider)
  Future<Map<String, dynamic>> completeService({
    required int id,
    String? workSummary,
    double? hoursWorked,
    double? materialsCost,
    required double finalAmount,
    List<File>? afterPhotos,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/$id/complete');
      final token = await _getAuthToken();

      print('🔵 [SERVICES_API] POST Complete Service: $uri');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add fields
      request.fields['final_amount'] = finalAmount.toString();
      if (workSummary != null) request.fields['work_summary'] = workSummary;
      if (hoursWorked != null) request.fields['hours_worked'] = hoursWorked.toString();
      if (materialsCost != null) request.fields['materials_cost'] = materialsCost.toString();

      // Add after photos
      if (afterPhotos != null && afterPhotos.isNotEmpty) {
        for (var photo in afterPhotos) {
          request.files.add(await http.MultipartFile.fromPath('after_photos', photo.path));
        }
      }

      final streamedResponse = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'completeService');
      rethrow;
    }
  }

  /// Upload payment proof (Customer)
  Future<Map<String, dynamic>> uploadPaymentProof({
    required int id,
    required String paymentMethod,
    required File paymentProof,
    String? paymentReference,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/$id/payment-proof');
      final token = await _getAuthToken();

      print('🔵 [SERVICES_API] POST Upload Payment Proof: $uri');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add fields
      request.fields['payment_method'] = paymentMethod;
      if (paymentReference != null) request.fields['payment_reference'] = paymentReference;

      // Add payment proof image
      request.files.add(await http.MultipartFile.fromPath('payment_proof', paymentProof.path));

      final streamedResponse = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'uploadPaymentProof');
      rethrow;
    }
  }

  /// Confirm payment (Provider)
  Future<Map<String, dynamic>> confirmPayment(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/$id/confirm-payment');

      print('🔵 [SERVICES_API] POST Confirm Payment: $uri');

      final response = await http
          .post(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'confirmPayment');
      rethrow;
    }
  }

  /// Cancel request
  Future<Map<String, dynamic>> cancelRequest(int id, String cancellationReason) async {
    try {
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/$id/cancel');

      print('🔵 [SERVICES_API] POST Cancel Request: $uri');

      final response = await http
          .post(
        uri,
        headers: await _getHeaders(),
        body: json.encode({'cancellation_reason': cancellationReason}),
      )
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'cancelRequest');
      rethrow;
    }
  }

  /// Get request statistics
  Future<Map<String, dynamic>> getRequestStats({String userType = 'customer'}) async {
    try {
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/stats')
          .replace(queryParameters: {'user_type': userType});

      print('🔵 [SERVICES_API] GET Request Stats: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getRequestStats');
      rethrow;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// RATINGS API
  /// ═══════════════════════════════════════════════════════════════════════

  /// Create rating (Customer only)
  Future<Map<String, dynamic>> createRating({
    required int requestId,
    required int rating,
    int? qualityRating,
    int? professionalismRating,
    int? communicationRating,
    int? valueRating,
    String? reviewText,
    List<File>? reviewPhotos,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$_ratingsEndpoint');
      final token = await _getAuthToken();

      print('🔵 [SERVICES_API] POST Create Rating: $uri');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add fields
      request.fields['request_id'] = requestId.toString();
      request.fields['rating'] = rating.toString();
      if (qualityRating != null) request.fields['quality_rating'] = qualityRating.toString();
      if (professionalismRating != null) request.fields['professionalism_rating'] = professionalismRating.toString();
      if (communicationRating != null) request.fields['communication_rating'] = communicationRating.toString();
      if (valueRating != null) request.fields['value_rating'] = valueRating.toString();
      if (reviewText != null) request.fields['review_text'] = reviewText;

      // Add review photos
      if (reviewPhotos != null && reviewPhotos.isNotEmpty) {
        for (var photo in reviewPhotos) {
          request.files.add(await http.MultipartFile.fromPath('review_photos', photo.path));
        }
      }

      final streamedResponse = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'createRating');
      rethrow;
    }
  }

  /// Get ratings for listing
  Future<Map<String, dynamic>> getRatingsForListing(
      int listingId, {
        int page = 1,
        int limit = 10,
        double? minRating,
      }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (minRating != null) queryParams['min_rating'] = minRating.toString();

      final uri = Uri.parse('$_baseUrl$_ratingsEndpoint/listing/$listingId')
          .replace(queryParameters: queryParams);

      print('🔵 [SERVICES_API] GET Ratings for Listing: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getRatingsForListing');
      rethrow;
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// DISPUTES API
  /// ═══════════════════════════════════════════════════════════════════════

  /// File dispute
  Future<Map<String, dynamic>> fileDispute({
    required int requestId,
    required String disputeType,
    required String description,
    required String resolutionRequested,
    double? refundAmount,
    List<File>? evidencePhotos,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$_disputesEndpoint');
      final token = await _getAuthToken();

      print('🔵 [SERVICES_API] POST File Dispute: $uri');

      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add fields
      request.fields['request_id'] = requestId.toString();
      request.fields['dispute_type'] = disputeType;
      request.fields['description'] = description;
      request.fields['resolution_requested'] = resolutionRequested;
      if (refundAmount != null) request.fields['refund_amount'] = refundAmount.toString();

      // Add evidence photos
      if (evidencePhotos != null && evidencePhotos.isNotEmpty) {
        for (var photo in evidencePhotos) {
          request.files.add(await http.MultipartFile.fromPath('evidence_photos', photo.path));
        }
      }

      final streamedResponse = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'fileDispute');
      rethrow;
    }
  }

  /// Get my disputes
  Future<Map<String, dynamic>> getMyDisputes({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('$_baseUrl$_disputesEndpoint/my-disputes')
          .replace(queryParameters: queryParams);

      print('🔵 [SERVICES_API] GET My Disputes: $uri');

      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));

      return _handleResponse(response);
    } catch (e) {
      _handleError(e, 'getMyDisputes');
      rethrow;
    }
  }
}
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

  static final String _baseUrl =
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:4000/api';
  static final int _timeout =
  int.parse(dotenv.env['API_TIMEOUT'] ?? '30000');

  static const String _categoriesEndpoint = '/services/categories';
  static const String _listingsEndpoint   = '/services/listings';
  static const String _requestsEndpoint   = '/services/requests';
  static const String _ratingsEndpoint    = '/services/ratings';
  static const String _disputesEndpoint   = '/services/disputes';

  // ── Auth helpers ──────────────────────────────────────────────────────────

  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    } catch (e) {
      print('❌ [SERVICES_API] Error getting token: $e');
      return null;
    }
  }

  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept':       'application/json',
    };
    if (includeAuth) {
      final token = await _getAuthToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

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

  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORIES
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getCategories({int page = 1, int limit = 50}) async {
    try {
      final uri = Uri.parse('$_baseUrl$_categoriesEndpoint').replace(
        queryParameters: {'page': '$page', 'limit': '$limit'},
      );
      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getCategories'); rethrow; }
  }

  Future<Map<String, dynamic>> getParentCategories({int page = 1, int limit = 20}) async {
    try {
      final uri = Uri.parse('$_baseUrl$_categoriesEndpoint/parents').replace(
        queryParameters: {'page': '$page', 'limit': '$limit'},
      );
      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getParentCategories'); rethrow; }
  }

  Future<Map<String, dynamic>> getSubcategories(int parentId,
      {int page = 1, int limit = 20}) async {
    try {
      final uri = Uri.parse(
          '$_baseUrl$_categoriesEndpoint/$parentId/subcategories')
          .replace(queryParameters: {'page': '$page', 'limit': '$limit'});
      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getSubcategories'); rethrow; }
  }

  Future<Map<String, dynamic>> getCategoryById(int id) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_categoriesEndpoint/$id');
      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getCategoryById'); rethrow; }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LISTINGS
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getListings({
    int     page      = 1,
    int     limit     = 20,
    int?    categoryId,
    String? city,
    String? pricingType,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String? search,
    String  sortBy    = 'created_at',
    String  sortOrder = 'desc',
  }) async {
    try {
      final q = <String, String>{
        'page':       '$page',
        'limit':      '$limit',
        'sort_by':    sortBy,
        'sort_order': sortOrder.toLowerCase(),
      };
      if (categoryId  != null) q['category_id']  = '$categoryId';
      if (city        != null) q['city']          = city;
      if (pricingType != null) q['pricing_type']  = pricingType;
      if (minPrice    != null) q['min_price']     = '$minPrice';
      if (maxPrice    != null) q['max_price']     = '$maxPrice';
      if (minRating   != null) q['min_rating']    = '$minRating';
      if (search      != null && search.isNotEmpty) q['search'] = search;

      final uri = Uri.parse('$_baseUrl$_listingsEndpoint').replace(queryParameters: q);
      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getListings'); rethrow; }
  }

  Future<Map<String, dynamic>> getListingById(int id) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_listingsEndpoint/$id');
      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getListingById'); rethrow; }
  }

  Future<Map<String, dynamic>> getMyListings({
    int     page  = 1,
    int     limit = 20,
    String? status,
  }) async {
    try {
      final q = <String, String>{'page': '$page', 'limit': '$limit'};
      if (status != null) q['status'] = status;
      final uri = Uri.parse('$_baseUrl$_listingsEndpoint/my/listings')
          .replace(queryParameters: q);
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getMyListings'); rethrow; }
  }

  Future<Map<String, dynamic>> createListing({
    required int    categoryId,
    required String title,
    required String description,
    required String pricingType,
    double?         hourlyRate,
    double?         minimumCharge,
    double?         fixedPrice,
    required String city,
    List<String>?   neighborhoods,
    double?         serviceRadiusKm,
    List<File>?     photos,
    List<String>?   availableDays,
    String?         availableHours,
    bool            emergencyService = false,
    int?            yearsExperience,
    String?         certifications,
    List<String>?   portfolioLinks,
  }) async {
    try {
      final uri     = Uri.parse('$_baseUrl$_listingsEndpoint');
      final token   = await _getAuthToken();
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['category_id']     = '$categoryId'
        ..fields['title']           = title
        ..fields['description']     = description
        ..fields['pricing_type']    = pricingType
        ..fields['city']            = city
        ..fields['emergency_service'] = '$emergencyService';

      if (hourlyRate      != null) request.fields['hourly_rate']      = '$hourlyRate';
      if (minimumCharge   != null) request.fields['minimum_charge']   = '$minimumCharge';
      if (fixedPrice      != null) request.fields['fixed_price']      = '$fixedPrice';
      if (serviceRadiusKm != null) request.fields['service_radius_km'] = '$serviceRadiusKm';
      if (neighborhoods   != null) request.fields['neighborhoods']    = json.encode(neighborhoods);
      if (availableDays   != null) request.fields['available_days']   = json.encode(availableDays);
      if (availableHours  != null) request.fields['available_hours']  = availableHours;
      if (yearsExperience != null) request.fields['years_experience'] = '$yearsExperience';
      if (certifications  != null) request.fields['certifications']   = certifications;
      if (portfolioLinks  != null) request.fields['portfolio_links']  = json.encode(portfolioLinks);

      if (photos != null) {
        for (final f in photos) {
          request.files.add(await http.MultipartFile.fromPath('photos', f.path));
        }
      }

      final streamed  = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response  = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'createListing'); rethrow; }
  }

  Future<Map<String, dynamic>> updateListing({
    required int    id,
    String?         title,
    String?         description,
    String?         pricingType,
    double?         hourlyRate,
    double?         minimumCharge,
    double?         fixedPrice,
    String?         city,
    List<String>?   neighborhoods,
    double?         serviceRadiusKm,
    List<File>?     photos,
    List<String>?   availableDays,
    String?         availableHours,
    bool?           emergencyService,
    int?            yearsExperience,
    String?         certifications,
    List<String>?   portfolioLinks,
  }) async {
    try {
      final uri     = Uri.parse('$_baseUrl$_listingsEndpoint/$id');
      final token   = await _getAuthToken();
      final request = http.MultipartRequest('PUT', uri)
        ..headers['Authorization'] = 'Bearer $token';

      if (title            != null) request.fields['title']            = title;
      if (description      != null) request.fields['description']      = description;
      if (pricingType      != null) request.fields['pricing_type']     = pricingType;
      if (city             != null) request.fields['city']             = city;
      if (hourlyRate       != null) request.fields['hourly_rate']      = '$hourlyRate';
      if (minimumCharge    != null) request.fields['minimum_charge']   = '$minimumCharge';
      if (fixedPrice       != null) request.fields['fixed_price']      = '$fixedPrice';
      if (serviceRadiusKm  != null) request.fields['service_radius_km'] = '$serviceRadiusKm';
      if (neighborhoods    != null) request.fields['neighborhoods']    = json.encode(neighborhoods);
      if (availableDays    != null) request.fields['available_days']   = json.encode(availableDays);
      if (availableHours   != null) request.fields['available_hours']  = availableHours;
      if (emergencyService != null) request.fields['emergency_service'] = '$emergencyService';
      if (yearsExperience  != null) request.fields['years_experience'] = '$yearsExperience';
      if (certifications   != null) request.fields['certifications']   = certifications;
      if (portfolioLinks   != null) request.fields['portfolio_links']  = json.encode(portfolioLinks);

      if (photos != null) {
        for (final f in photos) {
          request.files.add(await http.MultipartFile.fromPath('photos', f.path));
        }
      }

      final streamed  = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response  = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'updateListing'); rethrow; }
  }

  Future<Map<String, dynamic>> deleteListing(int id) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_listingsEndpoint/$id');
      final response = await http
          .delete(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'deleteListing'); rethrow; }
  }

  Future<Map<String, dynamic>> activateListing(int id) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_listingsEndpoint/$id/activate');
      final response = await http
          .post(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'activateListing'); rethrow; }
  }

  Future<Map<String, dynamic>> deactivateListing(int id) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_listingsEndpoint/$id/deactivate');
      final response = await http
          .post(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'deactivateListing'); rethrow; }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LISTING PLANS  (new — plan selection + CamPay payment gate)
  // ═══════════════════════════════════════════════════════════════════════

  /// GET /api/services/plans
  Future<Map<String, dynamic>> getListingPlans() async {
    try {
      final uri      = Uri.parse('$_baseUrl/services/plans');
      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getListingPlans'); rethrow; }
  }

  /// POST /api/services/listings/:id/activate-free
  Future<Map<String, dynamic>> activateFreePlan(int listingId) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_listingsEndpoint/$listingId/activate-free');
      final response = await http
          .post(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'activateFreePlan'); rethrow; }
  }

  /// POST /api/services/listings/:id/initiate-payment
  /// body: { plan_id, phone }
  Future<Map<String, dynamic>> initiateListingPayment({
    required int    listingId,
    required int    planId,
    required String phone,
  }) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_listingsEndpoint/$listingId/initiate-payment');
      final response = await http
          .post(
        uri,
        headers: await _getHeaders(),
        body:    json.encode({'plan_id': planId, 'phone': phone}),
      )
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'initiateListingPayment'); rethrow; }
  }

  /// GET /api/services/listings/:id/ad-status
  Future<Map<String, dynamic>> getAdStatus(int listingId) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_listingsEndpoint/$listingId/ad-status');
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getAdStatus'); rethrow; }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PROVIDER SUBSCRIPTION (buy a plan once, then post under its quota)
  // ═══════════════════════════════════════════════════════════════════════

  /// GET /api/services/subscription/mine
  Future<Map<String, dynamic>> getMySubscription() async {
    try {
      final uri = Uri.parse('$_baseUrl/services/subscription/mine');
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getMySubscription'); rethrow; }
  }

  /// GET /api/services/subscription/history — the provider's subscription payments
  Future<Map<String, dynamic>> getSubscriptionHistory({int page = 1, int limit = 20}) async {
    try {
      final uri = Uri.parse('$_baseUrl/services/subscription/history?page=$page&limit=$limit');
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getSubscriptionHistory'); rethrow; }
  }

  /// POST /api/services/subscription/activate-free
  Future<Map<String, dynamic>> activateFreeSubscription() async {
    try {
      final uri = Uri.parse('$_baseUrl/services/subscription/activate-free');
      final response = await http
          .post(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'activateFreeSubscription'); rethrow; }
  }

  /// POST /api/services/subscription/initiate-payment  body: { plan_id, phone }
  Future<Map<String, dynamic>> initiateSubscriptionPayment({
    required int    planId,
    required String phone,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/services/subscription/initiate-payment');
      final response = await http
          .post(uri, headers: await _getHeaders(), body: json.encode({'plan_id': planId, 'phone': phone}))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'initiateSubscriptionPayment'); rethrow; }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SERVICE REQUESTS
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> createRequest({
    required int    listingId,
    required String description,
    required String neededWhen,
    String?         scheduledDate,
    String?         scheduledTime,
    required String serviceLocation,
    double?         latitude,
    double?         longitude,
    double?         customerBudget,
    List<File>?     photos,
  }) async {
    try {
      final uri     = Uri.parse('$_baseUrl$_requestsEndpoint');
      final token   = await _getAuthToken();
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['listing_id']       = '$listingId'
        ..fields['description']      = description
        ..fields['needed_when']      = neededWhen
        ..fields['service_location'] = serviceLocation;

      if (scheduledDate  != null) request.fields['scheduled_date']  = scheduledDate;
      if (scheduledTime  != null) request.fields['scheduled_time']  = scheduledTime;
      if (latitude       != null) request.fields['latitude']        = '$latitude';
      if (longitude      != null) request.fields['longitude']       = '$longitude';
      if (customerBudget != null) request.fields['customer_budget'] = '$customerBudget';

      if (photos != null) {
        for (final f in photos) {
          request.files.add(await http.MultipartFile.fromPath('photos', f.path));
        }
      }

      final streamed  = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response  = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'createRequest'); rethrow; }
  }

  /// Record interest in a listing and notify the provider (push).
  /// POST /services/listings/:id/contact — returns the provider's contact info.
  Future<Map<String, dynamic>> requestServiceContact(int listingId,
      {String? message}) async {
    try {
      final uri  = Uri.parse('$_baseUrl$_listingsEndpoint/$listingId/contact');
      final resp = await http
          .post(uri,
              headers: await _getHeaders(),
              body: jsonEncode({if (message != null) 'message': message}))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(resp);
    } catch (e) { _handleError(e, 'requestServiceContact'); rethrow; }
  }

  Future<Map<String, dynamic>> getMyRequests({
    int     page  = 1,
    int     limit = 20,
    String? status,
  }) async {
    try {
      final q = <String, String>{'page': '$page', 'limit': '$limit'};
      if (status != null) q['status'] = status;
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/my-requests')
          .replace(queryParameters: q);
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getMyRequests'); rethrow; }
  }

  Future<Map<String, dynamic>> getIncomingRequests({
    int     page  = 1,
    int     limit = 20,
    String? status,
  }) async {
    try {
      final q = <String, String>{'page': '$page', 'limit': '$limit'};
      if (status != null) q['status'] = status;
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/incoming')
          .replace(queryParameters: q);
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getIncomingRequests'); rethrow; }
  }

  Future<Map<String, dynamic>> getRequestById(int id) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_requestsEndpoint/$id');
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getRequestById'); rethrow; }
  }

  Future<Map<String, dynamic>> acceptRequest(int id, {String? providerResponse}) async {
    try {
      final uri  = Uri.parse('$_baseUrl$_requestsEndpoint/$id/accept');
      final body = <String, dynamic>{};
      if (providerResponse != null) body['provider_response'] = providerResponse;
      final response = await http
          .post(uri, headers: await _getHeaders(), body: json.encode(body))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'acceptRequest'); rethrow; }
  }

  Future<Map<String, dynamic>> rejectRequest(int id, String rejectionReason) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_requestsEndpoint/$id/reject');
      final response = await http
          .post(uri,
          headers: await _getHeaders(),
          body:    json.encode({'rejection_reason': rejectionReason}))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'rejectRequest'); rethrow; }
  }

  Future<Map<String, dynamic>> startService(int id) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_requestsEndpoint/$id/start');
      final response = await http
          .post(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'startService'); rethrow; }
  }

  Future<Map<String, dynamic>> completeService({
    required int    id,
    String?         workSummary,
    double?         hoursWorked,
    double?         materialsCost,
    required double finalAmount,
    List<File>?     afterPhotos,
  }) async {
    try {
      final uri     = Uri.parse('$_baseUrl$_requestsEndpoint/$id/complete');
      final token   = await _getAuthToken();
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['final_amount']   = '$finalAmount';

      if (workSummary   != null) request.fields['work_summary']   = workSummary;
      if (hoursWorked   != null) request.fields['hours_worked']   = '$hoursWorked';
      if (materialsCost != null) request.fields['materials_cost'] = '$materialsCost';

      if (afterPhotos != null) {
        for (final f in afterPhotos) {
          request.files.add(await http.MultipartFile.fromPath('after_photos', f.path));
        }
      }

      final streamed  = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response  = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'completeService'); rethrow; }
  }

  Future<Map<String, dynamic>> uploadPaymentProof({
    required int    id,
    required String paymentMethod,
    required File   paymentProof,
    String?         paymentReference,
  }) async {
    try {
      final uri     = Uri.parse('$_baseUrl$_requestsEndpoint/$id/payment-proof');
      final token   = await _getAuthToken();
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization']    = 'Bearer $token'
        ..fields['payment_method']    = paymentMethod;

      if (paymentReference != null) request.fields['payment_reference'] = paymentReference;
      request.files.add(await http.MultipartFile.fromPath('payment_proof', paymentProof.path));

      final streamed  = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response  = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'uploadPaymentProof'); rethrow; }
  }

  Future<Map<String, dynamic>> confirmPayment(int id) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_requestsEndpoint/$id/confirm-payment');
      final response = await http
          .post(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'confirmPayment'); rethrow; }
  }

  Future<Map<String, dynamic>> cancelRequest(int id, String cancellationReason) async {
    try {
      final uri      = Uri.parse('$_baseUrl$_requestsEndpoint/$id/cancel');
      final response = await http
          .post(uri,
          headers: await _getHeaders(),
          body:    json.encode({'cancellation_reason': cancellationReason}))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'cancelRequest'); rethrow; }
  }

  Future<Map<String, dynamic>> getRequestStats({String userType = 'customer'}) async {
    try {
      final uri = Uri.parse('$_baseUrl$_requestsEndpoint/stats')
          .replace(queryParameters: {'user_type': userType});
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getRequestStats'); rethrow; }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RATINGS
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> createRating({
    required int    listingId,
    required int    rating,
    String?         reviewText,
    List<File>?     reviewPhotos,
  }) async {
    try {
      final uri     = Uri.parse('$_baseUrl$_ratingsEndpoint');
      final token   = await _getAuthToken();
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['listing_id']     = '$listingId'
        ..fields['rating']         = '$rating';

      if (reviewText != null) request.fields['review_text'] = reviewText;

      if (reviewPhotos != null) {
        for (final f in reviewPhotos) {
          request.files.add(await http.MultipartFile.fromPath('review_photos', f.path));
        }
      }

      final streamed  = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response  = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'createRating'); rethrow; }
  }

  Future<Map<String, dynamic>> getRatingsForListing(int listingId,
      {int page = 1, int limit = 10, double? minRating}) async {
    try {
      final q = <String, String>{'page': '$page', 'limit': '$limit'};
      if (minRating != null) q['min_rating'] = '$minRating';
      final uri = Uri.parse('$_baseUrl$_ratingsEndpoint/listing/$listingId')
          .replace(queryParameters: q);
      final response = await http
          .get(uri, headers: await _getHeaders(includeAuth: false))
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getRatingsForListing'); rethrow; }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DISPUTES
  // ═══════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> fileDispute({
    required int    requestId,
    required String disputeType,
    required String description,
    required String resolutionRequested,
    double?         refundAmount,
    List<File>?     evidencePhotos,
  }) async {
    try {
      final uri     = Uri.parse('$_baseUrl$_disputesEndpoint');
      final token   = await _getAuthToken();
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization']         = 'Bearer $token'
        ..fields['request_id']             = '$requestId'
        ..fields['dispute_type']           = disputeType
        ..fields['description']            = description
        ..fields['resolution_requested']   = resolutionRequested;

      if (refundAmount != null) request.fields['refund_amount'] = '$refundAmount';
      if (evidencePhotos != null) {
        for (final f in evidencePhotos) {
          request.files.add(await http.MultipartFile.fromPath('evidence_photos', f.path));
        }
      }

      final streamed  = await request.send().timeout(Duration(milliseconds: _timeout * 2));
      final response  = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'fileDispute'); rethrow; }
  }

  Future<Map<String, dynamic>> getMyDisputes({
    int     page  = 1,
    int     limit = 20,
    String? status,
  }) async {
    try {
      final q = <String, String>{'page': '$page', 'limit': '$limit'};
      if (status != null) q['status'] = status;
      final uri = Uri.parse('$_baseUrl$_disputesEndpoint/my-disputes')
          .replace(queryParameters: q);
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(Duration(milliseconds: _timeout));
      return _handleResponse(response);
    } catch (e) { _handleError(e, 'getMyDisputes'); rethrow; }
  }
}
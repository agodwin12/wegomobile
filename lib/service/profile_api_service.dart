// lib/services/profile_api_service.dart
// WEGO - Profile API Service (COMPLETE & FIXED)
// Handles all profile-related API calls

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/support_model.dart';
import '../models/user_profile_model.dart';
import '../models/vehicle_model.dart';
import '../models/driver_document_model.dart';
import '../models/user_preferences_model.dart';

class ProfileApiService {
  // Base URL from environment (already includes /api)
  static final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:4000/api';

  // ═══════════════════════════════════════════════════════════════════
  // TOKEN MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token'); // ✅ FIXED: Changed from 'auth_token' to 'access_token'

      print('🔑 [PROFILE API] Token retrieval:');
      print('   Key used: access_token');
      print('   Token found: ${token != null ? "YES (${token.substring(0, 20)}...)" : "NO"}');

      return token;
    } catch (e) {
      print('❌ [PROFILE API] Error getting token: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HEADERS
  // ═══════════════════════════════════════════════════════════════════

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    print('📤 [PROFILE API] Request headers:');
    print('   Content-Type: ${headers['Content-Type']}');
    print('   Accept: ${headers['Accept']}');
    print('   Authorization: ${headers['Authorization'] != null ? "Bearer ${token!.substring(0, 20)}..." : "MISSING"}');

    return headers;
  }

  Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _getToken();

    final headers = {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    print('📤 [PROFILE API] Multipart headers:');
    print('   Accept: ${headers['Accept']}');
    print('   Authorization: ${headers['Authorization'] != null ? "Bearer ${token!.substring(0, 20)}..." : "MISSING"}');

    return headers;
  }

  // ═══════════════════════════════════════════════════════════════════
  // PROFILE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Get current user profile with stats
  Future<UserProfile> getProfile() async {
    try {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📱 [PROFILE API] Getting user profile...');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final headers = await _getHeaders();
      final url = '$baseUrl/users/profile';

      print('🌐 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('📥 [PROFILE API] Response received:');
      print('   Status Code: ${response.statusCode}');
      print('   Body Length: ${response.body.length} chars');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final userData = data['data'] as Map<String, dynamic>;
        return UserProfile.fromJson(userData['user'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        print('❌ [PROFILE API] 401 Unauthorized - Token invalid or expired');
        throw Exception('Authentication failed. Please login again.');
      } else {
        print('❌ [PROFILE API] Failed with status ${response.statusCode}');
        print('   Response: ${response.body}');
        throw Exception('Failed to get profile: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error getting profile: $e');
      rethrow;
    }
  }

  /// Update profile information
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? address,
    String? city,
    DateTime? dateOfBirth,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};

      if (firstName != null) body['firstName'] = firstName;
      if (lastName != null) body['lastName'] = lastName;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      if (address != null) body['address'] = address;
      if (city != null) body['city'] = city;
      if (dateOfBirth != null) body['dateOfBirth'] = dateOfBirth.toIso8601String();

      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: headers,
        body: json.encode(body),
      );

      print('📱 [PROFILE API] Update profile - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final userData = data['data'] as Map<String, dynamic>;
        return UserProfile.fromJson(userData['user'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to update profile: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error updating profile: $e');
      rethrow;
    }
  }

  /// Upload/Update profile avatar
  Future<String> updateAvatar(File imageFile) async {
    try {
      final headers = await _getMultipartHeaders();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/profile/avatar'),
      );

      request.headers.addAll(headers);
      request.files.add(
        await http.MultipartFile.fromPath('avatar', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📱 [PROFILE API] Update avatar - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final responseData = data['data'] as Map<String, dynamic>;
        return responseData['avatarUrl'] as String;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to update avatar: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error updating avatar: $e');
      rethrow;
    }
  }

  /// Delete profile avatar
  Future<void> deleteAvatar() async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/users/profile/avatar'),
        headers: headers,
      );

      print('📱 [PROFILE API] Delete avatar - Status: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode != 200) {
        throw Exception('Failed to delete avatar: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error deleting avatar: $e');
      rethrow;
    }
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/users/change-password'),
        headers: headers,
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      print('📱 [PROFILE API] Change password - Status: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode != 200) {
        final error = json.decode(response.body) as Map<String, dynamic>;
        throw Exception(error['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error changing password: $e');
      rethrow;
    }
  }

  /// Get profile statistics
  Future<UserStats> getStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/stats'),
        headers: headers,
      );

      print('📱 [PROFILE API] Get stats - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final statsData = data['data'] as Map<String, dynamic>;
        return UserStats.fromJson(statsData['stats'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to get stats: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error getting stats: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // VEHICLE OPERATIONS (for drivers)
  // ═══════════════════════════════════════════════════════════════════

  /// Get driver's vehicle information
  Future<Vehicle?> getVehicle() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/driver/vehicle'),
        headers: headers,
      );

      print('📱 [PROFILE API] Get vehicle - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final vehicleData = data['data'] as Map<String, dynamic>;
        if (vehicleData['vehicle'] != null) {
          return Vehicle.fromJson(vehicleData['vehicle'] as Map<String, dynamic>);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to get vehicle: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error getting vehicle: $e');
      rethrow;
    }
  }

  /// Update vehicle information
  Future<Vehicle> updateVehicle({
    required String brand,
    required String model,
    required String year,
    required String color,
    required String licensePlate,
    String? vehicleType,
    required int capacity,
    String? insuranceNumber,
    DateTime? insuranceExpiry,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/driver/vehicle'),
        headers: headers,
        body: json.encode({
          'brand': brand,
          'model': model,
          'year': year,
          'color': color,
          'licensePlate': licensePlate,
          if (vehicleType != null) 'vehicleType': vehicleType,
          'capacity': capacity,
          if (insuranceNumber != null) 'insuranceNumber': insuranceNumber,
          if (insuranceExpiry != null) 'insuranceExpiry': insuranceExpiry.toIso8601String(),
        }),
      );

      print('📱 [PROFILE API] Update vehicle - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final vehicleData = data['data'] as Map<String, dynamic>;
        return Vehicle.fromJson(vehicleData['vehicle'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to update vehicle: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error updating vehicle: $e');
      rethrow;
    }
  }

  /// Upload vehicle insurance document
  Future<String> uploadInsuranceDoc(File documentFile) async {
    try {
      final headers = await _getMultipartHeaders();
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/driver/vehicle/insurance'),
      );

      request.headers.addAll(headers);
      request.files.add(
        await http.MultipartFile.fromPath('insurance', documentFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📱 [PROFILE API] Upload insurance - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final docData = data['data'] as Map<String, dynamic>;
        return docData['insuranceDoc'] as String;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to upload insurance: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error uploading insurance: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // DRIVER DOCUMENTS
  // ═══════════════════════════════════════════════════════════════════

  /// Get driver documents
  Future<DriverDocument?> getDriverDocuments() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/driver/documents'),
        headers: headers,
      );

      print('📱 [PROFILE API] Get documents - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final docsData = data['data'] as Map<String, dynamic>;
        if (docsData['documents'] != null) {
          return DriverDocument.fromJson(docsData['documents'] as Map<String, dynamic>);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to get documents: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error getting documents: $e');
      rethrow;
    }
  }

  /// Upload driver license
  Future<String> uploadDriverLicense(File licenseFile) async {
    try {
      final headers = await _getMultipartHeaders();
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/driver/documents/license'),
      );

      request.headers.addAll(headers);
      request.files.add(
        await http.MultipartFile.fromPath('license', licenseFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📱 [PROFILE API] Upload license - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final licenseData = data['data'] as Map<String, dynamic>;
        return licenseData['licenseUrl'] as String;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to upload license: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error uploading license: $e');
      rethrow;
    }
  }

  /// Upload CNI (National ID)
  Future<String> uploadCNI(File cniFile) async {
    try {
      final headers = await _getMultipartHeaders();
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/driver/documents/cni'),
      );

      request.headers.addAll(headers);
      request.files.add(
        await http.MultipartFile.fromPath('cni', cniFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📱 [PROFILE API] Upload CNI - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final cniData = data['data'] as Map<String, dynamic>;
        return cniData['cniUrl'] as String;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to upload CNI: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error uploading CNI: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // PREFERENCES & SETTINGS
  // ═══════════════════════════════════════════════════════════════════

  /// Get user preferences
  Future<UserPreferences> getPreferences() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile/preferences'),
        headers: headers,
      );

      print('📱 [PROFILE API] Get preferences - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final prefsData = data['data'] as Map<String, dynamic>;
        return UserPreferences.fromJson(prefsData['preferences'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to get preferences: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error getting preferences: $e');
      rethrow;
    }
  }

  /// Update notification settings
  Future<NotificationSettings> updateNotificationSettings(
      NotificationSettings settings,
      ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/users/profile/preferences/notifications'),
        headers: headers,
        body: json.encode(settings.toJson()),
      );

      print('📱 [PROFILE API] Update notifications - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final notifData = data['data'] as Map<String, dynamic>;
        return NotificationSettings.fromJson(notifData['notifications'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to update notifications: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error updating notifications: $e');
      rethrow;
    }
  }

  /// Update privacy settings
  Future<PrivacySettings> updatePrivacySettings(
      PrivacySettings settings,
      ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/users/profile/preferences/privacy'),
        headers: headers,
        body: json.encode(settings.toJson()),
      );

      print('📱 [PROFILE API] Update privacy - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final privacyData = data['data'] as Map<String, dynamic>;
        return PrivacySettings.fromJson(privacyData['privacy'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to update privacy: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error updating privacy: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // SUPPORT & HELP
  // ═══════════════════════════════════════════════════════════════════

  // ── FAQ ────────────────────────────────────────────────────────────
  //
  // The backend exposes ONE FAQ endpoint: GET /support/faq, optionally
  // filtered with ?category= or ?search=. It answers with the questions
  // already grouped by category:
  //
  //   { data: { total, faqs: { payment: [ {id, question, answer, ...} ] } } }
  //
  // The previous helpers here called /support/faq/category/:id,
  // /support/faq/search and /support/faq/:id/helpful — none of which exist,
  // and read data.categories, which the server never returns. That is why
  // Help & FAQ always showed "Failed to load FAQ items".

  /// Fetches the FAQ and returns one entry per category, items included.
  Future<List<FAQCategory>> getFAQCategories() async {
    final grouped = await _fetchGroupedFaq();

    return grouped.entries.map((entry) {
      final items = entry.value
          .map((json) => FAQItem.fromJson(json))
          .toList();
      return FAQCategory(
        id: entry.key,
        name: _prettyCategory(entry.key),
        icon: entry.key,
        description: '',
        itemCount: items.length,
        items: items,
      );
    }).toList();
  }

  /// Questions for a single category.
  Future<List<FAQItem>> getFAQItems(String categoryId) async {
    final grouped = await _fetchGroupedFaq(category: categoryId);
    return grouped.values
        .expand((list) => list)
        .map((json) => FAQItem.fromJson(json))
        .toList();
  }

  /// Full-text search, handled server-side by the same endpoint.
  Future<List<FAQItem>> searchFAQ(String query) async {
    final grouped = await _fetchGroupedFaq(search: query);
    return grouped.values
        .expand((list) => list)
        .map((json) => FAQItem.fromJson(json))
        .toList();
  }

  /// No "helpful" endpoint exists server-side yet, so this is intentionally a
  /// local no-op: the UI can keep its optimistic tick without firing a request
  /// that would 404. Wire it up here when the backend route lands.
  Future<void> markFAQHelpful(String faqId) async {
    print('ℹ️  [PROFILE API] FAQ $faqId marked helpful (local only — no endpoint)');
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchGroupedFaq({
    String? category,
    String? search,
  }) async {
    try {
      final query = <String, String>{
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      };
      final uri = Uri.parse('$baseUrl/support/faq')
          .replace(queryParameters: query.isEmpty ? null : query);

      final response = await http.get(uri, headers: await _getHeaders());

      print('📱 [PROFILE API] Get FAQ - Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Failed to load the FAQ: ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final faqs = (data['data']?['faqs'] ?? <String, dynamic>{})
          as Map<String, dynamic>;

      return faqs.map(
        (key, value) => MapEntry(key, (value as List).cast<Map<String, dynamic>>()),
      );
    } catch (e) {
      print('❌ [PROFILE API] Error loading FAQ: $e');
      rethrow;
    }
  }

  /// 'payment_issue' → 'Payment issue'. The API stores raw category slugs.
  String _prettyCategory(String slug) {
    if (slug.isEmpty) return slug;
    final words = slug.replaceAll('_', ' ').replaceAll('-', ' ');
    return words[0].toUpperCase() + words.substring(1);
  }

  /// Create support ticket
  Future<SupportTicket> createSupportTicket({
    required String subject,
    required String description,
    required String category,
    required String priority,
    List<File>? attachments,
  }) async {
    // The real route is POST /support/contact and it takes JSON with a
    // `message` field — not multipart POST /support/tickets with `description`
    // (that path is GET-only, so every call here used to fail). Attachments are
    // not supported server-side; they are accepted and ignored for now.
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/support/contact'),
        headers: await _getHeaders(),
        body: json.encode({
          'subject': subject,
          'message': description,
          'category': category,
          'priority': priority,
        }),
      );

      print('📱 [PROFILE API] Create ticket - Status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return SupportTicket.fromJson(data['data'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to create ticket: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error creating ticket: $e');
      rethrow;
    }
  }

  /// Get user's support tickets
  Future<List<SupportTicket>> getSupportTickets({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '$baseUrl/support/tickets?page=$page&limit=$limit';
      if (status != null) url += '&status=$status';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('📱 [PROFILE API] Get tickets - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final ticketsData = data['data'] as Map<String, dynamic>;
        final ticketsJson = ticketsData['tickets'] as List<dynamic>;
        return ticketsJson
            .map((json) => SupportTicket.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to get tickets: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error getting tickets: $e');
      rethrow;
    }
  }

  /// Get single support ticket with messages
  Future<SupportTicket> getSupportTicket(String ticketId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/support/tickets/$ticketId'),
        headers: headers,
      );

      print('📱 [PROFILE API] Get ticket detail - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final ticketData = data['data'] as Map<String, dynamic>;
        return SupportTicket.fromJson(ticketData['ticket'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to get ticket: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error getting ticket: $e');
      rethrow;
    }
  }

  /// Submit problem report.
  ///
  /// The route is POST /support/report and it reads exactly two JSON fields:
  /// `problemType` (app_crash | payment_issue | login_problem |
  /// feature_not_working | other) and `description`. The old implementation
  /// posted multipart `type`/`title`/`description` to /support/report-problem,
  /// which does not exist.
  Future<ProblemReport> submitProblemReport(ProblemReport report) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/support/report'),
        headers: await _getHeaders(),
        body: json.encode({
          'problemType': report.type,
          // The server has no title field — keep it in the body so support
          // still sees what the user called it.
          'description': report.title.isEmpty
              ? report.description
              : '${report.title}\n\n${report.description}',
        }),
      );

      print('📱 [PROFILE API] Submit report - Status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ProblemReport.fromJson(data['data'] as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else {
        throw Exception('Failed to submit report: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error submitting report: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACCOUNT MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Request account deletion
  Future<void> requestAccountDeletion(String reason) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/users/account'),
        headers: headers,
        body: json.encode({'reason': reason}),
      );

      print('📱 [PROFILE API] Request deletion - Status: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode != 200) {
        throw Exception('Failed to request deletion: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error requesting deletion: $e');
      rethrow;
    }
  }

  /// Deactivate account temporarily
  Future<void> deactivateAccount() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/users/account/deactivate'),
        headers: headers,
      );

      print('📱 [PROFILE API] Deactivate account - Status: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode != 200) {
        throw Exception('Failed to deactivate account: ${response.body}');
      }
    } catch (e) {
      print('❌ [PROFILE API] Error deactivating account: $e');
      rethrow;
    }
  }
}

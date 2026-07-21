// lib/service/support_api.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// SUPPORT API — the endpoints the backend actually exposes
// ═══════════════════════════════════════════════════════════════════════════
// src/routes/supportRoutes.js declares exactly seven routes:
//
//   GET  /support/faq                 ?category= &search=   (public)
//   GET  /support/faq/categories                            (public)
//   POST /support/contact             { subject, category, message, priority }
//   GET  /support/tickets
//   GET  /support/tickets/:ticketNumber
//   POST /support/report              { problemType, description }
//   POST /support/feedback            { feedbackType, message, rating? }
//
// The older helpers in profile_api_service.dart posted multipart bodies to
// /support/tickets and /support/report-problem with field names the server
// never reads (`description` instead of `message`, `type`/`title` instead of
// `problemType`). Those calls could not have succeeded. This client speaks the
// real contract.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Raised when the API answers with a failure. `message` is always safe to show
/// to a user — the server sends human sentences, and we fall back to one.
class SupportException implements Exception {
  final String message;
  SupportException(this.message);

  @override
  String toString() => message;
}

class SupportApi {
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:4000/api';

  static const Duration _timeout = Duration(seconds: 20);

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decode(http.Response res, String fallback) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw SupportException(fallback);
    }

    if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
      return body;
    }

    // The validation middleware returns { message, errors: [...] } — surface the
    // first concrete error rather than the generic "Validation failed".
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw SupportException(errors.first.toString());
    }
    throw SupportException(body['message']?.toString() ?? fallback);
  }

  // ── FAQ ──────────────────────────────────────────────────────────────────

  /// Returns the FAQ grouped by category: { 'payment': [ {id, question, ...} ] }.
  /// `search` is handled server-side by the same endpoint.
  static Future<Map<String, List<Map<String, dynamic>>>> getFaq({
    String? category,
    String? search,
  }) async {
    final query = <String, String>{
      if (category != null && category.isNotEmpty) 'category': category,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final uri = Uri.parse('$_baseUrl/support/faq')
        .replace(queryParameters: query.isEmpty ? null : query);

    final res = await http.get(uri, headers: await _headers()).timeout(_timeout);
    final body = _decode(res, 'Could not load the FAQ.');

    final grouped = (body['data']?['faqs'] ?? {}) as Map<String, dynamic>;
    return grouped.map(
      (key, value) => MapEntry(
        key,
        (value as List).cast<Map<String, dynamic>>(),
      ),
    );
  }

  // ── Contact support ──────────────────────────────────────────────────────

  /// Creates a support ticket. Returns the ticket number so the user has a
  /// reference to quote. Server rules: subject 5-200, message 20-2000.
  static Future<String?> createTicket({
    required String subject,
    required String message,
    required String category,
    required String priority,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/support/contact'),
          headers: await _headers(),
          body: jsonEncode({
            'subject': subject,
            'message': message,
            'category': category,
            'priority': priority,
          }),
        )
        .timeout(_timeout);

    final body = _decode(res, 'Could not send your request.');
    return body['data']?['ticketNumber']?.toString();
  }

  // ── Report a problem ─────────────────────────────────────────────────────

  /// Files a problem report. `problemType` must be one of app_crash,
  /// payment_issue, login_problem, feature_not_working, other.
  /// Server rule: description 20-2000.
  static Future<String?> reportProblem({
    required String problemType,
    required String description,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_baseUrl/support/report'),
          headers: await _headers(),
          body: jsonEncode({
            'problemType': problemType,
            'description': description,
          }),
        )
        .timeout(_timeout);

    final body = _decode(res, 'Could not send the report.');
    return body['data']?['reportNumber']?.toString();
  }
}

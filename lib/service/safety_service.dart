// lib/service/safety_service.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// SAFETY — real SOS and share-trip for the ride flow
// ═══════════════════════════════════════════════════════════════════════════
// Used by BOTH the passenger and the driver in-trip screens. SOS must be
// dependable: it captures the caller's live location, records the alert on the
// server (which also alerts the other party + ops), and then dials the local
// emergency number. Every step is best-effort so a network hiccup can never
// stop the phone call — the call is what saves a life.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SosResult {
  final bool alertSent;
  final bool dialled;
  final String emergencyNumber;
  const SosResult({
    required this.alertSent,
    required this.dialled,
    required this.emergencyNumber,
  });
}

class SafetyService {
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:4000/api';

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Best-effort current position — returns null rather than throwing so SOS
  /// still proceeds (recording + dialling) when location is unavailable.
  static Future<Position?> _currentPosition() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  /// Raises the alarm for [tripId]: records the alert server-side (with live
  /// location) and dials the local emergency number. Order is deliberate —
  /// the recording is fired but NOT awaited past a short timeout, so the call
  /// is never delayed by a slow network.
  static Future<SosResult> raiseSos(String tripId) async {
    final pos = await _currentPosition();

    String emergencyNumber = '117'; // Cameroon police — server may override
    bool alertSent = false;

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/trips/$tripId/sos'),
            headers: await _headers(),
            body: jsonEncode({
              if (pos != null) 'lat': pos.latitude,
              if (pos != null) 'lng': pos.longitude,
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        alertSent = true;
        final data = jsonDecode(res.body)['data'];
        final n = data?['emergency_number']?.toString();
        if (n != null && n.isNotEmpty) emergencyNumber = n;
      }
    } catch (_) {
      // Swallow — dialling must still happen.
    }

    final dialled = await _dial(emergencyNumber);
    return SosResult(
      alertSent: alertSent,
      dialled: dialled,
      emergencyNumber: emergencyNumber,
    );
  }

  static Future<bool> _dial(String number) async {
    try {
      final uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Requests a tokenised tracking link and shares it. Without share_plus, we
  /// copy the link to the clipboard and open the SMS composer prefilled — both
  /// are real, offline-safe share paths. Returns the link, or null on failure.
  static Future<String?> shareTrip(String tripId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/trips/$tripId/share'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final url = jsonDecode(res.body)['data']?['url']?.toString();
      if (url == null || url.isEmpty) return null;

      await Clipboard.setData(ClipboardData(text: url));
      // Prefill an SMS — the user picks the recipient.
      final sms = Uri.parse(
        'sms:?body=${Uri.encodeComponent('Suivez ma course WeGo en temps réel : $url')}',
      );
      try {
        if (await canLaunchUrl(sms)) {
          await launchUrl(sms, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}
      return url;
    } catch (_) {
      return null;
    }
  }
}

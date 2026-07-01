// lib/services/mode_service.dart
//
// ═══════════════════════════════════════════════════════════════════════
// MODE SERVICE
// ═══════════════════════════════════════════════════════════════════════
//
// Single source of truth for all mode-switching logic in the app.
//
// Responsibilities:
//   1. Call POST /api/auth/switch-mode
//   2. Save new tokens + active_mode to SharedPreferences
//   3. Reconnect socket with new token
//   4. Return the route string to navigate to
//
// ── Permission matrix (mirrors backend allowedMap) ────────────────────
//
//   user_type         active_mode        can switch TO
//   ──────────────────────────────────────────────────
//   PASSENGER         PASSENGER          (nothing — pill never shown)
//   DELIVERY_AGENT    DELIVERY_AGENT     PASSENGER
//   DELIVERY_AGENT    PASSENGER          DELIVERY_AGENT          ← fixed
//   DRIVER            DRIVER             DELIVERY_AGENT, PASSENGER
//   DRIVER            DELIVERY_AGENT     DRIVER, PASSENGER
//   DRIVER            PASSENGER          DRIVER, DELIVERY_AGENT
//
// ═══════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../main.dart'; // SocketHelper

// ─── Result object returned by switchTo() ────────────────────────────

// NEW
class ModeSwitchResult {
  final bool    success;
  final String? route;
  final String? activeMode;
  final String? newAccessToken;   // ← new token issued by switch-mode
  final String? errorMessage;
  final String? errorCode;

  const ModeSwitchResult._({
    required this.success,
    this.route,
    this.activeMode,
    this.newAccessToken,
    this.errorMessage,
    this.errorCode,
  });

  factory ModeSwitchResult.ok({
    required String route,
    required String activeMode,
    required String newAccessToken,
  }) =>
      ModeSwitchResult._(
        success:        true,
        route:          route,
        activeMode:     activeMode,
        newAccessToken: newAccessToken,
      );

  factory ModeSwitchResult.fail({
    required String message,
    String? code,
  }) =>
      ModeSwitchResult._(
          success: false, errorMessage: message, errorCode: code);
}

// ─── Target option shown in the UI ───────────────────────────────────

class ModeTarget {
  final String mode;
  final String label;
  final String emoji;

  const ModeTarget({
    required this.mode,
    required this.label,
    required this.emoji,
  });
}

// ═══════════════════════════════════════════════════════════════════════
// MODE SERVICE
// ═══════════════════════════════════════════════════════════════════════

class ModeService {
  // ── Route map ─────────────────────────────────────────────────────
  static const _routes = {
    'PASSENGER':      '/dashboard/passenger',
    'DRIVER':         '/dashboard/driver',
    'DELIVERY_AGENT': '/dashboard/delivery-agent',
  };

  // ═══════════════════════════════════════════════════════════════════
  // availableTargets
  // ─────────────────────────────────────────────────────────────────
  // Returns the list of modes this user can switch TO.
  // The list excludes the current active_mode (no point switching
  // to where you already are).
  // ═══════════════════════════════════════════════════════════════════

  static List<ModeTarget> availableTargets({
    required String userType,
    required String activeMode,
  }) {
    // Native passengers never see the switch button.
    if (userType == 'PASSENGER') return [];

    // ── DELIVERY_AGENT ─────────────────────────────────────────────
    if (userType == 'DELIVERY_AGENT') {
      if (activeMode == 'DELIVERY_AGENT') {
        // Currently in delivery mode → can only go to passenger.
        return [
          ModeTarget(
            mode:  'PASSENGER',
            label: 'Switch to Regular User',
            emoji: '🧑',
          ),
        ];
      }

      if (activeMode == 'PASSENGER') {
        // Currently in passenger mode → go back to delivery agent.
        return [
          ModeTarget(
            mode:  'DELIVERY_AGENT',
            label: 'Switch to Delivery Agent Mode',
            emoji: '📦',
          ),
        ];
      }

      // Fallback — should never happen for DELIVERY_AGENT,
      // but return passenger as a safe default.
      return [
        ModeTarget(
          mode:  'PASSENGER',
          label: 'Switch to Regular User',
          emoji: '🧑',
        ),
      ];
    }

    // ── DRIVER ─────────────────────────────────────────────────────
    if (userType == 'DRIVER') {
      if (activeMode == 'DRIVER') {
        // In ride-hailing mode → can go to delivery agent or passenger.
        return [
          ModeTarget(
            mode:  'DELIVERY_AGENT',
            label: 'Switch to Delivery Agent',
            emoji: '📦',
          ),
          ModeTarget(
            mode:  'PASSENGER',
            label: 'Switch to Regular User',
            emoji: '🧑',
          ),
        ];
      }

      if (activeMode == 'DELIVERY_AGENT') {
        // In delivery mode → can go back to driver or to passenger.
        return [
          ModeTarget(
            mode:  'DRIVER',
            label: 'Switch to Driver Mode',
            emoji: '🚗',
          ),
          ModeTarget(
            mode:  'PASSENGER',
            label: 'Switch to Regular User',
            emoji: '🧑',
          ),
        ];
      }

      if (activeMode == 'PASSENGER') {
        // In passenger mode → can go back to driver or delivery agent.
        return [
          ModeTarget(
            mode:  'DRIVER',
            label: 'Switch to Driver Mode',
            emoji: '🚗',
          ),
          ModeTarget(
            mode:  'DELIVERY_AGENT',
            label: 'Switch to Delivery Agent',
            emoji: '📦',
          ),
        ];
      }
    }

    return [];
  }

  // ═══════════════════════════════════════════════════════════════════
  // switchTo
  // ─────────────────────────────────────────────────────────────────
  // Calls the backend, persists new tokens + active_mode,
  // reconnects socket, returns the route to navigate to.
  // ═══════════════════════════════════════════════════════════════════

  static Future<ModeSwitchResult> switchTo(String targetMode) async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔄 [MODE-SERVICE] Switching to: $targetMode');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final prefs    = await SharedPreferences.getInstance();
      final token    = prefs.getString('access_token') ?? '';
      final userId   = prefs.getString('user_uuid')    ?? '';
      final userType = prefs.getString('user_type')    ?? '';

      if (token.isEmpty) {
        return ModeSwitchResult.fail(
          message: 'Not authenticated. Please login again.',
          code:    'NO_TOKEN',
        );
      }

      // ── API call ────────────────────────────────────────────────
      final response = await http
          .post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/switch-mode'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'target_mode': targetMode}),
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📡 [MODE-SERVICE] Response: ${response.statusCode}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data          = body['data'] as Map<String, dynamic>;
        final newToken      = data['access_token']  as String? ?? '';
        final newRefresh    = data['refresh_token'] as String? ?? '';
        final newActiveMode = data['active_mode']   as String? ?? targetMode;

        // ── Persist ─────────────────────────────────────────────
        await prefs.setString('access_token', newToken);
        await prefs.setString('active_mode',  newActiveMode);
        if (newRefresh.isNotEmpty) {
          await prefs.setString('refresh_token', newRefresh);
        }

        debugPrint('✅ [MODE-SERVICE] Saved — active_mode: $newActiveMode');



        final route = _routes[newActiveMode] ?? '/login';

        debugPrint('✅ [MODE-SERVICE] Switch complete → $route');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

// NEW
        return ModeSwitchResult.ok(
          route:          route,
          activeMode:     newActiveMode,
          newAccessToken: newToken,
        );
      } else {
        final message =
            body['message'] as String? ?? 'Mode switch failed.';
        final code = body['code'] as String? ?? 'SWITCH_FAILED';

        debugPrint('❌ [MODE-SERVICE] Failed: $message ($code)');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        return ModeSwitchResult.fail(message: message, code: code);
      }
    } on SocketException {
      debugPrint('❌ [MODE-SERVICE] No internet connection');
      return ModeSwitchResult.fail(
        message: 'No internet connection.',
        code:    'NETWORK_ERROR',
      );
    } on TimeoutException {
      debugPrint('❌ [MODE-SERVICE] Request timeout');
      return ModeSwitchResult.fail(
        message: 'Request timed out. Please try again.',
        code:    'TIMEOUT',
      );
    } catch (e) {
      debugPrint('❌ [MODE-SERVICE] Unexpected error: $e');
      return ModeSwitchResult.fail(
        message: 'Something went wrong. Please try again.',
        code:    'UNKNOWN_ERROR',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // getCurrentMode
  // ─────────────────────────────────────────────────────────────────
  // Reads active_mode from SharedPreferences.
  // Falls back to user_type for accounts created before mode switching.
  // ═══════════════════════════════════════════════════════════════════

  static Future<String> getCurrentMode() async {
    final prefs  = await SharedPreferences.getInstance();
    final saved  = prefs.getString('active_mode');
    if (saved != null && saved.isNotEmpty) return saved;

    final userType = prefs.getString('user_type') ?? '';
    return modeFromUserType(userType);
  }

  // ═══════════════════════════════════════════════════════════════════
  // routeForMode
  // ─────────────────────────────────────────────────────────────────
  // Returns the named route for a given active_mode.
  // Used by SplashScreen after token validation.
  // ═══════════════════════════════════════════════════════════════════

  static String routeForMode(String activeMode) {
    return _routes[activeMode] ?? '/login';
  }

  // ═══════════════════════════════════════════════════════════════════
  // saveActiveMode
  // ─────────────────────────────────────────────────────────────────
  // Called after login to persist the active_mode returned by backend.
  // ═══════════════════════════════════════════════════════════════════

  static Future<void> saveActiveMode(
      String? activeMode, String userType) async {
    final prefs    = await SharedPreferences.getInstance();
    final resolved = activeMode ?? modeFromUserType(userType);
    await prefs.setString('active_mode', resolved);
    debugPrint('✅ [MODE-SERVICE] active_mode saved: $resolved');
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  static String modeFromUserType(String userType) {
    const map = {
      'PASSENGER':      'PASSENGER',
      'DRIVER':         'DRIVER',
      'DELIVERY_AGENT': 'DELIVERY_AGENT',
    };
    return map[userType] ?? 'PASSENGER';
  }
}
// lib/widgets/notification_badge.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../../utils/app_typography.dart';


// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICATION BADGE WIDGET
// ═══════════════════════════════════════════════════════════════════════════════
//
// Wraps any widget (typically a bell icon) with an unread count badge.
//
// Usage — wrap your bell icon in the nav bar or appbar:
//
//   NotificationBadge(
//     child: Icon(Icons.notifications_outlined),
//     onTap: () => Navigator.pushNamed(context, '/notifications'),
//   )
//
// Polling:
//   - Fetches unread count on mount
//   - Re-fetches every 60 seconds automatically
//   - Call NotificationBadge.refresh() from anywhere to force a refresh
//     e.g. after returning from NotificationScreen or receiving a push
//
// ═══════════════════════════════════════════════════════════════════════════════

class NotificationBadge extends StatefulWidget {
  final Widget      child;
  final VoidCallback? onTap;
  final Color       badgeColor;
  final Color       textColor;

  const NotificationBadge({
    super.key,
    required this.child,
    this.onTap,
    this.badgeColor = const Color(0xFFE53935),
    this.textColor  = Colors.white,
  });

  @override
  State<NotificationBadge> createState() => NotificationBadgeState();

  // ── Static refresh trigger ─────────────────────────────────────────────────
  // Call this from anywhere to force an immediate badge refresh:
  //   NotificationBadge.refresh();
  static final _refreshNotifier = _BadgeRefreshNotifier();
  static void refresh() => _refreshNotifier.notify();
}

// ── Internal notifier (simple broadcast) ──────────────────────────────────────
class _BadgeRefreshNotifier {
  final List<VoidCallback> _listeners = [];
  void addListener(VoidCallback cb)    => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);
  void notify() {
    for (final cb in List.from(_listeners)) cb();
  }
}

class NotificationBadgeState extends State<NotificationBadge> {
  int    _unreadCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchCount();

    // Poll every 60 seconds
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchCount());

    // Listen for manual refresh triggers
    NotificationBadge._refreshNotifier.addListener(_fetchCount);
  }

  @override
  void dispose() {
    _timer?.cancel();
    NotificationBadge._refreshNotifier.removeListener(_fetchCount);
    super.dispose();
  }

  Future<void> _fetchCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      if (token.isEmpty) return;

      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/notifications/unread-count'),
        headers: { 'Authorization': 'Bearer $token' },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body  = jsonDecode(res.body);
        final count = body['data']?['unread_count'] ?? 0;
        if (mounted && _unreadCount != count) {
          setState(() => _unreadCount = count as int);
        }
      }
    } catch (_) {
      // Non-critical — badge just stays at last known value
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap?.call();
        // Refresh count when user opens the screen
        Future.delayed(const Duration(milliseconds: 800), _fetchCount);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,

          if (_unreadCount > 0)
            Positioned(
              top:   -4,
              right: -4,
              child: AnimatedScale(
                scale:    _unreadCount > 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve:    Curves.easeOutBack,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth:  18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color:        widget.badgeColor,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color:      widget.badgeColor.withOpacity(0.4),
                        blurRadius: 6,
                        offset:     const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: TextStyle(
                        fontFamily: AppTypography.secondaryFont,
                        fontSize:   _unreadCount > 9 ? 9 : 10,
                        fontWeight: FontWeight.w700,
                        color:      widget.textColor,
                        height:     1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
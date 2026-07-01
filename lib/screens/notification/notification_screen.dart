// lib/screens/notifications/notification_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

 import '../../core/config.dart';
import '../../service/notification_service.dart';
 import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════════════════════

class NotificationItem {
  final String  id;
  final String  title;
  final String  body;
  final String  type;
  final Map<String, dynamic>? data;
  final bool    isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id:        json['id']?.toString() ?? '',
      title:     json['title']?.toString() ?? '',
      body:      json['body']?.toString() ?? '',
      type:      json['type']?.toString() ?? '',
      data:      json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      isRead:    json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  NotificationItem copyWith({ bool? isRead }) => NotificationItem(
    id:        id,
    title:     title,
    body:      body,
    type:      type,
    data:      data,
    isRead:    isRead ?? this.isRead,
    createdAt: createdAt,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

IconData _iconForType(String type) {
  if (type.startsWith('RIDE_'))              return Icons.local_taxi_outlined;
  if (type.startsWith('DELIVERY_'))          return Icons.inventory_2_outlined;
  if (type.startsWith('SERVICE_'))           return Icons.build_outlined;
  if (type.startsWith('WALLET_'))            return Icons.account_balance_wallet_outlined;
  if (type.startsWith('RENTAL_'))            return Icons.car_rental_outlined;
  if (type.startsWith('ACCOUNT_'))           return Icons.person_outline_rounded;
  if (type.startsWith('SUPPORT_'))           return Icons.headset_mic_outlined;
  if (type == 'BROADCAST')                   return Icons.campaign_outlined;
  return Icons.notifications_outlined;
}

Color _colorForType(String type) {
  if (type.startsWith('RIDE_'))              return const Color(0xFF4CAF50);
  if (type.startsWith('DELIVERY_'))          return const Color(0xFFFF9800);
  if (type.startsWith('SERVICE_'))           return const Color(0xFF2196F3);
  if (type.startsWith('WALLET_TOPUP'))       return const Color(0xFF4CAF50);
  if (type.startsWith('WALLET_WITHDRAWAL'))  return const Color(0xFF9C27B0);
  if (type.startsWith('WALLET_'))            return const Color(0xFF9C27B0);
  if (type.startsWith('RENTAL_'))            return const Color(0xFF00BCD4);
  if (type == 'ACCOUNT_SUSPENDED')           return const Color(0xFFF44336);
  if (type.startsWith('ACCOUNT_'))           return AppColors.primaryGold;
  if (type.startsWith('SUPPORT_'))           return const Color(0xFF607D8B);
  if (type == 'BROADCAST')                   return AppColors.primaryDark;
  return AppColors.textSecondary;
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {

  List<NotificationItem> _items    = [];
  bool   _loading                  = true;
  bool   _loadingMore              = false;
  bool   _markingAll               = false;
  int    _page                     = 1;
  int    _totalPages               = 1;
  String? _error;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetch();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  // ── Infinite scroll ────────────────────────────────────────────────────────
  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
        !_loadingMore && _page < _totalPages) {
      _fetchMore();
    }
  }

  // ── API helpers ────────────────────────────────────────────────────────────

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? '';
  }

  String get _baseUrl => AppConfig.apiBaseUrl;

  Future<void> _fetch({ bool refresh = false }) async {
    if (refresh) {
      setState(() { _page = 1; _items = []; _loading = true; _error = null; });
    }

    try {
      final token = await _token();
      final res = await http.get(
        Uri.parse('$_baseUrl/notifications?page=1&limit=20'),
        headers: { 'Authorization': 'Bearer $token' },
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data']['notifications'] as List? ?? [])
            .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final pagination = body['data']['pagination'];
        setState(() {
          _items      = list;
          _totalPages = pagination['total_pages'] ?? 1;
          _page       = 1;
          _loading    = false;
          _error      = null;
        });
      } else {
        setState(() { _loading = false; _error = 'Failed to load notifications'; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = 'Network error. Pull to refresh.'; });
    }
  }

  Future<void> _fetchMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);

    try {
      final token    = await _token();
      final nextPage = _page + 1;
      final res = await http.get(
        Uri.parse('$_baseUrl/notifications?page=$nextPage&limit=20'),
        headers: { 'Authorization': 'Bearer $token' },
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['data']['notifications'] as List? ?? [])
            .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        setState(() {
          _items.addAll(list);
          _page       = nextPage;
          _loadingMore = false;
        });
      }
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAsRead(NotificationItem item) async {
    if (item.isRead) return;

    // Optimistic update
    setState(() {
      final idx = _items.indexWhere((n) => n.id == item.id);
      if (idx != -1) _items[idx] = item.copyWith(isRead: true);
    });

    try {
      final token = await _token();
      await http.patch(
        Uri.parse('$_baseUrl/notifications/${item.id}/read'),
        headers: { 'Authorization': 'Bearer $token' },
      );
    } catch (_) {
      // Revert on failure
      setState(() {
        final idx = _items.indexWhere((n) => n.id == item.id);
        if (idx != -1) _items[idx] = item.copyWith(isRead: false);
      });
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    final hasUnread = _items.any((n) => !n.isRead);
    if (!hasUnread) return;

    setState(() => _markingAll = true);

    // Optimistic update
    setState(() {
      _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    });

    try {
      final token = await _token();
      await http.patch(
        Uri.parse('$_baseUrl/notifications/read-all'),
        headers: { 'Authorization': 'Bearer $token' },
      );
    } catch (_) {
      // Non-critical — user already sees them as read visually
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  // ── On tap: mark read + navigate ──────────────────────────────────────────
  void _onTap(NotificationItem item) {
    _markAsRead(item);

    if (item.data != null && item.data!.isNotEmpty) {
      final type = _typeFromString(item.type);
      NotificationService.instance.onNotificationTap?.call(type, {
        ...item.data!,
        'type': item.type,
      });
    }
  }

  NotificationType _typeFromString(String type) {
    // Reuse the same mapping from NotificationService
    // Just map via the service's internal logic
    switch (type) {
      case 'RIDE_DRIVER_MATCHED':         return NotificationType.rideDriverMatched;
      case 'RIDE_DRIVER_ARRIVED':         return NotificationType.rideDriverArrived;
      case 'RIDE_CANCELLED':              return NotificationType.rideCancelled;
      case 'RIDE_TRIP_OFFER':             return NotificationType.rideTripOffer;
      case 'RIDE_OFFER_EXPIRED':          return NotificationType.rideOfferExpired;
      case 'RIDE_PAYMENT_RECEIVED':       return NotificationType.ridePaymentReceived;
      case 'DELIVERY_AGENT_ASSIGNED':     return NotificationType.deliveryAgentAssigned;
      case 'DELIVERY_PICKED_UP':          return NotificationType.deliveryPickedUp;
      case 'DELIVERY_CANCELLED':          return NotificationType.deliveryCancelled;
      case 'DELIVERY_OFFER':              return NotificationType.deliveryOffer;
      case 'DELIVERY_OFFER_EXPIRED':      return NotificationType.deliveryOfferExpired;
      case 'DELIVERY_PAYMENT_RECEIVED':   return NotificationType.deliveryPaymentReceived;
      case 'SERVICE_REQUEST_ACCEPTED':    return NotificationType.serviceRequestAccepted;
      case 'SERVICE_REQUEST_REJECTED':    return NotificationType.serviceRequestRejected;
      case 'SERVICE_DISPUTE_RESOLVED':    return NotificationType.serviceDisputeResolved;
      case 'SERVICE_NEW_REQUEST':         return NotificationType.serviceNewRequest;
      case 'WALLET_TOPUP_SUCCESS':        return NotificationType.walletTopupSuccess;
      case 'WALLET_TOPUP_FAILED':         return NotificationType.walletTopupFailed;
      case 'WALLET_WITHDRAWAL_REQUESTED': return NotificationType.walletWithdrawalRequested;
      case 'WALLET_WITHDRAWAL_COMPLETED': return NotificationType.walletWithdrawalCompleted;
      case 'WALLET_WITHDRAWAL_FAILED':    return NotificationType.walletWithdrawalFailed;
      case 'RENTAL_APPROVED':             return NotificationType.rentalApproved;
      case 'RENTAL_EXPIRY_REMINDER':      return NotificationType.rentalExpiryReminder;
      case 'ACCOUNT_APPROVED':            return NotificationType.accountApproved;
      case 'ACCOUNT_SUSPENDED':           return NotificationType.accountSuspended;
      case 'ACCOUNT_PASSWORD_CHANGED':    return NotificationType.accountPasswordChanged;
      case 'ACCOUNT_NEW_DEVICE_LOGIN':    return NotificationType.accountNewDeviceLogin;
      case 'SUPPORT_TICKET_REPLY':        return NotificationType.supportTicketReply;
      case 'SUPPORT_TICKET_RESOLVED':     return NotificationType.supportTicketResolved;
      case 'BROADCAST':                   return NotificationType.broadcast;
      default:                            return NotificationType.unknown;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontFamily: AppTypography.primaryFont,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (unreadCount > 0)
              Text(
                '$unreadCount unread',
                style: TextStyle(
                  fontFamily: AppTypography.secondaryFont,
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              child: _markingAll
                  ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
                  : Text(
                'Mark all read',
                style: TextStyle(
                  fontFamily: AppTypography.secondaryFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGold,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGold,
        onRefresh: () => _fetch(refresh: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(AppColors.primaryGold),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_outlined, size: 48, color: AppColors.textLight),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.secondaryFont,
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => _fetch(refresh: true),
                child: Text(
                  'Try again',
                  style: TextStyle(
                    fontFamily: AppTypography.secondaryFont,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDECEA),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.notifications_none_outlined,
                  size: 40,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No notifications yet',
                style: TextStyle(
                  fontFamily: AppTypography.primaryFont,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Trip updates, delivery alerts and\nwallet activity will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.secondaryFont,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.primaryGold),
              ),
            ),
          );
        }
        return _NotificationTile(
          item:      _items[index],
          onTap:     () => _onTap(_items[index]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICATION TILE
// ═══════════════════════════════════════════════════════════════════════════════

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback     onTap;

  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color   = _colorForType(item.type);
    final icon    = _iconForType(item.type);
    final isUnread = !item.isRead;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isUnread ? Colors.white : const Color(0xFFFAF9F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? color.withOpacity(0.25)
                : const Color(0xFFECEAE5),
            width: isUnread ? 1.5 : 1.0,
          ),
          boxShadow: isUnread
              ? [BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )]
              : [BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 4,
            offset: const Offset(0, 1),
          )],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Icon badge
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 22),
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontFamily: AppTypography.primaryFont,
                              fontSize: 14,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Unread dot
                        if (isUnread)
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontFamily: AppTypography.secondaryFont,
                        fontSize: 13,
                        color: isUnread
                            ? AppColors.textSecondary
                            : AppColors.textLight,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeago.format(item.createdAt),
                      style: TextStyle(
                        fontFamily: AppTypography.secondaryFont,
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
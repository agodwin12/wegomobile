// lib/presentation/screens/delivery_agent/delivery_agent_dashboard.dart
//
// Delivery Agent Dashboard — Production Ready
// ─────────────────────────────────────────────────────────────────────────────
//
// CHANGELOG:
//   ✅ FIX: _fetchWallet() now reads body['data'] instead of body['wallet']
//      to match the controller response shape:
//        { success: true, data: { wallet_id, balance, available_balance, ... } }
//   ✅ Mode switch pill in SliverAppBar actions
//   ✅ Socket: delivery:new_request, delivery:request_expired, delivery:cancelled
//   ✅ Active delivery resume banner with slide animation
//   ✅ Offer overlay with countdown timer + accept/decline
//   ✅ GPS updates every 15s while online

import 'dart:async';
import 'dart:convert';
import '../../../authentication service/api_services.dart';

import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/mode_switch_sheet.dart';
import '../../notification/notification_badge.dart';
import '../../notification/notification_screen.dart';
import '../agent_profile/agent_profile_screen.dart';
import '../delivery wallet/delivery_wallet_screen.dart';
import '../delivery_active/delivery_active_screen.dart';
import '../delivery_express/delivery_active_express_screen.dart';
import '../delivery_history/delivery_history_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _Wallet {
  final double balance;
  final double availableBalance;
  final double reservedBalance;
  final double totalEarned;
  final double totalCommissionPaid;
  final double outstandingCommission;
  final String status;
  final bool   canAcceptJobs;
  final String? frozenReason;

  const _Wallet({
    required this.balance,
    required this.availableBalance,
    required this.reservedBalance,
    required this.totalEarned,
    required this.totalCommissionPaid,
    required this.outstandingCommission,
    required this.status,
    required this.canAcceptJobs,
    this.frozenReason,
  });

  factory _Wallet.empty() => const _Wallet(
    balance:               0,
    availableBalance:      0,
    reservedBalance:       0,
    totalEarned:           0,
    totalCommissionPaid:   0,
    outstandingCommission: 0,
    status:        'active',
    canAcceptJobs: false,
  );

  /// Controller returns body['data'] with snake_case keys:
  ///   balance, available_balance, reserved_balance, total_earned,
  ///   total_commission_paid, outstanding_commission, status,
  ///   can_accept_jobs, frozen_reason
  factory _Wallet.fromJson(Map<String, dynamic> j) => _Wallet(
    balance:               _n(j['balance']),
    availableBalance:      _n(j['available_balance']      ?? j['availableBalance']),
    reservedBalance:       _n(j['reserved_balance']       ?? j['reservedBalance']),
    totalEarned:           _n(j['total_earned']           ?? j['totalEarned']),
    totalCommissionPaid:   _n(j['total_commission_paid']  ?? j['totalCommissionPaid']),
    outstandingCommission: _n(j['outstanding_commission'] ?? j['outstandingCommission']),
    status:        j['status']          as String? ?? 'active',
    canAcceptJobs: j['can_accept_jobs'] as bool?   ?? j['canAcceptJobs'] as bool? ?? false,
    frozenReason:  j['frozen_reason']   as String? ?? j['frozenReason']  as String?,
  );

  static double _n(dynamic v) => (v as num? ?? 0).toDouble();
}

class _ActiveDeliverySummary {
  final int    id;
  final String deliveryCode;
  final String deliveryType;
  final String trackingMode;
  final String status;
  final String pickupAddress;
  final String dropoffAddress;
  final double driverPayout;

  const _ActiveDeliverySummary({
    required this.id,
    required this.deliveryCode,
    required this.deliveryType,
    required this.trackingMode,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.driverPayout,
  });

  factory _ActiveDeliverySummary.fromJson(Map<String, dynamic> j) {
    final pickup  = j['pickup']  as Map? ?? {};
    final dropoff = j['dropoff'] as Map? ?? {};
    return _ActiveDeliverySummary(
      id:             j['id'] as int,
      deliveryCode:   j['deliveryCode']  as String? ?? j['delivery_code']  as String? ?? '',
      deliveryType:   j['deliveryType']  as String? ?? j['delivery_type']  as String? ?? 'regular',
      trackingMode:   j['trackingMode']  as String? ?? j['tracking_mode']  as String? ?? 'stage_updates',
      status:         j['status']        as String? ?? 'accepted',
      pickupAddress:  pickup['address']  as String? ?? j['pickup_address']  as String? ?? '',
      dropoffAddress: dropoff['address'] as String? ?? j['dropoff_address'] as String? ?? '',
      driverPayout:   (j['driverPayout'] ?? j['driver_payout'] as num? ?? 0).toDouble(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'accepted':         return 'Head to pickup';
      case 'en_route_pickup':  return 'On the way to pickup';
      case 'arrived_pickup':   return 'At pickup — collect package';
      case 'picked_up':        return 'Package collected';
      case 'en_route_dropoff': return 'On the way to dropoff';
      case 'arrived_dropoff':  return 'At dropoff — ask for PIN';
      default:                 return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'accepted':
      case 'en_route_pickup':  return AppColors.info;
      case 'arrived_pickup':
      case 'picked_up':        return AppColors.warning;
      case 'en_route_dropoff':
      case 'arrived_dropoff':  return AppColors.primaryGold;
      default:                 return AppColors.success;
    }
  }
}

const _kActiveStatuses = [
  'accepted',
  'en_route_pickup',
  'arrived_pickup',
  'picked_up',
  'en_route_dropoff',
  'arrived_dropoff',
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryAgentDashboard extends StatefulWidget {
  const DeliveryAgentDashboard({super.key});

  @override
  State<DeliveryAgentDashboard> createState() => _DeliveryAgentDashboardState();
}

class _DeliveryAgentDashboardState extends State<DeliveryAgentDashboard>
    with TickerProviderStateMixin {

  // ── User info ────────────────────────────────────────────────────────────
  String _firstName   = '';
  String _lastName    = '';
  String _avatarUrl   = '';
  String _accessToken = '';

  // ── Status ───────────────────────────────────────────────────────────────
  bool _isOnline       = false;
  bool _togglingStatus = false;

  // ── Wallet ───────────────────────────────────────────────────────────────
  _Wallet _wallet        = _Wallet.empty();
  bool    _loadingWallet = true;

  // ── Active delivery ───────────────────────────────────────────────────────
  _ActiveDeliverySummary? _activeDelivery;
  bool _loadingActiveDelivery  = true;
  bool _resumingActiveDelivery = false;

  // ── GPS ──────────────────────────────────────────────────────────────────
  Timer?    _gpsTimer;
  Position? _lastPosition;

  // ── Socket ───────────────────────────────────────────────────────────────
  io.Socket? _socket;
  bool       _socketConnected = false;

  // ── Offer overlay ────────────────────────────────────────────────────────
  Map<String, dynamic>? _pendingOffer;
  bool                  _offerVisible     = false;
  int                   _offerSecondsLeft = 25;
  Timer?                _offerTimer;
  bool                  _acceptingOffer   = false;

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;
  late AnimationController _offerCtrl;
  late Animation<double>   _offerScale;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;
  late AnimationController _bannerCtrl;
  late Animation<Offset>   _bannerSlide;

  // ─────────────────────────────────────────────────────────────────────────
  // INIT / DISPOSE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _bootstrap();
  }

  void _initAnimations() {
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _offerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _offerScale =
        CurvedAnimation(parent: _offerCtrl, curve: Curves.easeOutBack);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _bannerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _bannerSlide = Tween<Offset>(
        begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _bannerCtrl, curve: Curves.easeOutCubic));
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _firstName   = prefs.getString('first_name')   ?? '';
      _lastName    = prefs.getString('last_name')    ?? '';
      _avatarUrl   = prefs.getString('avatar_url')   ?? '';
      _accessToken = prefs.getString('access_token') ?? '';
      _isOnline    = prefs.getBool('is_online')      ?? false;
    });

    await Future.wait([_fetchWallet(), _checkActiveDelivery()]);
    _connectSocket();
    if (_isOnline) _startGpsUpdates();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _offerCtrl.dispose();
    _pulseCtrl.dispose();
    _bannerCtrl.dispose();
    _gpsTimer?.cancel();
    _offerTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIVE DELIVERY CHECK
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _checkActiveDelivery() async {
    if (_accessToken.isEmpty) {
      if (mounted) setState(() => _loadingActiveDelivery = false);
      return;
    }
    try {
      final statusQuery = _kActiveStatuses.join(',');
      final res = await http.get(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/deliveries/driver/history?status=$statusQuery&page=1&limit=1'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body       = jsonDecode(res.body) as Map<String, dynamic>;
        final deliveries = body['deliveries'] as List?;
        if (deliveries != null && deliveries.isNotEmpty) {
          final d = _ActiveDeliverySummary.fromJson(
              deliveries.first as Map<String, dynamic>);
          if (mounted) {
            setState(() {
              _activeDelivery        = d;
              _loadingActiveDelivery = false;
            });
            _bannerCtrl.forward();
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ [DASHBOARD] checkActiveDelivery error: $e');
    }
    if (mounted) setState(() => _loadingActiveDelivery = false);
  }

  Future<void> _resumeActiveDelivery() async {
    final summary = _activeDelivery;
    if (summary == null || _resumingActiveDelivery) return;
    setState(() => _resumingActiveDelivery = true);

    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/${summary.id}'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body     = jsonDecode(res.body) as Map<String, dynamic>;
        final dJson    = (body['delivery'] ?? body) as Map<String, dynamic>;
        final delivery = ActiveDelivery.fromJson(dJson);

        if (mounted) {
          final route = delivery.trackingMode == 'live_map'
              ? MaterialPageRoute(
              builder: (_) => DeliveryActiveExpressScreen(
                  delivery: delivery, socket: _socket))
              : MaterialPageRoute(
              builder: (_) => DeliveryActiveScreen(
                  delivery: delivery, socket: _socket));

          await Navigator.of(context).push(route);

          if (mounted) {
            setState(() {
              _activeDelivery        = null;
              _loadingActiveDelivery = true;
            });
            await Future.wait([_fetchWallet(), _checkActiveDelivery()]);
          }
        }
        return;
      }
      _showSnack('Could not load delivery. Try again.', isError: true);
    } catch (e) {
      _showSnack('Network error. Try again.', isError: true);
    }
    if (mounted) setState(() => _resumingActiveDelivery = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCKET
  // ─────────────────────────────────────────────────────────────────────────

  void _connectSocket() {
    if (_accessToken.isEmpty) return;
    _socket?.disconnect();
    _socket?.dispose();

    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _accessToken})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.connect();

    _socket!.on('connect', (_) {
      debugPrint('🔌 [AGENT] Socket connected: ${_socket!.id}');
      if (mounted) {
        setState(() => _socketConnected = true);
        // Refresh active delivery state on reconnect so stale banner never persists
        _checkActiveDelivery();
      }
    });

    _socket!.on('disconnect', (_) {
      debugPrint('🔌 [AGENT] Socket disconnected');
      if (mounted) setState(() => _socketConnected = false);
    });

    _socket!.on('delivery:new_request', (data) {
      if (!mounted || _activeDelivery != null) return;
      _showOfferOverlay(data as Map<String, dynamic>);
    });

    _socket!.on('delivery:request_expired', (_) {
      if (!mounted) return;
      _dismissOffer(expired: true);
    });

    _socket!.on('delivery:cancelled', (data) {
      if (!mounted) return;
      final deliveryId = (data is Map) ? data['deliveryId'] : null;
      if (deliveryId != null && _activeDelivery?.id == deliveryId) {
        setState(() => _activeDelivery = null);
        _showSnack('Delivery was cancelled by sender', isError: true);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WALLET  ← KEY FIX: body['data'] not body['wallet']
  // ─────────────────────────────────────────────────────────────────────────
  //
  // Controller response shape:
  //   GET /api/deliveries/driver/wallet
  //   → { success: true, data: { wallet_id, balance, available_balance, ... } }
  //
  // The old code read body['wallet'] which was always null, causing the wallet
  // to display zeros on the dashboard even when the API call succeeded.

  Future<void> _fetchWallet() async {
    if (_accessToken.isEmpty) {
      if (mounted) setState(() => _loadingWallet = false);
      return;
    }
    if (mounted) setState(() => _loadingWallet = true);

    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/driver/wallet'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;

        // ✅ FIXED: controller returns body['data'], not body['wallet']
        final walletData = body['data'] as Map<String, dynamic>?;

        if (walletData != null && mounted) {
          setState(() {
            _wallet        = _Wallet.fromJson(walletData);
            _loadingWallet = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ [AGENT] fetchWallet error: $e');
    }
    if (mounted) setState(() => _loadingWallet = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ONLINE / OFFLINE TOGGLE
  // ─────────────────────────────────────────────────────────────────────────

  // ── Authenticated POST with automatic token refresh-and-retry ──────────────
  // Handles 401 { shouldRefresh: true } (e.g. account status changed right
  // after admin approval) by refreshing the token and retrying once.
  Future<http.Response> _authedPost(String url,
      {Map<String, dynamic>? body,
      Duration timeout = const Duration(seconds: 12)}) async {
    Future<http.Response> doPost(String token) => http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body != null ? jsonEncode(body) : null,
        ).timeout(timeout);

    var res = await doPost(_accessToken);
    if (res.statusCode == 401) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['shouldRefresh'] == true) {
          final auth = AuthService();
          if (await auth.refreshAccessToken()) {
            final fresh = await auth.getAccessToken();
            if (fresh != null && fresh.isNotEmpty) {
              _accessToken = fresh;
              res = await doPost(fresh);
            }
          }
        }
      } catch (_) {}
    }
    return res;
  }

  Future<void> _toggleStatus() async {
    if (_togglingStatus) return;

    if (!_isOnline && !_wallet.canAcceptJobs) {
      _showSnack('Top up your wallet before going online', isError: true);
      return;
    }

    setState(() => _togglingStatus = true);

    try {
      if (!_isOnline) {
        // ── GPS check ──────────────────────────────────────────────────────
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _showSnack('GPS is turned off. Enable location in device settings.',
              isError: true);
          if (mounted) setState(() => _togglingStatus = false);
          return;
        }

        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          _showSnack('Location permission required to go online.',
              isError: true);
          if (mounted) setState(() => _togglingStatus = false);
          return;
        }

        Position? pos = _lastPosition;
        try {
          pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 15));
          _lastPosition = pos;
        } catch (e) {
          _showSnack('Could not get location. Make sure GPS is enabled.',
              isError: true);
          if (mounted) setState(() => _togglingStatus = false);
          return;
        }

        // ── Go online ──────────────────────────────────────────────────────
        final onlineRes = await _authedPost(
          '${AppConfig.apiBaseUrl}/driver/online',
          body: {
            'lat':     pos.latitude,
            'lng':     pos.longitude,
            'heading': pos.heading,
          },
        );

        if (onlineRes.statusCode != 200) {
          _showSnack(_parseMessage(onlineRes.body, 'Failed to go online'),
              isError: true);
          if (mounted) setState(() => _togglingStatus = false);
          return;
        }

        // ── Set delivery mode (best-effort) ────────────────────────────────
        await _authedPost(
          '${AppConfig.apiBaseUrl}/deliveries/driver/mode',
          body: {'mode': 'delivery'},
          timeout: const Duration(seconds: 8),
        ).catchError((_) => http.Response('{}', 200));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_online', true);
        if (mounted) {
          setState(() {
            _isOnline       = true;
            _togglingStatus = false;
          });
        }
        _startGpsUpdates();
        _showSnack("You're now online 🟢", isError: false);

      } else {
        // ── Go offline ─────────────────────────────────────────────────────
        final offlineRes = await _authedPost(
          '${AppConfig.apiBaseUrl}/driver/offline',
          timeout: const Duration(seconds: 10),
        );

        if (offlineRes.statusCode == 200) {
          _gpsTimer?.cancel();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_online', false);
          if (mounted) {
            setState(() {
              _isOnline       = false;
              _togglingStatus = false;
            });
          }
          _showSnack("You're now offline", isError: false);
        } else {
          _showSnack(_parseMessage(offlineRes.body, 'Failed to go offline'),
              isError: true);
          if (mounted) setState(() => _togglingStatus = false);
        }
      }
    } catch (e) {
      debugPrint('❌ [AGENT] toggleStatus error: $e');
      _showSnack('Network error. Try again.', isError: true);
      if (mounted) setState(() => _togglingStatus = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GPS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _startGpsUpdates() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;

    _sendLocation();
    _gpsTimer?.cancel();
    _gpsTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _sendLocation());
  }

  Future<void> _sendLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8));
      _lastPosition = pos;

      _socket?.emit('driver:location_update', {
        'lat':     pos.latitude,
        'lng':     pos.longitude,
        'heading': pos.heading,
        'speed':   pos.speed,
      });

      await http
          .post(
        Uri.parse('${AppConfig.apiBaseUrl}/driver/location'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({
          'lat':     pos.latitude,
          'lng':     pos.longitude,
          'heading': pos.heading,
          'speed':   pos.speed,
        }),
      )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OFFER OVERLAY
  // ─────────────────────────────────────────────────────────────────────────

  void _showOfferOverlay(Map<String, dynamic> offer) {
    setState(() {
      _pendingOffer     = offer;
      _offerVisible     = true;
      _offerSecondsLeft = (offer['expiresIn'] as num? ?? 25).toInt();
      _acceptingOffer   = false;
    });
    _offerCtrl.forward(from: 0);
    _startOfferCountdown();
  }

  void _startOfferCountdown() {
    _offerTimer?.cancel();
    _offerTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _offerSecondsLeft--);
      if (_offerSecondsLeft <= 0) {
        t.cancel();
        _dismissOffer(expired: true);
      }
    });
  }

  void _dismissOffer({bool expired = false}) {
    _offerTimer?.cancel();
    _offerCtrl.reverse().then((_) {
      if (mounted) setState(() { _offerVisible = false; _pendingOffer = null; });
    });
    if (expired && mounted) _showSnack('Offer expired', isError: false);
  }

  Future<void> _acceptOffer() async {
    final offer = _pendingOffer;
    if (offer == null || _acceptingOffer) return;

    _offerTimer?.cancel();
    setState(() => _acceptingOffer = true);

    try {
      final deliveryId = offer['deliveryId'];
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/$deliveryId/accept'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type':  'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && body['success'] == true) {
        _dismissOffer();
        _fetchWallet();

        final deliveryJson   = body['delivery'] as Map<String, dynamic>;
        final activeDelivery = ActiveDelivery.fromJson(deliveryJson);

        if (mounted) {
          final route = activeDelivery.trackingMode == 'live_map'
              ? MaterialPageRoute(
              builder: (_) => DeliveryActiveExpressScreen(
                  delivery: activeDelivery, socket: _socket))
              : MaterialPageRoute(
              builder: (_) => DeliveryActiveScreen(
                  delivery: activeDelivery, socket: _socket));

          await Navigator.of(context).push(route);

          if (mounted) {
            setState(() {
              _activeDelivery        = null;
              _loadingActiveDelivery = true;
            });
            await Future.wait([_fetchWallet(), _checkActiveDelivery()]);
          }
        }
        return;
      }

      _dismissOffer();
      _showSnack(_parseMessage(res.body, 'Could not accept delivery'),
          isError: true);
    } catch (_) {
      _dismissOffer();
      _showSnack('Network error. Offer may have expired.', isError: true);
    }
  }

  void _declineOffer() => _dismissOffer();

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _parseMessage(String body, String fallback) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      return j['message'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Quicksand')),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }

  String _fmt(double xaf) =>
      '${xaf.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} XAF';

  Future<void> _refreshAll() async =>
      Future.wait([_fetchWallet(), _checkActiveDelivery()]);

  Future<void> _logout() async {
    _socket?.disconnect();
    _gpsTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fade,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),

                      if (!_loadingActiveDelivery && _activeDelivery != null) ...[
                        SlideTransition(
                          position: _bannerSlide,
                          child: _buildActiveDeliveryBanner(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      _buildStatusToggle(),
                      const SizedBox(height: 20),
                      _buildWalletCard(),
                      const SizedBox(height: 16),
                      _buildStatsRow(),
                      const SizedBox(height: 20),
                      _buildQuickActions(),
                      const SizedBox(height: 20),
                      _buildWalletWarning(),
                      const SizedBox(height: 20),
                      _buildInfoCard(),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          if (_offerVisible && _pendingOffer != null) _buildOfferOverlay(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 130,
      backgroundColor: AppColors.primaryDark,
      automaticallyImplyLeading: false,
      actions: [
        // ── Mode switch pill ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: GestureDetector(
            onTap: () => showModeSwitchSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withOpacity(0.14), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz_rounded,
                      color: AppColors.primaryGold, size: 14),
                  SizedBox(width: 4),
                  Text(tr('agent.switch'),
                      style: TextStyle(
                          fontFamily: 'LeagueSpartan',
                          fontSize:   11,
                          fontWeight: FontWeight.w700,
                          color:      AppColors.primaryGold)),
                ],
              ),
            ),
          ),
        ),

        // ── Socket status ─────────────────────────────────────────────────
        // ── Notification bell ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: NotificationBadge(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationScreen(),
                ),
              ).then((_) => NotificationBadge.refresh());
            },
            child: IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 22,
              ),
              onPressed: null,
              tooltip: 'Notifications',
            ),
          ),
        ),

        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
          onPressed: _refreshAll,
          tooltip: 'Refresh',
        ),

        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
          onPressed: _refreshAll,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
          onPressed: _logout,
          tooltip: 'Log out',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        title: Row(
          children: [
            Container(
              width:  38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isOnline
                      ? AppColors.success
                      : Colors.white.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: _avatarUrl.isNotEmpty
                    ? Image.network(_avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _avatarInitial())
                    : _avatarInitial(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_firstName $_lastName'.trim().isEmpty
                        ? 'Delivery Agent'
                        : '$_firstName $_lastName',
                    style: const TextStyle(
                        fontFamily: 'LeagueSpartan',
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Transform.scale(
                        scale: _isOnline ? _pulse.value : 1.0,
                        child: Container(
                          width:  7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isOnline
                                ? AppColors.success
                                : AppColors.textLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isOnline ? 'Online — Delivery Mode' : 'Offline',
                      style: TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize:   10,
                          color: _isOnline
                              ? AppColors.success
                              : Colors.white.withOpacity(0.45)),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
              colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
            ),
          ),
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 36, right: 12),
              child: Icon(Icons.delivery_dining_rounded,
                  size:  80,
                  color: AppColors.primaryGold.withOpacity(0.06)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarInitial() {
    final initial = _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'A';
    return Center(
      child: Text(initial,
          style: const TextStyle(
              fontFamily: 'LeagueSpartan',
              fontSize:   15,
              fontWeight: FontWeight.w800,
              color:      AppColors.primaryGold)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIVE DELIVERY BANNER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildActiveDeliveryBanner() {
    final d = _activeDelivery!;
    return GestureDetector(
      onTap: _resumeActiveDelivery,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primaryDark.withBlue(50)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: d.statusColor.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
                color:      d.statusColor.withOpacity(0.2),
                blurRadius: 20,
                offset:     const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: _pulse.value,
                child: Container(
                  width:  48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:  d.statusColor.withOpacity(0.15),
                    shape:  BoxShape.circle,
                    border: Border.all(color: d.statusColor, width: 1.5),
                  ),
                  child: Icon(Icons.delivery_dining_rounded,
                      color: d.statusColor, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: d.statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        d.deliveryType == 'express' ? '⚡ EXPRESS' : '📦 REGULAR',
                        style: TextStyle(
                            fontFamily: 'LeagueSpartan',
                            fontSize:   9,
                            fontWeight: FontWeight.w700,
                            color:      d.statusColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(d.deliveryCode,
                          style: const TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize:   11,
                              color:      Colors.white60),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Text(d.statusLabel,
                      style: TextStyle(
                          fontFamily: 'LeagueSpartan',
                          fontSize:   13,
                          fontWeight: FontWeight.w700,
                          color:      d.statusColor)),
                  const SizedBox(height: 3),
                  Text(
                    '${d.pickupAddress}  →  ${d.dropoffAddress}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize:   11,
                        color:      Colors.white60),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _resumingActiveDelivery
                ? const SizedBox(
                width:  28, height: 28,
                child:  CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primaryGold))
                : Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:        AppColors.primaryGold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(tr('agent.resume'),
                  style: TextStyle(
                      fontFamily: 'LeagueSpartan',
                      fontSize:   12,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.primaryDark)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATUS TOGGLE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatusToggle() {
    return GestureDetector(
      onTap: _togglingStatus ? null : _toggleStatus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isOnline ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isOnline
                ? AppColors.success.withOpacity(0.4)
                : AppColors.borderLight,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: _isOnline
                    ? AppColors.success.withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width:  56,
              height: 56,
              decoration: BoxDecoration(
                color: _isOnline ? AppColors.success : AppColors.borderLight,
                shape: BoxShape.circle,
              ),
              child: _togglingStatus
                  ? Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
                  : Icon(
                  _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: Colors.white,
                  size:  28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOnline ? "You're Online" : "You're Offline",
                    style: TextStyle(
                        fontFamily: 'LeagueSpartan',
                        fontSize:   17,
                        fontWeight: FontWeight.w800,
                        color: _isOnline
                            ? AppColors.success
                            : AppColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _isOnline
                        ? 'Delivery requests will appear here'
                        : 'Tap to go online and start earning',
                    style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize:   12,
                        color: _isOnline
                            ? AppColors.success.withOpacity(0.7)
                            : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width:  52,
              height: 30,
              decoration: BoxDecoration(
                color: _isOnline ? AppColors.success : AppColors.borderMedium,
                borderRadius: BorderRadius.circular(15),
              ),
              child: AnimatedAlign(
                duration:  const Duration(milliseconds: 300),
                alignment: _isOnline
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width:  26,
                  height: 26,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color:  Colors.white,
                    shape:  BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color:      Colors.black.withOpacity(0.15),
                          blurRadius: 4)
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WALLET CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWalletCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => DeliveryWalletScreen(socket: _socket))),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.18),
                blurRadius: 18,
                offset:     const Offset(0, 6)),
          ],
        ),
        child: _loadingWallet
            ? Center(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryGold)))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.primaryGold, size: 16),
              const SizedBox(width: 8),
              Text(tr('agent.wallet'),
                  style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize:   12,
                      fontWeight: FontWeight.w500,
                      color:      AppColors.primaryGold)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                        const DeliveryWalletScreen(initialTab: 1))),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primaryGold.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.add_rounded,
                        color: AppColors.primaryGold, size: 12),
                    SizedBox(width: 3),
                    Text(tr('agent.topUp'),
                        style: TextStyle(
                            fontFamily: 'LeagueSpartan',
                            fontSize:   11,
                            fontWeight: FontWeight.w700,
                            color:      AppColors.primaryGold)),
                  ]),
                ),
              ),
            ]),

            const SizedBox(height: 16),

            Text(
              _fmt(_wallet.availableBalance),
              style: const TextStyle(
                  fontFamily:    'LeagueSpartan',
                  fontSize:      32,
                  fontWeight:    FontWeight.w800,
                  color:         AppColors.primaryGold,
                  letterSpacing: -1),
            ),
            Text(tr('agent.availableBalance'),
                style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize:   11,
                    color: Colors.white.withOpacity(0.4))),

            const SizedBox(height: 18),
            Container(height: 1, color: Colors.white.withOpacity(0.07)),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(child: _walletStat(
                  'Reserved', _fmt(_wallet.reservedBalance), AppColors.warning)),
              Container(width: 1, height: 36,
                  color: Colors.white.withOpacity(0.08)),
              Expanded(child: _walletStat(
                  'Total Earned', _fmt(_wallet.totalEarned), AppColors.success)),
              Container(width: 1, height: 36,
                  color: Colors.white.withOpacity(0.08)),
              Expanded(child: _walletStat(
                  'Commission Due', _fmt(_wallet.outstandingCommission),
                  AppColors.textSecondary)),
            ]),

            if (_wallet.status != 'active') ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.lock_rounded,
                      color: AppColors.error, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _wallet.frozenReason ??
                          'Wallet ${_wallet.status}. Contact support.',
                      style: const TextStyle(
                          fontFamily: 'Quicksand',
                          fontSize:   11,
                          color:      AppColors.error),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _walletStat(String label, String value, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontFamily: 'LeagueSpartan',
              fontSize:   12,
              fontWeight: FontWeight.w700,
              color:      color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize:   9,
              color: Colors.white.withOpacity(0.38))),
    ]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATS ROW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final activeCount = _activeDelivery != null ? '1' : '0';
    return Row(children: [
      Expanded(child: _statCard(
          '💰', 'Total\nEarned', _fmt(_wallet.totalEarned), AppColors.success)),
      const SizedBox(width: 12),
      Expanded(child: _statCard(
          '🔒', 'Commission\nReserved', _fmt(_wallet.reservedBalance),
          AppColors.warning)),
      const SizedBox(width: 12),
      Expanded(child: _statCard(
          '📦', 'Active\nDeliveries', activeCount, AppColors.info)),
    ]);
  }

  Widget _statCard(String emoji, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset:     const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        _loadingWallet
            ? SizedBox(
            width:  16, height: 16,
            child:  CircularProgressIndicator(strokeWidth: 2, color: color))
            : Text(value,
            style: TextStyle(
                fontFamily: 'LeagueSpartan',
                fontSize:   12,
                fontWeight: FontWeight.w800,
                color:      color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize:   9,
                color:      AppColors.textSecondary,
                height:     1.3)),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUICK ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('agent.quickActions'),
            style: TextStyle(
                fontFamily: 'LeagueSpartan',
                fontSize:   14,
                fontWeight: FontWeight.w700,
                color:      AppColors.textPrimary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _actionButton(
              icon:  Icons.account_balance_wallet_outlined,
              label: tr('agent.myWallet'),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const DeliveryWalletScreen(initialTab: 1))))),
          const SizedBox(width: 10),
          Expanded(child: _actionButton(
              icon:  Icons.history_rounded,
              label: tr('agent.history'),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const DeliveryHistoryScreen())))),
          const SizedBox(width: 10),
          Expanded(child: _actionButton(
              icon:  Icons.person_outline_rounded,
              label: tr('profile.title'),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const AgentProfileScreen())))),
          const SizedBox(width: 10),
          Expanded(child: _actionButton(
              icon:  Icons.headset_mic_outlined,
              label: tr('agent.support'),
              onTap: () {
                // TODO: launch support screen
              })),
        ]),
      ],
    );
  }

  Widget _actionButton({
    required IconData     icon,
    required String       label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
                color:      Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset:     const Offset(0, 3)),
          ],
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.primaryDark, size: 24),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize:   10,
                  fontWeight: FontWeight.w600,
                  color:      AppColors.textSecondary)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WALLET WARNING
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWalletWarning() {
    if (_wallet.canAcceptJobs || _loadingWallet) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.warningLight,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: EdgeInsets.only(top: 2),
              child:   Text('⚠️', style: TextStyle(fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('agent.balanceTooLow'),
                    style: TextStyle(
                        fontFamily: 'LeagueSpartan',
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.warning)),
                const SizedBox(height: 4),
                Text(
                    'You need sufficient balance to cover the delivery commission '
                        'before accepting jobs. Top up to go online.',
                    style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize:   11,
                        color:      AppColors.warning,
                        height:     1.5)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) =>
                          const DeliveryWalletScreen(initialTab: 1))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:        AppColors.warning,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(tr('agent.topUpWallet'),
                        style: TextStyle(
                            fontFamily: 'LeagueSpartan',
                            fontSize:   12,
                            fontWeight: FontWeight.w700,
                            color:      Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INFO CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.infoLight,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('agent.howEarningsWork'),
                    style: TextStyle(
                        fontFamily: 'LeagueSpartan',
                        fontSize:   12,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.info)),
                SizedBox(height: 5),
                Text(
                    '1. A commission is reserved from your wallet when you accept a delivery.\n'
                        '2. After successful delivery, your payout is credited to your wallet.\n'
                        '3. Request a cashout anytime from the Wallet screen.',
                    style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize:   11,
                        color:      AppColors.info,
                        height:     1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OFFER OVERLAY
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOfferOverlay() {
    final offer      = _pendingOffer!;
    final payout     = (offer['driverPayout']      as num? ?? 0).toDouble();
    final commission = (offer['commissionAmount']  as num? ?? 0).toDouble();
    final distance   = (offer['distanceKm']         as num? ?? 0).toDouble();
    final distPickup = (offer['distanceToPickupKm'] as num? ?? 0).toDouble();
    final isExpress  = (offer['deliveryType'] as String?) == 'express';
    final isFragile  = offer['isFragile'] as bool? ?? false;
    final emoji      = offer['categoryEmoji'] as String? ?? '📦';
    final catLabel   = offer['categoryLabel'] as String? ?? 'Package';
    final size       = offer['packageSize']   as String? ?? '';
    final pickup     = (offer['pickup']  as Map?)?['address'] as String? ?? '—';
    final dropoff    = (offer['dropoff'] as Map?)?['address'] as String? ?? '—';
    final payment    = offer['paymentMethod'] as String? ?? 'cash';

    final countdownColor = _offerSecondsLeft > 10
        ? AppColors.success
        : _offerSecondsLeft > 5
        ? AppColors.warning
        : AppColors.error;

    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: ScaleTransition(
          scale: _offerScale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color:      Colors.black.withOpacity(0.3),
                    blurRadius: 40,
                    offset:     const Offset(0, 16)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    color: isExpress ? AppColors.primaryDark : AppColors.primaryGold,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                  ),
                  child: Row(children: [
                    Text(isExpress ? '⚡' : '📦',
                        style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isExpress
                                ? 'Express Delivery'
                                : 'New Delivery Request',
                            style: TextStyle(
                                fontFamily: 'LeagueSpartan',
                                fontSize:   16,
                                fontWeight: FontWeight.w800,
                                color: isExpress
                                    ? Colors.white
                                    : AppColors.primaryDark),
                          ),
                          Text(
                            offer['deliveryCode'] as String? ?? '',
                            style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize:   11,
                                color: isExpress
                                    ? Colors.white.withOpacity(0.5)
                                    : AppColors.primaryDark.withOpacity(0.55)),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width:  50,
                          height: 50,
                          child:  CircularProgressIndicator(
                            value:           _offerSecondsLeft / 25,
                            strokeWidth:     3,
                            backgroundColor: countdownColor.withOpacity(0.2),
                            valueColor:
                            AlwaysStoppedAnimation<Color>(countdownColor),
                          ),
                        ),
                        Text('$_offerSecondsLeft',
                            style: TextStyle(
                                fontFamily: 'LeagueSpartan',
                                fontSize:   16,
                                fontWeight: FontWeight.w800,
                                color:      countdownColor)),
                      ],
                    ),
                  ]),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_fmt(payout),
                                style: const TextStyle(
                                    fontFamily:    'LeagueSpartan',
                                    fontSize:      28,
                                    fontWeight:    FontWeight.w800,
                                    color:         AppColors.success,
                                    letterSpacing: -0.5)),
                            Text(tr('agent.yourPayout'),
                                style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize:   11,
                                    color:      AppColors.textSecondary)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('- ${_fmt(commission)}',
                                style: const TextStyle(
                                    fontFamily: 'LeagueSpartan',
                                    fontSize:   15,
                                    fontWeight: FontWeight.w700,
                                    color:      AppColors.warning)),
                            Text(tr('agent.commission'),
                                style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize:   11,
                                    color:      AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Container(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 12),

                    Row(children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$catLabel${size.isNotEmpty ? ' · ${size[0].toUpperCase()}${size.substring(1)}' : ''}'
                              '${isFragile ? ' · 🏺 Fragile' : ''}',
                          style: const TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize:   13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('${distance.toStringAsFixed(1)} km',
                          style: TextStyle(
                              fontFamily: 'LeagueSpartan',
                              fontSize:   13,
                              fontWeight: FontWeight.w700,
                              color:      AppColors.textSecondary)),
                    ]),

                    const SizedBox(height: 12),
                    _offerRouteRow(pickup, dropoff),
                    const SizedBox(height: 10),

                    Row(children: [
                      _chip(Icons.directions_bike_rounded,
                          '${distPickup.toStringAsFixed(1)} km to pickup',
                          AppColors.info),
                      const SizedBox(width: 8),
                      _chip(
                        payment == 'cash'
                            ? Icons.payments_outlined
                            : Icons.phone_android_rounded,
                        payment == 'cash' ? 'Cash' : 'Mobile Money',
                        AppColors.success,
                      ),
                    ]),

                    const SizedBox(height: 18),
                  ]),
                ),

                // Accept / Decline buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Row(children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: _acceptingOffer ? null : _declineOffer,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.borderMedium),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(tr('agent.decline'),
                            style: TextStyle(
                                fontFamily: 'LeagueSpartan',
                                fontSize:   14,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: _acceptingOffer ? null : _acceptOffer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:         AppColors.success,
                          foregroundColor:         Colors.white,
                          disabledBackgroundColor: AppColors.success.withOpacity(0.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _acceptingOffer
                            ? const SizedBox(
                            width:  20, height: 20,
                            child:  CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(tr('agent.accept'),
                                style: TextStyle(
                                    fontFamily: 'LeagueSpartan',
                                    fontSize:   14,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _offerRouteRow(String pickup, String dropoff) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
              width:  8, height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.primaryDark, shape: BoxShape.circle)),
          Container(
              width:  1.5, height: 22,
              color:  AppColors.borderMedium,
              margin: const EdgeInsets.symmetric(vertical: 3)),
          Container(
              width:  8, height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.success, shape: BoxShape.circle)),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize:   12,
                      color:      AppColors.textPrimary)),
              const SizedBox(height: 16),
              Text(dropoff,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize:   12,
                      color:      AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize:   11,
                color:      color,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
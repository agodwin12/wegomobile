// lib/presentation/screens/trips/driver_trips_screen.dart
//
// Driver trips screen (Completed + Canceled + All) — responsive + overflow-safe
// ✅ Fixes Row overflows on small devices (Wrap/Flexible/FittedBox)
// ✅ Prevents "black screen" when pressing Android back while this screen is used as a TAB
//    (WillPopScope stops Navigator.pop from popping the whole wrapper route)
//
// Requires:
// - AppColors, AppTypography
// - flutter_dotenv
// - http
// - shared_preferences
//
// Backend endpoint used:
//   GET {API_BASE_URL}/driver/trips?status=COMPLETED,CANCELED&page=1&limit=20
//   status can be: all | COMPLETED | CANCELED
//
// Note: This screen fetches trips for the authenticated driver only.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wego_v1/utils/app_colors.dart';
import 'package:wego_v1/utils/app_typography.dart';

enum TripFilter { all, completed, canceled }

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen>
    with TickerProviderStateMixin {
  // ─── Networking ───────────────────────────────────────────────────
  String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:4000/api';

  String? _accessToken;

  // ─── State ────────────────────────────────────────────────────────
  bool _isDisposed = false;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  String? _error;

  TripFilter _filter = TripFilter.all;
  int _page = 1;
  final int _limit = 20;
  bool _hasMore = true;

  final List<Map<String, dynamic>> _trips = [];

  // ─── Scroll ───────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();

  // ─── Animations ───────────────────────────────────────────────────
  late final AnimationController _fadeInController;
  late final Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();

    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeInAnimation = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    );

    _scrollController.addListener(_onScroll);
    _init();
  }

  Future<void> _init() async {
    await _loadAccessToken();
    if (_isDisposed) return;

    await _fetchTrips(reset: true);
    if (_isDisposed) return;

    if (mounted) _fadeInController.forward();
  }

  Future<void> _loadAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
    } catch (_) {
      _accessToken = null;
    }
  }

  void _onScroll() {
    if (_isDisposed) return;
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore || _isLoading || !_hasMore) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _fetchTrips(loadMore: true);
    }
  }

  String _statusQueryForFilter(TripFilter f) {
    switch (f) {
      case TripFilter.completed:
        return 'COMPLETED';
      case TripFilter.canceled:
        return 'CANCELED';
      case TripFilter.all:
        return 'all';
    }
  }

  Future<void> _fetchTrips({bool reset = false, bool loadMore = false}) async {
    if (_isDisposed) return;

    if (_accessToken == null || _accessToken!.isEmpty) {
      if (mounted) setState(() => _error = 'Session expired. Please login again.');
      return;
    }

    if (reset) {
      _page = 1;
      _hasMore = true;
      _error = null;
      _trips.clear();
    }

    if (!_hasMore && loadMore) return;

    if (loadMore) {
      if (mounted) setState(() => _isLoadingMore = true);
    } else if (reset) {
      if (mounted) setState(() => _isLoading = true);
    } else {
      if (mounted) setState(() => _isRefreshing = true);
    }

    try {
      final status = _statusQueryForFilter(_filter);

      final uri = Uri.parse('$apiBaseUrl/driver/trips').replace(
        queryParameters: <String, String>{
          'status': status,
          'page': _page.toString(),
          'limit': _limit.toString(),
        },
      );

      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (_isDisposed || !mounted) return;

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final data = (body['data'] ?? {}) as Map<String, dynamic>;

        final tripsRaw = (data['trips'] ?? []) as List<dynamic>;
        final pagination = (data['pagination'] ?? {}) as Map<String, dynamic>;

        final totalPages = (pagination['totalPages'] is num)
            ? (pagination['totalPages'] as num).toInt()
            : 1;

        final newTrips = tripsRaw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        setState(() {
          _trips.addAll(newTrips);
          _hasMore = _page < totalPages && newTrips.isNotEmpty;
          _page = _page + 1;
          _error = null;
        });
      } else {
        setState(() => _error = 'Failed to load trips (${resp.statusCode})');
      }
    } on TimeoutException {
      if (mounted) setState(() => _error = 'Request timeout. Try again.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Error loading trips.');
    } finally {
      if (!mounted || _isDisposed) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
      });
    }
  }

  // ────────────────────────────────────────────────────────────────
  // UI helpers
  // ────────────────────────────────────────────────────────────────

  String _formatTripId(Map<String, dynamic> trip) {
    final raw =
    (trip['id'] ?? trip['uuid'] ?? trip['tripId'] ?? trip['trip_id'])
        ?.toString();
    if (raw == null || raw.isEmpty) return '#UNKNOWN';
    final cut = raw.length >= 8 ? raw.substring(0, 8) : raw;
    return '#${cut.toUpperCase()}';
  }

  String _money(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    return n.toInt().toString();
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d • $hh:$mm';
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELED':
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  Color _statusBg(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return AppColors.successLight;
      case 'CANCELED':
      case 'CANCELLED':
        return AppColors.error.withOpacity(0.08);
      default:
        return AppColors.info.withOpacity(0.10);
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 'COMPLETED';
      case 'CANCELED':
      case 'CANCELLED':
        return 'CANCELED';
      default:
        return status.toUpperCase();
    }
  }

  void _setFilter(TripFilter f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _fetchTrips(reset: true);
  }

  void _showBackHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Use the bottom menu to go back to Home.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ✅ Prevent Android back from popping the whole wrapper route (black screen when used as a TAB)
    return WillPopScope(
      onWillPop: () async {
        _showBackHint();
        return false; // don't pop
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: FadeTransition(
          opacity: _fadeInAnimation,
          child: RefreshIndicator(
            color: AppColors.primaryGold,
            backgroundColor: AppColors.primaryDark,
            onRefresh: () async => _fetchTrips(reset: true),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildDarkHeader()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  sliver: SliverToBoxAdapter(child: _buildFilterRow()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: _buildTripsBody(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDarkHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            children: [
              Row(
                children: [
                  _headerIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: _showBackHint, // ✅ don’t pop in tab mode
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your trips',
                          style: AppTypography.headlineMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Completed & canceled history',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _headerIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: () => _fetchTrips(reset: true),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSummaryPillsResponsive(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white54, size: 20),
      ),
    );
  }

  /// ✅ Responsive pills: uses Wrap to prevent overflow on small widths
  Widget _buildSummaryPillsResponsive() {
    final count = _trips.length;
    final completed = _trips
        .where((t) => (t['status'] ?? '').toString().toUpperCase() == 'COMPLETED')
        .length;
    final canceled = _trips
        .where((t) => (t['status'] ?? '').toString().toUpperCase() == 'CANCELED')
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        if (isNarrow) {
          // 2 rows on narrow screens
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: (constraints.maxWidth - 10) / 2,
                child: _pill(
                  label: 'Loaded',
                  value: '$count',
                  accent: AppColors.primaryGold,
                  bg: Colors.white.withOpacity(0.06),
                ),
              ),
              SizedBox(
                width: (constraints.maxWidth - 10) / 2,
                child: _pill(
                  label: 'Completed',
                  value: '$completed',
                  accent: AppColors.success,
                  bg: Colors.white.withOpacity(0.06),
                ),
              ),
              SizedBox(
                width: constraints.maxWidth,
                child: _pill(
                  label: 'Canceled',
                  value: '$canceled',
                  accent: AppColors.error,
                  bg: Colors.white.withOpacity(0.06),
                ),
              ),
            ],
          );
        }

        // 1 row on normal screens
        return Row(
          children: [
            Expanded(
              child: _pill(
                label: 'Loaded',
                value: '$count',
                accent: AppColors.primaryGold,
                bg: Colors.white.withOpacity(0.06),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _pill(
                label: 'Completed',
                value: '$completed',
                accent: AppColors.success,
                bg: Colors.white.withOpacity(0.06),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _pill(
                label: 'Canceled',
                value: '$canceled',
                accent: AppColors.error,
                bg: Colors.white.withOpacity(0.06),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pill({
    required String label,
    required String value,
    required Color accent,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white38,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          _filterChip(
            label: 'All',
            active: _filter == TripFilter.all,
            onTap: () => _setFilter(TripFilter.all),
          ),
          _filterChip(
            label: 'Completed',
            active: _filter == TripFilter.completed,
            onTap: () => _setFilter(TripFilter.completed),
          ),
          _filterChip(
            label: 'Canceled',
            active: _filter == TripFilter.canceled,
            onTap: () => _setFilter(TripFilter.canceled),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryDark : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: AppTypography.titleSmall.copyWith(
                  color: active ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  SliverList _buildTripsBody() {
    if (_isLoading && _trips.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate(
          [
            const SizedBox(height: 4),
            _skeletonCard(),
            const SizedBox(height: 12),
            _skeletonCard(),
            const SizedBox(height: 12),
            _skeletonCard(),
          ],
        ),
      );
    }

    if (_error != null && _trips.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate(
          [
            const SizedBox(height: 10),
            _errorCard(_error!),
          ],
        ),
      );
    }

    if (_trips.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate(
          [
            const SizedBox(height: 10),
            _emptyCard(),
          ],
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index == _trips.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _hasMore ? _loadingMore() : _endOfList(),
            );
          }
          final trip = _trips[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _tripCard(trip),
          );
        },
        childCount: _trips.length + 1,
      ),
    );
  }

  // ✅ OVERFLOW-SAFE trip card
  Widget _tripCard(Map<String, dynamic> trip) {
    final status = (trip['status'] ?? '').toString();
    final statusColor = _statusColor(status);
    final statusBg = _statusBg(status);

    final idDisplay = _formatTripId(trip);

    final passenger = trip['passenger'] as Map<String, dynamic>?;
    final passengerName = (passenger != null)
        ? ((passenger['name'] ??
        '${passenger['firstName'] ?? passenger['first_name'] ?? ''} ${passenger['lastName'] ?? passenger['last_name'] ?? ''}')
        .toString())
        .trim()
        : '';

    final fare = _money(trip['fareFinal'] ?? trip['fareEstimate'] ?? trip['fare']);
    final createdAt = _parseDate(trip['createdAt']);
    final completedAt = _parseDate(trip['completedAt']);
    final canceledAt = _parseDate(trip['canceledAt']);

    final when = status.toUpperCase() == 'COMPLETED'
        ? (completedAt ?? createdAt)
        : (canceledAt ?? createdAt);

    final pickupAddr = (trip['pickup'] is Map)
        ? (trip['pickup']['address']?.toString() ?? '')
        : (trip['pickupAddress']?.toString() ??
        trip['pickup_address']?.toString() ??
        '');

    final dropoffAddr = (trip['dropoff'] is Map)
        ? (trip['dropoff']['address']?.toString() ?? '')
        : (trip['dropoffAddress']?.toString() ??
        trip['dropoff_address']?.toString() ??
        '');

    return GestureDetector(
      onTap: () => _showTripBottomSheet(trip),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left status icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withOpacity(0.25)),
              ),
              child: Icon(
                status.toUpperCase() == 'COMPLETED'
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ top row uses Wrap instead of Row to avoid overflow
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        idDisplay,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.25)),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: AppTypography.labelSmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      // price aligned to the end by taking full width line when needed
                      SizedBox(
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$fare XAF',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ✅ passenger + time: Wrap to avoid overflow
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_rounded,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              passengerName.isNotEmpty ? passengerName : 'Passenger',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            _formatDateTime(when),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _routeLine(
                    pickup: pickupAddr.isNotEmpty ? pickupAddr : 'Pickup location',
                    dropoff: dropoffAddr.isNotEmpty ? dropoffAddr : 'Dropoff location',
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right arrow
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primaryGold,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeLine({required String pickup, required String dropoff}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primaryGold,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 20,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickup,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                dropoff,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loadingMore() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.3),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading more…',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _endOfList() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          'No more trips',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.error_rounded,
                color: AppColors.error, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _fetchTrips(reset: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Retry',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primaryGold,
              size: 26,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No trips found',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When you complete or cancel a trip, it will appear here.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _fetchTrips(reset: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Refresh',
                style: AppTypography.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonCard() {
    Widget bar({double w = double.infinity, double h = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.borderLight.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.borderLight.withOpacity(0.7),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: bar(w: 120, h: 12)),
                    const SizedBox(width: 10),
                    bar(w: 70, h: 12),
                  ],
                ),
                const SizedBox(height: 10),
                bar(w: 170, h: 10),
                const SizedBox(height: 14),
                bar(w: double.infinity, h: 10),
                const SizedBox(height: 8),
                bar(w: 220, h: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTripBottomSheet(Map<String, dynamic> trip) {
    final status = (trip['status'] ?? '').toString();
    final id = _formatTripId(trip);

    final pickupAddr = (trip['pickup'] is Map)
        ? (trip['pickup']['address']?.toString() ?? '')
        : (trip['pickupAddress']?.toString() ??
        trip['pickup_address']?.toString() ??
        '');

    final dropoffAddr = (trip['dropoff'] is Map)
        ? (trip['dropoff']['address']?.toString() ?? '')
        : (trip['dropoffAddress']?.toString() ??
        trip['dropoff_address']?.toString() ??
        '');

    final fare = _money(trip['fareFinal'] ?? trip['fareEstimate'] ?? trip['fare']);
    final createdAt = _parseDate(trip['createdAt']);
    final completedAt = _parseDate(trip['completedAt']);
    final canceledAt = _parseDate(trip['canceledAt']);

    final when = status.toUpperCase() == 'COMPLETED'
        ? (completedAt ?? createdAt)
        : (canceledAt ?? createdAt);

    final reason = (trip['cancelReason'] ?? trip['cancel_reason'])?.toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ✅ Wrap avoids overflow in header row
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        id,
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusBg(status),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _statusColor(status).withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: AppTypography.labelSmall.copyWith(
                            color: _statusColor(status),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$fare XAF',
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _detailRow(
                    icon: Icons.schedule_rounded,
                    label: 'Time',
                    value: _formatDateTime(when),
                  ),
                  const SizedBox(height: 10),
                  _detailRow(
                    icon: Icons.my_location_rounded,
                    label: 'Pickup',
                    value: pickupAddr.isNotEmpty ? pickupAddr : '—',
                  ),
                  const SizedBox(height: 10),
                  _detailRow(
                    icon: Icons.place_rounded,
                    label: 'Dropoff',
                    value: dropoffAddr.isNotEmpty ? dropoffAddr : '—',
                  ),

                  if (status.toUpperCase() == 'CANCELED' &&
                      reason != null &&
                      reason.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _detailRow(
                      icon: Icons.report_gmailerrorred_rounded,
                      label: 'Reason',
                      value: reason,
                    ),
                  ],

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Close',
                            style: AppTypography.titleSmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryGold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryGold, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }
}
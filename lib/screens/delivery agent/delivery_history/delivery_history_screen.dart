// lib/presentation/screens/delivery_agent/delivery_history_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _EarningsPeriod {
  final int    deliveries;
  final double totalEarnings;
  final double cashCollected;
  final double cashOwedToWego;
  final double walletCredited;
  final int    expressCount;
  final int    regularCount;

  const _EarningsPeriod({
    required this.deliveries,
    required this.totalEarnings,
    required this.cashCollected,
    required this.cashOwedToWego,
    required this.walletCredited,
    required this.expressCount,
    required this.regularCount,
  });

  factory _EarningsPeriod.fromJson(Map<String, dynamic> j) => _EarningsPeriod(
    deliveries:     (j['deliveries']    as num? ?? 0).toInt(),
    totalEarnings:  (j['totalEarnings'] as num? ?? 0).toDouble(),
    cashCollected:  (j['cashCollected'] as num? ?? 0).toDouble(),
    cashOwedToWego: (j['cashOwedToWego']as num? ?? 0).toDouble(),
    walletCredited: (j['walletCredited']as num? ?? 0).toDouble(),
    expressCount:   (j['expressCount']  as num? ?? 0).toInt(),
    regularCount:   (j['regularCount']  as num? ?? 0).toInt(),
  );

  factory _EarningsPeriod.empty() => const _EarningsPeriod(
    deliveries: 0, totalEarnings: 0, cashCollected: 0,
    cashOwedToWego: 0, walletCredited: 0, expressCount: 0, regularCount: 0,
  );
}

class _Earnings {
  final _EarningsPeriod today;
  final _EarningsPeriod week;
  final _EarningsPeriod month;
  final _EarningsPeriod allTime;

  const _Earnings({
    required this.today, required this.week,
    required this.month, required this.allTime,
  });

  factory _Earnings.fromJson(Map<String, dynamic> j) => _Earnings(
    today:   _EarningsPeriod.fromJson((j['today']   as Map<String, dynamic>?) ?? {}),
    week:    _EarningsPeriod.fromJson((j['week']    as Map<String, dynamic>?) ?? {}),
    month:   _EarningsPeriod.fromJson((j['month']   as Map<String, dynamic>?) ?? {}),
    allTime: _EarningsPeriod.fromJson((j['allTime'] as Map<String, dynamic>?) ?? {}),
  );

  factory _Earnings.empty() => _Earnings(
    today:   _EarningsPeriod.empty(), week:    _EarningsPeriod.empty(),
    month:   _EarningsPeriod.empty(), allTime: _EarningsPeriod.empty(),
  );

  _EarningsPeriod byIndex(int i) => [today, week, month, allTime][i];
}

class _Delivery {
  final int      id;
  final String   deliveryCode;
  final String   deliveryType;
  final String   status;
  final String   packageSize;
  final String   packageCategory;
  final String   categoryLabel;
  final String   categoryEmoji;
  final String   pickupAddress;
  final String   dropoffAddress;
  final double   distanceKm;
  final double   totalPrice;
  final double   driverPayout;
  final double   commissionAmount;
  final String   paymentMethod;
  final String   paymentStatus;
  final bool     isSurging;
  final String?  senderName;
  final String   recipientName;
  final int?     durationMinutes;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime  displayDate;   // acceptedAt or createdAt — whichever is available
  final String?  cancelledBy;
  final String?  cancellationReason;

  const _Delivery({
    required this.id,
    required this.deliveryCode,
    required this.deliveryType,
    required this.status,
    required this.packageSize,
    required this.packageCategory,
    required this.categoryLabel,
    required this.categoryEmoji,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.distanceKm,
    required this.totalPrice,
    required this.driverPayout,
    required this.commissionAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.isSurging,
    required this.recipientName,
    required this.displayDate,
    this.senderName,
    this.durationMinutes,
    this.deliveredAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
  });

  factory _Delivery.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num? ?? 0).toDouble();

    // Safe date parser — returns null instead of throwing
    DateTime? dt(String k) {
      final v = j[k];
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    // Use the first available date field as the display date
    // API sends: acceptedAt, arrivedPickupAt, pickedUpAt, deliveredAt, createdAt
    final displayDate =
        dt('createdAt')    ??
            dt('acceptedAt')   ??
            dt('deliveredAt')  ??
            dt('cancelledAt')  ??
            DateTime.now();

    final pickup  = (j['pickup']  as Map<String, dynamic>?) ?? {};
    final dropoff = (j['dropoff'] as Map<String, dynamic>?) ?? {};
    final sender  = j['sender']  as Map<String, dynamic>?;

    return _Delivery(
      id:                 (j['id'] as num).toInt(),
      deliveryCode:       j['deliveryCode']    as String? ?? '',
      deliveryType:       j['deliveryType']    as String? ?? 'regular',
      status:             j['status']          as String? ?? '',
      packageSize:        j['packageSize']     as String? ?? '',
      packageCategory:    j['packageCategory'] as String? ?? '',
      categoryLabel:      j['categoryLabel']   as String? ?? '',
      categoryEmoji:      j['categoryEmoji']   as String? ?? '📦',
      pickupAddress:      pickup['address']    as String? ?? '',
      dropoffAddress:     dropoff['address']   as String? ?? '',
      distanceKm:         d('distanceKm'),
      totalPrice:         d('totalPrice'),
      driverPayout:       d('driverPayout'),
      commissionAmount:   d('commissionAmount'),
      paymentMethod:      j['paymentMethod']   as String? ?? '',
      paymentStatus:      j['paymentStatus']   as String? ?? '',
      isSurging:          j['isSurging']       as bool? ?? false,
      senderName:         sender?['name']      as String?,
      recipientName:      j['recipientName']   as String? ?? '',
      durationMinutes:    j['durationMinutes'] as int?,
      deliveredAt:        dt('deliveredAt'),
      cancelledAt:        dt('cancelledAt'),
      displayDate:        displayDate,
      cancelledBy:        j['cancelledBy']        as String?,
      cancellationReason: j['cancellationReason'] as String?,
    );
  }

  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get isExpress   => deliveryType == 'express';
  bool get isCash      => paymentMethod == 'cash';
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

final _numFmt  = NumberFormat('#,###', 'fr_FR');
final _dtShort = DateFormat('d MMM, HH:mm');
final _dtFull  = DateFormat('d MMM yyyy, HH:mm');

String _xaf(double v) => '${_numFmt.format(v.round())} XAF';
String _dur(int? mins) {
  if (mins == null) return '—';
  return mins < 60 ? '${mins}min' : '${mins ~/ 60}h ${mins % 60}min';
}

({Color color, IconData icon, String label}) _statusCfg(String s) =>
    switch (s) {
      'delivered'        => (color: AppColors.success,     icon: Icons.check_circle_rounded,    label: 'Delivered'),
      'cancelled'        => (color: AppColors.error,       icon: Icons.cancel_rounded,           label: 'Cancelled'),
      'en_route_pickup'  => (color: AppColors.info,        icon: Icons.directions_bike_rounded,  label: 'En Route'),
      'arrived_pickup'   => (color: AppColors.info,        icon: Icons.location_on_rounded,      label: 'At Pickup'),
      'picked_up'        => (color: AppColors.primaryGold, icon: Icons.inventory_2_rounded,      label: 'Picked Up'),
      'en_route_dropoff' => (color: AppColors.primaryGold, icon: Icons.directions_bike_rounded,  label: 'Delivering'),
      'arrived_dropoff'  => (color: AppColors.primaryGold, icon: Icons.where_to_vote_rounded,    label: 'Arrived'),
      'accepted'         => (color: AppColors.info,        icon: Icons.thumb_up_rounded,         label: 'Accepted'),
      'disputed'         => (color: AppColors.warning,     icon: Icons.gavel_rounded,            label: 'Disputed'),
      'expired'          => (color: AppColors.secondaryGrey, icon: Icons.access_time_rounded,    label: 'Expired'),
      _                  => (color: AppColors.secondaryGrey, icon: Icons.help_outline_rounded,   label: s),
    };

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<DeliveryHistoryScreen>
    with SingleTickerProviderStateMixin {

  String _token = '';

  _Earnings _earnings        = _Earnings.empty();
  bool      _earningsLoading = true;
  late TabController _tabCtrl;

  final List<_Delivery> _list = [];
  bool _listLoading = true;
  bool _loadingMore = false;
  bool _hasMore     = true;
  int  _page        = 1;
  static const _limit = 15;

  String? _fStatus;
  String? _fType;
  String? _fPayment;

  final _scroll = ScrollController();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this, initialIndex: 1);
    _scroll.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // ✅ Load token FIRST, wait for it, then fire API calls
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    if (mounted) setState(() => _token = token);

    // Now both calls have the token
    await Future.wait([_loadEarnings(), _loadList(reset: true)]);
  }

  Map<String, String> get _h =>
      {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'};

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _loadEarnings() async {
    if (mounted) setState(() => _earningsLoading = true);
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/deliveries/agent/history/earnings'),
          headers: _h)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() =>
        _earnings = _Earnings.fromJson(body['earnings'] as Map<String, dynamic>));
      } else {
        debugPrint('⚠️ Earnings ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('⚠️ Earnings error: $e');
    }
    if (mounted) setState(() => _earningsLoading = false);
  }

  Future<void> _loadList({bool reset = false}) async {
    if (reset) {
      _list.clear();
      _page    = 1;
      _hasMore = true;
      if (mounted) setState(() => _listLoading = true);
    }
    if (!_hasMore) return;

    final params = {
      'page': '$_page', 'limit': '$_limit',
      if (_fStatus  != null) 'status':         _fStatus!,
      if (_fType    != null) 'delivery_type':   _fType!,
      if (_fPayment != null) 'payment_method':  _fPayment!,
    };

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/deliveries/agent/history')
          .replace(queryParameters: params);
      final res = await http.get(uri, headers: _h)
          .timeout(const Duration(seconds: 12));

      debugPrint('📦 History ${res.statusCode}');

      if (res.statusCode == 200 && mounted) {
        final body  = jsonDecode(res.body) as Map<String, dynamic>;
        final rawList = body['deliveries'] as List? ?? [];
        debugPrint('📦 Got ${rawList.length} deliveries');

        // Parse each item individually so one bad record doesn't kill the list
        final rows = <_Delivery>[];
        for (final e in rawList) {
          try {
            rows.add(_Delivery.fromJson(e as Map<String, dynamic>));
          } catch (err) {
            debugPrint('⚠️ Failed to parse delivery: $err\n$e');
          }
        }

        final pages = (((body['pagination'] as Map<String, dynamic>?)?['totalPages']) as num? ?? 1).toInt();
        if (mounted) {
          setState(() {
            _list.addAll(rows);
            _hasMore = _page < pages;
            _page++;
          });
        }
      } else {
        debugPrint('⚠️ History error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('⚠️ History exception: $e');
    }

    if (mounted) setState(() { _listLoading = false; _loadingMore = false; });
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
        !_loadingMore && _hasMore) {
      setState(() => _loadingMore = true);
      _loadList();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasFilter = _fStatus != null || _fType != null || _fPayment != null;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [

          // App bar
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.backgroundWhite,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: AppColors.primaryDark,
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Delivery History',
                style: AppTypography.titleLarge
                    .copyWith(color: AppColors.primaryDark)),
            actions: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    color: hasFilter ? AppColors.primaryGold : AppColors.secondaryGrey,
                    onPressed: _showFilterSheet,
                  ),
                  if (hasFilter)
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: AppColors.primaryGold,
                            shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),

          // Earnings card
          SliverToBoxAdapter(child: _buildEarningsCard()),

          // Quick filter chips
          SliverToBoxAdapter(child: _buildChipsRow()),

          // List content
          if (_listLoading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else if (_list.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildCard(_list[i]),
                  childCount: _list.length,
                ),
              ),
            ),

          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator())),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── Earnings card ──────────────────────────────────────────────────────────

  Widget _buildEarningsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGold, AppColors.primaryGoldDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              indicatorColor: Colors.white,
              indicatorWeight: 2,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: AppTypography.labelSmall
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 11),
              unselectedLabelStyle:
              AppTypography.labelSmall.copyWith(fontSize: 11),
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: 'This Week'),
                Tab(text: 'This Month'),
                Tab(text: 'All Time'),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _tabCtrl,
            builder: (_, __) => _earningsLoading
                ? const SizedBox(height: 100,
                child: Center(child: CircularProgressIndicator(
                    color: Colors.white54, strokeWidth: 2)))
                : _buildPeriod(_earnings.byIndex(_tabCtrl.index)),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriod(_EarningsPeriod p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_xaf(p.totalEarnings),
                  style: AppTypography.displaySmall.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${p.deliveries} deliveries',
                    style: AppTypography.bodySmall
                        .copyWith(color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(Icons.account_balance_wallet_rounded,
                  'Wallet', _xaf(p.walletCredited)),
              const SizedBox(width: 8),
              _stat(Icons.payments_rounded, 'Cash', _xaf(p.cashCollected)),
              const SizedBox(width: 8),
              _stat(Icons.flash_on_rounded, 'Express',
                  '${p.expressCount}', accent: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value,
      {bool accent = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent
              ? Colors.white.withOpacity(0.22)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 13),
            const SizedBox(height: 4),
            Text(value,
                style: AppTypography.labelMedium.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: Colors.white60, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────────

  Widget _buildChipsRow() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('All',       _fStatus == null,
                  () { setState(() => _fStatus = null);        _loadList(reset: true); }),
          const SizedBox(width: 6),
          _chip('Delivered', _fStatus == 'delivered',
                  () { setState(() => _fStatus = 'delivered'); _loadList(reset: true); }),
          const SizedBox(width: 6),
          _chip('Cancelled', _fStatus == 'cancelled',
                  () { setState(() => _fStatus = 'cancelled'); _loadList(reset: true); }),
          const SizedBox(width: 10),
          _chip(
            _fType == 'express' ? '⚡ Express'
                : _fType == 'regular' ? '📦 Regular' : 'All Types',
            _fType != null, _showFilterSheet,
          ),
          const SizedBox(width: 6),
          _chip(
            _fPayment == 'cash'             ? '💵 Cash'
                : _fPayment == 'mtn_mobile_money' ? '📱 MTN'
                : _fPayment == 'orange_money'     ? '🟠 Orange'
                : 'All Payments',
            _fPayment != null, _showFilterSheet,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryGold : AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.primaryGold : AppColors.borderLight),
        ),
        child: Center(
          child: Text(label,
              style: AppTypography.labelSmall.copyWith(
                // ✅ black text on chips
                color: active ? AppColors.primaryDark : AppColors.primaryDark,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              )),
        ),
      ),
    );
  }

  // ── Empty ──────────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 64, color: AppColors.secondaryLightGrey),
          const SizedBox(height: 16),
          Text('No deliveries yet',
              style: AppTypography.titleMedium
                  .copyWith(color: AppColors.primaryDark)),
          const SizedBox(height: 8),
          Text(
            (_fStatus != null || _fType != null || _fPayment != null)
                ? 'Try changing your filters'
                : 'Completed deliveries will appear here',
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.secondaryGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Delivery card ──────────────────────────────────────────────────────────

  Widget _buildCard(_Delivery d) {
    final cfg = _statusCfg(d.status);
    return GestureDetector(
      onTap: () => _openDetail(d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: d.isDelivered
                ? AppColors.success.withOpacity(0.25)
                : d.isCancelled
                ? AppColors.error.withOpacity(0.15)
                : AppColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(
                        color: AppColors.backgroundLight,
                        shape: BoxShape.circle),
                    child: Center(
                        child: Text(d.categoryEmoji,
                            style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // ✅ black delivery code
                            Text(d.deliveryCode,
                                style: AppTypography.titleSmall.copyWith(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700)),
                            if (d.isExpress) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('⚡ Express',
                                    style: AppTypography.labelSmall.copyWith(
                                        color: Colors.orange,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        // ✅ black date
                        Text(
                          _dtShort.format(d.displayDate.toLocal()),
                          style: AppTypography.labelSmall.copyWith(
                              color: AppColors.secondaryGrey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cfg.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cfg.icon, color: cfg.color, size: 11),
                        const SizedBox(width: 4),
                        Text(cfg.label,
                            style: AppTypography.labelSmall.copyWith(
                                color: cfg.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Route ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child:
              _routeRow(d.pickupAddress, d.dropoffAddress, d.distanceKm),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderLight),

            // ── Footer ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ payout amount black when delivered
                        Text(
                          d.isDelivered ? _xaf(d.driverPayout) : '—',
                          style: AppTypography.titleSmall.copyWith(
                            color: d.isDelivered
                                ? AppColors.success
                                : AppColors.secondaryGrey,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          d.isDelivered
                              ? (d.isCash ? 'Cash delivery' : 'Wallet credited')
                              : (d.isCancelled ? 'Cancelled' : d.status),
                          style: AppTypography.labelSmall.copyWith(
                            // ✅ black sublabel
                              color: AppColors.primaryDark, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  if (d.durationMinutes != null) ...[
                    _tag(Icons.timer_outlined, _dur(d.durationMinutes)),
                    const SizedBox(width: 6),
                  ],
                  _tag(
                    d.isCash
                        ? Icons.payments_rounded
                        : Icons.phone_android_rounded,
                    d.isCash
                        ? 'Cash'
                        : d.paymentMethod == 'mtn_mobile_money'
                        ? 'MTN'
                        : 'Orange',
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.secondaryGrey, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeRow(String pickup, String dropoff, double dist) {
    return Row(
      children: [
        Column(
          children: [
            Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.success, shape: BoxShape.circle)),
            Container(width: 1.5, height: 18, color: AppColors.borderLight),
            Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primaryGold, shape: BoxShape.circle)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ black address text
              Text(pickup,
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primaryDark, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(dropoff,
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primaryDark, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('${dist.toStringAsFixed(1)} km',
            style: AppTypography.labelSmall
                .copyWith(color: AppColors.secondaryGrey, fontSize: 10)),
      ],
    );
  }

  Widget _tag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.secondaryGrey, size: 11),
          const SizedBox(width: 3),
          // ✅ black tag text
          Text(label,
              style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primaryDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Filter sheet ───────────────────────────────────────────────────────────

  void _showFilterSheet() {
    String? tStatus  = _fStatus;
    String? tType    = _fType;
    String? tPayment = _fPayment;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Filter Deliveries',
                  style: AppTypography.titleLarge
                      .copyWith(color: AppColors.primaryDark)),
              const SizedBox(height: 20),
              _sheetSection('Status', {
                null: 'All', 'delivered': 'Delivered', 'cancelled': 'Cancelled',
              }, tStatus, (v) => setSt(() => tStatus = v)),
              const SizedBox(height: 16),
              _sheetSection('Type', {
                null: 'All', 'regular': '📦 Regular', 'express': '⚡ Express',
              }, tType, (v) => setSt(() => tType = v)),
              const SizedBox(height: 16),
              _sheetSection('Payment', {
                null: 'All',
                'cash': '💵 Cash',
                'mtn_mobile_money': '📱 MTN',
                'orange_money': '🟠 Orange',
              }, tPayment, (v) => setSt(() => tPayment = v)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() { _fStatus = _fType = _fPayment = null; });
                        _loadList(reset: true);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderLight),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Clear',
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.primaryDark)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _fStatus  = tStatus;
                          _fType    = tType;
                          _fPayment = tPayment;
                        });
                        _loadList(reset: true);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Apply',
                          style: AppTypography.labelMedium.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetSection(
      String title,
      Map<String?, String> opts,
      String? current,
      void Function(String?) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTypography.labelMedium
                .copyWith(color: AppColors.secondaryGrey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 6,
          children: opts.entries.map((e) {
            final active = current == e.key;
            return GestureDetector(
              onTap: () => onSelect(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryGold
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: active
                          ? AppColors.primaryGold
                          : AppColors.borderLight),
                ),
                child: Text(e.value,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    )),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _openDetail(_Delivery d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(delivery: d, headers: _h),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _DetailSheet extends StatefulWidget {
  final _Delivery delivery;
  final Map<String, String> headers;
  const _DetailSheet({required this.delivery, required this.headers});

  @override
  State<_DetailSheet> createState() => _DetailState();
}

class _DetailState extends State<_DetailSheet> {
  Map<String, dynamic>? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await http
          .get(Uri.parse(
          '${AppConfig.apiBaseUrl}/deliveries/agent/history/${widget.delivery.id}'),
          headers: widget.headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _detail = body['delivery'] as Map<String, dynamic>?);
      }
    } catch (e) {
      debugPrint('⚠️ Detail fetch error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final d   = widget.delivery;
    final cfg = _statusCfg(d.status);
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize:     0.4,
      maxChildSize:     0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Text(d.categoryEmoji,
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.deliveryCode,
                            style: AppTypography.titleLarge.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800)),
                        Text('${d.categoryLabel} · ${d.packageSize}',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.secondaryGrey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cfg.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(cfg.label,
                        style: AppTypography.labelSmall.copyWith(
                            color: cfg.color, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  if (d.isDelivered) ...[
                    _earningsSection(d), const SizedBox(height: 20),
                  ],
                  _routeSection(d),     const SizedBox(height: 20),
                  _recipientSection(d), const SizedBox(height: 20),
                  _timelineSection(d),
                  if (d.isCancelled && d.cancellationReason != null) ...[
                    const SizedBox(height: 20),
                    _cancelSection(d),
                  ],
                  if (_detail != null) ...[
                    const SizedBox(height: 20),
                    _txnSection(),
                  ],
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: d.deliveryCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Code copied'),
                            duration: Duration(seconds: 1)),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text('Copy ${d.deliveryCode}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondaryGrey,
                      side: const BorderSide(
                          color: AppColors.borderLight),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _earningsSection(_Delivery d) => _sec(
    'Earnings',
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _row2('Your payout', _xaf(d.driverPayout),
              valueColor: AppColors.success, bold: true),
          const SizedBox(height: 8),
          _row2('WeGo commission', '- ${_xaf(d.commissionAmount)}',
              valueColor: AppColors.error),
          Divider(height: 16, color: AppColors.success.withOpacity(0.2)),
          _row2('Total fare', _xaf(d.totalPrice), bold: true),
          if (d.isCash) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.orange, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cash delivery — collected ${_xaf(d.totalPrice)}, '
                          'owe ${_xaf(d.commissionAmount)} to WeGo.',
                      style: AppTypography.bodySmall.copyWith(
                          color: Colors.orange, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _routeSection(_Delivery d) => _sec(
    'Route · ${d.distanceKm.toStringAsFixed(1)} km',
    Column(children: [
      _iconRow(Icons.trip_origin_rounded, 'Pickup',
          d.pickupAddress, AppColors.success),
      const SizedBox(height: 12),
      _iconRow(Icons.location_on_rounded, 'Dropoff',
          d.dropoffAddress, AppColors.primaryGold),
    ]),
  );

  Widget _recipientSection(_Delivery d) => _sec(
    'Recipient',
    Column(children: [
      _iconRow(Icons.person_rounded, 'Name', d.recipientName),
      if (d.senderName != null) ...[
        const SizedBox(height: 10),
        _iconRow(Icons.send_rounded, 'Booked by', d.senderName!),
      ],
    ]),
  );

  Widget _timelineSection(_Delivery d) {
    final events = <({String label, String? time, Color color})>[
      (label: 'Delivery accepted',
      time: _dtFull.format(d.displayDate.toLocal()),
      color: AppColors.secondaryGrey),
      if (d.deliveredAt != null)
        (label: 'Delivered',
        time: _dtFull.format(d.deliveredAt!.toLocal()),
        color: AppColors.success),
      if (d.cancelledAt != null)
        (label: 'Cancelled',
        time: _dtFull.format(d.cancelledAt!.toLocal()),
        color: AppColors.error),
    ];
    return _sec(
      'Timeline${d.durationMinutes != null ? ' · ${_dur(d.durationMinutes)}' : ''}',
      Column(
        children: events.asMap().entries.map((entry) {
          final isLast = entry.key == events.length - 1;
          final e      = entry.value;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                        color: e.color, shape: BoxShape.circle)),
                if (!isLast)
                  Container(width: 1.5, height: 28,
                      color: AppColors.borderLight),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.label,
                          style: AppTypography.labelMedium.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600)),
                      if (e.time != null)
                        Text(e.time!,
                            style: AppTypography.bodySmall.copyWith(
                                color: AppColors.secondaryGrey,
                                fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _cancelSection(_Delivery d) => _sec(
    'Cancellation',
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: AppColors.error, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(d.cancellationReason!,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.error, fontSize: 12)),
        ),
      ]),
    ),
  );

  Widget _txnSection() {
    final txns = (_detail!['walletTransactions'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    if (txns.isEmpty) return const SizedBox.shrink();
    return _sec(
      'Wallet Transactions',
      Column(
        children: txns.map((t) {
          final type   = t['type'] as String? ?? '';
          final amount = (t['amount'] as num? ?? 0).toDouble();
          final credit = type == 'delivery_earning' || type == 'cash_collected';
          final label  = {
            'delivery_earning':     'Earning credited',
            'commission_deduction': 'Commission deducted',
            'cash_collected':       'Cash collected',
            'cash_commission_owed': 'Commission owed',
          }[type] ?? type;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: credit
                      ? AppColors.success.withOpacity(0.12)
                      : AppColors.error.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  credit
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: credit ? AppColors.success : AppColors.error,
                  size: 14,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primaryDark)),
              ),
              Text(
                '${credit ? '+' : '-'} ${_xaf(amount)}',
                style: AppTypography.labelMedium.copyWith(
                  color: credit ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _sec(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title,
          style: AppTypography.labelMedium.copyWith(
              color: AppColors.secondaryGrey,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
      const SizedBox(height: 10),
      child,
    ],
  );

  Widget _row2(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: bold
                ? AppTypography.labelMedium.copyWith(
                color: AppColors.primaryDark, fontWeight: FontWeight.w700)
                : AppTypography.bodySmall
                .copyWith(color: AppColors.primaryDark)),
        Text(value,
            style: bold
                ? AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.primaryDark)
                : AppTypography.bodySmall
                .copyWith(color: valueColor ?? AppColors.primaryDark)),
      ],
    );
  }

  Widget _iconRow(IconData icon, String label, String value,
      [Color? iconColor]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor ?? AppColors.secondaryGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.secondaryGrey, fontSize: 10)),
              Text(value,
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
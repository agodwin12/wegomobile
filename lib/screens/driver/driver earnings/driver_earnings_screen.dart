// lib/screens/driver/earnings/driver_earnings_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';

const _kBlack   = Color(0xFF0A0A0A);
const _kGold    = Color(0xFFFFDC71);
const _kCard    = Color(0xFF181818);
const _kCardAlt = Color(0xFF222222);
const _kWhite   = Colors.white;
const _kGrey    = Color(0xFFA9A9A9);
const _kGreen   = Color(0xFF4CAF50);
const _kRed     = Color(0xFFEF5350);
const _kOrange  = Color(0xFFFF6B35);   // used for TOP_UP accent

// ═══════════════════════════════════════════════════════════════════════
// API
// ═══════════════════════════════════════════════════════════════════════

class _EarningsApi {
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  static Future<Map<String, dynamic>> getSummary() async {
    final res = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/earnings/driver/summary'),
      headers: await _headers(),
    );
    return json.decode(res.body);
  }

  static Future<Map<String, dynamic>> getTrips({int page = 1, String period = 'week'}) async {
    final res = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/earnings/driver/trips?page=$page&limit=20&period=$period'),
      headers: await _headers(),
    );
    return json.decode(res.body);
  }

  static Future<Map<String, dynamic>> getActivity({
    int page = 1,
    String period = 'all',
    String type = 'all',
  }) async {
    final res = await http.get(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/earnings/driver/activity'
            '?page=$page&limit=30&period=$period&type=$type',
      ),
      headers: await _headers(),
    );
    return json.decode(res.body);
  }

  static Future<Map<String, dynamic>> getQuests() async {
    final res = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/earnings/driver/quests'),
      headers: await _headers(),
    );
    return json.decode(res.body);
  }

  static Future<Map<String, dynamic>> getRecentPayouts() async {
    final res = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/request/payout/driver?limit=3'),
      headers: await _headers(),
    );
    return json.decode(res.body);
  }

  static Future<Map<String, dynamic>> requestPayout({
    required int amount,
    required String paymentMethod,
    String? note,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/request/payout/driver'),
      headers: await _headers(),
      body: json.encode({
        'amount':        amount,
        'paymentMethod': paymentMethod,
        if (note != null) 'note': note,
      }),
    );
    return json.decode(res.body);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  // ── Summary ───────────────────────────────────────────────────────
  Map<String, dynamic>? _summary;
  bool    _summaryLoading = true;
  String? _summaryError;

  // ── Quests ────────────────────────────────────────────────────────
  List<dynamic> _quests        = [];
  bool          _questsLoading = true;

  // ── Trips tab ─────────────────────────────────────────────────────
  List<dynamic> _trips            = [];
  bool          _tripsLoading     = true;
  bool          _tripsLoadingMore = false;
  int           _tripsPage        = 1;
  int           _tripsTotalPages  = 1;
  String        _tripsPeriod      = 'week';

  // ── Activity tab ──────────────────────────────────────────────────
  List<dynamic>         _activity             = [];
  bool                  _activityLoading      = true;
  bool                  _activityLoadingMore  = false;
  int                   _activityPage         = 1;
  int                   _activityTotalPages   = 1;
  String                _activityPeriod       = 'all';
  String                _activityTypeFilter   = 'all';   // ← new: filter by tx type
  Map<String, dynamic>? _activityPeriodSummary;

  // ── Payouts ───────────────────────────────────────────────────────
  List<dynamic> _recentPayouts        = [];
  bool          _recentPayoutsLoading = true;

  final ScrollController _tripsScroll    = ScrollController();
  final ScrollController _activityScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tripsScroll.addListener(_onTripsScroll);
    _activityScroll.addListener(_onActivityScroll);
    _loadAll();
  }

  void _loadAll() {
    _loadSummary();
    _loadQuests();
    _loadTrips(reset: true);
    _loadActivity(reset: true);
    _loadRecentPayouts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tripsScroll.dispose();
    _activityScroll.dispose();
    super.dispose();
  }

  // ── Data loaders ──────────────────────────────────────────────────

  Future<void> _loadSummary() async {
    if (!mounted) return;
    setState(() { _summaryLoading = true; _summaryError = null; });
    try {
      final res = await _EarningsApi.getSummary();
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() { _summary = res['data']; _summaryLoading = false; });
      } else {
        setState(() { _summaryError = res['message'] ?? 'Failed'; _summaryLoading = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _summaryError = 'Network error'; _summaryLoading = false; });
    }
  }

  Future<void> _loadQuests() async {
    if (!mounted) return;
    setState(() => _questsLoading = true);
    try {
      final res = await _EarningsApi.getQuests();
      if (!mounted) return;
      setState(() {
        _quests = res['success'] == true ? (res['data']['quests'] ?? []) : [];
        _questsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _questsLoading = false);
    }
  }

  Future<void> _loadTrips({bool reset = false}) async {
    if (!mounted) return;
    if (reset) setState(() { _tripsLoading = true; _trips = []; _tripsPage = 1; });
    else setState(() => _tripsLoadingMore = true);
    try {
      final res = await _EarningsApi.getTrips(page: _tripsPage, period: _tripsPeriod);
      if (!mounted) return;
      if (res['success'] == true) {
        final data = res['data'];
        setState(() {
          _trips.addAll(data['receipts'] ?? []);
          _tripsTotalPages  = data['pagination']?['totalPages'] ?? 1;
          _tripsLoading     = false;
          _tripsLoadingMore = false;
        });
      } else {
        setState(() { _tripsLoading = false; _tripsLoadingMore = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _tripsLoading = false; _tripsLoadingMore = false; });
    }
  }

  Future<void> _loadActivity({bool reset = false}) async {
    if (!mounted) return;
    if (reset) setState(() { _activityLoading = true; _activity = []; _activityPage = 1; });
    else setState(() => _activityLoadingMore = true);
    try {
      final res = await _EarningsApi.getActivity(
        page:   _activityPage,
        period: _activityPeriod,
        type:   _activityTypeFilter,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        final data = res['data'];
        setState(() {
          _activity.addAll(data['transactions'] ?? []);
          _activityTotalPages    = data['pagination']?['totalPages'] ?? 1;
          _activityPeriodSummary = data['periodSummary'];
          _activityLoading       = false;
          _activityLoadingMore   = false;
        });
      } else {
        setState(() { _activityLoading = false; _activityLoadingMore = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _activityLoading = false; _activityLoadingMore = false; });
    }
  }

  // Payouts/withdrawals removed — WeGo is deposit/top-up only. No-op kept so
  // existing call sites stay valid.
  Future<void> _loadRecentPayouts() async {
    if (!mounted) return;
    setState(() => _recentPayoutsLoading = false);
  }

  void _onTripsScroll() {
    if (_tripsScroll.position.pixels >= _tripsScroll.position.maxScrollExtent - 200) {
      if (!_tripsLoadingMore && _tripsPage < _tripsTotalPages) {
        _tripsPage++;
        _loadTrips();
      }
    }
  }

  void _onActivityScroll() {
    if (_activityScroll.position.pixels >= _activityScroll.position.maxScrollExtent - 200) {
      if (!_activityLoadingMore && _activityPage < _activityTotalPages) {
        _activityPage++;
        _loadActivity();
      }
    }
  }

  // ── Payout bottom sheet ───────────────────────────────────────────

  void _openPayoutSheet() {
    final balance = (_summary?['balance'] as num?)?.toInt() ?? 0;
    showModalBottomSheet(
      context:             context,
      isScrollControlled:  true,
      backgroundColor:     Colors.transparent,
      builder: (_) => _PayoutRequestSheet(
        availableBalance: balance,
        onSuccess: () { _loadSummary(); _loadRecentPayouts(); },
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildTripsTab(),
                  _buildActivityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color:   _kBlack,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Earnings',
                style: TextStyle(
                  fontFamily:    'LeagueSpartan',
                  fontSize:      26,
                  fontWeight:    FontWeight.w700,
                  color:         _kWhite,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadAll,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color:        _kCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.refresh_rounded, color: _kGold, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _summaryLoading
              ? _buildShimmerBalance()
              : _summaryError != null
              ? _buildErrorBalance()
              : _buildBalanceCard(),
          const SizedBox(height: 14),
          _buildTabBar(),
        ],
      ),
    );
  }

  // ── Balance card ──────────────────────────────────────────────────

  Widget _buildBalanceCard() {
    final s          = _summary ?? {};
    final balance    = s['balance']         ?? 0;
    final todayNet   = s['today']?['net']   ?? 0;
    final todayTrips = s['today']?['trips'] ?? 0;
    final weekNet    = s['week']?['net']    ?? 0;
    final weekTrips  = s['week']?['trips']  ?? 0;
    final monthNet   = s['month']?['net']   ?? 0;
    final currency   = s['currency']        ?? 'XAF';
    final isFrozen   = s['walletStatus']    == 'FROZEN';

    return Column(
      children: [
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
              colors: isFrozen
                  ? [const Color(0xFF2A1A00), const Color(0xFF1A1000)]
                  : [const Color(0xFF1A1500), const Color(0xFF111100)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFrozen
                  ? Colors.orange.withOpacity(0.4)
                  : _kGold.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFrozen ? '🔒 Wallet Frozen' : 'Available Balance',
                      style: const TextStyle(
                        fontFamily:    'Quicksand',
                        fontSize:      11,
                        fontWeight:    FontWeight.w600,
                        color:         _kGrey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatAmount(balance),
                      style: TextStyle(
                        fontFamily:    'LeagueSpartan',
                        fontSize:      30,
                        fontWeight:    FontWeight.w800,
                        color:         isFrozen ? Colors.orange : _kGold,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:     const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration:  BoxDecoration(
                      color:        _kGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currency,
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize:   12,
                        fontWeight: FontWeight.w700,
                        color:      _kGold,
                      ),
                    ),
                  ),
                  // Withdraw button removed — WeGo is deposit/top-up only.
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildStatChip('Today',      todayNet,  todayTrips, 'trips')),
            const SizedBox(width: 8),
            Expanded(child: _buildStatChip('This Week',  weekNet,   weekTrips,  'trips')),
            const SizedBox(width: 8),
            Expanded(child: _buildStatChip('This Month', monthNet,  null,       null)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, dynamic amount, dynamic count, String? countLabel) {
    return Container(
      padding:     const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration:  BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Quicksand', fontSize: 10, color: _kGrey)),
          const SizedBox(height: 4),
          Text(
            _formatAmount(amount),
            style: const TextStyle(
              fontFamily: 'LeagueSpartan',
              fontSize:   14,
              fontWeight: FontWeight.w700,
              color:      _kWhite,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (count != null) ...[
            const SizedBox(height: 2),
            Text(
              '$count $countLabel',
              style: const TextStyle(
                fontFamily: 'Quicksand',
                fontSize:   10,
                color:      _kGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmerBalance() => Container(
    height:     100,
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
    child:      const Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)),
  );

  Widget _buildErrorBalance() => Container(
    padding:    const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: _kRed, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(_summaryError!, style: const TextStyle(color: _kGrey, fontSize: 13))),
        GestureDetector(
          onTap: _loadSummary,
          child: const Text('Retry', style: TextStyle(color: _kGold, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  Widget _buildTabBar() => Container(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
    ),
    child: TabBar(
      controller:           _tabController,
      labelColor:           _kGold,
      unselectedLabelColor: _kGrey,
      indicatorColor:       _kGold,
      indicatorWeight:      2.5,
      indicatorSize:        TabBarIndicatorSize.label,
      labelStyle: const TextStyle(
        fontFamily: 'Quicksand',
        fontWeight: FontWeight.w700,
        fontSize:   13,
      ),
      tabs: const [Tab(text: 'Overview'), Tab(text: 'Trips'), Tab(text: 'Activity')],
    ),
  );

  // ═════════════════════════════════════════════════════════════════
  // OVERVIEW TAB
  // ═════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      color:           _kGold,
      backgroundColor: _kCard,
      onRefresh: () async {
        await Future.wait([_loadSummary(), _loadQuests(), _loadRecentPayouts()]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_summary != null) _buildLifetimeStats(),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Active Quests',
                  style: TextStyle(
                    fontFamily: 'LeagueSpartan',
                    fontSize:   20,
                    fontWeight: FontWeight.w700,
                    color:      _kWhite,
                  ),
                ),
                const Spacer(),
                if (_questsLoading)
                  const SizedBox(
                    width:  16, height: 16,
                    child:  CircularProgressIndicator(color: _kGold, strokeWidth: 1.5),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_questsLoading)
              ..._buildQuestShimmers()
            else if (_quests.isEmpty)
              _buildEmptyQuests()
            else
              ..._quests.map((q) => _buildQuestCard(q as Map<String, dynamic>)),
          ],
        ),
      ),
    );
  }

  // ── Lifetime stats ────────────────────────────────────────────────

  Widget _buildLifetimeStats() {
    final s = _summary!;
    return Container(
      padding:     const EdgeInsets.all(20),
      decoration:  BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIFETIME SUMMARY',
            style: TextStyle(
              fontFamily:    'Quicksand',
              fontSize:      11,
              color:         _kGrey,
              fontWeight:    FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Row 1: total earned + commission
          Row(children: [
            Expanded(child: _buildLifetimeStat('Total Earned',  s['totalEarned']     ?? 0, _kGold)),
            const SizedBox(width: 16),
            Expanded(child: _buildLifetimeStat('Commission',    s['totalCommission'] ?? 0, _kRed)),
          ]),
          const SizedBox(height: 12),

          // Row 2: bonuses + total top-ups
          // totalTopUps is shown here — separate from totalEarned so the driver
          // can clearly see how much they funded vs how much they actually earned.
          Row(children: [
            Expanded(child: _buildLifetimeStat('Bonuses',       s['totalBonuses']    ?? 0, _kGreen)),
            const SizedBox(width: 16),
            Expanded(child: _buildLifetimeStat(
              'Total Topped Up',
              s['totalTopUps'] ?? 0,
              _kOrange,
              icon: Icons.account_balance_wallet_rounded,
            )),
          ]),
          const SizedBox(height: 12),

          // Row 3: paid out (full width)
          _buildLifetimeStat('Paid Out', s['totalPayouts'] ?? 0, _kGrey),
        ],
      ),
    );
  }

  Widget _buildLifetimeStat(
      String label,
      dynamic amount,
      Color color, {
        IconData? icon,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatAmount(amount),
          style: TextStyle(
            fontFamily: 'LeagueSpartan',
            fontSize:   18,
            fontWeight: FontWeight.w700,
            color:      color,
          ),
        ),
      ],
    );
  }

  // ── Quest cards ───────────────────────────────────────────────────

  Widget _buildQuestCard(Map<String, dynamic> q) {
    final progress  = (q['progressPercent'] as num?)?.toDouble() ?? 0.0;
    final completed = q['isCompleted'] == true;
    return Container(
      margin:      const EdgeInsets.only(bottom: 12),
      padding:     const EdgeInsets.all(16),
      decoration:  BoxDecoration(
        color:        completed ? const Color(0xFF0A1A0A) : _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed ? _kGreen.withOpacity(0.4) : _kGold.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(q['iconEmoji'] ?? '🏆', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q['name'] ?? '',
                      style: const TextStyle(
                        fontFamily: 'LeagueSpartan',
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color:      _kWhite,
                      ),
                    ),
                    Text(
                      completed
                          ? '✅ Completed!'
                          : '${q['remaining'] ?? 0} ${q['metricUnit'] ?? 'trips'} remaining',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize:   12,
                        color:      completed ? _kGreen : _kGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:     const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration:  BoxDecoration(
                  color:        (completed ? _kGreen : _kGold).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${_formatAmount(q['bonusAmount'] ?? 0)}',
                  style: TextStyle(
                    fontFamily: 'LeagueSpartan',
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      completed ? _kGreen : _kGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           (progress / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.07),
              valueColor:      AlwaysStoppedAnimation(completed ? _kGreen : _kGold),
              minHeight:       6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${q['currentMetric'] ?? 0} / ${q['targetValue'] ?? 1} ${q['metricUnit'] ?? 'trips'}',
                style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey),
              ),
              Text(
                '${progress.toInt()}%',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize:   11,
                  fontWeight: FontWeight.w700,
                  color:      completed ? _kGreen : _kGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQuestShimmers() => List.generate(
    2,
        (_) => Container(
      height:      100,
      margin:      const EdgeInsets.only(bottom: 12),
      decoration:  BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
    ),
  );

  Widget _buildEmptyQuests() => Container(
    padding:     const EdgeInsets.all(24),
    decoration:  BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(16)),
    child: const Center(
      child: Column(children: [
        Text('🎯', style: TextStyle(fontSize: 32)),
        SizedBox(height: 8),
        Text('No active quests right now', style: TextStyle(fontFamily: 'Quicksand', color: _kGrey, fontSize: 14)),
      ]),
    ),
  );

  // ═════════════════════════════════════════════════════════════════
  // TRIPS TAB
  // ═════════════════════════════════════════════════════════════════

  Widget _buildTripsTab() {
    return Column(
      children: [
        _buildPeriodFilter(
          selected: _tripsPeriod,
          onSelect: (p) { setState(() => _tripsPeriod = p); _loadTrips(reset: true); },
        ),
        Expanded(
          child: _tripsLoading
              ? _buildCenteredLoader()
              : _trips.isEmpty
              ? _buildEmptyState('No trips found\nfor this period', '🚗')
              : RefreshIndicator(
            color:           _kGold,
            backgroundColor: _kCard,
            onRefresh:       () => _loadTrips(reset: true),
            child: ListView.builder(
              controller: _tripsScroll,
              padding:    const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount:  _trips.length + (_tripsLoadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _trips.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child:   Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)),
                  );
                }
                return _buildTripReceiptCard(_trips[i] as Map<String, dynamic>);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripReceiptCard(Map<String, dynamic> r) {
    return Container(
      margin:      const EdgeInsets.only(bottom: 12),
      padding:     const EdgeInsets.all(16),
      decoration:  BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:  36, height: 36,
                decoration: BoxDecoration(color: _kGold.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.directions_car, color: _kGold, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['trip']?['pickupAddress'] ?? 'Pickup',
                      style: const TextStyle(fontFamily: 'Quicksand', fontSize: 12, color: _kWhite, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '→ ${r['trip']?['dropoffAddress'] ?? 'Dropoff'}',
                      style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatAmount(r['driverNet'] ?? 0),
                    style: const TextStyle(fontFamily: 'LeagueSpartan', fontSize: 18, fontWeight: FontWeight.w800, color: _kGold),
                  ),
                  Text(
                    _formatDate(r['createdAt']),
                    style: const TextStyle(fontFamily: 'Quicksand', fontSize: 10, color: _kGrey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildBreakdownItem('Fare',       _formatAmount(r['grossFare']        ?? 0), _kGrey)),
              Expanded(child: _buildBreakdownItem('Commission', '-${_formatAmount(r['commissionAmount'] ?? 0)}', _kRed)),
              Expanded(child: _buildBreakdownItem('Bonus',      '+${_formatAmount(r['bonusTotal']    ?? 0)}', _kGreen)),
              Expanded(child: _buildBreakdownItem('Net',        _formatAmount(r['driverNet']         ?? 0), _kGold)),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding:     const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration:  BoxDecoration(
                color:        Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _methodLabel(r['paymentMethod'] ?? 'CASH'),
                style: const TextStyle(fontFamily: 'Quicksand', fontSize: 10, color: _kGrey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String label, String value, Color color) => Column(
    children: [
      Text(label,  style: const TextStyle(fontFamily: 'Quicksand', fontSize: 10, color: _kGrey)),
      const SizedBox(height: 2),
      Text(value,  style: TextStyle(fontFamily: 'Quicksand', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ],
  );

  // ═════════════════════════════════════════════════════════════════
  // ACTIVITY TAB
  // ═════════════════════════════════════════════════════════════════

  Widget _buildActivityTab() {
    return Column(
      children: [
        // Period filter
        _buildPeriodFilter(
          selected: _activityPeriod,
          onSelect: (p) { setState(() => _activityPeriod = p); _loadActivity(reset: true); },
        ),
        // Type filter — now includes TOP_UP
        _buildTypeFilter(),
        if (_activityPeriodSummary != null && !_activityLoading)
          _buildPeriodSummaryBar(),
        Expanded(
          child: _activityLoading
              ? _buildCenteredLoader()
              : _activity.isEmpty
              ? _buildEmptyState('No transactions\nfor this period', '📊')
              : RefreshIndicator(
            color:           _kGold,
            backgroundColor: _kCard,
            onRefresh:       () => _loadActivity(reset: true),
            child: ListView.builder(
              controller: _activityScroll,
              padding:    const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount:  _activity.length + (_activityLoadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _activity.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child:   Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)),
                  );
                }
                return _buildTransactionRow(_activity[i] as Map<String, dynamic>);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Horizontal scrollable pill filters for transaction type.
  /// Lets driver view only top-ups, only payouts, etc.
  Widget _buildTypeFilter() {
    const types = [
      ('all',         'All'),
      ('TOP_UP',      'Top-Ups'),
      ('TRIP_FARE',   'Fares'),
      ('COMMISSION',  'Commission'),
      ('BONUS_TRIP',  'Trip Bonus'),
      ('BONUS_QUEST', 'Quests'),
      ('PAYOUT',      'Payouts'),
      ('ADJUSTMENT',  'Adjustments'),
      ('REFUND',      'Refunds'),
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.fromLTRB(20, 4, 20, 0),
        children: types.map((t) {
          final isSelected = _activityTypeFilter == t.$1;
          return GestureDetector(
            onTap: () {
              if (_activityTypeFilter != t.$1) {
                setState(() => _activityTypeFilter = t.$1);
                _loadActivity(reset: true);
              }
            },
            child: AnimatedContainer(
              duration:    const Duration(milliseconds: 200),
              margin:      const EdgeInsets.only(right: 8),
              padding:     const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration:  BoxDecoration(
                color:        isSelected
                    ? (t.$1 == 'TOP_UP' ? _kOrange : _kGold)
                    : _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? (t.$1 == 'TOP_UP' ? _kOrange : _kGold)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                t.$2,
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize:   11,
                  fontWeight: FontWeight.w700,
                  color:      isSelected ? _kBlack : _kGrey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodSummaryBar() {
    final ps    = _activityPeriodSummary!;
    final net   = ps['net'] ?? 0;
    final isPos = (net as num) >= 0;
    return Container(
      margin:      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration:  BoxDecoration(color: _kCardAlt, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _buildMiniStat('Credits', _formatAmount(ps['totalCredits'] ?? 0), _kGreen)),
          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.07)),
          Expanded(child: _buildMiniStat('Debits',  _formatAmount(ps['totalDebits']  ?? 0), _kRed)),
          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.07)),
          Expanded(child: _buildMiniStat(
            'Net',
            _formatAmount((net as num).abs()),
            isPos ? _kGold : _kRed,
          )),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) => Column(
    children: [
      Text(label, style: const TextStyle(fontFamily: 'Quicksand', fontSize: 10, color: _kGrey)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ],
  );

  Widget _buildTransactionRow(Map<String, dynamic> tx) {
    final isCredit   = tx['isCredit'] == true;
    final txType     = tx['type']?.toString() ?? '';
    final isTopUp    = txType == 'TOP_UP';
    final isPayout   = txType == 'PAYOUT';

    // TOP_UP gets the orange accent; everything else uses green/red
    final color = isTopUp
        ? _kOrange
        : isCredit ? _kGreen : _kRed;

    // For top-ups, show the payment method as a subtitle chip
    final topUpMethod  = tx['topUpMethod']?.toString();
    final payoutMethod = tx['payoutMethod']?.toString();
    final methodLabel  = isTopUp   ? (topUpMethod  != null ? _methodLabel(topUpMethod)  : null)
        : isPayout  ? (payoutMethod != null ? _methodLabel(payoutMethod) : null)
        : null;

    return Container(
      margin:      const EdgeInsets.only(bottom: 8),
      padding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration:  BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          // Type icon
          Container(
            width:  38, height: 38,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(_txIcon(txType), style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),

          // Label + description + method chip
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx['label'] ?? tx['type'] ?? '',
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      _kWhite,
                  ),
                ),
                Text(
                  tx['description'] ?? '',
                  style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                // Method chip for top-ups and payouts
                if (methodLabel != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:     const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration:  BoxDecoration(
                      color:        color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      methodLabel,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                        color:      color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Amount + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${_formatAmount((tx['amount'] as num?)?.abs() ?? 0)}',
                style: TextStyle(
                  fontFamily: 'LeagueSpartan',
                  fontSize:   15,
                  fontWeight: FontWeight.w800,
                  color:      color,
                ),
              ),
              Text(
                _formatDate(tx['createdAt']),
                style: const TextStyle(fontFamily: 'Quicksand', fontSize: 10, color: _kGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═════════════════════════════════════════════════════════════════

  Widget _buildPeriodFilter({
    required String selected,
    required void Function(String) onSelect,
  }) {
    const periods = [
      ('today', 'Today'),
      ('week',  'This Week'),
      ('month', 'This Month'),
      ('all',   'All Time'),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.fromLTRB(20, 4, 20, 0),
        children: periods.map((p) {
          final isSelected = selected == p.$1;
          return GestureDetector(
            onTap: () => onSelect(p.$1),
            child: AnimatedContainer(
              duration:    const Duration(milliseconds: 200),
              margin:      const EdgeInsets.only(right: 8),
              padding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration:  BoxDecoration(
                color:        isSelected ? _kGold : _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _kGold : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                p.$2,
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize:   12,
                  fontWeight: FontWeight.w700,
                  color:      isSelected ? _kBlack : _kGrey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCenteredLoader() =>
      const Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2));

  Widget _buildEmptyState(String message, String emoji) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Quicksand',
            fontSize:   14,
            color:      _kGrey,
            height:     1.6,
          ),
        ),
      ],
    ),
  );

  // ═════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════

  String _formatAmount(dynamic amount) {
    final val = (amount as num?)?.toInt() ?? 0;
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M XAF';
    if (val >= 1000)    return '${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}K XAF';
    return '$val XAF';
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt  = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  String _methodLabel(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':             return '💵 Cash';
      case 'MTN_MOMO':         return '🟡 MTN MoMo';
      case 'ORANGE_MONEY':     return '🟠 Orange Money';
      case 'BANK_TRANSFER':    return '🏦 Bank Transfer';
      case 'MOMO':             return '🟡 MTN MoMo';
      case 'OM':               return '🟠 Orange Money';
      case 'MTN_MOBILE_MONEY': return '🟡 MTN MoMo';
      default:                 return method;
    }
  }

  /// Icon emoji for each transaction type shown in the activity feed.
  String _txIcon(String type) {
    switch (type) {
      case 'TOP_UP':      return '💳';   // ← wallet top-up (pre-paid credit)
      case 'TRIP_FARE':   return '🚗';
      case 'COMMISSION':  return '📤';
      case 'BONUS_TRIP':  return '⭐';
      case 'BONUS_QUEST': return '🏆';
      case 'ADJUSTMENT':  return '✏️';
      case 'REFUND':      return '↩️';
      case 'PAYOUT':      return '💸';
      default:            return '💰';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PAYOUT REQUEST BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════

class _PayoutRequestSheet extends StatefulWidget {
  final int          availableBalance;
  final VoidCallback onSuccess;

  const _PayoutRequestSheet({
    required this.availableBalance,
    required this.onSuccess,
  });

  @override
  State<_PayoutRequestSheet> createState() => _PayoutRequestSheetState();
}

class _PayoutRequestSheetState extends State<_PayoutRequestSheet> {
  final _amountController = TextEditingController();
  final _noteController   = TextEditingController();
  String  _selectedMethod = 'CASH';
  bool    _loading        = false;
  String? _error;

  final _methods = [
    {'value': 'CASH', 'label': 'Cash',         'icon': '💵', 'subtitle': 'Collect at office'},
    {'value': 'MOMO', 'label': 'MTN MoMo',     'icon': '🟡', 'subtitle': 'Sent to your phone'},
    {'value': 'OM',   'label': 'Orange Money',  'icon': '🟠', 'subtitle': 'Sent to your phone'},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    final raw    = _amountController.text.trim();
    if (raw.isEmpty) { setState(() => _error = 'Please enter an amount.'); return; }

    final amount = int.tryParse(raw);
    if (amount == null || amount <= 0) { setState(() => _error = 'Enter a valid amount.'); return; }

    if (amount > widget.availableBalance) {
      setState(() => _error = 'Amount exceeds your available balance of ${_fmt(widget.availableBalance)}.');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await _EarningsApi.requestPayout(
        amount:        amount,
        paymentMethod: _selectedMethod,
        note:          _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (!mounted) return;

      if (res['success'] == true) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         const Text(
            'Payout request submitted! We\'ll process it shortly.',
            style:          TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w600),
          ),
          backgroundColor: _kGreen,
          behavior:        SnackBarBehavior.floating,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        setState(() { _error = res['message'] ?? 'Something went wrong.'; _loading = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Network error. Please check your connection.'; _loading = false; });
    }
  }

  String _fmt(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M XAF';
    if (amount >= 1000)    return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K XAF';
    return '$amount XAF';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color:        Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin:      const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration:  BoxDecoration(
                  color:        Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Request Payout',
              style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 22, fontWeight: FontWeight.w700, color: _kWhite),
            ),
            const SizedBox(height: 4),
            Text(
              'Available: ${_fmt(widget.availableBalance)}',
              style: const TextStyle(fontFamily: 'Quicksand', fontSize: 13, color: _kGold, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            const Text('Amount (XAF)', style: TextStyle(fontFamily: 'Quicksand', fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
              child: Row(
                children: [
                  const Padding(padding: EdgeInsets.only(left: 16), child: Text('XAF', style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 16, color: _kGold, fontWeight: FontWeight.w700))),
                  Expanded(
                    child: TextField(
                      controller:        _amountController,
                      keyboardType:      TextInputType.number,
                      inputFormatters:   [FilteringTextInputFormatter.digitsOnly],
                      style:             const TextStyle(fontFamily: 'LeagueSpartan', fontSize: 24, fontWeight: FontWeight.w700, color: _kWhite),
                      decoration: const InputDecoration(
                        hintText:       '0',
                        hintStyle:      TextStyle(fontFamily: 'LeagueSpartan', fontSize: 24, color: Color(0xFF333333), fontWeight: FontWeight.w700),
                        border:         InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _amountController.text = widget.availableBalance.toString(),
                    child: Container(
                      margin:      const EdgeInsets.only(right: 12),
                      padding:     const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration:  BoxDecoration(color: _kGold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: const Text('MAX', style: TextStyle(fontFamily: 'Quicksand', fontSize: 11, fontWeight: FontWeight.w700, color: _kGold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Payment Method', style: TextStyle(fontFamily: 'Quicksand', fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey)),
            const SizedBox(height: 10),
            ..._methods.map((m) {
              final isSelected = _selectedMethod == m['value'];
              return GestureDetector(
                onTap: () => setState(() => _selectedMethod = m['value']!),
                child: AnimatedContainer(
                  duration:    const Duration(milliseconds: 180),
                  margin:      const EdgeInsets.only(bottom: 8),
                  padding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration:  BoxDecoration(
                    color:        isSelected ? _kGold.withOpacity(0.1) : _kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? _kGold : Colors.white.withOpacity(0.06), width: isSelected ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      Text(m['icon']!, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['label']!, style: TextStyle(fontFamily: 'Quicksand', fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? _kGold : _kWhite)),
                            Text(m['subtitle']!, style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey)),
                          ],
                        ),
                      ),
                      if (isSelected) const Icon(Icons.check_circle_rounded, color: _kGold, size: 20),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text('Note (optional)', style: TextStyle(fontFamily: 'Quicksand', fontSize: 13, fontWeight: FontWeight.w600, color: _kGrey)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
              child: TextField(
                controller: _noteController,
                maxLines:   2,
                style:      const TextStyle(fontFamily: 'Quicksand', fontSize: 13, color: _kWhite),
                decoration: const InputDecoration(
                  hintText:       'Any message for the accountant...',
                  hintStyle:      TextStyle(color: Color(0xFF444444), fontSize: 13),
                  border:         InputBorder.none,
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Container(
                padding:     const EdgeInsets.all(12),
                decoration:  BoxDecoration(color: _kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _kRed.withOpacity(0.3))),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: _kRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(fontFamily: 'Quicksand', fontSize: 12, color: _kRed))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            GestureDetector(
              onTap: _loading ? null : _submit,
              child: AnimatedContainer(
                duration:    const Duration(milliseconds: 200),
                width:       double.infinity,
                padding:     const EdgeInsets.symmetric(vertical: 16),
                decoration:  BoxDecoration(color: _loading ? _kGold.withOpacity(0.5) : _kGold, borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: _kBlack, strokeWidth: 2.5))
                      : const Text('Submit Request', style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 17, fontWeight: FontWeight.w700, color: _kBlack)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
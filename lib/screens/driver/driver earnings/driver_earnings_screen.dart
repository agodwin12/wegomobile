// lib/screens/driver/earnings/driver_earnings_screen.dart
//
// Full driver earnings screen with 3 tabs:
//   Overview  — balance hero, period stats, quest progress cards
//   Trips     — paginated trip receipts with fare breakdown
//   Activity  — wallet transaction ledger
//
// Plugs into driver_navigation_wrapper.dart at index 2

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;



import '../../../core/config.dart';

// ═══════════════════════════════════════════════════════════════════════
// BRAND CONSTANTS
// ═══════════════════════════════════════════════════════════════════════

const _kBlack  = Color(0xFF0A0A0A);
const _kGold   = Color(0xFFFFDC71);
const _kGoldDark = Color(0xFFD4A800);
const _kCard   = Color(0xFF181818);
const _kCardAlt= Color(0xFF222222);
const _kWhite  = Colors.white;
const _kGrey   = Color(0xFFA9A9A9);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);

// ═══════════════════════════════════════════════════════════════════════
// API SERVICE (inline — no separate file needed)
// ═══════════════════════════════════════════════════════════════════════

class _EarningsApi {
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {
      'Content-Type':  'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> getSummary() async {
    final res = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/earnings/driver/summary'),
      headers: await _headers(),
    );
    return json.decode(res.body);
  }

  static Future<Map<String, dynamic>> getTrips({
    int page = 1,
    String period = 'week',
  }) async {
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
      Uri.parse('${AppConfig.apiBaseUrl}/earnings/driver/activity?page=$page&limit=30&period=$period&type=$type'),
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

  // ── Summary state ─────────────────────────────────────────────────
  Map<String, dynamic>? _summary;
  bool _summaryLoading = true;
  String? _summaryError;

  // ── Quests state ──────────────────────────────────────────────────
  List<dynamic> _quests = [];
  bool _questsLoading = true;

  // ── Trips state ───────────────────────────────────────────────────
  List<dynamic> _trips      = [];
  bool _tripsLoading        = true;
  bool _tripsLoadingMore    = false;
  int  _tripsPage           = 1;
  int  _tripsTotalPages     = 1;
  String _tripsPeriod       = 'week';

  // ── Activity state ────────────────────────────────────────────────
  List<dynamic> _activity      = [];
  bool _activityLoading        = true;
  bool _activityLoadingMore    = false;
  int  _activityPage           = 1;
  int  _activityTotalPages     = 1;
  String _activityPeriod       = 'all';
  Map<String, dynamic>? _activityPeriodSummary;

  // ── Scroll controllers for load-more ─────────────────────────────
  final ScrollController _tripsScroll    = ScrollController();
  final ScrollController _activityScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChange);

    _tripsScroll.addListener(_onTripsScroll);
    _activityScroll.addListener(_onActivityScroll);

    _loadSummary();
    _loadQuests();
    _loadTrips(reset: true);
    _loadActivity(reset: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tripsScroll.dispose();
    _activityScroll.dispose();
    super.dispose();
  }

  void _onTabChange() {
    if (!_tabController.indexIsChanging) return;
    // Refresh data when switching to a tab that had an error
    if (_tabController.index == 0 && _summaryError != null) _loadSummary();
  }

  // ── Loaders ─────────────────────────────────────────────────────

  Future<void> _loadSummary() async {
    if (!mounted) return;
    setState(() { _summaryLoading = true; _summaryError = null; });
    try {
      final res = await _EarningsApi.getSummary();
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() { _summary = res['data']; _summaryLoading = false; });
      } else {
        setState(() { _summaryError = res['message'] ?? 'Failed to load'; _summaryLoading = false; });
      }
    } catch (e) {
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
      if (res['success'] == true) {
        setState(() { _quests = res['data']['quests'] ?? []; _questsLoading = false; });
      } else {
        setState(() => _questsLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _questsLoading = false);
    }
  }

  Future<void> _loadTrips({ bool reset = false }) async {
    if (_tripsLoading && !reset) return;
    if (!mounted) return;

    if (reset) {
      setState(() { _tripsLoading = true; _trips = []; _tripsPage = 1; });
    } else {
      setState(() => _tripsLoadingMore = true);
    }

    try {
      final res = await _EarningsApi.getTrips(page: _tripsPage, period: _tripsPeriod);
      if (!mounted) return;
      if (res['success'] == true) {
        final data       = res['data'];
        final pagination = data['pagination'] ?? {};
        setState(() {
          _trips.addAll(data['receipts'] ?? []);
          _tripsTotalPages  = pagination['totalPages'] ?? 1;
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

  Future<void> _loadActivity({ bool reset = false }) async {
    if (_activityLoading && !reset) return;
    if (!mounted) return;

    if (reset) {
      setState(() { _activityLoading = true; _activity = []; _activityPage = 1; });
    } else {
      setState(() => _activityLoadingMore = true);
    }

    try {
      final res = await _EarningsApi.getActivity(page: _activityPage, period: _activityPeriod);
      if (!mounted) return;
      if (res['success'] == true) {
        final data       = res['data'];
        final pagination = data['pagination'] ?? {};
        setState(() {
          _activity.addAll(data['transactions'] ?? []);
          _activityTotalPages      = pagination['totalPages'] ?? 1;
          _activityPeriodSummary   = data['periodSummary'];
          _activityLoading         = false;
          _activityLoadingMore     = false;
        });
      } else {
        setState(() { _activityLoading = false; _activityLoadingMore = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _activityLoading = false; _activityLoadingMore = false; });
    }
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

  // ═════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBlack,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor:    _kBlack,
            pinned:             true,
            floating:           false,
            expandedHeight:     _summaryLoading ? 200 : 260,
            collapsedHeight:    60,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _buildHeroHeader(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _buildTabBar(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildTripsTab(),
            _buildActivityTab(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // HERO HEADER — balance + period stats
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [Color(0xFF111111), _kBlack],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Earnings',
                    style: TextStyle(
                      fontFamily:  'LeagueSpartan',
                      fontSize:    28,
                      fontWeight:  FontWeight.w700,
                      color:       _kWhite,
                      letterSpacing: -0.5,
                    ),
                  ),
                  // Refresh button
                  GestureDetector(
                    onTap: () {
                      _loadSummary();
                      _loadQuests();
                    },
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.refresh_rounded, color: _kGold, size: 20),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Balance card
              if (_summaryLoading)
                _buildShimmerBalance()
              else if (_summaryError != null)
                _buildErrorBalance()
              else
                _buildBalanceCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final s = _summary ?? {};
    final balance     = s['balance']     ?? 0;
    final todayNet    = s['today']?['net']  ?? 0;
    final todayTrips  = s['today']?['trips'] ?? 0;
    final weekNet     = s['week']?['net']   ?? 0;
    final weekTrips   = s['week']?['trips'] ?? 0;
    final monthNet    = s['month']?['net']  ?? 0;
    final currency    = s['currency'] ?? 'XAF';
    final isFrozen    = s['walletStatus'] == 'FROZEN';

    return Column(
      children: [
        // Main balance
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: isFrozen
                  ? [const Color(0xFF2A1A00), const Color(0xFF1A1000)]
                  : [const Color(0xFF1A1500), const Color(0xFF111100)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFrozen ? Colors.orange.withOpacity(0.4) : _kGold.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isFrozen ? '🔒 Wallet Frozen' : 'Available Balance',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                      color:      _kGrey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        _kGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      currency,
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize:   10,
                        fontWeight: FontWeight.w700,
                        color:      _kGold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatAmount(balance),
                style: TextStyle(
                  fontFamily:  'LeagueSpartan',
                  fontSize:    36,
                  fontWeight:  FontWeight.w800,
                  color:       isFrozen ? Colors.orange : _kGold,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Period stats row
        Row(
          children: [
            Expanded(child: _buildStatChip('Today', todayNet, todayTrips, 'trips')),
            const SizedBox(width: 8),
            Expanded(child: _buildStatChip('This Week', weekNet, weekTrips, 'trips')),
            const SizedBox(width: 8),
            Expanded(child: _buildStatChip('This Month', monthNet, null, null)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, dynamic amount, dynamic count, String? countLabel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontSize:   10,
              color:      _kGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatAmount(amount),
            style: const TextStyle(
              fontFamily:  'LeagueSpartan',
              fontSize:    15,
              fontWeight:  FontWeight.w700,
              color:       _kWhite,
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

  Widget _buildShimmerBalance() {
    return Container(
      height:      130,
      decoration:  BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _kGold, strokeWidth: 2),
      ),
    );
  }

  Widget _buildErrorBalance() {
    return Container(
      padding:     const EdgeInsets.all(20),
      decoration:  BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _kRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _summaryError ?? 'Failed to load',
              style: const TextStyle(color: _kGrey, fontFamily: 'Quicksand', fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: _loadSummary,
            child: const Text(
              'Retry',
              style: TextStyle(color: _kGold, fontFamily: 'Quicksand', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // TAB BAR
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: _kBlack,
      child: TabBar(
        controller:           _tabController,
        labelColor:           _kGold,
        unselectedLabelColor: _kGrey,
        indicatorColor:       _kGold,
        indicatorWeight:      2.5,
        indicatorSize:        TabBarIndicatorSize.label,
        labelStyle:   const TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Trips'),
          Tab(text: 'Activity'),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // TAB 1: OVERVIEW
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      color:           _kGold,
      backgroundColor: _kCard,
      onRefresh: () async {
        await Future.wait([_loadSummary(), _loadQuests()]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lifetime stats
            if (_summary != null) _buildLifetimeStats(),
            const SizedBox(height: 24),

            // Quests section
            Row(
              children: [
                const Text(
                  'Active Quests',
                  style: TextStyle(
                    fontFamily:  'LeagueSpartan',
                    fontSize:    20,
                    fontWeight:  FontWeight.w700,
                    color:       _kWhite,
                  ),
                ),
                const Spacer(),
                if (_questsLoading)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(color: _kGold, strokeWidth: 1.5),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            if (_questsLoading)
              ..._buildQuestShimmers()
            else if (_quests.isEmpty)
              _buildEmptyQuests()
            else
              ..._quests.map((q) => _buildQuestCard(q)),
          ],
        ),
      ),
    );
  }

  Widget _buildLifetimeStats() {
    final s            = _summary!;
    final totalEarned  = s['totalEarned']     ?? 0;
    final commission   = s['totalCommission'] ?? 0;
    final bonuses      = s['totalBonuses']    ?? 0;
    final payouts      = s['totalPayouts']    ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lifetime Summary',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize:   12,
              color:      _kGrey,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildLifetimeStat('Total Earned',  totalEarned, _kGold)),
              const SizedBox(width: 16),
              Expanded(child: _buildLifetimeStat('Commission',    commission,  _kRed)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildLifetimeStat('Bonuses',       bonuses,     _kGreen)),
              const SizedBox(width: 16),
              Expanded(child: _buildLifetimeStat('Paid Out',      payouts,     _kGrey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifetimeStat(String label, dynamic amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey)),
        const SizedBox(height: 4),
        Text(
          _formatAmount(amount),
          style: TextStyle(
            fontFamily:  'LeagueSpartan',
            fontSize:    18,
            fontWeight:  FontWeight.w700,
            color:       color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestCard(Map<String, dynamic> q) {
    final progress  = (q['progressPercent'] as num?)?.toDouble() ?? 0.0;
    final completed = q['isCompleted'] == true;
    final emoji     = q['iconEmoji']   ?? '🏆';
    final name      = q['name']        ?? '';
    final current   = q['currentMetric'] ?? 0;
    final target    = q['targetValue']   ?? 1;
    final bonus     = q['bonusAmount']   ?? 0;
    final unit      = q['metricUnit']    ?? 'trips';
    final remaining = q['remaining']     ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFF0A1A0A) : _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed
              ? _kGreen.withOpacity(0.4)
              : _kGold.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily:  'LeagueSpartan',
                        fontSize:    15,
                        fontWeight:  FontWeight.w700,
                        color:       _kWhite,
                      ),
                    ),
                    Text(
                      completed
                          ? '✅ Completed!'
                          : '$remaining $unit remaining',
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        completed ? _kGreen.withOpacity(0.15) : _kGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${_formatAmount(bonus)}',
                  style: TextStyle(
                    fontFamily:  'LeagueSpartan',
                    fontSize:    13,
                    fontWeight:  FontWeight.w700,
                    color:       completed ? _kGreen : _kGold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            (progress / 100).clamp(0.0, 1.0),
              backgroundColor:  Colors.white.withOpacity(0.07),
              valueColor:       AlwaysStoppedAnimation(
                completed ? _kGreen : _kGold,
              ),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current / $target $unit',
                style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey),
              ),
              Text(
                '${progress.toInt()}%',
                style: TextStyle(
                  fontFamily:  'Quicksand',
                  fontSize:    11,
                  fontWeight:  FontWeight.w700,
                  color:       completed ? _kGreen : _kGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQuestShimmers() {
    return List.generate(2, (_) => Container(
      height:  100,
      margin:  const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(16),
      ),
    ));
  }

  Widget _buildEmptyQuests() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          children: [
            Text('🎯', style: TextStyle(fontSize: 32)),
            SizedBox(height: 8),
            Text(
              'No active quests right now',
              style: TextStyle(fontFamily: 'Quicksand', color: _kGrey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // TAB 2: TRIPS
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildTripsTab() {
    return Column(
      children: [
        // Period filter
        _buildPeriodFilter(
          selected: _tripsPeriod,
          onSelect: (p) {
            setState(() { _tripsPeriod = p; });
            _loadTrips(reset: true);
          },
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
              controller:  _tripsScroll,
              padding:     const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount:   _trips.length + (_tripsLoadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _trips.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child:   Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)),
                  );
                }
                return _buildTripReceiptCard(_trips[i]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripReceiptCard(Map<String, dynamic> r) {
    final gross      = r['grossFare']        ?? 0;
    final commission = r['commissionAmount'] ?? 0;
    final bonuses    = r['bonusTotal']       ?? 0;
    final net        = r['driverNet']        ?? 0;
    final method     = r['paymentMethod']    ?? 'CASH';
    final pickup     = r['trip']?['pickupAddress']  ?? 'Pickup';
    final dropoff    = r['trip']?['dropoffAddress'] ?? 'Dropoff';
    final date       = _formatDate(r['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kGold.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car, color: _kGold, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickup,
                      style: const TextStyle(
                        fontFamily:  'Quicksand',
                        fontSize:    12,
                        color:       _kWhite,
                        fontWeight:  FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '→ $dropoff',
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize:   11,
                        color:      _kGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatAmount(net),
                    style: const TextStyle(
                      fontFamily:  'LeagueSpartan',
                      fontSize:    18,
                      fontWeight:  FontWeight.w800,
                      color:       _kGold,
                    ),
                  ),
                  Text(
                    date,
                    style: const TextStyle(fontFamily: 'Quicksand', fontSize: 10, color: _kGrey),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 12),

          // Breakdown row
          Row(
            children: [
              Expanded(child: _buildBreakdownItem('Fare',       _formatAmount(gross),      _kGrey)),
              Expanded(child: _buildBreakdownItem('Commission', '-${_formatAmount(commission)}', _kRed)),
              Expanded(child: _buildBreakdownItem('Bonus',      '+${_formatAmount(bonuses)}',   _kGreen)),
              Expanded(child: _buildBreakdownItem('Net',        _formatAmount(net),         _kGold)),
            ],
          ),

          const SizedBox(height: 8),

          // Payment method badge
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _methodLabel(method),
                style: const TextStyle(fontFamily: 'Quicksand', fontSize: 10, color: _kGrey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Quicksand', fontSize: 10, color: _kGrey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontFamily: 'Quicksand', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // TAB 3: ACTIVITY
  // ═════════════════════════════════════════════════════════════════════

  Widget _buildActivityTab() {
    return Column(
      children: [
        // Period filter + period summary
        _buildPeriodFilter(
          selected: _activityPeriod,
          onSelect: (p) {
            setState(() { _activityPeriod = p; });
            _loadActivity(reset: true);
          },
        ),

        // Period summary bar
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
              controller:  _activityScroll,
              padding:     const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount:   _activity.length + (_activityLoadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _activity.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child:   Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)),
                  );
                }
                return _buildTransactionRow(_activity[i]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSummaryBar() {
    final ps = _activityPeriodSummary!;
    final credits = ps['totalCredits'] ?? 0;
    final debits  = ps['totalDebits']  ?? 0;
    final net     = ps['net']          ?? 0;
    final isPos   = (net as num) >= 0;

    return Container(
      margin:  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:        _kCardAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildMiniStat('Credits', _formatAmount(credits), _kGreen)),
          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.07)),
          Expanded(child: _buildMiniStat('Debits',  _formatAmount(debits),  _kRed)),
          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.07)),
          Expanded(child: _buildMiniStat('Net', _formatAmount(net.abs()), isPos ? _kGold : _kRed)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Quicksand', fontSize: 10, color: _kGrey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _buildTransactionRow(Map<String, dynamic> tx) {
    final type      = tx['type']        ?? '';
    final amount    = tx['amount']      ?? 0;
    final label     = tx['label']       ?? type;
    final desc      = tx['description'] ?? label;
    final isCredit  = tx['isCredit']    == true;
    final date      = _formatDate(tx['createdAt']);
    final icon      = _txIcon(type);
    final color     = isCredit ? _kGreen : _kRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily:  'Quicksand',
                    fontSize:    13,
                    fontWeight:  FontWeight.w700,
                    color:       _kWhite,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${_formatAmount((amount as num).abs())}',
                style: TextStyle(
                  fontFamily:  'LeagueSpartan',
                  fontSize:    15,
                  fontWeight:  FontWeight.w800,
                  color:       color,
                ),
              ),
              Text(date, style: const TextStyle(fontFamily: 'Quicksand', fontSize: 10, color: _kGrey)),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═════════════════════════════════════════════════════════════════════

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

    return Container(
      height:  44,
      margin:  const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: periods.map((p) {
          final isSelected = selected == p.$1;
          return GestureDetector(
            onTap: () => onSelect(p.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin:   const EdgeInsets.only(right: 8),
              padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:        isSelected ? _kGold : _kCard,
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(
                  color: isSelected ? _kGold : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                p.$2,
                style: TextStyle(
                  fontFamily:  'Quicksand',
                  fontSize:    12,
                  fontWeight:  FontWeight.w700,
                  color:       isSelected ? _kBlack : _kGrey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCenteredLoader() {
    return const Center(
      child: CircularProgressIndicator(color: _kGold, strokeWidth: 2),
    );
  }

  Widget _buildEmptyState(String message, String emoji) {
    return Center(
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
  }

  // ═════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════════

  String _formatAmount(dynamic amount) {
    final val = (amount as num?)?.toInt() ?? 0;
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000)    return '${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}K';
    return '$val XAF';
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _methodLabel(String method) {
    switch (method.toUpperCase()) {
      case 'CASH':              return '💵 Cash';
      case 'ORANGE_MONEY':      return '🟠 Orange Money';
      case 'MTN_MOBILE_MONEY':  return '🟡 MTN MoMo';
      default:                  return method;
    }
  }

  String _txIcon(String type) {
    switch (type) {
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
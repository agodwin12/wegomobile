import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:lottie/lottie.dart';
import '../../../core/config.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/payment/payment_status_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _Wallet {
  final double balance;
  final double availableBalance;
  final double reservedBalance;
  final double pendingWithdrawal;
  final double totalToppedUp;
  final double totalEarned;
  final double totalCommissionPaid;
  final double outstandingCommission;
  final String status;
  final bool canAcceptJobs;
  final String? frozenReason;

  const _Wallet({
    required this.balance,
    required this.availableBalance,
    required this.reservedBalance,
    required this.pendingWithdrawal,
    required this.totalToppedUp,
    required this.totalEarned,
    required this.totalCommissionPaid,
    required this.outstandingCommission,
    required this.status,
    required this.canAcceptJobs,
    this.frozenReason,
  });

  factory _Wallet.empty() => const _Wallet(
    balance: 0,
    availableBalance: 0,
    reservedBalance: 0,
    pendingWithdrawal: 0,
    totalToppedUp: 0,
    totalEarned: 0,
    totalCommissionPaid: 0,
    outstandingCommission: 0,
    status: 'active',
    canAcceptJobs: false,
  );

  factory _Wallet.fromJson(Map<String, dynamic> j) {
    double d(String k1, [String? k2]) =>
        ((j[k1] ?? (k2 != null ? j[k2] : null)) as num? ?? 0).toDouble();
    return _Wallet(
      balance:               d('balance'),
      availableBalance:      d('available_balance', 'availableBalance'),
      reservedBalance:       d('reserved_balance',  'reservedBalance'),
      pendingWithdrawal:     d('pending_withdrawal', 'pendingWithdrawal'),
      totalToppedUp:         d('total_topped_up',   'totalToppedUp'),
      totalEarned:           d('total_earned',      'totalEarned'),
      totalCommissionPaid:   d('total_commission_paid',   'totalCommissionPaid'),
      outstandingCommission: d('outstanding_commission',  'outstandingCommission'),
      status:        j['status']         as String? ?? 'active',
      canAcceptJobs: j['can_accept_jobs'] as bool?  ??
          j['canAcceptJobs']  as bool?   ?? false,
      frozenReason:  j['frozen_reason']  as String?,
    );
  }
}

// ── Top-up status ─────────────────────────────────────────────────────────────

enum _TopUpStatus {
  pending,
  under_review,
  confirmed,
  credited,
  rejected,
  campay_pending,
  campay_failed;

  static _TopUpStatus fromString(String s) {
    switch (s) {
      case 'under_review':   return _TopUpStatus.under_review;
      case 'confirmed':      return _TopUpStatus.confirmed;
      case 'credited':       return _TopUpStatus.credited;
      case 'rejected':       return _TopUpStatus.rejected;
      case 'campay_pending': return _TopUpStatus.campay_pending;
      case 'campay_failed':  return _TopUpStatus.campay_failed;
      default:               return _TopUpStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case _TopUpStatus.pending:        return 'Pending';
      case _TopUpStatus.under_review:   return 'Under Review';
      case _TopUpStatus.confirmed:      return 'Confirmed';
      case _TopUpStatus.credited:       return 'Credited';
      case _TopUpStatus.rejected:       return 'Rejected';
      case _TopUpStatus.campay_pending: return 'Awaiting Payment';
      case _TopUpStatus.campay_failed:  return 'Payment Failed';
    }
  }

  Color get color {
    switch (this) {
      case _TopUpStatus.pending:        return AppColors.warning;
      case _TopUpStatus.under_review:   return AppColors.info;
      case _TopUpStatus.confirmed:      return AppColors.primaryGold;
      case _TopUpStatus.credited:       return AppColors.success;
      case _TopUpStatus.rejected:       return AppColors.error;
      case _TopUpStatus.campay_pending: return AppColors.info;
      case _TopUpStatus.campay_failed:  return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case _TopUpStatus.pending:        return Icons.hourglass_empty_rounded;
      case _TopUpStatus.under_review:   return Icons.manage_search_rounded;
      case _TopUpStatus.confirmed:      return Icons.verified_rounded;
      case _TopUpStatus.credited:       return Icons.check_circle_rounded;
      case _TopUpStatus.rejected:       return Icons.cancel_rounded;
      case _TopUpStatus.campay_pending: return Icons.phone_android_rounded;
      case _TopUpStatus.campay_failed:  return Icons.error_outline_rounded;
    }
  }

  bool get isTerminal => [
    _TopUpStatus.credited,
    _TopUpStatus.rejected,
    _TopUpStatus.campay_failed,
  ].contains(this);
}

// ── Top-up record ─────────────────────────────────────────────────────────────

class _TopUp {
  final int           id;
  final String        topupCode;
  final double        amount;
  final String        paymentChannel;
  final String        channelLabel;
  final _TopUpStatus  status;
  final String?       statusLabel;
  final bool          isCampayFlow;
  final String?       campayRef;
  final String?       proofUrl;
  final String?       paymentReference;
  final String?       driverNote;
  final String?       rejectionReason;
  final double?       balanceBeforeCredit;
  final double?       balanceAfterCredit;
  final DateTime      submittedAt;
  final DateTime?     creditedAt;
  final DateTime?     rejectedAt;

  const _TopUp({
    required this.id,
    required this.topupCode,
    required this.amount,
    required this.paymentChannel,
    required this.channelLabel,
    required this.status,
    this.statusLabel,
    required this.isCampayFlow,
    this.campayRef,
    this.proofUrl,
    this.paymentReference,
    this.driverNote,
    this.rejectionReason,
    this.balanceBeforeCredit,
    this.balanceAfterCredit,
    required this.submittedAt,
    this.creditedAt,
    this.rejectedAt,
  });

  factory _TopUp.fromJson(Map<String, dynamic> j) => _TopUp(
    id:             j['id']          as int,
    topupCode:      j['topup_code']  as String? ?? '—',
    amount:         (j['amount']     as num? ?? 0).toDouble(),
    paymentChannel: j['payment_channel'] as String? ?? '',
    channelLabel:   j['channel_label']   as String? ??
        j['payment_channel'] as String? ?? '',
    status:      _TopUpStatus.fromString(j['status'] as String? ?? 'pending'),
    statusLabel: j['status_label'] as String?,
    isCampayFlow: j['is_campay_flow'] as bool? ?? false,
    campayRef:    j['campay_ref']    as String?,
    proofUrl:     j['proof_url']     as String?,
    paymentReference: j['payment_reference'] as String?,
    driverNote:       j['driver_note']        as String?,
    rejectionReason:  j['rejection_reason']   as String?,
    balanceBeforeCredit: (j['balance_before_credit'] as num?)?.toDouble(),
    balanceAfterCredit:  (j['balance_after_credit']  as num?)?.toDouble(),
    submittedAt: DateTime.tryParse(j['submitted_at'] as String? ?? '') ??
        DateTime.now(),
    creditedAt:  j['credited_at'] != null
        ? DateTime.tryParse(j['credited_at'] as String)
        : null,
    rejectedAt:  j['rejected_at'] != null
        ? DateTime.tryParse(j['rejected_at'] as String)
        : null,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryWalletScreen extends StatefulWidget {
  /// Pass [initialTab] = 1 to open directly on the "Top Up" tab.
  final int       initialTab;
  final io.Socket? socket;

  const DeliveryWalletScreen({
    super.key,
    this.initialTab = 0,
    this.socket,
  });

  @override
  State<DeliveryWalletScreen> createState() => _DeliveryWalletScreenState();
}

class _DeliveryWalletScreenState extends State<DeliveryWalletScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabs;
  String _accessToken = '';

  // ── Wallet ────────────────────────────────────────────────────────────────
  _Wallet _wallet        = _Wallet.empty();
  bool    _loadingWallet = true;

  // ── History ───────────────────────────────────────────────────────────────
  final List<_TopUp> _topups       = [];
  bool _loadingHistory  = true;
  bool _historyHasMore  = true;
  int  _historyPage     = 1;
  static const int _historyLimit   = 20;
  final ScrollController _historyScroll = ScrollController();

  // ── Form state ────────────────────────────────────────────────────────────
  final _formKey     = GlobalKey<FormState>();
  final _amountCtrl  = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _noteCtrl    = TextEditingController();

  String _selectedChannel = 'mtn_mobile_money';
  bool   _submitting      = false;

  // ── CamPay waiting state ──────────────────────────────────────────────────
  // Non-null = show "Check your phone" screen
  _TopUp? _pendingCampayTopUp;
  String? _pendingUssdCode;
  bool    _campayConfirmed = false;   // set true when wallet:topped_up fires

  // ── Cash success state ────────────────────────────────────────────────────
  String? _cashSubmitCode;            // non-null = show cash submitted screen

  // ── Socket ────────────────────────────────────────────────────────────────
  io.Socket? _socket;

  // ── Channels ──────────────────────────────────────────────────────────────
  static const _channels = [
    {'value': 'mtn_mobile_money', 'label': 'MTN MoMo',      'emoji': '🟡'},
    {'value': 'orange_money',     'label': 'Orange Money',   'emoji': '🟠'},
    {'value': 'cash',             'label': 'Cash Deposit',   'emoji': '💵'},
  ];

  // ── Presets ───────────────────────────────────────────────────────────────
  static const _presets = [25, 100, 500, 1000, 5000, 25000];

  // ─────────────────────────────────────────────────────────────────────────
  // INIT / DISPOSE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
    _historyScroll.addListener(_onHistoryScroll);
    _socket = widget.socket;
    _init();
  }

  Future<void> _init() async {
    final prefs  = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token') ?? '';
    _listenSocket();
    await Future.wait([_fetchWallet(), _fetchHistory(reset: true)]);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _historyScroll.dispose();
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCKET — wallet:topped_up
  // ─────────────────────────────────────────────────────────────────────────

  void _listenSocket() {
    _socket?.on('wallet:topped_up', (data) {
      if (!mounted) return;
      debugPrint('🔔 [WALLET] wallet:topped_up received');
      setState(() => _campayConfirmed = true);
      // Refresh wallet balance and history silently
      _fetchWallet();
      _fetchHistory(reset: true);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NETWORK — wallet
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _fetchWallet() async {
    if (_accessToken.isEmpty) return;
    if (mounted) setState(() => _loadingWallet = true);
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/driver/wallet'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final raw  = (body['data'] ?? body['wallet']) as Map<String, dynamic>?;
        if (raw != null && mounted) {
          setState(() => _wallet = _Wallet.fromJson(raw));
        }
      }
    } catch (e) {
      debugPrint('❌ [WALLET] fetchWallet: $e');
    }
    if (mounted) setState(() => _loadingWallet = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NETWORK — history
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _fetchHistory({bool reset = false}) async {
    if (_accessToken.isEmpty) return;
    if (!_historyHasMore && !reset) return;

    if (reset) {
      _historyPage    = 1;
      _historyHasMore = true;
      _topups.clear();
    }

    if (mounted) setState(() => _loadingHistory = true);
    try {
      final res = await http.get(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/deliveries/driver/wallet/topup'
                '?page=$_historyPage&limit=$_historyLimit'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body  = jsonDecode(res.body) as Map<String, dynamic>;
        final data  = body['data'] as Map<String, dynamic>?;
        final items = ((data?['topups'] as List?) ?? [])
            .map((e) => _TopUp.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _topups.addAll(items);
            _historyHasMore = items.length == _historyLimit;
            _historyPage++;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [WALLET] fetchHistory: $e');
    }
    if (mounted) setState(() => _loadingHistory = false);
  }

  void _onHistoryScroll() {
    if (_historyScroll.position.pixels >
        _historyScroll.position.maxScrollExtent - 200) {
      if (_historyHasMore && !_loadingHistory) _fetchHistory();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NETWORK — submit top-up (routes by channel)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submitTopUp() async {
    if (!_formKey.currentState!.validate()) return;

    final isCampay = _selectedChannel != 'cash';

    // CamPay channels require a phone number
    if (isCampay && _phoneCtrl.text.trim().isEmpty) {
      _showSnack('Enter the mobile number to charge', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      if (isCampay) {
        await _initiateCampayTopUp();
      } else {
        await _submitCashTopUp();
      }
    } on TimeoutException {
      // A slow CamPay collect can exceed the client timeout while the charge is
      // still being set up server-side — the top-up record already exists. Don't
      // declare failure; tell the driver to watch for the PIN and refresh history.
      _showSnack(
        'Still processing — check your phone for the payment prompt. '
        'Your top-up will appear in history shortly.',
        isError: false,
      );
      if (mounted) _fetchHistory(reset: true);
    } catch (e) {
      _showSnack('Network error. Please try again.', isError: true);
    }

    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _initiateCampayTopUp() async {
    final res = await http.post(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/deliveries/driver/wallet/topup/initiate'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({
        'amount':          _amountCtrl.text.trim(),
        'payment_channel': _selectedChannel,
        'phone':           _phoneCtrl.text.trim(),
        if (_noteCtrl.text.trim().isNotEmpty) 'driver_note': _noteCtrl.text.trim(),
      }),
    ).timeout(const Duration(seconds: 90)); // generous — CamPay collect can be slow

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if ((res.statusCode == 200 || res.statusCode == 201) &&
        body['success'] == true) {
      final topUpJson = body['data'] as Map<String, dynamic>?;
      final topUp     = topUpJson != null ? _TopUp.fromJson(topUpJson) : null;
      final ussdCode  = body['ussd_code'] as String?;

      if (mounted) {
        setState(() {
          _pendingCampayTopUp = topUp;
          _pendingUssdCode    = ussdCode;
          _campayConfirmed    = false;
          // Reset form
          _amountCtrl.clear();
          _phoneCtrl.clear();
          _noteCtrl.clear();
        });
        _fetchHistory(reset: true);
      }
      return;
    }

    // Map CamPay error codes
    final code    = body['code']    as String?;
    final message = body['message'] as String? ?? 'Payment initiation failed';
    _showSnack(_campayErrorLabel(code, message), isError: true);
  }

  Future<void> _submitCashTopUp() async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/deliveries/driver/wallet/topup'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({
        'amount':     _amountCtrl.text.trim(),
        if (_noteCtrl.text.trim().isNotEmpty)
          'driver_note': _noteCtrl.text.trim(),
      }),
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if ((res.statusCode == 200 || res.statusCode == 201) &&
        body['success'] == true) {
      final code = (body['data'] as Map<String, dynamic>?)?['topup_code']
      as String?;
      if (mounted) {
        setState(() {
          _cashSubmitCode = code;
          _amountCtrl.clear();
          _noteCtrl.clear();
        });
        _fetchHistory(reset: true);
        _fetchWallet();
      }
      return;
    }

    _showSnack(body['message'] as String? ?? 'Submission failed', isError: true);
  }

  String _campayErrorLabel(String? code, String fallback) {
    switch (code) {
      case 'ER101': return 'Invalid phone number. Please check and try again.';
      case 'ER102': return 'This number is not supported. Use an MTN or Orange number.';
      case 'ER301': return 'Payment service temporarily unavailable. Try again shortly.';
      default:      return fallback;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Roboto')),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _fmt(double xaf) =>
      '${xaf.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} XAF';

  String _dateLabel(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0)
      return 'Today, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _resetTopUpForm() {
    setState(() {
      _pendingCampayTopUp = null;
      _pendingUssdCode    = null;
      _campayConfirmed    = false;
      _cashSubmitCode     = null;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: TabBarView(
          controller: _tabs,
          children: [
            _buildOverviewTab(),
            _buildTopUpTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 160,
      backgroundColor: AppColors.primaryDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () {
            _fetchWallet();
            _fetchHistory(reset: true);
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        indicatorColor: AppColors.primaryGold,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins', fontSize: 12),
        labelColor: AppColors.primaryGold,
        unselectedLabelColor: Colors.white54,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Top Up'),
          Tab(text: 'History'),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
        title: _loadingWallet
            ? const SizedBox.shrink()
            : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fmt(_wallet.availableBalance),
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryGold,
                    letterSpacing: -0.5)),
            Text(tr('agent.availableBalance'),
                style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5))),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2C)],
            ),
          ),
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 50, right: 20),
              child: Icon(Icons.account_balance_wallet_rounded,
                  size: 80,
                  color: AppColors.primaryGold.withOpacity(0.08)),
            ),
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TAB 1 — OVERVIEW
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    if (_loadingWallet) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold));
    }
    return RefreshIndicator(
      color: AppColors.primaryGold,
      onRefresh: _fetchWallet,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          if (_wallet.status != 'active') _buildFrozenBanner(),
          if (!_wallet.canAcceptJobs && _wallet.status == 'active')
            _buildLowBalanceBanner(),
          _buildBalanceGrid(),
          const SizedBox(height: 16),
          _buildTopUpCTA(),
          const SizedBox(height: 20),
          _buildRecentHistory(),
        ],
      ),
    );
  }

  Widget _buildFrozenBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.lock_rounded, color: AppColors.error, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Wallet ${_wallet.status}',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error)),
            if (_wallet.frozenReason != null)
              Text(_wallet.frozenReason!,
                  style: const TextStyle(
                      fontFamily: 'Roboto', fontSize: 11, color: AppColors.error)),
            const SizedBox(height: 4),
            Text(tr('agent.contactSupportResolve'),
                style: TextStyle(
                    fontFamily: 'Roboto', fontSize: 11, color: AppColors.error)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLowBalanceBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(children: [
        Text('⚠️', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('agent.tooLowAccept'),
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning)),
            const SizedBox(height: 3),
            Text(tr('agent.topUpToAccept'),
                style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    color: AppColors.warning,
                    height: 1.4)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _tabs.animateTo(1),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(tr('agent.topUpNow'),
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBalanceGrid() {
    final items = [
      ('💰', 'Available',          _wallet.availableBalance,      AppColors.success),
      ('🔒', 'Reserved',           _wallet.reservedBalance,       AppColors.warning),
      ('⏳', 'Pending Withdrawal', _wallet.pendingWithdrawal,     AppColors.info),
      ('📥', 'Total Topped Up',    _wallet.totalToppedUp,         AppColors.primaryGold),
      ('📈', 'Total Earned',       _wallet.totalEarned,           AppColors.success),
      ('🤝', 'Commission Paid',    _wallet.totalCommissionPaid,   AppColors.textSecondary),
    ];
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((item) {
        final (emoji, label, value, color) = item;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                          color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              Text(_fmt(value),
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopUpCTA() {
    return GestureDetector(
      onTap: () => _tabs.animateTo(1),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded,
                color: AppColors.primaryGold, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('agent.reloadWallet'),
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              Text(tr('agent.payMethods'),
                  style: TextStyle(
                      fontFamily: 'Roboto', fontSize: 11, color: Colors.white54)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: AppColors.primaryGold, size: 16),
        ]),
      ),
    );
  }

  Widget _buildRecentHistory() {
    if (_loadingHistory && _topups.isEmpty) {
      return Center(
          child: Padding(
              padding: EdgeInsets.all(20),
              child:
              CircularProgressIndicator(color: AppColors.primaryGold)));
    }
    if (_topups.isEmpty) return const SizedBox.shrink();

    final recent = _topups.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(tr('agent.recentRequests'),
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        GestureDetector(
          onTap: () => _tabs.animateTo(2),
          child: Text(tr('common.seeAll'),
              style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 10),
      ...recent.map(_buildTopUpTile),
    ]);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TAB 2 — TOP UP FORM
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildTopUpTab() {
    // 1. CamPay confirmed via socket
    if (_campayConfirmed) return _buildCampaySuccessScreen();

    // 2. CamPay initiated — waiting for phone PIN
    if (_pendingCampayTopUp != null) return _buildCampayWaitingScreen();

    // 3. Cash submitted successfully
    if (_cashSubmitCode != null) return _buildCashSubmitSuccessScreen();

    // 4. Normal form
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildChannelSelector(),
          const SizedBox(height: 20),
          _buildAmountField(),
          const SizedBox(height: 16),
          if (_selectedChannel != 'cash') ...[
            _buildPhoneField(),
            const SizedBox(height: 16),
          ],
          _buildNoteField(),
          const SizedBox(height: 28),
          _buildSubmitButton(),
          const SizedBox(height: 16),
          _buildPaymentNote(),
        ]),
      ),
    );
  }

  // ── CamPay waiting screen ──────────────────────────────────────────────────

  Widget _buildCampayWaitingScreen() {
    final topUp    = _pendingCampayTopUp!;
    final isMtn    = topUp.paymentChannel == 'mtn_mobile_money';
    final emoji    = isMtn ? '🟡' : '🟠';
    final opLabel  = isMtn ? 'MTN MoMo' : 'Orange Money';
    final color    = isMtn ? const Color(0xFFFFCC00) : const Color(0xFFFF6600);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Processing / waiting Lottie (loops until CamPay resolves)
          SizedBox(
            width: 150, height: 150,
            child: Lottie.asset(
              kPaymentPendingLottie,
              repeat: true,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.4), width: 2),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 40))),
              ),
            ),
          ),

          const SizedBox(height: 14),
          Text(tr('agent.checkPhone'),
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            '$opLabel will send you a USSD prompt.\n'
                'Enter your PIN to confirm the payment.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5),
          ),

          // Amount chip
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Text(_fmt(topUp.amount),
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success)),
          ),

          // USSD code if returned by operator
          if (_pendingUssdCode != null) ...[
            const SizedBox(height: 14),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Column(children: [
                Text(tr('agent.ussdCode'),
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10,
                        color: AppColors.info)),
                const SizedBox(height: 4),
                Text(_pendingUssdCode!,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.info,
                        letterSpacing: 2)),
              ]),
            ),
          ],

          const SizedBox(height: 24),

          // Pulse indicator — waiting
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: color),
            ),
            const SizedBox(width: 10),
            Text(tr('agent.waitingConfirm'),
                style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ]),

          const SizedBox(height: 8),
          Text('Ref: ${topUp.topupCode}',
              style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5)),

          const SizedBox(height: 28),

          // Try another amount button
          TextButton(
            onPressed: _resetTopUpForm,
            child: Text('Cancel / Try different amount',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }

  // ── CamPay confirmed screen ────────────────────────────────────────────────

  Widget _buildCampaySuccessScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Lottie.asset(
              kPaymentSuccessLottie,
              repeat: false,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.check_circle_rounded, color: AppColors.success, size: 70),
            ),
          ),
          const SizedBox(height: 12),
          Text(tr('agent.walletToppedUp'),
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Your payment was confirmed and the balance has been added to your wallet.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 24),
          // Updated balance pill
          if (!_loadingWallet)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Column(children: [
                Text(tr('agent.newBalance'),
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(_fmt(_wallet.availableBalance),
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success)),
              ]),
            ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () {
              _resetTopUpForm();
              _tabs.animateTo(0);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(tr('agent.viewWallet'),
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _resetTopUpForm,
            child: Text(tr('agent.topUpAgain'),
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  // ── Cash submitted screen ──────────────────────────────────────────────────

  Widget _buildCashSubmitSuccessScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 46),
          ),
          const SizedBox(height: 20),
          Text(tr('agent.requestSubmitted'),
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Your cash top-up request ($_cashSubmitCode) has been received.\n'
                'A WeGo agent will verify and credit your wallet shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () {
              _resetTopUpForm();
              _tabs.animateTo(2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(tr('agent.viewInHistory'),
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _resetTopUpForm,
            child: Text(tr('agent.submitAnother'),
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  // ── Form widgets ───────────────────────────────────────────────────────────

  Widget _buildChannelSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('payment.title'),
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      Row(
        children: _channels.map((ch) {
          final selected = _selectedChannel == ch['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedChannel = ch['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(
                    right: ch == _channels.last ? 0 : 8),
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryDark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: selected
                          ? AppColors.primaryGold
                          : AppColors.borderLight,
                      width: selected ? 2 : 1),
                  boxShadow: selected
                      ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                      : [],
                ),
                child: Column(children: [
                  (ch['value'] == 'mtn_mobile_money' || ch['value'] == 'orange_money')
                      ? Image.asset(
                          ch['value'] == 'mtn_mobile_money'
                              ? 'assets/images/momo.png'
                              : 'assets/images/om.png',
                          width: 26, height: 26, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Text(ch['emoji']!,
                              style: const TextStyle(fontSize: 22)),
                        )
                      : Text(ch['emoji']!, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 5),
                  Text(
                    ch['label']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.primaryGold
                            : AppColors.textSecondary,
                        height: 1.3),
                  ),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
      // CamPay badge
      if (_selectedChannel != 'cash') ...[
        const SizedBox(height: 8),
        Row(children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bolt_rounded,
                  color: AppColors.success, size: 12),
              SizedBox(width: 4),
              Text(tr('agent.instantNoScreenshot'),
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 10,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ],
    ]);
  }

  Widget _buildAmountField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Amount (XAF)',
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _presets.map((p) {
          final val      = p.toString();
          final selected = _amountCtrl.text == val;
          return GestureDetector(
            onTap: () => setState(() => _amountCtrl.text = val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        selected ? AppColors.primaryDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected
                        ? AppColors.primaryGold
                        : AppColors.borderLight),
              ),
              child: Text(
                p >= 1000
                    ? '${(p / 1000).toStringAsFixed(p % 1000 == 0 ? 0 : 1)}k'
                    : '$p',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.primaryGold
                        : AppColors.textSecondary),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _amountCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700),
        decoration: _inputDecoration('Enter amount', suffix: 'XAF'),
        validator: (v) {
          final n = int.tryParse(v?.trim() ?? '');
          if (n == null || n <= 0) return 'Enter a valid amount';
          if (n < 25) return 'Minimum top-up is 25 XAF';
          return null;
        },
      ),
    ]);
  }

  Widget _buildPhoneField() {
    final isMtn = _selectedChannel == 'mtn_mobile_money';
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      style: const TextStyle(fontFamily: 'Roboto', fontSize: 14),
      decoration: _inputDecoration(
        isMtn
            ? 'MTN number to charge (e.g. 670000000)'
            : 'Orange number to charge (e.g. 690000000)',
      ),
      validator: (v) {
        if (_selectedChannel == 'cash') return null;
        if (v == null || v.trim().isEmpty) return 'Phone number is required';
        final digits = v.trim().replaceAll(RegExp(r'\D'), '');
        if (digits.length != 9 && digits.length != 12) {
          return 'Enter 9 digits (670000000) or full format (237670000000)';
        }
        return null;
      },
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteCtrl,
      maxLines: 2,
      style: const TextStyle(fontFamily: 'Roboto', fontSize: 13),
      decoration: _inputDecoration('Note (optional)'),
    );
  }

  Widget _buildSubmitButton() {
    final isCampay = _selectedChannel != 'cash';
    final label    = isCampay ? 'Pay with Mobile Money' : 'Submit Cash Request';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submitTopUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.borderMedium,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _submitting
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isCampay ? Icons.phone_android_rounded : Icons.payments_outlined,
              size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _buildPaymentNote() {
    final isCampay = _selectedChannel != 'cash';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isCampay
                ? 'Tap Pay and enter your mobile money PIN when prompted on your phone. '
                'Your wallet will be credited instantly once the payment is confirmed.'
                : 'Submit this form after making your cash deposit at a WeGo office. '
                'A staff member will verify and credit your wallet within 30 minutes.',
            style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                color: AppColors.info,
                height: 1.5),
          ),
        ),
      ]),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TAB 3 — HISTORY
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildHistoryTab() {
    if (_loadingHistory && _topups.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold));
    }
    if (_topups.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_rounded,
              size: 52, color: AppColors.borderMedium),
          const SizedBox(height: 12),
          Text(tr('agent.noTopUps'),
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => _tabs.animateTo(1),
            child: Text(tr('agent.topUpNow'),
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryGold,
      onRefresh: () => _fetchHistory(reset: true),
      child: ListView.separated(
        controller: _historyScroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: _topups.length + (_historyHasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i == _topups.length) {
            return Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primaryGold)));
          }
          return _buildTopUpTile(_topups[i]);
        },
      ),
    );
  }

  // ── Shared tile ────────────────────────────────────────────────────────────

  Widget _buildTopUpTile(_TopUp t) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        // Main row
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: t.status.color.withOpacity(0.1),
                  shape: BoxShape.circle),
              child:
              Icon(t.status.icon, color: t.status.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(t.amount),
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: t.status.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              t.statusLabel ?? t.status.label,
                              style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: t.status.color),
                            ),
                          ),
                        ]),
                    const SizedBox(height: 3),
                    Text(
                      '${t.channelLabel}  ·  ${_dateLabel(t.submittedAt)}',
                      style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                  ]),
            ),
          ]),
        ),

        // Reference row
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(children: [
            Icon(Icons.tag_rounded,
                size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(t.topupCode,
                style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5)),
            // CamPay badge
            if (t.isCampayFlow) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(tr('agent.instant'),
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 9,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ),

        // Balance snapshot (credited)
        if (t.status == _TopUpStatus.credited &&
            t.balanceBeforeCredit != null &&
            t.balanceAfterCredit != null) ...[
          Container(height: 1, color: AppColors.borderLight),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Expanded(
                  child: _miniStat('Before',
                      _fmt(t.balanceBeforeCredit!), AppColors.textSecondary)),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: AppColors.borderMedium),
              Expanded(
                  child: _miniStat(
                      'After', _fmt(t.balanceAfterCredit!), AppColors.success)),
            ]),
          ),
        ],

        // Rejection / failure reason
        if ((t.status == _TopUpStatus.rejected ||
            t.status == _TopUpStatus.campay_failed) &&
            t.rejectionReason != null) ...[
          Container(height: 1, color: AppColors.borderLight),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.error),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(t.rejectionReason!,
                      style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          color: AppColors.error,
                          height: 1.4))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Column(children: [
    Text(value,
        style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis),
    Text(label,
        style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 9,
            color: AppColors.textSecondary)),
  ]);

  // ── Input decoration ───────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String hint, {String? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            color: AppColors.textSecondary),
        suffixText: suffix,
        suffixStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.borderLight)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.borderLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: AppColors.primaryGold, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
            const BorderSide(color: AppColors.error, width: 1.5)),
      );
}


import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
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
      balance: d('balance'),
      availableBalance: d('available_balance', 'availableBalance'),
      reservedBalance: d('reserved_balance', 'reservedBalance'),
      pendingWithdrawal: d('pending_withdrawal', 'pendingWithdrawal'),
      totalToppedUp: d('total_topped_up', 'totalToppedUp'),
      totalEarned: d('total_earned', 'totalEarned'),
      totalCommissionPaid: d('total_commission_paid', 'totalCommissionPaid'),
      outstandingCommission:
      d('outstanding_commission', 'outstandingCommission'),
      status: j['status'] as String? ?? 'active',
      canAcceptJobs:
      j['can_accept_jobs'] as bool? ?? j['canAcceptJobs'] as bool? ?? false,
      frozenReason: j['frozen_reason'] as String?,
    );
  }
}

enum _TopUpStatus {
  pending,
  under_review,
  confirmed,
  credited,
  rejected;

  static _TopUpStatus fromString(String s) {
    switch (s) {
      case 'under_review':
        return _TopUpStatus.under_review;
      case 'confirmed':
        return _TopUpStatus.confirmed;
      case 'credited':
        return _TopUpStatus.credited;
      case 'rejected':
        return _TopUpStatus.rejected;
      default:
        return _TopUpStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case _TopUpStatus.pending:
        return 'Pending';
      case _TopUpStatus.under_review:
        return 'Under Review';
      case _TopUpStatus.confirmed:
        return 'Confirmed';
      case _TopUpStatus.credited:
        return 'Credited';
      case _TopUpStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case _TopUpStatus.pending:
        return AppColors.warning;
      case _TopUpStatus.under_review:
        return AppColors.info;
      case _TopUpStatus.confirmed:
        return AppColors.primaryGold;
      case _TopUpStatus.credited:
        return AppColors.success;
      case _TopUpStatus.rejected:
        return AppColors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case _TopUpStatus.pending:
        return Icons.hourglass_empty_rounded;
      case _TopUpStatus.under_review:
        return Icons.manage_search_rounded;
      case _TopUpStatus.confirmed:
        return Icons.verified_rounded;
      case _TopUpStatus.credited:
        return Icons.check_circle_rounded;
      case _TopUpStatus.rejected:
        return Icons.cancel_rounded;
    }
  }
}

class _TopUp {
  final int id;
  final String topupCode;
  final double amount;
  final String paymentChannel;
  final String channelLabel;
  final _TopUpStatus status;
  final String? proofUrl;
  final String? paymentReference;
  final String? driverNote;
  final String? rejectionReason;
  final double? balanceBeforeCredit;
  final double? balanceAfterCredit;
  final DateTime submittedAt;
  final DateTime? creditedAt;
  final DateTime? rejectedAt;

  const _TopUp({
    required this.id,
    required this.topupCode,
    required this.amount,
    required this.paymentChannel,
    required this.channelLabel,
    required this.status,
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
    id: j['id'] as int,
    topupCode: j['topup_code'] as String? ?? '—',
    amount: (j['amount'] as num? ?? 0).toDouble(),
    paymentChannel: j['payment_channel'] as String? ?? '',
    channelLabel: j['channel_label'] as String? ?? j['payment_channel'] as String? ?? '',
    status: _TopUpStatus.fromString(j['status'] as String? ?? 'pending'),
    proofUrl: j['proof_url'] as String?,
    paymentReference: j['payment_reference'] as String?,
    driverNote: j['driver_note'] as String?,
    rejectionReason: j['rejection_reason'] as String?,
    balanceBeforeCredit: (j['balance_before_credit'] as num?)?.toDouble(),
    balanceAfterCredit: (j['balance_after_credit'] as num?)?.toDouble(),
    submittedAt: DateTime.tryParse(j['submitted_at'] as String? ?? '') ??
        DateTime.now(),
    creditedAt: j['credited_at'] != null
        ? DateTime.tryParse(j['credited_at'] as String)
        : null,
    rejectedAt: j['rejected_at'] != null
        ? DateTime.tryParse(j['rejected_at'] as String)
        : null,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryWalletScreen extends StatefulWidget {
  /// Pass [initialTab] = 1 to open directly on the "Top Up" tab.
  final int initialTab;
  const DeliveryWalletScreen({super.key, this.initialTab = 0});

  @override
  State<DeliveryWalletScreen> createState() => _DeliveryWalletScreenState();
}

class _DeliveryWalletScreenState extends State<DeliveryWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  String _accessToken = '';

  // ── Wallet state ─────────────────────────────────────────────────────────
  _Wallet _wallet = _Wallet.empty();
  bool _loadingWallet = true;

  // ── Top-up history state ──────────────────────────────────────────────────
  final List<_TopUp> _topups = [];
  bool _loadingHistory = true;
  bool _historyHasMore = true;
  int _historyPage = 1;
  static const int _historyLimit = 20;
  final ScrollController _historyScroll = ScrollController();

  // ── Submit form state ─────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _selectedChannel = 'mtn_mobile_money';
  File? _proofFile;
  bool _submitting = false;
  String? _submitSuccess; // non-null = show confirmation

  final _picker = ImagePicker();

  // ── Channel options ───────────────────────────────────────────────────────
  static const _channels = [
    {'value': 'mtn_mobile_money', 'label': 'MTN Mobile Money', 'emoji': '🟡'},
    {'value': 'orange_money', 'label': 'Orange Money', 'emoji': '🟠'},
    {'value': 'cash', 'label': 'Cash Deposit', 'emoji': '💵'},
  ];

  // ── Quick-amount presets (XAF) ────────────────────────────────────────────
  static const _presets = [1000, 2500, 5000, 10000, 25000, 50000];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _historyScroll.addListener(_onHistoryScroll);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token') ?? '';
    await Future.wait([_fetchWallet(), _fetchHistory(reset: true)]);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _historyScroll.dispose();
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
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
        // walletTopUp.controller.js wraps under 'data' key
        final raw = (body['data'] ?? body['wallet']) as Map<String, dynamic>?;
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
      _historyPage = 1;
      _topups.clear();
      _historyHasMore = true;
    }

    if (mounted) setState(() => _loadingHistory = true);
    try {
      final res = await http.get(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/deliveries/driver/wallet/topup?page=$_historyPage&limit=$_historyLimit'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        final rawList = (data?['topups'] as List?) ?? [];
        final items = rawList
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
  // NETWORK — submit top-up
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submitTopUp() async {
    if (!_formKey.currentState!.validate()) return;

    // Enforce proof for mobile money channels
    final needsProof = _selectedChannel != 'cash';
    if (needsProof && _proofFile == null) {
      _showSnack('Please attach your payment screenshot', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      final uri = Uri.parse(
          '${AppConfig.apiBaseUrl}/deliveries/driver/wallet/topup');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_accessToken'
        ..fields['amount'] = _amountCtrl.text.trim()
        ..fields['payment_channel'] = _selectedChannel;

      if (_referenceCtrl.text.trim().isNotEmpty) {
        request.fields['payment_reference'] = _referenceCtrl.text.trim();
      }
      if (_phoneCtrl.text.trim().isNotEmpty) {
        request.fields['sender_phone'] = _phoneCtrl.text.trim();
      }
      if (_noteCtrl.text.trim().isNotEmpty) {
        request.fields['driver_note'] = _noteCtrl.text.trim();
      }

      if (_proofFile != null) {
        final ext = _proofFile!.path.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'proof',
          _proofFile!.path,
          contentType: MediaType.parse(mime),
        ));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 || res.statusCode == 201) {
        final code =
        (body['data'] as Map<String, dynamic>?)?['topup_code'] as String?;
        setState(() {
          _submitSuccess = code;
          _submitting = false;
        });
        // Reset form
        _amountCtrl.clear();
        _referenceCtrl.clear();
        _phoneCtrl.clear();
        _noteCtrl.clear();
        _proofFile = null;
        // Refresh history and wallet in background
        _fetchHistory(reset: true);
        _fetchWallet();
        return;
      }

      final msg = body['message'] as String? ?? 'Submission failed';
      _showSnack(msg, isError: true);
    } catch (e) {
      _showSnack('Network error. Please try again.', isError: true);
    }
    if (mounted) setState(() => _submitting = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IMAGE PICKER
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickProof(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _proofFile = File(picked.path));
      }
    } on PlatformException catch (e) {
      _showSnack('Cannot access ${source == ImageSource.camera ? 'camera' : 'gallery'}: ${e.message}',
          isError: true);
    }
  }

  void _showProofSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primaryDark),
              title: const Text('Take photo',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickProof(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primaryDark),
              title: const Text('Choose from gallery',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickProof(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
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
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today, ${_timeStr(dt)}';
    if (diff.inDays == 1) return 'Yesterday, ${_timeStr(dt)}';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _timeStr(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w400),
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
            Text('Available balance',
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

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 — OVERVIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    if (_loadingWallet) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold));
    }
    return RefreshIndicator(
      color: AppColors.primaryGold,
      onRefresh: _fetchWallet,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          // Status banner (if not active)
          if (_wallet.status != 'active') _buildFrozenBanner(),

          // can_accept_jobs warning
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
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wallet ${_wallet.status}',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error)),
                if (_wallet.frozenReason != null)
                  Text(_wallet.frozenReason!,
                      style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          color: AppColors.error)),
                const SizedBox(height: 4),
                const Text('Contact support to resolve this.',
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
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
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Balance too low to accept jobs',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning)),
                const SizedBox(height: 3),
                const Text(
                    'Top up your wallet to start accepting deliveries.',
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        color: AppColors.warning,
                        height: 1.4)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _tabs.animateTo(1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Top Up Now',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceGrid() {
    final items = [
      (
      '💰',
      'Available',
      _wallet.availableBalance,
      AppColors.success,
      ),
      (
      '🔒',
      'Reserved',
      _wallet.reservedBalance,
      AppColors.warning,
      ),
      (
      '⏳',
      'Pending Withdrawal',
      _wallet.pendingWithdrawal,
      AppColors.info,
      ),
      (
      '📥',
      'Total Topped Up',
      _wallet.totalToppedUp,
      AppColors.primaryGold,
      ),
      (
      '📈',
      'Total Earned',
      _wallet.totalEarned,
      AppColors.success,
      ),
      (
      '🤝',
      'Commission Paid',
      _wallet.totalCommissionPaid,
      AppColors.textSecondary,
      ),
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
                      style: const TextStyle(
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
        child: Row(
          children: [
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reload Wallet',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  Text('MTN MoMo · Orange Money · Cash',
                      style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11,
                          color: Colors.white54)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.primaryGold, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentHistory() {
    if (_loadingHistory && _topups.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primaryGold)));
    }
    if (_topups.isEmpty) return const SizedBox.shrink();

    final recent = _topups.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent requests',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            GestureDetector(
              onTap: () => _tabs.animateTo(2),
              child: const Text('View all',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...recent.map(_buildTopUpTile),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 — TOP UP FORM
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTopUpTab() {
    // Show success confirmation
    if (_submitSuccess != null) {
      return _buildSubmitSuccess();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChannelSelector(),
            const SizedBox(height: 20),
            _buildAmountField(),
            const SizedBox(height: 20),
            _buildMobileMoneyFields(),
            const SizedBox(height: 20),
            _buildProofUpload(),
            const SizedBox(height: 16),
            _buildNoteField(),
            const SizedBox(height: 28),
            _buildSubmitButton(),
            const SizedBox(height: 16),
            _buildPaymentNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const Text('Request Submitted!',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Your top-up request ($_submitSuccess) has been received.\n'
                  'A WeGo agent will verify your payment shortly.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () {
                setState(() => _submitSuccess = null);
                _tabs.animateTo(2); // jump to history
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('View in History',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _submitSuccess = null),
              child: const Text('Submit another',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment method',
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
                onTap: () => setState(() {
                  _selectedChannel = ch['value']!;
                  _proofFile = null; // reset proof when channel changes
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                      right: ch == _channels.last ? 0 : 8),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryDark
                        : Colors.white,
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
                  child: Column(
                    children: [
                      Text(ch['emoji']!,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 5),
                      Text(
                        ch['label']!.replaceAll(' Money', '\nMoney').replaceAll(' Deposit', '\nDeposit'),
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
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amount (XAF)',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        // Preset chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((p) {
            final val = p.toString();
            final selected = _amountCtrl.text == val;
            return GestureDetector(
              onTap: () => setState(() => _amountCtrl.text = val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryDark
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: selected
                          ? AppColors.primaryGold
                          : AppColors.borderLight),
                ),
                child: Text(
                  '${(p / 1000).toStringAsFixed(p % 1000 == 0 ? 0 : 1)}k',
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
            if (n < 500) return 'Minimum top-up is 500 XAF';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildMobileMoneyFields() {
    if (_selectedChannel == 'cash') return const SizedBox.shrink();
    return Column(
      children: [
        TextFormField(
          controller: _referenceCtrl,
          style: const TextStyle(fontFamily: 'Roboto', fontSize: 14),
          decoration: _inputDecoration('Transaction reference (e.g. TXN12345)'),
          validator: (v) {
            if (_selectedChannel != 'cash' && (v == null || v.trim().isEmpty)) {
              return 'Please enter the transaction reference';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontFamily: 'Roboto', fontSize: 14),
          decoration: _inputDecoration('Sender phone number'),
        ),
      ],
    );
  }

  Widget _buildProofUpload() {
    final needsProof = _selectedChannel != 'cash';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Payment proof screenshot',
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            if (needsProof) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Required',
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 9,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _showProofSourceSheet,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _proofFile != null ? 160 : 100,
            decoration: BoxDecoration(
              color: _proofFile != null
                  ? Colors.transparent
                  : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _proofFile != null
                    ? AppColors.success
                    : AppColors.borderMedium,
                width: _proofFile != null ? 2 : 1.5,
                style: _proofFile != null
                    ? BorderStyle.solid
                    : BorderStyle.solid,
              ),
            ),
            child: _proofFile != null
                ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_proofFile!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _proofFile = null),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.upload_file_rounded,
                  color: needsProof
                      ? AppColors.primaryGold
                      : AppColors.textSecondary,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  needsProof
                      ? 'Tap to attach screenshot'
                      : 'Tap to attach (optional)',
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: needsProof
                          ? AppColors.primaryGold
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteCtrl,
      maxLines: 2,
      style: const TextStyle(fontFamily: 'Roboto', fontSize: 13),
      decoration: _inputDecoration('Note to reviewer (optional)'),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submitTopUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.borderMedium,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _submitting
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white))
            : const Text('Submit Top-Up Request',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildPaymentNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.info, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Send your payment to the WeGo collection number provided by your supervisor, '
                  'then submit this form with the screenshot. Credits are usually processed within 30 minutes.',
              style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: AppColors.info,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3 — HISTORY
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHistoryTab() {
    if (_loadingHistory && _topups.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold));
    }
    if (_topups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 52, color: AppColors.borderMedium),
            const SizedBox(height: 12),
            const Text('No top-up requests yet',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            const Text('Submit your first reload above',
                style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => _tabs.animateTo(1),
              child: const Text('Top Up Now',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
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
            return const Center(
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

  // ── Shared tile used in both Overview and History ──────────────────────────

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
      child: Column(
        children: [
          // ── Main row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Status icon circle
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: t.status.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(t.status.icon, color: t.status.color, size: 20),
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
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          // Status chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: t.status.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(t.status.label,
                                style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: t.status.color)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${t.channelLabel}  ·  ${_dateLabel(t.submittedAt)}',
                        style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Code row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                const Icon(Icons.tag_rounded,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(t.topupCode,
                    style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5)),
              ],
            ),
          ),

          // ── Credited balance snapshot ──────────────────────────────────
          if (t.status == _TopUpStatus.credited &&
              t.balanceBeforeCredit != null &&
              t.balanceAfterCredit != null) ...[
            Container(
              height: 1,
              color: AppColors.borderLight,
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                      child: _miniStat(
                          'Before', _fmt(t.balanceBeforeCredit!), AppColors.textSecondary)),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: AppColors.borderMedium),
                  Expanded(
                      child: _miniStat(
                          'After', _fmt(t.balanceAfterCredit!), AppColors.success)),
                ],
              ),
            ),
          ],

          // ── Rejection reason ───────────────────────────────────────────
          if (t.status == _TopUpStatus.rejected &&
              t.rejectionReason != null) ...[
            Container(height: 1, color: AppColors.borderLight),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(t.rejectionReason!,
                        style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: AppColors.error,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 9,
                color: AppColors.textSecondary)),
      ],
    );
  }

  // ── Input decoration helper ────────────────────────────────────────────────

  InputDecoration _inputDecoration(String hint, {String? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontFamily: 'Roboto', fontSize: 13, color: AppColors.textSecondary),
      suffixText: suffix,
      suffixStyle: const TextStyle(
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
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
        const BorderSide(color: AppColors.primaryGold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}
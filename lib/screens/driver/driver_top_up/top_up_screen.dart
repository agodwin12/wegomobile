// lib/screens/driver/wallet/driver_topup_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config.dart';

// ─── Palette (matches driver earnings screen dark theme) ──────────────
const _kBlack  = Color(0xFF0A0A0A);
const _kDark   = Color(0xFF111111);
const _kCard   = Color(0xFF181818);
const _kCard2  = Color(0xFF222222);
const _kGold   = Color(0xFFFFDC71);
const _kOrange = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);
const _kGrey   = Color(0xFFA9A9A9);
const _kWhite  = Colors.white;

// ─── Preset quick-amounts ─────────────────────────────────────────────
const _presets = [1000, 2000, 5000, 10000, 25000, 50000];

// ═══════════════════════════════════════════════════════════════════════
// API
// ═══════════════════════════════════════════════════════════════════════

class _TopUpApi {
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  /// POST /api/driver/wallet/topup
  static Future<Map<String, dynamic>> topUp({
    required int    amount,
    required String method,
    String?         phone,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/driver/wallet/topup'),
      headers: await _headers(),
      body: json.encode({
        'amount': amount,
        'method': method,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }),
    );
    return json.decode(res.body);
  }

  /// GET /api/driver/wallet/topup/history
  static Future<Map<String, dynamic>> getHistory({
    int    page   = 1,
    String period = 'all',
  }) async {
    final res = await http.get(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/driver/wallet/topup/history'
            '?page=$page&limit=20&period=$period',
      ),
      headers: await _headers(),
    );
    return json.decode(res.body);
  }

  /// GET /api/driver/wallet  (current balance)
  static Future<Map<String, dynamic>> getWallet() async {
    final res = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/driver/wallet'),
      headers: await _headers(),
    );
    return json.decode(res.body);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════

class DriverTopUpScreen extends StatefulWidget {
  /// If provided, shows the "you need X XAF more" callout at the top.
  final int? requiredAmount;

  const DriverTopUpScreen({super.key, this.requiredAmount});

  @override
  State<DriverTopUpScreen> createState() => _DriverTopUpScreenState();
}

class _DriverTopUpScreenState extends State<DriverTopUpScreen>
    with SingleTickerProviderStateMixin {

  // ─── Tab ──────────────────────────────────────────────────────────
  late TabController _tabs;

  // ─── Wallet balance ───────────────────────────────────────────────
  int    _balance     = 0;
  bool   _balanceLoad = true;

  // ─── Top-up form ──────────────────────────────────────────────────
  final _amountCtrl = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  String  _method   = 'MTN_MOMO';
  bool    _loading  = false;
  String? _error;
  bool    _success  = false;
  int     _successAmount = 0;
  int     _newBalance    = 0;

  // ─── History ──────────────────────────────────────────────────────
  List<dynamic> _history      = [];
  bool          _historyLoad  = true;
  bool          _historyMore  = false;
  int           _historyPage  = 1;
  int           _historyPages = 1;
  String        _historyPeriod = 'all';
  int           _historyTotal = 0;
  final ScrollController _scroll = ScrollController();

  // ─── Payment methods ──────────────────────────────────────────────
  final _methods = [
    {
      'value':    'MTN_MOMO',
      'label':    'MTN MoMo',
      'emoji':    '🟡',
      'subtitle': 'Instant — sent to your MTN number',
      'needPhone': true,
    },
    {
      'value':    'ORANGE_MONEY',
      'label':    'Orange Money',
      'emoji':    '🟠',
      'subtitle': 'Instant — sent to your Orange number',
      'needPhone': true,
    },
    {
      'value':    'CASH',
      'label':    'Cash at Agency',
      'emoji':    '💵',
      'subtitle': 'Pay cash at a WeGo partner agency',
      'needPhone': false,
    },
  ];

  bool get _needsPhone =>
      _methods.firstWhere((m) => m['value'] == _method)['needPhone'] == true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _scroll.addListener(_onScroll);
    _loadBalance();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      if (!_historyMore && _historyPage < _historyPages) {
        _historyPage++;
        _loadHistory();
      }
    }
  }

  // ─── Data loaders ─────────────────────────────────────────────────

  Future<void> _loadBalance() async {
    if (!mounted) return;
    try {
      final res = await _TopUpApi.getWallet();
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _balance     = (res['data']['balance'] as num?)?.toInt() ?? 0;
          _balanceLoad = false;
        });
      } else {
        setState(() => _balanceLoad = false);
      }
    } catch (_) {
      if (mounted) setState(() => _balanceLoad = false);
    }
  }

  Future<void> _loadHistory({bool reset = false}) async {
    if (!mounted) return;
    if (reset) {
      setState(() { _historyLoad = true; _history = []; _historyPage = 1; });
    } else {
      setState(() => _historyMore = true);
    }
    try {
      final res = await _TopUpApi.getHistory(
        page:   _historyPage,
        period: _historyPeriod,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        final data = res['data'];
        setState(() {
          _history.addAll(data['topUps'] ?? []);
          _historyPages = data['pagination']?['totalPages'] ?? 1;
          _historyTotal = (data['summary']?['totalAmount'] as num?)?.toInt() ?? 0;
          _historyLoad  = false;
          _historyMore  = false;
        });
      } else {
        setState(() { _historyLoad = false; _historyMore = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _historyLoad = false; _historyMore = false; });
    }
  }

  // ─── Submit top-up ────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() { _error = null; _success = false; });

    final raw    = _amountCtrl.text.trim();
    final amount = int.tryParse(raw);

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount.');
      return;
    }
    if (amount < 500) {
      setState(() => _error = 'Minimum top-up is 500 XAF.');
      return;
    }
    if (amount > 500000) {
      setState(() => _error = 'Maximum single top-up is 500,000 XAF.');
      return;
    }
    if (_needsPhone && _phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your phone number.');
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await _TopUpApi.topUp(
        amount: amount,
        method: _method,
        phone:  _needsPhone ? _phoneCtrl.text.trim() : null,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final newBal = (res['data']?['wallet']?['balance'] as num?)?.toInt()
            ?? (_balance + amount);

        setState(() {
          _loading       = false;
          _success       = true;
          _successAmount = amount;
          _newBalance    = newBal;
          _balance       = newBal;
          _amountCtrl.clear();
          _phoneCtrl.clear();
        });

        // Refresh history so the new entry appears immediately
        _loadHistory(reset: true);

      } else {
        final code = res['code']?.toString() ?? '';
        String msg  = res['message'] ?? 'Top-up failed. Please try again.';

        if (code == 'WALLET_FROZEN') {
          msg = 'Your wallet is frozen. Contact support.';
        } else if (code == 'WALLET_SUSPENDED') {
          msg = 'Your wallet is suspended. Contact support.';
        }

        setState(() { _error = msg; _loading = false; });
      }
    } catch (_) {
      if (mounted) {
        setState(() { _error = 'Network error. Please check your connection.'; _loading = false; });
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildBalanceBanner(),
            if (widget.requiredAmount != null) _buildRequiredCallout(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildTopUpTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        _kCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _kWhite,
                size:  18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Top Up Wallet',
            style: TextStyle(
              fontFamily: 'LeagueSpartan',
              fontSize:   22,
              fontWeight: FontWeight.w700,
              color:      _kWhite,
            ),
          ),
        ],
      ),
    );
  }

  // ── Balance banner ────────────────────────────────────────────────

  Widget _buildBalanceBanner() {
    return Container(
      margin:  const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kOrange.withOpacity(0.15), _kOrange.withOpacity(0.05)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: _kOrange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding:     const EdgeInsets.all(10),
            decoration:  BoxDecoration(
              color:        _kOrange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: _kOrange,
              size:  22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CURRENT BALANCE',
                  style: TextStyle(
                    fontFamily:    'Quicksand',
                    fontSize:      10,
                    color:         _kOrange,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                _balanceLoad
                    ? Container(
                  width:  100, height: 22,
                  decoration: BoxDecoration(
                    color:        _kCard2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
                    : Text(
                  _fmtAmount(_balance),
                  style: const TextStyle(
                    fontFamily: 'LeagueSpartan',
                    fontSize:   24,
                    fontWeight: FontWeight.w800,
                    color:      _kOrange,
                  ),
                ),
              ],
            ),
          ),
          // Refresh
          GestureDetector(
            onTap: () {
              setState(() => _balanceLoad = true);
              _loadBalance();
            },
            child: const Icon(Icons.refresh_rounded, color: _kOrange, size: 20),
          ),
        ],
      ),
    );
  }

  // ── Required callout (shown when coming from insufficient balance dialog) ──

  Widget _buildRequiredCallout() {
    final shortfall = (widget.requiredAmount! - _balance).clamp(0, widget.requiredAmount!);
    return Container(
      margin:  const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        _kRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _kRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontFamily: 'Quicksand', fontSize: 12, color: _kGrey),
                children: [
                  const TextSpan(text: 'You need at least '),
                  TextSpan(
                    text:  _fmtAmount(widget.requiredAmount!),
                    style: const TextStyle(color: _kRed, fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' to accept that trip. Top up '),
                  TextSpan(
                    text:  _fmtAmount(shortfall),
                    style: const TextStyle(color: _kRed, fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' or more.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: TabBar(
        controller:           _tabs,
        labelColor:           _kOrange,
        unselectedLabelColor: _kGrey,
        indicatorColor:       _kOrange,
        indicatorWeight:      2.5,
        indicatorSize:        TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontFamily: 'Quicksand',
          fontWeight: FontWeight.w700,
          fontSize:   13,
        ),
        tabs: const [Tab(text: 'Top Up'), Tab(text: 'History')],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // TOP-UP TAB
  // ═════════════════════════════════════════════════════════════════

  Widget _buildTopUpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Success state ─────────────────────────────────────────
          if (_success) ...[
            _buildSuccessBanner(),
            const SizedBox(height: 24),
          ],

          // ── Amount input ──────────────────────────────────────────
          const Text(
            'Amount',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      _kGrey,
            ),
          ),
          const SizedBox(height: 8),
          _buildAmountInput(),
          const SizedBox(height: 12),

          // ── Quick presets ─────────────────────────────────────────
          _buildPresets(),
          const SizedBox(height: 24),

          // ── Payment method ────────────────────────────────────────
          const Text(
            'Payment Method',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      _kGrey,
            ),
          ),
          const SizedBox(height: 10),
          ..._methods.map((m) => _buildMethodTile(m)),
          const SizedBox(height: 20),

          // ── Phone input (MoMo only) ───────────────────────────────
          if (_needsPhone) ...[
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve:    Curves.easeInOut,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phone Number (${_methods.firstWhere((m) => m['value'] == _method)['label']})',
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      _kGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPhoneInput(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],

          // ── Error ─────────────────────────────────────────────────
          if (_error != null) ...[
            _buildErrorCard(_error!),
            const SizedBox(height: 16),
          ],

          // ── Submit ────────────────────────────────────────────────
          _buildSubmitButton(),
          const SizedBox(height: 16),

          // ── Info note ─────────────────────────────────────────────
          _buildInfoNote(),
        ],
      ),
    );
  }

  // ── Success banner ────────────────────────────────────────────────

  Widget _buildSuccessBanner() {
    return Container(
      padding:     const EdgeInsets.all(20),
      decoration:  BoxDecoration(
        color:        _kGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: _kGreen.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: _kGreen, size: 40),
          const SizedBox(height: 10),
          Text(
            '${_fmtAmount(_successAmount)} added!',
            style: const TextStyle(
              fontFamily: 'LeagueSpartan',
              fontSize:   22,
              fontWeight: FontWeight.w800,
              color:      _kGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'New balance: ${_fmtAmount(_newBalance)}',
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontSize:   13,
              color:      _kGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding:     const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration:  BoxDecoration(
                color:        _kGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Go Back to Dashboard',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                  color:      _kBlack,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Amount input ──────────────────────────────────────────────────

  Widget _buildAmountInput() {
    return Container(
      decoration: BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 18),
            child: Text(
              'XAF',
              style: TextStyle(
                fontFamily: 'LeagueSpartan',
                fontSize:   18,
                fontWeight: FontWeight.w700,
                color:      _kOrange,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller:       _amountCtrl,
              keyboardType:     TextInputType.number,
              inputFormatters:  [FilteringTextInputFormatter.digitsOnly],
              onChanged:        (_) { if (_success) setState(() => _success = false); },
              style: const TextStyle(
                fontFamily: 'LeagueSpartan',
                fontSize:   28,
                fontWeight: FontWeight.w800,
                color:      _kWhite,
              ),
              decoration: const InputDecoration(
                hintText:       '0',
                hintStyle:      TextStyle(
                  fontFamily: 'LeagueSpartan',
                  fontSize:   28,
                  color:      Color(0xFF333333),
                  fontWeight: FontWeight.w800,
                ),
                border:         InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              ),
            ),
          ),
          // Clear button
          if (_amountCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() { _amountCtrl.clear(); _success = false; }),
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(Icons.cancel_rounded, color: _kGrey.withOpacity(0.5), size: 20),
              ),
            ),
        ],
      ),
    );
  }

  // ── Preset chips ──────────────────────────────────────────────────

  Widget _buildPresets() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presets.map((p) {
        final selected = _amountCtrl.text == p.toString();
        return GestureDetector(
          onTap: () {
            setState(() {
              _amountCtrl.text = p.toString();
              _success = false;
            });
          },
          child: AnimatedContainer(
            duration:    const Duration(milliseconds: 180),
            padding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration:  BoxDecoration(
              color:        selected ? _kOrange : _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? _kOrange : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Text(
              _fmtPreset(p),
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize:   12,
                fontWeight: FontWeight.w700,
                color:      selected ? _kBlack : _kGrey,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Method tile ───────────────────────────────────────────────────

  Widget _buildMethodTile(Map<String, dynamic> m) {
    final isSelected = _method == m['value'];
    return GestureDetector(
      onTap: () => setState(() { _method = m['value'] as String; _error = null; }),
      child: AnimatedContainer(
        duration:    const Duration(milliseconds: 200),
        margin:      const EdgeInsets.only(bottom: 10),
        padding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration:  BoxDecoration(
          color:        isSelected ? _kOrange.withOpacity(0.1) : _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kOrange : Colors.white.withOpacity(0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(m['emoji'] as String, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['label'] as String,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      isSelected ? _kOrange : _kWhite,
                    ),
                  ),
                  Text(
                    m['subtitle'] as String,
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize:   11,
                      color:      _kGrey,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration:    const Duration(milliseconds: 200),
              width:  22, height: 22,
              decoration:  BoxDecoration(
                shape:  BoxShape.circle,
                color:  isSelected ? _kOrange : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _kOrange : _kGrey.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: _kBlack, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Phone input ───────────────────────────────────────────────────

  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(
              '🇨🇲 +237',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize:   14,
                fontWeight: FontWeight.w700,
                color:      _kGrey,
              ),
            ),
          ),
          Container(
            width: 1, height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color:  Colors.white.withOpacity(0.08),
          ),
          Expanded(
            child: TextField(
              controller:      _phoneCtrl,
              keyboardType:    TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style:           const TextStyle(
                fontFamily: 'Quicksand',
                fontSize:   15,
                fontWeight: FontWeight.w600,
                color:      _kWhite,
              ),
              decoration: const InputDecoration(
                hintText:       '6XX XXX XXX',
                hintStyle:      TextStyle(color: Color(0xFF444444), fontSize: 15),
                border:         InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error card ────────────────────────────────────────────────────

  Widget _buildErrorCard(String message) {
    return Container(
      padding:     const EdgeInsets.all(14),
      decoration:  BoxDecoration(
        color:        _kRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _kRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _kRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Quicksand',
                fontSize:   12,
                color:      _kRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _loading ? null : _submit,
      child: AnimatedContainer(
        duration:    const Duration(milliseconds: 200),
        width:       double.infinity,
        padding:     const EdgeInsets.symmetric(vertical: 17),
        decoration:  BoxDecoration(
          color:        _loading ? _kOrange.withOpacity(0.5) : _kOrange,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _loading ? [] : [
            BoxShadow(
              color:      _kOrange.withOpacity(0.3),
              blurRadius: 20,
              offset:     const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _loading
              ? const SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(
              color:       _kBlack,
              strokeWidth: 2.5,
            ),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: _kBlack, size: 20),
              SizedBox(width: 8),
              Text(
                'Top Up Wallet',
                style: TextStyle(
                  fontFamily: 'LeagueSpartan',
                  fontSize:   17,
                  fontWeight: FontWeight.w700,
                  color:      _kBlack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Info note ─────────────────────────────────────────────────────

  Widget _buildInfoNote() {
    return Container(
      padding:     const EdgeInsets.all(14),
      decoration:  BoxDecoration(
        color:        Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _kGrey, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your wallet balance must cover the commission on any trip you accept. '
                  'Minimum balance: 500 XAF. Top-ups are reflected instantly.',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize:   11,
                color:      _kGrey.withOpacity(0.8),
                height:     1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // HISTORY TAB
  // ═════════════════════════════════════════════════════════════════

  Widget _buildHistoryTab() {
    return Column(
      children: [
        // ── Period filter ─────────────────────────────────────────
        _buildPeriodFilter(),

        // ── Total summary strip ───────────────────────────────────
        if (!_historyLoad && _history.isNotEmpty)
          _buildHistorySummaryStrip(),

        // ── List ──────────────────────────────────────────────────
        Expanded(
          child: _historyLoad
              ? const Center(child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2))
              : _history.isEmpty
              ? _buildEmptyHistory()
              : RefreshIndicator(
            color:           _kOrange,
            backgroundColor: _kCard,
            onRefresh:       () => _loadHistory(reset: true),
            child: ListView.builder(
              controller: _scroll,
              padding:    const EdgeInsets.fromLTRB(20, 8, 20, 80),
              itemCount:  _history.length + (_historyMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _history.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child:   Center(child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2)),
                  );
                }
                return _buildHistoryRow(_history[i] as Map<String, dynamic>);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodFilter() {
    const periods = [
      ('all',   'All Time'),
      ('today', 'Today'),
      ('week',  'This Week'),
      ('month', 'This Month'),
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.fromLTRB(20, 8, 20, 0),
        children: periods.map((p) {
          final isSelected = _historyPeriod == p.$1;
          return GestureDetector(
            onTap: () {
              if (_historyPeriod != p.$1) {
                setState(() => _historyPeriod = p.$1);
                _loadHistory(reset: true);
              }
            },
            child: AnimatedContainer(
              duration:    const Duration(milliseconds: 180),
              margin:      const EdgeInsets.only(right: 8),
              padding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration:  BoxDecoration(
                color:        isSelected ? _kOrange : _kCard,
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(
                  color: isSelected ? _kOrange : Colors.white.withOpacity(0.08),
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

  Widget _buildHistorySummaryStrip() {
    return Container(
      margin:  const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:        _kCard2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded, color: _kOrange, size: 16),
          const SizedBox(width: 8),
          Text(
            'Total topped up: ',
            style: const TextStyle(fontFamily: 'Quicksand', fontSize: 12, color: _kGrey),
          ),
          Text(
            _fmtAmount(_historyTotal),
            style: const TextStyle(
              fontFamily: 'LeagueSpartan',
              fontSize:   14,
              fontWeight: FontWeight.w700,
              color:      _kOrange,
            ),
          ),
          const Spacer(),
          Text(
            '${_history.length} top-up${_history.length == 1 ? '' : 's'}',
            style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> tx) {
    final method      = tx['topUpMethod']?.toString() ?? 'CASH';
    final methodLabel = _methodLabelShort(method);
    final methodEmoji = _methodEmoji(method);

    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        _kCard,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width:  44, height: 44,
            decoration: BoxDecoration(
              color:        _kOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(methodEmoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  methodLabel,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                    color:      _kWhite,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(tx['createdAt']),
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize:   11,
                    color:      _kGrey,
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${_fmtAmount((tx['amount'] as num?)?.toInt() ?? 0)}',
                style: const TextStyle(
                  fontFamily: 'LeagueSpartan',
                  fontSize:   16,
                  fontWeight: FontWeight.w800,
                  color:      _kOrange,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Balance: ${_fmtAmount((tx['balanceAfter'] as num?)?.toInt() ?? 0)}',
                style: const TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize:   10,
                  color:      _kGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💳', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'No top-ups yet',
            style: TextStyle(
              fontFamily: 'LeagueSpartan',
              fontSize:   20,
              fontWeight: FontWeight.w700,
              color:      _kWhite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _historyPeriod == 'all'
                ? 'Fund your wallet to start receiving trips.'
                : 'No top-ups in this period.',
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontSize:   13,
              color:      _kGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════

  String _fmtAmount(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M XAF';
    if (amount >= 1000)    return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K XAF';
    return '$amount XAF';
  }

  /// Short label for preset chips — e.g. "5K XAF"
  String _fmtPreset(int amount) {
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K XAF';
    return '$amount XAF';
  }

  String _methodLabelShort(String method) {
    switch (method.toUpperCase()) {
      case 'MTN_MOMO':      return 'MTN MoMo';
      case 'ORANGE_MONEY':  return 'Orange Money';
      case 'CASH':          return 'Cash';
      case 'BANK_TRANSFER': return 'Bank Transfer';
      default:              return method;
    }
  }

  String _methodEmoji(String method) {
    switch (method.toUpperCase()) {
      case 'MTN_MOMO':      return '🟡';
      case 'ORANGE_MONEY':  return '🟠';
      case 'CASH':          return '💵';
      case 'BANK_TRANSFER': return '🏦';
      default:              return '💳';
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt  = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.day == yesterday.day && dt.month == yesterday.month && dt.year == yesterday.year) {
        return 'Yesterday ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}
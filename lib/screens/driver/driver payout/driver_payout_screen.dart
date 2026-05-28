// lib/screens/driver/earnings/driver_payout_history_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/config.dart';

const _kBlack  = Color(0xFF0A0A0A);
const _kGold   = Color(0xFFFFDC71);
const _kCard   = Color(0xFF181818);
const _kWhite  = Colors.white;
const _kGrey   = Color(0xFFA9A9A9);
const _kGreen  = Color(0xFF4CAF50);
const _kRed    = Color(0xFFEF5350);

// ═══════════════════════════════════════════════════════════════════════
// API
// ═══════════════════════════════════════════════════════════════════════

class _PayoutApi {
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  static Future<Map<String, dynamic>> getPayouts({
    int page = 1,
    String? status,
  }) async {
    var url = '${AppConfig.apiBaseUrl}/request/payout/driver?page=$page&limit=20';
    if (status != null && status != 'ALL') url += '&status=$status';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return json.decode(res.body);
  }

  static Future<Map<String, dynamic>> cancelPayout(String id) async {
    final res = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/request/payout/driver/$id'),
      headers: await _headers(),
    );
    return json.decode(res.body);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════

class DriverPayoutHistoryScreen extends StatefulWidget {
  const DriverPayoutHistoryScreen({super.key});

  @override
  State<DriverPayoutHistoryScreen> createState() => _DriverPayoutHistoryScreenState();
}

class _DriverPayoutHistoryScreenState extends State<DriverPayoutHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _payouts          = [];
  bool          _loading          = true;
  bool          _loadingMore      = false;
  String?       _error;
  int           _page             = 1;
  int           _totalPages       = 1;
  int           _availableBalance = 0;
  String        _selectedStatus   = 'ALL';

  // Status filter options
  final _statusFilters = [
    {'value': 'ALL',        'label': 'All'},
    {'value': 'PENDING',    'label': 'Pending'},
    {'value': 'PROCESSING', 'label': 'Processing'},
    {'value': 'PAID',       'label': 'Paid'},
    {'value': 'REJECTED',   'label': 'Rejected'},
    {'value': 'CANCELLED',  'label': 'Cancelled'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _page < _totalPages) {
        _page++;
        _load();
      }
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!mounted) return;
    if (reset) {
      setState(() { _loading = true; _error = null; _payouts = []; _page = 1; });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final res = await _PayoutApi.getPayouts(
        page:   _page,
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final data = res['data'];
        setState(() {
          _payouts.addAll(data['requests'] ?? []);
          _totalPages       = data['pagination']?['totalPages'] ?? 1;
          _availableBalance = data['availableBalance'] ?? 0;
          _loading          = false;
          _loadingMore      = false;
        });
      } else {
        setState(() {
          _error       = res['message'] ?? 'Failed to load payouts.';
          _loading     = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error       = 'Network error. Please try again.';
        _loading     = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _cancelPayout(Map<String, dynamic> payout) async {
    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Request?', style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 20, fontWeight: FontWeight.w700, color: _kWhite)),
        content: Text(
          'Are you sure you want to cancel this payout request of ${_fmt(payout['amount'] ?? 0)}?',
          style: const TextStyle(fontFamily: 'Quicksand', fontSize: 14, color: _kGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep It', style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w700, color: _kGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w700, color: _kRed)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await _PayoutApi.cancelPayout(payout['id'].toString());
      if (!mounted) return;

      if (res['success'] == true) {
        // Update the item in list without full reload
        setState(() {
          final idx = _payouts.indexWhere((p) => p['id'].toString() == payout['id'].toString());
          if (idx != -1) {
            _payouts[idx] = Map<String, dynamic>.from(_payouts[idx])..['status'] = 'CANCELLED';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payout request cancelled.', style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF333333),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to cancel.', style: const TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w600)),
            backgroundColor: _kRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error.', style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w600)),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBlack,
      appBar: AppBar(
        backgroundColor: _kBlack,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _kWhite, size: 18),
          ),
        ),
        title: const Text(
          'Payout History',
          style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 22, fontWeight: FontWeight.w700, color: _kWhite),
        ),
        actions: [
          GestureDetector(
            onTap: () => _load(reset: true),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.refresh_rounded, color: _kGold, size: 20),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Balance Banner ──────────────────────────────────────────
          if (!_loading) _buildBalanceBanner(),

          // ── Status Filter ───────────────────────────────────────────
          _buildStatusFilter(),

          // ── List ────────────────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBalanceBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1500), const Color(0xFF111100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Balance', style: TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey, fontWeight: FontWeight.w600)),
                Text(
                  _fmt(_availableBalance),
                  style: const TextStyle(fontFamily: 'LeagueSpartan', fontSize: 22, fontWeight: FontWeight.w800, color: _kGold),
                ),
              ],
            ),
          ),
          // Pending count badge
          if (_payouts.where((p) => p['status'] == 'PENDING').isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _kGold.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Text(
                '${_payouts.where((p) => p['status'] == 'PENDING').length} pending',
                style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11, fontWeight: FontWeight.w700, color: _kGold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: _statusFilters.map((f) {
          final isSelected = _selectedStatus == f['value'];
          return GestureDetector(
            onTap: () {
              if (_selectedStatus != f['value']!) {
                setState(() => _selectedStatus = f['value']!);
                _load(reset: true);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? _kGold : _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? _kGold : Colors.white.withOpacity(0.08)),
              ),
              child: Text(
                f['label']!,
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? _kBlack : _kGrey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😕', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontFamily: 'Quicksand', color: _kGrey, fontSize: 14)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _load(reset: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: _kGold, borderRadius: BorderRadius.circular(12)),
                child: const Text('Retry', style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w700, color: _kBlack)),
              ),
            ),
          ],
        ),
      );
    }

    if (_payouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💸', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('No payout requests', style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 20, fontWeight: FontWeight.w700, color: _kWhite)),
            const SizedBox(height: 8),
            Text(
              _selectedStatus == 'ALL'
                  ? 'You haven\'t made any payout requests yet.'
                  : 'No ${_selectedStatus.toLowerCase()} requests found.',
              style: const TextStyle(fontFamily: 'Quicksand', color: _kGrey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kGold,
      backgroundColor: _kCard,
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _payouts.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _payouts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2)),
            );
          }
          return _buildPayoutCard(_payouts[i] as Map<String, dynamic>);
        },
      ),
    );
  }

  Widget _buildPayoutCard(Map<String, dynamic> p) {
    final status       = (p['status'] ?? 'PENDING') as String;
    final statusConfig = _statusConfig(status);
    final method       = p['paymentMethod'] ?? 'CASH';
    final isPending    = status == 'PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // ── Main row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status icon circle
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: (statusConfig['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(statusConfig['icon'] as String, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmt(p['amount'] ?? 0),
                        style: const TextStyle(fontFamily: 'LeagueSpartan', fontSize: 20, fontWeight: FontWeight.w800, color: _kWhite),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_methodLabel(method)} • ${_formatDate(p['createdAt'])}',
                        style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey),
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (statusConfig['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusConfig['label'] as String,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusConfig['color'] as Color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Reference number ───────────────────────────────────────
          if (p['referenceNumber'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.tag, color: _kGrey, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    p['referenceNumber'],
                    style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11, color: _kGrey),
                  ),
                ],
              ),
            ),

          // ── Rejection reason ───────────────────────────────────────
          if (status == 'REJECTED' && p['rejectionReason'] != null) ...[
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: _kRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${p['rejectionReason']}',
                      style: const TextStyle(fontFamily: 'Quicksand', fontSize: 12, color: _kRed),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Transaction ref (if paid) ──────────────────────────────
          if (status == 'PAID' && p['transactionRef'] != null) ...[
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: _kGreen, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Ref: ${p['transactionRef']}',
                    style: const TextStyle(fontFamily: 'Quicksand', fontSize: 12, color: _kGreen),
                  ),
                ],
              ),
            ),
          ],

          // ── Cancel button for PENDING ──────────────────────────────
          if (isPending) ...[
            Divider(color: Colors.white.withOpacity(0.05), height: 1),
            GestureDetector(
              onTap: () => _cancelPayout(p),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel_outlined, color: _kRed, size: 16),
                    SizedBox(width: 6),
                    Text('Cancel Request', style: TextStyle(fontFamily: 'Quicksand', fontSize: 13, fontWeight: FontWeight.w700, color: _kRed)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────

  Map<String, dynamic> _statusConfig(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':    return {'color': _kGold,        'label': 'Pending',    'icon': '⏳'};
      case 'PROCESSING': return {'color': Colors.blue,   'label': 'Processing', 'icon': '⚙️'};
      case 'PAID':       return {'color': _kGreen,       'label': 'Paid',       'icon': '✅'};
      case 'REJECTED':   return {'color': _kRed,         'label': 'Rejected',   'icon': '❌'};
      case 'CANCELLED':  return {'color': _kGrey,        'label': 'Cancelled',  'icon': '🚫'};
      default:           return {'color': _kGrey,        'label': status,       'icon': '💸'};
    }
  }

  String _fmt(dynamic amount) {
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
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.day == yesterday.day && dt.month == yesterday.month && dt.year == yesterday.year) {
        return 'Yesterday ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  String _methodLabel(String method) {
    switch (method.toUpperCase()) {
      case 'CASH': return '💵 Cash';
      case 'MOMO': return '🟡 MTN MoMo';
      case 'OM':   return '🟠 Orange Money';
      default:     return method;
    }
  }
}
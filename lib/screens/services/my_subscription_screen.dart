// lib/screens/services/my_subscription_screen.dart
//
// Provider-facing "My Subscription" page: current plan + expiry + quota usage,
// a renew/upgrade CTA, and the subscription payment history.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/services.dart';
import '../../utils/app_colors.dart';

class MySubscriptionScreen extends StatefulWidget {
  const MySubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<MySubscriptionScreen> createState() => _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends State<MySubscriptionScreen> {
  bool _loading = true;
  Map<String, dynamic>? _sub;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final provider = context.read<ServicesProvider>();
    final results = await Future.wait([
      provider.getMySubscription(),
      provider.getSubscriptionHistory(),
    ]);
    if (!mounted) return;
    setState(() {
      _sub     = results[0] as Map<String, dynamic>?;
      _history = results[1] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  int _daysLeft(DateTime? expiry) {
    if (expiry == null) return 0;
    return expiry.difference(DateTime.now()).inDays;
  }

  String _fmt(DateTime? d) => d == null ? '—' : DateFormat('dd MMM yyyy').format(d);

  ({Color bg, Color fg, String label}) _statusChip(String? status) {
    switch (status) {
      case 'active':
        return (bg: const Color(0xFFE8F9F0), fg: const Color(0xFF00A85C), label: 'Actif');
      case 'pending_payment':
        return (bg: const Color(0xFFFFF6E5), fg: const Color(0xFFCC8800), label: 'En attente');
      case 'expired':
        return (bg: const Color(0xFFFDECEC), fg: const Color(0xFFE0344B), label: 'Expiré');
      case 'cancelled':
        return (bg: const Color(0xFFEFEFF2), fg: const Color(0xFF6B7280), label: 'Annulé');
      case 'refunded':
        return (bg: const Color(0xFFEFEFF2), fg: const Color(0xFF6B7280), label: 'Remboursé');
      default:
        return (bg: const Color(0xFFEFEFF2), fg: const Color(0xFF6B7280), label: status ?? '—');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: const Text('Mon abonnement',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0D0D1A))),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0D0D1A)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : RefreshIndicator(
              color: AppColors.primaryGold,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildPlanCard(),
                  const SizedBox(height: 24),
                  _buildHistoryHeader(),
                  const SizedBox(height: 12),
                  ..._buildHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard() {
    final active = _sub != null && _sub!['active'] == true;

    if (!active) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight, width: 1.5),
        ),
        child: Column(children: [
          const Icon(Icons.workspace_premium_outlined, size: 46, color: Color(0xFFB8B8C0)),
          const SizedBox(height: 12),
          const Text('Aucun abonnement actif',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D0D1A))),
          const SizedBox(height: 6),
          Text('Choisissez un plan pour publier vos annonces.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          _cta('Voir les plans'),
        ]),
      );
    }

    final expiry   = _date(_sub!['plan_expires_at']);
    final started  = _date(_sub!['plan_starts_at']);
    final daysLeft = _daysLeft(expiry);
    final quota    = _sub!['listing_quota'] as int?;
    final used     = (_sub!['listings_used'] as num?)?.toInt() ?? 0;
    final chip     = _statusChip('active');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0D0D1A).withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              (_sub!['plan_label'] ?? _sub!['plan_key'] ?? 'Plan').toString(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: chip.bg, borderRadius: BorderRadius.circular(20)),
            child: Text(chip.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: chip.fg)),
          ),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          _metric('Expire le', _fmt(expiry), Icons.event_rounded),
          const SizedBox(width: 12),
          _metric(daysLeft >= 0 ? 'Jours restants' : 'Expiré depuis',
              '${daysLeft.abs()} j', Icons.timelapse_rounded),
        ]),
        const SizedBox(height: 16),
        // Quota
        Text(
          quota == null ? 'Annonces : illimité' : 'Annonces : $used / $quota',
          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (quota != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: quota == 0 ? 0 : (used / quota).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryGold),
            ),
          ),
        if (started != null) ...[
          const SizedBox(height: 14),
          Text('Depuis le ${_fmt(started)}', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
        ],
        const SizedBox(height: 18),
        _cta('Renouveler / Changer de plan', dark: true),
      ]),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: AppColors.primaryGold),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _cta(String label, {bool dark = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, '/services/listing-plan').then((_) => _load()),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGold,
          foregroundColor: AppColors.primaryDark,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return const Text('Historique des paiements',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D0D1A)));
  }

  List<Widget> _buildHistory() {
    if (_history.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          alignment: Alignment.center,
          child: Text('Aucun paiement pour le moment.',
              style: TextStyle(fontSize: 13, color: AppColors.textLight)),
        ),
      ];
    }
    return _history.map((h) {
      final chip = _statusChip(h['status'] as String?);
      final amount = (h['amount'] as num?)?.toDouble() ?? 0;
      final date = _date(h['created_at']) ?? _date(h['starts_at']);
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight, width: 1.2),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryGold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((h['plan_label'] ?? h['plan_key'] ?? 'Plan').toString(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D0D1A))),
              const SizedBox(height: 2),
              Text(_fmt(date), style: TextStyle(fontSize: 11, color: AppColors.textLight)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${amount.toStringAsFixed(0)} XAF',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0D0D1A))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: chip.bg, borderRadius: BorderRadius.circular(8)),
              child: Text(chip.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: chip.fg)),
            ),
          ]),
        ]),
      );
    }).toList();
  }
}

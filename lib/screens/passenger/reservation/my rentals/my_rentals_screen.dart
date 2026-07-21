import 'package:flutter/material.dart';
import '../../../../l10n/tr.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../../service/rental_api_service.dart';
import '../../../../utils/app_colors.dart';

class MyRentalsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String accessToken;

  const MyRentalsScreen({
    super.key,
    required this.user,
    required this.accessToken,
  });

  @override
  State<MyRentalsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends State<MyRentalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool loading = true;
  List<dynamic> allRentals = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserRentals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  List<dynamic> _parseImages(dynamic rawImages) {
    if (rawImages == null) return [];
    if (rawImages is String) {
      try {
        final decoded = json.decode(rawImages);
        if (decoded is List) return decoded;
      } catch (_) {}
      return [];
    } else if (rawImages is List) {
      return rawImages;
    }
    return [];
  }

  String _getString(dynamic rental, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      if (rental[k] != null) return rental[k].toString();
    }
    return fallback;
  }

  DateTime _parseDate(dynamic rental, List<String> keys) {
    for (final k in keys) {
      if (rental[k] != null) {
        try {
          return DateTime.parse(rental[k].toString());
        } catch (_) {}
      }
    }
    return DateTime.now();
  }

  // ─── Data ────────────────────────────────────────────────────────────────────

  Future<void> _fetchUserRentals() async {
    setState(() => loading = true);

    final response = await RentalApiService.fetchUserRentals(
      widget.accessToken,
      widget.user['uuid'],
    );

    setState(() => loading = false);

    if (response['success'] == true) {
      final data = response['data'];
      List<dynamic> rentals = [];

      try {
        if (data is Map) {
          if (data['data'] != null) {
            final inner = data['data'];
            if (inner is Map && inner['rentals'] is List) {
              rentals = inner['rentals'];
            } else if (inner is List) {
              rentals = inner;
            }
          } else if (data['rentals'] is List) {
            rentals = data['rentals'];
          }
        } else if (data is List) {
          rentals = data;
        }
      } catch (e) {
        debugPrint('❌ Error parsing rentals: $e');
      }

      setState(() => allRentals = rentals);
    } else {
      _showErrorDialog(
        title: response['statusCode'] == 0
            ? 'Connection Error'
            : 'Error ${response['statusCode']}',
        message: response['statusCode'] == 0
            ? 'Unable to connect. Please check your internet connection.'
            : response['error'] ?? 'Failed to load rentals',
      );
    }
  }

  List<dynamic> get activeRentals => allRentals
      .where((r) => r['status'] == 'PENDING' || r['status'] == 'CONFIRMED')
      .toList();

  List<dynamic> get pastRentals => allRentals
      .where((r) => r['status'] == 'COMPLETED' || r['status'] == 'CANCELLED')
      .toList();

  bool _canCancelRental(dynamic rental) {
    try {
      final status = rental['status'];
      if (status != 'PENDING' && status != 'CONFIRMED') return false;
      final start = _parseDate(rental, ['startDate', 'start_date']);
      return start.difference(DateTime.now()).inHours >= 24;
    } catch (_) {
      return false;
    }
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _showCancelDialog(dynamic rental) async {
    final start = _parseDate(rental, ['startDate', 'start_date']);
    final hours = start.difference(DateTime.now()).inHours;

    if (hours < 24) {
      _showErrorDialog(
        title: tr('rent.cannotCancel'),
        message:
        'Cancellation requires at least 24 hours notice. Your rental starts in $hours hours.',
      );
      return;
    }

    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.backgroundWhite,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel_outlined,
                      color: AppColors.error, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Cancel Rental?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Please provide a reason for cancellation:',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: tr('rent.reasonHint'),
                hintStyle:
                TextStyle(color: AppColors.textLight, fontSize: 14),
                filled: true,
                fillColor: AppColors.backgroundLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: AppColors.borderLight)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: AppColors.borderLight)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primaryGold, width: 2)),
                contentPadding: const EdgeInsets.all(14),
              ),
              style: TextStyle(
                  fontSize: 14, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('rent.keepRental'),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final r = reasonController.text.trim();
              if (r.length < 10) {
                _showErrorSnackBar(
                    'Please provide a reason (at least 10 characters)');
                return;
              }
              Navigator.of(ctx).pop();
              _cancelRental(
                _getString(rental, ['id', 'uuid']),
                r,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(tr('rent.cancelRental'),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textWhite)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRental(String rentalId, String reason) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildLoadingDialog('Cancelling rental...'),
    );

    final response = await RentalApiService.cancelRentalByUser(
      accessToken: widget.accessToken,
      rentalId: rentalId,
      reason: reason,
    );

    if (mounted) Navigator.of(context).pop();

    if (response['success'] == true) {
      _showSuccessDialog(
        title: tr('rent.cancelled'),
        message: 'Your rental has been cancelled successfully.',
        onClose: () {
          Navigator.of(context).pop();
          _fetchUserRentals();
        },
      );
    } else {
      _showErrorDialog(
        title: tr('rent.cancelFailed'),
        message: response['error'] ?? 'Unable to cancel rental',
        details: response['data']?['details']?.toString(),
      );
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildTabBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchUserRentals,
                color: AppColors.primaryGold,
                child: loading
                    ? _buildLoadingState()
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(activeRentals, isActive: true),
                    _buildList(pastRentals, isActive: false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight, width: 1.5),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 20),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'My Rentals',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          // Refresh button
          GestureDetector(
            onTap: _fetchUserRentals,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight, width: 1.5),
              ),
              child: Icon(Icons.refresh_rounded,
                  color: AppColors.textPrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        labelColor: AppColors.primaryDark,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle:
        const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
        const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.all(4),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tr('common.active')),
                if (activeRentals.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${activeRentals.length}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'Past'),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.shadowMedium,
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryGold, strokeWidth: 3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your rentals...',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<dynamic> rentals, {required bool isActive}) {
    if (rentals.isEmpty) return _buildEmptyState(isActive);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      itemCount: rentals.length,
      itemBuilder: (_, i) => _buildRentalCard(rentals[i], isActive: isActive),
    );
  }

  Widget _buildEmptyState(bool isActive) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight, width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Icon(Icons.event_busy_rounded,
                size: 50, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),
          Text(
            isActive ? 'No Active Rentals' : 'No Past Rentals',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            isActive
                ? 'Book a car to see your active rentals here'
                : 'Your completed and cancelled rentals will appear here',
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Rental Card ─────────────────────────────────────────────────────────────

  Widget _buildRentalCard(dynamic rental, {required bool isActive}) {
    final vehicle =
        rental['vehicle'] ?? rental['Vehicle'] ?? <String, dynamic>{};
    final images = _parseImages(vehicle['images']);
    final firstImage = images.isNotEmpty ? images[0] : null;
    final status = _getString(rental, ['status'], 'UNKNOWN');
    final paymentStatus =
    _getString(rental, ['paymentStatus', 'payment_status'], 'unpaid')
        .toLowerCase();
    final paymentMethod =
    _getString(rental, ['paymentMethod', 'payment_method'], '').toLowerCase();
    final rentalType =
    _getString(rental, ['rentalType', 'rental_type'], 'DAY');
    final canCancel = isActive && _canCancelRental(rental);

    final startDate = _parseDate(rental, ['startDate', 'start_date']);
    final endDate = _parseDate(rental, ['endDate', 'end_date']);
    final durationDays = endDate.difference(startDate).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ─────────────────────────────────────────────────────────
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  firstImage != null
                      ? Image.network(
                    firstImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildVehiclePlaceholder(
                            vehicle['makeModel'] ??
                                vehicle['make_model']),
                  )
                      : _buildVehiclePlaceholder(
                      vehicle['makeModel'] ?? vehicle['make_model']),

                  // Gradient overlay for legibility
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.35),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Status badge top-right
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildStatusBadge(status),
                  ),

                  // Rental type badge top-left
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _rentalTypeLabel(rentalType),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle name + price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        vehicle['makeModel'] ??
                            vehicle['make_model'] ??
                            'Unknown Vehicle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'XAF ${_formatPrice(rental['totalPrice'] ?? rental['total_price'])}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryGold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Date & Duration row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(14),
                    border:
                    Border.all(color: AppColors.borderLight, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          Icons.calendar_today_rounded,
                          'Start',
                          DateFormat('MMM dd, yyyy').format(startDate),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: AppColors.borderLight,
                        margin:
                        const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          Icons.event_rounded,
                          'End',
                          DateFormat('MMM dd, yyyy').format(endDate),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: AppColors.borderLight,
                        margin:
                        const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      _buildInfoItem(
                        Icons.access_time_rounded,
                        'Duration',
                        '$durationDays ${durationDays == 1 ? 'day' : 'days'}',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Payment status + method
                Row(
                  children: [
                    Expanded(
                        child: _buildPaymentStatusChip(paymentStatus)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildPaymentMethodChip(paymentMethod)),
                  ],
                ),

                // Unpaid warning for active unpaid MoMo rentals
                if (isActive &&
                    paymentStatus == 'unpaid' &&
                    (paymentMethod == 'mtn_momo' ||
                        paymentMethod == 'orange_money')) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primaryGold.withOpacity(0.3),
                          width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: AppColors.primaryGold),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment pending confirmation. Pull to refresh to check the latest status.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark
                                  .withOpacity(0.75),
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Cancellation reason
                if (_getString(rental,
                    ['cancellationReason', 'cancellation_reason'])
                    .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14, color: AppColors.error),
                            SizedBox(width: 6),
                            Text(
                              'Cancellation Reason',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _getString(rental, [
                            'cancellationReason',
                            'cancellation_reason'
                          ]),
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],

                // Cancel button
                if (canCancel) ...[
                  const SizedBox(height: 16),
                  Divider(
                      color: AppColors.borderLight, height: 1),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancelDialog(rental),
                      icon: const Icon(Icons.cancel_outlined,
                          color: AppColors.error, size: 18),
                      label: Text(
                        tr('rent.cancelRental'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.error, width: 1.5),
                        padding:
                        const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sub-widgets ─────────────────────────────────────────────────────────────

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.textLight),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final cfg = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cfg['bg'] as Color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: (cfg['bg'] as Color).withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg['icon'] as IconData,
              size: 12, color: cfg['text'] as Color),
          const SizedBox(width: 5),
          Text(
            cfg['label'] as String,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: cfg['text'] as Color),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusChip(String paymentStatus) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (paymentStatus) {
      case 'paid':
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
        label = 'Paid';
        break;
      case 'refunded':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        icon = Icons.replay_rounded;
        label = 'Refunded';
        break;
      default:
        bgColor = AppColors.primaryGold.withOpacity(0.12);
        textColor = const Color(0xFF8B6F00);
        icon = Icons.schedule_rounded;
        label = 'Unpaid';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChip(String method) {
    IconData icon;
    String label;
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (method) {
      case 'mtn_momo':
        icon = Icons.phone_android_rounded;
        label = 'MTN MoMo';
        bgColor = const Color(0xFFFFCC00).withOpacity(0.12);
        textColor = const Color(0xFF8B6F00);
        borderColor = const Color(0xFFFFCC00).withOpacity(0.4);
        break;
      case 'orange_money':
        icon = Icons.phone_android_rounded;
        label = 'Orange Money';
        bgColor = const Color(0xFFFF6600).withOpacity(0.10);
        textColor = const Color(0xFFCC4400);
        borderColor = const Color(0xFFFF6600).withOpacity(0.3);
        break;
      case 'cash':
        icon = Icons.payments_rounded;
        label = 'Cash on Pickup';
        bgColor = AppColors.backgroundLight;
        textColor = AppColors.textSecondary;
        borderColor = AppColors.borderLight;
        break;
      default:
        icon = Icons.help_outline_rounded;
        label = 'Not set';
        bgColor = AppColors.backgroundLight;
        textColor = AppColors.textLight;
        borderColor = AppColors.borderLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclePlaceholder(String? name) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.backgroundLight,
            AppColors.secondaryLightGrey.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.shadowMedium,
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: const Icon(Icons.directions_car_rounded,
                  size: 28, color: AppColors.primaryGold),
            ),
            if (name != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.backgroundWhite.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  name.split(' ').first,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────────

  Widget _buildLoadingDialog(String message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.shadowDark,
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                  color: AppColors.primaryGold, strokeWidth: 4),
            ),
            const SizedBox(height: 20),
            Text(message,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog({
    required String title,
    required String message,
    required VoidCallback onClose,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.backgroundWhite,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.successLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(message,
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(tr('common.done'),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textWhite)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog({
    required String title,
    required String message,
    String? details,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.backgroundWhite,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.errorLight, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 48),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(message,
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5),
                textAlign: TextAlign.center),
            if (details != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(details,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.error,
                        fontFamily: 'monospace')),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(tr('common.close'),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textWhite)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.textWhite, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─── Pure helpers ─────────────────────────────────────────────────────────────

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    try {
      final v = double.parse(price.toString());
      return v.toStringAsFixed(0);
    } catch (_) {
      return price.toString();
    }
  }

  String _rentalTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'HOUR':
        return 'Hourly';
      case 'DAY':
        return 'Daily';
      case 'WEEK':
        return 'Weekly';
      case 'MONTH':
        return 'Monthly';
      default:
        return type;
    }
  }

  Map<String, dynamic> _statusConfig(String status) {
    switch (status) {
      case 'PENDING':
        return {
          'bg': AppColors.primaryGold.withOpacity(0.9),
          'text': AppColors.primaryDark,
          'icon': Icons.schedule_rounded,
          'label': 'Pending',
        };
      case 'CONFIRMED':
        return {
          'bg': Colors.blue.shade600,
          'text': Colors.white,
          'icon': Icons.verified_rounded,
          'label': 'Confirmed',
        };
      case 'COMPLETED':
        return {
          'bg': AppColors.success,
          'text': Colors.white,
          'icon': Icons.check_circle_rounded,
          'label': 'Completed',
        };
      case 'CANCELLED':
        return {
          'bg': AppColors.error,
          'text': Colors.white,
          'icon': Icons.cancel_rounded,
          'label': 'Cancelled',
        };
      default:
        return {
          'bg': AppColors.textLight,
          'text': Colors.white,
          'icon': Icons.help_outline_rounded,
          'label': status,
        };
    }
  }
}
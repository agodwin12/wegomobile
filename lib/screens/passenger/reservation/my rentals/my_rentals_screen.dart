import 'package:flutter/material.dart';
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

  /// Parse images from backend
  List<dynamic> _parseImages(dynamic rawImages) {
    if (rawImages == null) return [];

    if (rawImages is String) {
      try {
        final decoded = json.decode(rawImages);
        if (decoded is List) return decoded;
      } catch (e) {
        debugPrint('Error parsing images: $e');
      }
      return [];
    } else if (rawImages is List) {
      return rawImages;
    }

    return [];
  }

  /// Fetch user's rentals
  /// Fetch user's rentals
  Future<void> _fetchUserRentals() async {
    setState(() => loading = true);

    final response = await RentalApiService.fetchUserRentals(
      widget.accessToken,
      widget.user['uuid'],
    );

    setState(() => loading = false);

    if (response['success']) {
      debugPrint('🔍 FULL RESPONSE: ${json.encode(response)}');

      // ✅ FIX: Handle double-nested data structure with proper type checking
      final data = response['data'];
      List<dynamic> rentals = [];

      try {
        // Check for double-nested structure
        if (data is Map) {
          // First check if data itself has a 'data' key (double-nested)
          if (data['data'] != null) {
            final innerData = data['data'];
            if (innerData is Map && innerData['rentals'] != null) {
              // ✅ FIXED: Ensure we're assigning a List
              final rentalsData = innerData['rentals'];
              if (rentalsData is List) {
                rentals = rentalsData;
              }
            } else if (innerData is List) {
              rentals = innerData;
            }
          }
          // Fallback to direct 'rentals' key
          else if (data['rentals'] != null) {
            final rentalsData = data['rentals'];
            if (rentalsData is List) {
              rentals = rentalsData;
            }
          }
        } else if (data is List) {
          rentals = data;
        }
      } catch (e) {
        debugPrint('❌ Error parsing rentals: $e');
        rentals = [];
      }

      debugPrint('✅ PARSED RENTALS COUNT: ${rentals.length}');

      if (rentals.isNotEmpty) {
        debugPrint('✅ FIRST RENTAL STATUS: ${rentals[0]['status']}');
        debugPrint('✅ FIRST RENTAL VEHICLE: ${rentals[0]['vehicle'] != null ? "Found" : "Missing"}');
      }

      setState(() {
        allRentals = rentals;
      });

      debugPrint('✅ Final allRentals count: ${allRentals.length}');
      debugPrint('✅ Active rentals: ${activeRentals.length}');
      debugPrint('✅ Past rentals: ${pastRentals.length}');
    } else {
      if (response['statusCode'] == 0) {
        _showErrorDialog(
          title: 'Connection Error',
          message: 'Unable to connect. Please check your internet connection.',
        );
      } else {
        _showErrorDialog(
          title: 'Error ${response['statusCode']}',
          message: response['error'] ?? 'Failed to load rentals',
        );
      }
    }
  }
  /// Get active rentals (PENDING, CONFIRMED)
  List<dynamic> get activeRentals {
    return allRentals
        .where((rental) =>
    rental['status'] == 'PENDING' || rental['status'] == 'CONFIRMED')
        .toList();
  }

  /// Get past rentals (COMPLETED, CANCELLED)
  List<dynamic> get pastRentals {
    return allRentals
        .where((rental) =>
    rental['status'] == 'COMPLETED' || rental['status'] == 'CANCELLED')
        .toList();
  }

  /// Check if cancellation is allowed (24 hours before start)
  bool _canCancelRental(dynamic rental) {
    try {
      final status = rental['status'];
      if (status != 'PENDING' && status != 'CONFIRMED') return false;

      final startDate = DateTime.parse(rental['startDate'] ?? rental['start_date']);
      final now = DateTime.now();
      final hoursUntilStart = startDate.difference(now).inHours;

      return hoursUntilStart >= 24;
    } catch (e) {
      debugPrint('❌ Error in _canCancelRental: $e');
      return false;
    }
  }

  /// Show cancel confirmation dialog
  Future<void> _showCancelDialog(dynamic rental) async {
    final TextEditingController reasonController = TextEditingController();

    DateTime startDate;
    try {
      startDate = DateTime.parse(rental['startDate'] ?? rental['start_date']);
    } catch (e) {
      debugPrint('❌ Error parsing start date: $e');
      _showErrorDialog(
        title: 'Error',
        message: 'Unable to process rental dates',
      );
      return;
    }

    final now = DateTime.now();
    final hoursUntilStart = startDate.difference(now).inHours;

    if (hoursUntilStart < 24) {
      _showErrorDialog(
        title: 'Cannot Cancel',
        message:
        'Cancellation is only allowed 24 hours before the rental start date. Your rental starts in $hoursUntilStart hours.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                  child: const Icon(
                    Icons.cancel_outlined,
                    color: AppColors.error,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cancel Rental?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Please provide a reason for cancellation:',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'e.g., Travel plans changed...',
                hintStyle: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.backgroundLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: AppColors.primaryGold, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Keep Rental',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty || reason.length < 10) {
                _showErrorSnackBar(
                    'Please provide a reason (at least 10 characters)');
                return;
              }
              Navigator.of(context).pop();
              // ✅ Try both possible ID field names
              _cancelRental(rental['id'] ?? rental['uuid'] ?? '', reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Cancel Rental',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cancel rental API call
  Future<void> _cancelRental(String rentalId, String reason) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLoadingDialog('Cancelling rental...'),
    );

    final response = await RentalApiService.cancelRentalByUser(
      accessToken: widget.accessToken,
      rentalId: rentalId,
      reason: reason,
    );

    if (mounted) Navigator.of(context).pop();

    if (response['success']) {
      _showSuccessDialog(
        title: 'Rental Cancelled',
        message: 'Your rental has been cancelled successfully.',
        onClose: () {
          Navigator.of(context).pop();
          _fetchUserRentals(); // Refresh list
        },
      );
    } else {
      _showErrorDialog(
        title: 'Cancellation Failed',
        message: response['error'] ?? 'Unable to cancel rental',
        details: response['data']?['details']?.toString(),
      );
    }
  }

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
                    _buildRentalsList(activeRentals, isActive: true),
                    _buildRentalsList(pastRentals, isActive: false),
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
            offset: const Offset(0, 2),
          ),
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
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          const Expanded(
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
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
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
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: 'Active'),
          Tab(text: 'Past'),
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
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGold,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading your rentals...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalsList(List<dynamic> rentals, {required bool isActive}) {
    if (rentals.isEmpty) {
      return _buildEmptyState(isActive);
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: rentals.length,
      itemBuilder: (context, index) {
        return _buildRentalCard(rentals[index], isActive: isActive);
      },
    );
  }

  Widget _buildEmptyState(bool isActive) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight, width: 2),
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              size: 60,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isActive ? 'No Active Rentals' : 'No Past Rentals',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isActive
                ? 'You don\'t have any active rentals'
                : 'Your rental history is empty',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalCard(dynamic rental, {required bool isActive}) {
    final vehicle = rental['vehicle'] ?? rental['Vehicle'] ?? {};
    final images = _parseImages(vehicle['images']);
    final firstImage = images.isNotEmpty ? images[0] : null;
    final status = rental['status'] ?? 'UNKNOWN';
    final canCancel = isActive && _canCancelRental(rental);

    DateTime startDate;
    DateTime endDate;

    try {
      startDate = DateTime.parse(rental['startDate'] ?? rental['start_date']);
      endDate = DateTime.parse(rental['endDate'] ?? rental['end_date']);
    } catch (e) {
      debugPrint('❌ Error parsing dates: $e');
      startDate = DateTime.now();
      endDate = DateTime.now().add(const Duration(days: 1));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Container(
            height: 160,
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              color: AppColors.backgroundLight,
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
                  child: firstImage != null
                      ? Image.network(
                    firstImage,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 160,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildVehiclePlaceholder(vehicle['makeModel'] ??
                            vehicle['make_model']),
                  )
                      : _buildVehiclePlaceholder(
                      vehicle['makeModel'] ?? vehicle['make_model']),
                ),
                // Status Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: _buildStatusBadge(status),
                ),
              ],
            ),
          ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Name
                Text(
                  vehicle['makeModel'] ??
                      vehicle['make_model'] ??
                      'Unknown Vehicle',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Dates
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Duration
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${endDate.difference(startDate).inDays} days',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Price
                Row(
                  children: [
                    const Icon(
                      Icons.payments,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'XAF ${rental['totalPrice'] ?? rental['total_price'] ?? '0'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                if (isActive && canCancel) ...[
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.borderLight, height: 1),
                  const SizedBox(height: 16),

                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showCancelDialog(rental),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.error, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel_outlined,
                              color: AppColors.error, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Cancel Rental',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (rental['cancellationReason'] != null ||
                    rental['cancellation_reason'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: AppColors.error),
                            SizedBox(width: 6),
                            Text(
                              'Cancellation Reason:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rental['cancellationReason'] ??
                              rental['cancellation_reason'] ??
                              '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status) {
      case 'PENDING':
        backgroundColor = AppColors.primaryGold.withOpacity(0.9);
        textColor = AppColors.primaryDark;
        displayText = 'Pending';
        break;
      case 'CONFIRMED':
        backgroundColor = Colors.blue.shade600;
        textColor = AppColors.textWhite;
        displayText = 'Confirmed';
        break;
      case 'COMPLETED':
        backgroundColor = AppColors.success;
        textColor = AppColors.textWhite;
        displayText = 'Completed';
        break;
      case 'CANCELLED':
        backgroundColor = AppColors.error;
        textColor = AppColors.textWhite;
        displayText = 'Cancelled';
        break;
      default:
        backgroundColor = AppColors.textLight;
        textColor = AppColors.textWhite;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildVehiclePlaceholder(String? vehicleName) {
    return Container(
      width: double.infinity,
      height: double.infinity,
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
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowMedium,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                size: 30,
                color: AppColors.primaryGold,
              ),
            ),
            const SizedBox(height: 12),
            if (vehicleName != null)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.backgroundWhite.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  vehicleName.split(' ').first,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

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
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppColors.primaryGold,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.backgroundWhite,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textWhite,
                  ),
                ),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.backgroundWhite,
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  details,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.left,
                ),
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
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textWhite,
                  ),
                ),
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
                color: AppColors.textWhite, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
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
}
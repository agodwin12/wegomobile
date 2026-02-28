// lib/screens/services/request_detail_screen.dart
// WEGO Services Marketplace - Request Detail Screen
// PRODUCTION READY - NO TODOs

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/services/service_request_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class RequestDetailScreen extends StatefulWidget {
  final int requestId;

  const RequestDetailScreen({
    Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _isLoading = true;
  ServiceRequest? _request;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequestDetail();
  }

  Future<void> _loadRequestDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<ServicesProvider>();
      final request = await provider.fetchRequestById(widget.requestId);

      if (mounted) {
        setState(() {
          _request = request;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState(isTablet)
          : _request == null
          ? _buildNotFoundState(isTablet)
          : _buildContent(isTablet),
      bottomNavigationBar: _buildBottomActions(isTablet),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.backgroundWhite,
      elevation: 0,
      title: Text(
        'Request #${widget.requestId}',
        style: AppTypography.titleLarge.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        if (_request != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'refresh') {
                _loadRequestDetail();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 12),
                    Text('Refresh'),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONTENT
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildContent(bool isTablet) {
    return RefreshIndicator(
      color: AppColors.primaryGold,
      onRefresh: _loadRequestDetail,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(isTablet),
            const SizedBox(height: 16),
            _buildCustomerCard(isTablet),
            const SizedBox(height: 16),
            _buildServiceCard(isTablet),
            const SizedBox(height: 16),
            _buildRequestDetailsCard(isTablet),
            const SizedBox(height: 16),
            _buildLocationCard(isTablet),
            if (_request!.photos != null && _request!.photos!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPhotosCard(isTablet),
            ],
            const SizedBox(height: 100), // Bottom padding for actions
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATUS CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStatusCard(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: _getStatusGradient(),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStatusIcon(),
              color: Colors.white,
              size: isTablet ? 32 : 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(),
                  style: (isTablet
                      ? AppTypography.titleLarge
                      : AppTypography.titleMedium)
                      .copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusDescription(),
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withOpacity(0.7),
            size: isTablet ? 32 : 28,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CUSTOMER CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildCustomerCard(bool isTablet) {
    String customerName = 'Customer';
    String? customerPhone;

    if (_request!.customer != null) {
      final customerMap = _request!.customer as Map<String, dynamic>;
      customerName = customerMap['full_name']?.toString() ??
          customerMap['fullName']?.toString() ??
          'Customer';
      customerPhone = customerMap['phone_number']?.toString() ??
          customerMap['phoneNumber']?.toString();
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Information',
            style: (isTablet
                ? AppTypography.titleMedium
                : AppTypography.titleSmall)
                .copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: isTablet ? 64 : 56,
                height: isTablet ? 64 : 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    customerName[0].toUpperCase(),
                    style: (isTablet
                        ? AppTypography.displaySmall
                        : AppTypography.headlineMedium)
                        .copyWith(
                      color: AppColors.primaryBlack,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: (isTablet
                          ? AppTypography.titleLarge
                          : AppTypography.titleMedium)
                          .copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (customerPhone != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            customerPhone,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (_request!.status == RequestStatus.accepted ||
                  _request!.status == RequestStatus.inProgress)
                IconButton(
                  onPressed: () => _callCustomer(customerPhone),
                  icon: const Icon(Icons.phone),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.successLight,
                    foregroundColor: AppColors.success,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SERVICE CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildServiceCard(bool isTablet) {
    String serviceTitle = 'Service';
    String? categoryName;
    String? subcategoryName;

    if (_request!.listing != null) {
      final listingMap = _request!.listing as Map<String, dynamic>;
      serviceTitle = listingMap['title']?.toString() ?? 'Service';
      categoryName = listingMap['category_name']?.toString() ??
          listingMap['categoryName']?.toString();
      subcategoryName = listingMap['subcategory_name']?.toString() ??
          listingMap['subcategoryName']?.toString();
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.construction_rounded,
                  color: AppColors.primaryBlack,
                  size: isTablet ? 24 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceTitle,
                      style: (isTablet
                          ? AppTypography.titleMedium
                          : AppTypography.titleSmall)
                          .copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (categoryName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subcategoryName != null
                            ? '$categoryName • $subcategoryName'
                            : categoryName,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // REQUEST DETAILS CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildRequestDetailsCard(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Details',
            style: (isTablet
                ? AppTypography.titleMedium
                : AppTypography.titleSmall)
                .copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Request ID & Date
          _buildDetailRow(
            Icons.confirmation_number_rounded,
            'Request ID',
            '#${_request!.id}',
            isTablet,
          ),
          const SizedBox(height: 12),

          _buildDetailRow(
            Icons.calendar_today,
            'Requested',
            _formatFullDate(_request!.createdAt),
            isTablet,
          ),
          const SizedBox(height: 12),

          // Schedule
          _buildDetailRow(
            Icons.access_time,
            'Needed',
            _getScheduleDisplay(),
            isTablet,
          ),

          const Divider(height: 32),

          // Description
          Text(
            'Problem Description',
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _request!.description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LOCATION CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildLocationCard(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on,
                  color: AppColors.error,
                  size: isTablet ? 24 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Service Location',
                  style: (isTablet
                      ? AppTypography.titleMedium
                      : AppTypography.titleSmall)
                      .copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _request!.serviceLocation,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PHOTOS CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildPhotosCard(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attached Photos (${_request!.photos!.length})',
            style: (isTablet
                ? AppTypography.titleMedium
                : AppTypography.titleSmall)
                .copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isTablet ? 4 : 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _request!.photos!.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _viewPhoto(_request!.photos![index]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _request!.photos![index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.backgroundLight,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: AppColors.textLight,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon,
      String label,
      String value,
      bool isTablet,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: isTablet ? 20 : 18,
          color: AppColors.primaryGold,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BOTTOM ACTIONS
  // ═══════════════════════════════════════════════════════════════════
  Widget? _buildBottomActions(bool isTablet) {
    if (_request == null) return null;

    // Different actions based on status
    switch (_request!.status) {
      case RequestStatus.pending:
        return _buildPendingActions(isTablet);

      case RequestStatus.accepted:
        return _buildAcceptedActions(isTablet);

      case RequestStatus.inProgress:
        return _buildInProgressActions(isTablet);

      case RequestStatus.paymentConfirmationPending:
        return _buildPaymentConfirmationActions(isTablet);

      default:
        return null;
    }
  }

  Widget _buildPendingActions(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showRejectDialog(),
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 2),
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 18 : 14,
                  ),
                  textStyle: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _showAcceptDialog(),
                icon: const Icon(Icons.check_circle),
                label: const Text('Accept Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 18 : 14,
                  ),
                  textStyle: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedActions(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: () => _startService(),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Service'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGold,
            foregroundColor: AppColors.primaryBlack,
            padding: EdgeInsets.symmetric(
              vertical: isTablet ? 18 : 14,
            ),
            textStyle: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInProgressActions(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: () => _showCompleteServiceDialog(),
          icon: const Icon(Icons.check_circle),
          label: const Text('Complete Service'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: isTablet ? 18 : 14,
            ),
            textStyle: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentConfirmationActions(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton.icon(
          onPressed: () => _confirmPayment(),
          icon: const Icon(Icons.verified),
          label: const Text('Confirm Payment Received'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: isTablet ? 18 : 14,
            ),
            textStyle: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATES
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(
                color: AppColors.primaryBlack,
                strokeWidth: 4,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Loading request...',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: isTablet ? 80 : 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to load request',
              style: (isTablet
                  ? AppTypography.headlineMedium
                  : AppTypography.titleLarge)
                  .copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadRequestDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.primaryBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState(bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: isTablet ? 80 : 64,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 24),
            Text(
              'Request not found',
              style: (isTablet
                  ? AppTypography.headlineMedium
                  : AppTypography.titleLarge)
                  .copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This request may have been deleted',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════

  Color _getStatusColor() {
    switch (_request!.status) {
      case RequestStatus.pending:
        return AppColors.warning;
      case RequestStatus.accepted:
        return AppColors.info;
      case RequestStatus.inProgress:
        return AppColors.primaryGold;
      case RequestStatus.completed:
      case RequestStatus.paymentConfirmed:
        return AppColors.success;
      default:
        return AppColors.textLight;
    }
  }

  LinearGradient _getStatusGradient() {
    final color = _getStatusColor();
    return LinearGradient(
      colors: [color, color.withOpacity(0.7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  IconData _getStatusIcon() {
    switch (_request!.status) {
      case RequestStatus.pending:
        return Icons.pending_rounded;
      case RequestStatus.accepted:
        return Icons.check_circle_rounded;
      case RequestStatus.inProgress:
        return Icons.play_circle_filled_rounded;
      case RequestStatus.completed:
        return Icons.done_all_rounded;
      case RequestStatus.paymentConfirmationPending:
        return Icons.payment_rounded;
      case RequestStatus.paymentConfirmed:
        return Icons.verified_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _getStatusText() {
    switch (_request!.status) {
      case RequestStatus.pending:
        return 'Awaiting Response';
      case RequestStatus.accepted:
        return 'Request Accepted';
      case RequestStatus.inProgress:
        return 'Service In Progress';
      case RequestStatus.completed:
        return 'Service Completed';
      case RequestStatus.paymentPending:
        return 'Payment Pending';
      case RequestStatus.paymentConfirmationPending:
        return 'Awaiting Payment Confirmation';
      case RequestStatus.paymentConfirmed:
        return 'Payment Confirmed';
      default:
        return _request!.status.name.toUpperCase();
    }
  }

  String _getStatusDescription() {
    switch (_request!.status) {
      case RequestStatus.pending:
        return 'Customer is waiting for your response';
      case RequestStatus.accepted:
        return 'You can now start the service';
      case RequestStatus.inProgress:
        return 'Service is being performed';
      case RequestStatus.completed:
        return 'Waiting for customer payment';
      case RequestStatus.paymentConfirmationPending:
        return 'Customer uploaded payment proof';
      case RequestStatus.paymentConfirmed:
        return 'Transaction complete';
      default:
        return '';
    }
  }

  String _formatFullDate(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  String _getScheduleDisplay() {
    final neededWhenStr = _request!.neededWhen.name;

    switch (neededWhenStr) {
      case 'asap':
        return 'ASAP (As soon as possible)';
      case 'today':
        return 'Today';
      case 'tomorrow':
        return 'Tomorrow';
      case 'scheduled':
        if (_request!.scheduledDate != null) {
          return DateFormat('EEEE, MMM dd, yyyy')
              .format(_request!.scheduledDate!);
        }
        return 'Scheduled';
      default:
        return 'Not specified';
    }
  }

  void _viewPhoto(String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: Image.network(
                photoUrl,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _callCustomer(String? phone) {
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Customer'),
        content: Text('Call $phone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling $phone...')),
              );
            },
            child: const Text('Call'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTION HANDLERS
  // ═══════════════════════════════════════════════════════════════════

  void _showAcceptDialog() {
    final responseController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Accept Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a message to the customer (optional)',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'e.g., I can be there in 30 minutes',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptRequest(responseController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'e.g., Not available at that time',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              _rejectRequest(reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showCompleteServiceDialog() {
    final workSummaryController = TextEditingController();
    final finalAmountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Complete Service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: workSummaryController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Work Summary (Optional)',
                  hintText: 'Describe what was done',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: finalAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Final Amount (FCFA) *',
                  hintText: 'Enter total cost',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (finalAmountController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter final amount'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              _completeService(
                workSummary: workSummaryController.text.trim(),
                finalAmount: double.parse(finalAmountController.text.trim()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRequest(String? response) async {
    final provider = context.read<ServicesProvider>();
    final success = await provider.acceptRequest(
      _request!.id,
      providerResponse: response?.isNotEmpty == true ? response : null,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request accepted!'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadRequestDetail();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.requestsError ?? 'Failed to accept'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _rejectRequest(String reason) async {
    final provider = context.read<ServicesProvider>();
    final success = await provider.rejectRequest(_request!.id, reason);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected'),
          backgroundColor: AppColors.info,
        ),
      );
      Navigator.pop(context); // Go back
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.requestsError ?? 'Failed to reject'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _startService() async {
    final provider = context.read<ServicesProvider>();
    final success = await provider.startService(_request!.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service started!'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadRequestDetail();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.requestsError ?? 'Failed to start'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _completeService({
    String? workSummary,
    required double finalAmount,
  }) async {
    final provider = context.read<ServicesProvider>();
    final success = await provider.completeService(
      requestId: _request!.id, // ✅ FIXED: Changed from 'id' to 'requestId'
      finalAmount: finalAmount,
      workSummary: workSummary,
      afterPhotos: null, // ✅ FIXED: Removed after photos
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service completed! Waiting for payment.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadRequestDetail();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.requestsError ?? 'Failed to complete'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmPayment() async {
    final provider = context.read<ServicesProvider>();
    final success = await provider.confirmPayment(_request!.id);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment confirmed! Transaction complete.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadRequestDetail();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.requestsError ?? 'Failed to confirm'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
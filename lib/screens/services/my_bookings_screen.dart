// lib/screens/services/my_bookings_screen.dart
// WEGO Services Marketplace - My Bookings (Customer View)
// ✅ FIXED - ALL METHOD CALLS CORRECTED

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/services/service_request_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({Key? key}) : super(key: key);

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  final List<String> _tabs = [
    'All',
    'Pending',
    'Accepted',
    'In Progress',
    'Payment',
    'Completed'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyBookings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyBookings() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final provider = Provider.of<ServicesProvider>(context, listen: false);
    await provider.fetchMyRequests();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<ServiceRequest> _filterRequestsByTab(List<ServiceRequest> allRequests) {
    final selectedTab = _tabs[_tabController.index];

    switch (selectedTab) {
      case 'Pending':
        return allRequests
            .where((r) => r.status == RequestStatus.pending)
            .toList();
      case 'Accepted':
        return allRequests
            .where((r) => r.status == RequestStatus.accepted)
            .toList();
      case 'In Progress':
        return allRequests
            .where((r) => r.status == RequestStatus.inProgress)
            .toList();
      case 'Payment':
        return allRequests
            .where((r) =>
        r.status == RequestStatus.paymentPending ||
            r.status == RequestStatus.paymentConfirmationPending)
            .toList();
      case 'Completed':
        return allRequests
            .where((r) =>
        r.status == RequestStatus.completed ||
            r.status == RequestStatus.paymentConfirmed)
            .toList();
      default:
        return allRequests;
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
          : RefreshIndicator(
        color: AppColors.primaryGold,
        onRefresh: _loadMyBookings,
        child: Consumer<ServicesProvider>(
          builder: (context, provider, child) {
            final allRequests = provider.myRequests ?? [];

            if (allRequests.isEmpty) {
              return _buildEmptyState('No bookings yet', isTablet);
            }

            return Column(
              children: [
                _buildStatsSummary(allRequests, isTablet),
                _buildTabBar(allRequests, isTablet),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) {
                      final requests = _filterRequestsByTab(allRequests);

                      if (requests.isEmpty) {
                        return _buildEmptyState(
                          'No ${tab.toLowerCase()} bookings',
                          isTablet,
                        );
                      }

                      return _buildRequestsList(requests, isTablet);
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.backgroundWhite,
      elevation: 0,
      title: const Text('My Bookings'),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATS SUMMARY
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStatsSummary(List<ServiceRequest> requests, bool isTablet) {
    final pendingCount =
        requests.where((r) => r.status == RequestStatus.pending).length;

    final activeCount = requests
        .where((r) =>
    r.status == RequestStatus.accepted ||
        r.status == RequestStatus.inProgress)
        .length;

    final completedCount = requests
        .where((r) =>
    r.status == RequestStatus.completed ||
        r.status == RequestStatus.paymentConfirmed)
        .length;

    return Container(
      margin: EdgeInsets.all(isTablet ? 24 : 16),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            'Pending',
            pendingCount.toString(),
            Icons.pending_rounded,
            isTablet,
          ),
          _buildStatDivider(),
          _buildStatItem(
            'Active',
            activeCount.toString(),
            Icons.play_circle_filled_rounded,
            isTablet,
          ),
          _buildStatDivider(),
          _buildStatItem(
            'Done',
            completedCount.toString(),
            Icons.check_circle_rounded,
            isTablet,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, bool isTablet) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryBlack, size: isTablet ? 28 : 24),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            value,
            style: (isTablet
                ? AppTypography.displaySmall
                : AppTypography.headlineMedium)
                .copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.primaryBlack,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 60,
      color: AppColors.primaryBlack.withOpacity(0.2),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB BAR
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTabBar(List<ServiceRequest> requests, bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.primaryGold,
        indicatorWeight: 3,
        labelColor: AppColors.primaryGold,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle:
        AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle:
        AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w500),
        tabs: _tabs.map((tab) {
          final count = _filterRequestsByTab(requests).length;
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tab),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _tabController.index == _tabs.indexOf(tab)
                          ? AppColors.primaryGold
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count.toString(),
                      style: AppTypography.caption.copyWith(
                        color: _tabController.index == _tabs.indexOf(tab)
                            ? AppColors.primaryBlack
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        onTap: (index) => setState(() {}),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // REQUESTS LIST
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildRequestsList(List<ServiceRequest> requests, bool isTablet) {
    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(request, isTablet);
      },
    );
  }

  Widget _buildRequestCard(ServiceRequest request, bool isTablet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          _buildRequestHeader(request, isTablet),
          const Divider(height: 1),
          _buildRequestBody(request, isTablet),
          _buildRequestActions(request, isTablet),
        ],
      ),
    );
  }

  Widget _buildRequestHeader(ServiceRequest request, bool isTablet) {
    // Extract provider info safely
    String providerName = 'Provider';
    String? avatarUrl;

    if (request.listing != null) {
      final listingMap = request.listing as Map<String, dynamic>;
      if (listingMap['provider'] != null) {
        final providerMap = listingMap['provider'] as Map<String, dynamic>;
        providerName = providerMap['full_name']?.toString() ??
            providerMap['fullName']?.toString() ??
            'Provider';
        avatarUrl = providerMap['avatar_url']?.toString();
      }
    }

    // Extract service title safely
    String serviceTitle = 'Service';
    if (request.listing != null) {
      final listingMap = request.listing as Map<String, dynamic>;
      serviceTitle = listingMap['title']?.toString() ?? 'Service';
    }

    return Padding(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Row(
        children: [
          // Provider Avatar (Circular)
          Container(
            width: isTablet ? 56 : 48,
            height: isTablet ? 56 : 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: avatarUrl == null || avatarUrl.isEmpty
                  ? AppColors.primaryGradient
                  : null,
              color: avatarUrl != null && avatarUrl.isNotEmpty
                  ? AppColors.backgroundLight
                  : null,
            ),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
              child: Image.network(
                avatarUrl,
                width: isTablet ? 56 : 48,
                height: isTablet ? 56 : 48,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGold,
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      providerName[0].toUpperCase(),
                      style: (isTablet
                          ? AppTypography.headlineMedium
                          : AppTypography.titleLarge)
                          .copyWith(
                        color: AppColors.primaryBlack,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                },
              ),
            )
                : Center(
              child: Text(
                providerName[0].toUpperCase(),
                style: (isTablet
                    ? AppTypography.headlineMedium
                    : AppTypography.titleLarge)
                    .copyWith(
                  color: AppColors.primaryBlack,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerName,
                  style: (isTablet
                      ? AppTypography.titleLarge
                      : AppTypography.titleMedium)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  serviceTitle,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStatusBadge(request.status, isTablet),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(RequestStatus status, bool isTablet) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String text;

    switch (status) {
      case RequestStatus.pending:
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        icon = Icons.pending_rounded;
        text = 'PENDING';
        break;
      case RequestStatus.accepted:
        bgColor = AppColors.infoLight;
        textColor = AppColors.info;
        icon = Icons.check_circle_outline_rounded;
        text = 'ACCEPTED';
        break;
      case RequestStatus.rejected:
        bgColor = AppColors.errorLight;
        textColor = AppColors.error;
        icon = Icons.cancel_outlined;
        text = 'REJECTED';
        break;
      case RequestStatus.inProgress:
        bgColor = AppColors.primaryGold.withOpacity(0.1);
        textColor = AppColors.primaryGold;
        icon = Icons.play_circle_filled_rounded;
        text = 'IN PROGRESS';
        break;
      case RequestStatus.completed:
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        text = 'COMPLETED';
        break;
      case RequestStatus.cancelled:
        bgColor = AppColors.backgroundLight;
        textColor = AppColors.textLight;
        icon = Icons.block_rounded;
        text = 'CANCELLED';
        break;
      case RequestStatus.paymentPending:
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        icon = Icons.payment_rounded;
        text = 'PAYMENT DUE';
        break;
      case RequestStatus.paymentConfirmationPending:
        bgColor = AppColors.infoLight;
        textColor = AppColors.info;
        icon = Icons.hourglass_empty_rounded;
        text = 'CONFIRMING';
        break;
      case RequestStatus.paymentConfirmed:
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        icon = Icons.verified_rounded;
        text = 'PAID';
        break;
      case RequestStatus.expired:
        bgColor = AppColors.backgroundLight;
        textColor = AppColors.textLight;
        icon = Icons.schedule_rounded;
        text = 'EXPIRED';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 12 : 10,
        vertical: isTablet ? 6 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isTablet ? 16 : 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: (isTablet
                ? AppTypography.labelMedium
                : AppTypography.labelSmall)
                .copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestBody(ServiceRequest request, bool isTablet) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Request ID & Date
          Row(
            children: [
              Icon(Icons.confirmation_number_rounded,
                  size: isTablet ? 18 : 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Booking #${request.id}',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(request.createdAt),
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            request.description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          // Location
          _buildDetailRow(
            Icons.location_on_outlined,
            request.serviceLocation,
            isTablet,
          ),

          const SizedBox(height: 12),

          // Schedule
          _buildDetailRow(
            Icons.access_time,
            _getScheduleDisplay(request),
            isTablet,
          ),

          // Provider Response (if accepted)
          if (request.providerResponse != null &&
              request.providerResponse!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.message, color: AppColors.info, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Provider\'s message:',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.providerResponse!,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Final Amount (if completed)
          if (request.finalAmount != null && request.finalAmount! > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments, color: AppColors.primaryBlack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${request.finalAmount!.toStringAsFixed(0)} FCFA',
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.primaryBlack,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Work Summary (if provided)
          if (request.workSummary != null &&
              request.workSummary!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Work Summary:',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              request.workSummary!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],

          // Photos
          if (request.photos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Attached Photos (${request.photos.length})',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: request.photos.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        request.photos[index],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, bool isTablet) {
    return Row(
      children: [
        Icon(icon, size: isTablet ? 18 : 16, color: AppColors.primaryGold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestActions(ServiceRequest request, bool isTablet) {
    // Don't show actions section if there are no actions
    if (!_hasActions(request)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: _buildActionButtonsForStatus(request, isTablet),
    );
  }

  bool _hasActions(ServiceRequest request) {
    switch (request.status) {
      case RequestStatus.pending:
      case RequestStatus.accepted:
      case RequestStatus.paymentPending:
        return true;
      case RequestStatus.inProgress:
      case RequestStatus.paymentConfirmationPending:
      case RequestStatus.completed:
      case RequestStatus.paymentConfirmed:
        return true; // Info message
      default:
        return false;
    }
  }

  Widget _buildActionButtonsForStatus(ServiceRequest request, bool isTablet) {
    switch (request.status) {
      case RequestStatus.pending:
      // Show Cancel button
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showCancelDialog(request),
            icon: const Icon(Icons.close),
            label: const Text('Cancel Request'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
            ),
          ),
        );

      case RequestStatus.accepted:
      // Show info + cancel option
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Provider accepted your request. Waiting for service to start.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(request),
                icon: const Icon(Icons.close),
                label: const Text('Cancel Request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
                ),
              ),
            ),
          ],
        );

      case RequestStatus.inProgress:
      // Show info message
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.play_circle_filled,
                  color: AppColors.primaryGold),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Service in progress. Please wait for completion.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case RequestStatus.paymentPending:
      // Show "Upload Payment Proof" button
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showPaymentProofDialog(request),
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Payment Proof'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: AppColors.primaryBlack,
              padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
            ),
          ),
        );

      case RequestStatus.paymentConfirmationPending:
      // Waiting for provider confirmation
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_empty, color: AppColors.info),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Payment proof uploaded. Waiting for provider confirmation.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case RequestStatus.paymentConfirmed:
      case RequestStatus.completed:
      // Service completed successfully
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Service completed successfully!',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRatingDialog(request),
                icon: const Icon(Icons.star),
                label: const Text('Rate Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: AppColors.primaryBlack,
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
                ),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTION HANDLERS
  // ═══════════════════════════════════════════════════════════════════

  void _showCancelDialog(ServiceRequest request) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.cancel,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Cancel Request'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this request?',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g., Found another provider',
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
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelRequest(request, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: Correct method signature - 2 positional arguments
  Future<void> _cancelRequest(ServiceRequest request, String reason) async {
    final provider = Provider.of<ServicesProvider>(context, listen: false);

    // ✅ Pass 2 positional arguments as expected by provider
    final success = await provider.cancelRequest(
      request.id,
      reason.isNotEmpty ? reason : 'Cancelled by customer',
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request cancelled'),
          backgroundColor: AppColors.info,
        ),
      );
      _loadMyBookings();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.requestsError ?? 'Failed to cancel request',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showPaymentProofDialog(ServiceRequest request) {
    String? selectedMethod;
    String transactionRef = '';
    File? proofImage;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Upload Payment Proof'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount to pay: ${request.finalAmount?.toStringAsFixed(0) ?? '0'} FCFA',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Payment Method *',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'mtn_momo',
                      child: Text('MTN Mobile Money'),
                    ),
                    DropdownMenuItem(
                      value: 'orange_money',
                      child: Text('Orange Money'),
                    ),
                    DropdownMenuItem(
                      value: 'cash',
                      child: Text('Cash'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedMethod = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => transactionRef = value,
                  decoration: InputDecoration(
                    labelText: 'Transaction Reference (optional)',
                    hintText: 'e.g., TXN123456',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Payment Screenshot *',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (proofImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          proofImage!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: () {
                            setDialogState(() {
                              proofImage = null;
                            });
                          },
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () async {
                      final XFile? image =
                      await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setDialogState(() {
                          proofImage = File(image.path);
                        });
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose Image'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
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
                if (selectedMethod == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select payment method'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                if (proofImage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please upload payment screenshot'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                _uploadPaymentProof(
                  request,
                  selectedMethod!,
                  proofImage!,
                  transactionRef.isNotEmpty ? transactionRef : null,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
              ),
              child: const Text('Upload Proof'),
            ),
          ],
        ),
      ),
    );
  }

// ✅ FIXED: Correct parameter types and names
  Future<void> _uploadPaymentProof(
      ServiceRequest request,
      String paymentMethod,
      File proofImage,
      String? transactionRef,
      ) async {
    final provider = Provider.of<ServicesProvider>(context, listen: false);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );

    // ✅ Pass File object directly, not path string
    // ✅ Include required paymentMethod parameter
    // ✅ Handle nullable transactionReference
    final success = await provider.uploadPaymentProof(
      id: request.id,
      paymentMethod: paymentMethod,
      paymentProof: proofImage, // ✅ Pass File object, not string path
      // ✅ Convert null to empty string
    );

    if (mounted) {
      Navigator.pop(context); // Close loading

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof uploaded successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadMyBookings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.requestsError ?? 'Failed to upload payment proof',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }



  void _showRatingDialog(ServiceRequest request) {
    int selectedRating = 5;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Rate Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How was the service?',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () {
                        setDialogState(() {
                          selectedRating = index + 1;
                        });
                      },
                      icon: Icon(
                        index < selectedRating
                            ? Icons.star
                            : Icons.star_border,
                        color: AppColors.primaryGold,
                        size: 40,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reviewController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: 'Write a review (optional)',
                    hintText: 'Share your experience...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitRating(
                  request,
                  selectedRating,
                  reviewController.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
              ),
              child: const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FIXED: Using correct provider method
  Future<void> _submitRating(
      ServiceRequest request,
      int rating,
      String review,
      ) async {
    final provider = Provider.of<ServicesProvider>(context, listen: false);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );

    // ✅ Use createRating method with correct parameters
    final success = await provider.createRating(
      requestId: request.id,
      rating: rating, review: '',

    );

    if (mounted) {
      Navigator.pop(context); // Close loading

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadMyBookings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.ratingsError ?? 'Failed to submit rating',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildEmptyState(String message, bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                color: AppColors.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: isTablet ? 80 : 64,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: (isTablet
                  ? AppTypography.headlineMedium
                  : AppTypography.titleLarge)
                  .copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Browse services and book one',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LOADING STATE
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
            'Loading bookings...',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  String _getScheduleDisplay(ServiceRequest request) {
    final neededWhenStr = request.neededWhen.name;

    switch (neededWhenStr) {
      case 'asap':
        return 'ASAP';
      case 'today':
        return 'Today';
      case 'tomorrow':
        return 'Tomorrow';
      case 'scheduled':
        if (request.scheduledDate != null) {
          return DateFormat('MMM dd, yyyy').format(request.scheduledDate!);
        }
        return 'Scheduled';
      default:
        return 'Not specified';
    }
  }
}
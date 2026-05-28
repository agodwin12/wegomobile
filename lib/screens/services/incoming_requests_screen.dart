// lib/screens/services/incoming_requests_screen.dart
// WEGO Services Marketplace - Incoming Requests (Provider View)
// ✅ COMPLETE - With real-time socket listeners

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/services/service_request_model.dart';
import '../../providers/services.dart';
import '../../service/api/service_socket_listener.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class IncomingRequestsScreen extends StatefulWidget {
  const IncomingRequestsScreen({Key? key}) : super(key: key);

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  final List<String> _tabs = ['All', 'Pending', 'Accepted', 'In Progress', 'Completed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadIncomingRequests();
      _registerSocketListeners();
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // SOCKET LISTENERS
  // ═══════════════════════════════════════════════════════════════════

  void _registerSocketListeners() {
    final listener = ServiceSocketListener.instance;

    // New request from customer
    listener.onNewRequest = (data) {
      if (!mounted) return;
      _loadIncomingRequests();
      final customerName = data['customer']?['first_name'] ?? 'Customer';
      final listingTitle = data['listing_title'] ?? 'your service';
      listener.showBanner(
        context: context,
        message: '$customerName sent a request for $listingTitle!',
        backgroundColor: Colors.blue.shade700,
        icon: Icons.notification_important,
        onTap: () {
          _tabController.animateTo(1); // Jump to Pending tab
          _loadIncomingRequests();
        },
      );
    };

    // Customer cancelled their request
    listener.onRequestCancelled = (data) {
      if (!mounted) return;
      _loadIncomingRequests();
      final customerName = data['cancelled_by']?['first_name'] ?? 'Customer';
      listener.showBanner(
        context: context,
        message: '$customerName cancelled their request.',
        backgroundColor: Colors.red.shade600,
        icon: Icons.cancel,
        onTap: () {
          _tabController.animateTo(0);
          _loadIncomingRequests();
        },
      );
    };

    // Payment proof uploaded by customer
    listener.onPaymentProofUploaded = (data) {
      if (!mounted) return;
      _loadIncomingRequests();
      final customerName = data['customer']?['first_name'] ?? 'Customer';
      final amount = data['final_amount']?.toString() ?? '';
      listener.showBanner(
        context: context,
        message: '$customerName uploaded payment proof for $amount FCFA. Please confirm!',
        backgroundColor: Colors.orange.shade700,
        icon: Icons.payment,
        onTap: () {
          _tabController.animateTo(3); // Jump to In Progress tab
          _loadIncomingRequests();
        },
      );
    };

    // Dispute filed against provider
    listener.onDisputeFiled = (data) {
      if (!mounted) return;
      _loadIncomingRequests();
      listener.showBanner(
        context: context,
        message: 'A dispute has been filed. Please respond within 48 hours.',
        backgroundColor: Colors.red.shade800,
        icon: Icons.gavel,
        onTap: () => _loadIncomingRequests(),
      );
    };

    // Dispute resolved
    listener.onDisputeResolved = (data) {
      if (!mounted) return;
      _loadIncomingRequests();
      listener.showBanner(
        context: context,
        message: 'A dispute has been resolved.',
        backgroundColor: Colors.purple.shade700,
        icon: Icons.gavel,
        onTap: () => _loadIncomingRequests(),
      );
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Clear callbacks so they don't fire after screen is gone
    final listener = ServiceSocketListener.instance;
    listener.onNewRequest = null;
    listener.onRequestCancelled = null;
    listener.onPaymentProofUploaded = null;
    listener.onDisputeFiled = null;
    listener.onDisputeResolved = null;
    super.dispose();
  }

  Future<void> _loadIncomingRequests() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final provider = Provider.of<ServicesProvider>(context, listen: false);
    await provider.fetchIncomingRequests();

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
        onRefresh: _loadIncomingRequests,
        child: Consumer<ServicesProvider>(
          builder: (context, provider, child) {
            final allRequests = provider.incomingRequests;

            if (allRequests.isEmpty) {
              return _buildEmptyState('No requests yet', isTablet);
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
                          'No ${tab.toLowerCase()} requests',
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
      title: const Text('Incoming Requests'),
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
    final pendingCount = requests
        .where((r) => r.status == RequestStatus.pending)
        .length;

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
          _buildStatItem('Pending', pendingCount.toString(),
              Icons.pending_rounded, isTablet),
          _buildStatDivider(),
          _buildStatItem('Active', activeCount.toString(),
              Icons.play_circle_filled_rounded, isTablet),
          _buildStatDivider(),
          _buildStatItem('Done', completedCount.toString(),
              Icons.check_circle_rounded, isTablet),
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
          if (_shouldShowActions(request))
            _buildRequestActions(request, isTablet),
        ],
      ),
    );
  }

  bool _shouldShowActions(ServiceRequest request) {
    return request.status == RequestStatus.pending ||
        request.status == RequestStatus.accepted ||
        request.status == RequestStatus.inProgress ||
        request.status == RequestStatus.paymentPending ||
        request.status == RequestStatus.paymentConfirmationPending ||
        request.status == RequestStatus.completed ||
        request.status == RequestStatus.paymentConfirmed;
  }

  Widget _buildRequestHeader(ServiceRequest request, bool isTablet) {
    String customerName = 'Customer';
    String? avatarUrl;

    if (request.customer != null) {
      final customerMap = request.customer as Map<String, dynamic>;
      customerName = customerMap['full_name']?.toString() ??
          customerMap['fullName']?.toString() ??
          'Customer';
      avatarUrl = customerMap['avatar_url']?.toString();
    }

    String serviceTitle = 'Service';
    if (request.listing != null) {
      final listingMap = request.listing as Map<String, dynamic>;
      serviceTitle = listingMap['title']?.toString() ?? 'Service';
    }

    return Padding(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Row(
        children: [
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
                      customerName[0].toUpperCase(),
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
                customerName[0].toUpperCase(),
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
                  customerName,
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
      case RequestStatus.paymentConfirmationPending:
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        icon = Icons.payment_rounded;
        text = 'PAYMENT';
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
          Row(
            children: [
              Icon(Icons.confirmation_number_rounded,
                  size: isTablet ? 18 : 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Request #${request.id}',
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

          _buildDetailRow(
              Icons.location_on_outlined, request.serviceLocation, isTablet),

          const SizedBox(height: 12),

          _buildDetailRow(
              Icons.access_time, _getScheduleDisplay(request), isTablet),

          if (request.photos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Attached Photos (${request.photos.length})',
              style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
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
                            child: const Icon(Icons.image_not_supported,
                                color: AppColors.textLight),
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

  Widget _buildActionButtonsForStatus(ServiceRequest request, bool isTablet) {
    switch (request.status) {
      case RequestStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showRejectDialog(request),
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showAcceptDialog(request),
                icon: const Icon(Icons.check),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
                ),
              ),
            ),
          ],
        );

      case RequestStatus.accepted:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _startService(request),
            icon: const Icon(Icons.play_circle_filled),
            label: const Text('Start Service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: AppColors.primaryBlack,
              padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
            ),
          ),
        );

      case RequestStatus.inProgress:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showCompleteServiceDialog(request),
            icon: const Icon(Icons.check_circle),
            label: const Text('Complete Service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
            ),
          ),
        );

      case RequestStatus.paymentPending:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.payment, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Waiting for customer to upload payment proof',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case RequestStatus.paymentConfirmationPending:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showConfirmPaymentDialog(request),
            icon: const Icon(Icons.verified),
            label: const Text('Confirm Payment Received'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
            ),
          ),
        );

      case RequestStatus.paymentConfirmed:
      case RequestStatus.completed:
        return Container(
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
                  'Service completed successfully',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTION HANDLERS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _startService(ServiceRequest request) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );

    final provider = Provider.of<ServicesProvider>(context, listen: false);
    final success = await provider.startService(request.id);

    if (mounted) {
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Service started!'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadIncomingRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.requestsError ?? 'Failed to start service'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showCompleteServiceDialog(ServiceRequest request) {
    final amountController = TextEditingController();
    final summaryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Complete Service')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the final amount for the completed service',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Final Amount (FCFA) *',
                  hintText: 'e.g., 15000',
                  prefixIcon: const Icon(Icons.payments),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: summaryController,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Work Summary (optional)',
                  hintText: 'Describe the work completed...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Customer will be notified to make payment.',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
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
              final amountText = amountController.text.trim();
              if (amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter final amount'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              final amount = double.tryParse(amountText);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _completeService(request, amount, summaryController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Complete Service'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeService(
      ServiceRequest request, double amount, String summary) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );

    final provider = Provider.of<ServicesProvider>(context, listen: false);
    final success = await provider.completeService(
      requestId: request.id,
      finalAmount: amount,
      workSummary: summary.isNotEmpty ? summary : null,
    );

    if (mounted) {
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Service completed! Amount: ${amount.toStringAsFixed(0)} FCFA\nCustomer notified to make payment.',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        await _loadIncomingRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                provider.requestsError ?? 'Failed to complete service'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showConfirmPaymentDialog(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.verified,
                  color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Confirm Payment')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Have you received the payment from the customer?',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only confirm if payment is received. This action cannot be undone.',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmPayment(request);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Yes, Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPayment(ServiceRequest request) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      ),
    );

    final provider = Provider.of<ServicesProvider>(context, listen: false);
    final success = await provider.confirmPayment(request.id);

    if (mounted) {
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Payment confirmed! Service completed.'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadIncomingRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                provider.requestsError ?? 'Failed to confirm payment'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAcceptDialog(ServiceRequest request) {
    final responseController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Accept Request')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a message to the customer (optional)',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'e.g., I can be there in 30 minutes',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
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
              _acceptRequest(
                  request, responseController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Accept Request'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(ServiceRequest request) {
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
              child: const Icon(Icons.cancel,
                  color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Reject Request')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejection',
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
                hintText: 'e.g., Not available at that time',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
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
              _rejectRequest(request, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRequest(
      ServiceRequest request, String? response) async {
    final provider = Provider.of<ServicesProvider>(context, listen: false);
    final success = await provider.acceptRequest(
      request.id,
      providerResponse:
      response?.isNotEmpty == true ? response : null,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request accepted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadIncomingRequests();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              provider.requestsError ?? 'Failed to accept request'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _rejectRequest(
      ServiceRequest request, String reason) async {
    final provider = Provider.of<ServicesProvider>(context, listen: false);
    final success = await provider.rejectRequest(request.id, reason);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected'),
          backgroundColor: AppColors.info,
        ),
      );
      await _loadIncomingRequests();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              provider.requestsError ?? 'Failed to reject request'),
          backgroundColor: AppColors.error,
        ),
      );
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
                Icons.inbox_rounded,
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
              'New requests will appear here',
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
            'Loading requests...',
            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
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
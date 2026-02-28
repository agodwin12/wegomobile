// lib/screens/services/my_listings_screen.dart
// ✅ FIXED: All null safety issues resolved

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/services/service_listing_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({Key? key}) : super(key: key);

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  final List<String> _tabs = ['All', 'Active', 'Pending', 'Rejected', 'Inactive'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // ✅ FIX: Load data after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyListings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyListings() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    // ✅ FIX: Use Provider.of with listen: false
    final provider = Provider.of<ServicesProvider>(context, listen: false);
    await provider.fetchMyListings();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<ServiceListing> _filterListingsByTab(List<ServiceListing> allListings) {
    final selectedTab = _tabs[_tabController.index];

    switch (selectedTab) {
      case 'Active':
        return allListings
            .where((l) => l.status == ListingStatus.active)
            .toList();
      case 'Pending':
        return allListings
            .where((l) => l.status == ListingStatus.pending)
            .toList();
      case 'Rejected':
        return allListings
            .where((l) => l.status == ListingStatus.rejected)
            .toList();
      case 'Inactive':
        return allListings
            .where((l) =>
        l.status == ListingStatus.inactive ||
            l.status == ListingStatus.deleted)
            .toList();
      default:
        return allListings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(),
      floatingActionButton: _buildFAB(),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
        color: AppColors.primaryGold,
        onRefresh: _loadMyListings,
        child: Consumer<ServicesProvider>(
          builder: (context, provider, child) {
            final allListings = provider.myListings ?? [];

            if (allListings.isEmpty) {
              return _buildEmptyState('No listings yet', isTablet);
            }

            return Column(
              children: [
                _buildStatsSummary(allListings, isTablet),
                _buildTabBar(allListings, isTablet),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) {
                      final listings = _filterListingsByTab(allListings);

                      if (listings.isEmpty) {
                        return _buildEmptyState(
                          'No ${tab.toLowerCase()} listings',
                          isTablet,
                        );
                      }

                      return _buildListingsList(listings, isTablet);
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
      title: const Text('My Listings'),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        IconButton(
          onPressed: _showFilterOptions,
          icon: const Icon(Icons.filter_list_rounded),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // FLOATING ACTION BUTTON
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.pushNamed(context, '/services/post').then((_) {
          _loadMyListings();
        });
      },
      backgroundColor: AppColors.primaryGold,
      foregroundColor: AppColors.primaryBlack,
      icon: const Icon(Icons.add),
      label: const Text('Post Service'),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATS SUMMARY
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStatsSummary(List<ServiceListing> listings, bool isTablet) {
    final activeCount = listings
        .where((l) => l.status == ListingStatus.active)
        .length;

    final totalViews = listings.fold<int>(
      0,
          (sum, listing) => sum + listing.viewCount,
    );

    final totalContacts = listings.fold<int>(
      0,
          (sum, listing) => sum + listing.contactCount,
    );

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
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem(
                'Active',
                activeCount.toString(),
                Icons.check_circle_rounded,
                isTablet,
              ),
              _buildStatDivider(),
              _buildStatItem(
                'Views',
                totalViews.toString(),
                Icons.visibility_rounded,
                isTablet,
              ),
              _buildStatDivider(),
              _buildStatItem(
                'Contacts',
                totalContacts.toString(),
                Icons.message_rounded,
                isTablet,
              ),
            ],
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
  Widget _buildTabBar(List<ServiceListing> listings, bool isTablet) {
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
        tabAlignment: TabAlignment.start,
        indicatorColor: AppColors.primaryGold,
        indicatorWeight: 3,
        labelColor: AppColors.primaryGold,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle:
        AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle:
        AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w500),
        tabs: _tabs.map((tab) {
          final count = _filterListingsByTab(listings).length;
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
  // LISTINGS LIST
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildListingsList(List<ServiceListing> listings, bool isTablet) {
    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        return _buildListingCard(listing, isTablet);
      },
    );
  }

  Widget _buildListingCard(ServiceListing listing, bool isTablet) {
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
          _buildListingHeader(listing, isTablet),
          const Divider(height: 1),
          _buildListingBody(listing, isTablet),
          _buildListingFooter(listing, isTablet),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ✅ FIXED: LISTING HEADER WITH NULL SAFETY
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildListingHeader(ServiceListing listing, bool isTablet) {
    // ✅ FIX: Safely get category name with fallback
    String categoryName = 'Uncategorized';

    // Try to get from categoryName field
    if (listing.categoryName != null && listing.categoryName!.isNotEmpty) {
      categoryName = listing.categoryName!;
    }
    // Try to get from category object if available
    else if (listing.category != null) {
      final categoryMap = listing.category as Map<String, dynamic>?;
      if (categoryMap != null) {
        categoryName = categoryMap['name_en']?.toString() ??
            categoryMap['name_fr']?.toString() ??
            categoryMap['name']?.toString() ??
            'Uncategorized';
      }
    }

    return Padding(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Row(
        children: [
          // Thumbnail or Icon
          Container(
            width: isTablet ? 80 : 64,
            height: isTablet ? 80 : 64,
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              image: listing.photos.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(listing.photos.first),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: listing.photos.isEmpty
                ? const Icon(
              Icons.work_outline_rounded,
              size: 32,
              color: AppColors.textLight,
            )
                : null,
          ),

          SizedBox(width: isTablet ? 16 : 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: (isTablet
                      ? AppTypography.titleLarge
                      : AppTypography.titleMedium)
                      .copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        categoryName, // ✅ FIXED: Safe category name
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          _buildStatusBadge(listing.status, isTablet),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ListingStatus status, bool isTablet) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String text;

    switch (status) {
      case ListingStatus.active:
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        text = 'ACTIVE';
        break;
      case ListingStatus.approved:
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        icon = Icons.verified_rounded;
        text = 'APPROVED';
        break;
      case ListingStatus.pending:
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        icon = Icons.pending_rounded;
        text = 'PENDING';
        break;
      case ListingStatus.rejected:
        bgColor = AppColors.errorLight;
        textColor = AppColors.error;
        icon = Icons.cancel_rounded;
        text = 'REJECTED';
        break;
      case ListingStatus.inactive:
      case ListingStatus.deleted:
        bgColor = AppColors.backgroundLight;
        textColor = AppColors.textLight;
        icon = Icons.visibility_off_rounded;
        text = 'INACTIVE';
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

  Widget _buildListingBody(ServiceListing listing, bool isTablet) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description Preview
          Text(
            listing.description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          // Pricing
          Row(
            children: [
              const Icon(
                Icons.payments_rounded,
                size: 16,
                color: AppColors.primaryGold,
              ),
              const SizedBox(width: 8),
              Text(
                _getPriceDisplay(listing),
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stats Row
          Row(
            children: [
              _buildStatChip(
                Icons.visibility_rounded,
                '${listing.viewCount} views',
                isTablet,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.message_rounded,
                '${listing.contactCount} contacts',
                isTablet,
              ),
            ],
          ),

          if (listing.averageRating != null && listing.averageRating! > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.star,
                  size: 16,
                  color: AppColors.primaryGold,
                ),
                const SizedBox(width: 4),
                Text(
                  listing.averageRating!.toStringAsFixed(1),
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${listing.totalReviews})',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, bool isTablet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingFooter(ServiceListing listing, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Posted Date
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: AppColors.textLight,
              ),
              const SizedBox(width: 6),
              Text(
                'Posted ${_formatDate(listing.createdAt)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildActionButtons(listing, isTablet),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(ServiceListing listing, bool isTablet) {
    final buttons = <Widget>[];

    // View Stats Button (always available)
    buttons.add(
      OutlinedButton.icon(
        onPressed: () => _showStatsDialog(listing),
        icon: const Icon(Icons.bar_chart_rounded, size: 16),
        label: const Text('Stats'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGold,
          side: const BorderSide(color: AppColors.primaryGold),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );

    // Edit Button (if can edit)
    if (listing.status.canEdit) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => _editListing(listing),
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.info,
            side: const BorderSide(color: AppColors.info),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    // Delete Button (always available)
    buttons.add(
      IconButton(
        onPressed: () => _deleteListing(listing),
        icon: const Icon(Icons.delete_outline_rounded),
        color: AppColors.error,
        iconSize: 20,
      ),
    );

    return buttons;
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
                Icons.work_outline_rounded,
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
              'Start offering your services to customers',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/services/post').then((_) {
                  _loadMyListings();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.primaryBlack,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Post Your First Service'),
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
            'Loading your listings...',
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
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? "s" : ""} ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  String _getPriceDisplay(ServiceListing listing) {
    switch (listing.pricingType) {
      case PricingType.negotiable:
        return 'Negotiable';
      case PricingType.hourly:
        if (listing.hourlyRate != null) {
          final price =
          NumberFormat('#,###').format(listing.hourlyRate!.toInt());
          return '$price FCFA/hour';
        }
        return 'Price not set';
      case PricingType.fixed:
        if (listing.fixedPrice != null) {
          final price =
          NumberFormat('#,###').format(listing.fixedPrice!.toInt());
          return '$price FCFA';
        }
        return 'Price not set';
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTION HANDLERS
  // ═══════════════════════════════════════════════════════════════════

  void _showStatsDialog(ServiceListing listing) {
    showDialog(
      context: context,
      builder: (context) => _StatsDialog(listing: listing),
    );
  }

  void _editListing(ServiceListing listing) {
    // TODO: Navigate to edit screen with listing data
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit listing #${listing.id}'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _deleteListing(ServiceListing listing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Listing?'),
        content: const Text(
          'This action cannot be undone. Are you sure you want to delete this listing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final provider = Provider.of<ServicesProvider>(context, listen: false);
              final success = await provider.deleteListing(listing.id);

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Listing deleted successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
                _loadMyListings();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.listingsError ?? 'Failed to delete listing',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort & Filter',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildFilterOption('Most Recent', Icons.access_time),
            _buildFilterOption('Most Popular', Icons.trending_up),
            _buildFilterOption('Highest Rated', Icons.star),
            _buildFilterOption('Most Views', Icons.visibility),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryGold),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sorted by: $label'),
            backgroundColor: AppColors.success,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// STATS DIALOG
// ═══════════════════════════════════════════════════════════════════════

class _StatsDialog extends StatelessWidget {
  final ServiceListing listing;

  const _StatsDialog({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bar_chart_rounded,
                    color: AppColors.primaryBlack,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Performance Stats',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlack,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: AppColors.primaryBlack,
                  ),
                ],
              ),
            ),

            // Stats Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildStatRow(
                      'Total Views',
                      '${listing.viewCount}',
                      Icons.visibility_rounded,
                      AppColors.info,
                    ),
                    const Divider(height: 24),
                    _buildStatRow(
                      'Contact Requests',
                      '${listing.contactCount}',
                      Icons.message_rounded,
                      AppColors.primaryGold,
                    ),
                    const Divider(height: 24),
                    _buildStatRow(
                      'Average Rating',
                      listing.averageRating != null
                          ? listing.averageRating!.toStringAsFixed(1)
                          : 'N/A',
                      Icons.star_rounded,
                      AppColors.warning,
                    ),
                    const Divider(height: 24),
                    _buildStatRow(
                      'Total Reviews',
                      '${listing.totalReviews}',
                      Icons.rate_review_rounded,
                      AppColors.info,
                    ),

                    const SizedBox(height: 24),

                    // Conversion Rate
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Conversion Rate',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _calculateConversionRate(),
                            style: AppTypography.headlineMedium.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Views to contacts',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _calculateConversionRate() {
    final views = listing.viewCount;
    final contacts = listing.contactCount;

    if (views == 0) return '0%';

    final rate = (contacts / views * 100).toStringAsFixed(1);
    return '$rate%';
  }
}
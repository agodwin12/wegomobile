// lib/screens/services/services_home_screen.dart
// UPDATED - Responsive grid layout for listings

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/services/category_model.dart';
import '../../models/services/service_listing_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class ServicesHomeScreen extends StatefulWidget {
  const ServicesHomeScreen({Key? key, Map<String, dynamic>? user, String? accessToken}) : super(key: key);

  @override
  State<ServicesHomeScreen> createState() => _ServicesHomeScreenState();
}

class _ServicesHomeScreenState extends State<ServicesHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    final provider = context.read<ServicesProvider>();
    await Future.wait([
      provider.fetchParentCategories(),
      provider.fetchListings(refresh: true),
    ]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primaryGold,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildHeroSection(isTablet)),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildQuickActions(isTablet)),
              SliverToBoxAdapter(child: _buildCategoriesSection(isTablet)),
              SliverToBoxAdapter(child: _buildListingsHeader(isTablet)),
              _buildListingsGrid(isTablet),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppColors.backgroundWhite,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'WEGO',
              style: TextStyle(
                fontFamily: 'League Spartan',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryBlack,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Services',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _navigateToNotifications(),
          icon: Stack(
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: AppColors.textPrimary,
                size: 26,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HERO SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildHeroSection(bool isTablet) {
    return Container(
      margin: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: _HeroBackgroundPainter(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isTablet ? 32 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: isTablet ? 56 : 48,
                      height: isTablet ? 56 : 48,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowMedium,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '🛠️',
                          style: TextStyle(fontSize: isTablet ? 28 : 24),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 16 : 12),
                Text(
                  'Find Local Services\nNear You',
                  style: (isTablet
                      ? AppTypography.displaySmall
                      : AppTypography.headlineLarge)
                      .copyWith(
                    color: AppColors.primaryBlack,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: isTablet ? 8 : 6),
                Text(
                  'Connect with trusted professionals',
                  style: (isTablet
                      ? AppTypography.bodyLarge
                      : AppTypography.bodyMedium)
                      .copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SEARCH BAR
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
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
        child: TextField(
          controller: _searchController,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search for services...',
            hintStyle: AppTypography.inputHint,
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.textSecondary,
              size: 24,
            ),
            suffixIcon: IconButton(
              onPressed: () => _showFiltersSheet(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tune,
                  color: AppColors.primaryBlack,
                  size: 20,
                ),
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _performSearch(value.trim());
            }
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ═══════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════
// QUICK ACTIONS
// ═══════════════════════════════════════════════════════════════════
  Widget _buildQuickActions(bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
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
            'Quick Actions',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: isTablet ? 16 : 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.add_circle_outline,
                  label: 'Post Service',
                  color: AppColors.success,
                  onTap: () => Navigator.pushNamed(context, '/services/post'),
                  isTablet: isTablet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.list_alt,
                  label: 'My Listings',
                  color: AppColors.info,
                  onTap: () => Navigator.pushNamed(context, '/services/my-listings'),
                  isTablet: isTablet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.inbox_rounded,
                  label: 'Incoming',
                  color: AppColors.warning,
                  onTap: () => Navigator.pushNamed(context, '/services/incoming-requests'),
                  isTablet: isTablet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.bookmark_outline,
                  label: 'Bookings',
                  color: AppColors.primaryGold,
                  onTap: () => Navigator.pushNamed(context, '/services/my-bookings'),
                  isTablet: isTablet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isTablet ? 16 : 12,
          horizontal: isTablet ? 12 : 8,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isTablet ? 28 : 24),
            SizedBox(height: isTablet ? 8 : 6),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 13 : 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CATEGORIES SECTION (Horizontal Scroll)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildCategoriesSection(bool isTablet) {
    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        final categories = provider.parentCategories;

        if (categories.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 24 : 16,
                isTablet ? 24 : 20,
                isTablet ? 24 : 16,
                isTablet ? 16 : 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Categories',
                    style: (isTablet
                        ? AppTypography.headlineMedium
                        : AppTypography.headlineSmall)
                        .copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _navigateToAllCategories(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Text(
                      'View All',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    label: const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.primaryGold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: isTablet ? 120 : 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
                itemCount: categories.length > 10 ? 10 : categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _buildCategoryChip(category, isTablet);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryChip(ServiceCategory category, bool isTablet) {
    return GestureDetector(
      onTap: () => _navigateToCategoryListings(category),
      child: Container(
        width: isTablet ? 100 : 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: isTablet ? 64 : 56,
              height: isTablet ? 64 : 56,
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryGold.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: category.iconUrl != null
                  ? ClipOval(
                child: Image.network(
                  category.iconUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.work_outline,
                      color: AppColors.primaryGold,
                      size: isTablet ? 32 : 28,
                    );
                  },
                ),
              )
                  : Icon(
                Icons.work_outline,
                color: AppColors.primaryGold,
                size: isTablet ? 32 : 28,
              ),
            ),
            SizedBox(height: isTablet ? 8 : 6),
            Text(
              category.getLocalizedName(useFrench: true),
              style: (isTablet
                  ? AppTypography.labelMedium
                  : AppTypography.labelSmall)
                  .copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LISTINGS HEADER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildListingsHeader(bool isTablet) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 24 : 16,
        isTablet ? 24 : 20,
        isTablet ? 24 : 16,
        isTablet ? 16 : 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Available Services',
            style: (isTablet
                ? AppTypography.headlineMedium
                : AppTypography.headlineSmall)
                .copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LISTINGS GRID - RESPONSIVE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildListingsGrid(bool isTablet) {
    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        if (provider.listingsLoading && provider.listings.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  color: AppColors.primaryGold,
                ),
              ),
            ),
          );
        }

        if (provider.listingsError != null && provider.listings.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildErrorState(
              message: provider.listingsError!,
              onRetry: () => provider.fetchListings(refresh: true),
            ),
          );
        }

        final listings = provider.listings;

        if (listings.isEmpty) {
          return const SliverToBoxAdapter(
            child: _EmptyState(
              icon: Icons.shopping_bag_outlined,
              message: 'No services available yet',
            ),
          );
        }

        // Responsive columns: 2 for mobile, 3 for tablet
        final crossAxisCount = isTablet ? 3 : 2;

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: isTablet ? 16 : 12,
              mainAxisSpacing: isTablet ? 16 : 12,
              childAspectRatio: isTablet ? 0.75 : 0.70, // Slightly taller cards
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final listing = listings[index];
                return _buildListingCard(listing, isTablet);
              },
              childCount: listings.length,
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LISTING CARD - COMPACT GRID VERSION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildListingCard(ServiceListing listing, bool isTablet) {
    return InkWell(
      onTap: () => _navigateToServiceDetail(listing),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  listing.mainPhoto.isNotEmpty
                      ? Image.network(
                    listing.mainPhoto,
                    height: isTablet ? 140 : 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholderImage(isTablet);
                    },
                  )
                      : _buildPlaceholderImage(isTablet),

                  // Rating badge overlay
                  if (listing.averageRating != null &&
                      listing.averageRating! > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              listing.averageRating!.toStringAsFixed(1),
                              style: AppTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      listing.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: isTablet ? 14 : 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Provider
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primaryGold.withOpacity(0.1),
                          backgroundImage: listing.provider?.avatarUrl != null
                              ? NetworkImage(listing.provider!.avatarUrl!)
                              : null,
                          child: listing.provider?.avatarUrl == null
                              ? const Icon(
                            Icons.person,
                            size: 10,
                            color: AppColors.primaryGold,
                          )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            listing.provider?.fullName ?? 'Unknown',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: isTablet ? 11 : 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Price
                    Text(
                      listing.priceDisplay,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.w800,
                        fontSize: isTablet ? 15 : 14,
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

  Widget _buildPlaceholderImage(bool isTablet) {
    return Container(
      height: isTablet ? 140 : 120,
      width: double.infinity,
      color: AppColors.backgroundLight,
      child: Icon(
        Icons.image_outlined,
        size: isTablet ? 48 : 40,
        color: AppColors.textLight,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ERROR STATE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildErrorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: AppColors.primaryBlack,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // FLOATING ACTION BUTTON
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _navigateToPostService(),
      backgroundColor: AppColors.primaryGold,
      foregroundColor: AppColors.primaryBlack,
      elevation: 4,
      icon: const Icon(Icons.add),
      label: const Text(
        'Post Service',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // NAVIGATION METHODS
  // ═══════════════════════════════════════════════════════════════════

  void _navigateToNotifications() {
    Navigator.pushNamed(context, '/services/notifications');
  }

  void _navigateToPostService() {
    Navigator.pushNamed(context, '/services/post');
  }

  void _navigateToAllCategories() {
    Navigator.pushNamed(context, '/services/categories');
  }

  void _navigateToCategoryListings(ServiceCategory category) {
    context.read<ServicesProvider>().selectCategory(category);
    Navigator.pushNamed(
      context,
      '/services/category-listings',
      arguments: {'category': category},
    );
  }

  void _navigateToServiceDetail(ServiceListing listing) {
    context.read<ServicesProvider>().selectListing(listing);
    Navigator.pushNamed(
      context,
      '/services/detail',
      arguments: {'listingId': listing.id},
    );
  }

  void _performSearch(String query) {
    Navigator.pushNamed(
      context,
      '/services/search',
      arguments: {'query': query},
    );
  }

  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FiltersBottomSheet(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// FILTERS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════

class _FiltersBottomSheet extends StatefulWidget {
  @override
  State<_FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<_FiltersBottomSheet> {
  RangeValues _priceRange = const RangeValues(0, 100000);
  double _minRating = 0;
  String? _selectedCity;

  final List<String> _cities = [
    'Douala',
    'Yaoundé',
    'Bafoussam',
    'Bamenda',
    'Garoua',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _priceRange = const RangeValues(0, 100000);
                      _minRating = 0;
                      _selectedCity = null;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'City',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cities.map((city) {
                      final isSelected = _selectedCity == city;
                      return ChoiceChip(
                        label: Text(city),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCity = selected ? city : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Price Range (FCFA)',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 100000,
                    divisions: 20,
                    labels: RangeLabels(
                      '${_priceRange.start.toInt()}',
                      '${_priceRange.end.toInt()}',
                    ),
                    onChanged: (values) {
                      setState(() {
                        _priceRange = values;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_priceRange.start.toInt()} FCFA'),
                      Text('${_priceRange.end.toInt()} FCFA'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Minimum Rating',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: _minRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    label: _minRating.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        _minRating = value;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('0.0 ★'),
                      Text('${_minRating.toStringAsFixed(1)} ★'),
                      const Text('5.0 ★'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.read<ServicesProvider>().fetchListings(
                    refresh: true,
                    city: _selectedCity,
                    minPrice: _priceRange.start,
                    maxPrice: _priceRange.end,
                    minRating: _minRating > 0 ? _minRating : null,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: AppColors.primaryBlack,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Apply Filters'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// EMPTY STATE WIDGET
// ═══════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(icon, size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// HERO BACKGROUND PAINTER
// ═══════════════════════════════════════════════════════════════════════

class _HeroBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 60, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.7), 30, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
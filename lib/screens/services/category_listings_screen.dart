// lib/screens/services/category_listings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/services/category_model.dart';
import '../../models/services/service_listing_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class CategoryListingsScreen extends StatefulWidget {
  final ServiceCategory category;

  const CategoryListingsScreen({
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  State<CategoryListingsScreen> createState() => _CategoryListingsScreenState();
}

class _CategoryListingsScreenState extends State<CategoryListingsScreen> {
  final ScrollController _scrollController = ScrollController();
  String _sortBy = 'created_at';
  String _sortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadListings();
    });

    // Pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        final provider = context.read<ServicesProvider>();
        if (!provider.listingsLoading && provider.hasMoreListings) {
          provider.fetchListings(
            categoryId: widget.category.id,
            sortBy: _sortBy,
            sortOrder: _sortOrder,
          );
        }
      }
    });
  }

  Future<void> _loadListings() async {
    if (!mounted) return;
    final provider = context.read<ServicesProvider>();
    await provider.fetchListings(
      categoryId: widget.category.id,
      refresh: true,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadListings,
        color: AppColors.primaryGold,
        child: Consumer<ServicesProvider>(
          builder: (context, provider, child) {
            // Filter listings by category
            final categoryListings = provider.listings
                .where((listing) => listing.categoryId == widget.category.id)
                .toList();

            if (provider.listingsLoading && categoryListings.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryGold,
                ),
              );
            }

            if (provider.listingsError != null && categoryListings.isEmpty) {
              return _buildErrorState(
                message: provider.listingsError!,
                onRetry: _loadListings,
              );
            }

            if (categoryListings.isEmpty) {
              return _buildEmptyState();
            }

            return Column(
              children: [
                _buildHeader(categoryListings.length, isTablet),
                _buildSortOptions(),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: categoryListings.length + (provider.listingsLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == categoryListings.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGold,
                            ),
                          ),
                        );
                      }

                      final listing = categoryListings[index];
                      return _buildListingCard(listing, isTablet);
                    },
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
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(
          Icons.arrow_back,
          color: AppColors.textPrimary,
        ),
      ),
      title: Row(
        children: [
          if (widget.category.iconUrl != null)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.category.iconUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.work_outline,
                      color: AppColors.primaryGold,
                      size: 20,
                    );
                  },
                ),
              ),
            )
          else
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.work_outline,
                color: AppColors.primaryGold,
                size: 20,
              ),
            ),
          Expanded(
            child: Text(
              widget.category.getLocalizedName(useFrench: true),
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _showFiltersSheet(),
          icon: const Icon(
            Icons.tune,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildHeader(int count, bool isTablet) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.getLocalizedName(useFrench: true),
                  style: (isTablet
                      ? AppTypography.headlineMedium
                      : AppTypography.headlineSmall)
                      .copyWith(
                    color: AppColors.primaryBlack,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count ${count == 1 ? 'service' : 'services'} available',
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
          Container(
            width: isTablet ? 64 : 56,
            height: isTablet ? 64 : 56,
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowMedium,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: widget.category.iconUrl != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.category.iconUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.work_outline,
                    size: isTablet ? 32 : 28,
                    color: AppColors.primaryGold,
                  );
                },
              ),
            )
                : Icon(
              Icons.work_outline,
              size: isTablet ? 32 : 28,
              color: AppColors.primaryGold,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SORT OPTIONS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSortOptions() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildSortChip(
            label: 'Newest',
            isSelected: _sortBy == 'created_at' && _sortOrder == 'desc',
            onTap: () => _applySorting('created_at', 'desc'),
          ),
          _buildSortChip(
            label: 'Price: Low to High',
            isSelected: _sortBy == 'fixed_price' && _sortOrder == 'asc',
            onTap: () => _applySorting('fixed_price', 'asc'),
          ),
          _buildSortChip(
            label: 'Price: High to Low',
            isSelected: _sortBy == 'fixed_price' && _sortOrder == 'desc',
            onTap: () => _applySorting('fixed_price', 'desc'),
          ),
          _buildSortChip(
            label: 'Top Rated',
            isSelected: _sortBy == 'average_rating' && _sortOrder == 'desc',
            onTap: () => _applySorting('average_rating', 'desc'),
          ),
          _buildSortChip(
            label: 'Most Viewed',
            isSelected: _sortBy == 'view_count' && _sortOrder == 'desc',
            onTap: () => _applySorting('view_count', 'desc'),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: AppColors.backgroundWhite,
        selectedColor: AppColors.primaryGold,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryBlack : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppColors.primaryGold : AppColors.borderLight,
          ),
        ),
      ),
    );
  }

  void _applySorting(String sortBy, String sortOrder) {
    setState(() {
      _sortBy = sortBy;
      _sortOrder = sortOrder;
    });
    _loadListings();
  }

  // ═══════════════════════════════════════════════════════════════════
  // LISTING CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildListingCard(ServiceListing listing, bool isTablet) {
    return InkWell(
      onTap: () => _navigateToServiceDetail(listing),
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: listing.mainPhoto != null
                  ? Image.network(
                listing.mainPhoto!,
                height: isTablet ? 220 : 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderImage(isTablet);
                },
              )
                  : _buildPlaceholderImage(isTablet),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    listing.title,
                    style: (isTablet
                        ? AppTypography.titleLarge
                        : AppTypography.titleMedium)
                        .copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    listing.description,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Provider Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryGold.withOpacity(0.1),
                        backgroundImage: listing.provider?.avatarUrl != null
                            ? NetworkImage(listing.provider!.avatarUrl!)
                            : null,
                        child: listing.provider?.avatarUrl == null
                            ? const Icon(
                          Icons.person,
                          size: 16,
                          color: AppColors.primaryGold,
                        )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listing.provider?.fullName ?? 'Unknown Provider',
                              style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (listing.averageRating != null &&
                                listing.averageRating! > 0)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${listing.averageRating!.toStringAsFixed(1)} (${listing.totalReviews} reviews)',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'New provider',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Price & Location
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          listing.priceDisplay,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primaryGold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      // Location
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            listing.city,
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Emergency Badge
                  if (listing.emergencyService)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.emergency,
                              size: 14,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '24/7 Emergency Service',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(bool isTablet) {
    return Container(
      height: isTablet ? 220 : 180,
      width: double.infinity,
      color: AppColors.backgroundLight,
      child: const Icon(
        Icons.image_outlined,
        size: 64,
        color: AppColors.textLight,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 24),
            Text(
              'No Services Yet',
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No services are available in this category at the moment. Check back later!',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.primaryBlack,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Browse Other Categories'),
            ),
          ],
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════════
  void _navigateToServiceDetail(ServiceListing listing) {
    context.read<ServicesProvider>().selectListing(listing);
    Navigator.pushNamed(
      context,
      '/services/detail',
      arguments: {'listingId': listing.id},
    );
  }

  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FiltersBottomSheet(
        categoryId: widget.category.id,
        onApply: (filters) {
          context.read<ServicesProvider>().fetchListings(
            categoryId: widget.category.id,
            refresh: true,
            city: filters['city'],
            minPrice: filters['minPrice'],
            maxPrice: filters['maxPrice'],
            minRating: filters['minRating'],
            sortBy: _sortBy,
            sortOrder: _sortOrder,
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// FILTERS BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════

class _FiltersBottomSheet extends StatefulWidget {
  final int categoryId;
  final Function(Map<String, dynamic>) onApply;

  const _FiltersBottomSheet({
    required this.categoryId,
    required this.onApply,
  });

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
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
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
                  // City Filter
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

                  // Price Range
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

                  // Rating Filter
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

          // Apply Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply({
                    'city': _selectedCity,
                    'minPrice': _priceRange.start,
                    'maxPrice': _priceRange.end,
                    'minRating': _minRating > 0 ? _minRating : null,
                  });
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
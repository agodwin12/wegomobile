// lib/screens/services/search_screen.dart
// WEGO Services Marketplace - Search Screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/services/service_listing_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class ServiceSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const ServiceSearchScreen({Key? key, this.initialQuery}) : super(key: key);

  @override
  State<ServiceSearchScreen> createState() => _ServiceSearchScreenState();
}

class _ServiceSearchScreenState extends State<ServiceSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSearching = false;
  bool _hasSearched = false;

  // Filter state
  String? _selectedCity;
  String? _selectedPricingType;
  double _minPrice = 0;
  double _maxPrice = 100000;
  double _minRating = 0;
  String _sortBy = 'created_at';
  String _sortOrder = 'desc';

  final List<String> _cities = [
    'Douala',
    'Yaoundé',
    'Bafoussam',
    'Bamenda',
    'Garoua',
    'Maroua',
    'Ngaoundéré',
    'Kribi',
    'Limbe',
  ];

  // Recent searches stored in memory
  final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    // Add to recent searches
    if (!_recentSearches.contains(query.trim())) {
      setState(() {
        _recentSearches.insert(0, query.trim());
        if (_recentSearches.length > 5) _recentSearches.removeLast();
      });
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final provider = context.read<ServicesProvider>();
    await provider.fetchListings(
      refresh: true,
      search: query.trim(),
      city: _selectedCity,
      minPrice: _minPrice > 0 ? _minPrice : null,
      maxPrice: _maxPrice < 100000 ? _maxPrice : null,
      minRating: _minRating > 0 ? _minRating : null,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
    );

    if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _hasSearched = false;
      _isSearching = false;
    });
    context.read<ServicesProvider>().fetchListings(refresh: true);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(isTablet),
      body: Column(
        children: [
          _buildFiltersBar(isTablet),
          Expanded(
            child: _hasSearched
                ? _buildSearchResults(isTablet)
                : _buildSearchSuggestions(isTablet),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // APP BAR WITH SEARCH
  // ═══════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar(bool isTablet) {
    return AppBar(
      backgroundColor: AppColors.backgroundWhite,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
      ),
      title: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: AppTypography.bodyMedium,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search services...',
            hintStyle: AppTypography.inputHint,
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.textSecondary,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              onPressed: _clearSearch,
              icon: const Icon(
                Icons.close,
                color: AppColors.textSecondary,
                size: 20,
              ),
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
          ),
          onSubmitted: _performSearch,
          onChanged: (value) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_searchController.text.trim().isNotEmpty) {
              _performSearch(_searchController.text.trim());
            }
          },
          child: Text(
            'Search',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.primaryGold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // FILTERS BAR
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildFiltersBar(bool isTablet) {
    final hasActiveFilters = _selectedCity != null ||
        _selectedPricingType != null ||
        _minPrice > 0 ||
        _maxPrice < 100000 ||
        _minRating > 0;

    return Container(
      color: AppColors.backgroundWhite,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          // Filter button
          GestureDetector(
            onTap: () => _showFiltersSheet(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: hasActiveFilters
                    ? AppColors.primaryGold
                    : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasActiveFilters
                      ? AppColors.primaryGold
                      : AppColors.borderLight,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune,
                    size: 16,
                    color: hasActiveFilters
                        ? AppColors.primaryBlack
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasActiveFilters ? 'Filters •' : 'Filters',
                    style: AppTypography.labelMedium.copyWith(
                      color: hasActiveFilters
                          ? AppColors.primaryBlack
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Sort chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip('Newest', 'created_at', 'desc'),
                  const SizedBox(width: 8),
                  _buildSortChip('Top Rated', 'average_rating', 'desc'),
                  const SizedBox(width: 8),
                  _buildSortChip('Price ↑', 'fixed_price', 'asc'),
                  const SizedBox(width: 8),
                  _buildSortChip('Price ↓', 'fixed_price', 'desc'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String sortBy, String sortOrder) {
    final isSelected = _sortBy == sortBy && _sortOrder == sortOrder;

    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = sortBy;
          _sortOrder = sortOrder;
        });
        if (_hasSearched && _searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold.withOpacity(0.15)
              : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? AppColors.primaryGold : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SEARCH SUGGESTIONS (shown before searching)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSearchSuggestions(bool isTablet) {
    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        final categories = provider.parentCategories;

        return ListView(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          children: [
            // Recent searches
            if (_recentSearches.isNotEmpty) ...[
              Text(
                'Recent Searches',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ..._recentSearches.map((query) => _buildRecentSearchTile(query)),
              const SizedBox(height: 24),
            ],

            // Popular categories
            if (categories.isNotEmpty) ...[
              Text(
                'Browse by Category',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.take(8).map((category) {
                  return GestureDetector(
                    onTap: () {
                      _searchController.text =
                          category.getLocalizedName(useFrench: true);
                      _performSearch(
                          category.getLocalizedName(useFrench: true));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowLight,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.category_outlined,
                            size: 16,
                            color: AppColors.primaryGold,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category.getLocalizedName(useFrench: true),
                            style: AppTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Popular searches
            Text(
              'Popular Searches',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Plombier',
                'Électricien',
                'Nettoyage',
                'Coiffeur',
                'Menuisier',
                'Peintre',
                'Maçon',
                'Mécanicien',
              ].map((term) {
                return GestureDetector(
                  onTap: () {
                    _searchController.text = term;
                    _performSearch(term);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryGold.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      term,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentSearchTile(String query) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.history,
          size: 18,
          color: AppColors.textSecondary,
        ),
      ),
      title: Text(
        query,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: IconButton(
        onPressed: () {
          setState(() => _recentSearches.remove(query));
        },
        icon: const Icon(
          Icons.close,
          size: 16,
          color: AppColors.textLight,
        ),
      ),
      onTap: () {
        _searchController.text = query;
        _performSearch(query);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SEARCH RESULTS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSearchResults(bool isTablet) {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        if (provider.listingsError != null) {
          return _buildErrorState(provider.listingsError!, isTablet);
        }

        final results = provider.listings;

        if (results.isEmpty) {
          return _buildNoResultsState(isTablet);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 24 : 16,
                isTablet ? 16 : 12,
                isTablet ? 24 : 16,
                0,
              ),
              child: Text(
                '${results.length} result${results.length == 1 ? '' : 's'} for "${_searchController.text}"',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final listing = results[index];
                  return _buildListingCard(listing, isTablet);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListingCard(ServiceListing listing, bool isTablet) {
    return GestureDetector(
      onTap: () {
        context.read<ServicesProvider>().selectListing(listing);
        Navigator.pushNamed(
          context,
          '/services/detail',
          arguments: {'listingId': listing.id},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: listing.photos.isNotEmpty
                  ? Image.network(
                listing.photos.first,
                width: isTablet ? 120 : 100,
                height: isTablet ? 120 : 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(isTablet),
              )
                  : _buildPlaceholder(isTablet),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        listing.categoryName,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Title
                    Text(
                      listing.title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Provider name
                    Text(
                      listing.provider?.fullName ?? 'Provider',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Price and rating row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          listing.priceDisplay,
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.primaryGold,
                            fontWeight: FontWeight.w800,
                          ),
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
                                listing.averageRating!.toStringAsFixed(1),
                                style: AppTypography.labelSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Arrow
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isTablet) {
    return Container(
      width: isTablet ? 120 : 100,
      height: isTablet ? 120 : 100,
      color: AppColors.backgroundLight,
      child: const Icon(
        Icons.image_outlined,
        color: AppColors.textLight,
        size: 32,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATES
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildNoResultsState(bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 56,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No results found',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or remove filters',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Clear Search'),
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

  Widget _buildErrorState(String message, bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
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
              onPressed: () => _performSearch(_searchController.text),
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
  // FILTERS BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════════
  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchFiltersSheet(
        selectedCity: _selectedCity,
        selectedPricingType: _selectedPricingType,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        minRating: _minRating,
        cities: _cities,
        onApply: (city, pricingType, minPrice, maxPrice, minRating) {
          setState(() {
            _selectedCity = city;
            _selectedPricingType = pricingType;
            _minPrice = minPrice;
            _maxPrice = maxPrice;
            _minRating = minRating;
          });
          if (_searchController.text.isNotEmpty) {
            _performSearch(_searchController.text);
          }
        },
        onReset: () {
          setState(() {
            _selectedCity = null;
            _selectedPricingType = null;
            _minPrice = 0;
            _maxPrice = 100000;
            _minRating = 0;
          });
          if (_searchController.text.isNotEmpty) {
            _performSearch(_searchController.text);
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// FILTERS BOTTOM SHEET WIDGET
// ═══════════════════════════════════════════════════════════════════════

class _SearchFiltersSheet extends StatefulWidget {
  final String? selectedCity;
  final String? selectedPricingType;
  final double minPrice;
  final double maxPrice;
  final double minRating;
  final List<String> cities;
  final Function(
      String? city,
      String? pricingType,
      double minPrice,
      double maxPrice,
      double minRating,
      ) onApply;
  final VoidCallback onReset;

  const _SearchFiltersSheet({
    required this.selectedCity,
    required this.selectedPricingType,
    required this.minPrice,
    required this.maxPrice,
    required this.minRating,
    required this.cities,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<_SearchFiltersSheet> {
  late String? _selectedCity;
  late String? _selectedPricingType;
  late RangeValues _priceRange;
  late double _minRating;

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.selectedCity;
    _selectedPricingType = widget.selectedPricingType;
    _priceRange = RangeValues(widget.minPrice, widget.maxPrice);
    _minRating = widget.minRating;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      _selectedCity = null;
                      _selectedPricingType = null;
                      _priceRange = const RangeValues(0, 100000);
                      _minRating = 0;
                    });
                  },
                  child: Text(
                    'Reset All',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // City
                  Text(
                    'City',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.cities.map((city) {
                      final isSelected = _selectedCity == city;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedCity = isSelected ? null : city;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryGold
                                : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Text(
                            city,
                            style: AppTypography.labelMedium.copyWith(
                              color: isSelected
                                  ? AppColors.primaryBlack
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Pricing type
                  Text(
                    'Pricing Type',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPricingChip('Hourly', 'hourly'),
                      const SizedBox(width: 8),
                      _buildPricingChip('Fixed', 'fixed'),
                      const SizedBox(width: 8),
                      _buildPricingChip('Negotiable', 'negotiable'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Price range
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Price Range (FCFA)',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_priceRange.start.toInt()} - ${_priceRange.end.toInt()}',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 100000,
                    divisions: 20,
                    activeColor: AppColors.primaryGold,
                    inactiveColor: AppColors.borderLight,
                    labels: RangeLabels(
                      '${_priceRange.start.toInt()}',
                      '${_priceRange.end.toInt()}',
                    ),
                    onChanged: (values) => setState(() => _priceRange = values),
                  ),

                  const SizedBox(height: 24),

                  // Minimum rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Minimum Rating',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _minRating > 0
                            ? '${_minRating.toStringAsFixed(1)} ★'
                            : 'Any',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _minRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    activeColor: AppColors.primaryGold,
                    inactiveColor: AppColors.borderLight,
                    label: _minRating > 0
                        ? '${_minRating.toStringAsFixed(1)} ★'
                        : 'Any',
                    onChanged: (value) => setState(() => _minRating = value),
                  ),
                ],
              ),
            ),
          ),

          // Apply button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onApply(
                    _selectedCity,
                    _selectedPricingType,
                    _priceRange.start,
                    _priceRange.end,
                    _minRating,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: AppColors.primaryBlack,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Apply Filters',
                  style: AppTypography.buttonMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingChip(String label, String value) {
    final isSelected = _selectedPricingType == value;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedPricingType = isSelected ? null : value;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: isSelected ? AppColors.primaryBlack : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
// lib/screens/services/category_listings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Category Listings Screen
// Overflow-fixed + aligned to AppColors / AppTypography
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../utils/services_post_flow.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/services/category_model.dart';
import '../../models/services/service_listing_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import '../../widgets/services/service_card_widget.dart';

// ─── Local design tokens ──────────────────────────────────────────────────────
const _kPrimary      = AppColors.primaryGold;
const _kPrimaryDark  = AppColors.primaryGoldDark;
const _kPrimaryLight = Color(0xFFFFFDE7);
const _kPrimaryMid   = Color(0xFFFFECB3);
Color get _kSurface => AppColors.backgroundWhite;
Color get _kPageBg => AppColors.backgroundLight;
Color get _kInputBg => AppColors.inputBackground;
Color get _kBorder => AppColors.borderLight;
Color get _kTextPrimary => AppColors.textPrimary;
Color get _kTextSecond => AppColors.textSecondary;
Color get _kTextLight => AppColors.textLight;
const _kError        = AppColors.error;

const double _rLg   = 16.0;
const double _rXl   = 24.0;
const double _rPill = 999.0;

const List<BoxShadow> _kCardShadow = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
];
const List<BoxShadow> _kBottomShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -3)),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class CategoryListingsScreen extends StatefulWidget {
  final ServiceCategory category;

  const CategoryListingsScreen({
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  State<CategoryListingsScreen> createState() =>
      _CategoryListingsScreenState();
}

class _CategoryListingsScreenState extends State<CategoryListingsScreen> {
  final ScrollController _scrollController = ScrollController();

  int?   _selectedSubcategoryId;
  String _sortBy    = 'created_at';
  String _sortOrder = 'desc';

  static const _sorts = [
    _SortOption('Plus récent',  'created_at',     'desc'),
    _SortOption('Prix ↑',       'fixed_price',    'asc'),
    _SortOption('Prix ↓',       'fixed_price',    'desc'),
    _SortOption('Mieux noté',   'average_rating', 'desc'),
    _SortOption('Populaire',    'view_count',      'desc'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    if (!mounted) return;
    final provider = context.read<ServicesProvider>();
    await provider.fetchSubcategories(widget.category.id);
    await _fetchListings(refresh: true);
  }

  Future<void> _fetchListings({bool refresh = false}) async {
    if (!mounted) return;
    await context.read<ServicesProvider>().fetchListings(
      categoryId: _selectedSubcategoryId ?? widget.category.id,
      refresh: refresh,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.85) {
      final provider = context.read<ServicesProvider>();
      if (!provider.listingsLoading && provider.hasMoreListings) {
        _fetchListings();
      }
    }
  }

  void _applySort(_SortOption opt) {
    if (_sortBy == opt.sortBy && _sortOrder == opt.order) return;
    setState(() {
      _sortBy    = opt.sortBy;
      _sortOrder = opt.order;
    });
    _fetchListings(refresh: true);
  }

  void _selectSubcategory(int? id) {
    if (_selectedSubcategoryId == id) return;
    setState(() => _selectedSubcategoryId = id);
    _fetchListings(refresh: true);
  }

  void _goToDetail(ServiceListing listing) {
    context.read<ServicesProvider>().selectListing(listing);
    Navigator.pushNamed(
      context,
      '/services/detail',
      arguments: {'listingId': listing.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white icons on gold header
      child: Scaffold(
        backgroundColor: _kPageBg,
        body: RefreshIndicator(
          color: _kPrimary,
          onRefresh: () => _fetchListings(refresh: true),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              _buildHeroHeader(),
              _buildSubcategoryChips(),
              _buildSortChips(),
              _buildCountLabel(),
              _buildGrid(),
              _buildPaginationLoader(),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero header ───────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 160,
      // FIX: gold background for the collapsed bar, not hardcoded green
      backgroundColor: _kPrimary,
      // FIX: use light overlay style so back-button icon is white on gold
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded,
              color: Colors.black87, size: 20),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: _showFiltersSheet,
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(_rPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune_rounded,
                    color: Colors.black87, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Filtres',
                  style: AppTypography.labelSmall
                      .copyWith(color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          // FIX: gold→goldDark gradient (correct brand) with dark text
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kPrimary, _kPrimaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                // Decorative circles — ClipRect prevents them from causing
                // overflow assertions on the SliverAppBar
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  right: 60,
                  bottom: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.04),
                    ),
                  ),
                ),

                // Content row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Row(
                    children: [
                      // Icon circle — fixed 64×64
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.black.withOpacity(0.2),
                              width: 2),
                        ),
                        child: widget.category.iconUrl != null
                            ? ClipOval(
                          child: Image.network(
                            widget.category.iconUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _heroEmoji(),
                          ),
                        )
                            : _heroEmoji(),
                      ),

                      const SizedBox(width: 16),

                      // Name + count — Expanded to prevent overflow on long names
                      Expanded(
                        child: Consumer<ServicesProvider>(
                          builder: (_, provider, __) {
                            final count = provider.listings.length;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // FIX: max 2 lines + ellipsis for long category names
                                Text(
                                  widget.category
                                      .getLocalizedName(useFrench: true),
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    // FIX: dark text on gold (correct contrast)
                                    color: Colors.black87,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$count service${count == 1 ? '' : 's'} disponible${count == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroEmoji() {
    return Center(
      child: Text(
        _categoryEmoji(widget.category.nameEn),
        style: const TextStyle(fontSize: 28),
      ),
    );
  }

  // ── Subcategory chips ─────────────────────────────────────────────────────
  Widget _buildSubcategoryChips() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        final subs = provider.subcategories ?? [];
        if (subs.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Container(
            color: _kSurface,
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
            child: SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: subs.length + 1, // +1 for "Tous"
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _SubChip(
                      label: 'Tous',
                      selected: _selectedSubcategoryId == null,
                      onTap: () => _selectSubcategory(null),
                    );
                  }
                  final sub = subs[i - 1];
                  return _SubChip(
                    label: sub.getLocalizedName(useFrench: true),
                    selected: _selectedSubcategoryId == sub.id,
                    onTap: () => _selectSubcategory(sub.id),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Sort chips ────────────────────────────────────────────────────────────
  Widget _buildSortChips() {
    return SliverToBoxAdapter(
      child: Container(
        color: _kPageBg,
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
        child: SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sorts.length,
            itemBuilder: (_, i) {
              final opt      = _sorts[i];
              final selected = _sortBy == opt.sortBy && _sortOrder == opt.order;
              return _SortChip(
                label: opt.label,
                selected: selected,
                onTap: () => _applySort(opt),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Count label ───────────────────────────────────────────────────────────
  Widget _buildCountLabel() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        final count = provider.listings.length;
        if (count == 0) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '$count résultat${count == 1 ? '' : 's'}',
              style: AppTypography.labelMedium
                  .copyWith(color: _kTextSecond),
            ),
          ),
        );
      },
    );
  }

  // ── 2-column grid ─────────────────────────────────────────────────────────
  Widget _buildGrid() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        // Loading
        if (provider.listingsLoading && provider.listings.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                        color: _kPrimary, strokeWidth: 2),
                    const SizedBox(height: 16),
                    Text('Chargement des services…',
                        style: AppTypography.bodySmall
                            .copyWith(color: _kTextLight)),
                  ],
                ),
              ),
            ),
          );
        }

        // Error
        if (provider.listingsError != null && provider.listings.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 48, color: _kTextLight),
                  const SizedBox(height: 12),
                  Text(
                    provider.listingsError!,
                    style: AppTypography.bodySmall
                        .copyWith(color: _kTextSecond),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _fetchListings(refresh: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: _kTextPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_rLg)),
                    ),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        // Empty
        if (provider.listings.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 56, color: _kTextLight),
                  const SizedBox(height: 16),
                  Text('Aucun service ici',
                      style: AppTypography.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Soyez le premier à proposer un service dans cette catégorie !',
                    style: AppTypography.bodySmall
                        .copyWith(color: _kTextSecond),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () =>
                        startServicePostFlow(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: _kTextPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_rLg)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Publier un service'),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverGrid(
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
                  (_, i) => ServiceGridCard(
                listing: provider.listings[i],
                onTap: () => _goToDetail(provider.listings[i]),
              ),
              childCount: provider.listings.length,
            ),
          ),
        );
      },
    );
  }

  // ── Pagination loader ─────────────────────────────────────────────────────
  Widget _buildPaginationLoader() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        if (!provider.listingsLoading || provider.listings.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(
                  color: _kPrimary, strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  // ── Filters sheet ─────────────────────────────────────────────────────────
  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FiltersSheet(
        onApply: ({
          String? city,
          double? minPrice,
          double? maxPrice,
          double? minRating,
        }) {
          context.read<ServicesProvider>().fetchListings(
            categoryId: _selectedSubcategoryId ?? widget.category.id,
            refresh: true,
            city: city,
            minPrice: minPrice,
            maxPrice: maxPrice,
            minRating: minRating,
            sortBy: _sortBy,
            sortOrder: _sortOrder,
          );
        },
      ),
    );
  }

  String _categoryEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('plomb') || n.contains('plumb')) return '🔧';
    if (n.contains('elec')) return '⚡';
    if (n.contains('nettoy') || n.contains('clean')) return '🧹';
    if (n.contains('coiff') || n.contains('hair')) return '✂️';
    if (n.contains('menuis') || n.contains('carpen')) return '🪚';
    if (n.contains('paint') || n.contains('peintr')) return '🎨';
    if (n.contains('mec') || n.contains('auto')) return '🚗';
    if (n.contains('garden') || n.contains('jardin')) return '🌿';
    return '🛠️';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBCATEGORY CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _SubChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : _kSurface,
          borderRadius: BorderRadius.circular(_rPill),
          border: Border.all(
            color: selected ? _kPrimary : _kBorder,
          ),
          boxShadow: selected ? _kCardShadow : null,
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            // FIX: dark text on gold chip (correct contrast)
            color: selected ? _kTextPrimary : _kTextSecond,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SORT CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kPrimaryLight : _kSurface,
          borderRadius: BorderRadius.circular(_rPill),
          border: Border.all(
            color: selected ? _kPrimary : _kBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: selected ? _kPrimaryDark : _kTextSecond,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SORT OPTION
// ─────────────────────────────────────────────────────────────────────────────
class _SortOption {
  final String label;
  final String sortBy;
  final String order;
  const _SortOption(this.label, this.sortBy, this.order);
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTERS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _FiltersSheet extends StatefulWidget {
  final Function({
  String? city,
  double? minPrice,
  double? maxPrice,
  double? minRating,
  }) onApply;

  const _FiltersSheet({required this.onApply});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  String? _city;
  RangeValues _price = const RangeValues(0, 100000);
  double _minRating  = 0;

  static const _cities = [
    'Douala', 'Yaoundé', 'Bafoussam',
    'Bamenda', 'Garoua', 'Kribi', 'Limbé',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_rXl)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _kBorder,
              borderRadius: BorderRadius.circular(_rPill),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filtres', style: AppTypography.headlineSmall),
                TextButton(
                  onPressed: () => setState(() {
                    _city      = null;
                    _price     = const RangeValues(0, 100000);
                    _minRating = 0;
                  }),
                  child: Text(
                    'Réinitialiser',
                    style: AppTypography.labelMedium
                        .copyWith(color: _kError),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: _kBorder),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // City
                  Text('Ville', style: AppTypography.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cities.map((c) {
                      final sel = _city == c;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _city = sel ? null : c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? _kPrimary : _kInputBg,
                            borderRadius: BorderRadius.circular(_rPill),
                            border: Border.all(
                              color: sel ? _kPrimary : _kBorder,
                            ),
                          ),
                          child: Text(
                            c,
                            style: AppTypography.labelMedium.copyWith(
                              // FIX: dark text on gold selected chip
                              color: sel ? _kTextPrimary : _kTextSecond,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Price range
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // FIX: Flexible prevents label from pushing value off-screen
                      Flexible(
                        child: Text(
                          'Fourchette de prix (XAF)',
                          style: AppTypography.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_price.start.toInt()} – ${_price.end.toInt()}',
                        style: AppTypography.labelMedium
                            .copyWith(color: _kPrimary),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _price,
                    min: 0,
                    max: 100000,
                    divisions: 20,
                    activeColor: _kPrimary,
                    inactiveColor: _kPrimaryMid,
                    onChanged: (v) => setState(() => _price = v),
                  ),

                  const SizedBox(height: 24),

                  // Min rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Note minimale',
                          style: AppTypography.titleMedium),
                      Text(
                        _minRating > 0
                            ? '${_minRating.toStringAsFixed(1)} ★'
                            : 'Toutes',
                        style: AppTypography.labelMedium
                            .copyWith(color: _kPrimary),
                      ),
                    ],
                  ),
                  Slider(
                    value: _minRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    activeColor: _kPrimary,
                    inactiveColor: _kPrimaryMid,
                    onChanged: (v) => setState(() => _minRating = v),
                  ),
                ],
              ),
            ),
          ),

          // Apply button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onApply(
                    city:      _city,
                    minPrice:  _price.start > 0 ? _price.start : null,
                    maxPrice:  _price.end < 100000 ? _price.end : null,
                    minRating: _minRating > 0 ? _minRating : null,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: _kTextPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_rLg)),
                ),
                child: Text('Appliquer les filtres',
                    style: AppTypography.buttonLarge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
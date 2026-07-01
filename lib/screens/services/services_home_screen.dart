// lib/screens/services/services_home_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Services Marketplace — Home Screen
// Overflow-fixed + aligned to AppColors / AppTypography
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/services/category_model.dart';
import '../../models/services/service_listing_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import '../../widgets/services/promo_banner_widget.dart';
import '../../widgets/services/service_card_widget.dart';

// ─── Convenience aliases so the body stays readable ──────────────────────────
// Primary accent used throughout this screen
const _kPrimary      = AppColors.primaryGold;
const _kPrimaryLight = Color(0xFFFFFDE7); // soft yellow tint
const _kPrimaryMid   = Color(0xFFFFECB3); // medium yellow tint
const _kSurface      = AppColors.backgroundWhite;
const _kPageBg       = AppColors.backgroundLight;
const _kInputBg      = AppColors.inputBackground;
const _kBorder       = AppColors.borderLight;
const _kTextPrimary  = AppColors.textPrimary;
const _kTextSecond   = AppColors.textSecondary;
const _kTextLight    = AppColors.textLight;
const _kError        = AppColors.error;
const _kShadow       = Color(0x14000000); // ~8 % black

// ─── Radius constants ─────────────────────────────────────────────────────────
const double _rSm   = 8.0;
const double _rMd   = 12.0;
const double _rLg   = 16.0;
const double _rXl   = 24.0;
const double _rPill = 999.0;

class ServicesHomeScreen extends StatefulWidget {
  const ServicesHomeScreen({Key? key, String? accessToken, Map<String, dynamic>? user})
      : super(key: key);

  @override
  State<ServicesHomeScreen> createState() => _ServicesHomeScreenState();
}

class _ServicesHomeScreenState extends State<ServicesHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _userLocation = 'Douala, Cameroun';
  bool _appBarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final city = prefs.getString('city');
      if (city != null && city.isNotEmpty) _userLocation = '$city, Cameroun';
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

  void _onScroll() {
    final collapsed = _scrollController.offset > 60;
    if (collapsed != _appBarCollapsed) setState(() => _appBarCollapsed = collapsed);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────
  void _goToSearch() => Navigator.pushNamed(context, '/services/search',
      arguments: {'query': _searchController.text.trim()});

  void _goToCategory(ServiceCategory cat) {
    context.read<ServicesProvider>().selectCategory(cat);
    Navigator.pushNamed(context, '/services/category-listings',
        arguments: {'category': cat});
  }

  void _goToDetail(ServiceListing listing) {
    context.read<ServicesProvider>().selectListing(listing);
    Navigator.pushNamed(context, '/services/detail',
        arguments: {'listingId': listing.id});
  }

  void _goToAllCategories() => Navigator.pushNamed(context, '/services/categories');
  void _goToPostService()   => Navigator.pushNamed(context, '/services/listing-plan');
  void _goToMyListings()    => Navigator.pushNamed(context, '/services/my-listings');

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kPageBg,
        body: RefreshIndicator(
          color: _kPrimary,
          onRefresh: _loadData,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Sticky header ────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                floating: false,
                backgroundColor: _kSurface,
                elevation: _appBarCollapsed ? 2 : 0,
                shadowColor: _kShadow,
                automaticallyImplyLeading: false,
                // FIX: use a fixed toolbarHeight; never use expandedHeight when
                // flexibleSpace is conditionally null — it causes a blank sliver.
                toolbarHeight: 64,
                title: _buildHeaderRow(),
                titleSpacing: 0,
                actions: [
                  _NotificationBell(
                    onTap: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                  const SizedBox(width: 12),
                ],
              ),

              // ── Search bar ───────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildSearchBar()),

              // ── Promo banner ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: PromoBannerWidget(
                    banners: [
                      PromoBanner(
                        title: 'Jusqu\'à 30% de réduction !',
                        subtitle: 'Profitez de nos offres chaque jour',
                        ctaLabel: 'Voir',
                        emoji: '🛒',
                        bgColor: _kPrimaryLight,
                        textColor: _kTextPrimary,
                        onTap: _goToAllCategories,
                      ),
                      PromoBanner(
                        title: 'Nouveaux prestataires',
                        subtitle: 'Des pros qualifiés près de chez vous',
                        ctaLabel: 'Explorer',
                        emoji: '⚡',
                        bgColor: AppColors.infoLight,
                        textColor: _kTextPrimary,
                        onTap: _goToAllCategories,
                      ),
                      PromoBanner(
                        title: 'Urgence 24h/24',
                        subtitle: 'De l\'aide quand vous en avez besoin',
                        ctaLabel: 'Trouver',
                        emoji: '🔧',
                        bgColor: AppColors.warningLight,
                        textColor: _kTextPrimary,
                        onTap: _goToAllCategories,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Categories ───────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildCategoriesSection()),

              // ── Quick actions ────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildQuickActions()),

              // ── Best Deal ────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildBestDealSection()),

              // ── Available Services header ────────────────────────────────
              SliverToBoxAdapter(child: _buildAvailableHeader()),

              // ── 2-column grid ────────────────────────────────────────────
              _buildServicesGrid(),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
        floatingActionButton: _buildFab(),
      ),
    );
  }

  // ── Header row (always visible in SliverAppBar title) ───────────────────────
  // FIX: was split between flexibleSpace/title causing a blank 64 px gap when
  // _appBarCollapsed toggled. Now it's always the title child, just changes layout.
  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, size: 18, color: _kPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: _appBarCollapsed
                ? Text(_userLocation,
                style: AppTypography.titleMedium,
                overflow: TextOverflow.ellipsis)
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Localisation',
                    style: AppTypography.labelSmall
                        .copyWith(color: _kTextLight)),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _userLocation,
                        style: AppTypography.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: _kTextPrimary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          // FIX: Expanded wraps the search field properly
          Expanded(
            child: GestureDetector(
              onTap: _goToSearch,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _kInputBg,
                  borderRadius: BorderRadius.circular(_rLg),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(Icons.search_rounded,
                        color: _kTextLight, size: 22),
                    const SizedBox(width: 10),
                    // FIX: Flexible prevents text from overflowing the row
                    Flexible(
                      child: Text(
                        'Rechercher un service…',
                        style: AppTypography.bodyMedium
                            .copyWith(color: _kTextLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filter button — fixed size, never Expanded
          GestureDetector(
            onTap: _showFiltersSheet,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(_rLg),
              ),
              child: const Icon(Icons.tune_rounded,
                  color: _kTextPrimary, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ── Categories ────────────────────────────────────────────────────────────
  Widget _buildCategoriesSection() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        final cats = provider.parentCategories;
        if (provider.categoriesLoading && cats.isEmpty) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(
                  color: _kPrimary, strokeWidth: 2),
            ),
          );
        }
        if (cats.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _SectionHeader(
                title: 'Catégories',
                onSeeAll: _goToAllCategories,
              ),
            ),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: cats.length > 8 ? 8 : cats.length,
                itemBuilder: (_, i) =>
                    _CategoryChip(category: cats[i], onTap: _goToCategory),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Quick actions ─────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 2 items, 1 gap of 10 px
          final itemWidth = (constraints.maxWidth - 10) / 2;
          return Row(
            children: [
              _QuickActionCard(
                width: itemWidth,
                icon: Icons.add_circle_outline_rounded,
                label: 'Publier une annonce',
                color: _kPrimary,
                textColor: _kTextPrimary,
                onTap: _goToPostService,
              ),
              const SizedBox(width: 10),
              _QuickActionCard(
                width: itemWidth,
                icon: Icons.list_alt_rounded,
                label: 'Mes annonces',
                color: AppColors.info,
                textColor: Colors.white,
                onTap: _goToMyListings,
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Best Deal ─────────────────────────────────────────────────────────────
  Widget _buildBestDealSection() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        final listings = provider.listings;
        if (listings.isEmpty) return const SizedBox.shrink();
        final featured = listings.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: _SectionHeader(
                title: 'Meilleures offres',
                onSeeAll: _goToAllCategories,
              ),
            ),
            SizedBox(
              // FIX: explicit height for the horizontal list so it never
              // expands to intrinsic (which would break inside a Column/Sliver).
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: featured.length,
                itemBuilder: (_, i) => ServiceFeaturedCard(
                  listing: featured[i],
                  onTap: () => _goToDetail(featured[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Available Services header ─────────────────────────────────────────────
  Widget _buildAvailableHeader() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        final count = provider.listings.length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: _SectionHeader(
            title: count > 0
                ? 'Services disponibles ($count)'
                : 'Services disponibles',
          ),
        );
      },
    );
  }

  // ── 2-column grid ─────────────────────────────────────────────────────────
  Widget _buildServicesGrid() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        if (provider.listingsLoading && provider.listings.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
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

        if (provider.listingsError != null && provider.listings.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 48, color: _kTextLight),
                  const SizedBox(height: 12),
                  Text(provider.listingsError!,
                      style: AppTypography.bodySmall
                          .copyWith(color: _kTextSecond),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
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

        final listings = provider.listings;

        if (listings.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 56, color: _kTextLight),
                  const SizedBox(height: 16),
                  Text('Aucun service pour le moment',
                      style: AppTypography.titleMedium),
                  const SizedBox(height: 6),
                  Text('Soyez le premier à publier un service !',
                      style: AppTypography.bodySmall
                          .copyWith(color: _kTextSecond),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _goToPostService,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: _kTextPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_rLg)),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Publier un service'),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
                  (_, i) => ServiceGridCard(
                listing: listings[i],
                onTap: () => _goToDetail(listings[i]),
              ),
              childCount: listings.length,
            ),
          ),
        );
      },
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────
  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _goToPostService,
      backgroundColor: _kPrimary,
      foregroundColor: _kTextPrimary,
      elevation: 3,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        'Publier',
        style: AppTypography.buttonMedium,
      ),
    );
  }

  // ── Filters bottom sheet ──────────────────────────────────────────────────
  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FiltersSheet(
        onApply: (city, minPrice, maxPrice, minRating) {
          context.read<ServicesProvider>().fetchListings(
            refresh: true,
            city: city,
            minPrice: minPrice,
            maxPrice: maxPrice,
            minRating: minRating,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // FIX: Flexible prevents the title from overflowing when long
        Flexible(
          child: Text(
            title,
            style: AppTypography.titleLarge,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onSeeAll != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'Voir tout',
              style: AppTypography.labelMedium.copyWith(color: _kPrimary),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION BELL
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationBell extends StatelessWidget {
  final VoidCallback onTap;
  const _NotificationBell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _kInputBg,
          borderRadius: BorderRadius.circular(_rMd),
          border: Border.all(color: _kBorder),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.notifications_outlined,
                color: _kTextPrimary, size: 22),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _kError,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY CHIP  (icon circle + label)
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final ServiceCategory category;
  final void Function(ServiceCategory) onTap;

  const _CategoryChip({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(category),
      child: SizedBox(
        // FIX: explicit SizedBox width replaces Container with unconstrained
        // width, which caused overflow in tight horizontal lists
        width: 70,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kPrimaryMid, width: 1.5),
                ),
                child: category.iconUrl != null
                    ? ClipOval(
                  child: Image.network(
                    category.iconUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _fallbackIcon(category.nameEn),
                  ),
                )
                    : _fallbackIcon(category.nameEn),
              ),
              const SizedBox(height: 6),
              // FIX: explicit width forces text wrapping instead of overflowing
              SizedBox(
                width: 70,
                child: Text(
                  category.getLocalizedName(useFrench: true),
                  style: AppTypography.labelSmall
                      .copyWith(color: _kTextPrimary),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon(String name) => Center(
    child: Text(_categoryEmoji(name),
        style: const TextStyle(fontSize: 24)),
  );

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
// QUICK ACTION CARD
// FIX: removed Expanded — items now receive an explicit width computed by
// LayoutBuilder in the parent so they never request unbounded horizontal space.
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(_rLg),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            // FIX: constrain text to the card width so it wraps rather than overflows
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.3,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTERS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _FiltersSheet extends StatefulWidget {
  final Function(String? city, double? minPrice, double? maxPrice,
      double? minRating) onApply;

  const _FiltersSheet({required this.onApply});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  String? _city;
  RangeValues _price = const RangeValues(0, 100000);
  double _minRating = 0;

  static const _cities = [
    'Douala', 'Yaoundé', 'Bafoussam',
    'Bamenda', 'Garoua', 'Kribi', 'Limbé',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      // FIX: clamp sheet height so it never overflows on small screens
      height: MediaQuery.of(context).size.height * 0.68,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(_rXl)),
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
                    _city = null;
                    _price = const RangeValues(0, 100000);
                    _minRating = 0;
                  }),
                  child: Text('Réinitialiser',
                      style: AppTypography.labelMedium
                          .copyWith(color: _kError)),
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
                  Text('Ville',
                      style: AppTypography.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cities.map((c) {
                      final sel = _city == c;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _city = sel ? null : c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? _kPrimary : _kInputBg,
                            borderRadius:
                            BorderRadius.circular(_rPill),
                            border: Border.all(
                              color: sel ? _kPrimary : _kBorder,
                            ),
                          ),
                          child: Text(
                            c,
                            style: AppTypography.labelMedium.copyWith(
                              color: sel
                                  ? _kTextPrimary
                                  : _kTextSecond,
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
                      // FIX: Flexible prevents this row from overflowing on
                      // narrow screens when the price label is long
                      const Flexible(
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
                    _city,
                    _price.start > 0 ? _price.start : null,
                    _price.end < 100000 ? _price.end : null,
                    _minRating > 0 ? _minRating : null,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: _kTextPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_rLg),
                  ),
                ),
                child: Text(
                  'Appliquer les filtres',
                  style: AppTypography.buttonLarge,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
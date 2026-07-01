// lib/screens/services/search_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Services Search Screen
// Overflow-fixed + aligned to AppColors / AppTypography
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
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
const _kPrimaryLight = Color(0xFFFFFDE7);
const _kPrimaryMid   = Color(0xFFFFECB3);
const _kPrimaryDark  = AppColors.primaryGoldDark;
const _kSurface      = AppColors.backgroundWhite;
const _kPageBg       = AppColors.backgroundLight;
const _kInputBg      = AppColors.inputBackground;
const _kBorder       = AppColors.borderLight;
const _kTextPrimary  = AppColors.textPrimary;
const _kTextSecond   = AppColors.textSecondary;
const _kTextLight    = AppColors.textLight;
const _kError        = AppColors.error;

const double _rMd   = 12.0;
const double _rLg   = 16.0;
const double _rXl   = 24.0;
const double _rPill = 999.0;

const List<BoxShadow> _kCardShadow = [
  BoxShadow(color: Color(0x12000000), blurRadius: 6, offset: Offset(0, 2)),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ServiceSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const ServiceSearchScreen({Key? key, this.initialQuery}) : super(key: key);

  @override
  State<ServiceSearchScreen> createState() => _ServiceSearchScreenState();
}

class _ServiceSearchScreenState extends State<ServiceSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _hasSearched = false;
  bool _isSearching = false;

  String _sortBy    = 'created_at';
  String _sortOrder = 'desc';

  String? _selectedCity;
  double? _minPrice;
  double? _maxPrice;
  double? _minRating;

  final List<String> _recentSearches = [];

  static const _popular = [
    'Plombier', 'Électricien', 'Nettoyage', 'Coiffeur',
    'Menuisier', 'Peintre', 'Maçon', 'Mécanicien',
    'Informatique', 'Jardinage',
  ];

  static const _sorts = [
    _SortOpt('Plus récent',   'created_at',     'desc'),
    _SortOpt('Mieux noté',   'average_rating', 'desc'),
    _SortOpt('Prix ↑',       'fixed_price',    'asc'),
    _SortOpt('Prix ↓',       'fixed_price',    'desc'),
    _SortOpt('Populaire',    'view_count',     'desc'),
  ];

  bool get _hasActiveFilters =>
      _selectedCity != null ||
          _minPrice != null ||
          _maxPrice != null ||
          _minRating != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _search(widget.initialQuery!));
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Search logic ──────────────────────────────────────────────────────────
  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    _focusNode.unfocus();

    _recentSearches.remove(q);
    _recentSearches.insert(0, q);
    if (_recentSearches.length > 6) _recentSearches.removeLast();

    setState(() {
      _hasSearched = true;
      _isSearching = true;
    });

    await context.read<ServicesProvider>().fetchListings(
      refresh: true,
      search: q,
      city: _selectedCity,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      minRating: _minRating,
      sortBy: _sortBy,
      sortOrder: _sortOrder,
    );

    if (mounted) setState(() => _isSearching = false);
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _hasSearched = false;
      _isSearching = false;
    });
    _focusNode.requestFocus();
  }

  void _applySort(_SortOpt opt) {
    if (_sortBy == opt.sortBy && _sortOrder == opt.order) return;
    setState(() {
      _sortBy    = opt.sortBy;
      _sortOrder = opt.order;
    });
    if (_hasSearched && _controller.text.isNotEmpty) _search(_controller.text);
  }

  void _goToDetail(ServiceListing listing) {
    context.read<ServicesProvider>().selectListing(listing);
    Navigator.pushNamed(
      context,
      '/services/detail',
      arguments: {'listingId': listing.id},
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kPageBg,
        // FIX: resizeToAvoidBottomInset true (default) so the keyboard never
        // pushes the sort bar / results out of view.
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            _buildSearchHeader(),
            if (_hasSearched) _buildSortBar(),
            Expanded(
              child: _hasSearched ? _buildResults() : _buildSuggestions(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search header ─────────────────────────────────────────────────────────
  Widget _buildSearchHeader() {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      color: _kSurface,
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 12),
      child: Row(
        children: [
          // Back button — fixed size, never in Expanded
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_rounded,
                color: _kTextPrimary, size: 24),
          ),

          const SizedBox(width: 12),

          // Search input — Expanded so it fills remaining horizontal space
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _kInputBg,
                borderRadius: BorderRadius.circular(_rLg),
                border: Border.all(color: _kBorder),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: AppTypography.bodyMedium
                    .copyWith(color: _kTextPrimary),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher un service…',
                  hintStyle: AppTypography.bodyMedium
                      .copyWith(color: _kTextLight),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _kTextLight, size: 20),
                  // FIX: suffixIcon tap area wrapped in SizedBox to avoid
                  // the icon being clipped by the 48 px container height
                  suffixIcon: _controller.text.isNotEmpty
                      ? GestureDetector(
                    onTap: _clearSearch,
                    child: const SizedBox(
                      width: 40,
                      child: Icon(Icons.close_rounded,
                          color: _kTextLight, size: 18),
                    ),
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onSubmitted: _search,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Filter button — fixed 48×48, never Expanded
          GestureDetector(
            onTap: _showFiltersSheet,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _hasActiveFilters ? _kPrimary : _kInputBg,
                borderRadius: BorderRadius.circular(_rLg),
                border: Border.all(
                  color: _hasActiveFilters ? _kPrimary : _kBorder,
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                // FIX: dark icon on gold (correct contrast), light icon otherwise
                color: _hasActiveFilters ? _kTextPrimary : _kTextSecond,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sort bar ──────────────────────────────────────────────────────────────
  Widget _buildSortBar() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.only(bottom: 10),
      // FIX: explicit SizedBox height so the ListView.builder has a bounded
      // vertical constraint and doesn't throw an unbounded-height error
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _sorts.length,
          itemBuilder: (_, i) {
            final opt      = _sorts[i];
            final selected = _sortBy == opt.sortBy && _sortOrder == opt.order;
            return GestureDetector(
              onTap: () => _applySort(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? _kPrimaryLight : _kInputBg,
                  borderRadius: BorderRadius.circular(_rPill),
                  border: Border.all(
                    color: selected ? _kPrimary : _kBorder,
                  ),
                ),
                child: Text(
                  opt.label,
                  style: AppTypography.labelSmall.copyWith(
                    color: selected ? _kPrimaryDark : _kTextSecond,
                    fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Pre-search suggestions ────────────────────────────────────────────────
  Widget _buildSuggestions() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        final categories = provider.parentCategories;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Recent searches
            if (_recentSearches.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // FIX: Flexible so the title never pushes "Tout effacer" off-screen
                  const Flexible(
                    child: Text(
                      'Recherches récentes',
                      style: AppTypography.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _recentSearches.clear()),
                    child: Text(
                      'Tout effacer',
                      style: AppTypography.labelMedium
                          .copyWith(color: _kError),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._recentSearches.map((q) => _RecentTile(
                query: q,
                onTap: () {
                  _controller.text = q;
                  _search(q);
                },
                onRemove: () =>
                    setState(() => _recentSearches.remove(q)),
              )),
              const SizedBox(height: 24),
            ],

            // Browse by category
            if (categories.isNotEmpty) ...[
              _SectionHeader(
                title: 'Parcourir par catégorie',
                onSeeAll: () =>
                    Navigator.pushNamed(context, '/services/categories'),
              ),
              const SizedBox(height: 12),
              // FIX: Wrap never overflows — chips flow to next lines naturally
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.take(8).map((c) {
                  return GestureDetector(
                    onTap: () {
                      final name = c.getLocalizedName(useFrench: true);
                      _controller.text = name;
                      _search(name);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(_rPill),
                        border: Border.all(color: _kBorder),
                        boxShadow: _kCardShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _categoryEmoji(c.nameEn),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          // FIX: ConstrainedBox so a long category name
                          // doesn't widen the chip beyond the screen edge
                          ConstrainedBox(
                            constraints:
                            const BoxConstraints(maxWidth: 120),
                            child: Text(
                              c.getLocalizedName(useFrench: true),
                              style: AppTypography.labelMedium
                                  .copyWith(color: _kTextPrimary),
                              overflow: TextOverflow.ellipsis,
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
            const Text(
              'Recherches populaires',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _popular.map((term) {
                return GestureDetector(
                  onTap: () {
                    _controller.text = term;
                    _search(term);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(_rPill),
                      border: Border.all(color: _kPrimaryMid),
                    ),
                    child: Text(
                      term,
                      style: AppTypography.labelMedium.copyWith(
                        color: _kPrimaryDark,
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

  // ── Search results ────────────────────────────────────────────────────────
  Widget _buildResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
            SizedBox(height: 16),
            Text('Recherche en cours…',
                style: AppTypography.bodySmall),
          ],
        ),
      );
    }

    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        // Error state
        if (provider.listingsError != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
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
                    onPressed: () => _search(_controller.text),
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

        final results = provider.listings;

        // Empty state
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 56, color: _kTextLight),
                  const SizedBox(height: 16),
                  const Text('Aucun résultat',
                      style: AppTypography.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Essayez d\'autres mots-clés ou supprimez des filtres',
                    style: AppTypography.bodySmall
                        .copyWith(color: _kTextSecond),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Effacer la recherche'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPrimary,
                      side: const BorderSide(color: _kPrimary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_rLg)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Results list
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Result count
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                // FIX: wrapped in Flexible-safe context (it's alone in a
                // Column so no Flexible needed, but maxLines guards against
                // very long query strings overflowing the single-line chip)
                '${results.length} résultat${results.length == 1 ? '' : 's'}'
                    ' pour « ${_controller.text} »',
                style: AppTypography.labelMedium
                    .copyWith(color: _kTextSecond),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: results.length,
                itemBuilder: (_, i) => ServiceListCard(
                  listing: results[i],
                  onTap: () => _goToDetail(results[i]),
                ),
              ),
            ),
          ],
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
        initialCity: _selectedCity,
        initialMinPrice: _minPrice ?? 0,
        initialMaxPrice: _maxPrice ?? 100000,
        initialMinRating: _minRating ?? 0,
        onApply: (city, minP, maxP, minR) {
          setState(() {
            _selectedCity = city;
            _minPrice     = minP > 0 ? minP : null;
            _maxPrice     = maxP < 100000 ? maxP : null;
            _minRating    = minR > 0 ? minR : null;
          });
          if (_hasSearched && _controller.text.isNotEmpty) {
            _search(_controller.text);
          }
        },
        onReset: () {
          setState(() {
            _selectedCity = null;
            _minPrice     = null;
            _maxPrice     = null;
            _minRating    = null;
          });
          if (_hasSearched && _controller.text.isNotEmpty) {
            _search(_controller.text);
          }
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
        Flexible(
          child: Text(
            title,
            style: AppTypography.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onSeeAll != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'Voir tout',
              style: AppTypography.labelMedium
                  .copyWith(color: _kPrimary),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT SEARCH TILE
// ─────────────────────────────────────────────────────────────────────────────
class _RecentTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentTile({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(_rMd),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded,
                size: 18, color: _kTextLight),
            const SizedBox(width: 12),
            // FIX: Expanded so long queries wrap/ellipsis instead of
            // pushing the remove icon off-screen
            Expanded(
              child: Text(
                query,
                style: AppTypography.bodySmall
                    .copyWith(color: _kTextPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              // FIX: explicit tap-target size so the small × is easy to hit
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.close_rounded,
                    size: 16, color: _kTextLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SORT OPTION  (data class)
// ─────────────────────────────────────────────────────────────────────────────
class _SortOpt {
  final String label;
  final String sortBy;
  final String order;
  const _SortOpt(this.label, this.sortBy, this.order);
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTERS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _FiltersSheet extends StatefulWidget {
  final String? initialCity;
  final double initialMinPrice;
  final double initialMaxPrice;
  final double initialMinRating;
  final Function(String? city, double minPrice, double maxPrice,
      double minRating) onApply;
  final VoidCallback onReset;

  const _FiltersSheet({
    required this.initialCity,
    required this.initialMinPrice,
    required this.initialMaxPrice,
    required this.initialMinRating,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String? _city;
  late RangeValues _price;
  late double _minRating;

  static const _cities = [
    'Douala', 'Yaoundé', 'Bafoussam',
    'Bamenda', 'Garoua', 'Kribi', 'Limbé',
  ];

  @override
  void initState() {
    super.initState();
    _city      = widget.initialCity;
    _price     = RangeValues(widget.initialMinPrice, widget.initialMaxPrice);
    _minRating = widget.initialMinRating;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.68,
      decoration: const BoxDecoration(
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
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onReset();
                  },
                  child: Text(
                    'Réinitialiser',
                    style: AppTypography.labelMedium
                        .copyWith(color: _kError),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: _kBorder),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── City ──────────────────────────────────────────────
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
                            borderRadius:
                            BorderRadius.circular(_rPill),
                            border: Border.all(
                              color: sel ? _kPrimary : _kBorder,
                            ),
                          ),
                          child: Text(
                            c,
                            style: AppTypography.labelMedium.copyWith(
                              // FIX: dark text on gold selected chip
                              color: sel
                                  ? AppColors.textPrimary
                                  : _kTextSecond,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ── Price range ───────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // FIX: Flexible prevents label overflowing on narrow phones
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

                  // ── Min rating ────────────────────────────────────────
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
                      _city, _price.start, _price.end, _minRating);
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
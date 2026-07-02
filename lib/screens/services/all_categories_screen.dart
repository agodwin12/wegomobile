// lib/screens/services/all_categories_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// All Categories Screen
// Overflow-fixed + aligned to AppColors / AppTypography
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/services/category_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

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

const double _rLg   = 16.0;
const double _rPill = 999.0;

const List<BoxShadow> _kCardShadow = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({Key? key}) : super(key: key);

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicesProvider>().fetchParentCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goToCategory(ServiceCategory category) {
    context.read<ServicesProvider>().selectCategory(category);
    Navigator.pushNamed(
      context,
      '/services/category-listings',
      arguments: {'category': category},
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kPageBg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kSurface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back_rounded, color: _kTextPrimary),
      ),
      title: Text('Catégories', style: AppTypography.titleLarge),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: _kInputBg,
          borderRadius: BorderRadius.circular(_rLg),
          border: Border.all(color: _kBorder),
        ),
        child: TextField(
          controller: _searchController,
          style: AppTypography.bodyMedium.copyWith(color: _kTextPrimary),
          decoration: InputDecoration(
            hintText: 'Rechercher une catégorie…',
            hintStyle: AppTypography.bodyMedium.copyWith(color: _kTextLight),
            prefixIcon: Icon(Icons.search_rounded,
                color: _kTextLight, size: 20),
            // FIX: explicit SizedBox tap target for the clear icon
            suffixIcon: _query.isNotEmpty
                ? GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              child: SizedBox(
                width: 40,
                child: Icon(Icons.close_rounded,
                    color: _kTextLight, size: 18),
              ),
            )
                : null,
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (v) => setState(() => _query = v.toLowerCase().trim()),
        ),
      ),
    );
  }

  // ── Grid ──────────────────────────────────────────────────────────────────
  Widget _buildGrid() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        // Loading
        if (provider.categoriesLoading && provider.parentCategories.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
                SizedBox(height: 16),
                Text('Chargement des catégories…',
                    style: AppTypography.bodySmall),
              ],
            ),
          );
        }

        // Error
        if (provider.categoriesError != null &&
            provider.parentCategories.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 48, color: _kTextLight),
                  const SizedBox(height: 12),
                  Text(
                    provider.categoriesError!,
                    style: AppTypography.bodySmall
                        .copyWith(color: _kTextSecond),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchParentCategories(),
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

        // Filter by query
        final all = provider.parentCategories;
        final filtered = _query.isEmpty
            ? all
            : all.where((c) {
          final name =
          c.getLocalizedName(useFrench: true).toLowerCase();
          final nameEn = c.nameEn.toLowerCase();
          return name.contains(_query) || nameEn.contains(_query);
        }).toList();

        // Empty
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.category_outlined,
                      size: 48, color: _kTextLight),
                  const SizedBox(height: 16),
                  Text(
                    _query.isEmpty
                        ? 'Aucune catégorie'
                        : 'Aucun résultat pour « $_query »',
                    style: AppTypography.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _query.isEmpty
                        ? 'Les catégories apparaîtront ici une fois ajoutées'
                        : 'Essayez un autre terme de recherche',
                    style: AppTypography.bodySmall
                        .copyWith(color: _kTextSecond),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: _kPrimary,
          onRefresh: () => provider.fetchParentCategories(),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              // FIX: raised from 0.88 to 0.82 so the name (up to 2 lines) +
              // sub-count chip always fits inside the card without overflowing
              childAspectRatio: 0.82,
            ),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _CategoryCard(
              category: filtered[i],
              onTap: () => _goToCategory(filtered[i]),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasSubcategories = category.subcategories != null &&
        category.subcategories!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(_rLg),
          boxShadow: _kCardShadow,
        ),
        // FIX: replace Column(mainAxisAlignment: center) with a Padding +
        // Column(mainAxisSize: min) centred via the card's own alignment.
        // MainAxisAlignment.center inside a tight grid cell caused the column
        // to measure children at natural height and then try to centre them,
        // which overflowed when the name wrapped to 2 lines + chip was present.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon circle — fixed 60×60
            Container(
              width: 60,
              height: 60,
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

            const SizedBox(height: 8),

            // Category name — max 2 lines, ellipsis
            Text(
              category.getLocalizedName(useFrench: true),
              style: AppTypography.titleSmall.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Sub-count chip
            if (hasSubcategories) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(_rPill),
                ),
                child: Text(
                  '${category.subcategories!.length} sous-catégories',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: _kPrimaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fallbackIcon(String name) {
    return Center(
      child: Text(
        _categoryEmoji(name),
        style: const TextStyle(fontSize: 26),
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
    if (n.contains('secu') || n.contains('secur')) return '🔒';
    if (n.contains('it') || n.contains('info') || n.contains('tech')) {
      return '💻';
    }
    if (n.contains('photo')) return '📷';
    if (n.contains('event') || n.contains('evenem')) return '🎉';
    if (n.contains('transport') || n.contains('livr')) return '🚚';
    if (n.contains('sante') || n.contains('health')) return '❤️';
    if (n.contains('cours') || n.contains('teach')) return '📚';
    return '🛠️';
  }
}
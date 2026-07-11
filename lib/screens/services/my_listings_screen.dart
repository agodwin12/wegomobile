// lib/screens/services/my_listings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// My Listings Screen  (Provider view)
// Overflow-fixed + aligned to AppColors / AppTypography
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../utils/services_post_flow.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/services/service_listing_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

// ─── Local design tokens ──────────────────────────────────────────────────────
const _kPrimary      = AppColors.primaryGold;
const _kPrimaryDark  = AppColors.primaryGoldDark;
const _kPrimaryLight = Color(0xFFFFFDE7);
Color get _kSurface => AppColors.backgroundWhite;
Color get _kPageBg => AppColors.backgroundLight;
Color get _kInputBg => AppColors.inputBackground;
Color get _kBorder => AppColors.borderLight;
Color get _kTextPrimary => AppColors.textPrimary;
Color get _kTextSecond => AppColors.textSecondary;
Color get _kTextLight => AppColors.textLight;
const _kError        = AppColors.error;
Color get _kErrorLight => AppColors.errorLight;
const _kSuccess      = AppColors.success;
Color get _kSuccessLight => AppColors.successLight;
const _kWarning      = AppColors.warning;
Color get _kWarningLight => AppColors.warningLight;
const _kInfo         = AppColors.info;

const double _rSm   = 6.0;
const double _rMd   = 12.0;
const double _rLg   = 16.0;
const double _rXl   = 24.0;
const double _rPill = 999.0;

const List<BoxShadow> _kCardShadow = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({Key? key}) : super(key: key);

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  static const _tabs = ['Tous', 'Actifs', 'En attente', 'Rejetés', 'Inactifs'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await context.read<ServicesProvider>().fetchMyListings();
    if (mounted) setState(() => _isLoading = false);
  }

  List<ServiceListing> _filter(List<ServiceListing> all) {
    switch (_tabs[_tabController.index]) {
      case 'Actifs':
        return all.where((l) => l.status == ListingStatus.active).toList();
      case 'En attente':
        return all.where((l) => l.status == ListingStatus.pending).toList();
      case 'Rejetés':
        return all.where((l) => l.status == ListingStatus.rejected).toList();
      case 'Inactifs':
        return all
            .where((l) =>
        l.status == ListingStatus.inactive ||
            l.status == ListingStatus.deleted)
            .toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kPageBg,
        appBar: _buildAppBar(),
        floatingActionButton: _buildFab(),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
              color: _kPrimary, strokeWidth: 2),
        )
            : RefreshIndicator(
          color: _kPrimary,
          onRefresh: _load,
          child: Consumer<ServicesProvider>(
            builder: (_, provider, __) {
              final all = provider.myListings ?? [];
              return Column(
                children: [
                  _buildStats(all),
                  _buildTabBar(all),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: _tabs.map((tab) {
                        final items = _filter(all);
                        return items.isEmpty
                            ? _buildEmpty(tab)
                            : _buildList(items);
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kSurface,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back_rounded, color: _kTextPrimary),
      ),
      title: Text('Mes annonces', style: AppTypography.titleLarge),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Mon abonnement',
          onPressed: () => Navigator.pushNamed(context, '/services/my-subscription')
              .then((_) => _load()),
          icon: Icon(Icons.workspace_premium_rounded, color: _kPrimary),
        ),
      ],
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────
  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () =>
          startServicePostFlow(context).then((_) => _load()),
      backgroundColor: _kPrimary,
      // FIX: dark foreground on gold (correct contrast)
      foregroundColor: _kTextPrimary,
      elevation: 3,
      icon: const Icon(Icons.add_rounded),
      label: Text('Nouvelle annonce', style: AppTypography.buttonSmall),
    );
  }

  // ── Stats banner ──────────────────────────────────────────────────────────
  Widget _buildStats(List<ServiceListing> all) {
    final active       = all.where((l) => l.status == ListingStatus.active).length;
    final totalViews   = all.fold<int>(0, (s, l) => s + l.viewCount);
    final totalContacts = all.fold<int>(0, (s, l) => s + l.contactCount);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        // FIX: use gold→goldDark gradient (correct brand colours)
        gradient: const LinearGradient(
          colors: [_kPrimary, _kPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_rXl),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
              label: 'Actifs', value: '$active',
              icon: Icons.check_circle_rounded),
          _VerticalDivider(),
          _StatItem(
              label: 'Vues', value: '$totalViews',
              icon: Icons.visibility_rounded),
          _VerticalDivider(),
          _StatItem(
              label: 'Contacts', value: '$totalContacts',
              icon: Icons.message_rounded),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar(List<ServiceListing> all) {
    return Container(
      color: _kSurface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: _kPrimary,
        indicatorWeight: 3,
        labelColor: _kPrimary,
        unselectedLabelColor: _kTextSecond,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: _tabs.map((tab) {
          // FIX: compute count for this specific tab rather than reusing
          // _filter() which references _tabController.index — building tabs
          // during build() while the controller is animating caused index
          // mismatch and incorrect badge counts on every tab.
          final count = _countForTab(tab, all);
          final isSelected = _tabs[_tabController.index] == tab;

          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // FIX: constrain tab label so very long translated strings
                // don't expand the Tab beyond the screen width
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 88),
                  child: Text(
                    tab,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count > 0 && tab != 'Tous') ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      // FIX: selected badge gets _kPrimary bg with dark text;
                      // unselected gets inputBg with secondary text
                      color: isSelected ? _kPrimary : _kInputBg,
                      borderRadius: BorderRadius.circular(_rPill),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? _kTextPrimary : _kTextSecond,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        onTap: (_) => setState(() {}),
      ),
    );
  }

  int _countForTab(String tab, List<ServiceListing> all) {
    switch (tab) {
      case 'Actifs':    return all.where((l) => l.status == ListingStatus.active).length;
      case 'En attente': return all.where((l) => l.status == ListingStatus.pending).length;
      case 'Rejetés':   return all.where((l) => l.status == ListingStatus.rejected).length;
      case 'Inactifs':  return all.where((l) =>
      l.status == ListingStatus.inactive ||
          l.status == ListingStatus.deleted).length;
      default:          return all.length;
    }
  }

  // ── List ──────────────────────────────────────────────────────────────────
  Widget _buildList(List<ServiceListing> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => _ListingCard(
        listing: items[i],
        onRefresh: _load,
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty(String tab) {
    final isAll = tab == 'Tous';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_outline_rounded,
                size: 56, color: _kTextLight),
            const SizedBox(height: 16),
            Text(
              isAll ? 'Aucune annonce' : 'Aucune annonce $tab',
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isAll
                  ? 'Commencez à proposer vos services aux clients à Douala'
                  : 'Rien ici pour le moment',
              style: AppTypography.bodySmall.copyWith(color: _kTextSecond),
              textAlign: TextAlign.center,
            ),
            if (isAll) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/services/listing-plan')
                    .then((_) => _load()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: _kTextPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_rLg)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Publier votre premier service'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTING CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ListingCard extends StatelessWidget {
  final ServiceListing listing;
  final VoidCallback onRefresh;

  const _ListingCard({required this.listing, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_rLg),
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Divider(height: 1, color: _kBorder),
          _buildBody(),
          _buildFooter(context),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final categoryName = (listing.categoryName?.isNotEmpty == true)
        ? listing.categoryName!
        : 'Non catégorisé';

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail — fixed 72×72, never in an Expanded
          ClipRRect(
            borderRadius: BorderRadius.circular(_rMd),
            child: listing.photos.isNotEmpty
                ? Image.network(
              listing.photos.first,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
                : _placeholder(),
          ),

          const SizedBox(width: 12),

          // Title + category — Expanded so they shrink before the badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: AppTypography.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.category_outlined,
                        size: 12, color: _kTextLight),
                    const SizedBox(width: 4),
                    // FIX: Expanded so long category name doesn't push
                    // status badge off the right edge
                    Expanded(
                      child: Text(
                        categoryName,
                        style: AppTypography.labelSmall,
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
          // Status badge — intrinsic width, never in Expanded
          _StatusBadge(status: listing.status),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: _kInputBg,
        borderRadius: BorderRadius.circular(_rMd),
      ),
      child: Icon(Icons.work_outline_rounded,
          color: _kTextLight, size: 28),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price + location + date row
          Row(
            children: [
              // Price chip — intrinsic width
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(_rMd),
                ),
                child: Text(
                  listing.priceDisplay,
                  style: AppTypography.titleSmall
                      .copyWith(color: _kPrimaryDark),
                ),
              ),

              const SizedBox(width: 8),

              // Location — Flexible so it never pushes the date off-screen
              Icon(Icons.location_on_outlined,
                  size: 13, color: _kTextLight),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  listing.city,
                  style: AppTypography.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const Spacer(),

              // Date — fixed intrinsic width
              Text(
                _postedDate(listing.createdAt),
                style: AppTypography.labelSmall
                    .copyWith(color: _kTextLight),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Stats chips row
          // FIX: Wrap so that on narrow screens or when all three chips are
          // present they flow to a second line instead of overflowing
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatChip(
                  icon: Icons.visibility_rounded,
                  label: '${listing.viewCount} vues'),
              _StatChip(
                  icon: Icons.message_rounded,
                  label: '${listing.contactCount} contacts'),
              if (listing.averageRating != null &&
                  listing.averageRating! > 0)
                _StatChip(
                  icon: Icons.star_rounded,
                  label:
                  '${listing.averageRating!.toStringAsFixed(1)} (${listing.totalReviews})',
                  iconColor: _kWarning,
                ),
            ],
          ),

          // Rejection reason
          if (listing.status == ListingStatus.rejected &&
              listing.rejectionReason != null &&
              listing.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kErrorLight,
                borderRadius: BorderRadius.circular(_rMd),
                border: Border.all(color: _kError.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: _kError),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejeté : ${listing.rejectionReason}',
                      style: AppTypography.bodySmall
                          .copyWith(color: _kError),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Pending info
          if (listing.status == ListingStatus.pending) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kWarningLight,
                borderRadius: BorderRadius.circular(_rMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pending_rounded,
                      size: 15, color: _kWarning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'En cours d\'examen — approbation sous 24 h',
                      style: AppTypography.bodySmall
                          .copyWith(color: _kWarning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Footer: action buttons ────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(_rLg),
          bottomRight: Radius.circular(_rLg),
        ),
      ),
      child: Row(
        children: [
          if (_canEdit()) ...[
            Expanded(
              child: _OutlineBtn(
                label: 'Modifier',
                icon: Icons.edit_outlined,
                color: AppColors.info,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/services/edit-listing',
                  arguments: {'listing': listing},
                ).then((_) => onRefresh()),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _DeleteBtn(onTap: () => _confirmDelete(context)),
        ],
      ),
    );
  }

  bool _canEdit() =>
      listing.status == ListingStatus.active ||
          listing.status == ListingStatus.pending ||
          listing.status == ListingStatus.rejected ||
          listing.status == ListingStatus.inactive;

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rXl)),
        title: Text('Supprimer l\'annonce ?',
            style: AppTypography.titleLarge),
        content: Text(
          'Cela supprimera définitivement « ${listing.title} ». Cette action est irréversible.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: AppTypography.labelMedium
                  .copyWith(color: _kTextSecond),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final p = context.read<ServicesProvider>();
              final ok = await p.deleteListing(listing.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Annonce supprimée'
                      : (p.listingsError ?? 'Échec de la suppression')),
                  backgroundColor: ok ? _kSuccess : _kError,
                ),
              );
              if (ok) onRefresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_rMd)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  String _postedDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Aujourd\'hui';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    if (diff.inDays < 30) return 'Il y a ${(diff.inDays / 7).floor()}sem';
    return DateFormat('dd MMM').format(date);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT ITEM  (inside the gradient banner)
// ─────────────────────────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatItem(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black87, size: 24),
          const SizedBox(height: 6),
          // FIX: constrain value text so a very large number (e.g. 10 000+)
          // doesn't overflow the banner column
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              color: Colors.black54,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERTICAL DIVIDER inside banner
// ─────────────────────────────────────────────────────────────────────────────
class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 48,
    color: Colors.black.withOpacity(0.15),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final ListingStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case ListingStatus.active:
      case ListingStatus.approved:
        bg = _kSuccessLight; fg = _kSuccess; label = 'ACTIF'; break;
      case ListingStatus.pending:
        bg = _kWarningLight; fg = _kWarning; label = 'ATTENTE'; break;
      case ListingStatus.rejected:
        bg = _kErrorLight;   fg = _kError;   label = 'REJETÉ'; break;
      case ListingStatus.inactive:
      case ListingStatus.deleted:
        bg = _kInputBg;      fg = _kTextLight; label = 'INACTIF'; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_rPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT CHIP  (views / contacts / rating)
// ─────────────────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  const _StatChip(
      {required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _kInputBg,
        borderRadius: BorderRadius.circular(_rSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? _kTextSecond),
          const SizedBox(width: 4),
          // FIX: ConstrainedBox so a very long label (e.g. "1 200 vues")
          // doesn't widen the chip beyond the screen
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTLINE BUTTON  (Edit)
// ─────────────────────────────────────────────────────────────────────────────
class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 10),
        textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rLg)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE ICON BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _DeleteBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.delete_outline_rounded,
          color: _kError, size: 22),
      tooltip: 'Supprimer',
      style: IconButton.styleFrom(
        backgroundColor: _kErrorLight,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rMd)),
      ),
    );
  }
}
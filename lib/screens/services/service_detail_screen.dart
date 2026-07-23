// lib/screens/services/service_detail_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Service Detail Screen
// Overflow-fixed + aligned to AppColors / AppTypography
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/services/service_listing_model.dart';
import '../../models/services/service_rating_model.dart';
import '../../providers/services.dart';
import '../../service/api/services_api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import '../../widgets/services/service_card_widget.dart';

// ─── Local design tokens ──────────────────────────────────────────────────────
const _kPrimary      = AppColors.primaryGold;       // #FFDC71 (Jaune Or charte)
const _kPrimaryLight = Color(0xFFFFFDE7);
const _kPrimaryMid   = Color(0xFFFFECB3);
const _kPrimaryDark  = AppColors.primaryGoldDark;   // #F5C844
Color get _kSurface => AppColors.backgroundWhite;
Color get _kPageBg => AppColors.backgroundLight;
Color get _kInputBg => AppColors.inputBackground;
Color get _kBorder => AppColors.borderLight;
Color get _kTextPrimary => AppColors.textPrimary;
Color get _kTextSecond => AppColors.textSecondary;
Color get _kTextLight => AppColors.textLight;
const _kError        = AppColors.error;
const _kWarning      = AppColors.warning;           // star colour

// Radius
const double _rSm   = 8.0;
const double _rMd   = 12.0;
const double _rLg   = 16.0;
const double _rXl   = 24.0;
const double _rPill = 999.0;

// Shadows
const List<BoxShadow> _kCardShadow = [
  BoxShadow(color: Color(0x18000000), blurRadius: 8, offset: Offset(0, 2)),
];
const List<BoxShadow> _kBottomShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -3)),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ServiceDetailScreen extends StatefulWidget {
  final int? listingId;
  const ServiceDetailScreen({Key? key, this.listingId}) : super(key: key);

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final PageController _imageController = PageController();

  int  _imageIndex   = 0;
  bool _isFavourite  = false;
  bool _descExpanded = false;
  bool _isLoading    = true;
  ServiceListing? _listing;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    final provider = context.read<ServicesProvider>();

    if (provider.selectedListing != null &&
        (widget.listingId == null ||
            provider.selectedListing!.id == widget.listingId)) {
      _listing = provider.selectedListing;
    } else if (widget.listingId != null) {
      _listing = await provider.fetchListingById(widget.listingId!);
    }

    if (_listing != null) {
      await provider.fetchRatingsForListing(_listing!.id);
      await provider.fetchListings(
        categoryId: _listing!.categoryId,
        refresh: true,
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _callProvider() async {
    if (_listing == null) return;
    final phone = _listing!.provider?.phone;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numéro non disponible')),
        );
      }
      return;
    }
    // Record the lead + push-notify the provider that a customer is interested.
    // Fire-and-forget so the dialer opens instantly even if the network is slow.
    ServicesApiService().requestServiceContact(_listing!.id).catchError((e) {
      debugPrint('⚠️ [SERVICE] contact notify failed: $e');
      return <String, dynamic>{};
    });

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showReviews() {
    if (_listing == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewsSheet(listingId: _listing!.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kSurface,
        body: _isLoading
            ? _buildLoader()
            : _listing == null
            ? _buildNotFound()
            : _buildContent(),
      ),
    );
  }

  // ── Loader ────────────────────────────────────────────────────────────────
  Widget _buildLoader() {
    return const Center(
      child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
    );
  }

  // ── Not found ─────────────────────────────────────────────────────────────
  Widget _buildNotFound() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _kTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Détails', style: AppTypography.titleLarge),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 56, color: _kTextLight),
              const SizedBox(height: 16),
              Text('Service introuvable',
                  style: AppTypography.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Cette annonce a peut-être été supprimée.',
                  style: AppTypography.bodySmall.copyWith(color: _kTextSecond),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main content ──────────────────────────────────────────────────────────
  Widget _buildContent() {
    return Stack(
      children: [
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildImageGallery()),
            SliverToBoxAdapter(child: _buildInfoCard()),
            SliverToBoxAdapter(child: _buildMoreSection()),
            // Space for sticky bottom bar
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _buildBottomBar(),
        ),
      ],
    );
  }

  // ── Image gallery ─────────────────────────────────────────────────────────
  Widget _buildImageGallery() {
    final photos = _listing!.photos;
    final hasPhotos = photos.isNotEmpty;
    final topPad = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          // Pager / placeholder
          hasPhotos
              ? PageView.builder(
            controller: _imageController,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _imageIndex = i),
            itemBuilder: (_, i) => Image.network(
              photos[i],
              fit: BoxFit.cover,
              width: double.infinity,
              height: 300,
              errorBuilder: (_, __, ___) => _imagePlaceholder(),
            ),
          )
              : _imagePlaceholder(),

          // Back button
          Positioned(
            top: topPad + 8,
            left: 16,
            child: _CircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),

          // Favourite button
          Positioned(
            top: topPad + 8,
            right: 16,
            child: _CircleButton(
              icon: _isFavourite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: _isFavourite ? _kError : _kTextSecond,
              onTap: () => setState(() => _isFavourite = !_isFavourite),
            ),
          ),

          // Dot indicators
          if (photos.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: _ImageDots(count: photos.length, current: _imageIndex),
            ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 300,
      color: _kInputBg,
      child: Center(
        child: Icon(Icons.image_outlined, size: 64, color: _kTextLight),
      ),
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────────
  Widget _buildInfoCard() {
    final listing = _listing!;
    final hasRating =
        listing.averageRating != null && listing.averageRating! > 0;

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_rXl)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category label
          Text(
            listing.categoryName.toUpperCase(),
            style: AppTypography.overline.copyWith(color: _kPrimary),
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          // Title
          Text(
            listing.title,
            style: AppTypography.headlineSmall,
            overflow: TextOverflow.visible,
          ),

          const SizedBox(height: 10),

          // Rating row
          hasRating
              ? GestureDetector(
            onTap: _showReviews,
            child: Row(
              // FIX: mainAxisSize.min + no Expanded child so it never
              // requests infinite width inside the Column
              mainAxisSize: MainAxisSize.min,
              children: [
                _StarRow(rating: listing.averageRating!),
                const SizedBox(width: 6),
                Text(
                  '(${listing.totalReviews})',
                  style: AppTypography.labelMedium,
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: _kTextLight),
              ],
            ),
          )
              : Text(
            'Pas encore d\'avis',
            style: AppTypography.labelMedium
                .copyWith(color: _kTextLight),
          ),

          const SizedBox(height: 20),
          Divider(color: _kBorder, height: 1),
          const SizedBox(height: 20),

          // Product Details header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // FIX: Flexible so the title shrinks when "Read more" is next to it
              Flexible(
                child: Text(
                  'Détails du service',
                  style: AppTypography.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    setState(() => _descExpanded = !_descExpanded),
                child: Text(
                  _descExpanded ? 'Réduire' : 'Lire plus',
                  style: AppTypography.labelMedium
                      .copyWith(color: _kPrimary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Description (collapsible)
          AnimatedCrossFade(
            firstChild: Text(
              listing.description,
              style: AppTypography.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            secondChild: Text(
              listing.description,
              style: AppTypography.bodySmall,
            ),
            crossFadeState: _descExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),

          const SizedBox(height: 20),

          // Detail chips
          _buildDetailsChips(listing),

          const SizedBox(height: 20),

          // Provider card
          _buildProviderCard(listing),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Detail chips ─────────────────────────────────────────────────────────
  Widget _buildDetailsChips(ServiceListing listing) {
    // FIX: Wrap handles its own overflow by flowing to next lines — no
    // explicit Row needed, so chips never clip on narrow screens.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _DetailChip(
          icon: Icons.location_on_outlined,
          label: listing.city,
        ),
        _DetailChip(
          icon: Icons.access_time_rounded,
          label: listing.availabilityDisplay,
        ),
        if (listing.emergencyService)
          _DetailChip(
            icon: Icons.bolt_rounded,
            label: '24/7 Urgence',
            color: _kError,
          ),
      ],
    );
  }

  // ── Provider card ─────────────────────────────────────────────────────────
  Widget _buildProviderCard(ServiceListing listing) {
    final provider = listing.provider;
    if (provider == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kPageBg,
        borderRadius: BorderRadius.circular(_rLg),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          // Avatar — fixed size, never in an Expanded
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kPrimaryMid, width: 2),
            ),
            child: ClipOval(
              child: provider.avatarUrl != null
                  ? Image.network(
                provider.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _avatarFallback(provider.fullName),
              )
                  : _avatarFallback(provider.fullName),
            ),
          ),

          const SizedBox(width: 12),

          // Name + role — Expanded so it shrinks before the jobs column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // FIX: Flexible prevents name from pushing verify icon off-screen
                    Flexible(
                      child: Text(
                        provider.fullName,
                        style: AppTypography.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (provider.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded,
                          size: 15, color: _kPrimary),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _listing!.providerType,
                  style: AppTypography.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Completed services — fixed width column, no flex
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${provider.completedServices}',
                style: AppTypography.titleMedium.copyWith(color: _kPrimary),
              ),
              Text(
                'missions',
                style: AppTypography.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: _kPrimaryLight,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: AppTypography.headlineSmall.copyWith(color: _kPrimaryDark),
        ),
      ),
    );
  }

  // ── More from category ────────────────────────────────────────────────────
  Widget _buildMoreSection() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        final others = provider.listings
            .where((l) =>
        l.id != _listing!.id &&
            l.categoryId == _listing!.categoryId)
            .take(6)
            .toList();

        if (others.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // FIX: Flexible so the title wraps on narrow screens
                  Flexible(
                    child: Text(
                      'Plus dans ${_listing!.categoryName}',
                      style: AppTypography.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20),
                itemCount: others.length,
                itemBuilder: (_, i) => ServiceFeaturedCard(
                  listing: others[i],
                  onTap: () {
                    provider.selectListing(others[i]);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ServiceDetailScreen(listingId: others[i].id),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Sticky bottom bar ─────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final phone = _listing!.provider?.phone;
    final hasPhone = phone != null && phone.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 12),
      decoration: BoxDecoration(
        color: _kSurface,
        boxShadow: _kBottomShadow,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: hasPhone ? _callProvider : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: _kTextPrimary,
            disabledBackgroundColor: _kBorder,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rLg),
            ),
          ),
          icon: const Icon(Icons.phone_rounded, size: 20),
          label: Text('Appeler le prestataire', style: AppTypography.buttonMedium),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEWS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewsSheet extends StatefulWidget {
  final int listingId;
  const _ReviewsSheet({required this.listingId});

  @override
  State<_ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends State<_ReviewsSheet> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context
        .read<ServicesProvider>()
        .fetchRatingsForListing(widget.listingId);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Avis', style: AppTypography.headlineSmall),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded,
                        color: _kTextSecond),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: _kBorder),

            Expanded(
              child: _loading
                  ? const Center(
                child: CircularProgressIndicator(
                    color: _kPrimary, strokeWidth: 2),
              )
                  : Consumer<ServicesProvider>(
                builder: (_, provider, __) {
                  final ratings = provider.ratings;
                  if (ratings.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_border_rounded,
                                size: 48, color: _kTextLight),
                            const SizedBox(height: 12),
                            Text('Pas encore d\'avis',
                                style: AppTypography.titleMedium),
                            const SizedBox(height: 6),
                            Text(
                              'Soyez le premier à noter ce service',
                              style: AppTypography.bodySmall
                                  .copyWith(color: _kTextSecond),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    itemCount: ratings.length,
                    separatorBuilder: (_, __) =>
                    Divider(height: 24, color: _kBorder),
                    itemBuilder: (_, i) =>
                        _ReviewTile(rating: ratings[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEW TILE
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewTile extends StatelessWidget {
  final ServiceRating rating;
  const _ReviewTile({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar — fixed size
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFFFFFDE7),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              rating.customerFirstName.isNotEmpty
                  ? rating.customerFirstName[0].toUpperCase()
                  : '?',
              style: AppTypography.titleMedium
                  .copyWith(color: AppColors.primaryGoldDark),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Content — Expanded so long review text wraps
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // FIX: Flexible so long name doesn't push date off-screen
                  Flexible(
                    child: Text(
                      rating.customerFirstName,
                      style: AppTypography.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rating.relativeTime,
                    style: AppTypography.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _StarRow(rating: rating.rating.toDouble(), size: 13),
              if (rating.hasReviewText) ...[
                const SizedBox(height: 6),
                Text(
                  rating.reviewText!,
                  style: AppTypography.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CIRCLE BUTTON  (back + favourite)
// ─────────────────────────────────────────────────────────────────────────────
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _kSurface,
          shape: BoxShape.circle,
          boxShadow: _kCardShadow,
        ),
        child: Icon(
          icon,
          size: 20,
          color: iconColor ?? _kTextPrimary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAR ROW  (half-star support)
// ─────────────────────────────────────────────────────────────────────────────
class _StarRow extends StatelessWidget {
  final double rating;
  final double size;

  const _StarRow({required this.rating, this.size = 15});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(Icons.star_rounded,
              size: size, color: _kWarning);
        } else if (i < rating && rating - i >= 0.5) {
          return Icon(Icons.star_half_rounded,
              size: size, color: _kWarning);
        } else {
          return Icon(Icons.star_outline_rounded,
              size: size, color: _kBorder);
        }
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL CHIP   (location, availability, emergency)
// ─────────────────────────────────────────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _DetailChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? _kPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(_rPill),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 5),
          // FIX: ConstrainedBox caps chip label at 160 px — long availability
          // strings (e.g. "Lun–Sam, 08:00–18:00") no longer overflow the Wrap
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(color: c),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE PAGE DOTS
// ─────────────────────────────────────────────────────────────────────────────
class _ImageDots extends StatelessWidget {
  final int count;
  final int current;
  const _ImageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      // FIX: wrap in a horizontal SingleChildScrollView so an image set with
      // 10+ photos doesn't overflow the 300 px wide screen.
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? _kPrimary : Colors.white54,
            borderRadius: BorderRadius.circular(_rPill),
          ),
        );
      }),
    );
  }
}
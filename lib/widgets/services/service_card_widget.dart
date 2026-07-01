// lib/widgets/services/service_card_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reusable product-style service card
// Used by: services_home_screen, category_listings_screen, search_screen
//
// Two variants:
//   ServiceGridCard     → compact 2-column grid card (home + category)
//   ServiceListCard     → horizontal list card (search results)
//   ServiceFeaturedCard → fixed-width horizontal scroll card (Best Deal row)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../models/services/service_listing_model.dart';
import '../../utils/services_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GRID CARD  (compact, used in 2-column grid)
// ─────────────────────────────────────────────────────────────────────────────
class ServiceGridCard extends StatelessWidget {
  final ServiceListing listing;
  final VoidCallback onTap;

  const ServiceGridCard({
    Key? key,
    required this.listing,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasRating =
        listing.averageRating != null && listing.averageRating! > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: SvcColors.surface,
          borderRadius: BorderRadius.circular(SvcRadius.lg),
          boxShadow: SvcShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ─────────────────────────────────────────────────
            _Thumbnail(
              photoUrl: listing.mainPhoto,
              pricingType: listing.pricingType,
              emergencyService: listing.emergencyService,
            ),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      listing.title,
                      style: SvcText.cardTitle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Provider
                    Row(
                      children: [
                        _ProviderAvatar(
                          avatarUrl: listing.provider?.avatarUrl,
                          name: listing.provider?.fullName ?? '',
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            listing.provider?.fullName ?? 'Provider',
                            style: SvcText.label(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Rating
                    if (hasRating) ...[
                      SvcWidgets.ratingRow(
                        listing.averageRating!,
                        listing.totalReviews,
                        iconSize: 13,
                      ),
                      const SizedBox(height: 5),
                    ],

                    // Price
                    Text(
                      listing.priceDisplay,
                      style: SvcText.price(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// LIST CARD  (horizontal, used in search results)
// ─────────────────────────────────────────────────────────────────────────────
class ServiceListCard extends StatelessWidget {
  final ServiceListing listing;
  final VoidCallback onTap;

  const ServiceListCard({
    Key? key,
    required this.listing,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasRating =
        listing.averageRating != null && listing.averageRating! > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: SvcColors.surface,
          borderRadius: BorderRadius.circular(SvcRadius.lg),
          boxShadow: SvcShadows.card,
        ),
        child: Row(
          children: [
            // ── Thumbnail ─────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(SvcRadius.lg),
                bottomLeft: Radius.circular(SvcRadius.lg),
              ),
              child: Stack(
                children: [
                  _buildNetworkImage(
                      listing.mainPhoto,
                      width: 110,
                      height: 110),
                  // Negotiable badge
                  if (listing.pricingType == PricingType.negotiable)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: SvcWidgets.discountBadge('Negotiate'),
                    ),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: SvcColors.primaryLight,
                        borderRadius:
                        BorderRadius.circular(SvcRadius.xs),
                      ),
                      child: Text(
                        listing.categoryName,
                        style: SvcText.badge(
                            color: SvcColors.primaryDark),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Title
                    Text(
                      listing.title,
                      style: SvcText.cardTitle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Provider
                    Row(
                      children: [
                        _ProviderAvatar(
                          avatarUrl: listing.provider?.avatarUrl,
                          name: listing.provider?.fullName ?? '',
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            listing.provider?.fullName ?? 'Provider',
                            style: SvcText.label(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Price + rating row
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          listing.priceDisplay,
                          style: SvcText.price(fontSize: 14),
                        ),
                        if (hasRating)
                          SvcWidgets.ratingRow(
                            listing.averageRating!,
                            listing.totalReviews,
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
                Icons.chevron_right_rounded,
                color: SvcColors.textLight,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURED CARD  (fixed-width 160px, used in "Best Deal" horizontal scroll)
// ─────────────────────────────────────────────────────────────────────────────
class ServiceFeaturedCard extends StatelessWidget {
  final ServiceListing listing;
  final VoidCallback onTap;

  const ServiceFeaturedCard({
    Key? key,
    required this.listing,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasRating =
        listing.averageRating != null && listing.averageRating! > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: SvcColors.surface,
          borderRadius: BorderRadius.circular(SvcRadius.lg),
          boxShadow: SvcShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            _Thumbnail(
              photoUrl: listing.mainPhoto,
              pricingType: listing.pricingType,
              emergencyService: listing.emergencyService,
              height: 120,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: SvcText.cardTitle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (hasRating) ...[
                    SvcWidgets.ratingRow(
                      listing.averageRating!,
                      listing.totalReviews,
                      iconSize: 13,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    listing.priceDisplay,
                    style: SvcText.price(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Thumbnail with overlay badges
class _Thumbnail extends StatelessWidget {
  final String? photoUrl;
  final PricingType pricingType;
  final bool emergencyService;
  final double height;

  const _Thumbnail({
    required this.photoUrl,
    required this.pricingType,
    this.emergencyService = false,
    this.height = 110,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SvcRadius.lg),
      ),
      child: Stack(
        children: [
          _buildNetworkImage(photoUrl,
              width: double.infinity, height: height),

          // Negotiable badge — top-left
          if (pricingType == PricingType.negotiable)
            Positioned(
              top: 8,
              left: 8,
              child: SvcWidgets.discountBadge('Negotiate'),
            ),

          // Emergency badge — top-right
          if (emergencyService)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: SvcColors.error,
                  borderRadius:
                  BorderRadius.circular(SvcRadius.xs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        size: 10, color: Colors.white),
                    const SizedBox(width: 2),
                    Text('24/7', style: SvcText.badge()),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small circular provider avatar with fallback initial
class _ProviderAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;

  const _ProviderAvatar({
    required this.avatarUrl,
    required this.name,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(initial),
        ),
      );
    }
    return _fallback(initial);
  }

  Widget _fallback(String initial) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: SvcColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: size * 0.45,
            fontWeight: FontWeight.w700,
            color: SvcColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED IMAGE BUILDER
// ─────────────────────────────────────────────────────────────────────────────
Widget _buildNetworkImage(
    String? url, {
      required double width,
      required double height,
    }) {
  if (url != null && url.isNotEmpty) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _imagePlaceholder(width, height),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return _imageShimmer(width, height);
      },
    );
  }
  return _imagePlaceholder(width, height);
}

Widget _imagePlaceholder(double width, double height) {
  return Container(
    width: width,
    height: height,
    color: SvcColors.inputBg,
    child: const Center(
      child: Icon(
        Icons.image_outlined,
        color: SvcColors.textLight,
        size: 32,
      ),
    ),
  );
}

Widget _imageShimmer(double width, double height) {
  return Container(
    width: width,
    height: height,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          SvcColors.inputBg,
          SvcColors.border,
          SvcColors.inputBg,
        ],
      ),
    ),
  );
}
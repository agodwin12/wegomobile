// lib/screens/services/reviews_screen.dart
// WEGO Services Marketplace - Reviews Screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/services/service_rating_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class ServiceReviewsScreen extends StatefulWidget {
  final int listingId;
  final String listingTitle;

  const ServiceReviewsScreen({
    Key? key,
    required this.listingId,
    required this.listingTitle,
  }) : super(key: key);

  @override
  State<ServiceReviewsScreen> createState() => _ServiceReviewsScreenState();
}

class _ServiceReviewsScreenState extends State<ServiceReviewsScreen> {
  bool _isLoading = true;
  double _filterRating = 0; // 0 = All

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReviews());
  }

  Future<void> _loadReviews() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await context.read<ServicesProvider>().fetchRatingsForListing(
      widget.listingId,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  List<ServiceRating> _filterRatings(List<ServiceRating> all) {
    if (_filterRating == 0) return all;
    return all.where((r) => r.rating == _filterRating.toInt()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reviews',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              widget.listingTitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoader()
          : RefreshIndicator(
        color: AppColors.primaryGold,
        onRefresh: _loadReviews,
        child: Consumer<ServicesProvider>(
          builder: (context, provider, _) {
            final allRatings = provider.ratings;

            if (allRatings.isEmpty) {
              return _buildEmptyState();
            }

            final filtered = _filterRatings(allRatings);

            return CustomScrollView(
              slivers: [
                // Stats header
                SliverToBoxAdapter(
                  child: _buildStatsHeader(allRatings, isTablet),
                ),

                // Filter chips
                SliverToBoxAdapter(
                  child: _buildFilterChips(allRatings, isTablet),
                ),

                // Results count
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 24 : 16,
                      12,
                      isTablet ? 24 : 16,
                      4,
                    ),
                    child: Text(
                      '${filtered.length} review${filtered.length == 1 ? '' : 's'}${_filterRating > 0 ? ' · ${_filterRating.toInt()} star' : ''}',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                // Reviews list
                filtered.isEmpty
                    ? SliverFillRemaining(
                  child: _buildNoFilterResults(),
                )
                    : SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 16,
                      ),
                      child: _buildReviewCard(
                        filtered[index],
                        isTablet,
                      ),
                    ),
                    childCount: filtered.length,
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATS HEADER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStatsHeader(List<ServiceRating> ratings, bool isTablet) {
    final avg = ratings.isEmpty
        ? 0.0
        : ratings.map((r) => r.rating).reduce((a, b) => a + b) /
        ratings.length;

    final breakdown = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in ratings) {
      breakdown[r.rating] = (breakdown[r.rating] ?? 0) + 1;
    }

    return Container(
      margin: EdgeInsets.all(isTablet ? 24 : 16),
      padding: EdgeInsets.all(isTablet ? 24 : 20),
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
          // Average rating
          Column(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: isTablet ? 56 : 48,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              _buildStars(avg, isTablet ? 20 : 18),
              const SizedBox(height: 6),
              Text(
                '${ratings.length} review${ratings.length == 1 ? '' : 's'}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Rating breakdown bars
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = breakdown[star] ?? 0;
                final percent =
                ratings.isEmpty ? 0.0 : count / ratings.length;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(
                        '$star',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 12, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: AppColors.backgroundLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryGold,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$count',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(double rating, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(Icons.star, size: size, color: AppColors.warning);
        } else if (i < rating && rating - i > 0) {
          return Icon(Icons.star_half, size: size, color: AppColors.warning);
        } else {
          return Icon(Icons.star_border, size: size, color: AppColors.borderMedium);
        }
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // FILTER CHIPS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildFilterChips(List<ServiceRating> ratings, bool isTablet) {
    return Container(
      height: 44,
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 0),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 16),
        children: [
          _buildFilterChip('All', 0, ratings.length),
          const SizedBox(width: 8),
          ...[5, 4, 3, 2, 1].map((star) {
            final count = ratings.where((r) => r.rating == star).length;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip('$star ★', star.toDouble(), count),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, double value, int count) {
    final isSelected = _filterRating == value;

    return GestureDetector(
      onTap: () => setState(() => _filterRating = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : AppColors.borderLight,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primaryGold.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          count > 0 ? '$label ($count)' : label,
          style: AppTypography.labelMedium.copyWith(
            color: isSelected ? AppColors.primaryBlack : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // REVIEW CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildReviewCard(ServiceRating rating, bool isTablet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
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
          // Header row
          Row(
            children: [
              // Avatar
              _buildCustomerAvatar(rating, isTablet),

              const SizedBox(width: 12),

              // Name + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.customerFirstName,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rating.relativeTime,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Star rating
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _ratingColor(rating.rating).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: _ratingColor(rating.rating),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${rating.rating}.0',
                      style: AppTypography.labelMedium.copyWith(
                        color: _ratingColor(rating.rating),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stars row
          _buildStars(rating.rating.toDouble(), 16),

          // Review text
          if (rating.hasReviewText) ...[
            const SizedBox(height: 12),
            Text(
              rating.reviewText!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ],

          // Aspect ratings
          if (rating.qualityRating != null ||
              rating.professionalismRating != null ||
              rating.communicationRating != null ||
              rating.valueRating != null) ...[
            const SizedBox(height: 16),
            _buildAspectRatings(rating, isTablet),
          ],

          // Review photos
          if (rating.hasPhotos) ...[
            const SizedBox(height: 16),
            _buildReviewPhotos(rating, isTablet),
          ],

          // Provider response
          if (rating.hasProviderResponse) ...[
            const SizedBox(height: 16),
            _buildProviderResponse(rating, isTablet),
          ],

          // Verified badge
          if (rating.isVerified) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.verified,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'Verified purchase',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerAvatar(ServiceRating rating, bool isTablet) {
    final size = isTablet ? 44.0 : 38.0;
    final avatarUrl = rating.customerAvatarUrl;
    final initial = rating.customerFirstName.isNotEmpty
        ? rating.customerFirstName[0].toUpperCase()
        : 'C';

    Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryGold,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlack,
          ),
        ),
      ),
    );

    if (avatarUrl == null || avatarUrl.isEmpty) return placeholder;

    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }

  Widget _buildAspectRatings(ServiceRating rating, bool isTablet) {
    final aspects = <String, int?>{
      'Quality': rating.qualityRating,
      'Professionalism': rating.professionalismRating,
      'Communication': rating.communicationRating,
      'Value': rating.valueRating,
    }..removeWhere((key, value) => value == null);

    if (aspects.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: aspects.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    entry.key,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (entry.value ?? 0) / 5,
                      backgroundColor: AppColors.borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGold,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value}',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReviewPhotos(ServiceRating rating, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos',
          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: rating.reviewPhotos.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showPhotoViewer(rating.reviewPhotos, index),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      rating.reviewPhotos[index],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: AppColors.backgroundLight,
                        child: const Icon(Icons.image_not_supported,
                            color: AppColors.textLight),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProviderResponse(ServiceRating rating, bool isTablet) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.reply, size: 16, color: AppColors.primaryGold),
              const SizedBox(width: 6),
              Text(
                'Provider\'s Response',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (rating.providerRespondedAt != null) ...[
                const Spacer(),
                Text(
                  rating.providerRespondedAt!.difference(DateTime.now()).abs().inDays > 0
                      ? '${rating.providerRespondedAt!.difference(DateTime.now()).abs().inDays}d ago'
                      : 'Today',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rating.providerResponse!,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PHOTO VIEWER
  // ═══════════════════════════════════════════════════════════════════
  void _showPhotoViewer(List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      photos[index],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATES
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(
                color: AppColors.primaryBlack,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading reviews...',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: AppColors.backgroundLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_border_rounded,
                size: 56,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No reviews yet',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to review this service',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilterResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.filter_list_off, size: 48, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            'No ${_filterRating.toInt()}-star reviews',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _filterRating = 0),
            child: Text(
              'Show all reviews',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primaryGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════
  Color _ratingColor(int rating) {
    switch (rating) {
      case 5: return const Color(0xFF22C55E);
      case 4: return AppColors.primaryGold;
      case 3: return AppColors.warning;
      case 2: return AppColors.error;
      case 1: return const Color(0xFFDC2626);
      default: return AppColors.textSecondary;
    }
  }
}
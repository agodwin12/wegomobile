// lib/screens/services/service_detail_screen.dart
// Service Detail Screen - FIXED for new model structure

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/services/service_listing_model.dart';
import '../../models/services/service_rating_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class ServiceDetailScreen extends StatefulWidget {
  final int? listingId;

  const ServiceDetailScreen({
    Key? key,
    this.listingId,
  }) : super(key: key);

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  int _currentImageIndex = 0;
  bool _isLoading = true;
  ServiceListing? _listing;

  @override
  void initState() {
    super.initState();
    _loadServiceDetails();
  }

  Future<void> _loadServiceDetails() async {
    setState(() => _isLoading = true);

    final provider = context.read<ServicesProvider>();

    // Try to get from selected listing first
    if (provider.selectedListing != null &&
        (widget.listingId == null ||
            provider.selectedListing!.id == widget.listingId)) {
      _listing = provider.selectedListing;
    } else if (widget.listingId != null) {
      // Fetch by ID
      _listing = await provider.fetchListingById(widget.listingId!);
    }

    // Fetch ratings
    if (_listing != null) {
      await provider.fetchRatingsForListing(_listing!.id);
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundWhite,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryGold,
          ),
        ),
      );
    }

    if (_listing == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundWhite,
          elevation: 0,
          title: const Text('Service Not Found'),
        ),
        body: Center(
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
                'Service not found',
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // ═══════════════════════════════════════════════════════
          // IMAGE GALLERY HEADER
          // ═══════════════════════════════════════════════════════
          _buildImageGallery(isTablet),

          // ═══════════════════════════════════════════════════════
          // SERVICE INFO
          // ═══════════════════════════════════════════════════════
          SliverToBoxAdapter(
            child: _buildServiceInfo(isTablet),
          ),

          // ═══════════════════════════════════════════════════════
          // PROVIDER CARD
          // ═══════════════════════════════════════════════════════
          SliverToBoxAdapter(
            child: _buildProviderCard(isTablet),
          ),

          // ═══════════════════════════════════════════════════════
          // DESCRIPTION
          // ═══════════════════════════════════════════════════════
          SliverToBoxAdapter(
            child: _buildDescription(isTablet),
          ),

          // ═══════════════════════════════════════════════════════
          // DETAILS SECTION
          // ═══════════════════════════════════════════════════════
          SliverToBoxAdapter(
            child: _buildDetailsSection(isTablet),
          ),

          // ═══════════════════════════════════════════════════════
          // REVIEWS SECTION
          // ═══════════════════════════════════════════════════════
          SliverToBoxAdapter(
            child: _buildReviewsSection(isTablet),
          ),

          // Bottom padding for FAB
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),

      // ═══════════════════════════════════════════════════════════
      // CONTACT BUTTON (FIXED AT BOTTOM)
      // ═══════════════════════════════════════════════════════════
      bottomNavigationBar: _buildBottomBar(isTablet),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // IMAGE GALLERY
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildImageGallery(bool isTablet) {
    final photos = _listing!.photos;
    final hasPhotos = photos.isNotEmpty;

    return SliverAppBar(
      expandedHeight: isTablet ? 400 : 300,
      pinned: true,
      backgroundColor: AppColors.backgroundWhite,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _shareService(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.share,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          onPressed: () => _toggleFavorite(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              color: Colors.white,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: hasPhotos
            ? Stack(
          children: [
            // Image PageView
            PageView.builder(
              itemCount: photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Image.network(
                  photos[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPlaceholderImage();
                  },
                );
              },
            ),

            // Gradient Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Image Counter
            if (photos.length > 1)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1}/${photos.length}',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        )
            : _buildPlaceholderImage(),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.backgroundLight,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 80,
          color: AppColors.textLight,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SERVICE INFO
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildServiceInfo(bool isTablet) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.all(isTablet ? 24 : 20),
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
          // Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _listing!.categoryName,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          SizedBox(height: isTablet ? 16 : 12),

          // Title
          Text(
            _listing!.title,
            style: (isTablet
                ? AppTypography.displaySmall
                : AppTypography.headlineLarge)
                .copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          SizedBox(height: isTablet ? 16 : 12),

          // Stats Row
          Row(
            children: [
              // Rating
              if (_listing!.averageRating != null &&
                  _listing!.averageRating! > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _listing!.averageRating!.toStringAsFixed(1),
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        ' (${_listing!.totalReviews})',
                        style: AppTypography.labelSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // View Count
              Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_listing!.viewCount} views',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Status Badge
              _buildStatusBadge(),
            ],
          ),

          const Divider(height: 32),

          // Pricing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _listing!.priceDisplay,
                    style: (isTablet
                        ? AppTypography.headlineLarge
                        : AppTypography.headlineMedium)
                        .copyWith(
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_listing!.pricingType == PricingType.hourly &&
                      _listing!.minimumCharge != null)
                    Text(
                      'Min: ${_listing!.minimumCharge!.toStringAsFixed(0)} FCFA',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                ],
              ),

              // Emergency Service Badge
              if (_listing!.emergencyService)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emergency,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '24/7 Available',
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;

    switch (_listing!.status) {
      case ListingStatus.active:
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        break;
      case ListingStatus.pending:
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        break;
      case ListingStatus.approved:
        bgColor = AppColors.infoLight;
        textColor = AppColors.info;
        break;
      case ListingStatus.inactive:
        bgColor = AppColors.backgroundLight;
        textColor = AppColors.textSecondary;
        break;
      case ListingStatus.rejected:
        bgColor = AppColors.errorLight;
        textColor = AppColors.error;
        break;
      case ListingStatus.deleted:
        bgColor = AppColors.backgroundLight;
        textColor = AppColors.textLight;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _listing!.status.displayName.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PROVIDER CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildProviderCard(bool isTablet) {
    final provider = _listing!.provider;
    if (provider == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(isTablet ? 20 : 16),
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
      child: Row(
        children: [
          // Profile Photo
          Container(
            width: isTablet ? 80 : 64,
            height: isTablet ? 80 : 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryGold,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: provider.avatarUrl != null
                  ? Image.network(
                provider.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAvatar(isTablet);
                },
              )
                  : _buildDefaultAvatar(isTablet),
            ),
          ),

          SizedBox(width: isTablet ? 20 : 16),

          // Provider Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider.fullName,
                        style: (isTablet
                            ? AppTypography.headlineSmall
                            : AppTypography.titleLarge)
                            .copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (provider.isVerified)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 16,
                          color: AppColors.primaryBlack,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _listing!.providerType.toUpperCase(),
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (provider.averageRating != null) ...[
                      const Icon(
                        Icons.star,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${provider.averageRating!.toStringAsFixed(1)} (${provider.totalReviews})',
                        style: AppTypography.labelMedium,
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Icon(
                      Icons.task_alt,
                      size: 16,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${provider.completedServices} services',
                      style: AppTypography.labelMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Message Button
          IconButton(
            onPressed: () => _messageProvider(),
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.message_outlined,
                color: AppColors.primaryBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(bool isTablet) {
    return Container(
      color: AppColors.primaryGold.withOpacity(0.2),
      child: Icon(
        Icons.person,
        size: isTablet ? 40 : 32,
        color: AppColors.primaryGold,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DESCRIPTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDescription(bool isTablet) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(isTablet ? 24 : 20),
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
          Text(
            'About This Service',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _listing!.description,
            style: AppTypography.bodyMedium.copyWith(
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DETAILS SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDetailsSection(bool isTablet) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(isTablet ? 24 : 20),
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
          Text(
            'Service Details',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Location
          _buildDetailRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: _listing!.locationDisplay,
            isTablet: isTablet,
          ),

          const Divider(height: 24),

          // Availability
          _buildDetailRow(
            icon: Icons.access_time,
            label: 'Availability',
            value: _listing!.availabilityDisplay,
            isTablet: isTablet,
          ),

          // Service Areas (neighborhoods)
          if (_listing!.neighborhoods.isNotEmpty) ...[
            const Divider(height: 24),
            _buildDetailRow(
              icon: Icons.map_outlined,
              label: 'Service Areas',
              value: _listing!.neighborhoods.join(', '),
              isTablet: isTablet,
            ),
          ],

          // Emergency Service badge
          if (_listing!.emergencyService) ...[
            const Divider(height: 24),
            _buildDetailRow(
              icon: Icons.emergency,
              label: 'Emergency Service',
              value: 'Available 24/7',
              isTablet: isTablet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isTablet,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: isTablet ? 24 : 20,
            color: AppColors.primaryGold,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // REVIEWS SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildReviewsSection(bool isTablet) {
    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        final ratings = provider.ratings;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: EdgeInsets.all(isTablet ? 24 : 20),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reviews',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (ratings.isNotEmpty)
                    TextButton(
                      onPressed: () => _viewAllReviews(),
                      child: const Text('View All'),
                    ),
                ],
              ),

              if (ratings.isEmpty) ...[
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.rate_review_outlined,
                        size: 48,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No reviews yet',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to review this service',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                ...ratings.take(3).map((rating) {
                  return _buildReviewCard(rating, isTablet);
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewCard(ServiceRating rating, bool isTablet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Customer Avatar
              CircleAvatar(
                radius: isTablet ? 24 : 20,
                backgroundColor: AppColors.primaryGold.withOpacity(0.2),
                child: Text(
                  rating.customerName[0].toUpperCase(),
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.customerName,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating.rating
                                ? Icons.star
                                : Icons.star_border,
                            size: 16,
                            color: AppColors.warning,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          rating.relativeTime,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (rating.reviewText != null && rating.reviewText!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              rating.reviewText!,
              style: AppTypography.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (rating.reviewPhotos != null &&
              rating.reviewPhotos!.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: rating.reviewPhotos!.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(rating.reviewPhotos![index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BOTTOM BAR (CONTACT BUTTON)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildBottomBar(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Price Display
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Starting from',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  _listing!.priceDisplay,
                  style: (isTablet
                      ? AppTypography.headlineMedium
                      : AppTypography.headlineSmall)
                      .copyWith(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 16),

            // Contact Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _contactProvider(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: AppColors.primaryBlack,
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 20 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(
                  'Contact Provider',
                  style: (isTablet
                      ? AppTypography.buttonLarge
                      : AppTypography.buttonMedium)
                      .copyWith(
                    color: AppColors.primaryBlack,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // NAVIGATION & ACTION METHODS
  // ═══════════════════════════════════════════════════════════════════

  void _shareService() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  void _toggleFavorite() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Favorite functionality coming soon')),
    );
  }

  void _messageProvider() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Messaging coming soon')),
    );
  }

  void _contactProvider() {
    Navigator.pushNamed(
      context,
      '/services/contact',
      arguments: {'listing': _listing},
    );
  }

  void _viewAllReviews() {
    Navigator.pushNamed(
      context,
      '/services/reviews',
      arguments: {'listingId': _listing!.id},
    );
  }
}
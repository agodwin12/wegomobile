// lib/models/services/service_rating_model.dart
// Service Rating & Review Model - Production Ready

/// ═══════════════════════════════════════════════════════════════════════
/// SERVICE RATING MODEL
/// ═══════════════════════════════════════════════════════════════════════

class ServiceRating {
  final int id;
  final int requestId;
  final int listingId;
  final int customerId;
  final String customerType;
  final int providerId;
  final String providerType;
  final int rating; // Overall rating 1-5
  final int? qualityRating;
  final int? professionalismRating;
  final int? communicationRating;
  final int? valueRating;
  final String? reviewText;
  final List<String> reviewPhotos;
  final String? providerResponseText;
  final DateTime? providerRespondedAt;
  final bool isFlagged;
  final String? flagReason;
  final int? flaggedBy;
  final DateTime? flaggedAt;
  final int helpfulCount;
  final bool isVerifiedService;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Nested data
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? provider;
  final Map<String, dynamic>? listing;

  ServiceRating({
    required this.id,
    required this.requestId,
    required this.listingId,
    required this.customerId,
    required this.customerType,
    required this.providerId,
    required this.providerType,
    required this.rating,
    this.qualityRating,
    this.professionalismRating,
    this.communicationRating,
    this.valueRating,
    this.reviewText,
    required this.reviewPhotos,
    this.providerResponseText,
    this.providerRespondedAt,
    required this.isFlagged,
    this.flagReason,
    this.flaggedBy,
    this.flaggedAt,
    required this.helpfulCount,
    required this.isVerifiedService,
    required this.createdAt,
    required this.updatedAt,
    this.customer,
    this.provider,
    this.listing,
  });

  /// ═══════════════════════════════════════════════════════════════════════
  /// JSON SERIALIZATION
  /// ═══════════════════════════════════════════════════════════════════════

  factory ServiceRating.fromJson(Map<String, dynamic> json) {
    return ServiceRating(
      id: json['id'] as int,
      requestId: json['request_id'] as int,
      listingId: json['listing_id'] as int,
      customerId: json['customer_id'] as int,
      customerType: json['customer_type'] as String,
      providerId: json['provider_id'] as int,
      providerType: json['provider_type'] as String,
      rating: json['rating'] as int,
      qualityRating: json['quality_rating'] as int?,
      professionalismRating: json['professionalism_rating'] as int?,
      communicationRating: json['communication_rating'] as int?,
      valueRating: json['value_rating'] as int?,
      reviewText: json['review_text'] as String?,
      reviewPhotos: json['review_photos'] != null
          ? List<String>.from(json['review_photos'] as List)
          : [],
      providerResponseText: json['provider_response_text'] as String?,
      providerRespondedAt: json['provider_responded_at'] != null
          ? DateTime.parse(json['provider_responded_at'] as String)
          : null,
      isFlagged: json['is_flagged'] as bool? ?? false,
      flagReason: json['flag_reason'] as String?,
      flaggedBy: json['flagged_by'] as int?,
      flaggedAt: json['flagged_at'] != null
          ? DateTime.parse(json['flagged_at'] as String)
          : null,
      helpfulCount: json['helpful_count'] as int? ?? 0,
      isVerifiedService: json['is_verified_service'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      customer: json['customer'] as Map<String, dynamic>?,
      provider: json['provider'] as Map<String, dynamic>?,
      listing: json['listing'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'listing_id': listingId,
      'customer_id': customerId,
      'customer_type': customerType,
      'provider_id': providerId,
      'provider_type': providerType,
      'rating': rating,
      'quality_rating': qualityRating,
      'professionalism_rating': professionalismRating,
      'communication_rating': communicationRating,
      'value_rating': valueRating,
      'review_text': reviewText,
      'review_photos': reviewPhotos,
      'provider_response_text': providerResponseText,
      'provider_responded_at': providerRespondedAt?.toIso8601String(),
      'is_flagged': isFlagged,
      'flag_reason': flagReason,
      'flagged_by': flaggedBy,
      'flagged_at': flaggedAt?.toIso8601String(),
      'helpful_count': helpfulCount,
      'is_verified_service': isVerifiedService,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'customer': customer,
      'provider': provider,
      'listing': listing,
    };
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// HELPER METHODS
  /// ═══════════════════════════════════════════════════════════════════════

  /// Get customer name
  String get customerName {
    if (customer == null) return 'Anonymous';
    return '${customer!['first_name']} ${customer!['last_name']}';
  }

  /// Get customer first name only
  String get customerFirstName {
    if (customer == null) return 'Anonymous';
    return customer!['first_name'] as String;
  }

  /// Get customer photo
  String? get customerPhoto {
    if (customer == null) return null;
    return customer!['profile_photo'] as String?;
  }

  /// Get provider name
  String get providerName {
    if (provider == null) return 'Provider';
    return '${provider!['first_name']} ${provider!['last_name']}';
  }

  /// Get listing title
  String get listingTitle {
    if (listing == null) return 'Service';
    return listing!['title'] as String;
  }

  /// Get star display (★★★★★)
  String get starDisplay {
    return '★' * rating + '☆' * (5 - rating);
  }

  /// Get star emoji display (⭐⭐⭐⭐⭐)
  String get starEmojiDisplay {
    return '⭐' * rating;
  }

  /// Get rating text
  String get ratingText {
    switch (rating) {
      case 5:
        return 'Excellent';
      case 4:
        return 'Very Good';
      case 3:
        return 'Good';
      case 2:
        return 'Fair';
      case 1:
        return 'Poor';
      default:
        return 'No Rating';
    }
  }

  /// Get rating color for UI
  String get ratingColorHex {
    if (rating >= 4) return '#4CAF50'; // Green
    if (rating == 3) return '#FF9800'; // Orange
    return '#F44336'; // Red
  }

  /// Check if has review text
  bool get hasReviewText => reviewText != null && reviewText!.isNotEmpty;

  /// Check if has photos
  bool get hasPhotos => reviewPhotos.isNotEmpty;

  /// Check if has provider response
  bool get hasProviderResponse =>
      providerResponseText != null && providerResponseText!.isNotEmpty;

  /// Get short review text (first 100 chars)
  String? get shortReviewText {
    if (reviewText == null || reviewText!.isEmpty) return null;
    if (reviewText!.length <= 100) return reviewText;
    return '${reviewText!.substring(0, 100)}...';
  }

  /// Get review length category
  String get reviewLength {
    if (reviewText == null || reviewText!.isEmpty) return 'No review';
    if (reviewText!.length < 50) return 'Short';
    if (reviewText!.length < 200) return 'Medium';
    return 'Detailed';
  }

  /// Check if verified purchase
  bool get isVerified => isVerifiedService;

  /// Get verified badge text
  String get verifiedBadge => isVerifiedService ? '✓ Verified Service' : '';

  /// Get average of aspect ratings
  double? get aspectRatingsAverage {
    final aspects = [
      qualityRating,
      professionalismRating,
      communicationRating,
      valueRating,
    ].whereType<int>().toList();

    if (aspects.isEmpty) return null;

    final sum = aspects.reduce((a, b) => a + b);
    return sum / aspects.length;
  }

  /// Get relative time (e.g., "2 days ago")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Get formatted date (e.g., "Jan 15, 2025")
  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  /// Get helpful count display
  String get helpfulCountDisplay {
    if (helpfulCount == 0) return '';
    if (helpfulCount == 1) return '1 person found this helpful';
    return '$helpfulCount people found this helpful';
  }

  /// Build aspect ratings summary
  String get aspectRatingsSummary {
    final buffer = StringBuffer();

    if (qualityRating != null) {
      buffer.write('Quality: ${'★' * qualityRating!}');
    }
    if (professionalismRating != null) {
      if (buffer.isNotEmpty) buffer.write(' | ');
      buffer.write('Professionalism: ${'★' * professionalismRating!}');
    }
    if (communicationRating != null) {
      if (buffer.isNotEmpty) buffer.write(' | ');
      buffer.write('Communication: ${'★' * communicationRating!}');
    }
    if (valueRating != null) {
      if (buffer.isNotEmpty) buffer.write(' | ');
      buffer.write('Value: ${'★' * valueRating!}');
    }

    return buffer.toString();
  }

  /// Check if all aspect ratings are 5 stars
  bool get isPerfectRating {
    if (rating != 5) return false;

    return (qualityRating == null || qualityRating == 5) &&
        (professionalismRating == null || professionalismRating == 5) &&
        (communicationRating == null || communicationRating == 5) &&
        (valueRating == null || valueRating == 5);
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// COPY WITH
  /// ═══════════════════════════════════════════════════════════════════════

  ServiceRating copyWith({
    int? id,
    int? requestId,
    int? listingId,
    int? customerId,
    String? customerType,
    int? providerId,
    String? providerType,
    int? rating,
    int? qualityRating,
    int? professionalismRating,
    int? communicationRating,
    int? valueRating,
    String? reviewText,
    List<String>? reviewPhotos,
    String? providerResponseText,
    DateTime? providerRespondedAt,
    bool? isFlagged,
    String? flagReason,
    int? flaggedBy,
    DateTime? flaggedAt,
    int? helpfulCount,
    bool? isVerifiedService,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? customer,
    Map<String, dynamic>? provider,
    Map<String, dynamic>? listing,
  }) {
    return ServiceRating(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      listingId: listingId ?? this.listingId,
      customerId: customerId ?? this.customerId,
      customerType: customerType ?? this.customerType,
      providerId: providerId ?? this.providerId,
      providerType: providerType ?? this.providerType,
      rating: rating ?? this.rating,
      qualityRating: qualityRating ?? this.qualityRating,
      professionalismRating: professionalismRating ?? this.professionalismRating,
      communicationRating: communicationRating ?? this.communicationRating,
      valueRating: valueRating ?? this.valueRating,
      reviewText: reviewText ?? this.reviewText,
      reviewPhotos: reviewPhotos ?? this.reviewPhotos,
      providerResponseText: providerResponseText ?? this.providerResponseText,
      providerRespondedAt: providerRespondedAt ?? this.providerRespondedAt,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      flaggedBy: flaggedBy ?? this.flaggedBy,
      flaggedAt: flaggedAt ?? this.flaggedAt,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isVerifiedService: isVerifiedService ?? this.isVerifiedService,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customer: customer ?? this.customer,
      provider: provider ?? this.provider,
      listing: listing ?? this.listing,
    );
  }

  @override
  String toString() {
    return 'ServiceRating(id: $id, rating: $rating, customer: $customerName)';
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// RATING LIST RESPONSE MODEL
/// ═══════════════════════════════════════════════════════════════════════

class RatingListResponse {
  final bool success;
  final String message;
  final List<ServiceRating> ratings;
  final Map<String, dynamic>? statistics;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  RatingListResponse({
    required this.success,
    required this.message,
    required this.ratings,
    this.statistics,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory RatingListResponse.fromJson(Map<String, dynamic> json) {
    return RatingListResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      ratings: (json['data']['ratings'] as List)
          .map((item) => ServiceRating.fromJson(item as Map<String, dynamic>))
          .toList(),
      statistics: json['data']['statistics'] as Map<String, dynamic>?,
      total: json['data']['pagination']['total'] as int,
      page: json['data']['pagination']['page'] as int,
      limit: json['data']['pagination']['limit'] as int,
      totalPages: json['data']['pagination']['total_pages'] as int,
    );
  }

  bool get hasMore => page < totalPages;

  /// Get average rating from statistics
  double? get averageRating {
    if (statistics == null) return null;
    final avg = statistics!['average_rating'];
    return avg != null ? (avg as num).toDouble() : null;
  }

  /// Get rating breakdown (5 star: X, 4 star: Y, etc.)
  Map<int, int>? get ratingBreakdown {
    if (statistics == null) return null;

    final breakdown = statistics!['rating_breakdown'] as Map<String, dynamic>?;
    if (breakdown == null) return null;

    return {
      5: breakdown['5_star'] as int? ?? 0,
      4: breakdown['4_star'] as int? ?? 0,
      3: breakdown['3_star'] as int? ?? 0,
      2: breakdown['2_star'] as int? ?? 0,
      1: breakdown['1_star'] as int? ?? 0,
    };
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// SINGLE RATING RESPONSE MODEL
/// ═══════════════════════════════════════════════════════════════════════

class SingleRatingResponse {
  final bool success;
  final String message;
  final ServiceRating rating;

  SingleRatingResponse({
    required this.success,
    required this.message,
    required this.rating,
  });

  factory SingleRatingResponse.fromJson(Map<String, dynamic> json) {
    return SingleRatingResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      rating: ServiceRating.fromJson(json['data']['rating'] as Map<String, dynamic>),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// RATING STATISTICS MODEL
/// For provider/listing rating summary
/// ═══════════════════════════════════════════════════════════════════════

class RatingStatistics {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingBreakdown; // star -> count
  final int fiveStarCount;
  final int fourStarCount;
  final int threeStarCount;
  final int twoStarCount;
  final int oneStarCount;
  final double? averageQuality;
  final double? averageProfessionalism;
  final double? averageCommunication;
  final double? averageValue;

  RatingStatistics({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingBreakdown,
    required this.fiveStarCount,
    required this.fourStarCount,
    required this.threeStarCount,
    required this.twoStarCount,
    required this.oneStarCount,
    this.averageQuality,
    this.averageProfessionalism,
    this.averageCommunication,
    this.averageValue,
  });

  factory RatingStatistics.fromJson(Map<String, dynamic> json) {
    final breakdown = json['rating_breakdown'] as Map<String, dynamic>? ?? {};

    return RatingStatistics(
      averageRating: (json['average_rating'] as num).toDouble(),
      totalReviews: json['total_reviews'] as int,
      ratingBreakdown: {
        5: breakdown['5_star'] as int? ?? 0,
        4: breakdown['4_star'] as int? ?? 0,
        3: breakdown['3_star'] as int? ?? 0,
        2: breakdown['2_star'] as int? ?? 0,
        1: breakdown['1_star'] as int? ?? 0,
      },
      fiveStarCount: breakdown['5_star'] as int? ?? 0,
      fourStarCount: breakdown['4_star'] as int? ?? 0,
      threeStarCount: breakdown['3_star'] as int? ?? 0,
      twoStarCount: breakdown['2_star'] as int? ?? 0,
      oneStarCount: breakdown['1_star'] as int? ?? 0,
      averageQuality: json['average_quality'] != null
          ? (json['average_quality'] as num).toDouble()
          : null,
      averageProfessionalism: json['average_professionalism'] != null
          ? (json['average_professionalism'] as num).toDouble()
          : null,
      averageCommunication: json['average_communication'] != null
          ? (json['average_communication'] as num).toDouble()
          : null,
      averageValue: json['average_value'] != null
          ? (json['average_value'] as num).toDouble()
          : null,
    );
  }

  /// Get star display (e.g., "4.8 ★")
  String get starDisplay {
    return '${averageRating.toStringAsFixed(1)} ★';
  }

  /// Get display with review count (e.g., "4.8 ★ (156)")
  String get displayWithCount {
    return '${averageRating.toStringAsFixed(1)} ★ ($totalReviews)';
  }

  /// Get percentage for each star rating
  Map<int, double> get ratingPercentages {
    if (totalReviews == 0) return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

    return {
      5: (fiveStarCount / totalReviews * 100),
      4: (fourStarCount / totalReviews * 100),
      3: (threeStarCount / totalReviews * 100),
      2: (twoStarCount / totalReviews * 100),
      1: (oneStarCount / totalReviews * 100),
    };
  }

  /// Get most common rating
  int get mostCommonRating {
    var maxCount = 0;
    var maxRating = 5;

    ratingBreakdown.forEach((rating, count) {
      if (count > maxCount) {
        maxCount = count;
        maxRating = rating;
      }
    });

    return maxRating;
  }

  /// Check if mostly positive (4+ stars >= 75%)
  bool get isMostlyPositive {
    if (totalReviews == 0) return false;
    final positiveCount = fiveStarCount + fourStarCount;
    return (positiveCount / totalReviews) >= 0.75;
  }
}
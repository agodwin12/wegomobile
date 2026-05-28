

import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// HELPER FUNCTIONS
/// ═══════════════════════════════════════════════════════════════════════

int _parseInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

String _parseString(dynamic value, {String defaultValue = ''}) {
  if (value == null) return defaultValue;
  return value.toString();
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return null;
    }
  }
  return null;
}

List<String> _parseStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value
        .map((e) => e?.toString())
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .toList();
  }
  return [];
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is String) return value.toLowerCase() == 'true' || value == '1';
  return false;
}

/// ═══════════════════════════════════════════════════════════════════════
/// SERVICE RATING MODEL
/// ═══════════════════════════════════════════════════════════════════════

class ServiceRating {
  final int id;
  final int requestId;
  final int listingId;

  // ✅ FIXED: These are UUIDs (strings) not integers
  final String customerId;
  final String providerId;

  final int rating;
  final int? qualityRating;
  final int? professionalismRating;
  final int? communicationRating;
  final int? valueRating;
  final String? reviewText;
  final List<String> reviewPhotos;
  final String? providerResponse;
  final DateTime? providerRespondedAt;
  final bool isFlagged;
  final String? flaggedReason;
  final int helpfulCount;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Nested data
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? provider;
  final Map<String, dynamic>? listing;
  final Map<String, dynamic>? request;

  ServiceRating({
    required this.id,
    required this.requestId,
    required this.listingId,
    required this.customerId,
    required this.providerId,
    required this.rating,
    this.qualityRating,
    this.professionalismRating,
    this.communicationRating,
    this.valueRating,
    this.reviewText,
    required this.reviewPhotos,
    this.providerResponse,
    this.providerRespondedAt,
    required this.isFlagged,
    this.flaggedReason,
    required this.helpfulCount,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
    this.customer,
    this.provider,
    this.listing,
    this.request,
  });

  /// ═══════════════════════════════════════════════════════════════════════
  /// JSON SERIALIZATION - FULLY NULL-SAFE
  /// ═══════════════════════════════════════════════════════════════════════

  factory ServiceRating.fromJson(Map<String, dynamic> json) {
    try {
      return ServiceRating(
        id: _parseInt(json['id']),
        requestId: _parseInt(json['request_id']),
        listingId: _parseInt(json['listing_id']),

        // ✅ FIXED: UUID fields — always parse as String
        customerId: _parseString(json['customer_id']),
        providerId: _parseString(json['provider_id']),

        rating: _parseInt(json['rating'], defaultValue: 1),
        qualityRating: json['quality_rating'] != null
            ? _parseInt(json['quality_rating'])
            : null,
        professionalismRating: json['professionalism_rating'] != null
            ? _parseInt(json['professionalism_rating'])
            : null,
        communicationRating: json['communication_rating'] != null
            ? _parseInt(json['communication_rating'])
            : null,
        valueRating: json['value_rating'] != null
            ? _parseInt(json['value_rating'])
            : null,
        reviewText: json['review_text']?.toString(),

        // ✅ Handle both field names from backend
        reviewPhotos: _parseStringList(
          json['review_photos'],
        ),

        // ✅ Handle both field names from backend
        providerResponse: json['provider_response']?.toString() ??
            json['provider_response_text']?.toString(),

        providerRespondedAt: _parseDateTime(
          json['provider_responded_at'],
        ),

        isFlagged: _parseBool(json['is_flagged']),

        // ✅ Handle both field names from backend
        flaggedReason: json['flagged_reason']?.toString() ??
            json['flag_reason']?.toString(),

        helpfulCount: _parseInt(json['helpful_count']),

        // ✅ Handle both field names from backend
        isVerified: _parseBool(json['is_verified'] ?? json['is_verified_service']),

        createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']) ??
            DateTime.now(),
        updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']) ??
            DateTime.now(),

        customer: json['customer'] as Map<String, dynamic>?,
        provider: json['provider'] as Map<String, dynamic>?,
        listing: json['listing'] as Map<String, dynamic>?,
        request: json['request'] as Map<String, dynamic>?,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [SERVICE_RATING_MODEL] Error parsing: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'listing_id': listingId,
      'customer_id': customerId,
      'provider_id': providerId,
      'rating': rating,
      'quality_rating': qualityRating,
      'professionalism_rating': professionalismRating,
      'communication_rating': communicationRating,
      'value_rating': valueRating,
      'review_text': reviewText,
      'review_photos': reviewPhotos,
      'provider_response': providerResponse,
      'provider_responded_at': providerRespondedAt?.toIso8601String(),
      'is_flagged': isFlagged,
      'flagged_reason': flaggedReason,
      'helpful_count': helpfulCount,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'customer': customer,
      'provider': provider,
      'listing': listing,
      'request': request,
    };
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// HELPER METHODS
  /// ═══════════════════════════════════════════════════════════════════════

  String get customerName {
    if (customer == null) return 'Anonymous';
    final firstName = customer!['first_name']?.toString() ?? '';
    final lastName = customer!['last_name']?.toString() ?? '';
    return '$firstName $lastName'.trim().isEmpty
        ? 'Anonymous'
        : '$firstName $lastName'.trim();
  }

  String get customerFirstName {
    if (customer == null) return 'Anonymous';
    return customer!['first_name']?.toString() ?? 'Anonymous';
  }

  String? get customerAvatarUrl {
    if (customer == null) return null;
    return customer!['avatar_url']?.toString();
  }

  String get providerName {
    if (provider == null) return 'Provider';
    final firstName = provider!['first_name']?.toString() ?? '';
    final lastName = provider!['last_name']?.toString() ?? '';
    return '$firstName $lastName'.trim().isEmpty
        ? 'Provider'
        : '$firstName $lastName'.trim();
  }

  String get listingTitle {
    if (listing == null) return 'Service';
    return listing!['title']?.toString() ?? 'Service';
  }

  String get starDisplay => '★' * rating + '☆' * (5 - rating);

  String get starEmojiDisplay => '⭐' * rating;

  String get ratingText {
    switch (rating) {
      case 5: return 'Excellent';
      case 4: return 'Very Good';
      case 3: return 'Good';
      case 2: return 'Fair';
      case 1: return 'Poor';
      default: return 'No Rating';
    }
  }

  bool get hasReviewText => reviewText != null && reviewText!.isNotEmpty;

  bool get hasPhotos => reviewPhotos.isNotEmpty;

  bool get hasProviderResponse =>
      providerResponse != null && providerResponse!.isNotEmpty;

  String? get shortReviewText {
    if (reviewText == null || reviewText!.isEmpty) return null;
    if (reviewText!.length <= 100) return reviewText;
    return '${reviewText!.substring(0, 100)}...';
  }

  double? get aspectRatingsAverage {
    final aspects = [
      qualityRating,
      professionalismRating,
      communicationRating,
      valueRating,
    ].whereType<int>().toList();

    if (aspects.isEmpty) return null;
    return aspects.reduce((a, b) => a + b) / aspects.length;
  }

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

  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  String get helpfulCountDisplay {
    if (helpfulCount == 0) return '';
    if (helpfulCount == 1) return '1 person found this helpful';
    return '$helpfulCount people found this helpful';
  }

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
    String? customerId,
    String? providerId,
    int? rating,
    int? qualityRating,
    int? professionalismRating,
    int? communicationRating,
    int? valueRating,
    String? reviewText,
    List<String>? reviewPhotos,
    String? providerResponse,
    DateTime? providerRespondedAt,
    bool? isFlagged,
    String? flaggedReason,
    int? helpfulCount,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? customer,
    Map<String, dynamic>? provider,
    Map<String, dynamic>? listing,
    Map<String, dynamic>? request,
  }) {
    return ServiceRating(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      listingId: listingId ?? this.listingId,
      customerId: customerId ?? this.customerId,
      providerId: providerId ?? this.providerId,
      rating: rating ?? this.rating,
      qualityRating: qualityRating ?? this.qualityRating,
      professionalismRating:
      professionalismRating ?? this.professionalismRating,
      communicationRating: communicationRating ?? this.communicationRating,
      valueRating: valueRating ?? this.valueRating,
      reviewText: reviewText ?? this.reviewText,
      reviewPhotos: reviewPhotos ?? this.reviewPhotos,
      providerResponse: providerResponse ?? this.providerResponse,
      providerRespondedAt: providerRespondedAt ?? this.providerRespondedAt,
      isFlagged: isFlagged ?? this.isFlagged,
      flaggedReason: flaggedReason ?? this.flaggedReason,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customer: customer ?? this.customer,
      provider: provider ?? this.provider,
      listing: listing ?? this.listing,
      request: request ?? this.request,
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
    try {
      // ✅ Handle both direct array and wrapped response
      List<ServiceRating> ratingsList = [];
      Map<String, dynamic>? stats;
      int total = 0;
      int page = 1;
      int limit = 10;
      int totalPages = 1;

      final data = json['data'];

      if (data is List) {
        // Backend returns data as direct array
        ratingsList = data
            .map((item) => ServiceRating.fromJson(item as Map<String, dynamic>))
            .toList();
        total = ratingsList.length;
      } else if (data is Map<String, dynamic>) {
        // Backend returns wrapped object
        final rawList = data['ratings'] as List? ?? [];
        ratingsList = rawList
            .map((item) => ServiceRating.fromJson(item as Map<String, dynamic>))
            .toList();
        stats = data['statistics'] as Map<String, dynamic>?;

        final pagination = data['pagination'] as Map<String, dynamic>?
            ?? json['pagination'] as Map<String, dynamic>?
            ?? {};
        total = _parseInt(pagination['total'], defaultValue: ratingsList.length);
        page = _parseInt(pagination['page'], defaultValue: 1);
        limit = _parseInt(pagination['limit'], defaultValue: 10);
        totalPages = _parseInt(
          pagination['totalPages'] ?? pagination['total_pages'],
          defaultValue: 1,
        );
      }

      return RatingListResponse(
        success: json['success'] as bool? ?? true,
        message: json['message']?.toString() ?? '',
        ratings: ratingsList,
        statistics: stats,
        total: total,
        page: page,
        limit: limit,
        totalPages: totalPages,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [RATING_LIST_RESPONSE] Error parsing: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  bool get hasMore => page < totalPages;

  double? get averageRating {
    if (statistics == null) return null;
    return _parseDouble(statistics!['average_rating']);
  }

  Map<int, int>? get ratingBreakdown {
    if (statistics == null) return null;
    final breakdown = statistics!['rating_distribution'] as Map<String, dynamic>?
        ?? statistics!['rating_breakdown'] as Map<String, dynamic>?;
    if (breakdown == null) return null;

    return {
      5: _parseInt(breakdown['5'] ?? breakdown['5_star']),
      4: _parseInt(breakdown['4'] ?? breakdown['4_star']),
      3: _parseInt(breakdown['3'] ?? breakdown['3_star']),
      2: _parseInt(breakdown['2'] ?? breakdown['2_star']),
      1: _parseInt(breakdown['1'] ?? breakdown['1_star']),
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
    final data = json['data'];
    ServiceRating ratingData;

    if (data is Map<String, dynamic> && data.containsKey('rating')) {
      ratingData = ServiceRating.fromJson(
          data['rating'] as Map<String, dynamic>);
    } else if (data is Map<String, dynamic>) {
      ratingData = ServiceRating.fromJson(data);
    } else {
      throw Exception('Invalid response format for SingleRatingResponse');
    }

    return SingleRatingResponse(
      success: json['success'] as bool? ?? true,
      message: json['message']?.toString() ?? '',
      rating: ratingData,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// RATING STATISTICS MODEL
/// ═══════════════════════════════════════════════════════════════════════

class RatingStatistics {
  final double averageRating;
  final int totalReviews;
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
    // ✅ Handle both rating_distribution and rating_breakdown key names
    final breakdown = json['rating_distribution'] as Map<String, dynamic>?
        ?? json['rating_breakdown'] as Map<String, dynamic>?
        ?? {};

    return RatingStatistics(
      averageRating: _parseDouble(json['average_rating']) ?? 0.0,
      totalReviews: _parseInt(json['total_reviews']),
      fiveStarCount: _parseInt(breakdown['5'] ?? breakdown['5_star']),
      fourStarCount: _parseInt(breakdown['4'] ?? breakdown['4_star']),
      threeStarCount: _parseInt(breakdown['3'] ?? breakdown['3_star']),
      twoStarCount: _parseInt(breakdown['2'] ?? breakdown['2_star']),
      oneStarCount: _parseInt(breakdown['1'] ?? breakdown['1_star']),
      averageQuality: _parseDouble(json['average_quality']),
      averageProfessionalism: _parseDouble(json['average_professionalism']),
      averageCommunication: _parseDouble(json['average_communication']),
      averageValue: _parseDouble(json['average_value']),
    );
  }

  String get starDisplay =>
      '${averageRating.toStringAsFixed(1)} ★';

  String get displayWithCount =>
      '${averageRating.toStringAsFixed(1)} ★ ($totalReviews)';

  Map<int, double> get ratingPercentages {
    if (totalReviews == 0) return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    return {
      5: fiveStarCount / totalReviews * 100,
      4: fourStarCount / totalReviews * 100,
      3: threeStarCount / totalReviews * 100,
      2: twoStarCount / totalReviews * 100,
      1: oneStarCount / totalReviews * 100,
    };
  }

  bool get isMostlyPositive {
    if (totalReviews == 0) return false;
    return ((fiveStarCount + fourStarCount) / totalReviews) >= 0.75;
  }
}
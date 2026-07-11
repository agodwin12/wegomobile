// lib/models/services/service_listing_model.dart
// ✅ COMPLETE FIX - All null safety issues resolved

import 'category_model.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// HELPER FUNCTIONS - Safe parsing for all types
/// ═══════════════════════════════════════════════════════════════════════

/// Safely parse String (handles null)
String? _parseString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.isEmpty ? null : value;
  return value.toString();
}

/// Safely parse non-nullable String with fallback
String _parseStringRequired(dynamic value, String fallback) {
  if (value == null) return fallback;
  if (value is String) return value.isEmpty ? fallback : value;
  return value.toString();
}

/// Safely parse double
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

/// Safely parse int
int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

/// Safely parse non-nullable int with fallback
int _parseIntRequired(dynamic value, int fallback) {
  final result = _parseInt(value);
  return result ?? fallback;
}

/// Safely parse DateTime
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

/// Safely parse DateTime (required)
DateTime _parseDateTimeRequired(dynamic value) {
  final result = _parseDateTime(value);
  return result ?? DateTime.now();
}

/// Safely parse List<String>
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

/// Safely parse bool
bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value == 1;
  if (value is String) return value.toLowerCase() == 'true' || value == '1';
  return false;
}

/// ═══════════════════════════════════════════════════════════════════════
/// ENUMS
/// ═══════════════════════════════════════════════════════════════════════

enum PricingType {
  hourly,
  fixed,
  negotiable;

  String get displayName {
    switch (this) {
      case PricingType.hourly:
        return 'Hourly Rate';
      case PricingType.fixed:
        return 'Fixed Price';
      case PricingType.negotiable:
        return 'Negotiable';
    }
  }

  static PricingType fromString(String? value) {
    if (value == null) return PricingType.negotiable;
    switch (value.toLowerCase()) {
      case 'hourly':
        return PricingType.hourly;
      case 'fixed':
        return PricingType.fixed;
      case 'negotiable':
        return PricingType.negotiable;
      default:
        return PricingType.negotiable;
    }
  }
}

enum ListingStatus {
  pending,
  approved,
  active,
  inactive,
  rejected,
  deleted;

  String get displayName {
    switch (this) {
      case ListingStatus.pending:
        return 'Pending Approval';
      case ListingStatus.approved:
        return 'Approved';
      case ListingStatus.active:
        return 'Active';
      case ListingStatus.inactive:
        return 'Inactive';
      case ListingStatus.rejected:
        return 'Rejected';
      case ListingStatus.deleted:
        return 'Deleted';
    }
  }

  static ListingStatus fromString(String? value) {
    if (value == null) return ListingStatus.pending;
    switch (value.toLowerCase()) {
      case 'pending':
      case 'pending_review': // backend v2: post awaiting moderation
      case 'draft':
        return ListingStatus.pending;
      case 'approved':
        return ListingStatus.approved;
      case 'active':
      case 'hero_pending': // live, hero placement under review
        return ListingStatus.active;
      case 'inactive':
      case 'expired': // plan ran out — hidden, can be renewed
      case 'suspended':
        return ListingStatus.inactive;
      case 'rejected':
        return ListingStatus.rejected;
      case 'deleted':
        return ListingStatus.deleted;
      default:
        return ListingStatus.pending;
    }
  }

  bool get isActionable => this == ListingStatus.pending || this == ListingStatus.rejected;
  bool get isVisible => this == ListingStatus.active;
  bool get canEdit => this == ListingStatus.pending || this == ListingStatus.rejected || this == ListingStatus.approved;
}

/// ═══════════════════════════════════════════════════════════════════════
/// PROVIDER MODEL (Nested in Listing)
/// ═══════════════════════════════════════════════════════════════════════

class ServiceProvider {
  final String uuid;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final double? averageRating;
  final int totalReviews;
  final int completedServices;
  final int? responseTimeMinutes;
  final bool isVerified;

  ServiceProvider({
    required this.uuid,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    this.avatarUrl,
    this.averageRating,
    required this.totalReviews,
    required this.completedServices,
    this.responseTimeMinutes,
    required this.isVerified,
  });

  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    return ServiceProvider(
      uuid: _parseStringRequired(json['uuid'], ''),
      firstName: _parseStringRequired(json['first_name'], 'Unknown'),
      lastName: _parseStringRequired(json['last_name'], ''),
      phone: _parseString(json['phone'] ?? json['phone_e164']),
      email: _parseString(json['email']),
      avatarUrl: _parseString(json['avatar_url']),
      averageRating: _parseDouble(json['average_rating']),
      totalReviews: _parseIntRequired(json['total_reviews'], 0),
      completedServices: _parseIntRequired(json['completed_services'], 0),
      responseTimeMinutes: _parseInt(json['response_time_minutes']),
      isVerified: _parseBool(json['is_verified']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'avatar_url': avatarUrl,
      'average_rating': averageRating,
      'total_reviews': totalReviews,
      'completed_services': completedServices,
      'response_time_minutes': responseTimeMinutes,
      'is_verified': isVerified,
    };
  }

  String get fullName => '$firstName $lastName';

  String get verificationBadge {
    if (isVerified) return '✓ Verified';
    return 'Unverified';
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// SERVICE LISTING MODEL
/// ═══════════════════════════════════════════════════════════════════════

class ServiceListing {
  final int id;
  final String listingId;
  final String providerId;
  final String providerType;
  final int categoryId;
  final String categoryName;
  final String? subcategoryName;
  final String title;
  final String description;
  final PricingType pricingType;
  final double? hourlyRate;
  final double? minimumCharge;
  final double? fixedPrice;
  final String city;
  final List<String> neighborhoods;
  final double? serviceRadiusKm;
  final List<String> photos;
  final String? availableDays;
  final String? availableHours;
  final bool emergencyService;
  final int? yearsExperience;
  final String? certifications;
  final String? portfolioLinks;
  final ListingStatus status;
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final int viewCount;
  final int contactCount;
  final int bookingCount;
  final double? averageRating;
  final int totalReviews;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool isHero;            // featured in the hero carousel
  final DateTime? heroExpiresAt;

  final dynamic category; // Keep as dynamic to hold raw JSON
  final ServiceProvider? provider;

  ServiceListing({
    required this.id,
    required this.listingId,
    required this.providerId,
    required this.providerType,
    required this.categoryId,
    required this.categoryName,
    this.subcategoryName,
    required this.title,
    required this.description,
    required this.pricingType,
    this.hourlyRate,
    this.minimumCharge,
    this.fixedPrice,
    required this.city,
    required this.neighborhoods,
    this.serviceRadiusKm,
    required this.photos,
    this.availableDays,
    this.availableHours,
    required this.emergencyService,
    this.yearsExperience,
    this.certifications,
    this.portfolioLinks,
    required this.status,
    this.rejectionReason,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    required this.viewCount,
    required this.contactCount,
    required this.bookingCount,
    this.averageRating,
    required this.totalReviews,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isHero = false,
    this.heroExpiresAt,
    this.category,
    this.provider,
  });

  /// ═══════════════════════════════════════════════════════════════════════
  /// JSON SERIALIZATION - COMPLETE NULL-SAFE VERSION
  /// ═══════════════════════════════════════════════════════════════════════

  factory ServiceListing.fromJson(Map<String, dynamic> json) {
    try {
      // ✅ Extract category name with multiple fallbacks
      String extractCategoryName() {
        // Try category_name field first
        if (json['category_name'] != null) {
          final name = _parseString(json['category_name']);
          if (name != null && name.isNotEmpty) return name;
        }

        // Try category object
        if (json['category'] != null && json['category'] is Map) {
          final categoryMap = json['category'] as Map<String, dynamic>;
          final nameEn = _parseString(categoryMap['name_en']);
          if (nameEn != null && nameEn.isNotEmpty) return nameEn;

          final nameFr = _parseString(categoryMap['name_fr']);
          if (nameFr != null && nameFr.isNotEmpty) return nameFr;

          final name = _parseString(categoryMap['name']);
          if (name != null && name.isNotEmpty) return name;
        }

        return 'Uncategorized';
      }

      return ServiceListing(
        id: _parseIntRequired(json['id'], 0),
        listingId: _parseStringRequired(json['listing_id'], ''),
        providerId: _parseStringRequired(json['provider_id'], ''),
        providerType: _parseStringRequired(json['provider_type'], 'driver'),
        categoryId: _parseIntRequired(json['category_id'], 0),
        categoryName: extractCategoryName(),
        subcategoryName: _parseString(json['subcategory_name']),
        title: _parseStringRequired(json['title'], 'Untitled Service'),
        description: _parseStringRequired(json['description'], ''),
        pricingType: PricingType.fromString(_parseString(json['pricing_type'])),
        hourlyRate: _parseDouble(json['hourly_rate']),
        minimumCharge: _parseDouble(json['minimum_charge']),
        fixedPrice: _parseDouble(json['fixed_price']),
        city: _parseStringRequired(json['city'], ''),
        neighborhoods: _parseStringList(json['neighborhoods']),
        serviceRadiusKm: _parseDouble(json['service_radius_km']),
        photos: _parseStringList(json['photos']),
        availableDays: _parseString(json['available_days']),
        availableHours: _parseString(json['available_hours']),
        emergencyService: _parseBool(json['emergency_service']),
        yearsExperience: _parseInt(json['years_experience']),
        certifications: _parseString(json['certifications']),
        portfolioLinks: _parseString(json['portfolio_links']),
        status: ListingStatus.fromString(_parseString(json['status'])),
        rejectionReason: _parseString(json['rejection_reason']),
        approvedBy: _parseString(json['approved_by']),
        approvedAt: _parseDateTime(json['approved_at']),
        rejectedBy: _parseString(json['rejected_by']),
        rejectedAt: _parseDateTime(json['rejected_at']),
        viewCount: _parseIntRequired(json['view_count'], 0),
        contactCount: _parseIntRequired(json['contact_count'], 0),
        bookingCount: _parseIntRequired(json['booking_count'], 0),
        averageRating: _parseDouble(json['average_rating']),
        totalReviews: _parseIntRequired(json['total_reviews'], 0),
        createdAt: _parseDateTimeRequired(json['createdAt'] ?? json['created_at']),
        updatedAt: _parseDateTimeRequired(json['updatedAt'] ?? json['updated_at']),
        deletedAt: _parseDateTime(json['deletedAt'] ?? json['deleted_at']),
        isHero: _parseBool(json['is_hero']),
        heroExpiresAt: _parseDateTime(json['hero_expires_at']),
        category: json['category'], // Keep raw JSON
        provider: json['provider'] != null
            ? ServiceProvider.fromJson(json['provider'] as Map<String, dynamic>)
            : null,
      );
    } catch (e, stackTrace) {
      print('❌ [MODEL] ServiceListing.fromJson error: $e');
      print('❌ [MODEL] Stack trace: $stackTrace');
      print('❌ [MODEL] JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listing_id': listingId,
      'provider_id': providerId,
      'provider_type': providerType,
      'category_id': categoryId,
      'category_name': categoryName,
      'subcategory_name': subcategoryName,
      'title': title,
      'description': description,
      'pricing_type': pricingType.name,
      'hourly_rate': hourlyRate,
      'minimum_charge': minimumCharge,
      'fixed_price': fixedPrice,
      'is_hero': isHero,
      'hero_expires_at': heroExpiresAt?.toIso8601String(),
      'city': city,
      'neighborhoods': neighborhoods,
      'service_radius_km': serviceRadiusKm,
      'photos': photos,
      'available_days': availableDays,
      'available_hours': availableHours,
      'emergency_service': emergencyService,
      'years_experience': yearsExperience,
      'certifications': certifications,
      'portfolio_links': portfolioLinks,
      'status': status.name,
      'rejection_reason': rejectionReason,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_by': rejectedBy,
      'rejected_at': rejectedAt?.toIso8601String(),
      'view_count': viewCount,
      'contact_count': contactCount,
      'booking_count': bookingCount,
      'average_rating': averageRating,
      'total_reviews': totalReviews,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'category': category,
      'provider': provider?.toJson(),
    };
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// HELPER METHODS
  /// ═══════════════════════════════════════════════════════════════════════

  String get mainPhoto => photos.isNotEmpty
      ? photos.first
      : 'https://via.placeholder.com/400x300?text=No+Photo';

  String get priceDisplay {
    switch (pricingType) {
      case PricingType.hourly:
        return '${hourlyRate?.toStringAsFixed(0) ?? '0'} FCFA/hr';
      case PricingType.fixed:
        return '${fixedPrice?.toStringAsFixed(0) ?? '0'} FCFA';
      case PricingType.negotiable:
        return 'Negotiable';
    }
  }

  String get priceRangeDisplay {
    if (pricingType == PricingType.hourly && minimumCharge != null) {
      return '${minimumCharge?.toStringAsFixed(0)} - ${hourlyRate?.toStringAsFixed(0)} FCFA';
    }
    return priceDisplay;
  }

  String get detailedPriceInfo {
    switch (pricingType) {
      case PricingType.hourly:
        if (minimumCharge != null) {
          return '${hourlyRate?.toStringAsFixed(0)} FCFA/hour (Min: ${minimumCharge?.toStringAsFixed(0)} FCFA)';
        }
        return '${hourlyRate?.toStringAsFixed(0)} FCFA/hour';
      case PricingType.fixed:
        return '${fixedPrice?.toStringAsFixed(0)} FCFA (Fixed)';
      case PricingType.negotiable:
        return 'Price Negotiable';
    }
  }

  String get ratingDisplay {
    if (averageRating == null || totalReviews == 0) {
      return 'No reviews yet';
    }
    return '★ ${averageRating!.toStringAsFixed(1)} ($totalReviews)';
  }

  bool get hasReviews => totalReviews > 0;

  String get availabilityDisplay {
    if (emergencyService) return '⚡ 24/7 Emergency Service';
    if (availableDays != null && availableDays!.isNotEmpty) {
      return availableDays!;
    }
    return 'Schedule on request';
  }

  String get locationDisplay {
    if (neighborhoods.isNotEmpty) {
      return '$city (${neighborhoods.join(', ')})';
    }
    return city;
  }

  bool get isProviderVerified => provider?.isVerified ?? false;

  String get experienceDisplay {
    if (yearsExperience == null) return 'Experience not specified';
    if (yearsExperience == 1) return '1 year experience';
    return '$yearsExperience years experience';
  }

  String get shortDescription {
    if (description.length <= 100) return description;
    return '${description.substring(0, 100)}...';
  }

  String get serviceAreaDisplay {
    if (serviceRadiusKm != null) {
      return '$city (${serviceRadiusKm}km radius)';
    }
    return locationDisplay;
  }

  String get statusColorHex {
    switch (status) {
      case ListingStatus.pending:
        return '#FFA500';
      case ListingStatus.approved:
      case ListingStatus.active:
        return '#4CAF50';
      case ListingStatus.inactive:
        return '#9E9E9E';
      case ListingStatus.rejected:
        return '#F44336';
      case ListingStatus.deleted:
        return '#000000';
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// COPY WITH
  /// ═══════════════════════════════════════════════════════════════════════

  ServiceListing copyWith({
    int? id,
    String? listingId,
    String? providerId,
    String? providerType,
    int? categoryId,
    String? categoryName,
    String? subcategoryName,
    String? title,
    String? description,
    PricingType? pricingType,
    double? hourlyRate,
    double? minimumCharge,
    double? fixedPrice,
    String? city,
    List<String>? neighborhoods,
    double? serviceRadiusKm,
    List<String>? photos,
    String? availableDays,
    String? availableHours,
    bool? emergencyService,
    int? yearsExperience,
    String? certifications,
    String? portfolioLinks,
    ListingStatus? status,
    String? rejectionReason,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    int? viewCount,
    int? contactCount,
    int? bookingCount,
    double? averageRating,
    int? totalReviews,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    dynamic category,
    ServiceProvider? provider,
  }) {
    return ServiceListing(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      providerId: providerId ?? this.providerId,
      providerType: providerType ?? this.providerType,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      title: title ?? this.title,
      description: description ?? this.description,
      pricingType: pricingType ?? this.pricingType,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      minimumCharge: minimumCharge ?? this.minimumCharge,
      fixedPrice: fixedPrice ?? this.fixedPrice,
      city: city ?? this.city,
      neighborhoods: neighborhoods ?? this.neighborhoods,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      photos: photos ?? this.photos,
      availableDays: availableDays ?? this.availableDays,
      availableHours: availableHours ?? this.availableHours,
      emergencyService: emergencyService ?? this.emergencyService,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      certifications: certifications ?? this.certifications,
      portfolioLinks: portfolioLinks ?? this.portfolioLinks,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      viewCount: viewCount ?? this.viewCount,
      contactCount: contactCount ?? this.contactCount,
      bookingCount: bookingCount ?? this.bookingCount,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      category: category ?? this.category,
      provider: provider ?? this.provider,
    );
  }

  @override
  String toString() {
    return 'ServiceListing(id: $id, title: $title, status: $status, price: $priceDisplay)';
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// LISTING LIST RESPONSE MODEL
/// ═══════════════════════════════════════════════════════════════════════

class ListingListResponse {
  final bool success;
  final String message;
  final List<ServiceListing> listings;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  ListingListResponse({
    required this.success,
    required this.message,
    required this.listings,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory ListingListResponse.fromJson(Map<String, dynamic> json) {
    return ListingListResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      listings: (json['data']['listings'] as List)
          .map((item) => ServiceListing.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['data']['pagination']['total'] as int,
      page: json['data']['pagination']['page'] as int,
      limit: json['data']['pagination']['limit'] as int,
      totalPages: json['data']['pagination']['total_pages'] as int,
    );
  }

  bool get hasMore => page < totalPages;
}

/// ═══════════════════════════════════════════════════════════════════════
/// SINGLE LISTING RESPONSE MODEL
/// ═══════════════════════════════════════════════════════════════════════

class SingleListingResponse {
  final bool success;
  final String message;
  final ServiceListing listing;

  SingleListingResponse({
    required this.success,
    required this.message,
    required this.listing,
  });

  factory SingleListingResponse.fromJson(Map<String, dynamic> json) {
    return SingleListingResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      listing: ServiceListing.fromJson(json['data']['listing'] as Map<String, dynamic>),
    );
  }
}
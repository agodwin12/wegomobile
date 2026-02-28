// lib/models/services/category_model.dart
// Service Category Model - Production Ready with Full Null Safety

/// ═══════════════════════════════════════════════════════════════════════
/// SERVICE CATEGORY MODEL
/// Represents a service category (parent or subcategory)
/// Handles all null cases from backend gracefully
/// ═══════════════════════════════════════════════════════════════════════

class ServiceCategory {
  final int id;
  final String nameEn;
  final String nameFr;
  final String? descriptionEn;
  final String? descriptionFr;
  final String? iconUrl;
  final int? parentId;
  final int displayOrder;
  final bool isActive;
  final int activeListingsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Nested subcategories (only for parent categories)
  final List<ServiceCategory>? subcategories;

  ServiceCategory({
    required this.id,
    required this.nameEn,
    required this.nameFr,
    this.descriptionEn,
    this.descriptionFr,
    this.iconUrl,
    this.parentId,
    required this.displayOrder,
    required this.isActive,
    required this.activeListingsCount,
    this.createdAt,
    this.updatedAt,
    this.subcategories,
  });

  /// ═══════════════════════════════════════════════════════════════════════
  /// HELPER: SAFE INT PARSING
  /// Handles both int and string values from backend
  /// ═══════════════════════════════════════════════════════════════════════

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// JSON SERIALIZATION - FIXED VERSION
  /// ═══════════════════════════════════════════════════════════════════════

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    try {
      return ServiceCategory(
        id: _parseInt(json['id']),
        nameEn: json['name_en']?.toString() ?? '',
        nameFr: json['name_fr']?.toString() ?? json['name_en']?.toString() ?? '', // Fallback to English if French missing
        descriptionEn: json['description_en']?.toString(),
        descriptionFr: json['description_fr']?.toString(),
        iconUrl: json['icon_url'] as String?, // ✅ Nullable
        parentId: _parseNullableInt(json['parent_id']),
        displayOrder: _parseInt(json['display_order'], defaultValue: 0),
        isActive: json['is_active'] == true ||
            json['is_active'] == 1 ||
            json['is_active'] == '1',
        activeListingsCount: _parseInt(json['active_listings_count'], defaultValue: 0),
        // ✅ Handle both snake_case and camelCase from backend
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString())
            : json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
        subcategories: json['subcategories'] != null
            ? (json['subcategories'] as List)
            .map((item) => ServiceCategory.fromJson(item as Map<String, dynamic>))
            .toList()
            : null,
      );
    } catch (e) {
      print('❌ [CATEGORY_MODEL] Error parsing category: $e');
      print('❌ [CATEGORY_MODEL] JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_fr': nameFr,
      'description_en': descriptionEn,
      'description_fr': descriptionFr,
      'icon_url': iconUrl,
      'parent_id': parentId,
      'display_order': displayOrder,
      'is_active': isActive,
      'active_listings_count': activeListingsCount,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'subcategories': subcategories?.map((cat) => cat.toJson()).toList(),
    };
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// HELPER METHODS
  /// ═══════════════════════════════════════════════════════════════════════

  /// Get localized name (French primary for Cameroon)
  String getLocalizedName({bool useFrench = true}) {
    return useFrench ? nameFr : nameEn;
  }

  /// Get localized description
  String? getLocalizedDescription({bool useFrench = true}) {
    return useFrench ? descriptionFr : descriptionEn;
  }

  /// Check if this is a parent category
  bool get isParent => parentId == null;

  /// Check if this is a subcategory
  bool get isSubcategory => parentId != null;

  /// Check if has subcategories
  bool get hasSubcategories =>
      subcategories != null && subcategories!.isNotEmpty;

  /// Get count of subcategories
  int get subcategoryCount => subcategories?.length ?? 0;

  /// Get active subcategories only
  List<ServiceCategory> get activeSubcategories {
    if (subcategories == null) return [];
    return subcategories!.where((cat) => cat.isActive).toList();
  }

  /// Get formatted date
  String get formattedCreatedAt {
    if (createdAt == null) return 'N/A';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }

  /// Get formatted updated date
  String get formattedUpdatedAt {
    if (updatedAt == null) return 'N/A';
    return '${updatedAt!.day}/${updatedAt!.month}/${updatedAt!.year}';
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// COPY WITH (for state updates)
  /// ═══════════════════════════════════════════════════════════════════════

  ServiceCategory copyWith({
    int? id,
    String? nameEn,
    String? nameFr,
    String? descriptionEn,
    String? descriptionFr,
    String? iconUrl,
    int? parentId,
    int? displayOrder,
    bool? isActive,
    int? activeListingsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ServiceCategory>? subcategories,
  }) {
    return ServiceCategory(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameFr: nameFr ?? this.nameFr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionFr: descriptionFr ?? this.descriptionFr,
      iconUrl: iconUrl ?? this.iconUrl,
      parentId: parentId ?? this.parentId,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      activeListingsCount: activeListingsCount ?? this.activeListingsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subcategories: subcategories ?? this.subcategories,
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// EQUALITY & HASH CODE
  /// ═══════════════════════════════════════════════════════════════════════

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServiceCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ServiceCategory(id: $id, nameEn: $nameEn, nameFr: $nameFr, '
        'isParent: $isParent, subcategories: $subcategoryCount)';
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// CATEGORY LIST RESPONSE MODEL
/// For paginated API responses
/// ═══════════════════════════════════════════════════════════════════════

class CategoryListResponse {
  final bool success;
  final String message;
  final List<ServiceCategory> categories;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  CategoryListResponse({
    required this.success,
    required this.message,
    required this.categories,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory CategoryListResponse.fromJson(Map<String, dynamic> json) {
    try {
      final categoriesData = json['data']?['categories'] as List<dynamic>? ?? [];
      final paginationData = json['data']?['pagination'] as Map<String, dynamic>? ??
          json['pagination'] as Map<String, dynamic>? ?? {};

      return CategoryListResponse(
        success: json['success'] as bool? ?? true,
        message: json['message']?.toString() ?? '',
        categories: categoriesData
            .map((item) => ServiceCategory.fromJson(item as Map<String, dynamic>))
            .toList(),
        total: ServiceCategory._parseInt(paginationData['total']),
        page: ServiceCategory._parseInt(paginationData['page'], defaultValue: 1),
        limit: ServiceCategory._parseInt(paginationData['limit'], defaultValue: 20),
        totalPages: ServiceCategory._parseInt(paginationData['totalPages'] ?? paginationData['total_pages']),
        hasNext: paginationData['hasNext'] == true || paginationData['has_next'] == true,
        hasPrev: paginationData['hasPrev'] == true || paginationData['has_prev'] == true,
      );
    } catch (e) {
      print('❌ [CATEGORY_LIST_RESPONSE] Error parsing: $e');
      print('❌ [CATEGORY_LIST_RESPONSE] JSON: $json');
      rethrow;
    }
  }

  bool get hasMore => hasNext;

  bool get isEmpty => categories.isEmpty;

  int get count => categories.length;
}

/// ═══════════════════════════════════════════════════════════════════════
/// SINGLE CATEGORY RESPONSE MODEL
/// For single category API responses
/// ═══════════════════════════════════════════════════════════════════════

class SingleCategoryResponse {
  final bool success;
  final String message;
  final ServiceCategory category;

  SingleCategoryResponse({
    required this.success,
    required this.message,
    required this.category,
  });

  factory SingleCategoryResponse.fromJson(Map<String, dynamic> json) {
    try {
      return SingleCategoryResponse(
        success: json['success'] as bool? ?? true,
        message: json['message']?.toString() ?? '',
        category: ServiceCategory.fromJson(
          json['data']['category'] as Map<String, dynamic>,
        ),
      );
    } catch (e) {
      print('❌ [SINGLE_CATEGORY_RESPONSE] Error parsing: $e');
      print('❌ [SINGLE_CATEGORY_RESPONSE] JSON: $json');
      rethrow;
    }
  }
}
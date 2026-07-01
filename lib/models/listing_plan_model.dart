// lib/models/services/listing_plan_model.dart
// Maps to GET /api/services/plans response → data.plans[]

class ListingPlan {
  final int     id;
  final String  planKey;
  final String  labelEn;
  final String  labelFr;
  final String? descriptionEn;
  final String? descriptionFr;
  final int     priceXaf;
  final int     durationDays;
  final int     maxPhotos;
  final bool    isHeroPlacement;
  final bool    requiresAdminApproval;
  final int     boostPriority;
  final bool    isHighlighted;
  final String? highlightLabelEn;
  final String? highlightLabelFr;
  final int     displayOrder;

  const ListingPlan({
    required this.id,
    required this.planKey,
    required this.labelEn,
    required this.labelFr,
    this.descriptionEn,
    this.descriptionFr,
    required this.priceXaf,
    required this.durationDays,
    required this.maxPhotos,
    required this.isHeroPlacement,
    required this.requiresAdminApproval,
    required this.boostPriority,
    required this.isHighlighted,
    this.highlightLabelEn,
    this.highlightLabelFr,
    required this.displayOrder,
  });

  bool get isFree => priceXaf == 0;

  factory ListingPlan.fromJson(Map<String, dynamic> json) {
    return ListingPlan(
      id:                    json['id'] as int,
      planKey:               json['plan_key'] as String,
      labelEn:               json['label_en'] as String,
      labelFr:               json['label_fr'] as String,
      descriptionEn:         json['description_en'] as String?,
      descriptionFr:         json['description_fr'] as String?,
      priceXaf:              (json['price_xaf'] as num).toInt(),
      durationDays:          (json['duration_days'] as num).toInt(),
      maxPhotos:             (json['max_photos'] as num?)?.toInt() ?? 3,
      isHeroPlacement:       json['is_hero_placement'] == true,
      requiresAdminApproval: json['requires_admin_approval'] == true,
      boostPriority:         (json['boost_priority'] as num?)?.toInt() ?? 0,
      isHighlighted:         json['is_highlighted'] == true,
      highlightLabelEn:      json['highlight_label_en'] as String?,
      highlightLabelFr:      json['highlight_label_fr'] as String?,
      displayOrder:          (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}
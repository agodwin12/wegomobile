// lib/screens/delivery agent/active_delivery.dart
//
// Shared model — the delivery data an agent works from (offer-accept response /
// resume payload). Extracted from the old regular active screen so the express
// active screen + agent dashboard can use it after the express/regular screens
// were unified into one live-map delivery.

import '../../l10n/tr.dart';

class ActiveDelivery {
  final int id;
  final String deliveryCode;
  final String deliveryType; // 'regular' | 'express' (legacy) — behaviour is unified
  final String trackingMode; // always 'live_map' now
  final String status;

  // Pickup
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String? pickupLandmark;

  // Dropoff
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String? dropoffLandmark;

  // Package
  final String packageSize;
  final String packageCategory;
  final String categoryLabel;
  final String categoryEmoji;
  final String? packagePhotoUrl;
  final String? packageDescription;
  final bool isFragile;

  // Financials
  final double totalPrice;
  final double driverPayout;
  final double commissionAmount;
  final String paymentMethod;

  // Recipient
  final String recipientName;
  final String recipientPhone;
  final String? recipientNote;

  const ActiveDelivery({
    required this.id,
    required this.deliveryCode,
    required this.deliveryType,
    required this.trackingMode,
    required this.status,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    this.pickupLandmark,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    this.dropoffLandmark,
    required this.packageSize,
    required this.packageCategory,
    required this.categoryLabel,
    required this.categoryEmoji,
    this.packagePhotoUrl,
    this.packageDescription,
    required this.isFragile,
    required this.totalPrice,
    required this.driverPayout,
    required this.commissionAmount,
    required this.paymentMethod,
    required this.recipientName,
    required this.recipientPhone,
    this.recipientNote,
  });

  factory ActiveDelivery.fromJson(Map<String, dynamic> j) => ActiveDelivery(
    id: j['id'] as int,
    deliveryCode: j['deliveryCode'] as String? ?? j['delivery_code'] as String? ?? '',
    deliveryType: j['deliveryType'] as String? ?? j['delivery_type'] as String? ?? 'regular',
    trackingMode: j['trackingMode'] as String? ?? j['tracking_mode'] as String? ?? 'live_map',
    status: j['status'] as String? ?? 'accepted',
    pickupAddress: (j['pickup'] as Map?)?['address'] as String? ?? j['pickup_address'] as String? ?? '',
    pickupLat: ((j['pickup'] as Map?)?['lat'] ?? j['pickup_latitude'] as num? ?? 0).toDouble(),
    pickupLng: ((j['pickup'] as Map?)?['lng'] ?? j['pickup_longitude'] as num? ?? 0).toDouble(),
    pickupLandmark: (j['pickup'] as Map?)?['landmark'] as String?,
    dropoffAddress: (j['dropoff'] as Map?)?['address'] as String? ?? j['dropoff_address'] as String? ?? '',
    dropoffLat: ((j['dropoff'] as Map?)?['lat'] ?? j['dropoff_latitude'] as num? ?? 0).toDouble(),
    dropoffLng: ((j['dropoff'] as Map?)?['lng'] ?? j['dropoff_longitude'] as num? ?? 0).toDouble(),
    dropoffLandmark: (j['dropoff'] as Map?)?['landmark'] as String?,
    packageSize: j['packageSize'] as String? ?? j['package_size'] as String? ?? 'medium',
    packageCategory: j['packageCategory'] as String? ?? j['package_category'] as String? ?? 'other',
    categoryLabel: j['categoryLabel'] as String? ?? tr('delivery.active.packageDefault'),
    categoryEmoji: j['categoryEmoji'] as String? ?? '📦',
    packagePhotoUrl: j['packagePhotoUrl'] as String? ?? j['package_photo_url'] as String?,
    packageDescription: j['packageDescription'] as String? ?? j['package_description'] as String?,
    isFragile: j['isFragile'] as bool? ?? j['is_fragile'] as bool? ?? false,
    totalPrice: (j['totalPrice'] ?? j['total_price'] as num? ?? 0).toDouble(),
    driverPayout: (j['driverPayout'] ?? j['driver_payout'] as num? ?? 0).toDouble(),
    commissionAmount: (j['commissionAmount'] ?? j['commission_amount'] as num? ?? 0).toDouble(),
    paymentMethod: j['paymentMethod'] as String? ?? j['payment_method'] as String? ?? 'cash',
    recipientName: j['recipientName'] as String? ?? j['recipient_name'] as String? ?? '',
    recipientPhone: j['recipientPhone'] as String? ?? j['recipient_phone'] as String? ?? '',
    recipientNote: j['recipientNote'] as String? ?? j['recipient_note'] as String?,
  );
}

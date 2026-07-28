// lib/screens/passenger/delivery/active_delivery_resume.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// ACTIVE DELIVERY RESUME — customer (sender) recovery, mirror of the ride's
// active_trip_resume.dart.
// ═══════════════════════════════════════════════════════════════════════════
// A delivery lives on the server, not in the app. If the sender force-quits,
// the phone dies, or the app is killed in the background, the delivery carries
// on and they must be able to get back to its live tracking view.
//
// GET /deliveries/my?status=<active csv>&limit=1 returns the sender's delivery
// still in flight. This file owns the single mapping from delivery status → the
// tracking screen, and normalises the backend's snake_case row into the
// camelCase shape the tracking screens expect (the same shape the booking flow
// hands them), so resume and the normal flow can never disagree.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config.dart';
import 'delivery regular/regular_delivery.dart';
import 'delivery express/express_delivery.dart';

/// Statuses that mean "an agent is assigned and this delivery is in flight".
/// `searching` is deliberately excluded: the offer window is only ~25s, so a
/// backgrounded search has already matched (push) or expired by the time the
/// app is reopened, and re-entering the search screen could re-trigger dispatch.
const List<String> kActiveDeliveryStatuses = [
  'accepted',
  'en_route_pickup',
  'arrived_pickup',
  'picked_up',
  'en_route_dropoff',
  'arrived_dropoff',
];

double? _numOf(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}');
}

/// A running delivery for the sender, already validated and normalised to the
/// camelCase shape the tracking screens read from `widget.delivery`.
class ActiveDelivery {
  final String id;
  final String status;
  final String deliveryType;   // 'express' | 'regular'
  final String deliveryCode;
  final Map<String, dynamic> tracking; // payload handed straight to the screen

  const ActiveDelivery({
    required this.id,
    required this.status,
    required this.deliveryType,
    required this.deliveryCode,
    required this.tracking,
  });

  /// Returns null when the payload cannot be turned into a usable screen — no
  /// delivery, no id, or a status that is not resumable. Callers treat null as
  /// "nothing to resume" rather than showing a broken banner.
  static ActiveDelivery? fromPayload(Map<String, dynamic>? raw) {
    if (raw == null) return null;

    final id = (raw['id'] ?? '').toString();
    if (id.isEmpty) return null;

    final status = (raw['status'] ?? '').toString();
    if (!kActiveDeliveryStatuses.contains(status)) return null;

    final deliveryType =
        (raw['deliveryType'] ?? raw['delivery_type'] ?? 'regular').toString();
    final trackingMode =
        (raw['trackingMode'] ?? (deliveryType == 'express' ? 'live_map' : 'stage_updates'))
            .toString();

    final driver = raw['driver'] is Map
        ? Map<String, dynamic>.from(raw['driver'] as Map)
        : null;

    // The tracking screens read camelCase keys; the backend row is snake_case.
    final tracking = <String, dynamic>{
      'id':             raw['id'],
      'status':         status,
      'deliveryCode':   raw['delivery_code'] ?? raw['deliveryCode'] ?? '',
      'deliveryType':   deliveryType,
      'trackingMode':   trackingMode,
      'pickupLat':      _numOf(raw['pickup_latitude']  ?? raw['pickupLat']),
      'pickupLng':      _numOf(raw['pickup_longitude'] ?? raw['pickupLng']),
      'dropoffLat':     _numOf(raw['dropoff_latitude']  ?? raw['dropoffLat']),
      'dropoffLng':     _numOf(raw['dropoff_longitude'] ?? raw['dropoffLng']),
      'pickupAddress':  raw['pickup_address']  ?? raw['pickupAddress']  ?? '',
      'dropoffAddress': raw['dropoff_address'] ?? raw['dropoffAddress'] ?? '',
      'totalPrice':     raw['total_price'] ?? raw['totalPrice'] ?? '',
      'recipientName':  raw['recipient_name']  ?? raw['recipientName']  ?? '',
      'recipientPhone': raw['recipient_phone'] ?? raw['recipientPhone'] ?? '',
      'driver':         driver,
    };

    return ActiveDelivery(
      id:           id,
      status:       status,
      deliveryType: deliveryType,
      deliveryCode: (tracking['deliveryCode'] ?? '').toString(),
      tracking:     tracking,
    );
  }

  /// Translation key describing the current stage — reuses the regular-tracking
  /// stage titles already defined in tr.dart.
  String get statusTitleKey => switch (status) {
        'en_route_pickup'  => 'delivery.regularTrack.enRoutePickupTitle',
        'arrived_pickup'   => 'delivery.regularTrack.arrivedPickupTitle',
        'picked_up'        => 'delivery.regularTrack.pickedUpTitle',
        'en_route_dropoff' => 'delivery.regularTrack.enRouteDropoffTitle',
        'arrived_dropoff'  => 'delivery.regularTrack.arrivedDropoffTitle',
        _                  => 'delivery.regularTrack.acceptedTitle',
      };
}

/// Asks the server whether this sender has a delivery in flight.
/// Never throws — a failure here must not break the dashboard.
Future<ActiveDelivery?> fetchActiveDelivery(String? accessToken) async {
  if (accessToken == null || accessToken.isEmpty) return null;
  try {
    final statusQuery = kActiveDeliveryStatuses.join(',');
    final res = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/deliveries/my'
          '?status=$statusQuery&page=1&limit=1'),
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['deliveries'] as List?;
    if (list == null || list.isEmpty) return null;
    return ActiveDelivery.fromPayload(
        Map<String, dynamic>.from(list.first as Map));
  } catch (e) {
    debugPrint('ℹ️ [ACTIVE-DELIVERY] None to resume (or lookup failed): $e');
    return null;
  }
}

/// Pushes the sender back into their running delivery's tracking screen.
Future<void> openActiveDelivery(
    BuildContext context, ActiveDelivery d, String accessToken) async {
  final screen = d.deliveryType == 'express'
      ? DeliveryTrackingExpress(delivery: d.tracking, accessToken: accessToken)
      : DeliveryTrackingRegular(delivery: d.tracking, accessToken: accessToken);
  await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

// lib/screens/passenger/trip/active_trip_resume.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// ACTIVE TRIP RESUME — shared recovery logic for the passenger side
// ═══════════════════════════════════════════════════════════════════════════
// A trip lives on the server, not in the app. If the passenger force-quits,
// the phone dies, or the app is killed in the background, the ride carries on
// and they must be able to get back to it.
//
// GET /trips/active returns whatever ride is still running for the caller.
// This file owns the single mapping from trip status → the screen that should
// be shown, so the ride map and the dashboard banner can never disagree about
// where a given status leads.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../service/api_services.dart';
import 'driver_arriving_screen.dart';
import 'searching_driver_screen.dart';
import 'tripProgressScreen.dart';

/// Statuses that mean "this ride is still going".
const List<String> kActiveTripStatuses = [
  'SEARCHING',
  'MATCHED',
  'DRIVER_ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
  'IN_PROGRESS',
];

LatLng? _latLngFrom(dynamic lat, dynamic lng) {
  final dLat = lat is num ? lat.toDouble() : double.tryParse('${lat ?? ''}');
  final dLng = lng is num ? lng.toDouble() : double.tryParse('${lng ?? ''}');
  if (dLat == null || dLng == null) return null;
  return LatLng(dLat, dLng);
}

/// A running trip, already validated: anything returned here has the
/// coordinates needed to rebuild its screen.
class ActiveTrip {
  final String tripId;
  final String status;
  final LatLng pickup;
  final LatLng dropoff;
  final String pickupAddress;
  final String dropoffAddress;
  final Map<String, dynamic> driver;

  const ActiveTrip({
    required this.tripId,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.driver,
  });

  /// Returns null when the payload cannot be turned into a usable screen —
  /// no trip, no id, or missing coordinates. Callers treat null as "nothing
  /// to resume" rather than showing a broken banner.
  static ActiveTrip? fromPayload(Map<String, dynamic>? trip) {
    if (trip == null) return null;

    final tripId = (trip['id'] ?? '').toString();
    if (tripId.isEmpty) return null;

    final status = (trip['status'] ?? '').toString();
    if (!kActiveTripStatuses.contains(status)) return null;

    final pickup = _latLngFrom(trip['pickupLat'], trip['pickupLng']);
    final dropoff = _latLngFrom(trip['dropoffLat'], trip['dropoffLng']);
    if (pickup == null || dropoff == null) return null;

    return ActiveTrip(
      tripId: tripId,
      status: status,
      pickup: pickup,
      dropoff: dropoff,
      pickupAddress: (trip['pickupAddress'] ?? '').toString(),
      dropoffAddress: (trip['dropoffAddress'] ?? '').toString(),
      driver: trip['driver'] is Map
          ? Map<String, dynamic>.from(trip['driver'] as Map)
          : <String, dynamic>{},
    );
  }

  /// The driver's display name, or an empty string before one is assigned.
  String get driverName {
    final first = (driver['firstName'] ?? driver['first_name'] ?? '').toString();
    final last = (driver['lastName'] ?? driver['last_name'] ?? '').toString();
    return '$first $last'.trim();
  }

  /// Translation key describing the current stage to the passenger.
  String get statusKey => switch (status) {
        'SEARCHING' => 'trip.resumeSearching',
        'IN_PROGRESS' => 'trip.resumeInProgress',
        'DRIVER_ARRIVED' => 'trip.resumeArrived',
        _ => 'trip.resumeOnTheWay',
      };
}

/// Asks the server whether this passenger has a ride in flight.
/// Never throws — a failure here must not break the screen that called it.
Future<ActiveTrip?> fetchActiveTrip(String? accessToken) async {
  if (accessToken == null || accessToken.isEmpty) return null;
  try {
    final resp = await ApiService.getActiveTrip(accessToken: accessToken);
    final trip = resp['data']?['trip'];
    return ActiveTrip.fromPayload(
      trip is Map ? Map<String, dynamic>.from(trip) : null,
    );
  } catch (e) {
    debugPrint('ℹ️ [ACTIVE-TRIP] None to resume (or lookup failed): $e');
    return null;
  }
}

/// Builds the screen a given trip should reopen into.
Widget? screenForActiveTrip(ActiveTrip trip) {
  switch (trip.status) {
    case 'SEARCHING':
      return SearchingDriverScreen(
        tripId: trip.tripId,
        pickupAddress: trip.pickupAddress,
        dropoffAddress: trip.dropoffAddress,
        pickupLocation: trip.pickup,
        dropoffLocation: trip.dropoff,
      );

    case 'MATCHED':
    case 'DRIVER_ASSIGNED':
    case 'DRIVER_EN_ROUTE':
    case 'DRIVER_ARRIVED':
      return DriverArrivingScreen(
        tripId: trip.tripId,
        driver: trip.driver,
        pickupLocation: trip.pickup,
        dropoffLocation: trip.dropoff,
        pickupAddress: trip.pickupAddress,
        dropoffAddress: trip.dropoffAddress,
      );

    case 'IN_PROGRESS':
      return TripInProgressScreen(
        tripId: trip.tripId,
        driver: trip.driver,
        pickupLocation: trip.pickup,
        dropoffLocation: trip.dropoff,
        pickupAddress: trip.pickupAddress,
        dropoffAddress: trip.dropoffAddress,
      );

    default:
      return null;
  }
}

/// Pushes the passenger back into their running trip.
Future<void> openActiveTrip(BuildContext context, ActiveTrip trip) async {
  final screen = screenForActiveTrip(trip);
  if (screen == null) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

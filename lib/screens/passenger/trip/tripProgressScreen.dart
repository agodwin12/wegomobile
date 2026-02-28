// lib/presentation/screens/trip/trip_in_progress_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/config.dart';
import '../../../providers/trip_provider.dart';
import '../../../utils/app_colors.dart';
import '../../chat/trip_chat_screen.dart';
import 'trip_completed_screen.dart';

class TripInProgressScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> driver;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;

  const TripInProgressScreen({
    super.key,
    required this.tripId,
    required this.driver,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
  });

  @override
  State<TripInProgressScreen> createState() => _TripInProgressScreenState();
}

class _TripInProgressScreenState extends State<TripInProgressScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // ── Animations ────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _carAnimationController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // ── State ─────────────────────────────────────────────────────────────
  LatLng? _currentDriverLocation;
  LatLng? _animatedDriverLocation;
  bool _hasNavigated = false;
  BitmapDescriptor? _carIcon;

  String _eta = '— min';
  double _distance = 0.0;
  double _tripProgress = 0.0;
  List<LatLng> _routePoints = [];

  TripProvider? _tripProvider;
  VoidCallback? _tripListener;

  @override
  void initState() {
    super.initState();
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚗 [TRIP_IN_PROGRESS] Initializing — ${widget.tripId}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    _setupAnimations();
    _initializeDriverLocation();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Build custom car icon
      _carIcon = await _buildCarIcon();
      // 2. Fetch real route from Google
      await _fetchRoute();
      // 3. Static markers (destination pin only)
      _setupMarkers();
      // 4. Attach trip provider listener
      if (!mounted) return;
      _tripProvider = Provider.of<TripProvider>(context, listen: false);
      _tripListener = () => _checkTripStatus(_tripProvider!);
      _tripProvider!.addListener(_tripListener!);
      _checkTripStatus(_tripProvider!);
    });
  }

  @override
  void dispose() {
    if (_tripProvider != null && _tripListener != null) {
      _tripProvider!.removeListener(_tripListener!);
    }
    _pulseController.dispose();
    _carAnimationController.dispose();
    _slideController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════
  // CAR ICON — drawn on Canvas, looks like a top-down car
  // ══════════════════════════════════════════════════════════════════════

  Future<BitmapDescriptor> _buildCarIcon() async {
    const size = 80.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder,
        Rect.fromLTWH(0, 0, size, size));

    final bodyPaint = Paint()..color = Colors.black;
    final windowPaint = Paint()..color = const Color(0xFFB0C4DE);
    final wheelPaint = Paint()..color = const Color(0xFF333333);
    final lightPaint = Paint()..color = AppColors.primaryGold;

    // Car body
    final bodyRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 8, 44, 64),
      const Radius.circular(12),
    );
    canvas.drawRRect(bodyRRect, bodyPaint);

    // Windshield (front)
    final windshieldPath = Path()
      ..moveTo(24, 20)
      ..lineTo(56, 20)
      ..lineTo(52, 32)
      ..lineTo(28, 32)
      ..close();
    canvas.drawPath(windshieldPath, windowPaint);

    // Rear window
    final rearPath = Path()
      ..moveTo(28, 50)
      ..lineTo(52, 50)
      ..lineTo(56, 60)
      ..lineTo(24, 60)
      ..close();
    canvas.drawPath(rearPath, windowPaint);

    // Side windows
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(18, 34, 8, 14), const Radius.circular(2)),
        windowPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(54, 34, 8, 14), const Radius.circular(2)),
        windowPaint);

    // Wheels — 4 corners
    for (final pos in [
      const Rect.fromLTWH(8, 12, 12, 18),
      const Rect.fromLTWH(60, 12, 12, 18),
      const Rect.fromLTWH(8, 50, 12, 18),
      const Rect.fromLTWH(60, 50, 12, 18),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(pos, const Radius.circular(4)), wheelPaint);
    }

    // Front headlights (gold)
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(22, 8, 12, 5), const Radius.circular(2)),
        lightPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(46, 8, 12, 5), const Radius.circular(2)),
        lightPaint);

    // Rear lights (red)
    final redPaint = Paint()..color = Colors.red.shade400;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(22, 67, 12, 5), const Radius.circular(2)),
        redPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(46, 67, 12, 5), const Radius.circular(2)),
        redPaint);

    final picture = recorder.endRecording();
    final img =
    await picture.toImage(size.toInt(), size.toInt());
    final bytes =
    await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  // ══════════════════════════════════════════════════════════════════════
  // REAL ROUTE from Google Directions API
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _fetchRoute() async {
    try {
      final origin =
          '${widget.pickupLocation.latitude},${widget.pickupLocation.longitude}';
      final dest =
          '${widget.dropoffLocation.latitude},${widget.dropoffLocation.longitude}';
      final apiKey = AppConfig.googleMapsApiKey;

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=$origin&destination=$dest&key=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final encodedPolyline =
          data['routes'][0]['overview_polyline']['points'] as String;
          final points = _decodePolyline(encodedPolyline);

          // Also pull real duration/distance from response
          final leg = data['routes'][0]['legs'][0];
          final durationText = leg['duration']['text'] as String;
          final distanceM = (leg['distance']['value'] as int).toDouble();

          if (mounted) {
            setState(() {
              _routePoints = points;
              _distance = distanceM / 1000;
              _eta = durationText;
            });
          }

          _updatePolyline(points);
          debugPrint('✅ [ROUTE] Fetched ${points.length} points');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ROUTE] Failed to fetch — falling back to straight line: $e');
      // Straight-line fallback
      if (mounted) {
        setState(() {
          _routePoints = [widget.pickupLocation, widget.dropoffLocation];
        });
      }
      _updatePolyline([widget.pickupLocation, widget.dropoffLocation]);
    }
  }

  void _updatePolyline(List<LatLng> points) {
    if (!mounted) return;
    setState(() {
      _polylines
        ..removeWhere((p) => p.polylineId.value == 'route')
        ..add(Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.amber,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ));
    });
  }

  /// Decode Google encoded polyline string into LatLng list
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ══════════════════════════════════════════════════════════════════════
  // SETUP
  // ══════════════════════════════════════════════════════════════════════

  void _setupAnimations() {
    _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _pulseController.repeat(reverse: true);

    _carAnimationController = AnimationController(
        duration: const Duration(seconds: 2), vsync: this);

    _slideController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _slideController.forward();
  }

  void _initializeDriverLocation() {
    _currentDriverLocation = widget.pickupLocation;
    _animatedDriverLocation = _currentDriverLocation;
  }

  void _setupMarkers() {
    if (!mounted) return;
    setState(() {
      _markers.clear();

      // Destination pin — red
      _markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: widget.dropoffLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 1.0),
        infoWindow:
        InfoWindow(title: 'Destination', snippet: widget.dropoffAddress),
      ));

      // Driver car marker
      _updateDriverMarker();
    });
  }

  void _updateDriverMarker() {
    if (_animatedDriverLocation == null) return;
    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: _animatedDriverLocation!,
      icon: _carIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      anchor: const Offset(0.5, 0.5),
      rotation:
      _calculateBearing(_animatedDriverLocation!, widget.dropoffLocation),
      flat: true,
    ));
    if (mounted) setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════
  // TRIP STATUS LISTENER
  // ══════════════════════════════════════════════════════════════════════

  void _checkTripStatus(TripProvider tripProvider) {
    if (_hasNavigated || !mounted) return;

    if (tripProvider.driverLocation != null) {
      final newLat = tripProvider.driverLocation!['lat'];
      final newLng = tripProvider.driverLocation!['lng'];
      if (newLat != null && newLng != null) {
        final newLoc = LatLng(_toDouble(newLat), _toDouble(newLng));
        final changed = _currentDriverLocation == null ||
            _currentDriverLocation!.latitude != newLoc.latitude ||
            _currentDriverLocation!.longitude != newLoc.longitude;
        if (changed) {
          if (_currentDriverLocation != null) {
            _animateCarMovement(_currentDriverLocation!, newLoc);
          } else {
            setState(() {
              _currentDriverLocation = newLoc;
              _animatedDriverLocation = newLoc;
            });
            _updateDriverMarker();
            _calculateProgressFromRoute();
          }
        }
      }
    }

    switch (tripProvider.status) {
      case TripStatus.completed:
        _navigateToCompleted(tripProvider);
        break;
      case TripStatus.canceled:
        _showCanceledDialog(
            tripProvider.errorMessage ?? 'Trip was canceled');
        break;
      default:
        break;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // CAR ANIMATION
  // ══════════════════════════════════════════════════════════════════════

  void _animateCarMovement(LatLng from, LatLng to) {
    _carAnimationController.reset();
    final anim =
    Tween<double>(begin: 0.0, end: 1.0).animate(_carAnimationController);

    anim.addListener(() {
      if (!mounted) return;
      final lat = from.latitude + (to.latitude - from.latitude) * anim.value;
      final lng =
          from.longitude + (to.longitude - from.longitude) * anim.value;
      setState(() => _animatedDriverLocation = LatLng(lat, lng));
      _updateDriverMarker();
      _calculateProgressFromRoute();
    });

    anim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentDriverLocation = to;
      }
    });

    _carAnimationController.forward();
  }

  void _calculateProgressFromRoute() {
    if (_animatedDriverLocation == null) return;

    final totalDist = _routePoints.length >= 2
        ? _pathLength(_routePoints)
        : _calculateDistance(
      widget.pickupLocation.latitude,
      widget.pickupLocation.longitude,
      widget.dropoffLocation.latitude,
      widget.dropoffLocation.longitude,
    );

    final remaining = _calculateDistance(
      _animatedDriverLocation!.latitude,
      _animatedDriverLocation!.longitude,
      widget.dropoffLocation.latitude,
      widget.dropoffLocation.longitude,
    );

    final traveled = (totalDist - remaining).clamp(0.0, totalDist);
    final progress =
    totalDist > 0 ? (traveled / totalDist).clamp(0.0, 1.0) : 0.0;
    final etaMin = remaining > 0 ? (remaining / 30 * 60).ceil() : 0;

    if (mounted) {
      setState(() {
        _distance = remaining;
        _tripProgress = progress;
        _eta = etaMin < 1 ? '< 1 min' : '$etaMin min';
      });
    }
  }

  double _pathLength(List<LatLng> pts) {
    double total = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      total += _calculateDistance(pts[i].latitude, pts[i].longitude,
          pts[i + 1].latitude, pts[i + 1].longitude);
    }
    return total;
  }

  // ══════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ══════════════════════════════════════════════════════════════════════

  void _navigateToCompleted(TripProvider tripProvider) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TripCompletedScreen(
          tripId: widget.tripId,
          driver: widget.driver,
          tripDetails: tripProvider.currentTrip ?? {
            'pickup': widget.pickupAddress,
            'dropoff': widget.dropoffAddress,
            'fareEstimate': 3500,
            'distanceM': (_distance * 1000).toInt(),
          },
        ),
      ),
    );
  }

  void _showCanceledDialog(String message) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Trip Canceled',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: const TextStyle(fontSize: 15, color: Colors.black54)),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Okay',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _callDriver() async {
    final phone =
    _getField(widget.driver, ['phone', 'phone_e164', 'phoneNumber']);
    if (phone == null || phone.isEmpty) {
      _showSnack('Driver phone number not available', Colors.red);
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnack('Cannot open phone dialer', Colors.red);
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          tripId: widget.tripId,
          otherUserName: _getDriverName(),
          otherUserAvatar:
          _getField(widget.driver, ['avatar', 'avatar_url']),
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _fitMapToRoute() {
    if (_mapController == null) return;
    final allPoints = [
      widget.pickupLocation,
      widget.dropoffLocation,
      if (_animatedDriverLocation != null) _animatedDriverLocation!,
    ];
    double minLat = allPoints.map((p) => p.latitude).reduce(math.min);
    double maxLat = allPoints.map((p) => p.latitude).reduce(math.max);
    double minLng = allPoints.map((p) => p.longitude).reduce(math.min);
    double maxLng = allPoints.map((p) => p.longitude).reduce(math.max);

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      80,
    ));
  }

  // ══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════

  String _getDriverName() {
    final first =
        _getField(widget.driver, ['firstName', 'first_name']) ?? '';
    final last = _getField(widget.driver, ['lastName', 'last_name']) ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : (_getField(widget.driver, ['name']) ?? 'Driver');
  }

  String? _getField(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final k in keys) {
      final v = map[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }

  String? get _driverAvatarUrl {
    // Check nested vehicle map first, then top-level
    return _getField(widget.driver, ['avatar', 'avatar_url', 'photo', 'picture', 'profilePhoto']);
  }

  Map<String, String> get _vehicleInfo {
    final v = widget.driver['vehicle'] as Map<String, dynamic>?;
    return {
      'plate': _getField(v ?? widget.driver,
          ['plate', 'vehiclePlate', 'vehicle_plate']) ??
          'N/A',
      'makeModel': _getField(v ?? widget.driver, [
        'makeModel',
        'vehicle_make_model',
        'vehicleMakeModel',
        'make_model',
      ]) ??
          'Vehicle',
      'color': _getField(v ?? widget.driver,
          ['color', 'vehicleColor', 'vehicle_color']) ??
          'Unknown',
    };
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = _toRad(from.latitude);
    final lat2 = _toRad(to.latitude);
    final dLon = _toRad(to.longitude - from.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double d) => d * math.pi / 180.0;

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  // ══════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final driverName = _getDriverName();
    final vehicle = _vehicleInfo;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── MAP ──────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition:
            CameraPosition(target: widget.pickupLocation, zoom: 14),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onMapCreated: (c) {
              _mapController = c;
              Future.delayed(
                  const Duration(milliseconds: 500), _fitMapToRoute);
            },
          ),

          // ── TOP STATUS PILL ──────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.green.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        const Text('Trip in progress',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── BOTTOM SHEET ─────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          MediaQuery.of(context).padding.bottom + 16),
                      child: Column(
                        children: [
                          // Progress row
                          _ProgressRow(
                              progress: _tripProgress,
                              eta: _eta,
                              distance: _distance),
                          const SizedBox(height: 20),

                          // Driver card with real avatar
                          _DriverRow(
                            name: driverName,
                            avatarUrl: _driverAvatarUrl,
                            vehicle: vehicle,
                            onCall: _callDriver,
                            onChat: _openChat,
                          ),
                          const SizedBox(height: 14),

                          // Destination card
                          _DestinationCard(address: widget.dropoffAddress),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// PROGRESS ROW
// ════════════════════════════════════════════════════════════════════════

class _ProgressRow extends StatelessWidget {
  final double progress;
  final String eta;
  final double distance;

  const _ProgressRow(
      {required this.progress, required this.eta, required this.distance});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Trip progress',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500)),
            Text('${(progress * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: Colors.grey.shade100,
            valueColor:
            const AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _InfoPill(
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                value: eta,
                label: 'ETA',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoPill(
                icon: Icons.route_rounded,
                iconColor: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFF7ED),
                value: '${distance.toStringAsFixed(1)} km',
                label: 'Remaining',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String value;
  final String label;

  const _InfoPill({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration:
      BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
              Text(label,
                  style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// DRIVER ROW — with real avatar + fallback initial
// ════════════════════════════════════════════════════════════════════════

class _DriverRow extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final Map<String, String> vehicle;
  final VoidCallback onCall;
  final VoidCallback onChat;

  const _DriverRow({
    required this.name,
    required this.avatarUrl,
    required this.vehicle,
    required this.onCall,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // ── Avatar ───────────────────────────────────────────────
              _DriverAvatar(name: name, avatarUrl: avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                    Text(
                      '${vehicle['color']} ${vehicle['makeModel']}',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              _ActionBtn(
                icon: Icons.call_rounded,
                iconColor: const Color(0xFF16A34A),
                bgColor: const Color(0xFFDCFCE7),
                onTap: onCall,
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.chat_bubble_rounded,
                iconColor: AppColors.primaryGold,
                bgColor: AppColors.primaryGold.withOpacity(0.12),
                onTap: onChat,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Plate bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car_rounded,
                    size: 16, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text(
                  vehicle['plate'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                    color: Colors.black87,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar widget — photo with fallback to initial ──────────────────────

class _DriverAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _DriverAvatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    final fallback = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primaryGold,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black),
        ),
      ),
    );

    if (avatarUrl == null || avatarUrl!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: CachedNetworkImage(
        imageUrl: avatarUrl!,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// DESTINATION CARD
// ════════════════════════════════════════════════════════════════════════

class _DestinationCard extends StatelessWidget {
  final String address;

  const _DestinationCard({required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primaryGold.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.location_on_rounded,
                color: Colors.red, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destination',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}
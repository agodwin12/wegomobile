// lib/presentation/screens/trip/driver_arriving_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wego_v1/screens/passenger/trip/tripProgressScreen.dart';
import '../../../providers/trip_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';
import '../../chat/trip_chat_screen.dart';

class DriverArrivingScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> driver;
  final Map<String, dynamic>? driverLocation;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;

  const DriverArrivingScreen({
    super.key,
    required this.tripId,
    required this.driver,
    this.driverLocation,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
  });

  @override
  State<DriverArrivingScreen> createState() => _DriverArrivingScreenState();
}

class _DriverArrivingScreenState extends State<DriverArrivingScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _carAnimationController;
  late AnimationController _pulseController;
  late AnimationController _arrivedBannerController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _arrivedBannerAnimation;

  LatLng? _currentDriverLocation;
  LatLng? _animatedDriverLocation;
  bool _hasNavigated = false;
  bool _driverArrivedShown = false;
  bool _driverHasArrived = false;
  String _eta = '5 min';
  double _distance = 4.8;

  TripProvider? _tripProvider;
  VoidCallback? _tripListener;

  @override
  void initState() {
    super.initState();
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚗 [DRIVER_ARRIVING] Initializing...');
    debugPrint('   Trip: ${widget.tripId}');
    debugPrint('   Driver: ${_getDriverName()}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    _setupAnimations();
    _initializeDriverLocation();
    _setupMarkers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    _slideController.dispose();
    _carAnimationController.dispose();
    _pulseController.dispose();
    _arrivedBannerController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SETUP
  // ═══════════════════════════════════════════════════════════════════════

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _carAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Arrived banner slides down from top
    _arrivedBannerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _arrivedBannerAnimation = CurvedAnimation(
      parent: _arrivedBannerController,
      curve: Curves.easeOutBack,
    );

    _slideController.forward();
  }

  void _initializeDriverLocation() {
    if (widget.driverLocation != null) {
      final lat = widget.driverLocation!['lat'];
      final lng = widget.driverLocation!['lng'];
      if (lat != null && lng != null) {
        _currentDriverLocation = LatLng(_toDouble(lat), _toDouble(lng));
        _animatedDriverLocation = _currentDriverLocation;
      } else {
        _currentDriverLocation = widget.pickupLocation;
        _animatedDriverLocation = _currentDriverLocation;
      }
    } else {
      _currentDriverLocation = widget.pickupLocation;
      _animatedDriverLocation = _currentDriverLocation;
    }
    _calculateDistanceAndETA();
  }

  void _setupMarkers() {
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: widget.pickupLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      anchor: const Offset(0.5, 0.5),
      infoWindow: InfoWindow(title: 'Pickup', snippet: widget.pickupAddress),
    ));
    _updateDriverMarker();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TRIP STATUS LISTENER
  // ═══════════════════════════════════════════════════════════════════════

  void _checkTripStatus(TripProvider tripProvider) {
    if (_hasNavigated || !mounted) return;

    // Update driver location
    if (tripProvider.driverLocation != null) {
      final newLat = tripProvider.driverLocation!['lat'];
      final newLng = tripProvider.driverLocation!['lng'];
      if (newLat != null && newLng != null) {
        final newLocation = LatLng(_toDouble(newLat), _toDouble(newLng));
        final hasChanged = _currentDriverLocation == null ||
            _currentDriverLocation!.latitude != newLocation.latitude ||
            _currentDriverLocation!.longitude != newLocation.longitude;

        if (hasChanged) {
          if (_currentDriverLocation != null) {
            _animateCarMovement(_currentDriverLocation!, newLocation);
          } else {
            setState(() {
              _currentDriverLocation = newLocation;
              _animatedDriverLocation = newLocation;
            });
            _updateDriverMarker();
            _calculateDistanceAndETA();
          }
        }
      }
    }

    switch (tripProvider.status) {
      case TripStatus.arrivedPickup:
        if (!_driverArrivedShown) {
          _driverArrivedShown = true;
          debugPrint('📍 [DRIVER_ARRIVING] Driver arrived at pickup!');
          setState(() => _driverHasArrived = true);
          _arrivedBannerController.forward();
          // Stop the pulsing ETA since driver is here
          _pulseController.stop();
        }
        break;

      case TripStatus.inProgress:
        debugPrint('🚀 [DRIVER_ARRIVING] Trip started — navigating...');
        _navigateToTripInProgress();
        break;

      case TripStatus.canceled:
        debugPrint('⚠️ [DRIVER_ARRIVING] Trip canceled');
        _showCanceledDialog(tripProvider.errorMessage ?? 'Trip was canceled');
        break;

      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ANIMATION
  // ═══════════════════════════════════════════════════════════════════════

  void _animateCarMovement(LatLng from, LatLng to) {
    _carAnimationController.reset();
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(_carAnimationController);

    animation.addListener(() {
      if (!mounted) return;
      final lat = from.latitude + (to.latitude - from.latitude) * animation.value;
      final lng = from.longitude + (to.longitude - from.longitude) * animation.value;
      setState(() => _animatedDriverLocation = LatLng(lat, lng));
      _updateDriverMarker();
      _calculateDistanceAndETA();
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentDriverLocation = to;
      }
    });

    _carAnimationController.forward();
  }

  void _updateDriverMarker() {
    if (_animatedDriverLocation == null) return;
    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: _animatedDriverLocation!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      anchor: const Offset(0.5, 0.5),
      rotation: _calculateBearing(_animatedDriverLocation!, widget.pickupLocation),
      infoWindow: InfoWindow(title: _getDriverName(), snippet: 'Your driver'),
    ));

    _polylines.clear();
    _polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      points: [_animatedDriverLocation!, widget.pickupLocation],
      color: AppColors.primaryGold,
      width: 4,
      patterns: [PatternItem.dash(20), PatternItem.gap(10)],
    ));

    if (mounted) setState(() {});
  }

  void _calculateDistanceAndETA() {
    if (_animatedDriverLocation == null) return;
    final distance = _calculateDistance(
      _animatedDriverLocation!.latitude,
      _animatedDriverLocation!.longitude,
      widget.pickupLocation.latitude,
      widget.pickupLocation.longitude,
    );
    if (mounted) {
      setState(() {
        _distance = distance;
        final etaMinutes = (distance / 30 * 60).ceil();
        _eta = etaMinutes < 1 ? '< 1 min' : '$etaMinutes min';
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════

  void _navigateToTripInProgress() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TripInProgressScreen(
          tripId: widget.tripId,
          driver: widget.driver,
          pickupLocation: widget.pickupLocation,
          dropoffLocation: widget.dropoffLocation,
          pickupAddress: widget.pickupAddress,
          dropoffAddress: widget.dropoffAddress,
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Trip Canceled',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: const TextStyle(fontSize: 15, color: Colors.black54)),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Okay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _callDriver() async {
    final phone = _getField(widget.driver, ['phone', 'phone_e164', 'phoneNumber']);
    if (phone == null || phone.isEmpty) {
      _showErrorSnackBar('Driver phone number not available');
      return;
    }
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showErrorSnackBar('Cannot open phone dialer');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to make call');
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          tripId: widget.tripId,
          otherUserName: _getDriverName(),
          otherUserAvatar: _getField(widget.driver, ['avatar', 'avatar_url']),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _cancelTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Trip?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: const Text('The driver is on their way. Are you sure you want to cancel?',
            style: TextStyle(fontSize: 15, color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, Keep Trip',
                style: TextStyle(fontSize: 16, color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, Cancel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      tripProvider.cancelTrip(widget.tripId, 'Canceled by passenger');
      _hasNavigated = true;
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _fitMapToRoute() {
    if (_mapController == null || _animatedDriverLocation == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_animatedDriverLocation!.latitude, widget.pickupLocation.latitude),
        math.min(_animatedDriverLocation!.longitude, widget.pickupLocation.longitude),
      ),
      northeast: LatLng(
        math.max(_animatedDriverLocation!.latitude, widget.pickupLocation.latitude),
        math.max(_animatedDriverLocation!.longitude, widget.pickupLocation.longitude),
      ),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  String _getDriverName() {
    final first = _getField(widget.driver, ['firstName', 'first_name']) ?? '';
    final last = _getField(widget.driver, ['lastName', 'last_name']) ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : 'Driver';
  }

  String? _getDriverAvatarUrl() {
    return _getField(widget.driver, [
      'avatar',
      'avatar_url',
      'avatarUrl',
      'profile_photo',
      'profilePhoto',
      'photo',
      'picture',
    ]);
  }

  String? _getField(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }
    return null;
  }

  Map<String, String> get _vehicleInfo {
    final vehicle = widget.driver['vehicle'] as Map<String, dynamic>?;
    return {
      'type': _getField(vehicle ?? widget.driver, ['type', 'vehicleType']) ?? 'Standard',
      'plate': _getField(vehicle ?? widget.driver, ['plate', 'vehiclePlate']) ?? 'N/A',
      'makeModel': _getField(vehicle ?? widget.driver,
          ['makeModel', 'vehicle_make_model', 'vehicleMakeModel']) ?? 'Vehicle',
      'color': _getField(vehicle ?? widget.driver, ['color', 'vehicleColor']) ?? 'Unknown',
      'year': _getField(vehicle ?? widget.driver, ['year', 'vehicleYear']) ?? '',
      'photo': _getField(vehicle ?? widget.driver, ['photo', 'vehicle_photo_url']) ?? '',
    };
  }

  String get _driverRating =>
      _getField(widget.driver, ['rating', 'rating_avg', 'ratingAvg']) ?? '4.8';

  double _calculateBearing(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRadians(double deg) => deg * (math.pi / 180.0);

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Color _getVehicleColor(String colorName) {
    final map = {
      'black': Colors.black,
      'white': Colors.white,
      'silver': Colors.grey.shade400,
      'grey': Colors.grey,
      'gray': Colors.grey,
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'brown': Colors.brown,
      'gold': AppColors.primaryGold,
      'beige': const Color(0xFFF5F5DC),
      'purple': Colors.purple,
      'pink': Colors.pink,
    };
    return map[colorName.toLowerCase()] ?? Colors.grey;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════

  /// Driver avatar: tries to load image from URL, falls back to initials
  Widget _buildDriverAvatar({double size = 56, double fontSize = 24}) {
    final avatarUrl = _getDriverAvatarUrl();
    final driverName = _getDriverName();
    final initials = driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D';

    // Fallback widget — shown while loading OR when no URL
    Widget fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryGold,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );

    if (avatarUrl == null || avatarUrl.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // While loading, show initials fallback
        placeholder: (context, url) => fallback,
        // On error (broken URL, 404, etc.), show initials fallback
        errorWidget: (context, url, error) {
          debugPrint('⚠️ [DRIVER_ARRIVING] Avatar load failed: $url — $error');
          return fallback;
        },
      ),
    );
  }

  /// Persistent "Driver has arrived" banner — slides down from top
  /// Replaces the ETA pill once driver arrives
  Widget _buildArrivedBanner() {
    return ScaleTransition(
      scale: _arrivedBannerAnimation,
      child: FadeTransition(
        opacity: _arrivedBannerAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Your driver has arrived!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Persistent arrived banner shown inside the bottom card
  Widget _buildArrivedCardBanner() {
    return AnimatedBuilder(
      animation: _arrivedBannerAnimation,
      builder: (context, child) {
        final t = _arrivedBannerAnimation.value;

        // Opacity must be 0..1 even if curve overshoots
        final opacity = t.clamp(0.0, 1.0);

        // Keep the "pop" effect but make it stable
        final scale = 0.92 + (t * 0.08); // reaches ~1.0, small pop

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade500, Colors.green.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎉 Driver has arrived!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Head to your pickup point',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            _PulsingDot(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final vehicleInfo = _vehicleInfo;
    final driverName = _getDriverName();
    final rating = _driverRating;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── MAP ─────────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _animatedDriverLocation ?? widget.pickupLocation,
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              Future.delayed(const Duration(milliseconds: 500), _fitMapToRoute);
            },
          ),

          // ── TOP STATUS PILL (ETA or Arrived) ────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: _driverHasArrived
                  ? _buildArrivedBanner()
                  : AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _eta,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── BOTTOM CARD ──────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: [
                          // ── VEHICLE IDENTIFICATION CARD ────────────────
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryGold.withOpacity(0.15),
                                  AppColors.primaryGold.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primaryGold, width: 2),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.directions_car,
                                        color: AppColors.primaryGold, size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Your ride',
                                      style: AppTypography.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: _getVehicleColor(vehicleInfo['color']!),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vehicleInfo['makeModel']!,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            vehicleInfo['year']!.isNotEmpty
                                                ? '${vehicleInfo['color']} • ${vehicleInfo['year']}'
                                                : vehicleInfo['color']!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // License Plate
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.black, width: 2),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        vehicleInfo['plate']!,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 3,
                                          color: Colors.black,
                                          fontFamily: 'Courier',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── ARRIVED BANNER or PICKUP ADDRESS ──────────
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    child: child,
                                  ),
                                ),
                            child: _driverHasArrived
                                ? _buildArrivedCardBanner()
                                : _buildPickupAddressRow(),
                          ),

                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // ── DRIVER SECTION ─────────────────────────────
                          Row(
                            children: [
                              // ✅ Real avatar with fallback to initials
                              _buildDriverAvatar(size: 56, fontSize: 24),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driverName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star,
                                            size: 16, color: AppColors.primaryGold),
                                        const SizedBox(width: 4),
                                        Text(
                                          rating,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Call button
                              _ActionButton(
                                onTap: _callDriver,
                                icon: Icons.call,
                                iconColor: Colors.green.shade700,
                                backgroundColor: Colors.green.shade50,
                              ),
                              const SizedBox(width: 8),
                              // Chat button
                              _ActionButton(
                                onTap: _openChat,
                                icon: Icons.chat_bubble,
                                iconColor: AppColors.primaryGold,
                                backgroundColor: AppColors.primaryGold.withOpacity(0.1),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── CANCEL BUTTON ──────────────────────────────
                          // Hide cancel button once driver has arrived
                          if (!_driverHasArrived) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: _cancelTrip,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: Colors.grey.shade300, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text(
                                  'Cancel Trip',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // ── WAITING MESSAGE (shown after driver arrives) ─
                          if (_driverHasArrived) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Please make your way to the pickup point',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
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

  // ─────────────────────────────────────────────────────────────────
  Widget _buildPickupAddressRow() {
    return Container(
      key: const ValueKey('pickup'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.location_on, color: Colors.green.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pickup',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 2),
                Text(
                  widget.pickupAddress.length > 30
                      ? '${widget.pickupAddress.substring(0, 30)}...'
                      : widget.pickupAddress,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.straighten, size: 14, color: Colors.black54),
              const SizedBox(height: 2),
              Text(
                '${_distance.toStringAsFixed(1)} km',
                style: const TextStyle(
                    fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const _ActionButton({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

/// Small pulsing green dot shown in the arrived banner
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_animation.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(_animation.value * 0.5),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
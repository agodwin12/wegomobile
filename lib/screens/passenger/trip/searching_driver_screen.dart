// lib/presentation/screens/trip/searching_driver_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../utils/app_colors.dart';
import 'driver_arriving_screen.dart';

class SearchingDriverScreen extends StatefulWidget {
  final String tripId;
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;

  const SearchingDriverScreen({
    super.key,
    required this.tripId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
  });

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _rippleController;   // expanding rings
  late AnimationController _slideController;    // bottom sheet slide-up
  late AnimationController _orbitController;    // cars orbiting icon
  late AnimationController _shimmerController;  // text shimmer

  late Animation<Offset> _slideAnimation;
  late Animation<double> _shimmerAnimation;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _hasNavigated = false;
  int _searchingSeconds = 0;
  Timer? _counterTimer;

  // FIX: proper provider listener (not addPostFrameCallback inside builder)
  TripProvider? _tripProvider;
  VoidCallback? _tripListener;

  // ── Ripple data ────────────────────────────────────────────────────────────
  // Three rings staggered 0 / 0.33 / 0.66
  static const int _rippleCount = 3;

  @override
  void initState() {
    super.initState();
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔍 [SEARCHING] Screen initializing...');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _setupAnimations();
    _setupMarkers();
    _startSearchingTimer();

    // FIX: attach listener after first frame
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
    debugPrint('🗑️ [SEARCHING] Disposing screen resources...');
    if (_tripProvider != null && _tripListener != null) {
      _tripProvider!.removeListener(_tripListener!);
    }
    _rippleController.dispose();
    _slideController.dispose();
    _orbitController.dispose();
    _shimmerController.dispose();
    _counterTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SETUP
  // ══════════════════════════════════════════════════════════════════════════

  void _setupAnimations() {
    // Ripple rings — 3.5 s loop so each ring has time to fully expand
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    )..repeat();

    // Bottom sheet slides up on entry
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();

    // Mini cars orbit the central icon
    _orbitController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();

    // Shimmer on the status text
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _shimmerAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  void _setupMarkers() {
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: widget.pickupLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      anchor: const Offset(0.5, 1.0),
    ));
    _markers.add(Marker(
      markerId: const MarkerId('dropoff'),
      position: widget.dropoffLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      anchor: const Offset(0.5, 1.0),
    ));
    _polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      points: [widget.pickupLocation, widget.dropoffLocation],
      color: AppColors.primaryGold,
      width: 4,
      patterns: [PatternItem.dash(18), PatternItem.gap(10)],
    ));
  }

  void _startSearchingTimer() {
    _counterTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _searchingSeconds++);
        if (_searchingSeconds % 10 == 0) {
          debugPrint('⏱️ [SEARCHING] Searching for ${_searchingSeconds}s...');
        }
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TRIP STATUS
  // ══════════════════════════════════════════════════════════════════════════

  void _checkTripStatus(TripProvider tripProvider) {
    if (_hasNavigated || !mounted) return;

    switch (tripProvider.status) {
      case TripStatus.matched:
        debugPrint('\n✅ [SEARCHING] Driver matched! Navigating...\n');
        _navigateToDriverArriving(tripProvider);
        break;

      case TripStatus.idle:
      case TripStatus.canceled:
        if (tripProvider.errorMessage != null) {
          debugPrint('\n⚠️ [SEARCHING] Search ended: ${tripProvider.errorMessage}\n');
          _showNoDriverDialog(tripProvider.errorMessage!);
        }
        break;

      default:
        break;
    }
  }

  void _navigateToDriverArriving(TripProvider tripProvider) {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _counterTimer?.cancel();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && tripProvider.driver != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverArrivingScreen(
              tripId: widget.tripId,
              driver: tripProvider.driver!,
              driverLocation: tripProvider.driverLocation,
              pickupLocation: widget.pickupLocation,
              dropoffLocation: widget.dropoffLocation,
              pickupAddress: widget.pickupAddress,
              dropoffAddress: widget.dropoffAddress,
            ),
          ),
        );
      }
    });
  }

  void _showNoDriverDialog(String message) {
    if (_hasNavigated || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'No Drivers Available',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(message,
            style: const TextStyle(fontSize: 15, color: Colors.black54)),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try Again',
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

  Future<void> _cancelTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Search?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to cancel this trip request?',
            style: TextStyle(fontSize: 15, color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No',
                style: TextStyle(color: Colors.black54, fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, Cancel',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      debugPrint('❌ [SEARCHING] User canceled search');
      final tripProvider =
      Provider.of<TripProvider>(context, listen: false);
      // cancelTrip is void — no await
      tripProvider.cancelTrip(widget.tripId, 'Canceled by passenger');
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _fitMapToBounds() {
    if (_mapController == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(widget.pickupLocation.latitude,
            widget.dropoffLocation.latitude),
        math.min(widget.pickupLocation.longitude,
            widget.dropoffLocation.longitude),
      ),
      northeast: LatLng(
        math.max(widget.pickupLocation.latitude,
            widget.dropoffLocation.latitude),
        math.max(widget.pickupLocation.longitude,
            widget.dropoffLocation.longitude),
      ),
    );
    _mapController!
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 120));
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── MAP ──────────────────────────────────────────────────────────
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
            onMapCreated: (controller) {
              _mapController = controller;
              Future.delayed(
                  const Duration(milliseconds: 400), _fitMapToBounds);
            },
          ),

          // ── TOP TIMER PILL ───────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryGold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedBuilder(
                      animation: _shimmerAnimation,
                      builder: (_, __) => Opacity(
                        opacity: _shimmerAnimation.value,
                        child: Text(
                          'Searching  ${_formatTime(_searchingSeconds)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── CLOSE BUTTON ─────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            right: 16,
            child: _MapButton(
              icon: Icons.close_rounded,
              onTap: _cancelTrip,
            ),
          ),

          // ── BOTTOM SHEET ─────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: _BottomCard(
                pickupAddress: widget.pickupAddress,
                dropoffAddress: widget.dropoffAddress,
                rippleController: _rippleController,
                orbitController: _orbitController,
                shimmerAnimation: _shimmerAnimation,
                onCancel: _cancelTrip,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MAP FLOATING BUTTON
// ════════════════════════════════════════════════════════════════════════════

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BOTTOM CARD
// ════════════════════════════════════════════════════════════════════════════

class _BottomCard extends StatelessWidget {
  final String pickupAddress;
  final String dropoffAddress;
  final AnimationController rippleController;
  final AnimationController orbitController;
  final Animation<double> shimmerAnimation;
  final VoidCallback onCancel;

  const _BottomCard({
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.rippleController,
    required this.orbitController,
    required this.shimmerAnimation,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -6))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 14, bottom: 4),
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              children: [
                // ── HERO ANIMATION ──────────────────────────────────────
                _SearchingHeroAnimation(
                  rippleController: rippleController,
                  orbitController: orbitController,
                ),

                const SizedBox(height: 24),

                // ── STATUS TEXT ─────────────────────────────────────────
                AnimatedBuilder(
                  animation: shimmerAnimation,
                  builder: (_, __) => Opacity(
                    opacity: shimmerAnimation.value,
                    child: Column(
                      children: [
                        const Text(
                          'Finding your driver',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Connecting you with nearby drivers…',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── ROUTE CARD ──────────────────────────────────────────
                _RouteCard(
                    pickup: pickupAddress, dropoff: dropoffAddress),

                const SizedBox(height: 20),

                // ── CANCEL BUTTON ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.grey.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HERO SEARCHING ANIMATION
// ════════════════════════════════════════════════════════════════════════════

class _SearchingHeroAnimation extends StatelessWidget {
  final AnimationController rippleController;
  final AnimationController orbitController;

  const _SearchingHeroAnimation({
    required this.rippleController,
    required this.orbitController,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── RIPPLE RINGS ─────────────────────────────────────────────
          ...List.generate(3, (i) {
            final offset = i / 3.0;
            return AnimatedBuilder(
              animation: rippleController,
              builder: (_, __) {
                // Each ring lags behind the previous by `offset`
                final t = ((rippleController.value + offset) % 1.0);
                final scale = 0.35 + t * 0.65; // grows from 35% to 100%
                final opacity = (1.0 - t).clamp(0.0, 0.55);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryGold.withOpacity(opacity),
                        width: 2.5,
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // ── ORBITING MINI CARS ───────────────────────────────────────
          ...List.generate(3, (i) {
            final startAngle = (i / 3.0) * 2 * math.pi;
            return AnimatedBuilder(
              animation: orbitController,
              builder: (_, __) {
                final angle =
                    startAngle + orbitController.value * 2 * math.pi;
                const radius = 68.0;
                final x = math.cos(angle) * radius;
                final y = math.sin(angle) * radius;
                return Transform.translate(
                  offset: Offset(x, y),
                  child: Transform.rotate(
                    // car icon faces direction of travel
                    angle: angle + math.pi / 2,
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: AppColors.primaryGold,
                      size: 18,
                    ),
                  ),
                );
              },
            );
          }),

          // ── CENTRAL GOLD DISC ────────────────────────────────────────
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primaryGold,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withOpacity(0.40),
                  blurRadius: 22,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.local_taxi_rounded,
                size: 36,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ROUTE CARD
// ════════════════════════════════════════════════════════════════════════════

class _RouteCard extends StatelessWidget {
  final String pickup;
  final String dropoff;

  const _RouteCard({required this.pickup, required this.dropoff});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // ── DOT + LINE + DOT ─────────────────────────────────────────
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF22C55E), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // ── ADDRESSES ────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddressRow(label: 'Pickup', address: pickup),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                ),
                _AddressRow(label: 'Destination', address: dropoff),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final String label;
  final String address;

  const _AddressRow({required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(
          address.length > 38 ? '${address.substring(0, 38)}…' : address,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
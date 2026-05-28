// lib/presentation/screens/trip/searching_driver_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../providers/trip_provider.dart';
import '../../../utils/app_colors.dart';
import 'driver_arriving_screen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _kSheetMinFrac = 0.18;
const _kSheetMidFrac = 0.48;
const _kSheetMaxFrac = 0.85;

const _kTips = [
  'Usually takes 1–2 minutes',
  'Your safety is our priority',
  'Driver will call if needed',
  'Free cancellation while searching',
];

class SearchingDriverScreen extends StatefulWidget {
  final String tripId;
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String? fareEstimate;
  final String? vehicleType;
  final String? paymentMethod;

  const SearchingDriverScreen({
    super.key,
    required this.tripId,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.fareEstimate,
    this.vehicleType,
    this.paymentMethod,
  });

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen>
    with TickerProviderStateMixin {

  // ── API key ── read from dotenv internally, never from constructor ─────────
  String get _gmapsKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // ── Map ───────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  final Set<Marker>   _markers   = {};
  final Set<Polyline> _polylines = {};

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _tipFadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _tipFadeAnimation;

  // ── State ─────────────────────────────────────────────────────────────────
  bool   _hasNavigated     = false;
  int    _searchingSeconds = 0;
  int    _tipIndex         = 0;
  Timer? _counterTimer;
  Timer? _tipTimer;

  final List<LatLng> _nearbyDriverDots = [];
  Timer? _driverDotTimer;

  TripProvider? _tripProvider;
  VoidCallback? _tripListener;

  final DraggableScrollableController _sheetController =
  DraggableScrollableController();

  // ═════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 [SEARCHING] init — trip: ${widget.tripId}');
    _setupAnimations();
    _setupMarkers();
    _generateNearbyDriverDots();
    _startTimers();

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
    _tripProvider?.removeListener(_tripListener!);
    _radarController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _tipFadeController.dispose();
    _counterTimer?.cancel();
    _tipTimer?.cancel();
    _driverDotTimer?.cancel();
    _mapController?.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SETUP
  // ═════════════════════════════════════════════════════════════════════════

  void _setupAnimations() {
    _radarController = AnimationController(
        duration: const Duration(milliseconds: 2400), vsync: this)
      ..repeat();

    _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat(reverse: true);

    _slideController = AnimationController(
        duration: const Duration(milliseconds: 650), vsync: this);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));
    _slideController.forward();

    _tipFadeController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _tipFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _tipFadeController, curve: Curves.easeInOut));
    _tipFadeController.forward();
  }

  void _setupMarkers() {
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: widget.pickupLocation,
      icon:
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      anchor: const Offset(0.5, 1.0),
      infoWindow:
      InfoWindow(title: 'Pickup', snippet: widget.pickupAddress),
    ));
    _markers.add(Marker(
      markerId: const MarkerId('dropoff'),
      position: widget.dropoffLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      anchor: const Offset(0.5, 1.0),
      infoWindow:
      InfoWindow(title: 'Destination', snippet: widget.dropoffAddress),
    ));
  }

  void _generateNearbyDriverDots() {
    final rng = math.Random();
    _nearbyDriverDots.clear();
    for (int i = 0; i < 6; i++) {
      _nearbyDriverDots.add(LatLng(
        widget.pickupLocation.latitude  + (rng.nextDouble() - 0.5) * 0.022,
        widget.pickupLocation.longitude + (rng.nextDouble() - 0.5) * 0.022,
      ));
    }
    _rebuildDriverDots();

    _driverDotTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final rng2 = math.Random();
      for (int i = 0; i < _nearbyDriverDots.length; i++) {
        _nearbyDriverDots[i] = LatLng(
          _nearbyDriverDots[i].latitude  + (rng2.nextDouble() - 0.5) * 0.003,
          _nearbyDriverDots[i].longitude + (rng2.nextDouble() - 0.5) * 0.003,
        );
      }
      _rebuildDriverDots();
    });
  }

  void _rebuildDriverDots() {
    _markers
        .removeWhere((m) => m.markerId.value.startsWith('driver_dot_'));
    for (int i = 0; i < _nearbyDriverDots.length; i++) {
      _markers.add(Marker(
        markerId: MarkerId('driver_dot_$i'),
        position: _nearbyDriverDots[i],
        icon: BitmapDescriptor.defaultMarkerWithHue(38),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        alpha: 0.85,
      ));
    }
    if (mounted) setState(() {});
  }

  void _startTimers() {
    _counterTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _searchingSeconds++);
    });

    _tipTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _tipFadeController.reverse().then((_) {
        if (mounted) {
          setState(() => _tipIndex = (_tipIndex + 1) % _kTips.length);
          _tipFadeController.forward();
        }
      });
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // POLYLINE  ←  reads dotenv key directly
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _fetchRoutePolyline() async {
    final key = _gmapsKey;

    if (key.isEmpty) {
      debugPrint(
          '⚠️ [SEARCHING] GOOGLE_MAPS_API_KEY not set — straight line fallback');
      _drawFallbackPolyline();
      return;
    }

    final origin =
        '${widget.pickupLocation.latitude},${widget.pickupLocation.longitude}';
    final dest =
        '${widget.dropoffLocation.latitude},${widget.dropoffLocation.longitude}';

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$origin'
          '&destination=$dest'
          '&key=$key'
          '&mode=driving',
    );

    debugPrint('🗺️ [SEARCHING] Fetching route: $origin → $dest');

    try {
      final res =
      await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) {
        debugPrint('⚠️ [SEARCHING] HTTP ${res.statusCode} — fallback');
        _drawFallbackPolyline();
        return;
      }

      final data   = json.decode(res.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'UNKNOWN';

      if (status != 'OK') {
        debugPrint(
            '⚠️ [SEARCHING] Directions status: $status — fallback');
        _drawFallbackPolyline();
        return;
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        _drawFallbackPolyline();
        return;
      }

      final encoded =
          routes[0]['overview_polyline']['points'] as String? ?? '';
      if (encoded.isEmpty) {
        _drawFallbackPolyline();
        return;
      }

      final points = _decodePolyline(encoded);
      debugPrint('✅ [SEARCHING] ${points.length} points decoded');
      _applyPolyline(points);
    } catch (e) {
      debugPrint('❌ [SEARCHING] Route fetch exception: $e — fallback');
      _drawFallbackPolyline();
    }
  }

  void _drawFallbackPolyline() {
    debugPrint('🗺️ [SEARCHING] Straight-line fallback');
    _applyPolyline([widget.pickupLocation, widget.dropoffLocation]);
  }

  void _applyPolyline(List<LatLng> points) {
    _polylines.clear();
    _polylines.add(Polyline(
      polylineId: const PolylineId('route'),
      points: points,
      color: AppColors.primaryGold,
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
    ));
    if (mounted) setState(() {});
  }

  List<LatLng> _decodePolyline(String encoded) {
    final result = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, r = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        r |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((r & 1) != 0 ? ~(r >> 1) : (r >> 1));
      shift = 0;
      r = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        r |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((r & 1) != 0 ? ~(r >> 1) : (r >> 1));
      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }

  void _fitMapToBounds() {
    if (_mapController == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(widget.pickupLocation.latitude,
            widget.dropoffLocation.latitude) - 0.003,
        math.min(widget.pickupLocation.longitude,
            widget.dropoffLocation.longitude) - 0.003,
      ),
      northeast: LatLng(
        math.max(widget.pickupLocation.latitude,
            widget.dropoffLocation.latitude) + 0.003,
        math.max(widget.pickupLocation.longitude,
            widget.dropoffLocation.longitude) + 0.003,
      ),
    );
    _mapController!
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TRIP STATUS
  // ═════════════════════════════════════════════════════════════════════════

  void _checkTripStatus(TripProvider tp) {
    if (_hasNavigated || !mounted) return;

    switch (tp.status) {
      case TripStatus.matched:
        debugPrint('✅ [SEARCHING] Driver matched');
        _navigateToDriverArriving(tp);
        break;

      case TripStatus.idle:
      case TripStatus.canceled:
        if (tp.errorMessage != null) {
          _showNoDriverDialog(tp.errorMessage!);
        }
        break;

      default:
        break;
    }
  }

  void _navigateToDriverArriving(TripProvider tp) {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _counterTimer?.cancel();
    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && tp.driver != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverArrivingScreen(
              tripId:          widget.tripId,
              driver:          tp.driver!,
              driverLocation:  tp.driverLocation,
              pickupLocation:  widget.pickupLocation,
              dropoffLocation: widget.dropoffLocation,
              pickupAddress:   widget.pickupAddress,
              dropoffAddress:  widget.dropoffAddress,
              // No googleMapsApiKey param — DriverArrivingScreen
              // reads from dotenv directly
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
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('No Drivers Available',
            style:
            TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: const TextStyle(
                fontSize: 15, color: Colors.black54)),
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
                padding:
                const EdgeInsets.symmetric(vertical: 16),
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Search?',
            style:
            TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to cancel this trip request?',
            style:
            TextStyle(fontSize: 15, color: Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No',
                style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
            child: const Text('Yes, Cancel',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final tp = Provider.of<TripProvider>(context, listen: false);
      tp.cancelTrip(widget.tripId, 'Canceled by passenger');
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _formatTime(int s) {
    final m   = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          // ── MAP ──────────────────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                  target: widget.pickupLocation, zoom: 14),
              markers:   _markers,
              polylines: _polylines,
              myLocationEnabled:       false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled:     false,
              mapToolbarEnabled:       false,
              compassEnabled:          false,
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (!mounted) return;
                  _fitMapToBounds();
                  _fetchRoutePolyline();
                });
              },
            ),
          ),

          // ── TOP TIMER PILL ────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0, right: 0,
            child: Center(
                child: _TimerPill(
                    elapsed: _formatTime(_searchingSeconds))),
          ),

          // ── CLOSE BUTTON ──────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: _MapIconButton(
                icon: Icons.close_rounded, onTap: _cancelTrip),
          ),

          // ── DRAGGABLE BOTTOM SHEET ────────────────────────────────────────
          DraggableScrollableSheet(
            controller:      _sheetController,
            initialChildSize: _kSheetMidFrac,
            minChildSize:     _kSheetMinFrac,
            maxChildSize:     _kSheetMaxFrac,
            snap: true,
            snapSizes: const [
              _kSheetMinFrac, _kSheetMidFrac, _kSheetMaxFrac
            ],
            builder: (ctx, scrollCtrl) {
              return SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(26)),
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 24,
                          offset: Offset(0, -6)),
                    ],
                  ),
                  child: ListView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 12),
                          width: 38, height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius:
                              BorderRadius.circular(2)),
                        ),
                      ),

                      Padding(
                        padding:
                        const EdgeInsets.fromLTRB(24, 4, 24, 0),
                        child: Column(
                          children: [
                            _RadarAnimation(
                              radarCtrl: _radarController,
                              pulseCtrl: _pulseController,
                            ),

                            const SizedBox(height: 20),

                            const Text(
                              'Finding your driver',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: -0.3,
                              ),
                            ),

                            const SizedBox(height: 6),

                            FadeTransition(
                              opacity: _tipFadeAnimation,
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 13,
                                      color: Colors.grey.shade500),
                                  const SizedBox(width: 5),
                                  Text(
                                    _kTips[_tipIndex],
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500,
                                        fontWeight:
                                        FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            _TripMetaRow(
                              fareEstimate:  widget.fareEstimate,
                              vehicleType:   widget.vehicleType,
                              paymentMethod: widget.paymentMethod,
                            ),

                            const SizedBox(height: 20),

                            _RouteCard(
                              pickup:  widget.pickupAddress,
                              dropoff: widget.dropoffAddress,
                            ),

                            const SizedBox(height: 20),

                            _CancelButton(onTap: _cancelTrip),

                            SizedBox(
                              height: MediaQuery.of(context)
                                  .padding
                                  .bottom +
                                  20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RADAR ANIMATION
// ═══════════════════════════════════════════════════════════════════════════

class _RadarAnimation extends StatelessWidget {
  final AnimationController radarCtrl;
  final AnimationController pulseCtrl;
  const _RadarAnimation(
      {required this.radarCtrl, required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160, height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(3, (i) {
            final frac = 0.38 + i * 0.31;
            return Container(
              width:  160 * frac,
              height: 160 * frac,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.grey.shade200, width: 1.5),
              ),
            );
          }),

          AnimatedBuilder(
            animation: radarCtrl,
            builder: (_, __) => CustomPaint(
              size: const Size(160, 160),
              painter: _RadarSweepPainter(
                  angle: radarCtrl.value * 2 * math.pi),
            ),
          ),

          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) {
              final scale = 0.92 +
                  Tween<double>(begin: 0.0, end: 1.0)
                      .animate(CurvedAnimation(
                      parent: pulseCtrl,
                      curve: Curves.easeInOut))
                      .value *
                      0.08;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGold
                            .withOpacity(0.45),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.local_taxi_rounded,
                        size: 30, color: Colors.black),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RadarSweepPainter extends CustomPainter {
  final double angle;
  _RadarSweepPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center     = Offset(size.width / 2, size.height / 2);
    final radius     = size.width / 2;
    final sweepAngle = math.pi * 0.75;
    final startAngle = angle - sweepAngle;
    final rect       = Rect.fromCircle(center: center, radius: radius);

    final shader = SweepGradient(
      center: Alignment.center,
      startAngle: startAngle,
      endAngle: angle,
      colors: [
        AppColors.primaryGold.withOpacity(0.0),
        AppColors.primaryGold.withOpacity(0.18),
      ],
    ).createShader(rect);

    canvas.drawArc(rect, startAngle, sweepAngle, true,
        Paint()..shader = shader..style = PaintingStyle.fill);

    canvas.drawLine(
      center,
      Offset(center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius),
      Paint()
        ..color = AppColors.primaryGold.withOpacity(0.7)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_RadarSweepPainter old) => old.angle != angle;
}

// ═══════════════════════════════════════════════════════════════════════════
// TRIP META ROW
// ═══════════════════════════════════════════════════════════════════════════

class _TripMetaRow extends StatelessWidget {
  final String? fareEstimate;
  final String? vehicleType;
  final String? paymentMethod;
  const _TripMetaRow(
      {this.fareEstimate, this.vehicleType, this.paymentMethod});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (fareEstimate != null && fareEstimate!.isNotEmpty) {
      items.add(_MetaPill(
          icon: Icons.payments_rounded,
          label: fareEstimate!,
          accent: AppColors.primaryGold));
    }
    if (vehicleType != null && vehicleType!.isNotEmpty) {
      items.add(_MetaPill(
          icon: Icons.directions_car_rounded,
          label: vehicleType!,
          accent: Colors.black));
    }
    if (paymentMethod != null && paymentMethod!.isNotEmpty) {
      items.add(_MetaPill(
          icon: paymentMethod == 'Cash'
              ? Icons.money_rounded
              : Icons.phone_android_rounded,
          label: paymentMethod!,
          accent: Colors.black));
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items
          .expand((w) => [w, const SizedBox(width: 8)])
          .toList()
        ..removeLast(),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  const _MetaPill(
      {required this.icon, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isGold = accent == AppColors.primaryGold;
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isGold
            ? AppColors.primaryGold.withOpacity(0.12)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
            color: isGold
                ? AppColors.primaryGold.withOpacity(0.4)
                : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color:
              isGold ? Colors.orange.shade800 : Colors.black87),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isGold
                      ? Colors.orange.shade900
                      : Colors.black87)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ROUTE CARD
// ═══════════════════════════════════════════════════════════════════════════

class _RouteCard extends StatelessWidget {
  final String pickup;
  final String dropoff;
  const _RouteCard({required this.pickup, required this.dropoff});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle)),
              Container(
                width: 2, height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF22C55E),
                      Color(0xFFEF4444)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddrLine(label: 'Pickup',      address: pickup),
                Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                      height: 1, color: Colors.grey.shade200),
                ),
                _AddrLine(
                    label: 'Destination', address: dropoff),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddrLine extends StatelessWidget {
  final String label;
  final String address;
  const _AddrLine({required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(
          address.length > 38
              ? '${address.substring(0, 38)}…'
              : address,
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

// ═══════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _TimerPill extends StatelessWidget {
  final String elapsed;
  const _TimerPill({required this.elapsed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.88),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGold),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Searching  $elapsed',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: Colors.grey.shade300, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Cancel Trip',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
        ),
      ),
    );
  }
}
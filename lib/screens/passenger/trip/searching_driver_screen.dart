// lib/presentation/screens/trip/searching_driver_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../providers/trip_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/map_style.dart';
import '../../../widgets/map_style_button.dart';
import 'driver_arriving_screen.dart';
import 'no_drivers_screen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _kSheetMinFrac = 0.18;
const _kSheetMidFrac = 0.48;
const _kSheetMaxFrac = 0.85;

const _kTips = [
  'Cela prend généralement 1 à 2 minutes',
  'Votre sécurité est notre priorité',
  'Le chauffeur vous appellera si besoin',
  'Annulation gratuite pendant la recherche',
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

  String get _mapboxToken => dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  MapStyle _mapStyle = MapStyle.dark;

  final MapController _mapCtrl = MapController();
  List<Polyline> _polylines = [];

  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _tipFadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _tipFadeAnimation;

  bool   _hasNavigated     = false;
  int    _searchingSeconds = 0;
  int    _tipIndex         = 0;
  Timer? _counterTimer;
  Timer? _tipTimer;

  final List<_SearchCar> _searchCars = [];
  Timer? _driverCarTimer;

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
    _setupAnimations();
    _generateNearbyDriverCars();
    _startTimers();
    loadMapStylePref().then((s) { if (mounted) setState(() => _mapStyle = s); });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _tripProvider = Provider.of<TripProvider>(context, listen: false);
      _tripListener = () => _checkTripStatus(_tripProvider!);
      _tripProvider!.addListener(_tripListener!);
      _checkTripStatus(_tripProvider!);

      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        _fitMapToBounds();
        _fetchRoutePolyline();
      }
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
    _driverCarTimer?.cancel();
    _mapCtrl.dispose();
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
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _slideController.forward();

    _tipFadeController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _tipFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _tipFadeController, curve: Curves.easeInOut));
    _tipFadeController.forward();
  }

  // Small Uber/Yango-style cars drifting around the pickup while we search.
  void _generateNearbyDriverCars() {
    final rng = math.Random();
    _searchCars.clear();
    for (int i = 0; i < 6; i++) {
      _searchCars.add(_SearchCar(
        LatLng(
          widget.pickupLocation.latitude  + (rng.nextDouble() - 0.5) * 0.012,
          widget.pickupLocation.longitude + (rng.nextDouble() - 0.5) * 0.012,
        ),
        rng.nextDouble() * 360,
      ));
    }

    _driverCarTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final rng2 = math.Random();
      setState(() {
        for (final car in _searchCars) {
          final from = car.pos;
          final next = LatLng(
            from.latitude  + (rng2.nextDouble() - 0.5) * 0.0016,
            from.longitude + (rng2.nextDouble() - 0.5) * 0.0016,
          );
          car.heading = _bearing(from, next);
          car.pos     = next;
        }
      });
    });
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
  // ROUTE POLYLINE (Mapbox Directions)
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _fetchRoutePolyline() async {
    final token = _mapboxToken;
    if (token.isEmpty || token.startsWith('pk.YOUR')) {
      _drawFallbackPolyline();
      return;
    }

    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
          '${widget.pickupLocation.longitude},${widget.pickupLocation.latitude};'
          '${widget.dropoffLocation.longitude},${widget.dropoffLocation.latitude}'
          '?access_token=$token&geometries=polyline&overview=full',
    );

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data   = json.decode(res.body);
        final routes = data['routes'] as List? ?? [];
        if (routes.isNotEmpty) {
          final points = _decodePolyline(routes[0]['geometry'] as String);
          _applyPolyline(points);
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SEARCHING] Route fetch: $e — fallback');
    }
    _drawFallbackPolyline();
  }

  void _drawFallbackPolyline() => _applyPolyline([widget.pickupLocation, widget.dropoffLocation]);

  void _applyPolyline(List<LatLng> points) {
    if (!mounted) return;
    setState(() {
      _polylines = [
        Polyline(points: points, color: AppColors.primaryGold.withOpacity(0.25), strokeWidth: 11),
        Polyline(points: points, color: AppColors.primaryGold, strokeWidth: 5),
      ];
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    final result = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, r = 0;
      do { b = encoded.codeUnitAt(index++) - 63; r |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lat += ((r & 1) != 0 ? ~(r >> 1) : (r >> 1));
      shift = 0; r = 0;
      do { b = encoded.codeUnitAt(index++) - 63; r |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lng += ((r & 1) != 0 ? ~(r >> 1) : (r >> 1));
      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }

  void _fitMapToBounds() {
    if (!mounted) return;
    try {
      final bounds = LatLngBounds.fromPoints([widget.pickupLocation, widget.dropoffLocation]);
      _mapCtrl.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(100)));
    } catch (_) {}
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TRIP STATUS
  // ═════════════════════════════════════════════════════════════════════════

  void _checkTripStatus(TripProvider tp) {
    if (_hasNavigated || !mounted) return;
    switch (tp.status) {
      case TripStatus.matched:
        _navigateToDriverArriving(tp);
        break;
      case TripStatus.idle:
      case TripStatus.canceled:
        if (tp.errorMessage != null) _showNoDriverDialog(tp.errorMessage!);
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
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DriverArrivingScreen(
          tripId:          widget.tripId,
          driver:          tp.driver!,
          driverLocation:  tp.driverLocation,
          pickupLocation:  widget.pickupLocation,
          dropoffLocation: widget.dropoffLocation,
          pickupAddress:   widget.pickupAddress,
          dropoffAddress:  widget.dropoffAddress,
          fareEstimate:    widget.fareEstimate,
          paymentMethod:   widget.paymentMethod,
          vehicleType:     widget.vehicleType,
        )));
      }
    });
  }

  void _showNoDriverDialog(String message) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _counterTimer?.cancel();
    _tipTimer?.cancel();
    _driverCarTimer?.cancel();
    // Full-screen "no drivers" experience instead of a dialog so the passenger
    // is never left on an infinite searching spinner. Both Retry and Cancel
    // return to the ride map (pushReplacement removed this searching screen).
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => NoDriversScreen(message: message)),
    );
  }

  Future<void> _cancelTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Annuler la recherche ?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary)),
        content: const Text('Êtes-vous sûr de vouloir annuler cette demande de course ?', style: TextStyle(fontSize: 15, color: AppColors.darkTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Non', style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 16, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            child: const Text('Oui, annuler', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Provider.of<TripProvider>(context, listen: false).cancelTrip(widget.tripId, 'Annulée par le passager');
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _formatTime(int s) {
    final m   = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y    = math.sin(dLon) * math.cos(lat2);
    final x    = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[
      // pickup (origin)
      Marker(
        point: widget.pickupLocation, width: 34, height: 34,
        child: Container(
          decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))]),
          child: Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
        ),
      ),
      // dropoff
      Marker(
        point: widget.dropoffLocation, width: 32, height: 32,
        child: Container(
          decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))]),
          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 15),
        ),
      ),
    ];

    for (final car in _searchCars) {
      markers.add(Marker(
        point: car.pos, width: 40, height: 40,
        child: _SearchingCarMarker(heading: car.heading),
      ));
    }
    return markers;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: widget.pickupLocation,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapStyle.tileUrl(_mapboxToken),
                  userAgentPackageName: 'com.wego.app',
                  fallbackUrl: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                ),
                PolylineLayer(polylines: _polylines),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
          ),

          MapStyleButton(
            current: _mapStyle,
            onChanged: (s) { setState(() => _mapStyle = s); saveMapStylePref(s); },
          ),

          // Timer pill
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0, right: 0,
            child: Center(child: _TimerPill(elapsed: _formatTime(_searchingSeconds))),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: _MapIconButton(icon: Icons.close_rounded, onTap: _cancelTrip),
          ),

          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _kSheetMidFrac,
            minChildSize: _kSheetMinFrac,
            maxChildSize: _kSheetMaxFrac,
            snap: true,
            snapSizes: const [_kSheetMinFrac, _kSheetMidFrac, _kSheetMaxFrac],
            builder: (ctx, scrollCtrl) {
              return SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                    border: Border(top: BorderSide(color: AppColors.darkBorder.withOpacity(0.6))),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, -6))],
                  ),
                  child: ListView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    children: [
                      Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 38, height: 4, decoration: BoxDecoration(color: AppColors.darkSurfaceHigh, borderRadius: BorderRadius.circular(2)))),

                      // ── Promo banner ─────────────────────────────────────
                      if (widget.vehicleType != null)
                        _SearchingPromoBanner(vehicleType: widget.vehicleType!),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Column(
                          children: [
                            _RadarAnimation(radarCtrl: _radarController, pulseCtrl: _pulseController),
                            const SizedBox(height: 20),
                            const Text('Finding your driver', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.darkTextPrimary, letterSpacing: -0.3)),
                            const SizedBox(height: 6),
                            FadeTransition(
                              opacity: _tipFadeAnimation,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 13, color: AppColors.darkTextTertiary),
                                  const SizedBox(width: 5),
                                  Flexible(child: Text(_kTips[_tipIndex], textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary, fontWeight: FontWeight.w500))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            _TripMetaRow(fareEstimate: widget.fareEstimate, vehicleType: widget.vehicleType, paymentMethod: widget.paymentMethod),
                            const SizedBox(height: 20),
                            _RouteCard(pickup: widget.pickupAddress, dropoff: widget.dropoffAddress),
                            const SizedBox(height: 20),
                            _CancelButton(onTap: _cancelTrip),
                            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
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
// SEARCHING CARS (small top-down sedans, Uber/Yango style)
// ═══════════════════════════════════════════════════════════════════════════

class _SearchCar {
  LatLng pos;
  double heading;
  _SearchCar(this.pos, this.heading);
}

class _SearchingCarMarker extends StatefulWidget {
  final double heading;
  const _SearchingCarMarker({required this.heading});

  @override
  State<_SearchingCarMarker> createState() => _SearchingCarMarkerState();
}

class _SearchingCarMarkerState extends State<_SearchingCarMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final forward = -1.5 + _c.value * 3.0;
        return Transform.rotate(
          angle: widget.heading * math.pi / 180,
          child: Transform.translate(
            offset: Offset(0, forward),
            child: Image.asset('assets/images/carmarker.png',
                width: 30, height: 30, fit: BoxFit.contain),
          ),
        );
      },
    );
  }
}

class _CarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final body  = Paint()..color = AppColors.primaryGold;
    final glass = Paint()..color = const Color(0xFF15151A).withOpacity(0.9);
    final light = Paint()..color = Colors.white.withOpacity(0.92);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.66, height: h * 0.92),
      Radius.circular(w * 0.24),
    );

    canvas.drawRRect(bodyRect.shift(const Offset(0, 1.6)), shadow);
    canvas.drawRRect(bodyRect, body);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, h * 0.31), width: w * 0.46, height: h * 0.17), const Radius.circular(2.5)),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, h * 0.67), width: w * 0.46, height: h * 0.15), const Radius.circular(2.5)),
      glass,
    );

    canvas.drawCircle(Offset(w * 0.40, h * 0.10), 1.2, light);
    canvas.drawCircle(Offset(w * 0.60, h * 0.10), 1.2, light);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// RADAR ANIMATION
// ═══════════════════════════════════════════════════════════════════════════

class _RadarAnimation extends StatelessWidget {
  final AnimationController radarCtrl;
  final AnimationController pulseCtrl;
  const _RadarAnimation({required this.radarCtrl, required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160, height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(3, (i) {
            final frac = 0.38 + i * 0.31;
            return Container(width: 160 * frac, height: 160 * frac, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.darkBorder, width: 1.5)));
          }),
          AnimatedBuilder(
            animation: radarCtrl,
            builder: (_, __) => CustomPaint(
              size: const Size(160, 160),
              painter: _RadarSweepPainter(angle: radarCtrl.value * 2 * math.pi),
            ),
          ),
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) {
              final scale = 0.92 + Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: pulseCtrl, curve: Curves.easeInOut)).value * 0.08;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.primaryGold.withOpacity(0.45), blurRadius: 20, spreadRadius: 4)],
                  ),
                  child: const Center(child: Icon(Icons.local_taxi_rounded, size: 30, color: AppColors.textPrimary)),
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

    canvas.drawArc(rect, startAngle, sweepAngle, true,
        Paint()
          ..shader = SweepGradient(center: Alignment.center, startAngle: startAngle, endAngle: angle, colors: [AppColors.primaryGold.withOpacity(0.0), AppColors.primaryGold.withOpacity(0.18)]).createShader(rect)
          ..style = PaintingStyle.fill);

    canvas.drawLine(center, Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius),
        Paint()..color = AppColors.primaryGold.withOpacity(0.7)..strokeWidth = 2.0..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_RadarSweepPainter old) => old.angle != angle;
}

// ═══════════════════════════════════════════════════════════════════════════
// TRIP META ROW
// ═══════════════════════════════════════════════════════════════════════════

String _paymentLabel(String m) {
  switch (m.toLowerCase()) {
    case 'cash': return 'Espèces';
    case 'om':   return 'Orange Money';
    case 'momo': return 'MTN MoMo';
    default:     return m;
  }
}

IconData _paymentIcon(String m) => m.toLowerCase() == 'cash' ? Icons.payments_rounded : Icons.phone_android_rounded;

class _TripMetaRow extends StatelessWidget {
  final String? fareEstimate;
  final String? vehicleType;
  final String? paymentMethod;
  const _TripMetaRow({this.fareEstimate, this.vehicleType, this.paymentMethod});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (fareEstimate != null && fareEstimate!.isNotEmpty) items.add(_MetaPill(icon: Icons.payments_rounded, label: fareEstimate!, gold: true));
    if (vehicleType  != null && vehicleType!.isNotEmpty)  items.add(_MetaPill(icon: Icons.directions_car_rounded, label: vehicleType!, gold: false));
    if (paymentMethod!= null && paymentMethod!.isNotEmpty) items.add(_MetaPill(icon: _paymentIcon(paymentMethod!), label: _paymentLabel(paymentMethod!), gold: false));
    if (items.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.expand((w) => [w, const SizedBox(width: 8)]).toList()..removeLast(),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool gold;
  const _MetaPill({required this.icon, required this.label, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: gold ? AppColors.primaryGold.withOpacity(0.12) : AppColors.darkSurfaceAlt,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: gold ? AppColors.primaryGold.withOpacity(0.4) : AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: gold ? AppColors.primaryGold : AppColors.darkTextSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: gold ? AppColors.primaryGold : AppColors.darkTextPrimary)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
      child: Row(
        children: [
          Column(children: [
            Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
            Container(width: 2, height: 30, decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF22C55E), Color(0xFFEF4444)]), borderRadius: BorderRadius.circular(1))),
            Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AddrLine(label: 'Départ', address: pickup),
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: AppColors.darkBorder)),
              _AddrLine(label: 'Destination', address: dropoff),
            ],
          )),
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
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.darkTextTertiary)),
        const SizedBox(height: 2),
        Text(address.length > 38 ? '${address.substring(0, 38)}…' : address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(50), border: Border.all(color: AppColors.darkBorder), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 4))]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold))),
          const SizedBox(width: 10),
          Text('Recherche  $elapsed', style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
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
        decoration: BoxDecoration(color: AppColors.darkSurface, shape: BoxShape.circle, border: Border.all(color: AppColors.darkBorder), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROMO BANNER
// ═══════════════════════════════════════════════════════════════════════════

class _SearchingPromoBanner extends StatelessWidget {
  final String vehicleType;
  const _SearchingPromoBanner({required this.vehicleType});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.primaryGold,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.bolt_rounded, color: Colors.black, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(
          '$vehicleType · Matching you with nearby drivers',
          style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black,
          ),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        )),
      ]),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.darkBorder, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: const Text('Annuler la course', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary)),
      ),
    );
  }
}
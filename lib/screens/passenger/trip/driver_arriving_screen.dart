// lib/presentation/screens/trip/driver_arriving_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../providers/trip_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';
import '../../chat/trip_chat_screen.dart';
import 'tripProgressScreen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _kFreeCancelSeconds   = 300;
const _kBottomSheetMinFrac  = 0.22;
const _kBottomSheetMidFrac  = 0.52;
const _kBottomSheetMaxFrac  = 0.88;

// ─────────────────────────────────────────────────────────────────────────────

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

  // ── API key ────────────────────────────────────────────────────────────────
  String get _gmapsKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // ── Map ────────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  final Set<Marker>   _markers   = {};
  final Set<Polyline> _polylines = {};
  bool _isFollowingDriver = true;

  // ── Animations ─────────────────────────────────────────────────────────────
  AnimationController? _slideCtrl;
  AnimationController? _carAnimCtrl;
  AnimationController? _pulseCtrl;
  AnimationController? _arrivedBannerCtrl;

  Animation<Offset>? _slideAnim;
  Animation<double>? _pulseAnim;
  Animation<double>? _arrivedBannerAnim;

  // ── Driver position ────────────────────────────────────────────────────────
  LatLng? _currentDriverLocation;
  LatLng? _animatedDriverLocation;
  double  _driverBearing = 0.0;

  // ── Trip state ─────────────────────────────────────────────────────────────
  bool   _hasNavigated       = false;
  bool   _driverArrivedShown = false;
  bool   _driverHasArrived   = false;
  String _eta      = '--';
  double _distance = 0.0;

  // ── Free cancel timer ──────────────────────────────────────────────────────
  int    _freeCancelSecondsLeft = _kFreeCancelSeconds;
  Timer? _freeCancelTimer;
  bool   _freeCancelExpired = false;

  // ── Provider ───────────────────────────────────────────────────────────────
  TripProvider?  _tripProvider;
  VoidCallback?  _tripListener;

  // ── Sheet ──────────────────────────────────────────────────────────────────
  final DraggableScrollableController _sheetCtrl =
  DraggableScrollableController();

  // ── Custom markers ─────────────────────────────────────────────────────────
  BitmapDescriptor? _carMarkerIcon;
  BitmapDescriptor? _pickupMarkerIcon;

  // ── Polyline debounce ──────────────────────────────────────────────────────
  /// Tracks the last driver location for which we fetched a polyline.
  /// We only re-fetch when the driver has moved more than ~50 m, so we
  /// don't hammer the Directions API on every location tick.
  LatLng? _lastPolylineOrigin;

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    debugPrint('🚗 [ARRIVING] init — trip: ${widget.tripId}');
    _setupAnimations();
    _initDriverLocation();
    _startFreeCancelTimer();
    _loadCustomMarkers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tripProvider  = Provider.of<TripProvider>(context, listen: false);
      _tripListener  = () => _checkTripStatus(_tripProvider!);
      _tripProvider!.addListener(_tripListener!);
      _checkTripStatus(_tripProvider!);
    });
  }

  @override
  void dispose() {
    _tripProvider?.removeListener(_tripListener!);
    _slideCtrl?.dispose();
    _carAnimCtrl?.dispose();
    _pulseCtrl?.dispose();
    _arrivedBannerCtrl?.dispose();
    _mapController?.dispose();
    _sheetCtrl.dispose();
    _freeCancelTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETUP
  // ═══════════════════════════════════════════════════════════════════════════

  void _setupAnimations() {
    _slideCtrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl!, curve: Curves.easeOutCubic));

    _carAnimCtrl = AnimationController(
        duration: const Duration(seconds: 2), vsync: this);

    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 1400), vsync: this);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut),
    );
    _pulseCtrl!.repeat(reverse: true);

    _arrivedBannerCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _arrivedBannerAnim = CurvedAnimation(
        parent: _arrivedBannerCtrl!, curve: Curves.easeOutBack);

    _slideCtrl!.forward();
  }

  void _initDriverLocation() {
    final loc = widget.driverLocation;
    if (loc != null && loc['lat'] != null && loc['lng'] != null) {
      _currentDriverLocation =
          LatLng(_toDouble(loc['lat']), _toDouble(loc['lng']));
    } else {
      _currentDriverLocation = LatLng(
        widget.pickupLocation.latitude  + 0.003,
        widget.pickupLocation.longitude + 0.003,
      );
    }
    _animatedDriverLocation = _currentDriverLocation;
    _driverBearing =
        _calcBearing(_currentDriverLocation!, widget.pickupLocation);
    _calcDistETA();
  }

  void _startFreeCancelTimer() {
    _freeCancelTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_freeCancelSecondsLeft > 0) {
          _freeCancelSecondsLeft--;
        } else {
          _freeCancelExpired = true;
          t.cancel();
        }
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MARKERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadCustomMarkers() async {
    _carMarkerIcon    = await _createCarMarkerIcon();
    _pickupMarkerIcon = await _createPickupMarkerIcon();
    if (mounted) _rebuildMarkers();
  }

  Future<BitmapDescriptor> _createCarMarkerIcon() async {
    // 1. Try loading from assets
    try {
      final byteData = await rootBundle.load('assets/car.png');
      final codec = await ui.instantiateImageCodec(
        byteData.buffer.asUint8List(),
        targetWidth: 80, targetHeight: 80,
      );
      final frame    = await codec.getNextFrame();
      final pngBytes = await frame.image
          .toByteData(format: ui.ImageByteFormat.png);
      if (pngBytes != null) {
        debugPrint('✅ [ARRIVING] Car icon from assets/car.png');
        return BitmapDescriptor.fromBytes(pngBytes.buffer.asUint8List());
      }
    } catch (_) {}

    // 2. Draw a simple car-shaped icon as fallback
    try {
      const size = 80.0;
      final recorder = ui.PictureRecorder();
      final canvas   = Canvas(recorder);

      // Shadow
      canvas.drawCircle(
        const Offset(size / 2, size / 2 + 3),
        size / 2.6,
        Paint()..color = Colors.black.withOpacity(0.18),
      );
      // Gold circle body
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2.8,
        Paint()..color = AppColors.primaryGold,
      );
      // White border
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2.8,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      // Car icon text
      final tp = TextPainter(
        text: const TextSpan(
          text: '🚗',
          style: TextStyle(fontSize: 22),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset((size - tp.width) / 2, (size - tp.height) / 2));

      final picture = recorder.endRecording();
      final img     = await picture.toImage(size.toInt(), size.toInt());
      final bytes   = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) {
        return BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
      }
    } catch (_) {}

    return BitmapDescriptor.defaultMarkerWithHue(38);
  }

  Future<BitmapDescriptor> _createPickupMarkerIcon() async {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }

  void _rebuildMarkers() {
    _markers.clear();

    // Pickup pin
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: widget.pickupLocation,
      icon: _pickupMarkerIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      anchor: const Offset(0.5, 1.0),
      infoWindow: InfoWindow(
          title: 'Your pickup', snippet: widget.pickupAddress),
    ));

    // Animated driver car
    if (_animatedDriverLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _animatedDriverLocation!,
        icon: _carMarkerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(38),
        anchor: const Offset(0.5, 0.5),
        rotation: _driverBearing,
        flat: true,
        infoWindow: InfoWindow(
            title: _getDriverName(), snippet: 'Your driver'),
      ));
    }

    if (mounted) setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POLYLINE  ←  the real fix
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetches a real road polyline from the Google Directions API.
  ///
  /// Only re-fetches when the driver has moved > 50 m from the last fetch
  /// origin, keeping API usage reasonable.
  ///
  /// Falls back to a straight line only if the API call genuinely fails.
  Future<void> _fetchRoutePolyline({bool force = false}) async {
    if (_animatedDriverLocation == null) return;

    // Debounce: skip if driver hasn't moved > 50 m since last fetch
    if (!force && _lastPolylineOrigin != null) {
      final moved = _haversineKm(
        _animatedDriverLocation!.latitude,
        _animatedDriverLocation!.longitude,
        _lastPolylineOrigin!.latitude,
        _lastPolylineOrigin!.longitude,
      );
      if (moved < 0.05) {
        debugPrint('🗺️ [POLYLINE] Skipping re-fetch — driver moved only '
            '${(moved * 1000).toStringAsFixed(0)} m');
        return;
      }
    }

    final key = _gmapsKey;
    if (key.isEmpty) {
      debugPrint('⚠️ [POLYLINE] No API key — falling back to straight line');
      _drawStraightLine();
      return;
    }

    final origin =
        '${_animatedDriverLocation!.latitude},${_animatedDriverLocation!.longitude}';
    final destination =
        '${widget.pickupLocation.latitude},${widget.pickupLocation.longitude}';

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$origin'
          '&destination=$destination'
          '&key=$key'
          '&mode=driving',
    );

    debugPrint('🗺️ [POLYLINE] Fetching route: $origin → $destination');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('⚠️ [POLYLINE] HTTP ${response.statusCode} — fallback');
        _drawStraightLine();
        return;
      }

      final data   = json.decode(response.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'UNKNOWN';

      if (status != 'OK') {
        debugPrint('⚠️ [POLYLINE] Directions API status: $status — fallback');
        _drawStraightLine();
        return;
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        debugPrint('⚠️ [POLYLINE] No routes — fallback');
        _drawStraightLine();
        return;
      }

      final encoded =
          routes[0]['overview_polyline']['points'] as String? ?? '';
      if (encoded.isEmpty) {
        _drawStraightLine();
        return;
      }

      final points = _decodePolyline(encoded);
      debugPrint('✅ [POLYLINE] ${points.length} points decoded');

      _lastPolylineOrigin = _animatedDriverLocation;
      _applyPolyline(points);

    } catch (e) {
      debugPrint('❌ [POLYLINE] Exception: $e — fallback to straight line');
      _drawStraightLine();
    }
  }

  void _drawStraightLine() {
    if (_animatedDriverLocation == null) return;
    debugPrint('🗺️ [POLYLINE] Drawing straight line fallback');
    _applyPolyline([_animatedDriverLocation!, widget.pickupLocation]);
  }

  void _applyPolyline(List<LatLng> points) {
    _polylines.clear();
    _polylines.add(Polyline(
      polylineId: const PolylineId('driver_route'),
      points: points,
      color: AppColors.primaryGold,
      width: 5,
      startCap: Cap.roundCap,
      endCap:   Cap.roundCap,
      jointType: JointType.round,
    ));
    if (mounted) setState(() {});
  }

  /// Standard Google polyline decoder.
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

      shift = 0; r = 0;
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

  // ═══════════════════════════════════════════════════════════════════════════
  // MAP
  // ═══════════════════════════════════════════════════════════════════════════

  void _fitMapToRoute() {
    if (_mapController == null || _animatedDriverLocation == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        math.min(_animatedDriverLocation!.latitude,
            widget.pickupLocation.latitude) - 0.002,
        math.min(_animatedDriverLocation!.longitude,
            widget.pickupLocation.longitude) - 0.002,
      ),
      northeast: LatLng(
        math.max(_animatedDriverLocation!.latitude,
            widget.pickupLocation.latitude) + 0.002,
        math.max(_animatedDriverLocation!.longitude,
            widget.pickupLocation.longitude) + 0.002,
      ),
    );
    _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _recenterMap() {
    setState(() => _isFollowingDriver = true);
    _fitMapToRoute();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRIP STATUS
  // ═══════════════════════════════════════════════════════════════════════════

  void _checkTripStatus(TripProvider tp) {
    if (_hasNavigated || !mounted) return;

    // Update driver location from provider
    if (tp.driverLocation != null) {
      final newLat = tp.driverLocation!['lat'];
      final newLng = tp.driverLocation!['lng'];
      if (newLat != null && newLng != null) {
        final newLoc = LatLng(_toDouble(newLat), _toDouble(newLng));
        final same   = _currentDriverLocation != null &&
            _currentDriverLocation!.latitude  == newLoc.latitude &&
            _currentDriverLocation!.longitude == newLoc.longitude;
        if (!same) _animateDriverTo(newLoc);
      }
    }

    switch (tp.status) {
      case TripStatus.arrivedPickup:
        if (!_driverArrivedShown) {
          _driverArrivedShown = true;
          HapticFeedback.mediumImpact();
          debugPrint('📍 [ARRIVING] Driver arrived at pickup');
          setState(() => _driverHasArrived = true);
          _pulseCtrl?.stop();
          _arrivedBannerCtrl?.forward();
          _freeCancelTimer?.cancel();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _sheetCtrl.isAttached) {
              _sheetCtrl.animateTo(
                _kBottomSheetMidFrac,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              );
            }
          });
        }
        break;

      case TripStatus.inProgress:
        debugPrint('🚀 [ARRIVING] Trip started');
        _navigateToTripInProgress();
        break;

      case TripStatus.canceled:
        debugPrint('⚠️ [ARRIVING] Trip canceled');
        _showCanceledDialog(tp.errorMessage ?? 'Your trip was canceled');
        break;

      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SMOOTH CAR ANIMATION
  // ═══════════════════════════════════════════════════════════════════════════

  void _animateDriverTo(LatLng newLoc) {
    final from = _currentDriverLocation ?? newLoc;
    _driverBearing = _calcBearing(from, newLoc);

    _carAnimCtrl?.reset();
    final anim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(_carAnimCtrl!);

    anim.addListener(() {
      if (!mounted) return;
      final t   = anim.value;
      final lat = from.latitude  + (newLoc.latitude  - from.latitude)  * t;
      final lng = from.longitude + (newLoc.longitude - from.longitude) * t;
      _animatedDriverLocation = LatLng(lat, lng);
      _rebuildMarkers();
      _calcDistETA();
      if (_isFollowingDriver) {
        _mapController?.animateCamera(
            CameraUpdate.newLatLng(_animatedDriverLocation!));
      }
    });

    anim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentDriverLocation = newLoc;
        // Re-fetch road polyline if driver moved far enough
        _fetchRoutePolyline();
      }
    });

    _carAnimCtrl!.forward();
  }

  void _calcDistETA() {
    if (_animatedDriverLocation == null) return;
    final d = _haversineKm(
      _animatedDriverLocation!.latitude,
      _animatedDriverLocation!.longitude,
      widget.pickupLocation.latitude,
      widget.pickupLocation.longitude,
    );
    if (mounted) {
      setState(() {
        _distance = d;
        final mins = (d / 30.0 * 60).ceil();
        _eta = d < 0.05 ? 'Arriving' : (mins < 1 ? '< 1 min' : '$mins min');
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  void _navigateToTripInProgress() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TripInProgressScreen(
          tripId:          widget.tripId,
          driver:          widget.driver,
          pickupLocation:  widget.pickupLocation,
          dropoffLocation: widget.dropoffLocation,
          pickupAddress:   widget.pickupAddress,
          dropoffAddress:  widget.dropoffAddress,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _callDriver() async {
    final phone =
    _getField(widget.driver, ['phone', 'phone_e164', 'phoneNumber']);
    if (phone == null || phone.isEmpty) {
      _snack('Driver phone not available', isError: true);
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _snack('Cannot open dialer', isError: true);
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          tripId:          widget.tripId,
          otherUserName:   _getDriverName(),
          otherUserAvatar: _getField(widget.driver, ['avatar', 'avatar_url']),
        ),
      ),
    );
  }

  void _shareTrip() {
    final name  = _getDriverName();
    final plate = _vehicleInfo['plate'] ?? 'N/A';
    _snack('Trip shared: $name · $plate · ETA $_eta');
  }

  Future<void> _cancelTrip() async {
    final feeText = _freeCancelExpired
        ? 'A cancellation fee may apply.'
        : 'Free cancellation. No fee.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Trip?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The driver is on their way.',
                style: TextStyle(fontSize: 15, color: Colors.black54)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _freeCancelExpired
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _freeCancelExpired
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _freeCancelExpired
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle,
                    size: 18,
                    color: _freeCancelExpired
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feeText,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _freeCancelExpired
                              ? Colors.red.shade700
                              : Colors.green.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Trip',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
      _hasNavigated = true;
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.black87,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _getDriverName() {
    final first =
        _getField(widget.driver, ['firstName', 'first_name']) ?? '';
    final last =
        _getField(widget.driver, ['lastName', 'last_name']) ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : 'Driver';
  }

  String? _getDriverAvatarUrl() => _getField(widget.driver, [
    'avatar', 'avatar_url', 'avatarUrl',
    'profile_photo', 'profilePhoto', 'photo', 'picture',
  ]);

  String? _getField(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }

  Map<String, String> get _vehicleInfo {
    final v   = widget.driver['vehicle'] as Map<String, dynamic>?;
    final src = v ?? widget.driver;
    return {
      'type':      _getField(src, ['type', 'vehicleType']) ?? 'Standard',
      'plate':     _getField(src, ['plate', 'vehiclePlate', 'license_plate']) ?? 'N/A',
      'makeModel': _getField(src, ['makeModel', 'vehicle_make_model', 'make_model']) ?? 'Vehicle',
      'color':     _getField(src, ['color', 'vehicleColor', 'vehicle_color']) ?? 'Unknown',
      'year':      _getField(src, ['year', 'vehicleYear', 'vehicle_year']) ?? '',
      'photo':     _getField(src, ['photo', 'vehicle_photo_url', 'vehiclePhoto']) ?? '',
    };
  }

  String get _driverRating =>
      _getField(widget.driver, ['rating', 'rating_avg', 'ratingAvg']) ?? '4.8';

  String get _freeCancelLabel {
    if (_driverHasArrived) return '';
    if (_freeCancelExpired) return 'Free cancel expired';
    final m = _freeCancelSecondsLeft ~/ 60;
    final s = _freeCancelSecondsLeft % 60;
    return 'Free cancel: $m:${s.toString().padLeft(2, '0')}';
  }

  double _calcBearing(LatLng from, LatLng to) {
    final lat1 = _toRad(from.latitude);
    final lat2 = _toRad(to.latitude);
    final dLon = _toRad(to.longitude - from.longitude);
    final y    = math.sin(dLon) * math.cos(lat2);
    final x    = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r    = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a    = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * (math.pi / 180.0);

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int)    return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  Color _colorFromName(String name) {
    const map = {
      'black':  Color(0xFF1a1a1a),
      'white':  Colors.white,
      'silver': Color(0xFFb0b0b0),
      'grey':   Colors.grey,
      'gray':   Colors.grey,
      'red':    Colors.red,
      'blue':   Color(0xFF1565C0),
      'green':  Colors.green,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'brown':  Colors.brown,
      'gold':   AppColors.primaryGold,
      'beige':  Color(0xFFF5F5DC),
      'purple': Colors.purple,
      'pink':   Colors.pink,
    };
    return map[name.toLowerCase()] ?? Colors.grey;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGET HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _driverAvatar({double size = 56, double fontSize = 22}) {
    final url     = _getDriverAvatarUrl();
    final name    = _getDriverName();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';

    Widget fallback = Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryGold,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Text(initial,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
      ),
    );

    if (url == null || url.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size, height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _vehiclePhoto(String url, {double size = 80}) {
    if (url.isEmpty) {
      return Container(
        width: size, height: size * 0.65,
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.directions_car,
            size: size * 0.4, color: Colors.grey.shade400),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size, height: size * 0.65,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size, height: size * 0.65,
          color: Colors.grey.shade100,
          child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          width: size, height: size * 0.65,
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.directions_car,
              size: size * 0.4, color: Colors.grey.shade400),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          // ── MAP ────────────────────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _animatedDriverLocation ?? widget.pickupLocation,
                zoom: 15,
              ),
              markers:   _markers,
              polylines: _polylines,
              myLocationEnabled:       false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled:     false,
              mapToolbarEnabled:       false,
              compassEnabled:          false,
              onCameraMove: (_) {
                if (_isFollowingDriver) {
                  setState(() => _isFollowingDriver = false);
                }
              },
              onMapCreated: (controller) {
                _mapController = controller;
                _rebuildMarkers();
                // Wait for map to settle, then fit bounds + fetch real route
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (!mounted) return;
                  _fitMapToRoute();
                  // Force initial fetch regardless of distance debounce
                  _fetchRoutePolyline(force: true);
                });
              },
            ),
          ),

          // ── TOP STATUS PILL ────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _driverHasArrived
                    ? const _ArrivedPill(key: ValueKey('arrived'))
                    : _EtaPill(
                  key: const ValueKey('eta'),
                  eta: _eta,
                  pulseAnimation:
                  _pulseAnim ?? const AlwaysStoppedAnimation(1.0),
                ),
              ),
            ),
          ),

          // ── RE-CENTER FAB ──────────────────────────────────────────────────
          if (!_isFollowingDriver)
            Positioned(
              bottom: MediaQuery.of(context).size.height *
                  _kBottomSheetMinFrac +
                  16,
              right: 16,
              child: _RecenterFab(onTap: _recenterMap),
            ),

          // ── DRAGGABLE BOTTOM SHEET ─────────────────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: _kBottomSheetMidFrac,
            minChildSize:     _kBottomSheetMinFrac,
            maxChildSize:     _kBottomSheetMaxFrac,
            snap: true,
            snapSizes: const [
              _kBottomSheetMinFrac,
              _kBottomSheetMidFrac,
              _kBottomSheetMaxFrac,
            ],
            builder: (context, scrollCtrl) {
              return SlideTransition(
                position: _slideAnim ??
                    const AlwaysStoppedAnimation(Offset.zero),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),

                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            MediaQuery.of(context).padding.bottom + 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ── PEEK ────────────────────────────────────────
                            _PeekSection(
                              vehicleInfo:      _vehicleInfo,
                              eta:              _eta,
                              distance:         _distance,
                              driverHasArrived: _driverHasArrived,
                            ),

                            const SizedBox(height: 16),

                            // ── ARRIVED BANNER or PICKUP ROW ────────────────
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
                                    opacity: anim,
                                    child: SizeTransition(
                                        sizeFactor: anim, child: child),
                                  ),
                              child: _driverHasArrived
                                  ? _ArrivedCardBanner(
                                key: const ValueKey('banner'),
                                animation: _arrivedBannerAnim ??
                                    const AlwaysStoppedAnimation(1.0),
                              )
                                  : _PickupRow(
                                key: const ValueKey('pickup'),
                                address:  widget.pickupAddress,
                                distance: _distance,
                              ),
                            ),

                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),

                            // ── DRIVER ROW ───────────────────────────────────
                            Row(
                              children: [
                                _driverAvatar(size: 52),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getDriverName(),
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        const Icon(Icons.star,
                                            size: 14,
                                            color: AppColors.primaryGold),
                                        const SizedBox(width: 4),
                                        Text(_driverRating,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87)),
                                      ]),
                                    ],
                                  ),
                                ),
                                _RoundActionBtn(
                                    icon: Icons.call_rounded,
                                    iconColor: Colors.green.shade700,
                                    bg: Colors.green.shade50,
                                    onTap: _callDriver),
                                const SizedBox(width: 8),
                                _RoundActionBtn(
                                    icon: Icons.chat_bubble_rounded,
                                    iconColor: AppColors.primaryGold,
                                    bg: AppColors.primaryGold.withOpacity(0.1),
                                    onTap: _openChat),
                                const SizedBox(width: 8),
                                _RoundActionBtn(
                                    icon: Icons.share_rounded,
                                    iconColor: Colors.blue.shade700,
                                    bg: Colors.blue.shade50,
                                    onTap: _shareTrip),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // ── VEHICLE DETAIL ───────────────────────────────
                            _VehicleDetailCard(
                              vehicleInfo:    _vehicleInfo,
                              colorFromName:  _colorFromName,
                              vehiclePhoto:   _vehiclePhoto,
                            ),

                            const SizedBox(height: 20),

                            // ── CANCEL ───────────────────────────────────────
                            if (!_driverHasArrived) ...[
                              _CancelButton(
                                label:     _freeCancelLabel,
                                isExpired: _freeCancelExpired,
                                onTap:     _cancelTrip,
                              ),
                              const SizedBox(height: 8),
                            ],

                            if (_driverHasArrived)
                              Center(
                                child: Text(
                                  'Please make your way to the pickup point',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500),
                                ),
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
// SUB-WIDGETS  (unchanged from original)
// ═══════════════════════════════════════════════════════════════════════════

class _EtaPill extends StatelessWidget {
  final String eta;
  final Animation<double> pulseAnimation;
  const _EtaPill({super.key, required this.eta, required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (_, child) =>
          Transform.scale(scale: pulseAnimation.value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primaryGold,
                    shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(eta,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Text('away',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ArrivedPill extends StatelessWidget {
  const _ArrivedPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade600,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Driver has arrived!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RecenterFab extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterFab({required this.onTap});

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
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        child: const Icon(Icons.my_location_rounded,
            size: 22, color: Colors.black87),
      ),
    );
  }
}

class _PeekSection extends StatelessWidget {
  final Map<String, String> vehicleInfo;
  final String eta;
  final double distance;
  final bool driverHasArrived;

  const _PeekSection({
    required this.vehicleInfo,
    required this.eta,
    required this.distance,
    required this.driverHasArrived,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driverHasArrived ? '🎉 Driver arrived!' : 'Driver on the way',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black),
              ),
              const SizedBox(height: 2),
              Text(
                driverHasArrived
                    ? 'Head to your pickup point'
                    : '${distance > 0 ? "${distance.toStringAsFixed(1)} km • " : ""}$eta',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8)),
          child: Text(
            vehicleInfo['plate'] ?? 'N/A',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2),
          ),
        ),
      ],
    );
  }
}

class _PickupRow extends StatelessWidget {
  final String address;
  final double distance;
  const _PickupRow({super.key, required this.address, required this.distance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.location_on,
                color: Colors.green.shade700, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pickup location',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Text(
                  address.length > 35
                      ? '${address.substring(0, 35)}…'
                      : address,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (distance > 0) ...[
            const SizedBox(width: 8),
            Column(
              children: [
                Icon(Icons.straighten, size: 12, color: Colors.grey.shade500),
                const SizedBox(height: 2),
                Text('${distance.toStringAsFixed(1)} km',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ArrivedCardBanner extends StatelessWidget {
  final Animation<double> animation;
  const _ArrivedCardBanner(
      {super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) => Transform.scale(
        scale: (0.92 + animation.value * 0.08).clamp(0.0, 1.1),
        child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade500, Colors.green.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.location_on,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🎉 Driver has arrived!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Head to your pickup point',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            _PulsingDot(),
          ],
        ),
      ),
    );
  }
}

class _VehicleDetailCard extends StatelessWidget {
  final Map<String, String> vehicleInfo;
  final Color Function(String) colorFromName;
  final Widget Function(String, {double size}) vehiclePhoto;

  const _VehicleDetailCard({
    required this.vehicleInfo,
    required this.colorFromName,
    required this.vehiclePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final color    = colorFromName(vehicleInfo['color'] ?? '');
    final hasPhoto = (vehicleInfo['photo'] ?? '').isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car,
                  size: 16, color: Colors.black54),
              const SizedBox(width: 8),
              const Text('Your vehicle',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54)),
              const Spacer(),
              Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.grey.shade300, width: 1))),
              const SizedBox(width: 6),
              Text(vehicleInfo['color'] ?? '',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              vehiclePhoto(vehicleInfo['photo'] ?? '',
                  size: hasPhoto ? 100 : 72),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleInfo['makeModel'] ?? 'Vehicle',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black),
                    ),
                    if ((vehicleInfo['year'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(vehicleInfo['year']!,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500)),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: Colors.black, width: 2),
                      ),
                      child: Text(
                        vehicleInfo['plate'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: Colors.black,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final String label;
  final bool isExpired;
  final VoidCallback onTap;

  const _CancelButton(
      {required this.label,
        required this.isExpired,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: isExpired
                      ? Colors.red.shade300
                      : Colors.grey.shade300,
                  width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
            child: Text(
              'Cancel Trip',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isExpired
                      ? Colors.red.shade700
                      : Colors.black87),
            ),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isExpired
                      ? Colors.red.shade600
                      : Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}

class _RoundActionBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final VoidCallback onTap;

  const _RoundActionBtn(
      {required this.icon,
        required this.iconColor,
        required this.bg,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this)
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_a.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.white.withOpacity(_a.value * 0.5),
                blurRadius: 6,
                spreadRadius: 2)
          ],
        ),
      ),
    );
  }
}
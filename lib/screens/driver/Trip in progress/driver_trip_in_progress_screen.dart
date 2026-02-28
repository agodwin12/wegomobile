// lib/screens/driver/trip/driver_trip_in_progress_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wego_v1/providers/trip_provider.dart';
import 'package:wego_v1/utils/app_colors.dart';
import 'package:wego_v1/utils/app_typography.dart';
import '../../../service/chat_service.dart';
import '../../../service/socket_service.dart';
import '../../chat/trip_chat_screen.dart';
import '../trip complete/trip_complete.dart';

class DriverTripInProgressScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> trip;
  final Map<String, dynamic> passenger;

  const DriverTripInProgressScreen({
    Key? key,
    required this.tripId,
    required this.trip,
    required this.passenger,
  }) : super(key: key);

  @override
  State<DriverTripInProgressScreen> createState() =>
      _DriverTripInProgressScreenState();
}

class _DriverTripInProgressScreenState
    extends State<DriverTripInProgressScreen> with TickerProviderStateMixin {

  // ── Map ──────────────────────────────────────────────────────
  GoogleMapController?    _mapController;
  final Set<Marker>       _markers   = {};
  final Set<Polyline>     _polylines = {};

  // ── Animations ───────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late AnimationController _slideController;
  late Animation<double>  _pulseAnimation;
  late Animation<Offset>  _slideAnimation;

  // ── Location ─────────────────────────────────────────────────
  Position?                     _currentPosition;
  Timer?                        _locationTimer;
  StreamSubscription<Position>? _positionStream;

  // ── Route ────────────────────────────────────────────────────
  List<LatLng> _routePoints          = [];
  double       _distanceToDestination = 0.0;
  int          _etaMinutes           = 0;
  double       _currentSpeed         = 0.0;
  bool         _isLoadingRoute       = true;
  double       _tripProgress         = 0.0;
  bool         _routeFetched         = false;

  // ── Locations ────────────────────────────────────────────────
  late LatLng _pickupLocation;
  late LatLng _dropoffLocation;
  late String _pickupAddress;
  late String _dropoffAddress;
  double      _totalTripDistance = 0.0;

  // ── Timing ───────────────────────────────────────────────────
  DateTime? _tripStartTime;
  int       _tripDurationSeconds = 0;
  Timer?    _durationTimer;

  // ── State ────────────────────────────────────────────────────
  bool _hasNavigated      = false;
  bool _isCompleting      = false;
  bool _isNearDestination = false;
  bool _isCanceled        = false;

  // ── Car marker ───────────────────────────────────────────────
  BitmapDescriptor? _carMarkerIcon;

  // ── Provider ─────────────────────────────────────────────────
  TripProvider? _tripProvider;
  VoidCallback? _tripListener;

  // ── API ──────────────────────────────────────────────────────
  String get _gmapsKey   => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  String get _apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';

  // ════════════════════════════════════════════════════════════
  // INIT
  // ════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    debugPrint('🚗 [TRIP-IN-PROGRESS] Init — Trip: ${widget.tripId}');
    _parseLocations();
    _setupAnimations();
    _loadCarMarker();   // ← load custom car icon first
    _setupMarkers();
    _startDurationTimer();
    _initializeLocation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tripProvider = Provider.of<TripProvider>(context, listen: false);
      _tripListener = () => _checkTripStatus(_tripProvider!);
      _tripProvider!.addListener(_tripListener!);
      _checkTripStatus(_tripProvider!);
    });
  }

  // ════════════════════════════════════════════════════════════
  // ✅ CAR MARKER — drawn programmatically (Uber-style top-down car)
  // ════════════════════════════════════════════════════════════

  /// Draws a top-down car icon onto a Canvas and returns it as a
  /// [BitmapDescriptor] for use as a Google Maps marker.
  Future<void> _loadCarMarker() async {
    try {
      // Try loading from assets first (place a car PNG at
      // assets/images/car_marker.png for best results).
      // If not found, fall back to the drawn version.
      final byteData = await rootBundle.load('assets/images/car_marker.png');
      final codec    = await ui.instantiateImageCodec(
        byteData.buffer.asUint8List(),
        targetWidth: 80,
      );
      final frame = await codec.getNextFrame();
      final data  = await frame.image.toByteData(
          format: ui.ImageByteFormat.png);
      if (data != null) {
        _carMarkerIcon =
            BitmapDescriptor.fromBytes(data.buffer.asUint8List());
        debugPrint('✅ Car marker loaded from assets');
        return;
      }
    } catch (_) {
      debugPrint('⚠️  car_marker.png not found — drawing programmatically');
    }
    // Fallback: draw the car icon on a Canvas
    _carMarkerIcon = await _drawCarMarker();
  }

  /// Draws a simple Uber-style top-down car using Canvas and returns
  /// a [BitmapDescriptor].
  Future<BitmapDescriptor> _drawCarMarker() async {
    const double size   = 120.0;
    const double cx     = size / 2;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder,
        Rect.fromPoints(Offset.zero, const Offset(size, size)));

    // ── Shadow ───────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color         = Colors.black.withOpacity(0.25)
      ..maskFilter    = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(cx, size * 0.72),
          width: size * 0.55,
          height: size * 0.18),
      shadowPaint,
    );

    // ── Body ─────────────────────────────────────────────────
    final bodyPaint = Paint()..color = const Color(0xFF1A1A1A); // dark body
    final bodyRect  = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: const Offset(cx, size * 0.5),
          width:  size * 0.46,
          height: size * 0.72),
      const Radius.circular(18),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // ── Gold accent stripe (WEGO brand) ──────────────────────
    final accentPaint = Paint()..color = const Color(0xFFFFDC71);
    canvas.drawRect(
      Rect.fromCenter(
          center: const Offset(cx, size * 0.5),
          width:  size * 0.46,
          height: size * 0.06),
      accentPaint,
    );

    // ── Windscreen (front) ───────────────────────────────────
    final glassPaint = Paint()..color = const Color(0xFF90CAF9).withOpacity(0.85);
    final windscreenPath = Path()
      ..moveTo(cx - size * 0.16, size * 0.22)
      ..lineTo(cx + size * 0.16, size * 0.22)
      ..lineTo(cx + size * 0.13, size * 0.33)
      ..lineTo(cx - size * 0.13, size * 0.33)
      ..close();
    canvas.drawPath(windscreenPath, glassPaint);

    // ── Rear window ──────────────────────────────────────────
    final rearPath = Path()
      ..moveTo(cx - size * 0.13, size * 0.65)
      ..lineTo(cx + size * 0.13, size * 0.65)
      ..lineTo(cx + size * 0.16, size * 0.76)
      ..lineTo(cx - size * 0.16, size * 0.76)
      ..close();
    canvas.drawPath(rearPath, glassPaint);

    // ── Headlights ───────────────────────────────────────────
    final headlightPaint = Paint()..color = Colors.yellow.shade200;
    // Left
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx - size * 0.15, size * 0.14),
            width: size * 0.10, height: size * 0.07),
        const Radius.circular(4),
      ),
      headlightPaint,
    );
    // Right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx + size * 0.15, size * 0.14),
            width: size * 0.10, height: size * 0.07),
        const Radius.circular(4),
      ),
      headlightPaint,
    );

    // ── Tail lights ──────────────────────────────────────────
    final tailPaint = Paint()..color = Colors.red.shade400;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx - size * 0.15, size * 0.86),
            width: size * 0.10, height: size * 0.06),
        const Radius.circular(3),
      ),
      tailPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx + size * 0.15, size * 0.86),
            width: size * 0.10, height: size * 0.06),
        const Radius.circular(3),
      ),
      tailPaint,
    );

    // ── Wheels ───────────────────────────────────────────────
    final wheelPaint = Paint()..color = const Color(0xFF333333);
    final wheelPositions = [
      Offset(cx - size * 0.25, size * 0.28),
      Offset(cx + size * 0.25, size * 0.28),
      Offset(cx - size * 0.25, size * 0.72),
      Offset(cx + size * 0.25, size * 0.72),
    ];
    for (final pos in wheelPositions) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: pos,
              width: size * 0.12,
              height: size * 0.16),
          const Radius.circular(4),
        ),
        wheelPaint,
      );
    }

    // ── Finish ───────────────────────────────────────────────
    final picture = recorder.endRecording();
    final img     = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(
        byteData!.buffer.asUint8List());
  }

  // ════════════════════════════════════════════════════════════
  // PARSE LOCATIONS
  // ════════════════════════════════════════════════════════════

  void _parseLocations() {
    final pickup  = widget.trip['pickup']  ?? widget.trip['pickup_location'];
    final dropoff = widget.trip['dropoff'] ?? widget.trip['dropoff_location'];

    if (pickup != null) {
      _pickupLocation = LatLng(
        double.tryParse(pickup['lat']?.toString()  ?? pickup['latitude']?.toString()  ?? '0') ?? 0,
        double.tryParse(pickup['lng']?.toString()  ?? pickup['longitude']?.toString() ?? '0') ?? 0,
      );
      _pickupAddress = pickup['address']?.toString()
          ?? widget.trip['pickupAddress']?.toString()
          ?? 'Pickup Location';
    } else {
      _pickupLocation = LatLng(
        double.tryParse(widget.trip['pickupLat']?.toString() ?? '0') ?? 0,
        double.tryParse(widget.trip['pickupLng']?.toString() ?? '0') ?? 0,
      );
      _pickupAddress = widget.trip['pickupAddress']?.toString() ?? 'Pickup Location';
    }

    if (dropoff != null) {
      _dropoffLocation = LatLng(
        double.tryParse(dropoff['lat']?.toString() ?? dropoff['latitude']?.toString()  ?? '0') ?? 0,
        double.tryParse(dropoff['lng']?.toString() ?? dropoff['longitude']?.toString() ?? '0') ?? 0,
      );
      _dropoffAddress = dropoff['address']?.toString()
          ?? widget.trip['dropoffAddress']?.toString()
          ?? 'Destination';
    } else {
      _dropoffLocation = LatLng(
        double.tryParse(widget.trip['dropoffLat']?.toString() ?? '0') ?? 0,
        double.tryParse(widget.trip['dropoffLng']?.toString() ?? '0') ?? 0,
      );
      _dropoffAddress = widget.trip['dropoffAddress']?.toString() ?? 'Destination';
    }

    _totalTripDistance = Geolocator.distanceBetween(
      _pickupLocation.latitude,  _pickupLocation.longitude,
      _dropoffLocation.latitude, _dropoffLocation.longitude,
    );

    _tripStartTime = DateTime.now();
  }

  // ════════════════════════════════════════════════════════════
  // ANIMATIONS
  // ════════════════════════════════════════════════════════════

  void _setupAnimations() {
    _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);
    _pulseAnimation  = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _pulseController.repeat(reverse: true);

    _progressController = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);

    _slideController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _slideAnimation  = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));
    _slideController.forward();
  }

  // ════════════════════════════════════════════════════════════
  // MARKERS
  // ════════════════════════════════════════════════════════════

  void _setupMarkers() {
    // Faded pickup marker
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: _pickupLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      alpha: 0.4,
      infoWindow: InfoWindow(title: 'Pickup', snippet: _pickupAddress),
    ));
    // Destination marker
    _markers.add(Marker(
      markerId: const MarkerId('dropoff'),
      position: _dropoffLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: 'Destination', snippet: _dropoffAddress),
    ));
    if (mounted) setState(() {});
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _tripDurationSeconds++);
    });
  }

  // ════════════════════════════════════════════════════════════
  // LOCATION
  // ════════════════════════════════════════════════════════════

  Future<void> _initializeLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _updateDriverMarker();
      _calculateDistanceAndProgress();
      _startLocationTracking();
      await _fetchRoute();
      if (_mapController != null) _fitMapToRoute();
    } catch (e) {
      _showSnackBar('Unable to get location. Check GPS.', isError: true);
      await _fetchRoute();
    }
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      if (!mounted) return;
      _currentPosition = pos;
      _currentSpeed    = pos.speed * 3.6;
      _updateDriverMarker();
      _calculateDistanceAndProgress();
      _emitLocationUpdate();

      if (_distanceToDestination < 100 && !_isNearDestination) {
        _isNearDestination = true;
        _showNearDestinationDialog();
      }
    });

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      try {
        final pos = await Geolocator.getCurrentPosition();
        if (mounted) {
          _currentPosition = pos;
          _updateDriverMarker();
          _calculateDistanceAndProgress();
          _emitLocationUpdate();
        }
      } catch (_) {}
    });
  }

  // ════════════════════════════════════════════════════════════
  // ✅ UPDATE DRIVER MARKER — uses custom car icon
  // ════════════════════════════════════════════════════════════

  void _updateDriverMarker() {
    if (_currentPosition == null) return;
    final driverLatLng =
    LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: driverLatLng,
      // Use the drawn car icon; fall back to a styled default if not ready
      icon: _carMarkerIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      rotation: _currentPosition!.heading,
      anchor: const Offset(0.5, 0.5),
      flat: true,           // ← makes the icon rotate with the map heading
      zIndex: 10,
      infoWindow: const InfoWindow(title: 'You (Driver)'),
    ));

    if (mounted) setState(() {});

    _mapController?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target:  driverLatLng,
        zoom:    16,
        bearing: _currentPosition!.heading,
        tilt:    45,
      ),
    ));
  }

  void _emitLocationUpdate() {
    if (_currentPosition == null) return;
    SocketService.instance.socket?.emit('driver:location', {
      'tripId':    widget.tripId,
      'lat':       _currentPosition!.latitude,
      'lng':       _currentPosition!.longitude,
      'heading':   _currentPosition!.heading,
      'speed':     _currentSpeed,
      'progress':  _tripProgress,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _calculateDistanceAndProgress() {
    if (_currentPosition == null) return;
    _distanceToDestination = Geolocator.distanceBetween(
      _currentPosition!.latitude,  _currentPosition!.longitude,
      _dropoffLocation.latitude,   _dropoffLocation.longitude,
    );
    final traveled =
    (_totalTripDistance - _distanceToDestination).clamp(0.0, _totalTripDistance);
    _tripProgress = _totalTripDistance > 0
        ? (traveled / _totalTripDistance).clamp(0.0, 1.0)
        : 0.0;
    _progressController.animateTo(_tripProgress,
        duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    final distKm   = _distanceToDestination / 1000;
    final avgSpeed = _currentSpeed > 5 ? _currentSpeed : 30.0;
    _etaMinutes    = ((distKm / avgSpeed) * 60).ceil();
    if (mounted) setState(() {});
  }

  // ════════════════════════════════════════════════════════════
  // DIRECTIONS API
  // ════════════════════════════════════════════════════════════

  Future<void> _fetchRoute() async {
    if (_routeFetched) return;
    _routeFetched = true;

    final origin = _currentPosition != null
        ? '${_currentPosition!.latitude},${_currentPosition!.longitude}'
        : '${_pickupLocation.latitude},${_pickupLocation.longitude}';
    final destination =
        '${_dropoffLocation.latitude},${_dropoffLocation.longitude}';

    try {
      debugPrint('🗺️ Fetching Directions API route...');
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=$origin'
            '&destination=$destination'
            '&key=$_gmapsKey'
            '&mode=driving'
            '&alternatives=false',
      );

      final response =
      await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            (data['routes'] as List).isNotEmpty) {
          final route            = data['routes'][0];
          final leg              = route['legs'][0];
          final encodedPolyline  =
          route['overview_polyline']['points'] as String;

          _routePoints           = _decodePolyline(encodedPolyline);
          _distanceToDestination =
              (leg['distance']['value'] as num).toDouble();
          _etaMinutes = ((leg['duration']['value'] as num) / 60).ceil();

          _polylines
            ..clear()
            ..add(Polyline(
              polylineId: const PolylineId('route'),
              points:    _routePoints,
              color:     AppColors.primaryGold,
              width:     5,
              startCap:  Cap.roundCap,
              endCap:    Cap.roundCap,
              jointType: JointType.round,
            ));

          if (mounted) {
            setState(() => _isLoadingRoute = false);
            _fitMapToRoute();
          }
          return;
        }
        throw Exception('Directions API: ${data['status']}');
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Route fetch error: $e — falling back to straight line');
      _polylines
        ..clear()
        ..add(Polyline(
          polylineId: const PolylineId('route'),
          points: [
            if (_currentPosition != null)
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            _dropoffLocation,
          ],
          color:    AppColors.primaryGold,
          width:    4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ));
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _refreshRoute() async {
    _routeFetched = false;
    await _fetchRoute();
  }

  List<LatLng> _decodePolyline(String encoded) {
    final pts  = <LatLng>[];
    int index  = 0;
    final len  = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift  += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift  += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      pts.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return pts;
  }

  void _fitMapToRoute() {
    if (_mapController == null) return;
    if (_routePoints.length >= 2) {
      double minLat =  90, maxLat = -90;
      double minLng = 180, maxLng = -180;
      for (final p in _routePoints) {
        if (p.latitude  < minLat) minLat = p.latitude;
        if (p.latitude  > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ));
      return;
    }
    if (_currentPosition == null) return;
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(
          math.min(_currentPosition!.latitude,  _dropoffLocation.latitude),
          math.min(_currentPosition!.longitude, _dropoffLocation.longitude),
        ),
        northeast: LatLng(
          math.max(_currentPosition!.latitude,  _dropoffLocation.latitude),
          math.max(_currentPosition!.longitude, _dropoffLocation.longitude),
        ),
      ),
      80,
    ));
  }

  // ════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════

  void _showNearDestinationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.flag_rounded,
                color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Almost There!',
              style:
              TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
            'You\'re within 100 meters of the destination. Have you arrived?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not Yet')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _completeTrip();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Yes, Complete Trip',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTrip() async {
    if (_hasNavigated || _isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      final token    = await _getAccessToken();
      final response = await http
          .post(
        Uri.parse('$_apiBaseUrl/driver/trips/${widget.tripId}/complete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'final_fare':        widget.trip['fare_estimate'] ?? widget.trip['fareEstimate'],
          'distance_traveled': _totalTripDistance.toInt(),
          'duration_seconds':  _tripDurationSeconds,
        }),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        SocketService.instance.socket?.emit('trip:completed', {
          'tripId':    widget.tripId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _hasNavigated = true;
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DriverTripCompleteScreen(
              tripId:       widget.tripId,
              trip:         responseData['data']['trip'] ?? widget.trip,
              passenger:    widget.passenger,
              tripDuration: _tripDurationSeconds,
            ),
          ),
        );
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCompleting = false;
          _hasNavigated = false;
        });
        _showSnackBar('Failed to complete trip. Try again.', isError: true);
      }
    }
  }

  Future<void> _callPassenger() async {
    final phone = widget.passenger['phone']?.toString()
        ?? widget.passenger['phone_e164']?.toString()
        ?? '';
    if (phone.isEmpty) {
      _showSnackBar('Phone number not available', isError: true);
      return;
    }
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnackBar('Cannot open dialer', isError: true);
      }
    } catch (_) {
      _showSnackBar('Failed to call', isError: true);
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: Provider.of<ChatService>(context, listen: false),
          child: ChatScreen(
            tripId:          widget.tripId,
            otherUserName:   _passengerName,
            otherUserAvatar: widget.passenger['avatar_url']
                ?? widget.passenger['avatar'],
          ),
        ),
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.warning_rounded,
                color: AppColors.error, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Emergency',
              style:
              TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: const Text('Do you need emergency assistance?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSnackBar('Emergency services notified', isError: false);
            },
            style:
            ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Call Emergency',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _checkTripStatus(TripProvider provider) {
    if (_hasNavigated || !mounted) return;
    if (provider.status == TripStatus.canceled) {
      _handleCancellation(provider.errorMessage ?? 'Trip canceled');
    }
  }

  void _handleCancellation(String reason) {
    if (_isCanceled || _hasNavigated) return;
    _isCanceled   = true;
    _hasNavigated = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.cancel_rounded,
                color: AppColors.error, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Trip Canceled',
              style:
              TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Text(reason),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlack,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Return Home',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  Future<String> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? '';
  }

  String get _passengerName {
    final direct = widget.passenger['name']?.toString() ?? '';
    if (direct.isNotEmpty) return direct;
    final first  = widget.passenger['firstName']?.toString()
        ?? widget.passenger['first_name']?.toString()  ?? '';
    final last   = widget.passenger['lastName']?.toString()
        ?? widget.passenger['last_name']?.toString()   ?? '';
    final full   = '$first $last'.trim();
    return full.isNotEmpty ? full : 'Passenger';
  }

  /// Returns the first character of the passenger's name, uppercased.
  /// Falls back to 'P' if the name is empty.
  String get _passengerInitial {
    final name = _passengerName;
    if (name.isEmpty) return 'P';
    // Skip leading spaces just in case
    final trimmed = name.trimLeft();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'P';
  }

  String? get _passengerAvatarUrl =>
      widget.passenger['avatar_url']?.toString()
          ?? widget.passenger['avatarUrl']?.toString()
          ?? widget.passenger['profile_photo']?.toString()
          ?? widget.passenger['photo']?.toString();

  String? get _passengerRating {
    final r = widget.passenger['rating_avg']
        ?? widget.passenger['ratingAvg']
        ?? widget.passenger['rating'];
    if (r == null) return null;
    final d = double.tryParse(r.toString());
    if (d == null || d == 0) return null;
    return d.toStringAsFixed(1);
  }

  String _formatDistance(double meters) =>
      meters < 1000
          ? '${meters.toInt()} m'
          : '${(meters / 1000).toStringAsFixed(1)} km';

  String _formatETA(int minutes) {
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) {
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    final h  = m ~/ 60;
    final rm = m % 60;
    return '$h:${rm.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: AppTypography.bodySmall.copyWith(
              color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior:        SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ════════════════════════════════════════════════════════════
  // DISPOSE
  // ════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _slideController.dispose();
    _mapController?.dispose();
    _locationTimer?.cancel();
    _durationTimer?.cancel();
    _positionStream?.cancel();
    if (_tripProvider != null && _tripListener != null) {
      _tripProvider!.removeListener(_tripListener!);
    }
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // ── MAP ──────────────────────────────────────────
            GoogleMap(
              initialCameraPosition:
              CameraPosition(target: _dropoffLocation, zoom: 15),
              markers:                _markers,
              polylines:              _polylines,
              myLocationEnabled:      false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled:    false,
              mapToolbarEnabled:      false,
              compassEnabled:         true,
              onMapCreated: (c) {
                _mapController = c;
                if (_currentPosition != null) _fitMapToRoute();
              },
            ),

            // ── TOP SCRIM ─────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0, height: 200,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.88),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── TOP BAR ───────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(children: [
                  // Emergency button
                  GestureDetector(
                    onTap: _showEmergencyDialog,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color:  AppColors.error.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Icon(Icons.warning_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  // Pulsing trip timer pill
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                                color:  AppColors.success.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_car_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(_tripDurationSeconds),
                              style: AppTypography.caption.copyWith(
                                  color:      Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),

            // ── BOTTOM SHEET ──────────────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child:    _buildBottomSheet(),
              ),
            ),

            // ── ROUTE LOADING OVERLAY ─────────────────────────
            if (_isLoadingRoute)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                            AppColors.primaryGold)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // BOTTOM SHEET
  // ════════════════════════════════════════════════════════════

  Widget _buildBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color:  AppColors.shadowMedium,
              blurRadius: 24,
              offset: const Offset(0, -8))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin:    const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color:        AppColors.borderLight,
                borderRadius: BorderRadius.circular(2)),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 18, 20,
                MediaQuery.of(context).padding.bottom + 20),
            child: Column(
              children: [
                // ── PROGRESS BAR ───────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Trip Progress',
                        style: AppTypography.titleMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      '${(_tripProgress * 100).toStringAsFixed(0)}%',
                      style: AppTypography.titleMedium.copyWith(
                          color:      AppColors.primaryGold,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value:           _tripProgress,
                    minHeight:       8,
                    backgroundColor: AppColors.borderLight,
                    valueColor:      const AlwaysStoppedAnimation(
                        AppColors.primaryGold),
                  ),
                ),

                const SizedBox(height: 16),

                // ── ETA / DISTANCE TILES ────────────────────────
                Row(children: [
                  Expanded(child: _InfoTile(
                    icon:   Icons.access_time_rounded,
                    label:  'ETA',
                    value:  _formatETA(_etaMinutes),
                    accent: AppColors.info,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _InfoTile(
                    icon:   Icons.straighten_rounded,
                    label:  'Remaining',
                    value:  _formatDistance(_distanceToDestination),
                    accent: AppColors.warning,
                  )),
                ]),

                const SizedBox(height: 16),

                // ── PASSENGER CARD ──────────────────────────────
                _buildPassengerCard(),

                const SizedBox(height: 14),

                // ── DESTINATION ROW ─────────────────────────────
                _buildDestinationRow(),

                const SizedBox(height: 20),

                // ── COMPLETE BUTTON ─────────────────────────────
                Container(
                  width: double.infinity,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient:     AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color:  AppColors.primaryGold.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isCompleting ? null : _completeTrip,
                    icon: _isCompleting
                        ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(
                                Colors.black)))
                        : const Icon(Icons.check_circle_rounded,
                        color: Colors.black, size: 22),
                    label: Text(
                      _isCompleting ? 'Completing…' : 'Complete Trip',
                      style: const TextStyle(
                          fontSize:   17,
                          fontWeight: FontWeight.w800,
                          color:      Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor:     Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // ✅ PASSENGER CARD — photo with first-letter fallback
  // ════════════════════════════════════════════════════════════

  Widget _buildPassengerCard() {
    final name      = _passengerName;
    final avatarUrl = _passengerAvatarUrl;
    final rating    = _passengerRating;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: AppColors.borderLight),
      ),
      child: Row(children: [
        // ── Avatar ──────────────────────────────────────────
        _PassengerAvatar(
          initial:   _passengerInitial,
          avatarUrl: avatarUrl,
          size:      50,
        ),
        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color:      AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              if (rating != null)
                Row(children: [
                  const Icon(Icons.star_rounded,
                      size: 14, color: AppColors.primaryGold),
                  const SizedBox(width: 3),
                  Text(rating,
                      style: AppTypography.labelSmall.copyWith(
                          color:      AppColors.textPrimary,
                          fontWeight: FontWeight.w700)),
                ])
              else
                Text('Your passenger',
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary)),
            ],
          ),
        ),

        // Call button
        _ActionBtn(
          icon:      Icons.call_rounded,
          iconColor: AppColors.success,
          bgColor:   AppColors.successLight,
          onTap:     _callPassenger,
        ),
        const SizedBox(width: 8),
        // Chat button
        _ActionBtn(
          icon:      Icons.chat_bubble_rounded,
          iconColor: AppColors.primaryGold,
          bgColor:   AppColors.primaryGold.withOpacity(0.12),
          onTap:     _openChat,
        ),
      ]),
    );
  }

  // ── Destination row ──────────────────────────────────────────
  Widget _buildDestinationRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color:        AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.borderLight),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color:        AppColors.errorLight,
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.flag_rounded,
              color: AppColors.error, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Destination',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary)),
              const SizedBox(height: 3),
              Text(
                _dropoffAddress,
                style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ✅ PASSENGER AVATAR WIDGET
//    Shows the network photo when available.
//    Falls back to a gold circle with the passenger's first letter.
// ════════════════════════════════════════════════════════════════

class _PassengerAvatar extends StatelessWidget {
  final String  initial;
  final String? avatarUrl;
  final double  size;

  const _PassengerAvatar({
    required this.initial,
    required this.avatarUrl,
    this.size = 50,
  });

  /// Whether the URL is non-empty and looks like a real HTTP(S) URL.
  bool get _hasValidPhoto {
    if (avatarUrl == null) return false;
    final trimmed = avatarUrl!.trim();
    return trimmed.isNotEmpty &&
        (trimmed.startsWith('http://') || trimmed.startsWith('https://'));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.primaryGold.withOpacity(0.5), width: 2),
      ),
      child: ClipOval(
        child: _hasValidPhoto
            ? CachedNetworkImage(
          imageUrl:    avatarUrl!,
          width:       size,
          height:      size,
          fit:         BoxFit.cover,
          // Show initial while loading
          placeholder: (_, __) =>
              _AvatarFallback(initial: initial, size: size),
          // Show initial on any error
          errorWidget: (_, __, ___) =>
              _AvatarFallback(initial: initial, size: size),
        )
        // No valid URL — show initial immediately
            : _AvatarFallback(initial: initial, size: size),
      ),
    );
  }
}

// ── Fallback: gold circle with first letter ──────────────────────
class _AvatarFallback extends StatelessWidget {
  final String initial;
  final double size;

  const _AvatarFallback({required this.initial, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:     size,
      height:    size,
      color:     AppColors.primaryGold,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize:   size * 0.42,
          fontWeight: FontWeight.w800,
          color:      Colors.black,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// INFO TILE
// ════════════════════════════════════════════════════════════════

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    accent;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color:        accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: accent.withOpacity(0.25), width: 1.5),
      ),
      child: Column(children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(height: 8),
        Text(value,
            style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w800,
                color:      AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ACTION BUTTON
// ════════════════════════════════════════════════════════════════

class _ActionBtn extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final Color        bgColor;
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
        width:  42,
        height: 42,
        decoration: BoxDecoration(
            color:        bgColor,
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}
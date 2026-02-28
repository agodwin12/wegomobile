// lib/screens/driver/en_route_screen/driver_en_route_screen.dart

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
import 'package:wego_v1/main.dart';
import 'package:wego_v1/utils/app_colors.dart';
import 'package:wego_v1/utils/app_typography.dart';
import '../../../service/chat_service.dart';
import '../../chat/trip_chat_screen.dart';
import '../arrived_screen/driver_arrived.dart';

class DriverEnRouteScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> trip;
  final Map<String, dynamic> passenger;

  const DriverEnRouteScreen({
    Key? key,
    required this.tripId,
    required this.trip,
    required this.passenger,
  }) : super(key: key);

  @override
  State<DriverEnRouteScreen> createState() => _DriverEnRouteScreenState();
}

class _DriverEnRouteScreenState extends State<DriverEnRouteScreen>
    with TickerProviderStateMixin {

  // ── Map ──────────────────────────────────────────────────────
  GoogleMapController?  _mapController;
  final Set<Marker>     _markers   = {};
  final Set<Polyline>   _polylines = {};

  // ── Animations ───────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double>   _pulseAnimation;
  late Animation<Offset>   _slideAnimation;

  // ── Location ─────────────────────────────────────────────────
  Position?           _currentPosition;
  Timer?              _locationTimer;
  StreamSubscription? _positionStream;

  // ── Route ────────────────────────────────────────────────────
  List<LatLng> _routePoints      = [];
  double       _distanceToPickup = 0.0; // metres
  int          _etaMinutes       = 0;
  double       _currentSpeed     = 0.0; // km/h
  bool         _isLoadingRoute   = true;

  // ── Locations ────────────────────────────────────────────────
  late LatLng _pickupLocation;
  late LatLng _dropoffLocation;
  late String _pickupAddress;
  late String _dropoffAddress;

  // ── State ────────────────────────────────────────────────────
  bool _hasNavigated = false;
  bool _isArriving   = false;

  // ── Car marker ───────────────────────────────────────────────
  BitmapDescriptor? _carMarkerIcon;

  String get _gmapsKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // ════════════════════════════════════════════════════════════
  // INIT
  // ════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    debugPrint('🚗 [DRIVER-EN-ROUTE] Init — Trip: ${widget.tripId}');
    _parseLocations();
    _setupAnimations();
    _loadCarMarker();
    _setupMarkers();
    _initializeLocation();
    _fetchRoute();
  }

  // ════════════════════════════════════════════════════════════
  // ✅ CAR MARKER — drawn programmatically (Uber-style top-down car)
  // ════════════════════════════════════════════════════════════

  Future<void> _loadCarMarker() async {
    try {
      final byteData =
      await rootBundle.load('assets/images/car_marker.png');
      final codec = await ui.instantiateImageCodec(
          byteData.buffer.asUint8List(), targetWidth: 80);
      final frame    = await codec.getNextFrame();
      final data     =
      await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data != null) {
        _carMarkerIcon =
            BitmapDescriptor.fromBytes(data.buffer.asUint8List());
        debugPrint('✅ Car marker loaded from assets');
        return;
      }
    } catch (_) {
      debugPrint('⚠️  car_marker.png not found — drawing programmatically');
    }
    _carMarkerIcon = await _drawCarMarker();
  }

  Future<BitmapDescriptor> _drawCarMarker() async {
    const double size = 120.0;
    const double cx   = size / 2;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder,
        Rect.fromPoints(Offset.zero, const Offset(size, size)));

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(cx, size * 0.72),
          width:  size * 0.55,
          height: size * 0.18),
      Paint()
        ..color      = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: const Offset(cx, size * 0.5),
            width:  size * 0.46,
            height: size * 0.72),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xFF1A1A1A),
    );

    // Gold WEGO accent stripe
    canvas.drawRect(
      Rect.fromCenter(
          center: const Offset(cx, size * 0.5),
          width:  size * 0.46,
          height: size * 0.06),
      Paint()..color = const Color(0xFFFFDC71),
    );

    // Windscreen (front)
    final glassPaint = Paint()
      ..color = const Color(0xFF90CAF9).withOpacity(0.85);
    canvas.drawPath(
      Path()
        ..moveTo(cx - size * 0.16, size * 0.22)
        ..lineTo(cx + size * 0.16, size * 0.22)
        ..lineTo(cx + size * 0.13, size * 0.33)
        ..lineTo(cx - size * 0.13, size * 0.33)
        ..close(),
      glassPaint,
    );

    // Rear window
    canvas.drawPath(
      Path()
        ..moveTo(cx - size * 0.13, size * 0.65)
        ..lineTo(cx + size * 0.13, size * 0.65)
        ..lineTo(cx + size * 0.16, size * 0.76)
        ..lineTo(cx - size * 0.16, size * 0.76)
        ..close(),
      glassPaint,
    );

    // Headlights
    final headlightPaint = Paint()..color = Colors.yellow.shade200;
    for (final dx in [-size * 0.15, size * 0.15]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx + dx, size * 0.14),
              width:  size * 0.10,
              height: size * 0.07),
          const Radius.circular(4),
        ),
        headlightPaint,
      );
    }

    // Tail lights
    final tailPaint = Paint()..color = Colors.red.shade400;
    for (final dx in [-size * 0.15, size * 0.15]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx + dx, size * 0.86),
              width:  size * 0.10,
              height: size * 0.06),
          const Radius.circular(3),
        ),
        tailPaint,
      );
    }

    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF333333);
    for (final pos in [
      Offset(cx - size * 0.25, size * 0.28),
      Offset(cx + size * 0.25, size * 0.28),
      Offset(cx - size * 0.25, size * 0.72),
      Offset(cx + size * 0.25, size * 0.72),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: pos,
              width:  size * 0.12,
              height: size * 0.16),
          const Radius.circular(4),
        ),
        wheelPaint,
      );
    }

    final picture  = recorder.endRecording();
    final img      = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  // ════════════════════════════════════════════════════════════
  // PARSE LOCATIONS
  // ════════════════════════════════════════════════════════════

  void _parseLocations() {
    final pickup  =
        widget.trip['pickup']  ?? widget.trip['pickup_location']  ?? {};
    final dropoff =
        widget.trip['dropoff'] ?? widget.trip['dropoff_location'] ?? {};

    _pickupLocation = LatLng(
      double.tryParse(pickup['lat']?.toString()
          ?? pickup['latitude']?.toString()  ?? '0') ?? 0,
      double.tryParse(pickup['lng']?.toString()
          ?? pickup['longitude']?.toString() ?? '0') ?? 0,
    );
    _pickupAddress = pickup['address']?.toString()
        ?? widget.trip['pickupAddress']?.toString()
        ?? 'Pickup Location';

    _dropoffLocation = LatLng(
      double.tryParse(dropoff['lat']?.toString()
          ?? dropoff['latitude']?.toString()  ?? '0') ?? 0,
      double.tryParse(dropoff['lng']?.toString()
          ?? dropoff['longitude']?.toString() ?? '0') ?? 0,
    );
    _dropoffAddress = dropoff['address']?.toString()
        ?? widget.trip['dropoffAddress']?.toString()
        ?? 'Destination';
  }

  // ════════════════════════════════════════════════════════════
  // ANIMATIONS
  // ════════════════════════════════════════════════════════════

  void _setupAnimations() {
    _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);
    _slideController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(
            parent: _pulseController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));

    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  // ════════════════════════════════════════════════════════════
  // MARKERS
  // ════════════════════════════════════════════════════════════

  void _setupMarkers() {
    _markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: _pickupLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen),
      infoWindow:
      InfoWindow(title: 'Pickup', snippet: _pickupAddress),
    ));
    if (mounted) setState(() {});
  }

  // ════════════════════════════════════════════════════════════
  // LOCATION
  // ════════════════════════════════════════════════════════════

  Future<void> _initializeLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _updateDriverMarker();
      _calculateDistanceAndETA();
      _startLocationTracking();
      if (_mapController != null) _fitMapToRoute();
    } catch (e) {
      _showSnackBar(
          'Unable to get your location. Check GPS.', isError: true);
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
      _calculateDistanceAndETA();
      _emitLocationUpdate();
      if (_distanceToPickup < 50 && !_isArriving) {
        _isArriving = true;
        _showArrivedDialog();
      }
    });

    _locationTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
          if (!mounted) return;
          try {
            final pos = await Geolocator.getCurrentPosition();
            if (mounted) {
              _currentPosition = pos;
              _updateDriverMarker();
              _calculateDistanceAndETA();
              _emitLocationUpdate();
            }
          } catch (_) {}
        });
  }

  // ════════════════════════════════════════════════════════════
  // ✅ UPDATE DRIVER MARKER — custom car icon with flat rotation
  // ════════════════════════════════════════════════════════════

  void _updateDriverMarker() {
    if (_currentPosition == null) return;
    final driverLatLng =
    LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: driverLatLng,
      icon: _carMarkerIcon ??
          BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueYellow),
      rotation: _currentPosition!.heading,
      anchor:   const Offset(0.5, 0.5),
      flat:     true,   // rotates with map bearing
      zIndex:   10,
      infoWindow: const InfoWindow(title: 'You (Driver)'),
    ));

    if (mounted) setState(() {});

    _mapController?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target:  driverLatLng,
        zoom:    16,
        bearing: _currentPosition!.heading,
      ),
    ));
  }

  void _emitLocationUpdate() {
    if (_currentPosition == null) return;
    SocketHelper.instance.socket?.emit('driver:location', {
      'tripId':    widget.tripId,
      'lat':       _currentPosition!.latitude,
      'lng':       _currentPosition!.longitude,
      'heading':   _currentPosition!.heading,
      'speed':     _currentSpeed,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _calculateDistanceAndETA() {
    if (_currentPosition == null) return;
    _distanceToPickup = Geolocator.distanceBetween(
      _currentPosition!.latitude,  _currentPosition!.longitude,
      _pickupLocation.latitude,    _pickupLocation.longitude,
    );
    final distanceKm   = _distanceToPickup / 1000;
    final averageSpeed = _currentSpeed > 5 ? _currentSpeed : 30.0;
    _etaMinutes        = ((distanceKm / averageSpeed) * 60).ceil();
    if (mounted) setState(() {});
  }

  // ════════════════════════════════════════════════════════════
  // ROUTE
  // ════════════════════════════════════════════════════════════

  Future<void> _fetchRoute() async {
    if (_currentPosition == null) {
      await Future.delayed(const Duration(seconds: 2));
      if (_currentPosition == null) {
        if (mounted) setState(() => _isLoadingRoute = false);
        return;
      }
    }
    try {
      final origin =
          '${_currentPosition!.latitude},${_currentPosition!.longitude}';
      final destination =
          '${_pickupLocation.latitude},${_pickupLocation.longitude}';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=$origin&destination=$destination'
            '&key=$_gmapsKey&mode=driving&alternatives=false',
      );
      final response =
      await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            (data['routes'] as List).isNotEmpty) {
          final route       = data['routes'][0];
          _routePoints      =
              _decodePolyline(route['overview_polyline']['points']);
          final leg         = route['legs'][0];
          _distanceToPickup = leg['distance']['value'].toDouble();
          _etaMinutes       = (leg['duration']['value'] / 60).ceil();

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
        throw Exception('No routes: ${data['status']}');
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Route fetch error: $e — fallback to straight line');
      if (_currentPosition != null) {
        _polylines
          ..clear()
          ..add(Polyline(
            polylineId: const PolylineId('route'),
            points: [
              LatLng(_currentPosition!.latitude,
                  _currentPosition!.longitude),
              _pickupLocation,
            ],
            color:    AppColors.primaryGold,
            width:    5,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ));
      }
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift  += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift  += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _fitMapToRoute() {
    if (_mapController == null || _currentPosition == null) return;
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
        100,
      ));
      return;
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(
          math.min(_currentPosition!.latitude,  _pickupLocation.latitude),
          math.min(_currentPosition!.longitude, _pickupLocation.longitude),
        ),
        northeast: LatLng(
          math.max(_currentPosition!.latitude,  _pickupLocation.latitude),
          math.max(_currentPosition!.longitude, _pickupLocation.longitude),
        ),
      ),
      100,
    ));
  }

  // ════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════

  void _showArrivedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.location_on,
                color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Arrived at Pickup?',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: const Text(
            'You\'re within 50 meters of the pickup location. '
                'Have you arrived?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not Yet')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleArrived();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Yes, I\'ve Arrived',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleArrived() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
        final token      = await _getAccessToken();
        if (token.isEmpty) throw Exception('No access token');

        final response = await http
            .post(
          Uri.parse(
              '$apiBaseUrl/driver/trips/${widget.tripId}/arrived'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
            .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('Timed out'),
        );

        if (response.statusCode == 200 || response.statusCode == 409) {
          SocketHelper.instance.socket?.emit('driver:arrived', {
            'tripId':    widget.tripId,
            'timestamp': DateTime.now().toIso8601String(),
          });
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DriverArrivedScreen(
                tripId:    widget.tripId,
                trip:      widget.trip,
                passenger: widget.passenger,
              ),
            ),
          );
          return;
        }
        throw Exception('HTTP ${response.statusCode}');

      } on TimeoutException {
        retryCount++;
        if (retryCount > maxRetries) {
          if (mounted) {
            setState(() => _hasNavigated = false);
            final retry = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text('Connection Timeout'),
                content:
                const Text('Request timed out. Try again?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold),
                    child: const Text('Retry',
                        style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            );
            if (retry == true) {
              retryCount = 0;
              continue;
            }
          }
          return;
        }
        await Future.delayed(const Duration(seconds: 3));

      } catch (e) {
        if (mounted) {
          setState(() => _hasNavigated = false);
          _showSnackBar('Failed to update status: $e', isError: true);
        }
        return;
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

  Future<void> _cancelTrip() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _CancelDialog(),
    );
    if (reason == null || reason.isEmpty) return;

    try {
      final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final response   = await http
          .post(
        Uri.parse(
            '$apiBaseUrl/driver/trips/${widget.tripId}/cancel'),
        headers: {
          'Authorization':
          'Bearer ${await _getAccessToken()}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'reason': reason}),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        SocketHelper.instance.socket?.emit('trip:canceled', {
          'tripId':     widget.tripId,
          'canceledBy': 'DRIVER',
          'reason':     reason,
          'timestamp':  DateTime.now().toIso8601String(),
        });
        _showSnackBar('Trip canceled', isError: false);
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Failed to cancel trip', isError: true);
    }
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  Future<String> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? '';
  }

  /// Full display name, resolved from multiple possible keys.
  String get _passengerName {
    final direct = widget.passenger['name']?.toString() ?? '';
    if (direct.isNotEmpty) return direct;
    final first = widget.passenger['firstName']?.toString()
        ?? widget.passenger['first_name']?.toString()  ?? '';
    final last  = widget.passenger['lastName']?.toString()
        ?? widget.passenger['last_name']?.toString()   ?? '';
    final full  = '$first $last'.trim();
    return full.isNotEmpty ? full : 'Passenger';
  }

  /// First character of the passenger's first name, uppercased.
  /// Falls back to the full name initial, then 'P'.
  String get _passengerInitial {
    final firstName = widget.passenger['firstName']?.toString().trim()
        ?? widget.passenger['first_name']?.toString().trim()
        ?? '';
    if (firstName.isNotEmpty) return firstName[0].toUpperCase();
    final name = _passengerName.trimLeft();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return 'P';
  }

  /// Avatar URL — validated to be a real http/https address.
  String? get _passengerAvatarUrl {
    final candidates = [
      widget.passenger['avatar_url'],
      widget.passenger['avatarUrl'],
      widget.passenger['profile_photo'],
      widget.passenger['photo'],
      widget.passenger['avatar'],
    ];
    for (final c in candidates) {
      final url = c?.toString().trim() ?? '';
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }
    }
    return null;
  }

  String? get _passengerRating {
    final r = widget.passenger['rating_avg']
        ?? widget.passenger['ratingAvg']
        ?? widget.passenger['rating'];
    if (r == null) return null;
    final d = double.tryParse(r.toString());
    if (d == null || d == 0) return null;
    return d.toStringAsFixed(1);
  }

  String? get _passengerTotalTrips {
    final t = widget.passenger['total_trips']
        ?? widget.passenger['totalTrips'];
    if (t == null) return null;
    final i = int.tryParse(t.toString());
    if (i == null || i == 0) return null;
    return '$i trips';
  }

  String _formatDistance(double meters) => meters < 1000
      ? '${meters.toInt()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  String _formatETA(int minutes) {
    if (minutes < 1) return '< 1 min';
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  void _showSnackBar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: AppTypography.bodySmall.copyWith(
              color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ════════════════════════════════════════════════════════════
  // DISPOSE
  // ════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _mapController?.dispose();
    _locationTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── MAP ──────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition:
            CameraPosition(target: _pickupLocation, zoom: 15),
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

          // ── TOP SCRIM ─────────────────────────────────────────
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

          // ── TOP BAR ───────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(children: [
                _CircleBtn(
                    icon: Icons.support_agent_rounded, onTap: () {}),
                const Spacer(),
                // Pulsing status pill
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.info,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                              color:  AppColors.info.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.navigation_rounded,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('En Route to Pickup',
                              style: AppTypography.caption.copyWith(
                                  color:      Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── BOTTOM SHEET ──────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child:    _buildBottomSheet(),
            ),
          ),

          // ── ROUTE LOADING OVERLAY ─────────────────────────────
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
                // ── ETA / DISTANCE TILES ─────────────────────
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
                    label:  'Distance',
                    value:  _formatDistance(_distanceToPickup),
                    accent: AppColors.warning,
                  )),
                ]),

                const SizedBox(height: 16),

                // ── PASSENGER CARD ────────────────────────────
                _buildPassengerCard(),

                const SizedBox(height: 14),

                // ── PICKUP ROW ────────────────────────────────
                _buildPickupRow(),

                const SizedBox(height: 20),

                // ── ACTION BUTTONS ────────────────────────────
                Row(children: [
                  // Cancel
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelTrip,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                        side: const BorderSide(
                            color: AppColors.error, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color:      AppColors.error,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Arrived
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primaryGold
                                  .withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _handleArrived,
                        icon: const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.black,
                            size: 20),
                        label: const Text("I've Arrived",
                            style: TextStyle(
                                fontSize:   16,
                                fontWeight: FontWeight.w800,
                                color:      Colors.black)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor:     Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ]),
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
    final rating = _passengerRating;
    final trips  = _passengerTotalTrips;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(children: [
        // ── Avatar: photo → first-letter fallback ──────────
        _PassengerAvatar(
          initial:   _passengerInitial,
          avatarUrl: _passengerAvatarUrl,
          size:      52,
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _passengerName,
                style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color:      AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              if (rating != null || trips != null)
                Row(children: [
                  if (rating != null) ...[
                    const Icon(Icons.star_rounded,
                        size: 14, color: AppColors.primaryGold),
                    const SizedBox(width: 3),
                    Text(rating,
                        style: AppTypography.labelSmall.copyWith(
                            color:      AppColors.textPrimary,
                            fontWeight: FontWeight.w700)),
                    if (trips != null) const SizedBox(width: 8),
                  ],
                  if (trips != null)
                    Text(trips,
                        style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary)),
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

  // ── Pickup location row ──────────────────────────────────────
  Widget _buildPickupRow() {
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
              color:        AppColors.successLight,
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.location_on_rounded,
              color: AppColors.success, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pickup Location',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary)),
              const SizedBox(height: 3),
              Text(
                _pickupAddress,
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.w600),
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
//    Shows the network photo when a valid URL is available.
//    Falls back to a gold circle with the passenger's first letter.
// ════════════════════════════════════════════════════════════════

class _PassengerAvatar extends StatelessWidget {
  final String  initial;
  final String? avatarUrl;
  final double  size;

  const _PassengerAvatar({
    required this.initial,
    required this.avatarUrl,
    this.size = 52,
  });

  bool get _hasValidPhoto {
    if (avatarUrl == null) return false;
    final url = avatarUrl!.trim();
    return url.startsWith('http://') || url.startsWith('https://');
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
          placeholder: (_, __) =>
              _AvatarFallback(initial: initial, size: size),
          errorWidget: (_, __, ___) =>
              _AvatarFallback(initial: initial, size: size),
        )
            : _AvatarFallback(initial: initial, size: size),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AVATAR FALLBACK — gold circle with passenger's first letter
// ════════════════════════════════════════════════════════════════

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
// CIRCLE BUTTON
// ════════════════════════════════════════════════════════════════

class _CircleBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;

  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color:      AppColors.shadowMedium,
                blurRadius: 12,
                offset:     const Offset(0, 4))
          ],
        ),
        child: Icon(icon, size: 22, color: Colors.black87),
      ),
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

// ════════════════════════════════════════════════════════════════
// CANCEL DIALOG
// ════════════════════════════════════════════════════════════════

class _CancelDialog extends StatefulWidget {
  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  static const _reasons = [
    'Passenger not responding',
    'Wrong pickup location',
    'Traffic / Road closure',
    'Vehicle issue',
    'Other',
  ];
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: const Text('Cancel Trip?',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Please select a reason:',
              style: TextStyle(
                  fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 12),
          ..._reasons.map((r) => RadioListTile<String>(
            title: Text(r,
                style: const TextStyle(fontSize: 14)),
            value:       r,
            groupValue:  _selected,
            dense:       true,
            activeColor: AppColors.primaryGold,
            onChanged: (v) => setState(() => _selected = v),
          )),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back')),
        ElevatedButton(
          onPressed: _selected != null
              ? () => Navigator.pop(context, _selected)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Confirm Cancel',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
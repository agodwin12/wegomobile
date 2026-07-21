// lib/screens/driver/en_route_screen/driver_en_route_screen.dart
//
// Mapbox migration: flutter_map + latlong2 replacing google_maps_flutter.
// All logic preserved: TTS, auto-rerouting, double-layer polyline,
// direction-arrow Widget markers, location streaming, DraggableScrollableSheet.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wego_v1/main.dart';
import 'package:wego_v1/utils/app_colors.dart';
import 'package:wego_v1/utils/app_typography.dart';
import 'package:wego_v1/utils/car_marker_painter.dart';
import 'package:wego_v1/utils/map_style.dart';
import 'package:wego_v1/widgets/map_style_button.dart';
import '../../../service/chat_service.dart';
import '../../chat/trip_chat_screen.dart';
import '../arrived_screen/driver_arrived.dart';

// ───────────────────────────────────────────────────────────────
// CONSTANTS
// ───────────────────────────────────────────────────────────────

const double   _kRerouteThreshold = 50.0;
const Duration _kRerouteThrottle  = Duration(seconds: 20);
const double   _kArrivedThreshold = 50.0;
const double   _kArrowInterval    = 200.0;

// ═══════════════════════════════════════════════════════════════
// WIDGET
// ═══════════════════════════════════════════════════════════════

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
  final MapController _mapCtrl              = MapController();
  List<Polyline>      _polylines            = [];
  List<Marker>        _directionArrowMarkers = [];
  bool                _isFollowingDriver    = true;

  // ── Draggable sheet ──────────────────────────────────────────
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  // ── TTS ──────────────────────────────────────────────────────
  final FlutterTts _tts      = FlutterTts();
  bool             _ttsReady = false;
  bool             _isMuted  = false;

  bool _said500m = false;
  bool _said200m = false;
  bool _said50m  = false;

  // ── Animations ───────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  // ── Location ─────────────────────────────────────────────────
  Position?                     _currentPosition;
  Timer?                        _locationTimer;
  StreamSubscription<Position>? _positionStream;
  double                        _driverHeading = 0.0;

  // ── Route ────────────────────────────────────────────────────
  List<LatLng> _routePoints      = [];
  double       _distanceToPickup = 0.0;
  int          _etaMinutes       = 0;
  double       _currentSpeed     = 0.0;
  bool         _isLoadingRoute   = true;
  bool         _routeFetched     = false;

  // ── Rerouting ────────────────────────────────────────────────
  bool      _isRerouting  = false;
  DateTime? _lastRerouteAt;
  int       _rerouteCount = 0;

  // ── Locations ────────────────────────────────────────────────
  late LatLng _pickupLocation;
  late LatLng _dropoffLocation;
  late String _pickupAddress;
  late String _dropoffAddress;

  // ── State ────────────────────────────────────────────────────
  bool _hasNavigated = false;
  bool _isArriving   = false;

  // ── Tokens ───────────────────────────────────────────────────
  String get _liqKey => dotenv.env['LOCATIONIQ_KEY'] ?? '';
  MapStyle _mapStyle = MapStyle.navigationDay;
  String get _apiBaseUrl  => dotenv.env['API_BASE_URL']        ?? '';

  // ═══════════════════════════════════════════════════════════
  // INIT / DISPOSE
  // ═══════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    debugPrint('🚗 [EN-ROUTE] Init — trip: ${widget.tripId}');
    _parseLocations();
    _setupAnimations();
    _initTts();
    _initializeLocation();
    loadMapStylePref().then((s) { if (mounted) setState(() => _mapStyle = s); });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheetCtrl.dispose();
    _locationTimer?.cancel();
    _positionStream?.cancel();
    _tts.stop();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // TTS
  // ═══════════════════════════════════════════════════════════

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setSharedInstance(true);
      _ttsReady = true;
    } catch (e) {
      debugPrint('⚠️ [TTS] Init error: $e');
    }
  }

  Future<void> _speak(String text, {bool interrupt = false}) async {
    if (!_ttsReady || _isMuted) return;
    try {
      if (interrupt) await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void _announceEnRoute() {
    _speak('Heading to pickup. Collect $_passengerName.', interrupt: true);
  }

  void _checkDistanceCallouts() {
    if (_distanceToPickup <= 0) return;
    if (!_said500m && _distanceToPickup <= 500) {
      _said500m = true;
      _speak('Pickup location in 500 meters.');
    } else if (!_said200m && _distanceToPickup <= 200) {
      _said200m = true;
      _speak('Pickup location in 200 meters.');
    } else if (!_said50m && _distanceToPickup <= _kArrivedThreshold) {
      _said50m = true;
      _speak('You have arrived at the pickup location.');
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    if (_isMuted) {
      _tts.stop();
      _showSnackBar('Voice muted', isError: false);
    } else {
      _speak('Voice guidance on.');
      _showSnackBar('Voice enabled', isError: false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PARSE LOCATIONS
  // ═══════════════════════════════════════════════════════════

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
        ?? tr('driver.pickupLocation');

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

  // ═══════════════════════════════════════════════════════════
  // ANIMATIONS
  // ═══════════════════════════════════════════════════════════

  void _setupAnimations() {
    _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _pulseController.repeat(reverse: true);
  }

  // ═══════════════════════════════════════════════════════════
  // LOCATION
  // ═══════════════════════════════════════════════════════════

  Future<void> _initializeLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _driverHeading = _currentPosition!.heading;
      _calculateDistanceAndETA();
      _startLocationTracking();
      await _fetchRoute();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _fitMapToRoute();
        });
      });
      Future.delayed(const Duration(milliseconds: 800), _announceEnRoute);
    } catch (e) {
      _showSnackBar('Unable to get your location. Check GPS.', isError: true);
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
      _driverHeading   = pos.heading;
      _currentSpeed    = pos.speed * 3.6;
      if (mounted) setState(() {});
      _moveCameraToDriver();
      _calculateDistanceAndETA();
      _emitLocationUpdate();
      _checkDistanceCallouts();
      _checkDeviation();

      if (_distanceToPickup < _kArrivedThreshold && !_isArriving) {
        _isArriving = true;
        _showArrivedDialog();
      }
    });

    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      try {
        final pos = await Geolocator.getCurrentPosition();
        if (!mounted) return;
        _currentPosition = pos;
        _driverHeading   = pos.heading;
        _currentSpeed    = pos.speed * 3.6;
        setState(() {});
        _moveCameraToDriver();
        _calculateDistanceAndETA();
        _emitLocationUpdate();
        _checkDistanceCallouts();
        _checkDeviation();
      } catch (_) {}
    });
  }

  void _moveCameraToDriver() {
    if (_currentPosition == null || !_isFollowingDriver) return;
    try {
      _mapCtrl.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 16);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // REROUTING
  // ═══════════════════════════════════════════════════════════

  void _checkDeviation() {
    if (_currentPosition == null || _routePoints.isEmpty || _isRerouting) return;
    if (_lastRerouteAt != null &&
        DateTime.now().difference(_lastRerouteAt!) < _kRerouteThrottle) return;

    final driver =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    if (_nearestRouteDistance(driver) > _kRerouteThreshold) _rerouteNow();
  }

  double _nearestRouteDistance(LatLng pt) {
    double min = double.infinity;
    for (final rp in _routePoints) {
      final d = Geolocator.distanceBetween(
          pt.latitude, pt.longitude, rp.latitude, rp.longitude);
      if (d < min) min = d;
    }
    return min;
  }

  Future<void> _rerouteNow() async {
    if (_isRerouting) return;
    setState(() => _isRerouting = true);
    _lastRerouteAt = DateTime.now();
    _rerouteCount++;

    await _speak('Recalculating route.', interrupt: true);
    _routeFetched = false;
    await _fetchRoute();

    if (mounted) setState(() => _isRerouting = false);
    await _speak('Route updated. Continue to the pickup location.');
  }

  // ═══════════════════════════════════════════════════════════
  // COMPASS BEARING  (0–360°, a→b)
  // ═══════════════════════════════════════════════════════════

  double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude  * math.pi / 180;
    final lat2 = b.latitude  * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y    = math.sin(dLon) * math.cos(lat2);
    final x    = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  // ═══════════════════════════════════════════════════════════
  // LOCATION EMIT
  // ═══════════════════════════════════════════════════════════

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
      _currentPosition!.latitude, _currentPosition!.longitude,
      _pickupLocation.latitude,   _pickupLocation.longitude,
    );
    final km  = _distanceToPickup / 1000;
    final spd = _currentSpeed > 5 ? _currentSpeed : 30.0;
    _etaMinutes = ((km / spd) * 60).ceil();
    if (mounted) setState(() {});
  }

  // ═══════════════════════════════════════════════════════════
  // MARKERS
  // ═══════════════════════════════════════════════════════════

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    markers.add(Marker(
      point:  _pickupLocation,
      width:  40,
      height: 50,
      child: const Icon(Icons.location_on, color: Colors.green, size: 40),
    ));

    if (_currentPosition != null) {
      markers.add(Marker(
        point:  LatLng(
            _currentPosition!.latitude, _currentPosition!.longitude),
        width:  60,
        height: 60,
        child: CarMarkerWidget(
          heading: _driverHeading,
          color:   const Color(0xFF1A1A1A),
        ),
      ));
    }

    markers.addAll(_directionArrowMarkers);
    return markers;
  }

  // ═══════════════════════════════════════════════════════════
  // ROUTE — Mapbox Directions v5
  //         gold solid line + white inner stripe + arrow markers
  // ═══════════════════════════════════════════════════════════

  Future<void> _fetchRoute() async {
    if (_routeFetched) return;
    _routeFetched = true;

    if (_currentPosition == null) {
      await Future.delayed(const Duration(seconds: 2));
      if (_currentPosition == null) {
        if (mounted) setState(() => _isLoadingRoute = false);
        return;
      }
    }

    final driverLat = _currentPosition!.latitude;
    final driverLng = _currentPosition!.longitude;
    final pickupLat = _pickupLocation.latitude;
    final pickupLng = _pickupLocation.longitude;

    try {
      final url = Uri.parse(
        'https://us1.locationiq.com/v1/directions/driving/'
        '$driverLng,$driverLat;$pickupLng,$pickupLat'
        '?key=$_liqKey'
        '&geometries=polyline'
        '&overview=full',
      );
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data   = json.decode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          _routePoints      = _decodePolyline(route['geometry'] as String);
          _distanceToPickup = (route['distance'] as num).toDouble();
          _etaMinutes       = ((route['duration'] as num) / 60).ceil();
          await _buildPolylines();
          if (mounted) {
            setState(() => _isLoadingRoute = false);
            _fitMapToRoute();
          }
          return;
        }
        throw Exception('No routes in Mapbox response');
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Route fetch error: $e — fallback straight line');
      if (_currentPosition != null) {
        _routePoints = [
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          _pickupLocation,
        ];
        await _buildPolylines();
      }
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _buildPolylines() async {
    _polylines.clear();

    // Gold main route
    _polylines.add(Polyline(
      points:      _routePoints,
      color:       AppColors.primaryGold,
      strokeWidth: 6,
      strokeCap:   StrokeCap.round,
      strokeJoin:  StrokeJoin.round,
    ));

    // White inner stripe (3-D road look)
    _polylines.add(Polyline(
      points:      _routePoints,
      color:       Colors.white.withOpacity(0.55),
      strokeWidth: 2,
      strokeCap:   StrokeCap.round,
      strokeJoin:  StrokeJoin.round,
    ));

    _placeDirectionArrows();
    if (mounted) setState(() {});
  }

  void _placeDirectionArrows() {
    if (_routePoints.length < 2) return;
    _directionArrowMarkers.clear();

    double accumulated = 0.0;
    double nextAt      = _kArrowInterval;

    for (int i = 1; i < _routePoints.length; i++) {
      final prev    = _routePoints[i - 1];
      final curr    = _routePoints[i];
      final segDist = Geolocator.distanceBetween(
          prev.latitude, prev.longitude,
          curr.latitude, curr.longitude);
      accumulated += segDist;

      if (accumulated >= nextAt) {
        final midLat = (prev.latitude  + curr.latitude)  / 2;
        final midLng = (prev.longitude + curr.longitude) / 2;
        final angle  = _bearing(prev, curr) * math.pi / 180;

        _directionArrowMarkers.add(Marker(
          point:  LatLng(midLat, midLng),
          width:  28,
          height: 28,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              decoration: BoxDecoration(
                color:  Colors.white,
                shape:  BoxShape.circle,
                border: Border.all(
                    color: AppColors.primaryGold, width: 1.5),
              ),
              child: const Icon(
                  Icons.arrow_upward_rounded,
                  size:  14,
                  color: Colors.black87),
            ),
          ),
        ));
        nextAt += _kArrowInterval;
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final pts   = <LatLng>[];
    int index   = 0;
    final len   = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b       = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift  += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        b       = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift  += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      pts.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return pts;
  }

  void _fitMapToRoute() {
    if (_currentPosition == null) return;
    try {
      final points = _routePoints.length >= 2
          ? _routePoints
          : [
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              _pickupLocation,
            ];
      _mapCtrl.fitCamera(CameraFit.bounds(
        bounds:  LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(100),
      ));
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════

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
          Expanded(
            child: Text(tr('driver.arrivedAtPickup'),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: Text(
            'You\'re within 50 meters of the pickup location. '
            'Have you arrived?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('driver.notYet'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleArrived();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: Text('Yes, I\'ve Arrived',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleArrived() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    int retryCount   = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        final token = await _getAccessToken();
        if (token.isEmpty) throw Exception('No access token');

        final response = await http
            .post(
              Uri.parse(
                  '$_apiBaseUrl/driver/trips/${widget.tripId}/arrived'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type':  'application/json',
              },
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Timed out'),
            );

        if (response.statusCode == 200 || response.statusCode == 409) {
          // HTTP /arrived is authoritative; backend emits trip:driver_arrived.
          await _speak('You have arrived at the pickup location.',
              interrupt: true);
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          Navigator.pushReplacement(
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
                title:   Text(tr('driver.connTimeout')),
                content: Text(tr('driver.requestTimedOut')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(tr('common.cancel'))),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold),
                    child: Text(tr('common.retry'),
                        style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            );
            if (retry == true) { retryCount = 0; continue; }
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
        ?? widget.passenger['phone_e164']?.toString() ?? '';
    if (phone.isEmpty) {
      _showSnackBar('Phone number not available', isError: true);
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Cannot open dialer', isError: true);
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
        context: context, builder: (_) => _CancelDialog());
    if (reason == null || reason.isEmpty) return;

    try {
      final response = await http
          .post(
            Uri.parse(
                '$_apiBaseUrl/driver/trips/${widget.tripId}/cancel'),
            headers: {
              'Authorization': 'Bearer ${await _getAccessToken()}',
              'Content-Type':  'application/json',
            },
            body: json.encode({'reason': reason}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // HTTP /cancel is authoritative; backend emits trip:canceled to passenger.
        await _speak('Trip canceled.', interrupt: true);
        _showSnackBar('Trip canceled', isError: false);
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Failed to cancel: $e', isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  Future<String> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? '';
  }

  String get _passengerName {
    final d = widget.passenger['name']?.toString() ?? '';
    if (d.isNotEmpty) return d;
    final f = widget.passenger['firstName']?.toString()
        ?? widget.passenger['first_name']?.toString()  ?? '';
    final l = widget.passenger['lastName']?.toString()
        ?? widget.passenger['last_name']?.toString()   ?? '';
    final full = '$f $l'.trim();
    return full.isNotEmpty ? full : 'Passenger';
  }

  String get _passengerInitial {
    final f = widget.passenger['firstName']?.toString().trim()
        ?? widget.passenger['first_name']?.toString().trim() ?? '';
    if (f.isNotEmpty) return f[0].toUpperCase();
    final n = _passengerName.trimLeft();
    return n.isNotEmpty ? n[0].toUpperCase() : 'P';
  }

  String? get _passengerAvatarUrl {
    for (final k in [
      'avatar_url', 'avatarUrl', 'profile_photo', 'photo', 'avatar'
    ]) {
      final v = widget.passenger[k]?.toString().trim() ?? '';
      if (v.startsWith('http://') || v.startsWith('https://')) return v;
    }
    return null;
  }

  String? get _passengerRating {
    final r = widget.passenger['rating_avg']
        ?? widget.passenger['ratingAvg']
        ?? widget.passenger['rating'];
    final d = double.tryParse(r?.toString() ?? '');
    return (d != null && d > 0) ? d.toStringAsFixed(1) : null;
  }

  String? get _passengerTotalTrips {
    final t = widget.passenger['total_trips']
        ?? widget.passenger['totalTrips'];
    final i = int.tryParse(t?.toString() ?? '');
    return (i != null && i > 0) ? '$i trips' : null;
  }

  String _fmtDist(double m) =>
      m < 1000 ? '${m.toInt()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  String _fmtETA(int min) {
    if (min < 1)  return '< 1 min';
    if (min < 60) return '$min min';
    return '${min ~/ 60}h ${min % 60}m';
  }

  void _showSnackBar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: AppTypography.bodySmall.copyWith(
              color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final screenH     = MediaQuery.of(context).size.height;
    final minFraction = (130.0 / screenH).clamp(0.14, 0.20);
    const initFraction = 0.48;
    const maxFraction  = 0.72;

    return Scaffold(
      body: Stack(
        children: [

          // ── 1. MAP ──────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _pickupLocation,
                initialZoom:   15.0,
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture && _isFollowingDriver) {
                    setState(() => _isFollowingDriver = false);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapStyle.tileUrl(_liqKey),
                  userAgentPackageName: 'com.wego.app',
                  tileProvider: NetworkTileProvider(),
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

          // ── 2. TOP SCRIM ────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0, height: 200,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.88),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 3. TOP BAR ──────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(children: [
                _CircleBtn(
                    icon: Icons.support_agent_rounded,
                    onTap: () {}),
                const SizedBox(width: 10),
                _CircleBtn(
                  icon:  _isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  onTap: _toggleMute,
                  color: _isMuted ? AppColors.error : null,
                ),
                const Spacer(),
                _isRerouting
                    ? _ReroutingPill()
                    : AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (_, __) => Transform.scale(
                          scale: _pulseAnimation.value,
                          child: _StatusPill(
                            icon:  Icons.navigation_rounded,
                            label: tr('driver.enRoutePickup'),
                            color: AppColors.info,
                          ),
                        ),
                      ),
              ]),
            ),
          ),

          // ── 4. RE-CENTER FAB ────────────────────────────────
          Positioned(
            right:  16,
            bottom: screenH * initFraction + 16,
            child: FloatingActionButton.small(
              heroTag:         'recenter_enroute',
              backgroundColor: Colors.white,
              elevation:       4,
              onPressed: () {
                setState(() => _isFollowingDriver = true);
                if (_currentPosition != null) {
                  try {
                    _mapCtrl.move(
                      LatLng(_currentPosition!.latitude,
                          _currentPosition!.longitude),
                      16,
                    );
                  } catch (_) {}
                }
              },
              child: const Icon(Icons.my_location_rounded,
                  color: Colors.black87),
            ),
          ),

          // ── 5. DRAGGABLE BOTTOM SHEET ───────────────────────
          DraggableScrollableSheet(
            controller:       _sheetCtrl,
            initialChildSize: initFraction,
            minChildSize:     minFraction,
            maxChildSize:     maxFraction,
            snap:             true,
            snapSizes:        [minFraction, initFraction, maxFraction],
            builder: (context, scrollCtrl) => _BottomSheetContent(
              scrollController: scrollCtrl,
              etaMinutes:       _etaMinutes,
              distToPickup:     _distanceToPickup,
              currentSpeed:     _currentSpeed,
              passengerName:    _passengerName,
              passengerInitial: _passengerInitial,
              passengerAvatar:  _passengerAvatarUrl,
              passengerRating:  _passengerRating,
              passengerTrips:   _passengerTotalTrips,
              pickupAddress:    _pickupAddress,
              rerouteCount:     _rerouteCount,
              fmtDist:          _fmtDist,
              fmtETA:           _fmtETA,
              onArrived:        _handleArrived,
              onCancel:         _cancelTrip,
              onCall:           _callPassenger,
              onChat:           _openChat,
            ),
          ),

          // ── 6. LOADING OVERLAY ──────────────────────────────
          if (_isLoadingRoute)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: Center(
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
}

// ═══════════════════════════════════════════════════════════════
// SMALL UI WIDGETS
// ═══════════════════════════════════════════════════════════════

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _StatusPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    decoration: BoxDecoration(
      color:        color,
      borderRadius: BorderRadius.circular(50),
      boxShadow: [
        BoxShadow(
            color:      color.withOpacity(0.4),
            blurRadius: 12,
            offset:     const Offset(0, 4))
      ],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: Colors.white),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color:      Colors.white,
              fontSize:   13,
              fontWeight: FontWeight.w700)),
    ]),
  );
}

class _ReroutingPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
        color: AppColors.warning, borderRadius: BorderRadius.circular(50)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 14, height: 14,
        child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:  AlwaysStoppedAnimation(Colors.white)),
      ),
      SizedBox(width: 8),
      Text(tr('driver.rerouting'),
          style: TextStyle(
              color:      Colors.white,
              fontSize:   13,
              fontWeight: FontWeight.w700)),
    ]),
  );
}

class _CircleBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final Color?       color;
  const _CircleBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset:     const Offset(0, 4))
        ],
      ),
      child: Icon(icon, size: 22, color: color ?? Colors.black87),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// BOTTOM SHEET CONTENT
// ═══════════════════════════════════════════════════════════════

class _BottomSheetContent extends StatelessWidget {
  final ScrollController        scrollController;
  final int                     etaMinutes;
  final double                  distToPickup;
  final double                  currentSpeed;
  final String                  passengerName;
  final String                  passengerInitial;
  final String?                 passengerAvatar;
  final String?                 passengerRating;
  final String?                 passengerTrips;
  final String                  pickupAddress;
  final int                     rerouteCount;
  final String Function(double) fmtDist;
  final String Function(int)    fmtETA;
  final VoidCallback            onArrived;
  final VoidCallback            onCancel;
  final VoidCallback            onCall;
  final VoidCallback            onChat;

  const _BottomSheetContent({
    required this.scrollController,
    required this.etaMinutes,
    required this.distToPickup,
    required this.currentSpeed,
    required this.passengerName,
    required this.passengerInitial,
    required this.passengerAvatar,
    required this.passengerRating,
    required this.passengerTrips,
    required this.pickupAddress,
    required this.rerouteCount,
    required this.fmtDist,
    required this.fmtETA,
    required this.onArrived,
    required this.onCancel,
    required this.onCall,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color:      Color(0x1A000000),
              blurRadius: 24,
              offset:     Offset(0, -8))
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding:    EdgeInsets.zero,
        physics:    const ClampingScrollPhysics(),
        children: [
          Center(
            child: Container(
              margin:    const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20,
                MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // 3 info tiles
                Row(children: [
                  Expanded(child: _InfoTile(
                    icon:   Icons.access_time_rounded,
                    label:  tr('driver.eta'),
                    value:  fmtETA(etaMinutes),
                    accent: AppColors.info,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _InfoTile(
                    icon:   Icons.straighten_rounded,
                    label:  tr('common.distance'),
                    value:  fmtDist(distToPickup),
                    accent: AppColors.warning,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _InfoTile(
                    icon:   Icons.speed_rounded,
                    label:  tr('driver.speed'),
                    value:  '${currentSpeed.toStringAsFixed(0)} km/h',
                    accent: AppColors.success,
                  )),
                ]),

                if (rerouteCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:        AppColors.warning.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.warning.withOpacity(0.35)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.alt_route_rounded,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Rerouted $rerouteCount '
                        '${rerouteCount == 1 ? 'time' : 'times'}',
                        style: AppTypography.bodySmall.copyWith(
                            color:      AppColors.warning,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 16),

                _PassengerCard(
                  name:    passengerName,
                  initial: passengerInitial,
                  avatar:  passengerAvatar,
                  rating:  passengerRating,
                  trips:   passengerTrips,
                  onCall:  onCall,
                  onChat:  onChat,
                ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color:        AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.location_on_rounded,
                          color: AppColors.success, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('driver.pickupLocation'),
                              style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 3),
                          Text(
                            pickupAddress,
                            style: AppTypography.titleMedium
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),

                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side:    const BorderSide(
                            color: AppColors.error, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(tr('common.cancel'),
                          style: TextStyle(
                              color:      AppColors.error,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient:     AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primaryGold.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: onArrived,
                        icon:  const Icon(Icons.check_circle_rounded,
                            color: Colors.black, size: 20),
                        label: Text("I've Arrived",
                            style: TextStyle(
                                fontSize:   16,
                                fontWeight: FontWeight.w800,
                                color:      Colors.black)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor:     Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
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
}

// ═══════════════════════════════════════════════════════════════
// PASSENGER CARD
// ═══════════════════════════════════════════════════════════════

class _PassengerCard extends StatelessWidget {
  final String  name;
  final String  initial;
  final String? avatar;
  final String? rating;
  final String? trips;
  final VoidCallback onCall;
  final VoidCallback onChat;

  const _PassengerCard({
    required this.name,
    required this.initial,
    required this.avatar,
    required this.rating,
    required this.trips,
    required this.onCall,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        AppColors.backgroundLight,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Row(children: [
      _PassengerAvatar(initial: initial, avatarUrl: avatar, size: 52),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color:      AppColors.textPrimary)),
            const SizedBox(height: 4),
            if (rating != null || trips != null)
              Row(children: [
                if (rating != null) ...[
                  const Icon(Icons.star_rounded,
                      size: 14, color: AppColors.primaryGold),
                  const SizedBox(width: 3),
                  Text(rating!,
                      style: AppTypography.labelSmall.copyWith(
                          color:      AppColors.textPrimary,
                          fontWeight: FontWeight.w700)),
                  if (trips != null) const SizedBox(width: 8),
                ],
                if (trips != null)
                  Text(trips!,
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary)),
              ])
            else
              Text(tr('driver.yourPassenger'),
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary)),
          ],
        ),
      ),
      _ActionBtn(
          icon:      Icons.call_rounded,
          iconColor: AppColors.success,
          bgColor:   AppColors.successLight,
          onTap:     onCall),
      const SizedBox(width: 8),
      _ActionBtn(
          icon:      Icons.chat_bubble_rounded,
          iconColor: AppColors.primaryGold,
          bgColor:   AppColors.primaryGold.withOpacity(0.12),
          onTap:     onChat),
    ]),
  );
}

class _PassengerAvatar extends StatelessWidget {
  final String  initial;
  final String? avatarUrl;
  final double  size;

  const _PassengerAvatar({
    required this.initial,
    required this.avatarUrl,
    this.size = 52,
  });

  bool get _valid {
    final u = avatarUrl?.trim() ?? '';
    return u.startsWith('http://') || u.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) => Container(
    width:  size,
    height: size,
    decoration: BoxDecoration(
      shape:  BoxShape.circle,
      border: Border.all(
          color: AppColors.primaryGold.withOpacity(0.5), width: 2),
    ),
    child: ClipOval(
      child: _valid
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

class _AvatarFallback extends StatelessWidget {
  final String initial;
  final double size;
  const _AvatarFallback({required this.initial, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    color:     AppColors.primaryGold,
    alignment: Alignment.center,
    child: Text(initial,
        style: TextStyle(
            fontSize:   size * 0.42,
            fontWeight: FontWeight.w800,
            color:      Colors.black)),
  );
}

// ═══════════════════════════════════════════════════════════════
// INFO TILE
// ═══════════════════════════════════════════════════════════════

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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
    decoration: BoxDecoration(
      color:        accent.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accent.withOpacity(0.25), width: 1.5),
    ),
    child: Column(children: [
      Icon(icon, color: accent, size: 20),
      const SizedBox(height: 6),
      Text(value,
          textAlign: TextAlign.center,
          style: AppTypography.headlineSmall.copyWith(
              fontSize:   13,
              fontWeight: FontWeight.w800,
              color:      AppColors.textPrimary)),
      const SizedBox(height: 2),
      Text(label,
          style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
// ACTION BUTTON
// ═══════════════════════════════════════════════════════════════

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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: iconColor, size: 20),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// CANCEL DIALOG
// ═══════════════════════════════════════════════════════════════

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
      title: Text(tr('driver.cancelTripQ'),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('driver.selectReason'),
              style: TextStyle(fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 12),
          ..._reasons.map((r) => RadioListTile<String>(
            title:      Text(r, style: const TextStyle(fontSize: 14)),
            value:      r,
            groupValue: _selected,
            dense:      true,
            activeColor: AppColors.primaryGold,
            onChanged:  (v) => setState(() => _selected = v),
          )),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.goBack'))),
        ElevatedButton(
          onPressed: _selected != null
              ? () => Navigator.pop(context, _selected)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(tr('driver.confirmCancel'),
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

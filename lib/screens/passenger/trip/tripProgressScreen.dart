// lib/presentation/screens/trip/tripProgressScreen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/trip_provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/car_marker_painter.dart';
import '../../../utils/map_style.dart';
import '../../../widgets/map_style_button.dart';
import '../../chat/trip_chat_screen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _kSheetMinFrac = 0.14;
const _kSheetMidFrac = 0.44;
const _kSheetMaxFrac = 0.88;

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

  String get _liqKey => dotenv.env['LOCATIONIQ_KEY'] ?? '';
  MapStyle _mapStyle = MapStyle.streets;

  final MapController _mapCtrl = MapController();
  List<Polyline> _polylines = [];
  bool _isFollowingDriver = true;

  AnimationController? _slideCtrl;
  AnimationController? _carAnimCtrl;
  AnimationController? _pulseCtrl;
  AnimationController? _completedCtrl;

  Animation<Offset>? _slideAnim;
  Animation<double>? _pulseAnim;
  Animation<double>? _completedAnim;

  LatLng? _currentDriverLocation;
  LatLng? _animatedDriverLocation;
  double  _driverBearing = 0.0;

  bool   _hasNavigated   = false;
  bool   _tripCompleted  = false;
  String _eta            = '--';
  double _distanceKm     = 0.0;
  int    _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  LatLng? _lastPolylineOrigin;

  TripProvider? _tripProvider;
  VoidCallback? _tripListener;

  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();

  // ═════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startElapsedTimer();
    loadMapStylePref().then((s) { if (mounted) setState(() => _mapStyle = s); });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _tripProvider = Provider.of<TripProvider>(context, listen: false);
      _tripListener = () => _checkTripStatus(_tripProvider!);
      _tripProvider!.addListener(_tripListener!);
      _checkTripStatus(_tripProvider!);

      final loc = _tripProvider!.driverLocation;
      if (loc != null && loc['lat'] != null && loc['lng'] != null) {
        _currentDriverLocation = LatLng(_toDouble(loc['lat']), _toDouble(loc['lng']));
      } else {
        _currentDriverLocation = LatLng(widget.pickupLocation.latitude + 0.001, widget.pickupLocation.longitude + 0.001);
      }
      _animatedDriverLocation = _currentDriverLocation;
      _driverBearing = _calcBearing(_currentDriverLocation!, widget.dropoffLocation);
      _calcDistETA();
      setState(() {});

      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        _fitMapToRoute();
        _fetchRoutePolyline(force: true);
      }
    });
  }

  @override
  void dispose() {
    _tripProvider?.removeListener(_tripListener!);
    _slideCtrl?.dispose();
    _carAnimCtrl?.dispose();
    _pulseCtrl?.dispose();
    _completedCtrl?.dispose();
    _mapCtrl.dispose();
    _sheetCtrl.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SETUP
  // ═════════════════════════════════════════════════════════════════════════

  void _setupAnimations() {
    _slideCtrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl!, curve: Curves.easeOutCubic));
    _slideCtrl!.forward();

    _carAnimCtrl = AnimationController(duration: const Duration(seconds: 2), vsync: this);

    _pulseCtrl = AnimationController(duration: const Duration(milliseconds: 1400), vsync: this);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut));
    _pulseCtrl!.repeat(reverse: true);

    _completedCtrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _completedAnim = CurvedAnimation(parent: _completedCtrl!, curve: Curves.easeOutBack);
  }

  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // MAP MARKERS
  // ═════════════════════════════════════════════════════════════════════════

  List<Marker> _buildMarkers() {
    final markers = <Marker>[
      Marker(
        point: widget.dropoffLocation, width: 40, height: 50,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      ),
    ];
    if (_animatedDriverLocation != null) {
      markers.add(Marker(
        point: _animatedDriverLocation!, width: 60, height: 60,
        child: CarMarkerWidget(heading: _driverBearing, color: const Color(0xFF1A1A1A)),
      ));
    }
    return markers;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // POLYLINE (Mapbox Directions, 50 m debounce)
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _fetchRoutePolyline({bool force = false}) async {
    if (_animatedDriverLocation == null) return;

    if (!force && _lastPolylineOrigin != null) {
      final moved = _haversineKm(_animatedDriverLocation!.latitude, _animatedDriverLocation!.longitude, _lastPolylineOrigin!.latitude, _lastPolylineOrigin!.longitude);
      if (moved < 0.05) return;
    }

    final token = _liqKey;
    if (token.isEmpty || token.startsWith('pk.YOUR')) { _drawStraightLine(); return; }

    final url = Uri.parse(
      'https://us1.locationiq.com/v1/directions/driving/'
      '${_animatedDriverLocation!.longitude},${_animatedDriverLocation!.latitude};'
      '${widget.dropoffLocation.longitude},${widget.dropoffLocation.latitude}'
      '?key=$token&geometries=polyline&overview=full',
    );

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data   = json.decode(res.body);
        final routes = data['routes'] as List? ?? [];
        if (routes.isNotEmpty) {
          final points = _decodePolyline(routes[0]['geometry'] as String);
          _lastPolylineOrigin = _animatedDriverLocation;
          if (mounted) setState(() => _polylines = [Polyline(points: points, color: AppColors.primaryGold, strokeWidth: 5)]);
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [IN-PROGRESS POLYLINE] $e');
    }
    _drawStraightLine();
  }

  void _drawStraightLine() {
    if (_animatedDriverLocation == null || !mounted) return;
    setState(() => _polylines = [Polyline(points: [_animatedDriverLocation!, widget.dropoffLocation], color: AppColors.primaryGold, strokeWidth: 5)]);
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

  void _fitMapToRoute() {
    if (_animatedDriverLocation == null || !mounted) return;
    try {
      final bounds = LatLngBounds.fromPoints([_animatedDriverLocation!, widget.dropoffLocation]);
      _mapCtrl.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)));
    } catch (_) {}
  }

  void _recenterMap() {
    setState(() => _isFollowingDriver = true);
    _fitMapToRoute();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TRIP STATUS
  // ═════════════════════════════════════════════════════════════════════════

  void _checkTripStatus(TripProvider tp) {
    if (_hasNavigated || !mounted) return;

    if (tp.driverLocation != null) {
      final newLat = tp.driverLocation!['lat'];
      final newLng = tp.driverLocation!['lng'];
      if (newLat != null && newLng != null) {
        final newLoc = LatLng(_toDouble(newLat), _toDouble(newLng));
        final same   = _currentDriverLocation != null && _currentDriverLocation!.latitude == newLoc.latitude && _currentDriverLocation!.longitude == newLoc.longitude;
        if (!same) _animateDriverTo(newLoc);
      }
    }

    switch (tp.status) {
      case TripStatus.completed:
        if (!_tripCompleted) {
          _tripCompleted = true;
          HapticFeedback.mediumImpact();
          _pulseCtrl?.stop();
          _elapsedTimer?.cancel();
          _completedCtrl?.forward();
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && _sheetCtrl.isAttached) _sheetCtrl.animateTo(_kSheetMidFrac, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
          });
        }
        break;
      case TripStatus.canceled:
        _showCanceledDialog(tp.errorMessage ?? 'Your trip was canceled');
        break;
      default:
        break;
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SMOOTH CAR ANIMATION
  // ═════════════════════════════════════════════════════════════════════════

  void _animateDriverTo(LatLng newLoc) {
    final from = _currentDriverLocation ?? newLoc;
    _driverBearing = _calcBearing(from, newLoc);

    _carAnimCtrl?.reset();
    final anim = Tween<double>(begin: 0.0, end: 1.0).animate(_carAnimCtrl!);

    anim.addListener(() {
      if (!mounted) return;
      final t   = anim.value;
      final lat = from.latitude  + (newLoc.latitude  - from.latitude)  * t;
      final lng = from.longitude + (newLoc.longitude - from.longitude) * t;
      _animatedDriverLocation = LatLng(lat, lng);
      setState(() {});
      _calcDistETA();
      if (_isFollowingDriver) {
        try { _mapCtrl.move(_animatedDriverLocation!, 15); } catch (_) {}
      }
    });

    anim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentDriverLocation = newLoc;
        _fetchRoutePolyline();
      }
    });

    _carAnimCtrl!.forward();
  }

  void _calcDistETA() {
    if (_animatedDriverLocation == null) return;
    final d = _haversineKm(_animatedDriverLocation!.latitude, _animatedDriverLocation!.longitude, widget.dropoffLocation.latitude, widget.dropoffLocation.longitude);
    if (mounted) setState(() {
      _distanceKm = d;
      final mins = (d / 30.0 * 60).ceil();
      _eta = d < 0.05 ? 'Arriving' : (mins < 1 ? '< 1 min' : '$mins min');
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // DIALOGS & NAVIGATION
  // ═════════════════════════════════════════════════════════════════════════

  void _showCanceledDialog(String message) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Trip Canceled', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 15, color: Colors.black54)),
        actions: [SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Okay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ))],
      ),
    );
  }

  void _goHome() {
    _hasNavigated = true;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _callDriver() async {
    final phone = _getField(widget.driver, ['phone', 'phone_e164', 'phoneNumber']);
    if (phone == null || phone.isEmpty) { _snack('Driver phone not available', isError: true); return; }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
    else _snack('Cannot open dialer', isError: true);
  }

  void _openChat() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
      tripId: widget.tripId, otherUserName: _getDriverName(),
      otherUserAvatar: _getField(widget.driver, ['avatar', 'avatar_url']),
    )));
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: isError ? Colors.red.shade700 : Colors.black87,
      behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
    ));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════════════

  String _getDriverName() {
    final first = _getField(widget.driver, ['firstName', 'first_name']) ?? '';
    final last  = _getField(widget.driver, ['lastName',  'last_name'])  ?? '';
    final full  = '$first $last'.trim();
    return full.isNotEmpty ? full : 'Driver';
  }

  String? _getDriverAvatarUrl() => _getField(widget.driver, ['avatar', 'avatar_url', 'avatarUrl', 'profile_photo', 'profilePhoto', 'photo', 'picture']);

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
      'plate':     _getField(src, ['plate', 'vehiclePlate', 'license_plate']) ?? 'N/A',
      'makeModel': _getField(src, ['makeModel', 'vehicle_make_model', 'make_model']) ?? 'Vehicle',
      'color':     _getField(src, ['color', 'vehicleColor', 'vehicle_color']) ?? '',
    };
  }

  String get _driverRating => _getField(widget.driver, ['rating', 'rating_avg', 'ratingAvg']) ?? '4.8';

  String _formatElapsed(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  double _calcBearing(LatLng from, LatLng to) {
    final lat1 = _toRad(from.latitude);
    final lat2 = _toRad(to.latitude);
    final dLon = _toRad(to.longitude - from.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r    = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a    = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * (math.pi / 180.0);

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int)    return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // WIDGET HELPERS
  // ═════════════════════════════════════════════════════════════════════════

  Widget _driverAvatar({double size = 52, double fontSize = 20}) {
    final url     = _getDriverAvatarUrl();
    final name    = _getDriverName();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    final fallback = Container(
      width: size, height: size,
      decoration: BoxDecoration(color: AppColors.primaryGold, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Center(child: Text(initial, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.black))),
    );
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.cover, placeholder: (_, __) => fallback, errorWidget: (_, __, ___) => fallback),
    );
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
                initialZoom: 15,
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture && _isFollowingDriver) setState(() => _isFollowingDriver = false);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapStyle.tileUrl(_liqKey),
                  userAgentPackageName: 'com.wego.app',
                  fallbackUrl: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
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

          // Top status pill
          Positioned(
            top: MediaQuery.of(context).padding.top + 12, left: 0, right: 0,
            child: Center(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _tripCompleted
                ? const _CompletedPill(key: ValueKey('done'))
                : _EtaPill(key: const ValueKey('eta'), eta: _eta, elapsedLabel: _formatElapsed(_elapsedSeconds), pulseAnimation: _pulseAnim ?? const AlwaysStoppedAnimation(1.0)),
            )),
          ),

          // Re-center FAB
          if (!_isFollowingDriver)
            Positioned(
              bottom: MediaQuery.of(context).size.height * _kSheetMinFrac + 16, right: 16,
              child: _RecenterFab(onTap: _recenterMap),
            ),

          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: _kSheetMidFrac, minChildSize: _kSheetMinFrac, maxChildSize: _kSheetMaxFrac,
            snap: true, snapSizes: const [_kSheetMinFrac, _kSheetMidFrac, _kSheetMaxFrac],
            builder: (context, scrollCtrl) {
              return SlideTransition(
                position: _slideAnim ?? const AlwaysStoppedAnimation(Offset.zero),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(top: BorderSide(color: AppColors.darkBorder.withOpacity(0.6))),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, -6))],
                  ),
                  child: ListView(
                    controller: scrollCtrl, padding: EdgeInsets.zero, physics: const ClampingScrollPhysics(),
                    children: [
                      Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 42, height: 4, decoration: BoxDecoration(color: AppColors.darkSurfaceHigh, borderRadius: BorderRadius.circular(2)))),
                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PeekRow(tripCompleted: _tripCompleted, eta: _eta, distanceKm: _distanceKm, plate: _vehicleInfo['plate'] ?? 'N/A'),
                            const SizedBox(height: 16),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SizeTransition(sizeFactor: anim, child: child)),
                              child: _tripCompleted
                                ? _CompletedCard(key: const ValueKey('card'), animation: _completedAnim ?? const AlwaysStoppedAnimation(1.0), elapsedLabel: _formatElapsed(_elapsedSeconds), onGoHome: _goHome)
                                : _DestinationRow(key: const ValueKey('dest'), address: widget.dropoffAddress, distanceKm: _distanceKm),
                            ),
                            const SizedBox(height: 16),
                            Divider(height: 1, color: AppColors.darkBorder),
                            const SizedBox(height: 16),
                            Row(children: [
                              _driverAvatar(size: 52), const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_getDriverName(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.darkTextPrimary)),
                                const SizedBox(height: 2),
                                Row(children: [const Icon(Icons.star_rounded, size: 14, color: AppColors.primaryGold), const SizedBox(width: 4), Text(_driverRating, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkTextSecondary))]),
                              ])),
                              _RoundActionBtn(icon: Icons.call_rounded, iconColor: AppColors.success, bg: AppColors.success.withOpacity(0.16), onTap: _callDriver),
                              const SizedBox(width: 8),
                              _RoundActionBtn(icon: Icons.chat_bubble_rounded, iconColor: AppColors.primaryGold, bg: AppColors.primaryGold.withOpacity(0.16), onTap: _openChat),
                            ]),
                            const SizedBox(height: 16),
                            _VehicleStrip(vehicleInfo: _vehicleInfo),
                            const SizedBox(height: 20),
                            _RouteTimeline(pickup: widget.pickupAddress, dropoff: widget.dropoffAddress),
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
// SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _EtaPill extends StatelessWidget {
  final String eta;
  final String elapsedLabel;
  final Animation<double> pulseAnimation;
  const _EtaPill({super.key, required this.eta, required this.elapsedLabel, required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (_, child) => Transform.scale(scale: pulseAnimation.value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primaryGold, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(eta, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('away', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, fontWeight: FontWeight.w500)),
          Container(margin: const EdgeInsets.symmetric(horizontal: 10), width: 1, height: 16, color: Colors.white.withOpacity(0.2)),
          Icon(Icons.timer_outlined, size: 13, color: Colors.white.withOpacity(0.55)),
          const SizedBox(width: 4),
          Text(elapsedLabel, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _CompletedPill extends StatelessWidget {
  const _CompletedPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: AppColors.primaryGold, borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: AppColors.primaryGold.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))]),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_rounded, color: Colors.black, size: 18), SizedBox(width: 8),
        Text('You have arrived!', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
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
      child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 2))]), child: const Icon(Icons.my_location_rounded, size: 22, color: Colors.black87)),
    );
  }
}

class _PeekRow extends StatelessWidget {
  final bool tripCompleted;
  final String eta;
  final double distanceKm;
  final String plate;
  const _PeekRow({required this.tripCompleted, required this.eta, required this.distanceKm, required this.plate});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tripCompleted ? '🎉 You have arrived!' : 'Trip in Progress', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.darkTextPrimary, letterSpacing: -0.3)),
        const SizedBox(height: 2),
        Text(tripCompleted ? 'Trip completed' : '${distanceKm > 0 ? "${distanceKm.toStringAsFixed(1)} km  ·  " : ""}$eta to destination', style: const TextStyle(fontSize: 13, color: AppColors.darkTextSecondary, fontWeight: FontWeight.w500)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)), child: Text(plate, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2))),
    ]);
  }
}

class _DestinationRow extends StatelessWidget {
  final String address;
  final double distanceKm;
  const _DestinationRow({super.key, required this.address, required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkBorder)),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.error.withOpacity(0.14), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.location_on_rounded, color: AppColors.error, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Destination', style: TextStyle(fontSize: 11, color: AppColors.darkTextTertiary)),
          const SizedBox(height: 2),
          Text(address.length > 35 ? '${address.substring(0, 35)}…' : address, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (distanceKm > 0) ...[
          const SizedBox(width: 8),
          Column(children: [
            const Icon(Icons.straighten_rounded, size: 12, color: AppColors.darkTextTertiary), const SizedBox(height: 2),
            Text('${distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final Animation<double> animation;
  final String elapsedLabel;
  final VoidCallback onGoHome;
  const _CompletedCard({super.key, required this.animation, required this.elapsedLabel, required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) => Transform.scale(scale: (0.9 + animation.value * 0.1).clamp(0.0, 1.1), child: Opacity(opacity: animation.value.clamp(0.0, 1.0), child: child)),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryGold.withOpacity(0.9), AppColors.primaryGold], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.primaryGold.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))]),
        child: Column(children: [
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.black.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.emoji_events_rounded, color: Colors.black, size: 26)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('You have arrived!', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('Trip time: $elapsedLabel', style: TextStyle(color: Colors.black.withOpacity(0.65), fontSize: 12, fontWeight: FontWeight.w500)),
            ])),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 46, child: ElevatedButton(
            onPressed: onGoHome,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Done', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          )),
        ]),
      ),
    );
  }
}

class _VehicleStrip extends StatelessWidget {
  final Map<String, String> vehicleInfo;
  const _VehicleStrip({required this.vehicleInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkBorder)),
      child: Row(children: [
        const Icon(Icons.directions_car_rounded, size: 16, color: AppColors.darkTextTertiary), const SizedBox(width: 8),
        Expanded(child: Text(vehicleInfo['makeModel'] ?? 'Vehicle', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary))),
        if ((vehicleInfo['color'] ?? '').isNotEmpty) ...[
          Text(vehicleInfo['color']!, style: const TextStyle(fontSize: 13, color: AppColors.darkTextSecondary)), const SizedBox(width: 10),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.primaryGold, borderRadius: BorderRadius.circular(6)),
          child: Text(vehicleInfo['plate'] ?? 'N/A', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.black)),
        ),
      ]),
    );
  }
}

class _RouteTimeline extends StatelessWidget {
  final String pickup;
  final String dropoff;
  const _RouteTimeline({required this.pickup, required this.dropoff});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
      child: Row(children: [
        Column(children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
          Container(width: 2, height: 32, decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF22C55E), Color(0xFFEF4444)]), borderRadius: BorderRadius.circular(1))),
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
        ]),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _AddrLine(label: 'Pickup', address: pickup),
          const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Divider(height: 1, color: AppColors.darkBorder)),
          _AddrLine(label: 'Destination', address: dropoff),
        ])),
      ]),
    );
  }
}

class _AddrLine extends StatelessWidget {
  final String label;
  final String address;
  const _AddrLine({required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.darkTextTertiary)),
      const SizedBox(height: 2),
      Text(address.length > 38 ? '${address.substring(0, 38)}…' : address, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }
}

class _RoundActionBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bg;
  final VoidCallback onTap;
  const _RoundActionBtn({required this.icon, required this.iconColor, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 22)));
  }
}

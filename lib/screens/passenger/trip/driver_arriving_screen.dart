// lib/presentation/screens/trip/driver_arriving_screen.dart

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
import 'tripProgressScreen.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _kFreeCancelSeconds   = 300;
const _kBottomSheetMinFrac  = 0.22;
const _kBottomSheetMidFrac  = 0.52;
const _kBottomSheetMaxFrac  = 0.88;

class DriverArrivingScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> driver;
  final Map<String, dynamic>? driverLocation;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;
  final String? fareEstimate;
  final String? paymentMethod;
  final String? vehicleType;

  const DriverArrivingScreen({
    super.key,
    required this.tripId,
    required this.driver,
    this.driverLocation,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.fareEstimate,
    this.paymentMethod,
    this.vehicleType,
  });

  @override
  State<DriverArrivingScreen> createState() => _DriverArrivingScreenState();
}

class _DriverArrivingScreenState extends State<DriverArrivingScreen>
    with TickerProviderStateMixin {

  String get _mapboxToken => dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  MapStyle _mapStyle = MapStyle.dark;

  final MapController _mapCtrl = MapController();
  List<Polyline> _polylines = [];
  bool _isFollowingDriver = true;

  AnimationController? _slideCtrl;
  AnimationController? _carAnimCtrl;
  AnimationController? _pulseCtrl;
  AnimationController? _arrivedBannerCtrl;

  Animation<Offset>? _slideAnim;
  Animation<double>? _pulseAnim;
  Animation<double>? _arrivedBannerAnim;

  LatLng? _currentDriverLocation;
  LatLng? _animatedDriverLocation;
  double  _driverBearing = 0.0;

  bool   _hasNavigated       = false;
  bool   _driverArrivedShown = false;
  bool   _driverHasArrived   = false;
  String _eta      = '--';
  double _distance = 0.0;

  int    _freeCancelSecondsLeft = _kFreeCancelSeconds;
  Timer? _freeCancelTimer;
  bool   _freeCancelExpired = false;

  TripProvider? _tripProvider;
  VoidCallback? _tripListener;

  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();

  LatLng? _lastPolylineOrigin;

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initDriverLocation();
    _startFreeCancelTimer();
    loadMapStylePref().then((s) { if (mounted) setState(() => _mapStyle = s); });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _tripProvider = Provider.of<TripProvider>(context, listen: false);
      _tripListener = () => _checkTripStatus(_tripProvider!);
      _tripProvider!.addListener(_tripListener!);
      _checkTripStatus(_tripProvider!);

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
    _arrivedBannerCtrl?.dispose();
    _mapCtrl.dispose();
    _sheetCtrl.dispose();
    _freeCancelTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETUP
  // ═══════════════════════════════════════════════════════════════════════════

  void _setupAnimations() {
    _slideCtrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl!, curve: Curves.easeOutCubic));

    _carAnimCtrl = AnimationController(duration: const Duration(seconds: 2), vsync: this);

    _pulseCtrl = AnimationController(duration: const Duration(milliseconds: 1400), vsync: this);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.07)
        .animate(CurvedAnimation(parent: _pulseCtrl!, curve: Curves.easeInOut));
    _pulseCtrl!.repeat(reverse: true);

    _arrivedBannerCtrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _arrivedBannerAnim = CurvedAnimation(parent: _arrivedBannerCtrl!, curve: Curves.easeOutBack);

    _slideCtrl!.forward();
  }

  void _initDriverLocation() {
    final loc = widget.driverLocation;
    if (loc != null && loc['lat'] != null && loc['lng'] != null) {
      _currentDriverLocation = LatLng(_toDouble(loc['lat']), _toDouble(loc['lng']));
    } else {
      _currentDriverLocation = LatLng(
        widget.pickupLocation.latitude  + 0.003,
        widget.pickupLocation.longitude + 0.003,
      );
    }
    _animatedDriverLocation = _currentDriverLocation;
    _driverBearing = _calcBearing(_currentDriverLocation!, widget.pickupLocation);
    _calcDistETA();
  }

  void _startFreeCancelTimer() {
    _freeCancelTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_freeCancelSecondsLeft > 0) { _freeCancelSecondsLeft--; }
        else { _freeCancelExpired = true; t.cancel(); }
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAP MARKERS (flutter_map widget-based)
  // ═══════════════════════════════════════════════════════════════════════════

  List<Marker> _buildMarkers() {
    final markers = <Marker>[
      Marker(
        point: widget.pickupLocation, width: 34, height: 34,
        child: const _PickupDot(),
      ),
    ];
    if (_animatedDriverLocation != null) {
      markers.add(Marker(
        point: _animatedDriverLocation!, width: 60, height: 60,
        child: CarMarkerWidget(heading: _driverBearing, color: AppColors.primaryGold),
      ));
    }
    return markers;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POLYLINE (Mapbox Directions, 50 m debounce)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _fetchRoutePolyline({bool force = false}) async {
    if (_animatedDriverLocation == null) return;

    if (!force && _lastPolylineOrigin != null) {
      final moved = _haversineKm(_animatedDriverLocation!.latitude, _animatedDriverLocation!.longitude, _lastPolylineOrigin!.latitude, _lastPolylineOrigin!.longitude);
      if (moved < 0.05) return;
    }

    final token = _mapboxToken;
    if (token.isEmpty || token.startsWith('pk.YOUR')) {
      _drawStraightLine(); return;
    }

    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
          '${_animatedDriverLocation!.longitude},${_animatedDriverLocation!.latitude};'
          '${widget.pickupLocation.longitude},${widget.pickupLocation.latitude}'
          '?access_token=$token&geometries=polyline&overview=full',
    );

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data   = json.decode(res.body);
        final routes = data['routes'] as List? ?? [];
        if (routes.isNotEmpty) {
          final points = _decodePolyline(routes[0]['geometry'] as String);
          _lastPolylineOrigin = _animatedDriverLocation;
          _applyPolyline(points);
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ARRIVING POLYLINE] $e');
    }
    _drawStraightLine();
  }

  void _drawStraightLine() {
    if (_animatedDriverLocation == null || !mounted) return;
    _applyPolyline([_animatedDriverLocation!, widget.pickupLocation]);
  }

  void _applyPolyline(List<LatLng> points) {
    if (!mounted) return;
    setState(() => _polylines = [
      Polyline(points: points, color: AppColors.primaryGold.withOpacity(0.25), strokeWidth: 11),
      Polyline(points: points, color: AppColors.primaryGold, strokeWidth: 5),
    ]);
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
      final bounds = LatLngBounds.fromPoints([_animatedDriverLocation!, widget.pickupLocation]);
      _mapCtrl.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)));
    } catch (_) {}
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

    if (tp.driverLocation != null) {
      final newLat = tp.driverLocation!['lat'];
      final newLng = tp.driverLocation!['lng'];
      if (newLat != null && newLng != null) {
        final newLoc = LatLng(_toDouble(newLat), _toDouble(newLng));
        final same = _currentDriverLocation != null && _currentDriverLocation!.latitude == newLoc.latitude && _currentDriverLocation!.longitude == newLoc.longitude;
        if (!same) _animateDriverTo(newLoc);
      }
    }

    switch (tp.status) {
      case TripStatus.arrivedPickup:
        if (!_driverArrivedShown) {
          _driverArrivedShown = true;
          HapticFeedback.mediumImpact();
          setState(() => _driverHasArrived = true);
          _pulseCtrl?.stop();
          _arrivedBannerCtrl?.forward();
          _freeCancelTimer?.cancel();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _sheetCtrl.isAttached) _sheetCtrl.animateTo(_kBottomSheetMidFrac, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
          });
        }
        break;
      case TripStatus.inProgress:
        _navigateToTripInProgress();
        break;
      case TripStatus.canceled:
        _showCanceledDialog(tp.errorMessage ?? 'Votre course a été annulée');
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
    final d = _haversineKm(_animatedDriverLocation!.latitude, _animatedDriverLocation!.longitude, widget.pickupLocation.latitude, widget.pickupLocation.longitude);
    if (mounted) setState(() {
      _distance = d;
      final mins = (d / 30.0 * 60).ceil();
      _eta = d < 0.05 ? 'Arrive' : (mins < 1 ? '< 1 min' : '$mins min');
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  void _navigateToTripInProgress() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TripInProgressScreen(
      tripId:          widget.tripId, driver: widget.driver,
      pickupLocation:  widget.pickupLocation, dropoffLocation: widget.dropoffLocation,
      pickupAddress:   widget.pickupAddress,  dropoffAddress:  widget.dropoffAddress,
    )));
  }

  void _showCanceledDialog(String message) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Course annulée', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary)),
        content: Text(message, style: const TextStyle(fontSize: 15, color: AppColors.darkTextSecondary)),
        actions: [SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
        )],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _callDriver() async {
    final phone = _getField(widget.driver, ['phone', 'phone_e164', 'phoneNumber']);
    if (phone == null || phone.isEmpty) { _snack('Numéro du chauffeur indisponible', isError: true); return; }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
    else _snack('Impossible d\'ouvrir le téléphone', isError: true);
  }

  void _openChat() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
      tripId: widget.tripId, otherUserName: _getDriverName(),
      otherUserAvatar: _getField(widget.driver, ['avatar', 'avatar_url']),
    )));
  }

  void _shareTrip() {
    final name  = _getDriverName();
    final plate = _vehicleInfo['plate'] ?? 'N/D';
    _snack('Course partagée : $name · $plate · arrivée $_eta');
  }

  Future<void> _cancelTrip() async {
    final feeText = _freeCancelExpired ? 'Des frais d\'annulation peuvent s\'appliquer.' : 'Annulation gratuite. Aucuns frais.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Annuler la course ?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Le chauffeur est en route.', style: TextStyle(fontSize: 15, color: AppColors.darkTextSecondary)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _freeCancelExpired ? AppColors.error.withOpacity(0.14) : AppColors.success.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _freeCancelExpired ? AppColors.error.withOpacity(0.4) : AppColors.success.withOpacity(0.4)),
            ),
            child: Row(children: [
              Icon(_freeCancelExpired ? Icons.warning_amber_rounded : Icons.check_circle, size: 18, color: _freeCancelExpired ? AppColors.error : AppColors.success),
              const SizedBox(width: 8),
              Expanded(child: Text(feeText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _freeCancelExpired ? AppColors.error : AppColors.success))),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Garder la course', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkTextSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Oui, annuler', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Provider.of<TripProvider>(context, listen: false).cancelTrip(widget.tripId, 'Annulée par le passager');
      _hasNavigated = true;
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: AppColors.darkTextPrimary)),
      backgroundColor: isError ? AppColors.error : AppColors.darkSurfaceAlt,
      behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _getDriverName() {
    final first = _getField(widget.driver, ['firstName', 'first_name']) ?? '';
    final last  = _getField(widget.driver, ['lastName',  'last_name'])  ?? '';
    final full  = '$first $last'.trim();
    return full.isNotEmpty ? full : 'Chauffeur';
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
      'type':      _getField(src, ['type', 'vehicleType']) ?? 'Standard',
      'plate':     _getField(src, ['plate', 'vehiclePlate', 'license_plate']) ?? 'N/D',
      'makeModel': _getField(src, ['makeModel', 'vehicle_make_model', 'make_model']) ?? 'Véhicule',
      'color':     _getField(src, ['color', 'vehicleColor', 'vehicle_color']) ?? 'Inconnu',
      'year':      _getField(src, ['year', 'vehicleYear', 'vehicle_year']) ?? '',
      'photo':     _getField(src, ['photo', 'vehicle_photo_url', 'vehiclePhoto']) ?? '',
    };
  }

  String get _driverRating => _getField(widget.driver, ['rating', 'rating_avg', 'ratingAvg']) ?? '4.8';

  int get _driverRideCount {
    final raw = widget.driver['total_trips'] ?? widget.driver['totalTrips'] ?? widget.driver['rides'];
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  String get _rateLabel => widget.vehicleType ?? _vehicleInfo['type'] ?? 'Standard Rate';

  String get _paymentLabel {
    final m = (widget.paymentMethod ?? 'cash').toLowerCase();
    switch (m) {
      case 'om':   return 'Orange Money';
      case 'momo': return 'MTN MoMo';
      default:     return 'Cash';
    }
  }

  IconData get _paymentIcon {
    final m = (widget.paymentMethod ?? 'cash').toLowerCase();
    if (m == 'om' || m == 'momo') return Icons.phone_android_rounded;
    return Icons.payments_rounded;
  }

  String get _freeCancelLabel {
    if (_driverHasArrived) return '';
    if (_freeCancelExpired) return 'Annulation gratuite expirée';
    final m = _freeCancelSecondsLeft ~/ 60;
    final s = _freeCancelSecondsLeft % 60;
    return 'Annulation gratuite : $m:${s.toString().padLeft(2, '0')}';
  }

  double _calcBearing(LatLng from, LatLng to) {
    final lat1 = _toRad(from.latitude);
    final lat2 = _toRad(to.latitude);
    final dLon = _toRad(to.longitude - from.longitude);
    final y    = math.sin(dLon) * math.cos(lat2);
    final x    = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
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

  Color _colorFromName(String name) {
    const map = {
      'black': Color(0xFF1a1a1a), 'noir': Color(0xFF1a1a1a),
      'white': Colors.white, 'blanc': Colors.white,
      'silver': Color(0xFFb0b0b0), 'argent': Color(0xFFb0b0b0), 'argenté': Color(0xFFb0b0b0),
      'grey': Colors.grey, 'gray': Colors.grey, 'gris': Colors.grey,
      'red': Colors.red, 'rouge': Colors.red,
      'blue': Color(0xFF1565C0), 'bleu': Color(0xFF1565C0),
      'green': Colors.green, 'vert': Colors.green,
      'yellow': Colors.yellow, 'jaune': Colors.yellow,
      'orange': Colors.orange,
      'brown': Colors.brown, 'marron': Colors.brown, 'brun': Colors.brown,
      'gold': AppColors.primaryGold, 'or': AppColors.primaryGold, 'doré': AppColors.primaryGold,
      'beige': Color(0xFFF5F5DC),
      'purple': Colors.purple, 'violet': Colors.purple,
      'pink': Colors.pink, 'rose': Colors.pink,
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
    final fallback = Container(
      width: size, height: size,
      decoration: BoxDecoration(color: AppColors.primaryGold, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Center(child: Text(initial, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
    );
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.cover, placeholder: (_, __) => fallback, errorWidget: (_, __, ___) => fallback),
    );
  }

  Widget _vehiclePhoto(String url, {double size = 80}) {
    if (url.isEmpty) {
      return Container(width: size, height: size * 0.65, decoration: BoxDecoration(color: AppColors.darkSurfaceHigh, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.directions_car, size: size * 0.4, color: AppColors.darkTextTertiary));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(imageUrl: url, width: size, height: size * 0.65, fit: BoxFit.cover,
          placeholder: (_, __) => Container(width: size, height: size * 0.65, color: AppColors.darkSurfaceHigh, child: Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold)))),
          errorWidget: (_, __, ___) => Container(width: size, height: size * 0.65, decoration: BoxDecoration(color: AppColors.darkSurfaceHigh, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.directions_car, size: size * 0.4, color: AppColors.darkTextTertiary))),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

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
                initialCenter: _animatedDriverLocation ?? widget.pickupLocation,
                initialZoom: 15,
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture && _isFollowingDriver) setState(() => _isFollowingDriver = false);
                },
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

          // Top status pill
          Positioned(
            top: MediaQuery.of(context).padding.top + 12, left: 0, right: 0,
            child: Center(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _driverHasArrived
                  ? const _ArrivedPill(key: ValueKey('arrived'))
                  : _EtaPill(key: const ValueKey('eta'), eta: _eta, pulseAnimation: _pulseAnim ?? const AlwaysStoppedAnimation(1.0)),
            )),
          ),

          // Re-center FAB
          if (!_isFollowingDriver)
            Positioned(
              bottom: MediaQuery.of(context).size.height * _kBottomSheetMinFrac + 16,
              right: 16,
              child: _RecenterFab(onTap: _recenterMap),
            ),

          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: _kBottomSheetMidFrac, minChildSize: _kBottomSheetMinFrac, maxChildSize: _kBottomSheetMaxFrac,
            snap: true, snapSizes: const [_kBottomSheetMinFrac, _kBottomSheetMidFrac, _kBottomSheetMaxFrac],
            builder: (context, scrollCtrl) {
              return SlideTransition(
                position: _slideAnim ?? const AlwaysStoppedAnimation(Offset.zero),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(top: BorderSide(color: AppColors.darkBorder.withOpacity(0.6))),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, -6))],
                  ),
                  child: ListView(
                    controller: scrollCtrl, padding: EdgeInsets.zero, physics: const ClampingScrollPhysics(),
                    children: [
                      // ── Drag handle ────────────────────────────────────
                      Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 42, height: 4, decoration: BoxDecoration(color: AppColors.darkSurfaceHigh, borderRadius: BorderRadius.circular(2)))),

                      // ── Promo banner ───────────────────────────────────
                      _PromoBanner(label: _rateLabel),

                      Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Header: status + ETA / arrived ──────────
                            _PeekSection(vehicleInfo: _vehicleInfo, eta: _eta, distance: _distance, driverHasArrived: _driverHasArrived, rateLabel: _rateLabel),
                            const SizedBox(height: 14),

                            // ── Arrived banner OR pickup row ─────────────
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SizeTransition(sizeFactor: anim, child: child)),
                              child: _driverHasArrived
                                  ? _ArrivedCardBanner(key: const ValueKey('banner'), animation: _arrivedBannerAnim ?? const AlwaysStoppedAnimation(1.0))
                                  : _PickupRow(key: const ValueKey('pickup'), address: widget.pickupAddress, distance: _distance),
                            ),
                            const SizedBox(height: 16),
                            Divider(height: 1, color: AppColors.darkDivider),
                            const SizedBox(height: 16),

                            // ── Driver row: avatar + name + actions ───────
                            Row(children: [
                              _driverAvatar(size: 54),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(_getDriverName(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.darkTextPrimary)),
                                const SizedBox(height: 3),
                                Row(children: [
                                  const Icon(Icons.star_rounded, size: 14, color: AppColors.primaryGold),
                                  const SizedBox(width: 3),
                                  Text(_driverRating, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkTextSecondary)),
                                  if (_driverRideCount > 0) ...[
                                    Text('  ·  ', style: TextStyle(color: AppColors.darkTextTertiary)),
                                    Text('$_driverRideCount rides', style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary)),
                                  ],
                                ]),
                              ])),
                              _RoundActionBtn(icon: Icons.call_rounded, iconColor: AppColors.success, bg: AppColors.success.withOpacity(0.16), onTap: _callDriver),
                              const SizedBox(width: 8),
                              _RoundActionBtn(icon: Icons.chat_bubble_rounded, iconColor: AppColors.primaryGold, bg: AppColors.primaryGold.withOpacity(0.16), onTap: _openChat),
                            ]),

                            const SizedBox(height: 16),

                            // ── Vehicle card ──────────────────────────────
                            _VehicleDetailCard(vehicleInfo: _vehicleInfo, colorFromName: _colorFromName, vehiclePhoto: _vehiclePhoto),

                            const SizedBox(height: 16),

                            // ── Payment row ───────────────────────────────
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.darkSurfaceAlt,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.darkBorder),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.darkSurfaceHigh,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(_paymentIcon, color: AppColors.primaryGold, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Payment Method', style: TextStyle(fontSize: 11, color: AppColors.darkTextTertiary)),
                                  const SizedBox(height: 2),
                                  Text(_paymentLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary)),
                                ])),
                                if (widget.fareEstimate != null)
                                  Text(widget.fareEstimate!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryGold)),
                              ]),
                            ),

                            const SizedBox(height: 20),

                            // ── Cancel / arrived note ─────────────────────
                            if (!_driverHasArrived) ...[
                              _CancelButton(label: _freeCancelLabel, isExpired: _freeCancelExpired, onTap: _cancelTrip),
                              const SizedBox(height: 8),
                            ],
                            if (_driverHasArrived)
                              Center(child: Text('Head to your pickup point', style: TextStyle(fontSize: 13, color: AppColors.darkTextTertiary, fontWeight: FontWeight.w500))),
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

class _PickupDot extends StatelessWidget {
  const _PickupDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
    );
  }
}

class _EtaPill extends StatelessWidget {
  final String eta;
  final Animation<double> pulseAnimation;
  const _EtaPill({super.key, required this.eta, required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (_, child) => Transform.scale(scale: pulseAnimation.value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkSurface, borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.darkBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primaryGold, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(eta, style: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('chauffeur en route', style: TextStyle(color: AppColors.darkTextTertiary, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
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
      decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))]),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8),
        Text('Votre chauffeur est arrivé !', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
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
      child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.darkSurface, shape: BoxShape.circle, border: Border.all(color: AppColors.darkBorder), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 2))]), child: const Icon(Icons.my_location_rounded, size: 22, color: AppColors.primaryGold)),
    );
  }
}

class _PeekSection extends StatelessWidget {
  final Map<String, String> vehicleInfo;
  final String eta;
  final double distance;
  final bool driverHasArrived;
  final String rateLabel;
  const _PeekSection({
    required this.vehicleInfo,
    required this.eta,
    required this.distance,
    required this.driverHasArrived,
    required this.rateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          driverHasArrived ? 'Your driver has arrived!' : 'Contacting the Driver',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.darkTextPrimary, letterSpacing: -0.3),
        ),
        const SizedBox(height: 3),
        Text(
          driverHasArrived
              ? 'Head to your pickup point'
              : (distance > 0 ? '${distance.toStringAsFixed(1)} km away  ·  $eta' : '$eta away'),
          style: const TextStyle(fontSize: 13, color: AppColors.darkTextSecondary, fontWeight: FontWeight.w500),
        ),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: AppColors.primaryGold, borderRadius: BorderRadius.circular(8)),
        child: Text(vehicleInfo['plate'] ?? '--',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
    ]);
  }
}

// ─── Promo Banner ─────────────────────────────────────────────────────────────

class _PromoBanner extends StatelessWidget {
  final String label;
  const _PromoBanner({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryGold,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.local_offer_rounded, color: Colors.black, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label · Fast & reliable ride',
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black,
            ),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
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
      decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkBorder)),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.success.withOpacity(0.16), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.location_on, color: AppColors.success, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Point de départ', style: TextStyle(fontSize: 11, color: AppColors.darkTextTertiary)),
          const SizedBox(height: 2),
          Text(address.length > 35 ? '${address.substring(0, 35)}…' : address, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (distance > 0) ...[
          const SizedBox(width: 8),
          Column(children: [
            Icon(Icons.straighten, size: 12, color: AppColors.darkTextTertiary), const SizedBox(height: 2),
            Text('${distance.toStringAsFixed(1)} km', style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary, fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }
}

class _ArrivedCardBanner extends StatelessWidget {
  final Animation<double> animation;
  const _ArrivedCardBanner({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) => Transform.scale(scale: (0.92 + animation.value * 0.08).clamp(0.0, 1.1), child: Opacity(opacity: animation.value.clamp(0.0, 1.0), child: child)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.success, const Color(0xFF2E7D32)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.location_on, color: Colors.white, size: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🎉 Votre chauffeur est arrivé !', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Rejoignez votre point de départ', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w500)),
          ])),
          _PulsingDot(),
        ]),
      ),
    );
  }
}

class _VehicleDetailCard extends StatelessWidget {
  final Map<String, String> vehicleInfo;
  final Color Function(String) colorFromName;
  final Widget Function(String, {double size}) vehiclePhoto;
  const _VehicleDetailCard({required this.vehicleInfo, required this.colorFromName, required this.vehiclePhoto});

  @override
  Widget build(BuildContext context) {
    final color    = colorFromName(vehicleInfo['color'] ?? '');
    final hasPhoto = (vehicleInfo['photo'] ?? '').isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.directions_car, size: 16, color: AppColors.darkTextSecondary), const SizedBox(width: 8),
          const Text('Votre véhicule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.darkTextSecondary)),
          const Spacer(),
          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: AppColors.darkBorder, width: 1))),
          const SizedBox(width: 6),
          Text(vehicleInfo['color'] ?? '', style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          vehiclePhoto(vehicleInfo['photo'] ?? '', size: hasPhoto ? 100 : 72),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vehicleInfo['makeModel'] ?? 'Véhicule', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary)),
            if ((vehicleInfo['year'] ?? '').isNotEmpty) ...[const SizedBox(height: 2), Text(vehicleInfo['year']!, style: TextStyle(fontSize: 13, color: AppColors.darkTextTertiary))],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: AppColors.darkSurfaceHigh, borderRadius: BorderRadius.circular(7), border: Border.all(color: AppColors.primaryGold, width: 2)),
              child: Text(vehicleInfo['plate'] ?? 'N/D', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3, color: AppColors.darkTextPrimary, fontFamily: 'Courier')),
            ),
          ])),
        ]),
      ]),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final String label;
  final bool isExpired;
  final VoidCallback onTap;
  const _CancelButton({required this.label, required this.isExpired, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        width: double.infinity, height: 50,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(side: BorderSide(color: isExpired ? AppColors.error.withOpacity(0.6) : AppColors.darkBorder, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          child: Text('Annuler la course', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isExpired ? AppColors.error : AppColors.darkTextPrimary)),
        ),
      ),
      if (label.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: isExpired ? AppColors.error : AppColors.darkTextTertiary, fontWeight: FontWeight.w500)),
      ],
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

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(milliseconds: 900), vsync: this)..repeat(reverse: true);
    _a = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.white.withOpacity(_a.value), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.white.withOpacity(_a.value * 0.5), blurRadius: 6, spreadRadius: 2)])),
    );
  }
}
// lib/screens/delivery agent/delivery_express/delivery_active_express_screen.dart
//
// Mapbox migration: flutter_map + latlong2 replacing google_maps_flutter.
// Preserved: stage machine, GPS emit, auto-reroute (50 m), pickup photo,
// PIN verification, cash confirmation, cancel flow, draggable sheet.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/car_marker_painter.dart';
import '../../../../utils/map_style.dart';
import '../../../../widgets/map_style_button.dart';
import '../delivery_active/delivery_active_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STAGE
// ─────────────────────────────────────────────────────────────────────────────

enum _XStage {
  accepted,
  en_route_pickup,
  arrived_pickup,
  picked_up,
  en_route_dropoff,
  arrived_dropoff,
  delivered;

  static _XStage fromString(String s) {
    switch (s) {
      case 'en_route_pickup':  return _XStage.en_route_pickup;
      case 'arrived_pickup':   return _XStage.arrived_pickup;
      case 'picked_up':        return _XStage.picked_up;
      case 'en_route_dropoff': return _XStage.en_route_dropoff;
      case 'arrived_dropoff':  return _XStage.arrived_dropoff;
      case 'delivered':        return _XStage.delivered;
      default:                 return _XStage.accepted;
    }
  }

  String get apiValue => name;

  _XStage? get next {
    switch (this) {
      case _XStage.accepted:         return _XStage.en_route_pickup;
      case _XStage.en_route_pickup:  return _XStage.arrived_pickup;
      case _XStage.arrived_pickup:   return _XStage.picked_up;
      case _XStage.picked_up:        return _XStage.en_route_dropoff;
      case _XStage.en_route_dropoff: return _XStage.arrived_dropoff;
      case _XStage.arrived_dropoff:  return null; // PIN dialog
      default:                       return null;
    }
  }

  String get actionLabel {
    switch (this) {
      case _XStage.accepted:         return tr('dstage.startHeadPickup');
      case _XStage.en_route_pickup:  return tr('dstage.arrivedPickupShort');
      case _XStage.arrived_pickup:   return tr('dstage.packagePickedUp');
      case _XStage.picked_up:        return tr('dstage.enRouteDropoff');
      case _XStage.en_route_dropoff: return tr('dstage.arrivedAtDropoff');
      case _XStage.arrived_dropoff:  return tr('agent.enterPin');
      default:                       return '';
    }
  }

  String get statusLabel {
    switch (this) {
      case _XStage.accepted:         return tr('dstage.headToPickup');
      case _XStage.en_route_pickup:  return tr('dstage.onWayPickup');
      case _XStage.arrived_pickup:   return tr('dstage.atPickupCollect');
      case _XStage.picked_up:        return tr('dstage.packageCollected');
      case _XStage.en_route_dropoff: return tr('dstage.headingDropoff');
      case _XStage.arrived_dropoff:  return tr('dstage.atDropoffAskPin');
      case _XStage.delivered:        return tr('dstage.deliveredCheck');
    }
  }

  Color get color {
    switch (this) {
      case _XStage.accepted:
      case _XStage.en_route_pickup:  return AppColors.info;
      case _XStage.arrived_pickup:
      case _XStage.picked_up:        return AppColors.warning;
      case _XStage.en_route_dropoff:
      case _XStage.arrived_dropoff:  return AppColors.primaryGold;
      case _XStage.delivered:        return AppColors.success;
    }
  }

  bool get isPrePickup =>
      [_XStage.accepted, _XStage.en_route_pickup, _XStage.arrived_pickup]
          .contains(this);

  bool get headingToPickup =>
      [_XStage.accepted, _XStage.en_route_pickup, _XStage.arrived_pickup]
          .contains(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryActiveExpressScreen extends StatefulWidget {
  final ActiveDelivery delivery;
  final io.Socket?     socket;

  const DeliveryActiveExpressScreen({
    super.key,
    required this.delivery,
    this.socket,
  });

  @override
  State<DeliveryActiveExpressScreen> createState() =>
      _DeliveryActiveExpressScreenState();
}

class _DeliveryActiveExpressScreenState
    extends State<DeliveryActiveExpressScreen>
    with TickerProviderStateMixin {

  // ── Auth ─────────────────────────────────────────────────────────────────
  String _accessToken = '';

  // ── Stage ────────────────────────────────────────────────────────────────
  late _XStage _stage;
  bool _transitioning = false;

  // ── Map ──────────────────────────────────────────────────────────────────
  final MapController _mapCtrl   = MapController();
  LatLng?             _driverPos;
  double              _driverBearing  = 0;
  bool                _isFollowing    = true;
  LatLng?             _lastCameraPos;

  // ── Route ─────────────────────────────────────────────────────────────────
  List<Polyline> _polylines     = [];
  bool           _fetchingRoute = false;
  LatLng?        _lastRouteOrigin;

  // ── GPS ──────────────────────────────────────────────────────────────────
  Timer? _gpsTimer;

  // ── Bottom sheet ─────────────────────────────────────────────────────────
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  static const double _sheetMinSize = 0.22;
  static const double _sheetMidSize = 0.42;

  // ── Pickup photo ─────────────────────────────────────────────────────────
  File?   _pickupPhoto;
  String? _pickupPhotoUrl;
  bool    _uploadingPhoto = false;
  final   _picker = ImagePicker();

  // ── PIN ──────────────────────────────────────────────────────────────────
  final _pinCtrl  = TextEditingController();
  bool  _verifyingPin = false;
  String? _pinError;

  // ── Cancel / states ───────────────────────────────────────────────────────
  bool _cancelling          = false;
  bool _cancelledExternally = false;
  bool _confirmingCash      = false;
  bool _cashConfirmed       = false;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  static const _mapBottomPadding = 220.0;

  String get _liqKey => dotenv.env['LOCATIONIQ_KEY'] ?? '';
  MapStyle _mapStyle = MapStyle.streets;

  @override
  void initState() {
    super.initState();
    _stage = _XStage.fromString(widget.delivery.status);
    loadMapStylePref().then((s) { if (mounted) setState(() => _mapStyle = s); });

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _init();
  }

  Future<void> _init() async {
    final prefs  = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token') ?? '';
    _listenSocket();
    _startGps();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _gpsTimer?.cancel();
    _pinCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MARKERS
  // ─────────────────────────────────────────────────────────────────────────

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Pickup pin — bright green pre-pickup, faded after
    markers.add(Marker(
      point:  LatLng(widget.delivery.pickupLat, widget.delivery.pickupLng),
      width:  40,
      height: 50,
      child: Opacity(
        opacity: _stage.isPrePickup ? 1.0 : 0.4,
        child: const Icon(Icons.inventory_2_rounded,
            color: AppColors.success, size: 36),
      ),
    ));

    // Dropoff pin — bright gold post-pickup, faded before
    markers.add(Marker(
      point:  LatLng(widget.delivery.dropoffLat, widget.delivery.dropoffLng),
      width:  40,
      height: 50,
      child: Opacity(
        opacity: !_stage.isPrePickup ? 1.0 : 0.4,
        child: const Icon(Icons.flag_rounded,
            color: AppColors.primaryGold, size: 36),
      ),
    ));

    // Driver marker (CarMarkerWidget)
    if (_driverPos != null) {
      markers.add(Marker(
        point:  _driverPos!,
        width:  56,
        height: 56,
        child: CarMarkerWidget(
          heading: _driverBearing,
          color:   AppColors.primaryDark,
        ),
      ));
    }

    return markers;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GPS — 3 s interval for express
  // ─────────────────────────────────────────────────────────────────────────

  void _startGps() {
    _sendLocation();
    _gpsTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => _sendLocation());
  }

  Future<void> _sendLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      final latLng  = LatLng(pos.latitude, pos.longitude);
      final bearing = pos.heading >= 0 ? pos.heading : _driverBearing;

      widget.socket?.emit('driver:location_update', {
        'lat':             pos.latitude,
        'lng':             pos.longitude,
        'heading':         pos.heading,
        'speed_kmh':       (pos.speed * 3.6).clamp(0, 200),
        'accuracy_meters': pos.accuracy,
      });

      if (mounted) setState(() { _driverPos = latLng; _driverBearing = bearing; });

      _smoothFollowDriver(latLng, bearing);
      _maybeRefreshRoute(latLng);
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAMERA
  // ─────────────────────────────────────────────────────────────────────────

  void _smoothFollowDriver(LatLng pos, double bearing) {
    if (!_isFollowing) return;
    if (_lastCameraPos != null) {
      final dist = Geolocator.distanceBetween(
        _lastCameraPos!.latitude, _lastCameraPos!.longitude,
        pos.latitude, pos.longitude,
      );
      if (dist < 5) return;
    }
    _lastCameraPos = pos;
    try { _mapCtrl.move(pos, 16.5); } catch (_) {}
  }

  void _recenter() {
    if (_driverPos == null) return;
    setState(() => _isFollowing = true);
    _lastCameraPos = null;
    try { _mapCtrl.move(_driverPos!, 16.5); } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROUTE — Mapbox Directions v5
  // ─────────────────────────────────────────────────────────────────────────

  void _maybeRefreshRoute(LatLng driverPos) {
    if (_lastRouteOrigin != null) {
      final moved = Geolocator.distanceBetween(
        _lastRouteOrigin!.latitude, _lastRouteOrigin!.longitude,
        driverPos.latitude,          driverPos.longitude,
      );
      if (moved < 50) return;
    }
    _lastRouteOrigin = driverPos;
    _fetchRoute(driverPos);
  }

  Future<void> _fetchRoute(LatLng from) async {
    if (_fetchingRoute) return;
    _fetchingRoute = true;

    final dest = _stage.headingToPickup
        ? LatLng(widget.delivery.pickupLat,  widget.delivery.pickupLng)
        : LatLng(widget.delivery.dropoffLat, widget.delivery.dropoffLng);

    try {
      final uri = Uri.parse(
        'https://us1.locationiq.com/v1/directions/driving/'
        '${from.longitude},${from.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?key=$_liqKey'
        '&geometries=polyline'
        '&overview=full',
      );

      final res =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data   = jsonDecode(res.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final encoded = routes[0]['geometry'] as String;
          final points  = _decodePolyline(encoded);
          if (mounted) {
            setState(() {
              _polylines = [
                Polyline(
                  points:      points,
                  color:       _stage.headingToPickup
                      ? AppColors.info
                      : AppColors.primaryGold,
                  strokeWidth: 5,
                  strokeCap:   StrokeCap.round,
                  strokeJoin:  StrokeJoin.round,
                ),
              ];
            });
          }
        }
      }
    } catch (_) {
      // Route unavailable — map still functional
    }

    _fetchingRoute = false;
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int shift = 0, result = 0, b;
      do {
        b       = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift  += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0; result = 0;
      do {
        b       = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift  += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCKET
  // ─────────────────────────────────────────────────────────────────────────

  void _listenSocket() {
    widget.socket?.on('delivery:cancelled', (_) {
      if (!mounted) return;
      setState(() => _cancelledExternally = true);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) Navigator.of(context).pop();
      });
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE TRANSITION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _advanceStage() async {
    if (_transitioning) return;

    if (_stage == _XStage.arrived_dropoff) {
      _showPinDialog();
      return;
    }

    final nextStage = _stage.next;
    if (nextStage == null) return;

    if (nextStage == _XStage.picked_up &&
        _pickupPhoto != null &&
        _pickupPhotoUrl == null) {
      await _uploadPickupPhoto();
    }

    setState(() => _transitioning = true);

    final body = <String, dynamic>{'status': nextStage.apiValue};
    if (nextStage == _XStage.picked_up && _pickupPhotoUrl != null) {
      body['pickup_photo_url'] = _pickupPhotoUrl;
    }

    try {
      final res = await http.post(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/deliveries/${widget.delivery.id}/status'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type':  'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 12));

      final resBody = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && resBody['success'] == true) {
        setState(() => _stage = nextStage);

        if (nextStage == _XStage.en_route_dropoff && _driverPos != null) {
          _lastRouteOrigin = null;
          _fetchRoute(_driverPos!);
        }
        if (nextStage == _XStage.en_route_pickup && _driverPos != null) {
          _lastRouteOrigin = null;
          _fetchRoute(_driverPos!);
        }

        _showSnack(nextStage.statusLabel, isError: false);
      } else {
        _showSnack(
            resBody['message'] as String? ?? 'Failed', isError: true);
      }
    } catch (_) {
      _showSnack('Network error. Try again.', isError: true);
    }

    if (mounted) setState(() => _transitioning = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PICKUP PHOTO
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickPickupPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source:       ImageSource.camera,
        maxWidth:     1920,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _pickupPhoto = File(picked.path));
      }
    } on PlatformException catch (e) {
      _showSnack('Camera: ${e.message}', isError: true);
    }
  }

  Future<void> _uploadPickupPhoto() async {
    if (_pickupPhoto == null || _uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiBaseUrl}/upload/package-photo'),
      )
        ..headers['Authorization'] = 'Bearer $_accessToken'
        ..files.add(await http.MultipartFile.fromPath(
          'image', _pickupPhoto!.path,
          contentType: MediaType('image', 'jpeg'),
        ));

      final streamed =
          await request.send().timeout(const Duration(seconds: 20));
      final res  = await http.Response.fromStream(streamed);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['url'] != null) {
        _pickupPhotoUrl = body['url'] as String;
      }
    } catch (_) {}

    if (mounted) setState(() => _uploadingPhoto = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PIN DIALOG
  // ─────────────────────────────────────────────────────────────────────────

  void _showPinDialog() {
    _pinCtrl.clear();
    _pinError = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDS) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pin_rounded,
                      color: AppColors.primaryGold, size: 28),
                ),
                const SizedBox(height: 16),
                Text(tr('agent.enterPin'),
                    style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Ask ${widget.delivery.recipientName} for the 4-digit PIN.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Quicksand', fontSize: 12,
                      color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller:     _pinCtrl,
                  keyboardType:   TextInputType.number,
                  maxLength:      4,
                  textAlign:      TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontFamily: 'LeagueSpartan', fontSize: 32,
                      fontWeight: FontWeight.w800, letterSpacing: 12),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText:    '••••',
                    hintStyle: TextStyle(
                        color: AppColors.borderMedium,
                        fontSize: 32, letterSpacing: 12),
                    filled:    true,
                    fillColor: AppColors.backgroundLight,
                    border:    OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:   BorderSide.none),
                    errorText: _pinError,
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _verifyingPin ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(
                            color: AppColors.borderMedium),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(tr('agent.back'),
                          style: TextStyle(fontFamily: 'LeagueSpartan',
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _verifyingPin ? null : () async {
                        if (_pinCtrl.text.length != 4) {
                          setDS(() => _pinError = 'Enter 4 digits');
                          return;
                        }
                        setDS(() { _verifyingPin = true; _pinError = null; });
                        await _verifyPin(ctx, setDS);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _verifyingPin
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : Text(tr('common.confirm'),
                              style: TextStyle(fontFamily: 'LeagueSpartan',
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verifyPin(BuildContext dCtx, StateSetter setDS) async {
    try {
      final res = await http.post(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/deliveries/${widget.delivery.id}/verify-pin'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({'pin': _pinCtrl.text.trim()}),
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        if (mounted) Navigator.pop(dCtx);
        _gpsTimer?.cancel();
        setState(() => _stage = _XStage.delivered);
        return;
      }
      setDS(() {
        _pinError     = body['message'] as String? ?? 'Incorrect PIN';
        _verifyingPin = false;
      });
    } catch (_) {
      setDS(() { _pinError = 'Network error'; _verifyingPin = false; });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CANCEL
  // ─────────────────────────────────────────────────────────────────────────

  void _showCancelConfirm() {
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('agent.cancelDeliveryQ'),
                    style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'You will lose the commission fee as a cancellation penalty.',
                  style: TextStyle(fontFamily: 'Quicksand', fontSize: 12,
                      color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelDelivery();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white, elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text(tr('delivery.yesCancel'),
                        style: TextStyle(fontFamily: 'LeagueSpartan',
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.borderMedium),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text(tr('agent.keepDelivery'),
                        style: TextStyle(fontFamily: 'LeagueSpartan',
                            fontWeight: FontWeight.w600,
                            color:      AppColors.textSecondary)),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Future<void> _cancelDelivery() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    try {
      final res = await http.post(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/deliveries/${widget.delivery.id}/cancel'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({'reason': 'Driver cancelled'}),
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        _gpsTimer?.cancel();
        if (mounted) Navigator.of(context).pop();
        return;
      }
      _showSnack(
          (jsonDecode(res.body) as Map)['message'] as String?
              ?? 'Cannot cancel',
          isError: true);
    } catch (_) { _showSnack('Network error', isError: true); }
    if (mounted) setState(() => _cancelling = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIRM CASH
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _confirmCash() async {
    if (_confirmingCash) return;
    setState(() => _confirmingCash = true);
    try {
      final res = await http.post(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/deliveries/${widget.delivery.id}/confirm-cash'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        setState(() { _cashConfirmed = true; _confirmingCash = false; });
        _showSnack('Cash confirmed!', isError: false);
        return;
      }
    } catch (_) {}
    _showSnack('Failed', isError: true);
    if (mounted) setState(() => _confirmingCash = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg,
          style: const TextStyle(fontFamily: 'Quicksand')),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _fmt(double xaf) =>
      '${xaf.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} XAF';

  Future<void> _callRecipient() async {
    final phone = widget.delivery.recipientPhone;
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cancelledExternally) return _buildCancelledView();
    if (_stage == _XStage.delivered)  return _buildDeliveredView();

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildTopHud(),
          MapStyleButton(
            current: _mapStyle,
            onChanged: (s) { setState(() => _mapStyle = s); saveMapStylePref(s); },
            bottom: _mapBottomPadding + 130,
          ),
          Positioned(
            right:  16,
            bottom: _mapBottomPadding + 16,
            child:  _buildRecenterButton(),
          ),
          if (_stage.isPrePickup)
            Positioned(
              right:  16,
              bottom: _mapBottomPadding + 72,
              child:  _buildPhotoFab(),
            ),
          _buildDraggableSheet(),
        ],
      ),
    );
  }

  // ── Map ────────────────────────────────────────────────────────────────────

  Widget _buildMap() {
    final center = _driverPos
        ?? LatLng(widget.delivery.pickupLat, widget.delivery.pickupLng);

    return Positioned.fill(
      child: FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(
          initialCenter: center,
          initialZoom:   15,
          onPositionChanged: (_, hasGesture) {
            if (hasGesture && _isFollowing) {
              setState(() => _isFollowing = false);
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: _mapStyle.tileUrl(_liqKey),
            userAgentPackageName: 'com.wego.app',
            tileProvider:         NetworkTileProvider(),
          ),
          PolylineLayer(polylines: _polylines),
          MarkerLayer(markers: _buildMarkers()),
        ],
      ),
    );
  }

  // ── Top HUD ────────────────────────────────────────────────────────────────

  Widget _buildTopHud() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(
                    color:      Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset:     const Offset(0, 4))],
              ),
              child: Row(children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Transform.scale(
                    scale: _pulse.value,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _stage.color,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color:       _stage.color.withOpacity(0.6),
                            blurRadius:  6,
                            spreadRadius: 1)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.bolt_rounded,
                    color: AppColors.primaryGold, size: 14),
                const SizedBox(width: 4),
                Text(widget.delivery.deliveryCode,
                    style: const TextStyle(fontFamily: 'LeagueSpartan',
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color:    Colors.white)),
                const SizedBox(width: 6),
                Text(_stage.statusLabel,
                    style: TextStyle(fontFamily: 'Quicksand',
                        fontSize: 10, color: _stage.color)),
              ]),
            ),
            const Spacer(),
            if (_stage.isPrePickup)
              GestureDetector(
                onTap: _showCancelConfirm,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color:      Colors.black.withOpacity(0.15),
                        blurRadius: 8)],
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.error, size: 20),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRecenterButton() {
    return GestureDetector(
      onTap: _recenter,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.15), blurRadius: 8)],
        ),
        child: const Icon(Icons.my_location_rounded,
            color: AppColors.primaryDark, size: 20),
      ),
    );
  }

  Widget _buildPhotoFab() {
    return GestureDetector(
      onTap: _pickupPhoto == null ? _pickPickupPhoto : null,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _pickupPhotoUrl != null
              ? AppColors.success
              : _pickupPhoto != null
                  ? AppColors.warning
                  : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.15), blurRadius: 8)],
        ),
        child: Icon(
          _pickupPhotoUrl != null
              ? Icons.check_rounded
              : Icons.camera_alt_rounded,
          color: _pickupPhoto != null
              ? Colors.white
              : AppColors.primaryDark,
          size: 20,
        ),
      ),
    );
  }

  // ── Draggable bottom sheet ─────────────────────────────────────────────────

  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      controller:       _sheetCtrl,
      initialChildSize: _sheetMinSize,
      minChildSize:     _sheetMinSize,
      maxChildSize:     0.75,
      snap:             true,
      snapSizes:        const [_sheetMinSize, _sheetMidSize, 0.75],
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(
                color:      Colors.black12,
                blurRadius: 24,
                offset:     Offset(0, -4))],
          ),
          child: ListView(
            controller: scrollCtrl,
            physics:    const ClampingScrollPhysics(),
            padding:    EdgeInsets.zero,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  decoration: BoxDecoration(
                      color:        AppColors.borderMedium,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _buildActionButton(),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child:   _buildRouteRow(),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child:   _buildPackageRow(),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child:   _buildRecipientRow(),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child:   _buildFinancialsRow(),
              ),
              if (_stage.isPrePickup) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child:   _buildPickupPhotoSection(),
                ),
              ],
              if (_stage == _XStage.arrived_dropoff) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child:   _buildPinHint(),
                ),
              ],
              SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _transitioning ? null : _advanceStage,
        style: ElevatedButton.styleFrom(
          backgroundColor: _stage.color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.borderMedium,
          padding: const EdgeInsets.symmetric(vertical: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _transitioning
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(_stage.actionLabel,
                      style: const TextStyle(fontFamily: 'LeagueSpartan',
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
      ),
    );
  }

  Widget _buildRouteRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.primaryDark, shape: BoxShape.circle)),
          Container(width: 1.5, height: 24, color: AppColors.borderMedium,
              margin: const EdgeInsets.symmetric(vertical: 3)),
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(
                  color: AppColors.success, shape: BoxShape.circle)),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.delivery.pickupAddress,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Quicksand', fontSize: 12,
                      color: _stage.isPrePickup
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: _stage.isPrePickup
                          ? FontWeight.w600 : FontWeight.w400)),
              const SizedBox(height: 20),
              Text(widget.delivery.dropoffAddress,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Quicksand', fontSize: 12,
                      color: !_stage.isPrePickup
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: !_stage.isPrePickup
                          ? FontWeight.w600 : FontWeight.w400)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPackageRow() {
    return Row(children: [
      Text(widget.delivery.categoryEmoji,
          style: const TextStyle(fontSize: 22)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '${widget.delivery.categoryLabel} · '
            '${widget.delivery.packageSize[0].toUpperCase()}'
            '${widget.delivery.packageSize.substring(1)}'
            '${widget.delivery.isFragile ? ' · 🏺 Fragile' : ''}',
            style: const TextStyle(fontFamily: 'Quicksand', fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          if (widget.delivery.packageDescription != null)
            Text(widget.delivery.packageDescription!,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Quicksand', fontSize: 11,
                    color: AppColors.textSecondary)),
        ]),
      ),
    ]);
  }

  Widget _buildRecipientRow() {
    return Row(children: [
      Container(
        width: 34, height: 34,
        decoration: const BoxDecoration(
            color: AppColors.primaryDark, shape: BoxShape.circle),
        child: Center(
          child: Text(
            widget.delivery.recipientName.isNotEmpty
                ? widget.delivery.recipientName[0].toUpperCase()
                : 'R',
            style: const TextStyle(fontFamily: 'LeagueSpartan', fontSize: 14,
                fontWeight: FontWeight.w800,
                color:      AppColors.primaryGold),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.delivery.recipientName,
              style: const TextStyle(fontFamily: 'Quicksand', fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Text(widget.delivery.recipientPhone,
              style: TextStyle(fontFamily: 'Quicksand', fontSize: 11,
                  color: AppColors.textSecondary)),
        ]),
      ),
      GestureDetector(
        onTap: _callRecipient,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color:  AppColors.success.withOpacity(0.1),
              shape:  BoxShape.circle),
          child: const Icon(Icons.phone_rounded,
              color: AppColors.success, size: 17),
        ),
      ),
    ]);
  }

  Widget _buildFinancialsRow() {
    return Row(children: [
      _finStat('Your Payout',  _fmt(widget.delivery.driverPayout),
          AppColors.success),
      const SizedBox(width: 12),
      _finStat('Commission',   _fmt(widget.delivery.commissionAmount),
          AppColors.warning),
      const SizedBox(width: 12),
      _finStat('Payment',
          widget.delivery.paymentMethod == 'cash' ? '💵 Cash' : '📱 Mobile',
          AppColors.info),
    ]);
  }

  Widget _finStat(String label, String value, Color color) => Expanded(
    child: Column(children: [
      Text(value,
          style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 11,
              fontWeight: FontWeight.w700, color: color),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(fontFamily: 'Quicksand', fontSize: 9,
              color: AppColors.textSecondary)),
    ]),
  );

  Widget _buildPickupPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('agent.pickupPhotoOpt'),
            style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickPickupPhoto,
          child: _pickupPhoto != null
              ? Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_pickupPhoto!, width: double.infinity,
                        height: 100, fit: BoxFit.cover),
                  ),
                  if (_pickupPhotoUrl != null)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: AppColors.success, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ),
                ])
              : Container(
                  height: 60,
                  decoration: BoxDecoration(
                      color:        AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: AppColors.borderMedium)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_rounded,
                          color: AppColors.textSecondary, size: 18),
                      SizedBox(width: 8),
                      Text(tr('agent.takePickupPhoto'),
                          style: TextStyle(fontFamily: 'Quicksand', fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPinHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Row(children: [
        Text('🔐', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Ask ${widget.delivery.recipientName} for the 4-digit PIN '
            'before handing over the package.',
            style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11,
                color: AppColors.warning, height: 1.4),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELIVERED VIEW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDeliveredView() {
    final isCash = widget.delivery.paymentMethod == 'cash';
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 50),
            ),
            const SizedBox(height: 20),
            Text('⚡ Express Delivery Complete!',
                style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(widget.delivery.deliveryCode,
                style: TextStyle(fontFamily: 'Quicksand', fontSize: 13,
                    color: AppColors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(children: [
                _completionStat('💰 Your Payout',
                    _fmt(widget.delivery.driverPayout), AppColors.success),
                const SizedBox(height: 10),
                _completionStat('🏢 Commission',
                    _fmt(widget.delivery.commissionAmount), AppColors.warning),
                const SizedBox(height: 10),
                _completionStat('📦 Recipient',
                    widget.delivery.recipientName, AppColors.info),
              ]),
            ),
            if (isCash && !_cashConfirmed) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        AppColors.warningLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.warning.withOpacity(0.4)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('💵 Confirm cash received',
                          style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:      AppColors.warning)),
                      const SizedBox(height: 4),
                      Text(
                        'Confirm you received ${_fmt(widget.delivery.totalPrice)} '
                        'from ${widget.delivery.recipientName}.',
                        style: const TextStyle(fontFamily: 'Quicksand', fontSize: 11,
                            color: AppColors.warning, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirmingCash ? null : _confirmCash,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.white, elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          child: _confirmingCash
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : Text(tr('agent.confirmCash'),
                                  style: TextStyle(fontFamily: 'LeagueSpartan',
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
              ),
            ],
            if (isCash && _cashConfirmed) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color:        AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded,
                        color: AppColors.success, size: 15),
                    SizedBox(width: 6),
                    Text(tr('agent.cashConfirmed'),
                        style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:      AppColors.success)),
                  ],
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: Text(tr('agent.backToDashboard'),
                    style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _completionStat(String label, String value, Color color) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(fontFamily: 'Quicksand', fontSize: 12,
                color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 13,
                fontWeight: FontWeight.w700, color: color)),
      ]);

  // ─────────────────────────────────────────────────────────────────────────
  // CANCELLED VIEW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCancelledView() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.cancel_rounded,
                    color: AppColors.error, size: 40),
              ),
              const SizedBox(height: 20),
              Text(tr('agent.deliveryCancelled'),
                  style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'This express delivery was cancelled. '
                'Your commission has been released.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Quicksand', fontSize: 13,
                    color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: Text(tr('agent.backToDashboard'),
                    style: TextStyle(fontFamily: 'LeagueSpartan',
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// lib/screens/passenger/delivery/delivery express/express_delivery.dart
//
// EXPRESS DELIVERY TRACKING (passenger-side)
// Mapbox migration: flutter_map + latlong2 replacing google_maps_flutter.
// Live driver position updates via socket. All logic preserved.

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../l10n/tr.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/app_typography.dart';
import '../../../../utils/map_style.dart';
import '../../../../widgets/map_style_button.dart';
import '../../../../core/config.dart';

class DeliveryTrackingExpress extends StatefulWidget {
  final Map<String, dynamic> delivery;
  final String accessToken;

  const DeliveryTrackingExpress({
    super.key,
    required this.delivery,
    required this.accessToken,
  });

  @override
  State<DeliveryTrackingExpress> createState() =>
      _DeliveryTrackingExpressState();
}

class _DeliveryTrackingExpressState extends State<DeliveryTrackingExpress>
    with SingleTickerProviderStateMixin {

  final MapController _mapCtrl = MapController();
  io.Socket?          _socket;

  // ── Map state ──────────────────────────────────────────────────────────────
  LatLng?        _driverPosition;
  List<Marker>   _markers       = [];
  List<Polyline> _polylines     = [];
  bool           _fetchingRoute = false;
  LatLng?        _lastRouteOrigin;

  String get _liqKey => dotenv.env['LOCATIONIQ_KEY'] ?? '';
  MapStyle _mapStyle = MapStyle.streets;

  // ── Delivery state ─────────────────────────────────────────────────────────
  String  _currentStatus = 'accepted';
  bool    _delivered     = false;
  bool    _cancelled     = false;
  String? _cancelReason;
  Map<String, dynamic>? _driver;

  // ── Bottom sheet animation ─────────────────────────────────────────────────
  late AnimationController _sheetCtrl;
  late Animation<double>   _sheetAnim;

  static const _stageLabels = {
    'accepted':         ('✅', 'Driver accepted your delivery'),
    'en_route_pickup':  ('🚗', 'Driver is heading to pickup'),
    'arrived_pickup':   ('📍', 'Driver arrived at pickup'),
    'picked_up':        ('📦', 'Package picked up'),
    'en_route_dropoff': ('🚀', 'Driver heading to recipient'),
    'arrived_dropoff':  ('🏁', 'Driver at destination'),
    'delivered':        ('🎉', 'Package delivered!'),
  };

  // ── Map coords ─────────────────────────────────────────────────────────────
  late LatLng _pickupLatLng;
  late LatLng _dropoffLatLng;

  @override
  void initState() {
    super.initState();
    _sheetCtrl = AnimationController(
        duration: const Duration(milliseconds: 350), vsync: this);
    _sheetAnim =
        CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOut);
    _sheetCtrl.forward();
    loadMapStylePref().then((s) { if (mounted) setState(() => _mapStyle = s); });

    _currentStatus = widget.delivery['status'] as String? ?? 'accepted';
    _driver        = widget.delivery['driver'] as Map<String, dynamic>?;

    _pickupLatLng = LatLng(
      (widget.delivery['pickupLat']  as num?)?.toDouble() ?? 4.0511,
      (widget.delivery['pickupLng']  as num?)?.toDouble() ?? 9.7679,
    );
    _dropoffLatLng = LatLng(
      (widget.delivery['dropoffLat'] as num?)?.toDouble() ?? 4.0611,
      (widget.delivery['dropoffLng'] as num?)?.toDouble() ?? 9.7779,
    );

    _buildMarkers();
    _connectSocket();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(
          const Duration(milliseconds: 400), _fitMapToBoth);
    });
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAP
  // ─────────────────────────────────────────────────────────────────────────

  void _buildMarkers() {
    final markers = <Marker>[
      Marker(
        point:  _pickupLatLng,
        width:  40,
        height: 50,
        child: const Icon(Icons.location_on, color: Colors.green, size: 40),
      ),
      Marker(
        point:  _dropoffLatLng,
        width:  40,
        height: 50,
        child: const Icon(Icons.flag_rounded, color: Colors.red, size: 40),
      ),
    ];

    if (_driverPosition != null) {
      markers.add(Marker(
        point:  _driverPosition!,
        width:  36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color:  AppColors.primaryDark,
            shape:  BoxShape.circle,
            border: Border.all(color: AppColors.primaryGold, width: 2),
          ),
          child: const Icon(Icons.delivery_dining_rounded,
              color: AppColors.primaryGold, size: 20),
        ),
      ));
    }

    setState(() => _markers = markers);
  }

  void _updateDriverMarker(double lat, double lng) {
    final pos = LatLng(lat, lng);
    setState(() => _driverPosition = pos);
    _buildMarkers();
    _maybeRefreshRoute(pos);
    try { _mapCtrl.move(pos, 14); } catch (_) {}
  }

  void _maybeRefreshRoute(LatLng driverPos) {
    if (_lastRouteOrigin != null) {
      final dLat = (_lastRouteOrigin!.latitude  - driverPos.latitude).abs();
      final dLng = (_lastRouteOrigin!.longitude - driverPos.longitude).abs();
      if (dLat < 0.0005 && dLng < 0.0005) return; // ~50 m threshold
    }
    _lastRouteOrigin = driverPos;
    _fetchRoute(driverPos);
  }

  Future<void> _fetchRoute(LatLng from) async {
    if (_fetchingRoute) return;
    _fetchingRoute = true;
    final dest = _dropoffLatLng;
    try {
      final uri = Uri.parse(
        'https://us1.locationiq.com/v1/directions/driving/'
        '${from.longitude},${from.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?key=$_liqKey&geometries=polyline&overview=full',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data   = jsonDecode(res.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final points = _decodePolyline(routes[0]['geometry'] as String);
          if (mounted) {
            setState(() {
              _polylines = [
                Polyline(
                  points:      points,
                  color:       AppColors.primaryGold,
                  strokeWidth: 4,
                  strokeCap:   StrokeCap.round,
                  strokeJoin:  StrokeJoin.round,
                ),
              ];
            });
          }
        }
      }
    } catch (_) {}
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

  Future<void> _callDriver() async {
    final phone = _driver?['phone'] as String?;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }

  void _fitMapToBoth() {
    try {
      final points = [_pickupLatLng, _dropoffLatLng];
      if (_driverPosition != null) points.add(_driverPosition!);
      _mapCtrl.fitCamera(CameraFit.bounds(
        bounds:  LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(80),
      ));
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCKET
  // ─────────────────────────────────────────────────────────────────────────

  void _connectSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? widget.accessToken;

    _socket = io.io(AppConfig.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .disableAutoConnect()
            .build());

    _socket!.connect();

    _socket!.on('delivery:driver_location', (data) {
      if (!mounted) return;
      final d   = data as Map<String, dynamic>;
      final lat = (d['lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) _updateDriverMarker(lat, lng);
    });

    _socket!.on('delivery:status_update', (data) {
      if (!mounted) return;
      final status = (data as Map<String, dynamic>)['status'] as String?;
      if (status != null) setState(() => _currentStatus = status);
    });

    _socket!.on('delivery:completed', (_) {
      if (!mounted) return;
      setState(() { _currentStatus = 'delivered'; _delivered = true; });
    });

    _socket!.on('delivery:cancelled', (data) {
      if (!mounted) return;
      final d = data as Map<String, dynamic>;
      setState(() {
        _cancelled    = true;
        _cancelReason = d['message'] as String?;
      });
    });

    _socket!.on('delivery:driver_assigned', (data) {
      if (!mounted) return;
      final d = data as Map<String, dynamic>;
      if (d['driver'] != null) {
        setState(() => _driver = d['driver'] as Map<String, dynamic>);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CANCEL
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _cancelDelivery() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(tr('delivery.cancelQ'),
            style: TextStyle(fontFamily: 'LeagueSpartan',
                fontWeight: FontWeight.w700)),
        content: Text(tr('delivery.areYouSure'),
            style: TextStyle(fontFamily: 'Quicksand', fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: Text(tr('delivery.yesCancel'))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final id = widget.delivery['id'];
      await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/$id/cancel'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({'reason': 'Cancelled by sender'}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}

    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cancelled) return _buildCancelledScreen();

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _pickupLatLng,
                initialZoom:   14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapStyle.tileUrl(_liqKey),
                  userAgentPackageName: 'com.wego.app',
                  tileProvider: NetworkTileProvider(),
                ),
                PolylineLayer(polylines: _polylines),
                MarkerLayer(markers:   _markers),
              ],
            ),
          ),

          MapStyleButton(
            current: _mapStyle,
            onChanged: (s) { setState(() => _mapStyle = s); saveMapStylePref(s); },
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8)]),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8)]),
                    child: Row(children: [
                      const Icon(Icons.bolt_rounded,
                          color: AppColors.primaryGold, size: 16),
                      const SizedBox(width: 5),
                      Text(
                          widget.delivery['deliveryCode'] as String?
                              ?? 'Express',
                          style: const TextStyle(
                              fontFamily:  'LeagueSpartan',
                              fontSize:    13,
                              fontWeight:  FontWeight.w700,
                              color:       Colors.white)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

          // ── Bottom sheet ─────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end:   Offset.zero,
              ).animate(_sheetAnim),
              child: _buildBottomSheet(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    final stageInfo = _stageLabels[_currentStatus] ??
        ('📦', _currentStatus.replaceAll('_', ' '));

    return Container(
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow:    [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
                color: AppColors.borderMedium,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(stageInfo.$1,
                      style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(stageInfo.$2,
                        style: const TextStyle(
                            fontFamily:  'LeagueSpartan',
                            fontSize:    16,
                            fontWeight:  FontWeight.w800)),
                  ),
                  if (_delivered)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(tr('delivery.delivered'),
                          style: TextStyle(
                              fontFamily:  'LeagueSpartan',
                              fontSize:    12,
                              fontWeight:  FontWeight.w700,
                              color:       AppColors.success)),
                    ),
                ]),
                const SizedBox(height: 16),
                if (_driver != null) _buildDriverRow(),
                if (_driver != null) const SizedBox(height: 14),
                _buildAddressRow(),
                const SizedBox(height: 16),
                Row(children: [
                  Text('${widget.delivery['totalPrice']} XAF',
                      style: const TextStyle(
                          fontFamily:  'LeagueSpartan',
                          fontSize:    18,
                          fontWeight:  FontWeight.w800,
                          color:       AppColors.primaryGold)),
                  const Spacer(),
                  if (!_delivered &&
                      ['accepted', 'en_route_pickup']
                          .contains(_currentStatus))
                    TextButton(
                        onPressed: _cancelDelivery,
                        child: Text(tr('common.cancel'),
                            style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize:   13,
                                color:      AppColors.error))),
                ]),
                SizedBox(
                    height:
                        MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverRow() {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: const BoxDecoration(
            color: AppColors.primaryDark, shape: BoxShape.circle),
        child: const Icon(Icons.person_rounded,
            color: AppColors.primaryGold, size: 20),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(_driver!['name'] as String? ?? 'Driver',
            style: const TextStyle(fontFamily: 'Quicksand', fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
      if (_driver!['rating'] != null) ...[
        const Icon(Icons.star_rounded,
            color: AppColors.primaryGold, size: 14),
        const SizedBox(width: 3),
        Text(_driver!['rating'].toString(),
            style: const TextStyle(fontFamily: 'Quicksand', fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _callDriver,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.phone_rounded,
              color: AppColors.success, size: 17),
        ),
      ),
    ]);
  }

  Widget _buildAddressRow() {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TO',
                style: TextStyle(fontFamily: 'Quicksand', fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:      AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
                widget.delivery['dropoffAddress'] as String? ?? '—',
                maxLines:  1,
                overflow:  TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Quicksand', fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    ]);
  }

  Widget _buildCancelledScreen() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                    color: AppColors.errorLight, shape: BoxShape.circle),
                child: const Icon(Icons.cancel_rounded,
                    color: AppColors.error, size: 40),
              ),
              const SizedBox(height: 24),
              Text(tr('delivery.cancelled'),
                  style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(_cancelReason ?? tr('del.cancelledMsg'),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: Text(tr('delivery.backHome'),
                      style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

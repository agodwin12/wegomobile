// lib/screens/passenger/delivery/driver searching/delivery_searching_screen.dart
//
// Mapbox migration: flutter_map + latlong2 replacing google_maps_flutter.
// Preserved: socket searching logic, nearby driver markers, dashed route,
// draggable bottom sheet, delivery details cards, _DashedCirclePainter.

import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../l10n/tr.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../../utils/app_colors.dart';
import '../../../../utils/map_style.dart';
import '../../../../widgets/map_style_button.dart';
import '../../../../core/config.dart';
import '../delivery express/express_delivery.dart';
import '../delivery regular/regular_delivery.dart';

class DeliverySearchingScreen extends StatefulWidget {
  final Map<String, dynamic> delivery;
  final String accessToken;

  const DeliverySearchingScreen({
    super.key,
    required this.delivery,
    required this.accessToken,
  });

  @override
  State<DeliverySearchingScreen> createState() =>
      _DeliverySearchingScreenState();
}

class _DeliverySearchingScreenState extends State<DeliverySearchingScreen>
    with TickerProviderStateMixin {

  // ── Map ────────────────────────────────────────────────────────────────────
  final MapController _mapCtrl = MapController();
  List<Marker>   _markers   = [];
  List<Polyline> _polylines = [];
  List<Marker>   _baseMarkers = [];

  // ── Timers ─────────────────────────────────────────────────────────────────
  Timer? _refreshTimer;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late Animation<double>   _pulse;

  // ── Socket ─────────────────────────────────────────────────────────────────
  io.Socket? _socket;

  // ── State ──────────────────────────────────────────────────────────────────
  bool   _noDrivers    = false;
  bool   _cancelling   = false;
  int    _dots         = 1;
  int    _nearbyCount  = 0;
  Timer? _dotsTimer;

  // ── Sheet controller ───────────────────────────────────────────────────────
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  // ── Coords ─────────────────────────────────────────────────────────────────
  late double _pickupLat;
  late double _pickupLng;
  late double _dropoffLat;
  late double _dropoffLng;

  String get _liqKey => dotenv.env['LOCATIONIQ_KEY'] ?? '';
  MapStyle _mapStyle = MapStyle.streets;

  @override
  void initState() {
    super.initState();
    loadMapStylePref().then((s) { if (mounted) setState(() => _mapStyle = s); });

    _pickupLat  = _parseCoord('pickupLat',  'pickup_lat',  4.0511);
    _pickupLng  = _parseCoord('pickupLng',  'pickup_lng',  9.7679);
    _dropoffLat = _parseCoord('dropoffLat', 'dropoff_lat', 4.0611);
    _dropoffLng = _parseCoord('dropoffLng', 'dropoff_lng', 9.7779);

    _initAnimations();
    _startDotsTimer();
    _connectSocket();
    _initMapMarkers();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _fetchNearbyDrivers(),
    );
    _fetchNearbyDrivers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), _fitMapToRoute);
    });
  }

  double _parseCoord(String key1, String key2, double fallback) {
    final v = widget.delivery[key1] ?? widget.delivery[key2];
    if (v == null) return fallback;
    return (v as num).toDouble();
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 1400), vsync: this)
      ..repeat(reverse: true);
    _rotateCtrl = AnimationController(
        duration: const Duration(milliseconds: 2200), vsync: this)
      ..repeat();
    _pulse = Tween<double>(begin: 0.88, end: 1.12).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  void _startDotsTimer() {
    _dotsTimer = Timer.periodic(
      const Duration(milliseconds: 600),
      (_) { if (mounted) setState(() => _dots = (_dots % 3) + 1); },
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _dotsTimer?.cancel();
    _refreshTimer?.cancel();
    _sheetCtrl.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAP
  // ─────────────────────────────────────────────────────────────────────────

  void _initMapMarkers() {
    _baseMarkers = [
      Marker(
        point:  LatLng(_pickupLat, _pickupLng),
        width:  40,
        height: 50,
        child: const Icon(Icons.location_on, color: Colors.green, size: 40),
      ),
      Marker(
        point:  LatLng(_dropoffLat, _dropoffLng),
        width:  40,
        height: 50,
        child: const Icon(Icons.flag_rounded, color: Colors.red, size: 40),
      ),
    ];

    setState(() {
      _markers   = List.from(_baseMarkers);
      _polylines = [
        Polyline(
          points: [
            LatLng(_pickupLat,  _pickupLng),
            LatLng(_dropoffLat, _dropoffLng),
          ],
          color:       AppColors.primaryDark,
          strokeWidth: 3,
          pattern:     const StrokePattern.dotted(),
        ),
      ];
    });
  }

  void _fitMapToRoute() {
    try {
      final points = [
        LatLng(_pickupLat,  _pickupLng),
        LatLng(_dropoffLat, _dropoffLng),
      ];
      _mapCtrl.fitCamera(CameraFit.bounds(
        bounds:  LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(80),
      ));
    } catch (_) {}
  }

  Future<void> _fetchNearbyDrivers() async {
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/deliveries/nearby-drivers',
      ).replace(queryParameters: {
        'lat':    _pickupLat.toString(),
        'lng':    _pickupLng.toString(),
        'radius': '5',
      });

      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return;

      final data    = jsonDecode(res.body);
      final drivers = (data['drivers'] as List<dynamic>? ?? []);

      if (!mounted) return;

      final driverMarkers = drivers.expand<Marker>((d) {
        final lat = (d['lat'] as num?)?.toDouble();
        final lng = (d['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) return const [];
        final heading = (d['heading'] as num?)?.toDouble() ?? 0.0;
        return [
          Marker(
            point:  LatLng(lat, lng),
            width:  36,
            height: 36,
            child: Transform.rotate(
              angle: heading * math.pi / 180,
              child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: Colors.orange, size: 30),
            ),
          ),
        ];
      }).toList();

      setState(() {
        _markers     = [..._baseMarkers, ...driverMarkers];
        _nearbyCount = driverMarkers.length;
      });
    } catch (_) {
      // Silently ignore — map just won't update
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCKET
  // ─────────────────────────────────────────────────────────────────────────

  void _connectSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? widget.accessToken;

    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();

    _socket!.on('delivery:driver_assigned', (data) {
      if (!mounted) return;
      _refreshTimer?.cancel();
      _navigateToTracking(data as Map<String, dynamic>);
    });

    _socket!.on('delivery:no_drivers', (_) {
      if (!mounted) return;
      _refreshTimer?.cancel();
      setState(() => _noDrivers = true);
    });

    _socket!.on('delivery:cancelled', (_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  void _navigateToTracking(Map<String, dynamic> assignedData) {
    if (!mounted) return;
    final deliveryType =
        widget.delivery['deliveryType'] as String? ?? 'regular';
    final merged = {...widget.delivery, ...assignedData};

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => deliveryType == 'express'
            ? DeliveryTrackingExpress(
                delivery: merged, accessToken: widget.accessToken)
            : DeliveryTrackingRegular(
                delivery: merged, accessToken: widget.accessToken),
      ),
    );
  }

  Future<void> _cancelDelivery() async {
    setState(() => _cancelling = true);
    try {
      final id = widget.delivery['id'];
      await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/$id/cancel'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({'reason': 'Cancelled by sender during search'}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  bool get _isExpress =>
      (widget.delivery['deliveryType'] as String? ?? 'regular') == 'express';

  String get _deliveryCode =>
      widget.delivery['deliveryCode'] as String? ?? '—';

  String get _totalPrice {
    final p = widget.delivery['totalPrice'];
    if (p == null) return '—';
    return '${(p as num).toStringAsFixed(0)} XAF';
  }

  String get _pickupAddress =>
      widget.delivery['pickupAddress'] as String? ??
      widget.delivery['pickup_address'] as String? ??
      widget.delivery['pickup']?['address'] as String? ??
      '—';

  String get _dropoffAddress =>
      widget.delivery['dropoffAddress'] as String? ??
      widget.delivery['dropoff_address'] as String? ??
      widget.delivery['dropoff']?['address'] as String? ??
      '—';

  String get _recipientName {
    final name = widget.delivery['recipientName'] as String? ??
        widget.delivery['recipient_name'] as String? ??
        '—';
    return name.toUpperCase();
  }

  String get _recipientPhone =>
      widget.delivery['recipientPhone'] as String? ??
      widget.delivery['recipient_phone'] as String? ??
      '—';

  String get _categoryEmoji =>
      widget.delivery['categoryEmoji'] as String? ?? '📦';

  String get _categoryLabel =>
      widget.delivery['categoryLabel'] as String? ?? 'Package';

  String get _packageSize =>
      widget.delivery['packageSize'] as String? ??
      widget.delivery['package_size'] as String? ??
      '—';

  String get _paymentLabel {
    final m = widget.delivery['paymentMethod'] as String? ??
        widget.delivery['payment_method'] as String? ?? '';
    switch (m) {
      case 'mtn_mobile_money': return 'MTN MoMo';
      case 'orange_money':     return 'Orange Money';
      case 'cash':             return 'Cash';
      default:                 return m;
    }
  }

  bool   get _surgeActive =>
      widget.delivery['priceBreakdown']?['surgeActive'] == true;
  double get _surgeMultiplier =>
      (widget.delivery['priceBreakdown']?['surgeMultiplier'] as num? ?? 1.0)
          .toDouble();
  double get _expressSurcharge =>
      (widget.delivery['priceBreakdown']?['expressSurcharge'] as num? ?? 0)
          .toDouble();
  String get _trackingMode =>
      _isExpress ? '🗺  Live map' : '📋 Stage updates';

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // ── Full-screen map ──────────────────────────────────────────────
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: LatLng(_pickupLat, _pickupLng),
                  initialZoom:   13.5,
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
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8)],
                        ),
                        child: Row(children: [
                          if (!_noDrivers) ...[
                            SizedBox(
                              width: 14, height: 14,
                              child: AnimatedBuilder(
                                animation: _rotateCtrl,
                                builder: (_, child) => Transform.rotate(
                                    angle: _rotateCtrl.value * 2 * math.pi,
                                    child: child),
                                child: CustomPaint(
                                    painter: _DashedCirclePainter(size: 14)),
                              ),
                            ),
                            const SizedBox(width: 7),
                          ],
                          Text(
                            _noDrivers
                                ? '❌ No drivers found'
                                : 'Searching${'.' * _dots}',
                            style: const TextStyle(
                                fontFamily:  'Poppins',
                                fontSize:    13,
                                fontWeight:  FontWeight.w700,
                                color:       Colors.white),
                          ),
                        ]),
                      ),
                      const Spacer(),
                      if (_nearbyCount > 0 && !_noDrivers)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8)],
                          ),
                          child: Row(children: [
                            Text('🛵',
                                style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 5),
                            Text('$_nearbyCount nearby',
                                style: TextStyle(
                                    fontFamily:  'Roboto',
                                    fontSize:    12,
                                    fontWeight:  FontWeight.w600,
                                    color:       AppColors.textPrimary)),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Draggable bottom sheet ────────────────────────────────────────
            DraggableScrollableSheet(
              controller:       _sheetCtrl,
              initialChildSize: 0.38,
              minChildSize:     0.18,
              maxChildSize:     0.88,
              builder: (_, scrollCtrl) => _buildSheet(scrollCtrl),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSheet(ScrollController scrollCtrl) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.darkBorder.withOpacity(0.6))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: CustomScrollView(
        controller: scrollCtrl,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Container(
                  width: 42, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 14),
                  decoration: BoxDecoration(
                      color: AppColors.darkSurfaceHigh,
                      borderRadius: BorderRadius.circular(2)),
                ),
                // Promo banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: AppColors.primaryGold, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.local_shipping_rounded, color: Colors.black, size: 17),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        _isExpress ? 'Express delivery · Priority matching' : 'Regular delivery · Eco-friendly rate',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      )),
                    ]),
                  ),
                ),
                _buildHeroSection(),
                const SizedBox(height: 12),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildRouteCard(),
                const SizedBox(height: 8),
                _buildPackageCard(),
                const SizedBox(height: 8),
                _buildRecipientCard(),
                const SizedBox(height: 8),
                _buildFareCard(),
                const SizedBox(height: 8),
                _buildPinNote(),
                const SizedBox(height: 16),
                if (_noDrivers)
                  _buildNoDriversActions()
                else
                  _buildCancelButton(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (_noDrivers)
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sentiment_dissatisfied_rounded,
                  color: AppColors.error, size: 24),
            )
          else
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Container(
                    width:  50 * _pulse.value,
                    height: 50 * _pulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryGold.withOpacity(0.14),
                    ),
                  ),
                ),
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                      color: AppColors.primaryGold,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: Colors.black, size: 22),
                ),
              ],
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _noDrivers ? 'No drivers available' : 'Finding your driver',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppColors.darkTextPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  _noDrivers
                      ? 'Please try again in a moment'
                      : _nearbyCount > 0
                          ? '$_nearbyCount agent${_nearbyCount > 1 ? "s" : ""} nearby — accepting…'
                          : 'Looking for delivery agents...',
                  style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryGold.withOpacity(0.4)),
            ),
            child: Text(_deliveryCode,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.primaryGold, letterSpacing: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return _card(
      label: tr('delivery.route'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(width: 9, height: 9,
                decoration: const BoxDecoration(
                    color: AppColors.primaryDark, shape: BoxShape.circle)),
            Container(width: 1.5, height: 22,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: Colors.black12),
            Container(width: 9, height: 9,
                decoration: BoxDecoration(
                    color: _isExpress
                        ? AppColors.primaryGold
                        : AppColors.success,
                    shape: BoxShape.circle)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pickupAddress,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12,
                        color: AppColors.darkTextPrimary, height: 1.35)),
                const SizedBox(height: 12),
                Text(_dropoffAddress,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12,
                        color: AppColors.darkTextPrimary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard() {
    return _card(
      label: 'Package',
      child: Row(children: [
        Text(_categoryEmoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_categoryLabel · '
                '${_packageSize[0].toUpperCase()}'
                '${_packageSize.length > 1 ? _packageSize.substring(1) : ""}',
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary)),
              Text(_isExpress ? 'Express delivery' : 'Regular delivery',
                  style: const TextStyle(fontSize: 11,
                      color: AppColors.darkTextSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _isExpress
                ? AppColors.primaryGold
                : AppColors.primaryDark,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
              _isExpress ? 'EXPRESS' : 'REGULAR',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _isExpress
                      ? AppColors.primaryDark
                      : Colors.white)),
        ),
      ]),
    );
  }

  Widget _buildRecipientCard() {
    final name     = _recipientName;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join();

    return _card(
      label: tr('delivery.recipient'),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryGold.withOpacity(0.4))),
          child: Center(
            child: Text(initials,
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: AppColors.primaryGold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                    fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary)),
            Text(_recipientPhone,
                style: const TextStyle(fontSize: 11,
                    color: AppColors.darkTextSecondary)),
          ]),
        ),
        Row(children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
          SizedBox(width: 4),
          Text(tr('delivery.pinSent'),
              style: TextStyle(fontFamily: 'Roboto', fontSize: 10,
                  color: AppColors.success)),
        ]),
      ]),
    );
  }

  Widget _buildFareCard() {
    return _card(
      label: tr('delivery.fare'),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_totalPrice,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color:       AppColors.darkTextPrimary,
                      letterSpacing: -0.5)),
              Text(tr('delivery.totalFare'),
                  style: TextStyle(fontSize: 10,
                      color: AppColors.darkTextSecondary)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_paymentLabel,
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGold)),
              Text(tr('delivery.payment'),
                  style: TextStyle(fontSize: 10,
                      color: AppColors.darkTextSecondary)),
            ]),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: [
            if (_surgeActive)
              _chip('⚡ Surge ×${_surgeMultiplier.toStringAsFixed(1)}',
                  const Color(0xFFFAEEDA), const Color(0xFF854F0B)),
            if (_isExpress && _expressSurcharge > 0)
              _chip('+ ${_expressSurcharge.toStringAsFixed(0)} XAF express',
                  const Color(0xFFE6F1FB), const Color(0xFF185FA5)),
            _chip(_trackingMode,
                const Color(0xFFF5F4F0), AppColors.textSecondary),
          ],
        ),
      ]),
    );
  }

  Widget _buildPinNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4C8DFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4C8DFF).withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.lock_rounded, color: Color(0xFF4C8DFF), size: 14),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'A 4-digit PIN was sent to the recipient\'s number. '
            'The driver will request it to confirm delivery.',
            style: TextStyle(fontSize: 11, color: Color(0xFF7EB8FF), height: 1.5),
          ),
        ),
      ]),
    );
  }

  Widget _buildNoDriversActions() {
    return Column(children: [
      SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGold,
            foregroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(tr('common.retry'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        child: Text(tr('delivery.backHome'),
            style: TextStyle(fontSize: 13, color: AppColors.darkTextTertiary)),
      ),
    ]);
  }

  Widget _buildCancelButton() {
    return Center(
      child: TextButton(
        onPressed: _cancelling ? null : _cancelDelivery,
        child: _cancelling
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.primaryGold)))
            : Text(tr('delivery.cancelSearch'),
                style: TextStyle(fontSize: 13, color: AppColors.darkTextTertiary)),
      ),
    );
  }

  Widget _card({required String label, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: AppColors.darkTextTertiary, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    // Convert light chip colors to dark-mode equivalents
    final darkBg = AppColors.darkSurfaceHigh;
    final darkFg = AppColors.darkTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: darkBg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.darkBorder)),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: darkFg)),
    );
  }
}

// ── Rotating dashed ring painter ───────────────────────────────────────────

class _DashedCirclePainter extends CustomPainter {
  final double size;
  const _DashedCirclePainter({this.size = 64});

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color       = AppColors.primaryGold.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;
    final center    = Offset(s.width / 2, s.height / 2);
    final radius    = s.width / 2;
    const dashCount = 10;
    const dashAngle = (2 * math.pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          i * dashAngle, dashAngle * 0.5, false, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

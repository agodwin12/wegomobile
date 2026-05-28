// lib/presentation/screens/passenger/delivery/driver searching/delivery_searching_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../../utils/app_colors.dart';
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
  GoogleMapController? _mapController;
  Set<Marker>          _markers       = {};
  Set<Polyline>        _polylines     = {};
  Timer?               _refreshTimer;

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

  @override
  void initState() {
    super.initState();

    // Parse coords from delivery map — try multiple key formats
    _pickupLat  = _parseCoord('pickupLat',  'pickup_lat',  4.0511);
    _pickupLng  = _parseCoord('pickupLng',  'pickup_lng',  9.7679);
    _dropoffLat = _parseCoord('dropoffLat', 'dropoff_lat', 4.0611);
    _dropoffLng = _parseCoord('dropoffLng', 'dropoff_lng', 9.7779);

    _initAnimations();
    _startDotsTimer();
    _connectSocket();
    _initMapMarkers();

    // Poll nearby drivers every 8 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
          (_) => _fetchNearbyDrivers(),
    );
    _fetchNearbyDrivers(); // immediate first call
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
    _mapController?.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAP
  // ─────────────────────────────────────────────────────────────────────────

  void _initMapMarkers() {
    final markers = <Marker>{};

    // Pickup marker — green
    markers.add(Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(_pickupLat, _pickupLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: '📍 Pickup',
        snippet: _pickupAddress,
      ),
    ));

    // Dropoff marker — red
    markers.add(Marker(
      markerId: const MarkerId('dropoff'),
      position: LatLng(_dropoffLat, _dropoffLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: '🏁 Dropoff',
        snippet: _dropoffAddress,
      ),
    ));

    // Route polyline between pickup and dropoff
    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(_pickupLat, _pickupLng),
          LatLng(_dropoffLat, _dropoffLng),
        ],
        color: AppColors.primaryDark,
        width: 3,
        patterns: [PatternItem.dash(12), PatternItem.gap(6)],
      ),
    };

    setState(() {
      _markers   = markers;
      _polylines = polylines;
    });
  }

  Future<void> _fetchNearbyDrivers() async {
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/deliveries/nearby-drivers',
      ).replace(queryParameters: {
        'lat': _pickupLat.toString(),
        'lng': _pickupLng.toString(),
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

      // Remove old driver markers, keep pickup/dropoff
      final baseMarkers = _markers
          .where((m) =>
      m.markerId.value == 'pickup' ||
          m.markerId.value == 'dropoff')
          .toSet();

      // Add a yellow marker for each nearby driver
      for (final d in drivers) {
        final lat = (d['lat'] as num?)?.toDouble();
        final lng = (d['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        baseMarkers.add(Marker(
          markerId: MarkerId('driver_${d['id']}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueYellow),
          infoWindow: InfoWindow(
            title: '🛵 Delivery agent',
            snippet: '${(d['distance'] as num?)?.toStringAsFixed(1)} km away',
          ),
          rotation: (d['heading'] as num?)?.toDouble() ?? 0,
          flat: true,
        ));
      }

      setState(() {
        _markers      = baseMarkers;
        _nearbyCount  = drivers.length;
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

  String get _pickupAddress {
    return widget.delivery['pickupAddress'] as String? ??
        widget.delivery['pickup_address'] as String? ??
        widget.delivery['pickup']?['address'] as String? ??
        '—';
  }

  String get _dropoffAddress {
    return widget.delivery['dropoffAddress'] as String? ??
        widget.delivery['dropoff_address'] as String? ??
        widget.delivery['dropoff']?['address'] as String? ??
        '—';
  }

  // Recipient name always uppercase
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
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_pickupLat, _pickupLng),
                zoom: 13.5,
              ),
              markers:   _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                // After map loads, fit both pickup + dropoff in view
                Future.delayed(const Duration(milliseconds: 500), () {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngBounds(
                      LatLngBounds(
                        southwest: LatLng(
                          math.min(_pickupLat, _dropoffLat) - 0.01,
                          math.min(_pickupLng, _dropoffLng) - 0.01,
                        ),
                        northeast: LatLng(
                          math.max(_pickupLat, _dropoffLat) + 0.01,
                          math.max(_pickupLng, _dropoffLng) + 0.01,
                        ),
                      ),
                      100, // padding in pixels
                    ),
                  );
                });
              },
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
                                fontFamily: 'Poppins', fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ]),
                      ),
                      const Spacer(),
                      // Nearby count badge
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
                            const Text('🛵',
                                style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 5),
                            Text('$_nearbyCount nearby',
                                style: const TextStyle(fontFamily: 'Roboto',
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ]),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Draggable bottom sheet ────────────────────────────────────────
            DraggableScrollableSheet(
              controller: _sheetCtrl,
              initialChildSize: 0.38,
              minChildSize: 0.18,
              maxChildSize: 0.88,
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
      decoration: const BoxDecoration(
        color: Color(0xFFF5F4F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: CustomScrollView(
        controller: scrollCtrl,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sticky header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 14),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2)),
                ),
                // Animated icon + title
                _buildHeroSection(),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── Scrollable cards ───────────────────────────────────────────────
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
          // Animated icon (smaller, inline)
          if (_noDrivers)
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
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
                    width: 44 * _pulse.value,
                    height: 44 * _pulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryGold.withOpacity(0.1),
                    ),
                  ),
                ),
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(
                      color: AppColors.primaryGold,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.local_shipping_rounded,
                      color: AppColors.primaryDark, size: 20),
                ),
              ],
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _noDrivers ? 'No drivers available' : 'Finding your driver',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                Text(
                  _noDrivers
                      ? 'Please try again in a moment'
                      : _nearbyCount > 0
                      ? '$_nearbyCount driver${_nearbyCount > 1 ? 's' : ''} nearby — waiting for acceptance'
                      : 'Looking for delivery agents...',
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 11,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Delivery code pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_deliveryCode,
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 10,
                    fontWeight: FontWeight.w600, color: AppColors.primaryGold)),
          ),
        ],
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────────────────────

  Widget _buildRouteCard() {
    return _card(
      label: 'Route',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(width: 9, height: 9,
                  decoration: const BoxDecoration(
                      color: AppColors.primaryDark, shape: BoxShape.circle)),
              Container(width: 1.5, height: 22,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.black12),
              Container(width: 9, height: 9,
                  decoration: BoxDecoration(
                      color: _isExpress ? AppColors.primaryGold : AppColors.success,
                      shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pickupAddress,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 12,
                        color: AppColors.textPrimary, height: 1.35)),
                const SizedBox(height: 12),
                Text(_dropoffAddress,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 12,
                        color: AppColors.textPrimary, height: 1.35)),
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
      child: Row(
        children: [
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
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                        fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(_isExpress ? 'Express delivery' : 'Regular delivery',
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 11,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _isExpress ? AppColors.primaryGold : AppColors.primaryDark,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
                _isExpress ? 'EXPRESS' : 'REGULAR',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _isExpress ? AppColors.primaryDark : Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientCard() {
    // Always uppercase
    final name = _recipientName; // already uppercased in getter
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2)
        .join();

    return _card(
      label: 'Recipient',
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(
                color: Color(0xFFEEEDFE), shape: BoxShape.circle),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                      fontWeight: FontWeight.w700, color: Color(0xFF534AB7))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                        fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(_recipientPhone,
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 11,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          Row(children: const [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
            SizedBox(width: 4),
            Text('PIN sent',
                style: TextStyle(fontFamily: 'Roboto', fontSize: 10,
                    color: AppColors.success)),
          ]),
        ],
      ),
    );
  }

  Widget _buildFareCard() {
    return _card(
      label: 'Fare',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_totalPrice,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 22,
                          fontWeight: FontWeight.w800, color: AppColors.textPrimary,
                          letterSpacing: -0.5)),
                  const Text('Total fare',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 10,
                          color: AppColors.textSecondary)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_paymentLabel,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12,
                          fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const Text('Payment',
                      style: TextStyle(fontFamily: 'Roboto', fontSize: 10,
                          color: AppColors.textSecondary)),
                ],
              ),
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
              _chip(_trackingMode, const Color(0xFFF5F4F0), AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPinNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F1FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.lock_rounded, color: Color(0xFF185FA5), size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'A 4-digit PIN was sent to the recipient\'s number. '
                  'The driver will request it to confirm delivery.',
              style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
                  color: Color(0xFF185FA5), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDriversActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
              foregroundColor: AppColors.primaryDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Try again',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: Text('Back to home',
              style: TextStyle(fontFamily: 'Roboto', fontSize: 13,
                  color: Colors.black.withOpacity(0.35))),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: _cancelling ? null : _cancelDelivery,
      child: _cancelling
          ? const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2))
          : Text('Cancel search',
          style: TextStyle(fontFamily: 'Roboto', fontSize: 13,
              color: Colors.black.withOpacity(0.35))),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _card({required String label, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 9,
                  fontWeight: FontWeight.w700, color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(fontFamily: 'Roboto', fontSize: 10,
              fontWeight: FontWeight.w500, color: fg)),
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
      ..color = AppColors.primaryGold.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final center = Offset(s.width / 2, s.height / 2);
    final radius = s.width / 2;
    const dashCount = 10;
    const dashAngle = (2 * math.pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          i * dashAngle, dashAngle * 0.5, false, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
// lib/presentation/screens/passenger/delivery/delivery_tracking_express.dart
//
// EXPRESS DELIVERY TRACKING
// Shows a live Google Map with the driver's position updating in real time.
// Listens to:
//   delivery:driver_location  → update driver marker on map
//   delivery:status_update    → advance stage + update bottom sheet
//   delivery:completed        → show complete state
//   delivery:cancelled        → show cancellation

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../../utils/app_colors.dart';
import '../../../../utils/app_typography.dart';
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

  GoogleMapController? _mapController;
  io.Socket?           _socket;

  // ── Map state ──────────────────────────────────────────────────────────────
  LatLng? _driverPosition;
  Set<Marker>  _markers  = {};
  Set<Polyline> _polylines = {};

  // ── Delivery state ─────────────────────────────────────────────────────────
  String _currentStatus = 'accepted';
  bool   _delivered     = false;
  bool   _cancelled     = false;
  String? _cancelReason;
  Map<String, dynamic>? _driver;

  // ── Bottom sheet animation ─────────────────────────────────────────────────
  late AnimationController _sheetCtrl;
  late Animation<double>   _sheetAnim;

  static const _stageLabels = {
    'accepted':        ('✅', 'Driver accepted your delivery'),
    'en_route_pickup': ('🚗', 'Driver is heading to pickup'),
    'arrived_pickup':  ('📍', 'Driver arrived at pickup'),
    'picked_up':       ('📦', 'Package picked up'),
    'en_route_dropoff':('🚀', 'Driver heading to recipient'),
    'arrived_dropoff': ('🏁', 'Driver at destination'),
    'delivered':       ('🎉', 'Package delivered!'),
  };

  @override
  void initState() {
    super.initState();
    _sheetCtrl = AnimationController(
        duration: const Duration(milliseconds: 350), vsync: this);
    _sheetAnim = CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOut);
    _sheetCtrl.forward();

    _currentStatus = widget.delivery['status'] as String? ?? 'accepted';
    _driver        = widget.delivery['driver'] as Map<String, dynamic>?;

    _initMarkers();
    _connectSocket();
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    _mapController?.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAP SETUP
  // ─────────────────────────────────────────────────────────────────────────

  void _initMarkers() {
    final markers = <Marker>{};

    // Pickup marker
    final pickupLat = (widget.delivery['pickupLat'] as num?)?.toDouble();
    final pickupLng = (widget.delivery['pickupLng'] as num?)?.toDouble();
    if (pickupLat != null && pickupLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pickupLat, pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: '📍 Pickup'),
      ));
    }

    // Dropoff marker
    final dropoffLat = (widget.delivery['dropoffLat'] as num?)?.toDouble();
    final dropoffLng = (widget.delivery['dropoffLng'] as num?)?.toDouble();
    if (dropoffLat != null && dropoffLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(dropoffLat, dropoffLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: '🏁 Dropoff'),
      ));
    }

    setState(() => _markers = markers);
  }

  void _updateDriverMarker(double lat, double lng) {
    final pos = LatLng(lat, lng);
    final updated = Set<Marker>.from(_markers)
      ..removeWhere((m) => m.markerId == const MarkerId('driver'))
      ..add(Marker(
        markerId: const MarkerId('driver'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        infoWindow: InfoWindow(
            title: '🚗 ${_driver?['name'] ?? 'Driver'}'),
      ));

    setState(() {
      _markers        = updated;
      _driverPosition = pos;
    });

    // Smoothly pan map to driver
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
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

    // Live GPS ping from driver
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
      if (d['driver'] != null) setState(() => _driver = d['driver'] as Map<String, dynamic>);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CANCEL
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _cancelDelivery() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel delivery?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text('Are you sure?',
            style: TextStyle(fontFamily: 'Roboto', fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Yes, cancel')),
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

    final pickupLat  = (widget.delivery['pickupLat']  as num?)?.toDouble() ?? 4.0511;
    final pickupLng  = (widget.delivery['pickupLng']  as num?)?.toDouble() ?? 9.7679;

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(pickupLat, pickupLng),
              zoom: 14,
            ),
            markers:  _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (ctrl) => _mapController = ctrl,
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    // Back button
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
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Express badge
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
                            widget.delivery['deliveryCode'] as String? ?? 'Express',
                            style: const TextStyle(fontFamily: 'Poppins',
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom sheet ─────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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
                // Current stage
                Row(
                  children: [
                    Text(stageInfo.$1, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(stageInfo.$2,
                          style: const TextStyle(fontFamily: 'Poppins',
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    if (_delivered)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('Delivered',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Driver info
                if (_driver != null) _buildDriverRow(),
                if (_driver != null) const SizedBox(height: 14),

                // Address row
                _buildAddressRow(),
                const SizedBox(height: 16),

                // Price + cancel
                Row(
                  children: [
                    Text('${widget.delivery['totalPrice']} XAF',
                        style: const TextStyle(fontFamily: 'Poppins',
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: AppColors.primaryGold)),
                    const Spacer(),
                    if (!_delivered &&
                        ['accepted', 'en_route_pickup'].contains(_currentStatus))
                      TextButton(
                          onPressed: _cancelDelivery,
                          child: const Text('Cancel',
                              style: TextStyle(fontFamily: 'Roboto', fontSize: 13,
                                  color: AppColors.error))),
                  ],
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverRow() {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(
              color: AppColors.primaryDark, shape: BoxShape.circle),
          child: const Icon(Icons.person_rounded,
              color: AppColors.primaryGold, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
              _driver!['name'] as String? ?? 'Driver',
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        if (_driver!['rating'] != null) ...[
          const Icon(Icons.star_rounded, color: AppColors.primaryGold, size: 14),
          const SizedBox(width: 3),
          Text(_driver!['rating'].toString(),
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }

  Widget _buildAddressRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TO',
                  style: TextStyle(fontFamily: 'Roboto', fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(
                  widget.delivery['dropoffAddress'] as String? ?? '—',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Cancelled ──────────────────────────────────────────────────────────────

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
                decoration: const BoxDecoration(
                    color: AppColors.errorLight, shape: BoxShape.circle),
                child: const Icon(Icons.cancel_rounded,
                    color: AppColors.error, size: 40),
              ),
              const SizedBox(height: 24),
              const Text('Delivery cancelled',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(_cancelReason ?? 'This delivery has been cancelled.',
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
                      foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: const Text('Back to home',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 15,
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
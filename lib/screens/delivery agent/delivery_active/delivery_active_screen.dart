

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:http_parser/http_parser.dart';

import '../../../core/config.dart';
import '../../../utils/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL  —  delivery data passed from dashboard (offer accept response)
// ─────────────────────────────────────────────────────────────────────────────

class ActiveDelivery {
  final int id;
  final String deliveryCode;
  final String deliveryType; // 'regular' | 'express'
  final String trackingMode; // 'stage_updates' | 'live_map'
  final String status;

  // Pickup
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String? pickupLandmark;

  // Dropoff
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
  final String? dropoffLandmark;

  // Package
  final String packageSize;
  final String packageCategory;
  final String categoryLabel;
  final String categoryEmoji;
  final String? packagePhotoUrl;
  final String? packageDescription;
  final bool isFragile;

  // Financials
  final double totalPrice;
  final double driverPayout;
  final double commissionAmount;
  final String paymentMethod;

  // Recipient
  final String recipientName;
  final String recipientPhone;
  final String? recipientNote;

  const ActiveDelivery({
    required this.id,
    required this.deliveryCode,
    required this.deliveryType,
    required this.trackingMode,
    required this.status,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    this.pickupLandmark,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    this.dropoffLandmark,
    required this.packageSize,
    required this.packageCategory,
    required this.categoryLabel,
    required this.categoryEmoji,
    this.packagePhotoUrl,
    this.packageDescription,
    required this.isFragile,
    required this.totalPrice,
    required this.driverPayout,
    required this.commissionAmount,
    required this.paymentMethod,
    required this.recipientName,
    required this.recipientPhone,
    this.recipientNote,
  });

  factory ActiveDelivery.fromJson(Map<String, dynamic> j) => ActiveDelivery(
    id: j['id'] as int,
    deliveryCode: j['deliveryCode'] as String? ?? j['delivery_code'] as String? ?? '',
    deliveryType: j['deliveryType'] as String? ?? j['delivery_type'] as String? ?? 'regular',
    trackingMode: j['trackingMode'] as String? ?? j['tracking_mode'] as String? ?? 'stage_updates',
    status: j['status'] as String? ?? 'accepted',
    pickupAddress: (j['pickup'] as Map?)?['address'] as String? ?? j['pickup_address'] as String? ?? '',
    pickupLat: ((j['pickup'] as Map?)?['lat'] ?? j['pickup_latitude'] as num? ?? 0).toDouble(),
    pickupLng: ((j['pickup'] as Map?)?['lng'] ?? j['pickup_longitude'] as num? ?? 0).toDouble(),
    pickupLandmark: (j['pickup'] as Map?)?['landmark'] as String?,
    dropoffAddress: (j['dropoff'] as Map?)?['address'] as String? ?? j['dropoff_address'] as String? ?? '',
    dropoffLat: ((j['dropoff'] as Map?)?['lat'] ?? j['dropoff_latitude'] as num? ?? 0).toDouble(),
    dropoffLng: ((j['dropoff'] as Map?)?['lng'] ?? j['dropoff_longitude'] as num? ?? 0).toDouble(),
    dropoffLandmark: (j['dropoff'] as Map?)?['landmark'] as String?,
    packageSize: j['packageSize'] as String? ?? j['package_size'] as String? ?? 'medium',
    packageCategory: j['packageCategory'] as String? ?? j['package_category'] as String? ?? 'other',
    categoryLabel: j['categoryLabel'] as String? ?? 'Package',
    categoryEmoji: j['categoryEmoji'] as String? ?? '📦',
    packagePhotoUrl: j['packagePhotoUrl'] as String? ?? j['package_photo_url'] as String?,
    packageDescription: j['packageDescription'] as String? ?? j['package_description'] as String?,
    isFragile: j['isFragile'] as bool? ?? j['is_fragile'] as bool? ?? false,
    totalPrice: (j['totalPrice'] ?? j['total_price'] as num? ?? 0).toDouble(),
    driverPayout: (j['driverPayout'] ?? j['driver_payout'] as num? ?? 0).toDouble(),
    commissionAmount: (j['commissionAmount'] ?? j['commission_amount'] as num? ?? 0).toDouble(),
    paymentMethod: j['paymentMethod'] as String? ?? j['payment_method'] as String? ?? 'cash',
    recipientName: j['recipientName'] as String? ?? j['recipient_name'] as String? ?? '',
    recipientPhone: j['recipientPhone'] as String? ?? j['recipient_phone'] as String? ?? '',
    recipientNote: j['recipientNote'] as String? ?? j['recipient_note'] as String?,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE DEFINITION
// ─────────────────────────────────────────────────────────────────────────────

enum _Stage {
  accepted,
  en_route_pickup,
  arrived_pickup,
  picked_up,
  en_route_dropoff,
  arrived_dropoff,
  delivered;

  static _Stage fromString(String s) {
    switch (s) {
      case 'en_route_pickup':  return _Stage.en_route_pickup;
      case 'arrived_pickup':   return _Stage.arrived_pickup;
      case 'picked_up':        return _Stage.picked_up;
      case 'en_route_dropoff': return _Stage.en_route_dropoff;
      case 'arrived_dropoff':  return _Stage.arrived_dropoff;
      case 'delivered':        return _Stage.delivered;
      default:                 return _Stage.accepted;
    }
  }

  String get apiValue {
    switch (this) {
      case _Stage.en_route_pickup:  return 'en_route_pickup';
      case _Stage.arrived_pickup:   return 'arrived_pickup';
      case _Stage.picked_up:        return 'picked_up';
      case _Stage.en_route_dropoff: return 'en_route_dropoff';
      case _Stage.arrived_dropoff:  return 'arrived_dropoff';
      default:                      return name;
    }
  }

  _Stage? get next {
    switch (this) {
      case _Stage.accepted:        return _Stage.en_route_pickup;
      case _Stage.en_route_pickup: return _Stage.arrived_pickup;
      case _Stage.arrived_pickup:  return _Stage.picked_up;
      case _Stage.picked_up:       return _Stage.en_route_dropoff;
      case _Stage.en_route_dropoff:return _Stage.arrived_dropoff;
      case _Stage.arrived_dropoff: return null; // PIN dialog instead
      default:                     return null;
    }
  }

  String get actionLabel {
    switch (this) {
      case _Stage.accepted:        return 'Start Route to Pickup';
      case _Stage.en_route_pickup: return 'I\'ve Arrived at Pickup';
      case _Stage.arrived_pickup:  return 'Package Picked Up';
      case _Stage.picked_up:       return 'En Route to Dropoff';
      case _Stage.en_route_dropoff:return 'Arrived at Dropoff';
      case _Stage.arrived_dropoff: return 'Enter Delivery PIN';
      default:                     return '';
    }
  }

  String get statusLabel {
    switch (this) {
      case _Stage.accepted:        return 'Head to pickup';
      case _Stage.en_route_pickup: return 'On the way to pickup';
      case _Stage.arrived_pickup:  return 'At pickup — collect package';
      case _Stage.picked_up:       return 'Package collected — head to dropoff';
      case _Stage.en_route_dropoff:return 'On the way to dropoff';
      case _Stage.arrived_dropoff: return 'At dropoff — ask for PIN';
      case _Stage.delivered:       return 'Delivered ✓';
    }
  }

  Color get color {
    switch (this) {
      case _Stage.accepted:
      case _Stage.en_route_pickup: return AppColors.info;
      case _Stage.arrived_pickup:
      case _Stage.picked_up:       return AppColors.warning;
      case _Stage.en_route_dropoff:
      case _Stage.arrived_dropoff: return AppColors.primaryGold;
      case _Stage.delivered:       return AppColors.success;
    }
  }

  IconData get icon {
    switch (this) {
      case _Stage.accepted:        return Icons.check_circle_outline_rounded;
      case _Stage.en_route_pickup: return Icons.directions_bike_rounded;
      case _Stage.arrived_pickup:  return Icons.location_on_rounded;
      case _Stage.picked_up:       return Icons.inventory_2_rounded;
      case _Stage.en_route_dropoff:return Icons.delivery_dining_rounded;
      case _Stage.arrived_dropoff: return Icons.pin_drop_rounded;
      case _Stage.delivered:       return Icons.check_circle_rounded;
    }
  }

  bool get isPrePickup =>
      [_Stage.accepted, _Stage.en_route_pickup, _Stage.arrived_pickup].contains(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryActiveScreen extends StatefulWidget {
  final ActiveDelivery delivery;
  final io.Socket? socket;

  const DeliveryActiveScreen({
    super.key,
    required this.delivery,
    this.socket,
  });

  @override
  State<DeliveryActiveScreen> createState() => _DeliveryActiveScreenState();
}

class _DeliveryActiveScreenState extends State<DeliveryActiveScreen>
    with TickerProviderStateMixin {

  late ActiveDelivery _delivery;
  late _Stage _stage;

  String _accessToken = '';
  bool _transitioning = false;

  // ── GPS ──────────────────────────────────────────────────────────────────
  Timer? _gpsTimer;

  // ── Pickup photo ─────────────────────────────────────────────────────────
  File?   _pickupPhoto;
  String? _pickupPhotoUrl;  // uploaded R2 URL
  bool    _uploadingPhoto = false;
  final   _picker = ImagePicker();

  // ── PIN dialog ────────────────────────────────────────────────────────────
  final _pinCtrl = TextEditingController();
  bool  _verifyingPin = false;
  String? _pinError;

  // ── Cancel ────────────────────────────────────────────────────────────────
  bool _cancelling = false;

  // ── Cash confirm ──────────────────────────────────────────────────────────
  bool _confirmingCash = false;
  bool _cashConfirmed  = false;

  // ── Cancelled externally ──────────────────────────────────────────────────
  bool _cancelledExternally = false;

  // ── Animation ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  // ── Stage progress steps ──────────────────────────────────────────────────
  static const _stages = [
    _Stage.accepted,
    _Stage.en_route_pickup,
    _Stage.arrived_pickup,
    _Stage.picked_up,
    _Stage.en_route_dropoff,
    _Stage.arrived_dropoff,
    _Stage.delivered,
  ];

  @override
  void initState() {
    super.initState();
    _delivery = widget.delivery;
    _stage    = _Stage.fromString(_delivery.status);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token') ?? '';
    _listenSocket();
    _startGps();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _gpsTimer?.cancel();
    _pinCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCKET
  // ─────────────────────────────────────────────────────────────────────────

  void _listenSocket() {
    widget.socket?.on('delivery:cancelled', (data) {
      if (!mounted) return;
      setState(() => _cancelledExternally = true);
      // Auto-pop after 4s
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) Navigator.of(context).pop();
      });
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GPS
  // ─────────────────────────────────────────────────────────────────────────

  void _startGps() {
    _sendLocation();
    _gpsTimer = Timer.periodic(const Duration(seconds: 15), (_) => _sendLocation());
  }

  Future<void> _sendLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8));
      widget.socket?.emit('driver:location_update', {
        'lat':     pos.latitude,
        'lng':     pos.longitude,
        'heading': pos.heading,
        'speed':   pos.speed,
      });
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE TRANSITION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _advanceStage() async {
    if (_transitioning) return;

    // arrived_dropoff → open PIN dialog instead of direct API call
    if (_stage == _Stage.arrived_dropoff) {
      _showPinDialog();
      return;
    }

    final nextStage = _stage.next;
    if (nextStage == null) return;

    // picked_up requires pickup photo (optional but strongly encouraged)
    if (nextStage == _Stage.picked_up && _pickupPhoto != null && _pickupPhotoUrl == null) {
      await _uploadPickupPhoto();
    }

    setState(() => _transitioning = true);

    final body = <String, dynamic>{'status': nextStage.apiValue};
    if (nextStage == _Stage.picked_up && _pickupPhotoUrl != null) {
      body['pickup_photo_url'] = _pickupPhotoUrl;
    }

    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/${_delivery.id}/status'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type':  'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 12));

      final resBody = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && resBody['success'] == true) {
        setState(() => _stage = nextStage);
        _showSnack(nextStage.statusLabel, isError: false);
      } else {
        _showSnack(resBody['message'] as String? ?? 'Failed to update status', isError: true);
      }
    } catch (e) {
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
        source: ImageSource.camera,
        maxWidth: 1920,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _pickupPhoto = File(picked.path));
      }
    } on PlatformException catch (e) {
      _showSnack('Camera error: ${e.message}', isError: true);
    }
  }

  Future<void> _uploadPickupPhoto() async {
    if (_pickupPhoto == null || _uploadingPhoto) return;
    setState(() => _uploadingPhoto = true);

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_accessToken'
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          _pickupPhoto!.path,
          contentType: MediaType('image', 'jpeg'),
        ));

      final streamed = await request.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(streamed);
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && body['url'] != null) {
        _pickupPhotoUrl = body['url'] as String;
      }
    } catch (e) {
      debugPrint('⚠️ Pickup photo upload failed: $e');
    }

    if (mounted) setState(() => _uploadingPhoto = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PIN VERIFY
  // ─────────────────────────────────────────────────────────────────────────

  void _showPinDialog() {
    _pinCtrl.clear();
    _pinError = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pin_rounded,
                        color: AppColors.primaryGold, size: 28),
                  ),
                  const SizedBox(height: 16),
                  const Text('Enter Delivery PIN',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                    'Ask ${_delivery.recipientName} for the 4-digit PIN sent to their phone.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 12,
                        color: AppColors.primaryDark),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      hintStyle: TextStyle(
                          color: AppColors.borderMedium,
                          fontSize: 32,
                          letterSpacing: 12),
                      filled: true,
                      fillColor: AppColors.backgroundLight,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      errorText: _pinError,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _verifyingPin ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.borderMedium),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Back',
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _verifyingPin
                            ? null
                            : () async {
                          if (_pinCtrl.text.length < 4) {
                            setDialogState(() => _pinError = 'Enter 4 digits');
                            return;
                          }
                          setDialogState(() {
                            _verifyingPin = true;
                            _pinError = null;
                          });
                          await _verifyPin(
                            ctx,
                            setDialogState,
                          );
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
                            ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                            : const Text('Confirm',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _verifyPin(BuildContext dialogCtx, StateSetter setDialogState) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/${_delivery.id}/verify-pin'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({'pin': _pinCtrl.text.trim()}),
      ).timeout(const Duration(seconds: 12));

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && body['success'] == true) {
        if (mounted) Navigator.pop(dialogCtx); // close dialog
        setState(() => _stage = _Stage.delivered);
        _gpsTimer?.cancel();
        return;
      }

      final msg = body['message'] as String? ?? 'Incorrect PIN';
      setDialogState(() {
        _pinError = msg;
        _verifyingPin = false;
      });
    } catch (e) {
      setDialogState(() {
        _pinError = 'Network error. Try again.';
        _verifyingPin = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIRM CASH
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _confirmCash() async {
    if (_confirmingCash) return;
    setState(() => _confirmingCash = true);

    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/${_delivery.id}/confirm-cash'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        setState(() => _cashConfirmed = true);
        _showSnack('Cash payment confirmed!', isError: false);
        return;
      }
      _showSnack('Failed to confirm cash', isError: true);
    } catch (e) {
      _showSnack('Network error', isError: true);
    }

    if (mounted) setState(() => _confirmingCash = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CANCEL
  // ─────────────────────────────────────────────────────────────────────────

  void _showCancelConfirm() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cancel delivery?',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'You will lose the commission fee as a penalty for cancelling an accepted delivery.',
                style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5),
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
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Yes, cancel delivery',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderMedium),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Keep delivery',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelDelivery() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);

    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/${_delivery.id}/cancel'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({'reason': 'Driver cancelled'}),
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        _gpsTimer?.cancel();
        if (mounted) Navigator.of(context).pop(); // back to dashboard
        return;
      }

      final msg = (jsonDecode(res.body) as Map)['message'] as String? ?? 'Cannot cancel';
      _showSnack(msg, isError: true);
    } catch (e) {
      _showSnack('Network error', isError: true);
    }

    if (mounted) setState(() => _cancelling = false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Roboto')),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _fmt(double xaf) =>
      '${xaf.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} XAF';

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Cancelled externally — full-screen banner
    if (_cancelledExternally) return _buildCancelledView();

    // Delivered — completion screen
    if (_stage == _Stage.delivered) return _buildDeliveredView();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    _buildStageTracker(),
                    const SizedBox(height: 16),
                    _buildCurrentStatusCard(),
                    const SizedBox(height: 14),
                    _buildRouteCard(),
                    const SizedBox(height: 14),
                    _buildPackageCard(),
                    const SizedBox(height: 14),
                    _buildRecipientCard(),
                    const SizedBox(height: 14),
                    _buildFinancialCard(),
                    if (_stage.isPrePickup) ...[
                      const SizedBox(height: 14),
                      _buildPickupPhotoCard(),
                    ],
                    if (_stage == _Stage.arrived_dropoff) ...[
                      const SizedBox(height: 14),
                      _buildPinInstructionCard(),
                    ],
                  ]),
                ),
              ),
            ],
          ),
          // Bottom action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    final isExpress = _delivery.deliveryType == 'express';
    return SliverAppBar(
      pinned: true,
      backgroundColor: isExpress ? AppColors.primaryDark : AppColors.primaryDark,
      leading: _stage.isPrePickup
          ? IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white54),
        onPressed: _showCancelConfirm,
      )
          : const SizedBox.shrink(),
      title: Row(
        children: [
          if (isExpress) ...[
            const Text('⚡ ', style: TextStyle(fontSize: 16)),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _delivery.deliveryCode,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Opacity(
                  opacity: _pulse.value,
                  child: Text(
                    _stage.statusLabel,
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10,
                        color: _stage.color),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryGold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _fmt(_delivery.driverPayout),
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGold),
          ),
        ),
      ],
    );
  }

  // ── Stage tracker ──────────────────────────────────────────────────────────

  Widget _buildStageTracker() {
    final stageIndex = _stages.indexOf(_stage);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: List.generate(_stages.length, (i) {
          final s = _stages[i];
          final isDone    = i < stageIndex;
          final isCurrent = i == stageIndex;
          final isLast    = i == _stages.length - 1;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isCurrent ? 28 : 20,
                        height: isCurrent ? 28 : 20,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.success
                              : isCurrent
                              ? s.color
                              : AppColors.borderLight,
                          shape: BoxShape.circle,
                          boxShadow: isCurrent
                              ? [
                            BoxShadow(
                                color: s.color.withOpacity(0.35),
                                blurRadius: 8,
                                spreadRadius: 2)
                          ]
                              : [],
                        ),
                        child: Icon(
                          isDone ? Icons.check_rounded : s.icon,
                          size: isCurrent ? 14 : 10,
                          color: (isDone || isCurrent) ? Colors.white : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 2,
                      color: isDone ? AppColors.success : AppColors.borderLight,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Current status card ────────────────────────────────────────────────────

  Widget _buildCurrentStatusCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _stage.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stage.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _stage.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_stage.icon, color: _stage.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stageTitle(),
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _stage.color),
                ),
                const SizedBox(height: 2),
                Text(
                  _stage.statusLabel,
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: _stage.color.withOpacity(0.8),
                      height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _stageTitle() {
    switch (_stage) {
      case _Stage.accepted:        return 'Delivery Accepted';
      case _Stage.en_route_pickup: return 'En Route to Pickup';
      case _Stage.arrived_pickup:  return 'At Pickup Location';
      case _Stage.picked_up:       return 'Package Collected';
      case _Stage.en_route_dropoff:return 'En Route to Dropoff';
      case _Stage.arrived_dropoff: return 'At Dropoff Location';
      default:                     return '';
    }
  }

  // ── Route card ─────────────────────────────────────────────────────────────

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.route_rounded, size: 14, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Text('Route',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 14),
          _addressRow(
            icon: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primaryDark, shape: BoxShape.circle)),
            label: 'Pickup',
            address: _delivery.pickupAddress,
            landmark: _delivery.pickupLandmark,
            isActive: _stage.index <= _Stage.arrived_pickup.index,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3.5, top: 2, bottom: 2),
            child: Container(width: 1, height: 20, color: AppColors.borderMedium),
          ),
          _addressRow(
            icon: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: AppColors.success, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.success, width: 1))),
            label: 'Dropoff',
            address: _delivery.dropoffAddress,
            landmark: _delivery.dropoffLandmark,
            isActive: _stage.index >= _Stage.picked_up.index,
          ),
        ],
      ),
    );
  }

  Widget _addressRow({
    required Widget icon,
    required String label,
    required String address,
    String? landmark,
    required bool isActive,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 5), child: icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.primaryDark : AppColors.textSecondary)),
              Text(address,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.textPrimary : AppColors.textSecondary)),
              if (landmark != null)
                Text(landmark,
                    style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10,
                        color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Package card ───────────────────────────────────────────────────────────

  Widget _buildPackageCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          // Package photo
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _delivery.packagePhotoUrl != null
                ? Image.network(
              _delivery.packagePhotoUrl!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _packagePlaceholder(),
            )
                : _packagePlaceholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(_delivery.categoryEmoji,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(_delivery.categoryLabel,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  if (_delivery.isFragile) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('Fragile',
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 9,
                              color: AppColors.error,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(
                  '${_delivery.packageSize[0].toUpperCase()}${_delivery.packageSize.substring(1)} package',
                  style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: AppColors.textSecondary),
                ),
                if (_delivery.packageDescription != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _delivery.packageDescription!,
                    style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11,
                        color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _packagePlaceholder() => Container(
    width: 60,
    height: 60,
    decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(10)),
    child: Center(
        child: Text(_delivery.categoryEmoji,
            style: const TextStyle(fontSize: 26))),
  );

  // ── Recipient card ─────────────────────────────────────────────────────────

  Widget _buildRecipientCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.person_outline_rounded,
                size: 14, color: AppColors.textSecondary),
            SizedBox(width: 6),
            Text('Recipient',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _delivery.recipientName.isNotEmpty
                        ? _delivery.recipientName[0].toUpperCase()
                        : 'R',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_delivery.recipientName,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(_delivery.recipientPhone,
                        style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // Call button
              GestureDetector(
                onTap: () {
                  // TODO: launch phone dialer
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded,
                      color: AppColors.success, size: 18),
                ),
              ),
            ],
          ),
          if (_delivery.recipientNote != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 13, color: AppColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_delivery.recipientNote!,
                        style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: AppColors.info,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Financial card ─────────────────────────────────────────────────────────

  Widget _buildFinancialCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
              child: _finStat('Your Payout', _fmt(_delivery.driverPayout),
                  AppColors.success)),
          Container(
              width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          Expanded(
              child: _finStat('Commission', _fmt(_delivery.commissionAmount),
                  AppColors.warning)),
          Container(
              width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          Expanded(
              child: _finStat(
                  'Payment',
                  _delivery.paymentMethod == 'cash' ? '💵 Cash' : '📱 Mobile',
                  AppColors.info)),
        ],
      ),
    );
  }

  Widget _finStat(String label, String value, Color color) => Column(
    children: [
      Text(value,
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 3),
      Text(label,
          style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 9,
              color: Colors.white.withOpacity(0.4))),
    ],
  );

  // ── Pickup photo card ──────────────────────────────────────────────────────

  Widget _buildPickupPhotoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pickup photo',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Optional',
                    style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 9,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Take a photo before collecting the package',
              style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickPickupPhoto,
            child: _pickupPhoto != null
                ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_pickupPhoto!,
                      width: double.infinity,
                      height: 110,
                      fit: BoxFit.cover),
                ),
                if (_uploadingPhoto)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      ),
                    ),
                  ),
                if (_pickupPhotoUrl != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 12),
                    ),
                  ),
              ],
            )
                : Container(
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.borderMedium,
                    style: BorderStyle.solid),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded,
                      color: AppColors.textSecondary, size: 20),
                  SizedBox(width: 8),
                  Text('Tap to take photo',
                      style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PIN instruction card ───────────────────────────────────────────────────

  Widget _buildPinInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔐', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Get the delivery PIN',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning)),
                const SizedBox(height: 3),
                Text(
                  'Ask ${_delivery.recipientName} for the 4-digit PIN sent to ${_delivery.recipientPhone}. '
                      'Do not hand over the package before entering the correct PIN.',
                  style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: AppColors.warning,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom action bar ──────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _transitioning ? null : _advanceStage,
          style: ElevatedButton.styleFrom(
            backgroundColor: _stage.color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.borderMedium,
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _transitioning
              ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_stage.icon, size: 18),
              const SizedBox(width: 8),
              Text(_stage.actionLabel,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Delivered view ─────────────────────────────────────────────────────────

  Widget _buildDeliveredView() {
    final isCash = _delivery.paymentMethod == 'cash';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Celebration header
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 52),
              ),
              const SizedBox(height: 20),
              const Text('Delivery Complete! 🎉',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                _delivery.deliveryCode,
                style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 28),

              // Payout summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  children: [
                    _completionStat('💰 Your Payout',
                        _fmt(_delivery.driverPayout), AppColors.success),
                    const SizedBox(height: 12),
                    _completionStat('🏢 WeGo Commission',
                        _fmt(_delivery.commissionAmount), AppColors.warning),
                    const SizedBox(height: 12),
                    _completionStat('📦 Delivered to',
                        _delivery.recipientName, AppColors.info),
                  ],
                ),
              ),

              // Cash confirm section
              if (isCash && !_cashConfirmed) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💵 Cash payment received?',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning)),
                      const SizedBox(height: 4),
                      Text(
                        'Confirm you received ${_fmt(_delivery.totalPrice)} from ${_delivery.recipientName}.',
                        style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: AppColors.warning,
                            height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirmingCash ? null : _confirmCash,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _confirmingCash
                              ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white))
                              : const Text('Confirm Cash Received',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (isCash && _cashConfirmed) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded,
                          color: AppColors.success, size: 16),
                      SizedBox(width: 6),
                      Text('Cash payment confirmed',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success)),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Done button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Back to Dashboard',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _completionStat(String label, String value, Color color) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              color: AppColors.textSecondary)),
      Text(value,
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color)),
    ],
  );

  // ── Cancelled view ─────────────────────────────────────────────────────────

  Widget _buildCancelledView() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel_rounded,
                      color: AppColors.error, size: 40),
                ),
                const SizedBox(height: 20),
                const Text('Delivery Cancelled',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                const Text(
                  'This delivery was cancelled. Your commission fee has been released.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5),
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
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Back to Dashboard',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
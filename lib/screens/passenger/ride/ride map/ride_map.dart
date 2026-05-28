

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
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../../providers/trip_provider.dart';
import '../../../../service/api_services.dart';
import '../../../../service/socket_service.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/app_typography.dart';
import '../../trip/searching_driver_screen.dart';
import '../ride_payment/ride_payment_screen.dart';

// ─── Sheet modes ──────────────────────────────────────────────────────────────
enum BottomSheetMode { minimized, location, vehicleSelection }

// ─── Models ───────────────────────────────────────────────────────────────────

class VehicleType {
  final String id;
  final String name;
  final String description;
  final String assetImage;
  final int passengers;

  double? fareEstimate;
  String? distanceText;
  String? durationText;

  VehicleType({
    required this.id,
    required this.name,
    required this.description,
    required this.assetImage,
    required this.passengers,
    this.fareEstimate,
    this.distanceText,
    this.durationText,
  });

  String get etaLabel => durationText ?? '— min';
}

class FavoritePlace {
  final String name;
  final String address;
  final String time;
  final IconData icon;

  const FavoritePlace({
    required this.name,
    required this.address,
    required this.time,
    required this.icon,
  });
}

class PlacePrediction {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']?['main_text'],
      secondaryText: json['structured_formatting']?['secondary_text'],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class RideMapScreen extends StatefulWidget {
  final Map<String, dynamic>? prefilledDestination;

  const RideMapScreen({super.key, this.prefilledDestination});

  @override
  State<RideMapScreen> createState() => _RideMapScreenState();
}

class _RideMapScreenState extends State<RideMapScreen>
    with TickerProviderStateMixin {

  String get _baseUrl  => dotenv.env['API_BASE_URL']        ?? '';
  String get _gmapsKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  final SocketService _socketService = SocketService();

  final _pickupCtrl  = TextEditingController();
  final _destCtrl    = TextEditingController();
  final _promoCtrl   = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus   = FocusNode();
  GoogleMapController? _mapCtrl;
  final DraggableScrollableController _sheetCtrl =
  DraggableScrollableController();

  AnimationController? _shimmerCtrl;
  Animation<double>?   _shimmerAnim;

  AnimationController? _promoExpandCtrl;
  Animation<double>?   _promoExpandAnim;

  String? _accessToken;
  Map<String, dynamic>? _userData;

  LatLng? _pickup;
  LatLng? _dropoff;
  static const LatLng _doualaCenter = LatLng(4.0511, 9.7679);

  final _markers   = <MarkerId, Marker>{};
  final _polylines = <PolylineId, Polyline>{};

  bool _locating      = true;
  bool _requesting    = false;
  bool _loadingPrices = false;

  BottomSheetMode _currentMode = BottomSheetMode.minimized;

  VehicleType? _selectedVehicle;
  String       _selectedPaymentMethod = 'cash';

  // ── Promo state ─────────────────────────────────────────────────────────
  String  _promoCode        = '';
  bool    _promoApplied     = false;
  bool    _promoExpanded    = false;
  bool    _promoLoading     = false;
  String? _promoError;
  String? _promoLabel;
  double? _promoDiscount;
  double? _promoFinalFare;
  // ────────────────────────────────────────────────────────────────────────

  List<PlacePrediction> _suggestions    = [];
  bool  _searching       = false;
  bool  _searchingPickup = true;
  Timer? _debounce;

  final List<VehicleType> _vehicleTypes = [
    VehicleType(
      id: 'economy',
      name: 'Economy',
      description: 'Affordable rides',
      assetImage: 'assets/images/economy.png',
      passengers: 4,
    ),
    VehicleType(
      id: 'comfort',
      name: 'Comfort',
      description: 'Extra legroom',
      assetImage: 'assets/images/comfort.png',
      passengers: 4,
    ),
    VehicleType(
      id: 'luxury',
      name: 'Luxury',
      description: 'Premium experience',
      assetImage: 'assets/images/luxury.png',
      passengers: 4,
    ),
  ];

  List<FavoritePlace> _favoritePlaces = [];

  // ═════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    debugPrint('🗺️ [RIDE_MAP] Initializing...');
    _shimmerCtrl = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat();
    _shimmerAnim = Tween<double>(begin: -2, end: 2).animate(
        CurvedAnimation(parent: _shimmerCtrl!, curve: Curves.easeInOut));

    _promoExpandCtrl = AnimationController(
        duration: const Duration(milliseconds: 280), vsync: this);
    _promoExpandAnim = CurvedAnimation(
        parent: _promoExpandCtrl!, curve: Curves.easeInOut);

    _initializeScreen();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _shimmerCtrl?.dispose();
    _promoExpandCtrl?.dispose();
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _promoCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    _mapCtrl?.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // INIT
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _initializeScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');

      final userDataStr = prefs.getString('user_data');
      if (userDataStr != null) {
        _userData = json.decode(userDataStr);
        debugPrint('👤 [RIDE_MAP] User: ${_userData?['first_name']}');
      }

      _setupFocusListeners();
      await _initLocation();

      if (_accessToken != null && _accessToken!.isNotEmpty) {
        await _connectSocket();
      }

      await _loadFavoritePlaces();

      if (widget.prefilledDestination != null) {
        await _applyPrefilledDestination(widget.prefilledDestination!);
      }

      debugPrint('✅ [RIDE_MAP] Initialized');
    } catch (e) {
      debugPrint('❌ [RIDE_MAP] Init error: $e');
      _snack('Some features may be limited', isError: true);
    }
  }

  Future<void> _applyPrefilledDestination(Map<String, dynamic> dest) async {
    try {
      final lat  = (dest['lat']  as num?)?.toDouble();
      final lng  = (dest['lng']  as num?)?.toDouble();
      final name = dest['name']?.toString() ?? dest['address']?.toString();
      if (lat == null || lng == null || name == null) return;

      _dropoff = LatLng(lat, lng);
      _destCtrl.text = name;
      _updateDropoffMarker();

      if (_pickup != null) {
        await _fitToBoth();
        await _fetchRoute();
        await _fetchPricesFromBackend();
        _showVehicleSelection();
      }
    } catch (e) {
      debugPrint('⚠️ [RIDE_MAP] Prefill error: $e');
    }
  }

  void _setupFocusListeners() {
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus &&
          _currentMode != BottomSheetMode.vehicleSelection) {
        setState(() {
          _searchingPickup = true;
          _currentMode = BottomSheetMode.location;
        });
        _expandSheet();
      }
    });
    _destFocus.addListener(() {
      if (_destFocus.hasFocus &&
          _currentMode != BottomSheetMode.vehicleSelection) {
        setState(() {
          _searchingPickup = false;
          _currentMode = BottomSheetMode.location;
        });
        _expandSheet();
      }
    });
  }

  Future<void> _connectSocket() async {
    if (_accessToken == null || _userData == null) return;
    try {
      final userId = _userData!['uuid']?.toString() ??
          _userData!['id']?.toString() ?? '';
      if (userId.isEmpty) return;
      await _socketService.connect(
        url: _baseUrl,
        accessToken: _accessToken!,
        userId: userId,
        userType: 'PASSENGER',
      );
    } catch (e) {
      debugPrint('❌ [RIDE_MAP] Socket failed: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // LOCATION
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _initLocation() async {
    setState(() => _locating = true);
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _showLocationServiceSnack();
        _fallbackToDouala();
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        _showLocationPermissionSnack();
        _fallbackToDouala();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      _pickup = LatLng(pos.latitude, pos.longitude);
      await _updateLocationName(pos.latitude, pos.longitude);
      await _createUserMarker();
      if (mounted) setState(() => _locating = false);
      _animateTo(_pickup!, zoom: 15);
    } catch (e) {
      debugPrint('❌ Location error: $e');
      _fallbackToDouala();
    }
  }

  Future<void> _updateLocationName(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p    = placemarks.first;
        String name = p.street ?? p.name ?? 'Current Location';
        if (p.locality != null && p.locality!.isNotEmpty) {
          name += ', ${p.locality}';
        }
        if (mounted) setState(() => _pickupCtrl.text = name);
      } else {
        if (mounted) setState(() => _pickupCtrl.text = 'Current Location');
      }
    } catch (_) {
      if (mounted) setState(() => _pickupCtrl.text = 'Current Location');
    }
  }

  void _fallbackToDouala() {
    if (!mounted) return;
    setState(() {
      _pickup   = _doualaCenter;
      _locating = false;
    });
    _updateLocationName(_doualaCenter.latitude, _doualaCenter.longitude);
    _createUserMarker();
    _animateTo(_doualaCenter);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // MARKERS
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _createUserMarker() async {
    if (_pickup == null) return;
    try {
      final firstName = _userData?['first_name']?.toString() ?? 'U';
      final initial   = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';
      final avatarUrl = _userData?['avatar_url']?.toString();

      final icon = (avatarUrl != null && avatarUrl.isNotEmpty)
          ? await _createAvatarMarker(avatarUrl, initial)
          : await _createInitialMarker(initial);

      const id = MarkerId('pickup');
      _markers[id] = Marker(
        markerId: id,
        position: _pickup!,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('⚠️ [MARKER] Fallback: $e');
      _updatePickupMarker();
    }
  }

  Future<BitmapDescriptor> _createAvatarMarker(
      String avatarUrl, String initial) async {
    try {
      final response = await http
          .get(Uri.parse(avatarUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return _createInitialMarker(initial);

      final codec = await ui.instantiateImageCodec(response.bodyBytes,
          targetWidth: 120, targetHeight: 120);
      final frame    = await codec.getNextFrame();
      final rawImage = frame.image;
      const size     = 120.0;

      final recorder = ui.PictureRecorder();
      final canvas   = Canvas(recorder);

      canvas.drawCircle(const Offset(size / 2, size / 2), size / 2,
          Paint()..color = AppColors.primaryGold.withOpacity(0.35));
      canvas.drawCircle(
          const Offset(size / 2, size / 2),
          size / 2.3,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5);
      final path = Path()
        ..addOval(Rect.fromCircle(
            center: const Offset(size / 2, size / 2), radius: size / 2.5));
      canvas.clipPath(path);
      canvas.drawImageRect(
          rawImage,
          Rect.fromLTWH(
              0, 0, rawImage.width.toDouble(), rawImage.height.toDouble()),
          Rect.fromCircle(
              center: const Offset(size / 2, size / 2), radius: size / 2.5),
          Paint());

      final picture = recorder.endRecording();
      final img     = await picture.toImage(size.toInt(), size.toInt());
      final bytes   = await img.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    } catch (_) {
      return _createInitialMarker(initial);
    }
  }

  Future<BitmapDescriptor> _createInitialMarker(String initial) async {
    const size     = 120.0;
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2,
        Paint()..color = AppColors.primaryGold.withOpacity(0.3));
    canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2.5,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, 0),
            const Offset(size, size),
            [AppColors.primaryGold, AppColors.primaryGold.withOpacity(0.7)],
          ));
    canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);

    final tp = TextPainter(
      text: TextSpan(
          text: initial,
          style: TextStyle(
              color: Colors.black,
              fontSize: size / 3,
              fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

    final picture = recorder.endRecording();
    final img     = await picture.toImage(size.toInt(), size.toInt());
    final bytes   = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _updatePickupMarker() {
    if (_pickup == null) return;
    const id = MarkerId('pickup');
    _markers[id] = Marker(
      markerId: id,
      position: _pickup!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
    );
    if (mounted) setState(() {});
  }

  void _updateDropoffMarker() {
    if (_dropoff == null) return;
    const id = MarkerId('dropoff');
    _markers[id] = Marker(
      markerId: id,
      position: _dropoff!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
    if (mounted) setState(() {});
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ROUTE POLYLINE
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _fetchRoute() async {
    if (_pickup == null || _dropoff == null) return;
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=${_pickup!.latitude},${_pickup!.longitude}'
            '&destination=${_dropoff!.latitude},${_dropoff!.longitude}'
            '&key=$_gmapsKey&mode=driving',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK') {
          final encoded =
          data['routes'][0]['overview_polyline']['points'] as String;
          final points = _decodePolyline(encoded);
          _applyRoutePolyline(points);
          debugPrint('✅ [ROUTE] ${points.length} pts decoded');
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ROUTE] $e — straight-line fallback');
    }
    _applyRoutePolyline([_pickup!, _dropoff!]);
  }

  void _applyRoutePolyline(List<LatLng> points) {
    const id = PolylineId('route');
    _polylines[id] = Polyline(
      polylineId: id,
      points: points,
      color: AppColors.primaryGold,
      width: 5,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
    );
    if (mounted) setState(() {});
  }

  List<LatLng> _decodePolyline(String encoded) {
    final result = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, r = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        r |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((r & 1) != 0 ? ~(r >> 1) : (r >> 1));
      shift = 0;
      r = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        r |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((r & 1) != 0 ? ~(r >> 1) : (r >> 1));
      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CAMERA
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _animateTo(LatLng target, {double zoom = 14}) async {
    await _mapCtrl?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom)));
  }

  Future<void> _fitToBoth() async {
    if (_mapCtrl == null || _pickup == null || _dropoff == null) return;
    final minLat = math.min(_pickup!.latitude,  _dropoff!.latitude);
    final maxLat = math.max(_pickup!.latitude,  _dropoff!.latitude);
    final minLng = math.min(_pickup!.longitude, _dropoff!.longitude);
    final maxLng = math.max(_pickup!.longitude, _dropoff!.longitude);
    await _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - 0.003, minLng - 0.003),
        northeast: LatLng(maxLat + 0.003, maxLng + 0.003),
      ),
      100,
    ));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SWAP
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _swapLocations() async {
    if (_pickup == null && _dropoff == null) return;
    HapticFeedback.lightImpact();

    final tempLoc  = _pickup;
    final tempText = _pickupCtrl.text;

    setState(() {
      _pickup  = _dropoff;
      _dropoff = tempLoc;
      _pickupCtrl.text = _destCtrl.text;
      _destCtrl.text   = tempText;
    });

    if (_pickup != null)  await _createUserMarker();
    if (_dropoff != null) _updateDropoffMarker();

    if (_pickup != null && _dropoff != null) {
      await _fitToBoth();
      await _fetchRoute();
    } else if (_pickup != null) {
      _animateTo(_pickup!, zoom: 15);
      _markers.remove(const MarkerId('dropoff'));
      _polylines.remove(const PolylineId('route'));
      setState(() {});
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BACKEND PRICING
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _fetchPricesFromBackend() async {
    if (_pickup == null || _dropoff == null || _accessToken == null) return;
    setState(() => _loadingPrices = true);
    try {
      debugPrint('💰 [RIDE_MAP] Fetching prices...');
      final response = await ApiService.getRideFareEstimates(
        token: _accessToken!,
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        dropoffLat: _dropoff!.latitude,
        dropoffLng: _dropoff!.longitude,
      );

      if (response['success'] == true && response['data'] != null) {
        final estimates =
            (response['data']['estimates'] as Map<String, dynamic>?) ?? {};
        setState(() {
          for (final v in _vehicleTypes) {
            final est = estimates[v.id] as Map<String, dynamic>?;
            if (est != null) {
              v.fareEstimate = (est['fare_estimate'] as num?)?.toDouble();
              v.distanceText = est['distance_text']?.toString();
              v.durationText = est['duration_text']?.toString();
            }
          }
          _selectedVehicle = _vehicleTypes.firstWhere(
                (v) => v.fareEstimate != null,
            orElse: () => _vehicleTypes[0],
          );
        });
        debugPrint('✅ [RIDE_MAP] Prices loaded');
      } else {
        _snack('Could not load prices. Please try again.', isError: true);
      }
    } catch (e) {
      debugPrint('❌ [RIDE_MAP] Price fetch: $e');
      _snack('Could not load prices. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _loadingPrices = false);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PROMO CODE
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _applyPromoCode() async {
    final code = _promoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _promoError = 'Enter a promo code first');
      return;
    }
    if (_accessToken == null) return;
    if (_selectedVehicle?.fareEstimate == null) {
      setState(() => _promoError = 'Select a vehicle first');
      return;
    }

    setState(() {
      _promoLoading = true;
      _promoError   = null;
    });

    try {
      final response = await ApiService.validateCoupon(
        token: _accessToken!,
        code: code,
        fareEstimate: _selectedVehicle!.fareEstimate!,
      );

      if (response['success'] == true) {
        final data      = response['data'] as Map<String, dynamic>;
        final discount  = (data['discount_amount'] as num?)?.toDouble() ?? 0.0;
        final finalFare = (data['final_fare'] as num?)?.toDouble()
            ?? math.max(0, _selectedVehicle!.fareEstimate! - discount);
        final label     = data['discount_label']?.toString() ?? '';

        setState(() {
          _promoCode      = code;
          _promoApplied   = true;
          _promoDiscount  = discount;
          _promoFinalFare = finalFare;
          _promoLabel     = label;
          _promoError     = null;
          _promoLoading   = false;
        });
        HapticFeedback.lightImpact();
        debugPrint('✅ [PROMO] Applied: $code | -${discount.toInt()} XAF');
      } else {
        setState(() {
          _promoError   = response['message'] ?? 'Invalid promo code';
          _promoLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [PROMO] $e');
      final raw = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _promoError   = raw.isNotEmpty ? raw : 'Could not validate code';
        _promoLoading = false;
      });
    }
  }

  Future<void> _silentRevalidatePromo(VehicleType vehicle) async {
    if (!_promoApplied || _promoCode.isEmpty) return;
    if (_accessToken == null) return;
    if (vehicle.fareEstimate == null) return;

    debugPrint('🔄 [PROMO] Silent re-validate for ${vehicle.id}...');

    try {
      final response = await ApiService.validateCoupon(
        token: _accessToken!,
        code: _promoCode,
        fareEstimate: vehicle.fareEstimate!,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        final data      = response['data'] as Map<String, dynamic>;
        final discount  = (data['discount_amount'] as num?)?.toDouble() ?? 0.0;
        final finalFare = (data['final_fare'] as num?)?.toDouble()
            ?? math.max(0, vehicle.fareEstimate! - discount);
        final label     = data['discount_label']?.toString() ?? _promoLabel;

        setState(() {
          _promoDiscount  = discount;
          _promoFinalFare = finalFare;
          _promoLabel     = label;
        });
        debugPrint('✅ [PROMO] Re-validated: -${discount.toInt()} XAF');
      } else {
        _clearPromoSilently();
      }
    } catch (_) {
      _clearPromoSilently();
    }
  }

  void _clearPromoSilently() {
    if (!mounted) return;
    setState(() {
      _promoApplied   = false;
      _promoDiscount  = null;
      _promoFinalFare = null;
      _promoLabel     = null;
      _promoError     = null;
    });
    debugPrint('⚠️ [PROMO] Cleared silently after vehicle switch');
  }

  void _removePromo() {
    HapticFeedback.lightImpact();
    setState(() {
      _promoApplied   = false;
      _promoDiscount  = null;
      _promoFinalFare = null;
      _promoLabel     = null;
      _promoError     = null;
      _promoCode      = '';
      _promoCtrl.clear();
    });
  }

  void _togglePromoSection() {
    HapticFeedback.selectionClick();
    setState(() => _promoExpanded = !_promoExpanded);
    if (_promoExpanded) {
      _promoExpandCtrl?.forward();
    } else {
      _promoExpandCtrl?.reverse();
    }
  }

  double get _effectiveFare {
    final base = _selectedVehicle?.fareEstimate ?? 0;
    if (_promoApplied && _promoFinalFare != null) return _promoFinalFare!;
    if (_promoApplied && _promoDiscount  != null) {
      return math.max(0, base - _promoDiscount!);
    }
    return base;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // AUTOCOMPLETE
  // ═════════════════════════════════════════════════════════════════════════

  void _onQueryChanged(String q, {required bool forPickup}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runAutocomplete(q, forPickup: forPickup);
    });
  }

  Future<void> _runAutocomplete(String q, {required bool forPickup}) async {
    final query = q.trim();
    if (query.isEmpty) {
      _clearSuggestions();
      return;
    }

    setState(() {
      _searching      = true;
      _searchingPickup = forPickup;
    });

    try {
      final location = _pickup != null
          ? '&location=${_pickup!.latitude},${_pickup!.longitude}&radius=20000'
          : '';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=${Uri.encodeComponent(query)}&key=$_gmapsKey$location',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _suggestions = (data['predictions'] as List? ?? [])
              .map((p) => PlacePrediction.fromJson(p))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('❌ Autocomplete: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearSuggestions() {
    setState(() {
      _suggestions = [];
      _searching   = false;
    });
  }

  Future<void> _selectPrediction(PlacePrediction p,
      {required bool forPickup}) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=${p.placeId}&key=$_gmapsKey'
            '&fields=geometry,name,formatted_address',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return;

      final result = json.decode(res.body)['result'];
      if (result == null || result['geometry'] == null) return;

      final location = result['geometry']['location'];
      final pos      = LatLng(location['lat'], location['lng']);
      final name     = result['name'] ?? p.description;
      final address  = result['formatted_address'] ?? p.description;

      if (forPickup) {
        setState(() => _pickup = pos);
        _pickupCtrl.text = name;
        await _createUserMarker();
        _pickupFocus.unfocus();
      } else {
        setState(() => _dropoff = pos);
        _destCtrl.text = name;
        _updateDropoffMarker();
        _destFocus.unfocus();

        if (_pickup != null && _dropoff != null) {
          await _fitToBoth();
          await _fetchRoute();
          _showAddToFavoritesOption(name, address);
          await _fetchPricesFromBackend();
          _showVehicleSelection();
        }
      }

      _clearSuggestions();
      if (forPickup) await _animateTo(pos, zoom: 15);
    } catch (e) {
      debugPrint('❌ Place details: $e');
      _snack('Could not fetch location', isError: true);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SHEET HELPERS
  // ═════════════════════════════════════════════════════════════════════════

  void _expandSheet() {
    _sheetCtrl.animateTo(0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
  }

  void _minimizeSheet() {
    _sheetCtrl.animateTo(0.15,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
    _pickupFocus.unfocus();
    _destFocus.unfocus();
    _clearSuggestions();
  }

  void _showVehicleSelection() {
    setState(() => _currentMode = BottomSheetMode.vehicleSelection);
    _sheetCtrl.animateTo(0.75,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic);
  }

  void _backToLocation() {
    setState(() => _currentMode = BottomSheetMode.minimized);
    _minimizeSheet();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // FAVORITES
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _loadFavoritePlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json_ = prefs.getString('favorite_places');
      if (json_ != null && json_.isNotEmpty) {
        final list = json.decode(json_) as List<dynamic>;
        setState(() {
          _favoritePlaces = list
              .map((item) => FavoritePlace(
            name:    item['name']    ?? '',
            address: item['address'] ?? '',
            time:    item['time']    ?? '',
            icon:    _iconFromString(item['icon'] ?? 'location_on'),
          ))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('❌ [FAV] $e');
    }
  }

  Future<void> _saveFavoritePlaces() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'favorite_places',
      json.encode(_favoritePlaces
          .map((p) => {
        'name': p.name,
        'address': p.address,
        'time': p.time,
        'icon': _iconToString(p.icon),
      })
          .toList()),
    );
  }

  Future<void> _removeFavorite(int index) async {
    setState(() => _favoritePlaces.removeAt(index));
    await _saveFavoritePlaces();
    _snack('Retiré des favoris');
  }

  void _showAddToFavoritesOption(String name, String address) {
    final already = _favoritePlaces.any(
          (f) =>
      f.name.toLowerCase() == name.toLowerCase() ||
          f.address.toLowerCase() == address.toLowerCase(),
    );
    if (!already) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ajouter "$name" aux favoris?'),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Ajouter',
          textColor: AppColors.primaryGold,
          onPressed: () => _showAddFavoriteDialog(name, address),
        ),
      ));
    }
  }

  IconData _iconFromString(String n) {
    const map = {
      'home': Icons.home,
      'work': Icons.work,
      'local_movies': Icons.local_movies,
      'local_cafe': Icons.local_cafe,
      'shopping_cart': Icons.shopping_cart,
      'restaurant': Icons.restaurant,
      'local_hospital': Icons.local_hospital,
      'school': Icons.school,
    };
    return map[n] ?? Icons.location_on;
  }

  String _iconToString(IconData icon) {
    const map = {
      0xe318: 'home',
      0xe943: 'work',
      0xe54c: 'local_movies',
      0xe541: 'local_cafe',
      0xe8cb: 'shopping_cart',
      0xe56c: 'restaurant',
      0xe548: 'local_hospital',
      0xe80c: 'school',
    };
    return map[icon.codePoint] ?? 'location_on';
  }

  // ═════════════════════════════════════════════════════════════════════════
  // RIDE REQUEST  ← THE ONLY CHANGED METHOD
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _requestRide() async {
    if (_pickup == null || _dropoff == null || _selectedVehicle == null) {
      _snack('Please complete booking details', isError: true);
      return;
    }
    if (_accessToken == null || _accessToken!.isEmpty) {
      _snack('Session expired. Please login.', isError: true);
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    if (!_socketService.isConnected) {
      await _connectSocket();
      if (!_socketService.isConnected) {
        _snack('Connection error. Try again.', isError: true);
        return;
      }
    }

    setState(() => _requesting = true);
    try {
      final response = await ApiService.createTrip(
        accessToken:    _accessToken!,
        pickupLat:      _pickup!.latitude,
        pickupLng:      _pickup!.longitude,
        pickupAddress:  _pickupCtrl.text,
        dropoffLat:     _dropoff!.latitude,
        dropoffLng:     _dropoff!.longitude,
        dropoffAddress: _destCtrl.text,
        paymentMethod:  _selectedPaymentMethod,
        vehicleType:    _selectedVehicle!.id,
        promoCode:      _promoApplied ? _promoCode : null,
      );

      if (!mounted) return;

      final tripData = response['data']?['trip'];
      if (tripData == null) throw Exception('Invalid response from server');

      Provider.of<TripProvider>(context, listen: false)
          .setCurrentTrip(tripData);

      // ── Payment gate ────────────────────────────────────────────────────
      // Backend returns requiresPayment: true when payment_method is MOMO/OM.
      // In that case driver matching is held until CamPay webhook confirms.
      // We navigate to RidePaymentScreen which handles:
      //   1. Phone input + "initiate payment" call
      //   2. "Check your phone" waiting UI
      //   3. Listens for payment:confirmed / payment:failed socket events
      //   4. On confirmed → pushes to SearchingDriverScreen
      //
      // For cash (requiresPayment: false) we go straight to searching — same
      // as before.
      // ────────────────────────────────────────────────────────────────────
      final requiresPayment = response['requiresPayment'] == true;
      final tripId          = tripData['id'].toString();

      if (requiresPayment) {
        // ── Digital payment (MoMo / Orange Money) ──────────────────────
        debugPrint('💳 [RIDE_MAP] Payment required — navigating to RidePaymentScreen');
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RidePaymentScreen(
              tripId:          tripId,
              fareAmount:      _effectiveFare.toInt(),
              paymentMethod:   _selectedPaymentMethod,
              pickupAddress:   _pickupCtrl.text,
              dropoffAddress:  _destCtrl.text,
              pickupLocation:  _pickup!,
              dropoffLocation: _dropoff!,
              vehicleType:     _selectedVehicle!.name,
              accessToken:     _accessToken!,
            ),
          ),
        );
      } else {
        // ── Cash — existing flow, unchanged ────────────────────────────
        debugPrint('💵 [RIDE_MAP] Cash — navigating to SearchingDriverScreen');
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SearchingDriverScreen(
              tripId:          tripId,
              pickupAddress:   _pickupCtrl.text,
              dropoffAddress:  _destCtrl.text,
              pickupLocation:  _pickup!,
              dropoffLocation: _dropoff!,
              fareEstimate:    _effectiveFare > 0
                  ? '${_effectiveFare.toInt()} XAF'
                  : null,
              vehicleType:     _selectedVehicle!.name,
              paymentMethod:   _selectedPaymentMethod,
            ),
          ),
        );
      }
    } on Exception catch (e) {
      String msg = e.toString().replaceFirst('Exception: ', '');
      _snack(msg,
          isError: true,
          isWarning: msg.toLowerCase().contains('no driver'));
    } catch (e) {
      _snack('An unexpected error occurred', isError: true);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SNACKBARS
  // ═════════════════════════════════════════════════════════════════════════

  void _snack(String msg, {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isWarning
          ? Colors.orange.shade700
          : isError
          ? AppColors.error
          : Colors.black87,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showLocationServiceSnack() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Location services disabled'),
      backgroundColor: AppColors.textPrimary,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
          label: 'Enable',
          textColor: AppColors.primaryGold,
          onPressed: Geolocator.openLocationSettings),
    ));
  }

  void _showLocationPermissionSnack() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Location permission required'),
      backgroundColor: AppColors.textPrimary,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
          label: 'Settings',
          textColor: AppColors.primaryGold,
          onPressed: Geolocator.openAppSettings),
    ));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition:
              const CameraPosition(target: _doualaCenter, zoom: 12),
              myLocationEnabled:       true,
              myLocationButtonEnabled: false,
              compassEnabled:          false,
              zoomControlsEnabled:     false,
              mapToolbarEnabled:       false,
              markers:   Set<Marker>.of(_markers.values),
              polylines: Set<Polyline>.of(_polylines.values),
              onMapCreated: (c) {
                _mapCtrl = c;
                if (_pickup != null) _animateTo(_pickup!, zoom: 15);
              },
            ),
          ),

          if (_locating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryGold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Locating you…',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),

          if (_currentMode == BottomSheetMode.minimized)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: _TopSearchBar(
                userData: _userData,
                onTap: () {
                  setState(() => _currentMode = BottomSheetMode.location);
                  _expandSheet();
                  Future.delayed(const Duration(milliseconds: 350),
                          () => _destFocus.requestFocus());
                },
              ),
            ),

          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.15,
            minChildSize:     0.15,
            maxChildSize:     0.92,
            snap:      true,
            snapSizes: const [0.15, 0.5, 0.92],
            builder: (ctx, scrollCtrl) {
              return NotificationListener<DraggableScrollableNotification>(
                onNotification: (n) {
                  if (_currentMode != BottomSheetMode.vehicleSelection) {
                    final mode = n.extent < 0.3
                        ? BottomSheetMode.minimized
                        : BottomSheetMode.location;
                    if (mode != _currentMode) {
                      setState(() => _currentMode = mode);
                    }
                  }
                  return false;
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 20,
                          offset: const Offset(0, -5)),
                    ],
                  ),
                  child: ListView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      if (_currentMode == BottomSheetMode.minimized)
                        _buildMinimizedContent()
                      else if (_currentMode == BottomSheetMode.location)
                        _buildLocationContent()
                      else
                        _buildVehicleSelectionContent(),
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

  // ═════════════════════════════════════════════════════════════════════════
  // MINIMIZED CONTENT
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildMinimizedContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plan your ride',
              style: AppTypography.headlineSmall
                  .copyWith(fontWeight: FontWeight.w900, color: Colors.black)),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _CompactInput(
                      controller: _pickupCtrl,
                      focusNode: _pickupFocus,
                      hint: 'Pickup location',
                      icon: Icons.my_location_rounded,
                      iconColor: const Color(0xFF2563EB),
                      onChanged: (q) => _onQueryChanged(q, forPickup: true),
                    ),
                    const SizedBox(height: 8),
                    _CompactInput(
                      controller: _destCtrl,
                      focusNode: _destFocus,
                      hint: 'Where are you going?',
                      icon: Icons.location_on_rounded,
                      iconColor: Colors.red,
                      onChanged: (q) => _onQueryChanged(q, forPickup: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _swapLocations,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(Icons.swap_vert_rounded,
                      color: Colors.black54, size: 22),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (_favoritePlaces.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Favorite places',
                    style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700, color: Colors.black87)),
                TextButton.icon(
                  onPressed: _showManageFavoritesDialog,
                  icon: const Icon(Icons.edit_outlined,
                      size: 14, color: Colors.black45),
                  label: Text('Manage',
                      style:
                      AppTypography.caption.copyWith(color: Colors.black45)),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._favoritePlaces.asMap().entries
                .map((e) => _buildFavoriteCard(e.value, e.key)),
          ] else
            _buildEmptyFavoritesCard(),
        ],
      ),
    );
  }

  Widget _buildEmptyFavoritesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.star_border_rounded, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text('No favorite places yet',
              style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 6),
          Text('Add frequent destinations for quick access',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: Colors.black45)),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(FavoritePlace place, int index) {
    return Dismissible(
      key: Key('fav_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
            color: Colors.red, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => _removeFavorite(index),
      child: GestureDetector(
        onTap: () {
          _destCtrl.text = place.name;
          _destFocus.requestFocus();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(place.icon, color: Colors.black87, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name,
                        style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600, color: Colors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (place.address.isNotEmpty)
                      Text(place.address,
                          style: AppTypography.caption
                              .copyWith(color: Colors.black45),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.black38, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // LOCATION CONTENT
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildLocationContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where to?',
              style: AppTypography.headlineSmall
                  .copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),

          _FullInput(
            controller: _pickupCtrl,
            focusNode: _pickupFocus,
            label: 'Pickup',
            icon: Icons.my_location_rounded,
            iconColor: const Color(0xFF2563EB),
            gmapsKey: _gmapsKey,
            onChanged: (q) => _onQueryChanged(q, forPickup: true),
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              const SizedBox(width: 20),
              const Expanded(child: Divider()),
              GestureDetector(
                onTap: _swapLocations,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(Icons.swap_vert_rounded,
                      size: 18, color: Colors.black54),
                ),
              ),
              const Expanded(child: Divider()),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 6),

          _FullInput(
            controller: _destCtrl,
            focusNode: _destFocus,
            label: 'Destination',
            icon: Icons.location_on_rounded,
            iconColor: Colors.red,
            gmapsKey: _gmapsKey,
            onChanged: (q) => _onQueryChanged(q, forPickup: false),
          ),

          if (_searching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Suggestions',
                style: AppTypography.bodyMedium
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ..._suggestions.map(_buildSuggestionTile),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(PlacePrediction p) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.location_on_outlined,
            color: Colors.black54, size: 20),
      ),
      title: Text(
        p.mainText ?? p.description,
        style: AppTypography.bodyLarge
            .copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: (p.secondaryText ?? '').isEmpty
          ? null
          : Text(p.secondaryText!,
          style: AppTypography.caption.copyWith(color: Colors.black45),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      onTap: () => _selectPrediction(p, forPickup: _searchingPickup),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // VEHICLE SELECTION CONTENT
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildVehicleSelectionContent() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 4, 16, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header row ─────────────────────────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: _backToLocation,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      size: 20, color: Colors.black),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Choose a ride',
                    style: AppTypography.headlineSmall
                        .copyWith(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Route summary pill ─────────────────────────────────────────
          if (_pickup != null && _dropoff != null)
            _RouteSummaryPill(
                pickup: _pickupCtrl.text, dropoff: _destCtrl.text),
          const SizedBox(height: 16),

          // ── Vehicle cards ──────────────────────────────────────────────
          if (_loadingPrices)
            _buildShimmerCards()
          else
            ..._vehicleTypes.map(_buildVehicleCard),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // ── Payment method ─────────────────────────────────────────────
          Text('Payment method',
              style: AppTypography.bodyLarge
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _buildPaymentCards(),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // ── Promo code (collapsible) ───────────────────────────────────
          _buildPromoSection(),

          const SizedBox(height: 20),

          // ── Fare summary ───────────────────────────────────────────────
          if (_selectedVehicle?.fareEstimate != null)
            _FareSummaryRow(
              base:      _selectedVehicle!.fareEstimate!,
              discount:  _promoApplied ? _promoDiscount  : null,
              effective: _effectiveFare,
              label:     _promoApplied ? _promoLabel     : null,
            ),
          const SizedBox(height: 16),

          // ── Book button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedVehicle != null &&
                  !_requesting &&
                  !_loadingPrices
                  ? _requestRide
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _requesting
                  ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_taxi_rounded,
                      color: AppColors.primaryGold, size: 20),
                  const SizedBox(width: 10),
                  Text('Book now',
                      style: AppTypography.buttonLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Promo section ─────────────────────────────────────────────────────────

  Widget _buildPromoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _togglePromoSection,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _promoApplied
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _promoApplied
                      ? Icons.check_circle_rounded
                      : Icons.local_offer_outlined,
                  size: 18,
                  color: _promoApplied
                      ? Colors.green.shade600
                      : Colors.black54,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Have a promo code?',
                      style: AppTypography.bodyLarge
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (_promoApplied && _promoLabel != null)
                      Text(
                        '$_promoLabel applied',
                        style: AppTypography.caption.copyWith(
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _promoExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 280),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.black45,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        SizeTransition(
          sizeFactor: _promoExpandAnim ?? const AlwaysStoppedAnimation(0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _promoApplied
                              ? Colors.green.shade400
                              : _promoError != null
                              ? Colors.red.shade300
                              : Colors.grey.shade200,
                          width: (_promoApplied || _promoError != null) ? 1.5 : 1,
                        ),
                      ),
                      child: TextField(
                        controller: _promoCtrl,
                        textCapitalization: TextCapitalization.characters,
                        enabled: !_promoApplied,
                        style: AppTypography.bodyMedium
                            .copyWith(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'e.g. WEGO-SUMMER24',
                          hintStyle: AppTypography.bodyMedium
                              .copyWith(color: Colors.black38),
                          border: InputBorder.none,
                          isDense: true,
                          prefixIcon: Icon(
                            _promoApplied
                                ? Icons.check_circle_outline
                                : Icons.local_offer_outlined,
                            color: _promoApplied
                                ? Colors.green.shade600
                                : Colors.black38,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _promoLoading
                          ? null
                          : _promoApplied
                          ? _removePromo
                          : _applyPromoCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _promoApplied
                            ? Colors.green.shade600
                            : Colors.black,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: _promoLoading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white)),
                      )
                          : Text(
                        _promoApplied ? 'Remove' : 'Apply',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
              if (_promoError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 14, color: Colors.red.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _promoError!,
                        style: AppTypography.caption.copyWith(
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
              if (_promoApplied && _promoDiscount != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.celebration_outlined,
                          size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You save ${_promoDiscount!.toInt()} XAF on this ride!',
                          style: AppTypography.bodySmall.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shimmer skeleton ──────────────────────────────────────────────────────

  Widget _buildShimmerCards() {
    if (_shimmerAnim == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _shimmerAnim!,
      builder: (_, __) {
        return Column(
          children: List.generate(3, (i) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: const [0.0, 0.5, 1.0],
                  colors: [
                    Colors.grey.shade200,
                    Colors.grey.shade100,
                    Colors.grey.shade200,
                  ],
                  transform: GradientRotation(_shimmerAnim!.value),
                ),
              ),
              child: Row(
                children: [
                  Container(
                      width: 72,
                      height: 52,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            height: 13, width: 70, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Container(
                            height: 10, width: 100, color: Colors.grey.shade300),
                      ],
                    ),
                  ),
                  Container(
                      height: 16, width: 56, color: Colors.grey.shade300),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  // ── Vehicle card ──────────────────────────────────────────────────────────

  Widget _buildVehicleCard(VehicleType vehicle) {
    final isSelected = _selectedVehicle == vehicle;
    final hasPrice   = vehicle.fareEstimate != null;

    return GestureDetector(
      onTap: hasPrice
          ? () async {
        HapticFeedback.selectionClick();
        setState(() => _selectedVehicle = vehicle);
        await _silentRevalidatePromo(vehicle);
      }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF9E6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
                color: AppColors.primaryGold.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 76,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    vehicle.assetImage,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.directions_car_rounded,
                      size: 32,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vehicle.name,
                    style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: hasPrice ? Colors.black : Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          vehicle.etaLabel,
                          style: AppTypography.bodySmall
                              .copyWith(color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.person_outline,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text('${vehicle.passengers}',
                          style: AppTypography.bodySmall
                              .copyWith(color: Colors.black54)),
                    ],
                  ),
                  if (vehicle.distanceText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        vehicle.distanceText!,
                        style: AppTypography.caption
                            .copyWith(color: Colors.black38),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasPrice)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${vehicle.fareEstimate!.toInt()}',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black),
                            ),
                          )
                        else
                          Text('N/A',
                              style: AppTypography.bodyMedium
                                  .copyWith(color: Colors.grey)),
                        if (hasPrice)
                          Text('XAF',
                              style: AppTypography.caption
                                  .copyWith(color: Colors.black45)),
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                          color: AppColors.primaryGold,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.check,
                          size: 13, color: Colors.black),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Payment cards ─────────────────────────────────────────────────────────

  Widget _buildPaymentCards() {
    final methods = [
      _PaymentMethod(
        value: 'cash',
        label: 'Cash',
        subtitle: 'Pay in person',
        icon: Icons.payments_outlined,
        iconColor: Colors.green.shade700,
        bgColor: Colors.green.shade50,
      ),
      _PaymentMethod(
        value: 'om',
        label: 'Orange Money',
        subtitle: 'Mobile payment',
        assetImage: 'assets/images/om.png',
        iconColor: Colors.orange,
        bgColor: Colors.orange.shade50,
      ),
      _PaymentMethod(
        value: 'momo',
        label: 'MTN MoMo',
        subtitle: 'Mobile payment',
        assetImage: 'assets/images/momo.png',
        iconColor: Colors.yellow.shade700,
        bgColor: Colors.yellow.shade50,
      ),
    ];

    return Row(
      children: methods.map((m) {
        final selected = _selectedPaymentMethod == m.value;
        final isLast   = m.value == 'momo';
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPaymentMethod = m.value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: isLast ? 0 : 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFFFF9E6) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppColors.primaryGold
                      : Colors.grey.shade200,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  m.assetImage != null
                      ? SizedBox(
                    width: 26,
                    height: 26,
                    child: Image.asset(
                      m.assetImage!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.phone_android,
                        color: m.iconColor,
                        size: 22,
                      ),
                    ),
                  )
                      : Icon(m.icon ?? Icons.payments_outlined,
                      color: m.iconColor, size: 24),
                  const SizedBox(height: 5),
                  Text(
                    m.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.black : Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // FAVORITES DIALOGS
  // ═════════════════════════════════════════════════════════════════════════

  void _showAddFavoriteDialog(String name, String address) {
    final nameCtrl = TextEditingController(text: name);
    IconData selectedIcon = Icons.location_on;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Add to favorites',
              style: AppTypography.headlineSmall
                  .copyWith(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Place name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Choose an icon',
                  style: AppTypography.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  Icons.home,
                  Icons.work,
                  Icons.local_movies,
                  Icons.local_cafe,
                  Icons.shopping_cart,
                  Icons.restaurant,
                  Icons.local_hospital,
                  Icons.school,
                  Icons.location_on,
                ].map((icon) => GestureDetector(
                  onTap: () => setS(() => selectedIcon = icon),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selectedIcon == icon
                          ? AppColors.primaryGold
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon,
                        size: 22,
                        color: selectedIcon == icon
                            ? Colors.black
                            : Colors.black54),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: AppTypography.bodyLarge
                      .copyWith(color: Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _favoritePlaces.add(FavoritePlace(
                    name:    nameCtrl.text.trim(),
                    address: address,
                    time:    '',
                    icon:    selectedIcon,
                  ));
                });
                await _saveFavoritePlaces();
                Navigator.pop(ctx);
                _snack('Added to favorites');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showManageFavoritesDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Manage favorites',
            style: AppTypography.headlineSmall
                .copyWith(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: _favoritePlaces.isEmpty
              ? Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No favorites to manage',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium
                    .copyWith(color: Colors.black45)),
          )
              : ListView.builder(
            shrinkWrap: true,
            itemCount: _favoritePlaces.length,
            itemBuilder: (ctx, i) {
              final p = _favoritePlaces[i];
              return ListTile(
                leading: Icon(p.icon, color: AppColors.primaryGold),
                title: Text(p.name,
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.w600)),
                subtitle: p.address.isNotEmpty
                    ? Text(p.address, style: AppTypography.caption)
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  onPressed: () {
                    _removeFavorite(i);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATELESS SUB-WIDGETS  (unchanged)
// ═══════════════════════════════════════════════════════════════════════════

class _TopSearchBar extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback onTap;

  const _TopSearchBar({required this.userData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final firstName = userData?['first_name']?.toString() ?? 'U';
    final initial   = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';
    final avatarUrl = userData?['avatar_url']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Colors.black87, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Where are you going?',
                  style: AppTypography.bodyLarge.copyWith(
                      color: Colors.black54, fontWeight: FontWeight.w500)),
            ),
            ClipOval(
              child: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? CachedNetworkImage(
                imageUrl: avatarUrl,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    _InitialCircle(initial: initial, size: 38),
                errorWidget: (_, __, ___) =>
                    _InitialCircle(initial: initial, size: 38),
              )
                  : _InitialCircle(initial: initial, size: 38),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialCircle extends StatelessWidget {
  final String initial;
  final double size;
  const _InitialCircle({required this.initial, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
          color: AppColors.primaryGold, shape: BoxShape.circle),
      child: Center(
        child: Text(initial,
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.42)),
      ),
    );
  }
}

class _CompactInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final ValueChanged<String> onChanged;

  const _CompactInput({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: AppTypography.bodyMedium.copyWith(color: Colors.black87),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                AppTypography.bodyMedium.copyWith(color: Colors.black38),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final Color iconColor;
  final String gmapsKey;
  final ValueChanged<String> onChanged;

  const _FullInput({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.gmapsKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focusNode.hasFocus
              ? AppColors.primaryGold
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: AppTypography.bodyLarge.copyWith(color: Colors.black87),
              decoration: InputDecoration(
                labelText: label,
                labelStyle:
                AppTypography.bodySmall.copyWith(color: Colors.black45),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSummaryPill extends StatelessWidget {
  final String pickup;
  final String dropoff;
  const _RouteSummaryPill({required this.pickup, required this.dropoff});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2))),
              Container(
                  width: 1.5, height: 20, color: Colors.grey.shade300),
              Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pickup,
                    style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Text(dropoff,
                    style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FareSummaryRow extends StatelessWidget {
  final double  base;
  final double? discount;
  final double  effective;
  final String? label;

  const _FareSummaryRow({
    required this.base,
    required this.discount,
    required this.effective,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fare estimate',
                  style: AppTypography.bodyMedium
                      .copyWith(color: Colors.black54)),
              Text(
                '${base.toInt()} XAF',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: discount != null ? Colors.black38 : Colors.black87,
                    decoration: discount != null
                        ? TextDecoration.lineThrough
                        : null),
              ),
            ],
          ),
          if (discount != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Promo discount',
                        style: AppTypography.bodyMedium
                            .copyWith(color: Colors.green.shade700)),
                    if (label != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          label!,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '-${discount!.toInt()} XAF',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.w800)),
                Text('${effective.toInt()} XAF',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.black)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentMethod {
  final String value;
  final String label;
  final String subtitle;
  final IconData? icon;
  final String? assetImage;
  final Color iconColor;
  final Color bgColor;

  const _PaymentMethod({
    required this.value,
    required this.label,
    required this.subtitle,
    this.icon,
    this.assetImage,
    required this.iconColor,
    required this.bgColor,
  });
}

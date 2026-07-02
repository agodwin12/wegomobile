import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../../providers/trip_provider.dart';
import '../../../../service/api_services.dart';
import '../../../../service/socket_service.dart';
import '../../../../utils/map_style.dart';
import '../../../../widgets/map_style_button.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/app_typography.dart';
import '../../trip/searching_driver_screen.dart';
import '../../trip/driver_arriving_screen.dart';
import '../../trip/tripProgressScreen.dart';
// ride_payment_screen removed — rides are paid directly to the driver (P2P).

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
  final String id;
  final String description;
  final String? mainText;
  final String? secondaryText;
  final double lat;
  final double lng;

  PlacePrediction({
    required this.id,
    required this.description,
    this.mainText,
    this.secondaryText,
    required this.lat,
    required this.lng,
  });

  factory PlacePrediction.fromMapbox(Map<String, dynamic> json) {
    final coords  = json['geometry']?['coordinates'] as List?;
    final context = json['context'] as List? ?? [];
    final mainTxt = json['text']?.toString() ?? '';
    final full    = json['place_name']?.toString() ?? mainTxt;
    final secondary = context.take(2).map((c) => c['text']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ');

    return PlacePrediction(
      id:            json['id']?.toString() ?? '',
      description:   full,
      mainText:      mainTxt.isNotEmpty ? mainTxt : full,
      secondaryText: secondary.isNotEmpty ? secondary : null,
      lat:  (coords != null && coords.length >= 2) ? (coords[1] as num).toDouble() : 0,
      lng:  (coords != null && coords.length >= 2) ? (coords[0] as num).toDouble() : 0,
    );
  }
}

class _NearbyCar {
  final LatLng position;
  final double heading; // degrees
  const _NearbyCar(this.position, this.heading);
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

  String get _baseUrl      => dotenv.env['API_BASE_URL']        ?? '';
  String get _mapboxToken  => dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  // Dark map by default to match the ride-hailing aesthetic.
  MapStyle _mapStyle = MapStyle.dark;

  final SocketService _socketService = SocketService();

  final _pickupCtrl  = TextEditingController();
  final _destCtrl    = TextEditingController();
  final _promoCtrl   = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus   = FocusNode();
  final MapController _mapCtrl = MapController();
  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();

  AnimationController? _shimmerCtrl;
  Animation<double>?   _shimmerAnim;
  AnimationController? _promoExpandCtrl;
  Animation<double>?   _promoExpandAnim;

  String? _accessToken;
  Map<String, dynamic>? _userData;

  LatLng? _pickup;
  LatLng? _dropoff;
  static const LatLng _doualaCenter = LatLng(4.0511, 9.7679);

  List<Polyline> _polylines  = [];
  List<_NearbyCar> _nearbyCars = [];

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
    VehicleType(id: 'economy', name: 'Économique', description: 'Courses abordables', assetImage: 'assets/images/economy.png', passengers: 4),
    VehicleType(id: 'comfort', name: 'Confort',    description: 'Plus d\'espace',      assetImage: 'assets/images/comfort.png',  passengers: 4),
    VehicleType(id: 'luxury',  name: 'Luxe',       description: 'Expérience premium',  assetImage: 'assets/images/luxury.png',   passengers: 4),
  ];

  List<FavoritePlace> _favoritePlaces = [];

  // ═════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..repeat();
    _shimmerAnim = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _shimmerCtrl!, curve: Curves.easeInOut));
    _promoExpandCtrl = AnimationController(duration: const Duration(milliseconds: 280), vsync: this);
    _promoExpandAnim = CurvedAnimation(parent: _promoExpandCtrl!, curve: Curves.easeInOut);
    _initializeScreen();
    loadMapStylePref().then((s) { if (mounted) setState(() => _mapStyle = s); });
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
    _mapCtrl.dispose();
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
      if (userDataStr != null) _userData = json.decode(userDataStr);

      _setupFocusListeners();
      await _initLocation();

      if (_accessToken != null && _accessToken!.isNotEmpty) await _connectSocket();
      await _loadFavoritePlaces();

      if (widget.prefilledDestination != null) {
        await _applyPrefilledDestination(widget.prefilledDestination!);
      }

      // Recover an interrupted ride (phone died / app killed mid-trip): if the
      // passenger has an active trip, jump straight back into its live screen.
      await _resumeActiveTripIfAny();
    } catch (e) {
      debugPrint('❌ [RIDE_MAP] Init error: $e');
      _snack('Certaines fonctionnalités peuvent être limitées', isError: true);
    }
  }

  // ─── Resume an in-progress ride after an app/phone restart ──────────────────
  // Defensive: any parse failure simply leaves the passenger on the map screen.
  LatLng? _latLngFrom(dynamic lat, dynamic lng) {
    final dLat = lat is num ? lat.toDouble() : double.tryParse('${lat ?? ''}');
    final dLng = lng is num ? lng.toDouble() : double.tryParse('${lng ?? ''}');
    if (dLat == null || dLng == null) return null;
    return LatLng(dLat, dLng);
  }

  Future<void> _resumeActiveTripIfAny() async {
    try {
      if (_accessToken == null || _accessToken!.isEmpty) return;
      final resp = await ApiService.getActiveTrip(accessToken: _accessToken!);
      final trip = resp['data']?['trip'];
      if (trip == null || !mounted) return;

      final status = (trip['status'] ?? '').toString();
      final tripId = (trip['id'] ?? '').toString();
      if (tripId.isEmpty) return;

      final pick = _latLngFrom(trip['pickupLat'], trip['pickupLng']);
      final drop = _latLngFrom(trip['dropoffLat'], trip['dropoffLng']);
      if (pick == null || drop == null) return; // can't safely rebuild the screen

      final pickAddr = (trip['pickupAddress'] ?? '').toString();
      final dropAddr = (trip['dropoffAddress'] ?? '').toString();
      final driver = (trip['driver'] is Map)
          ? Map<String, dynamic>.from(trip['driver'] as Map)
          : <String, dynamic>{};

      Widget? screen;
      if (status == 'SEARCHING') {
        screen = SearchingDriverScreen(
          tripId: tripId, pickupAddress: pickAddr, dropoffAddress: dropAddr,
          pickupLocation: pick, dropoffLocation: drop,
        );
      } else if (['MATCHED', 'DRIVER_ASSIGNED', 'DRIVER_EN_ROUTE', 'DRIVER_ARRIVED'].contains(status)) {
        screen = DriverArrivingScreen(
          tripId: tripId, driver: driver,
          pickupLocation: pick, dropoffLocation: drop,
          pickupAddress: pickAddr, dropoffAddress: dropAddr,
        );
      } else if (status == 'IN_PROGRESS') {
        screen = TripInProgressScreen(
          tripId: tripId, driver: driver,
          pickupLocation: pick, dropoffLocation: drop,
          pickupAddress: pickAddr, dropoffAddress: dropAddr,
        );
      }

      if (screen != null && mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
      }
    } catch (e) {
      debugPrint('ℹ️ [RIDE_MAP] No active trip to resume (or resume skipped): $e');
    }
  }

  Future<void> _applyPrefilledDestination(Map<String, dynamic> dest) async {
    try {
      final lat  = (dest['lat']  as num?)?.toDouble();
      final lng  = (dest['lng']  as num?)?.toDouble();
      final name = dest['name']?.toString() ?? dest['address']?.toString();
      if (lat == null || lng == null || name == null) return;

      setState(() {
        _dropoff = LatLng(lat, lng);
        _destCtrl.text = name;
      });

      if (_pickup != null) {
        _fitToBoth();
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
      if (_pickupFocus.hasFocus && _currentMode != BottomSheetMode.vehicleSelection) {
        setState(() { _searchingPickup = true; _currentMode = BottomSheetMode.location; });
        _expandSheet();
      }
    });
    _destFocus.addListener(() {
      if (_destFocus.hasFocus && _currentMode != BottomSheetMode.vehicleSelection) {
        setState(() { _searchingPickup = false; _currentMode = BottomSheetMode.location; });
        _expandSheet();
      }
    });
  }

  Future<void> _connectSocket() async {
    if (_accessToken == null || _userData == null) return;
    try {
      final userId = _userData!['uuid']?.toString() ?? _userData!['id']?.toString() ?? '';
      if (userId.isEmpty) return;
      await _socketService.connect(url: _baseUrl, accessToken: _accessToken!, userId: userId, userType: 'PASSENGER');
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
      if (!serviceOn) { _showLocationServiceSnack(); _fallbackToDouala(); return; }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        _showLocationPermissionSnack();
        _fallbackToDouala();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
      setState(() { _pickup = LatLng(pos.latitude, pos.longitude); _locating = false; });
      _generateNearbyCars(_pickup!);
      await _updateLocationName(pos.latitude, pos.longitude);
      _animateTo(_pickup!, zoom: 15);
    } catch (e) {
      debugPrint('❌ Location error: $e');
      _fallbackToDouala();
    }
  }

  Future<void> _updateLocationName(double lat, double lng) async {
    try {
      final token = _mapboxToken;
      if (token.isEmpty || token.startsWith('pk.YOUR')) {
        if (mounted) setState(() => _pickupCtrl.text = 'Position actuelle');
        return;
      }
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
            '?access_token=$token&country=cm&language=fr'
            '&types=address,neighborhood,locality,place,poi&limit=1',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data     = json.decode(res.body);
        final features = data['features'] as List? ?? [];
        if (features.isNotEmpty) {
          final place = features[0];
          final text  = place['text']?.toString() ?? '';
          final context = place['context'] as List? ?? [];
          final locality = context.isNotEmpty ? context[0]['text']?.toString() ?? '' : '';
          final name = [text, locality].where((s) => s.isNotEmpty).take(2).join(', ');
          if (mounted) setState(() => _pickupCtrl.text = name.isNotEmpty ? name : 'Position actuelle');
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _pickupCtrl.text = 'Position actuelle');
  }

  void _fallbackToDouala() {
    if (!mounted) return;
    setState(() { _pickup = _doualaCenter; _locating = false; });
    _generateNearbyCars(_doualaCenter);
    _updateLocationName(_doualaCenter.latitude, _doualaCenter.longitude);
    _animateTo(_doualaCenter);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // NEARBY CARS (decorative — can be wired to socket geo-index later)
  // ═════════════════════════════════════════════════════════════════════════

  void _generateNearbyCars(LatLng center) {
    // Seed by location so the layout is stable per area but varies between places.
    final seed = (center.latitude * 1000).toInt() ^ (center.longitude * 1000).toInt();
    final rnd  = math.Random(seed);
    final cars = <_NearbyCar>[];
    final cosLat = math.cos(center.latitude * math.pi / 180);

    for (int i = 0; i < 6; i++) {
      final bearing = rnd.nextDouble() * 2 * math.pi;
      final dist    = 220 + rnd.nextDouble() * 680; // 220–900 m
      final dLat = (dist * math.cos(bearing)) / 111320;
      final dLng = (dist * math.sin(bearing)) / (111320 * (cosLat == 0 ? 1 : cosLat));
      cars.add(_NearbyCar(
        LatLng(center.latitude + dLat, center.longitude + dLng),
        rnd.nextDouble() * 360,
      ));
    }
    if (mounted) setState(() => _nearbyCars = cars);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ROUTE POLYLINE (Mapbox Directions)
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _fetchRoute() async {
    if (_pickup == null || _dropoff == null) return;
    try {
      final token = _mapboxToken;
      if (token.isEmpty || token.startsWith('pk.YOUR')) {
        _applyRoutePolyline([_pickup!, _dropoff!]);
        return;
      }
      // Mapbox expects lng,lat order
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
            '${_pickup!.longitude},${_pickup!.latitude};'
            '${_dropoff!.longitude},${_dropoff!.latitude}'
            '?access_token=$token&geometries=polyline&overview=full',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final data   = json.decode(res.body);
        final routes = data['routes'] as List? ?? [];
        if (routes.isNotEmpty) {
          final encoded = routes[0]['geometry'] as String;
          final points  = _decodePolyline(encoded);
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
    setState(() {
      _polylines = [
        // soft glow underlay
        Polyline(points: points, color: AppColors.primaryGold.withOpacity(0.25), strokeWidth: 11),
        Polyline(points: points, color: AppColors.primaryGold, strokeWidth: 5),
      ];
    });
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

  // ═════════════════════════════════════════════════════════════════════════
  // CAMERA
  // ═════════════════════════════════════════════════════════════════════════

  void _animateTo(LatLng target, {double zoom = 14}) {
    try { _mapCtrl.move(target, zoom); } catch (_) {}
  }

  void _fitToBoth() {
    if (_pickup == null || _dropoff == null) return;
    try {
      final bounds = LatLngBounds.fromPoints([_pickup!, _dropoff!]);
      _mapCtrl.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)));
    } catch (_) {}
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SWAP
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _swapLocations() async {
    if (_pickup == null && _dropoff == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      final tmpLoc  = _pickup;
      final tmpText = _pickupCtrl.text;
      _pickup  = _dropoff;
      _dropoff = tmpLoc;
      _pickupCtrl.text = _destCtrl.text;
      _destCtrl.text   = tmpText;
    });

    if (_pickup != null && _dropoff != null) {
      _fitToBoth();
      await _fetchRoute();
    } else if (_pickup != null) {
      _animateTo(_pickup!, zoom: 15);
      setState(() => _polylines = []);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BACKEND PRICING
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _fetchPricesFromBackend() async {
    if (_pickup == null || _dropoff == null || _accessToken == null) return;
    setState(() => _loadingPrices = true);
    try {
      final response = await ApiService.getRideFareEstimates(
        token:      _accessToken!,
        pickupLat:  _pickup!.latitude,
        pickupLng:  _pickup!.longitude,
        dropoffLat: _dropoff!.latitude,
        dropoffLng: _dropoff!.longitude,
      );

      if (response['success'] == true && response['data'] != null) {
        final estimates = (response['data']['estimates'] as Map<String, dynamic>?) ?? {};
        setState(() {
          for (final v in _vehicleTypes) {
            final est = estimates[v.id] as Map<String, dynamic>?;
            if (est != null) {
              v.fareEstimate = (est['fare_estimate'] as num?)?.toDouble();
              v.distanceText = est['distance_text']?.toString();
              v.durationText = est['duration_text']?.toString();
            }
          }
          _selectedVehicle = _vehicleTypes.firstWhere((v) => v.fareEstimate != null, orElse: () => _vehicleTypes[0]);
        });
      } else {
        _snack('Impossible de charger les tarifs. Réessayez.', isError: true);
      }
    } catch (e) {
      debugPrint('❌ [RIDE_MAP] Price fetch: $e');
      _snack('Impossible de charger les tarifs. Réessayez.', isError: true);
    } finally {
      if (mounted) setState(() => _loadingPrices = false);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // AUTOCOMPLETE (Mapbox Geocoding — worldwide)
  // ═════════════════════════════════════════════════════════════════════════

  void _onQueryChanged(String q, {required bool forPickup}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _runAutocomplete(q, forPickup: forPickup));
  }

  Future<void> _runAutocomplete(String q, {required bool forPickup}) async {
    final query = q.trim();
    if (query.isEmpty) { _clearSuggestions(); return; }

    setState(() { _searching = true; _searchingPickup = forPickup; });

    try {
      final token = _mapboxToken;
      if (token.isEmpty || token.startsWith('pk.YOUR')) { setState(() => _searching = false); return; }

      // Restrict to Cameroon and bias to the user's position (default: Douala
      // centre) so local neighbourhoods like "Ndokoti" surface instead of being
      // buried under global matches. autocomplete=true improves partial typing.
      final proxLng = _pickup?.longitude ?? 9.7679; // Douala
      final proxLat = _pickup?.latitude  ?? 4.0511;

      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
            '?access_token=$token&country=cm&language=fr&autocomplete=true'
            '&types=address,poi,place,locality,neighborhood,region'
            '&proximity=$proxLng,$proxLat&limit=8',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _suggestions = (data['features'] as List? ?? []).map((f) => PlacePrediction.fromMapbox(f)).toList();
        });
      }
    } catch (e) {
      debugPrint('❌ Autocomplete: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearSuggestions() => setState(() { _suggestions = []; _searching = false; });

  // Mapbox returns coordinates directly in the suggestion — no second API call needed
  Future<void> _selectPrediction(PlacePrediction p, {required bool forPickup}) async {
    if (p.lat == 0 && p.lng == 0) return;
    final pos  = LatLng(p.lat, p.lng);
    final name = p.mainText ?? p.description;

    if (forPickup) {
      setState(() => _pickup = pos);
      _pickupCtrl.text = name;
      _pickupFocus.unfocus();
      _generateNearbyCars(pos);
      _animateTo(pos, zoom: 15);
    } else {
      setState(() => _dropoff = pos);
      _destCtrl.text = name;
      _destFocus.unfocus();

      if (_pickup != null) {
        _fitToBoth();
        await _fetchRoute();
        _showAddToFavoritesOption(name, p.description);
        await _fetchPricesFromBackend();
        _showVehicleSelection();
      }
    }
    _clearSuggestions();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // PROMO CODE
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _applyPromoCode() async {
    final code = _promoCtrl.text.trim().toUpperCase();
    if (code.isEmpty) { setState(() => _promoError = 'Entrez d\'abord un code promo'); return; }
    if (_accessToken == null) return;
    if (_selectedVehicle?.fareEstimate == null) { setState(() => _promoError = 'Sélectionnez d\'abord un véhicule'); return; }

    setState(() { _promoLoading = true; _promoError = null; });
    try {
      final response = await ApiService.validateCoupon(token: _accessToken!, code: code, fareEstimate: _selectedVehicle!.fareEstimate!);
      if (response['success'] == true) {
        final data      = response['data'] as Map<String, dynamic>;
        final discount  = (data['discount_amount'] as num?)?.toDouble() ?? 0.0;
        final finalFare = (data['final_fare']       as num?)?.toDouble() ?? math.max(0, _selectedVehicle!.fareEstimate! - discount);
        setState(() {
          _promoCode = code; _promoApplied = true;
          _promoDiscount = discount; _promoFinalFare = finalFare;
          _promoLabel = data['discount_label']?.toString() ?? ''; _promoError = null; _promoLoading = false;
        });
        HapticFeedback.lightImpact();
      } else {
        setState(() { _promoError = response['message'] ?? 'Code promo invalide'; _promoLoading = false; });
      }
    } catch (e) {
      setState(() { _promoError = e.toString().replaceFirst('Exception: ', ''); _promoLoading = false; });
    }
  }

  Future<void> _silentRevalidatePromo(VehicleType vehicle) async {
    if (!_promoApplied || _promoCode.isEmpty || _accessToken == null || vehicle.fareEstimate == null) return;
    try {
      final response = await ApiService.validateCoupon(token: _accessToken!, code: _promoCode, fareEstimate: vehicle.fareEstimate!);
      if (!mounted) return;
      if (response['success'] == true) {
        final data      = response['data'] as Map<String, dynamic>;
        final discount  = (data['discount_amount'] as num?)?.toDouble() ?? 0.0;
        final finalFare = (data['final_fare']       as num?)?.toDouble() ?? math.max(0, vehicle.fareEstimate! - discount);
        setState(() { _promoDiscount = discount; _promoFinalFare = finalFare; _promoLabel = data['discount_label']?.toString() ?? _promoLabel; });
      } else {
        _clearPromoSilently();
      }
    } catch (_) { _clearPromoSilently(); }
  }

  void _clearPromoSilently() {
    if (!mounted) return;
    setState(() { _promoApplied = false; _promoDiscount = null; _promoFinalFare = null; _promoLabel = null; _promoError = null; });
  }

  void _removePromo() {
    HapticFeedback.lightImpact();
    setState(() { _promoApplied = false; _promoDiscount = null; _promoFinalFare = null; _promoLabel = null; _promoError = null; _promoCode = ''; _promoCtrl.clear(); });
  }

  void _togglePromoSection() {
    HapticFeedback.selectionClick();
    setState(() => _promoExpanded = !_promoExpanded);
    if (_promoExpanded) _promoExpandCtrl?.forward(); else _promoExpandCtrl?.reverse();
  }

  double get _effectiveFare {
    final base = _selectedVehicle?.fareEstimate ?? 0;
    if (_promoApplied && _promoFinalFare != null)  return _promoFinalFare!;
    if (_promoApplied && _promoDiscount  != null)  return math.max(0, base - _promoDiscount!);
    return base;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SHEET HELPERS
  // ═════════════════════════════════════════════════════════════════════════

  void _expandSheet() => _sheetCtrl.animateTo(0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  void _minimizeSheet() {
    _sheetCtrl.animateTo(0.15, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    _pickupFocus.unfocus(); _destFocus.unfocus(); _clearSuggestions();
  }
  void _showVehicleSelection() {
    setState(() => _currentMode = BottomSheetMode.vehicleSelection);
    _sheetCtrl.animateTo(0.75, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }
  void _backToLocation() { setState(() => _currentMode = BottomSheetMode.minimized); _minimizeSheet(); }

  // ═════════════════════════════════════════════════════════════════════════
  // FAVORITES
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _loadFavoritePlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('favorite_places');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = json.decode(jsonStr) as List<dynamic>;
        setState(() {
          _favoritePlaces = list.map((item) => FavoritePlace(
            name: item['name'] ?? '', address: item['address'] ?? '',
            time: item['time'] ?? '', icon: _iconFromString(item['icon'] ?? 'location_on'),
          )).toList();
        });
      }
    } catch (e) { debugPrint('❌ [FAV] $e'); }
  }

  Future<void> _saveFavoritePlaces() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('favorite_places', json.encode(_favoritePlaces.map((p) => {
      'name': p.name, 'address': p.address, 'time': p.time, 'icon': _iconToString(p.icon),
    }).toList()));
  }

  Future<void> _removeFavorite(int index) async {
    setState(() => _favoritePlaces.removeAt(index));
    await _saveFavoritePlaces();
    _snack('Retiré des favoris');
  }

  void _showAddToFavoritesOption(String name, String address) {
    final already = _favoritePlaces.any((f) => f.name.toLowerCase() == name.toLowerCase() || f.address.toLowerCase() == address.toLowerCase());
    if (!already) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ajouter « $name » aux favoris ?', style: const TextStyle(color: AppColors.darkTextPrimary)),
        backgroundColor: AppColors.darkSurfaceAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'Ajouter', textColor: AppColors.primaryGold, onPressed: () => _showAddFavoriteDialog(name, address)),
      ));
    }
  }

  IconData _iconFromString(String n) {
    const map = {'home': Icons.home, 'work': Icons.work, 'local_movies': Icons.local_movies, 'local_cafe': Icons.local_cafe, 'shopping_cart': Icons.shopping_cart, 'restaurant': Icons.restaurant, 'local_hospital': Icons.local_hospital, 'school': Icons.school};
    return map[n] ?? Icons.location_on;
  }

  String _iconToString(IconData icon) {
    const map = {0xe318: 'home', 0xe943: 'work', 0xe54c: 'local_movies', 0xe541: 'local_cafe', 0xe8cb: 'shopping_cart', 0xe56c: 'restaurant', 0xe548: 'local_hospital', 0xe80c: 'school'};
    return map[icon.codePoint] ?? 'location_on';
  }

  // ═════════════════════════════════════════════════════════════════════════
  // RIDE REQUEST
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _requestRide() async {
    if (_pickup == null || _dropoff == null || _selectedVehicle == null) { _snack('Veuillez compléter les détails de la réservation', isError: true); return; }
    if (_accessToken == null || _accessToken!.isEmpty) { _snack('Session expirée. Veuillez vous reconnecter.', isError: true); Navigator.pushReplacementNamed(context, '/login'); return; }
    if (!_socketService.isConnected) {
      await _connectSocket();
      if (!_socketService.isConnected) { _snack('Erreur de connexion. Réessayez.', isError: true); return; }
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
      if (tripData == null) throw Exception('Réponse invalide du serveur');

      Provider.of<TripProvider>(context, listen: false).setCurrentTrip(tripData);

      final tripId = tripData['id'].toString();

      // Ride fares are paid directly to the driver (P2P) — there is no upfront
      // WeGo payment. Matching starts immediately, so always go to searching.
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SearchingDriverScreen(
        tripId: tripId, pickupAddress: _pickupCtrl.text, dropoffAddress: _destCtrl.text,
        pickupLocation: _pickup!, dropoffLocation: _dropoff!,
        fareEstimate: _effectiveFare > 0 ? '${_effectiveFare.toInt()} XAF' : null,
        vehicleType: _selectedVehicle!.name, paymentMethod: _selectedPaymentMethod,
      )));
    } on Exception catch (e) {
      String msg = e.toString().replaceFirst('Exception: ', '');
      final lower = msg.toLowerCase();
      _snack(msg, isError: true, isWarning: lower.contains('no driver') || lower.contains('chauffeur'));
    } catch (_) {
      _snack('Une erreur inattendue s\'est produite', isError: true);
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
      content: Text(msg, style: const TextStyle(color: AppColors.darkTextPrimary)),
      backgroundColor: isWarning ? Colors.orange.shade800 : isError ? AppColors.error : AppColors.darkSurfaceAlt,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showLocationServiceSnack() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Services de localisation désactivés', style: TextStyle(color: AppColors.darkTextPrimary)),
      backgroundColor: AppColors.darkSurfaceAlt,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: 'Activer', textColor: AppColors.primaryGold, onPressed: Geolocator.openLocationSettings),
    ));
  }

  void _showLocationPermissionSnack() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Autorisation de localisation requise', style: TextStyle(color: AppColors.darkTextPrimary)),
      backgroundColor: AppColors.darkSurfaceAlt,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: 'Paramètres', textColor: AppColors.primaryGold, onPressed: Geolocator.openAppSettings),
    ));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // MAP MARKERS
  // ═════════════════════════════════════════════════════════════════════════

  List<Marker> _buildMapMarkers() {
    final markers = <Marker>[];

    // Nearby cars render beneath pickup/dropoff.
    for (final car in _nearbyCars) {
      markers.add(Marker(point: car.position, width: 52, height: 52, child: _NearbyCarMarker(heading: car.heading)));
    }
    if (_pickup != null) {
      markers.add(Marker(point: _pickup!, width: 96, height: 96, child: _PulsingPickupMarker(userData: _userData)));
    }
    if (_dropoff != null) {
      markers.add(Marker(point: _dropoff!, width: 44, height: 44, child: const _DestinationMarker()));
    }
    return markers;
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
                initialCenter: _pickup ?? _doualaCenter,
                initialZoom:   _pickup != null ? 15.0 : 12.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapStyle.tileUrl(_mapboxToken),
                  userAgentPackageName: 'com.wego.app',
                  fallbackUrl: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                ),
                PolylineLayer(polylines: _polylines),
                MarkerLayer(markers: _buildMapMarkers()),
              ],
            ),
          ),

          MapStyleButton(
            current: _mapStyle,
            onChanged: (s) { setState(() => _mapStyle = s); saveMapStylePref(s); },
          ),

          if (_locating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: AppColors.darkBorder),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold))),
                    const SizedBox(width: 10),
                    const Text('Localisation en cours…', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary)),
                  ]),
                ),
              ),
            ),

          if (_currentMode == BottomSheetMode.minimized)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16, right: 16,
              child: _TopSearchBar(
                userData: _userData,
                onTap: () {
                  setState(() => _currentMode = BottomSheetMode.location);
                  _expandSheet();
                  Future.delayed(const Duration(milliseconds: 350), () => _destFocus.requestFocus());
                },
              ),
            ),

          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.15, minChildSize: 0.15, maxChildSize: 0.92,
            snap: true, snapSizes: const [0.15, 0.5, 0.92],
            builder: (ctx, scrollCtrl) {
              return NotificationListener<DraggableScrollableNotification>(
                onNotification: (n) {
                  if (_currentMode != BottomSheetMode.vehicleSelection) {
                    final mode = n.extent < 0.3 ? BottomSheetMode.minimized : BottomSheetMode.location;
                    if (mode != _currentMode) setState(() => _currentMode = mode);
                  }
                  return false;
                },
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
                      if (_currentMode == BottomSheetMode.minimized)    _buildMinimizedContent()
                      else if (_currentMode == BottomSheetMode.location) _buildLocationContent()
                      else                                                _buildVehicleSelectionContent(),
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Planifiez votre course', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900, color: AppColors.darkTextPrimary)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Column(children: [
                _CompactInput(controller: _pickupCtrl, focusNode: _pickupFocus, hint: 'Point de départ', icon: Icons.my_location_rounded, iconColor: const Color(0xFF4C8DFF), onChanged: (q) => _onQueryChanged(q, forPickup: true)),
                const SizedBox(height: 8),
                _CompactInput(controller: _destCtrl, focusNode: _destFocus, hint: 'Où allez-vous ?', icon: Icons.location_on_rounded, iconColor: AppColors.error, onChanged: (q) => _onQueryChanged(q, forPickup: false)),
              ])),
              const SizedBox(width: 10),
              GestureDetector(onTap: _swapLocations, child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkBorder)),
                child: const Icon(Icons.swap_vert_rounded, color: AppColors.darkTextSecondary, size: 22),
              )),
            ],
          ),
          const SizedBox(height: 24),
          if (_favoritePlaces.isNotEmpty) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Lieux favoris', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary)),
              TextButton.icon(
                onPressed: _showManageFavoritesDialog,
                icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.darkTextTertiary),
                label: Text('Gérer', style: AppTypography.caption.copyWith(color: AppColors.darkTextTertiary)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ]),
            const SizedBox(height: 10),
            ..._favoritePlaces.asMap().entries.map((e) => _buildFavoriteCard(e.value, e.key)),
            const SizedBox(height: 8),
          ] else ...[
            _buildEmptyFavoritesCard(),
            const SizedBox(height: 16),
          ],
          const _ReferralCard(),
        ],
      ),
    );
  }

  Widget _buildEmptyFavoritesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
      child: Column(children: [
        Icon(Icons.star_border_rounded, size: 42, color: AppColors.darkTextTertiary),
        const SizedBox(height: 10),
        Text('Aucun lieu favori', style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary)),
        const SizedBox(height: 6),
        Text('Ajoutez vos destinations fréquentes pour un accès rapide', textAlign: TextAlign.center, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary)),
      ]),
    );
  }

  Widget _buildFavoriteCard(FavoritePlace place, int index) {
    return Dismissible(
      key: Key('fav_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => _removeFavorite(index),
      child: GestureDetector(
        onTap: () { _destCtrl.text = place.name; _destFocus.requestFocus(); },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkBorder)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.14), borderRadius: BorderRadius.circular(8)), child: Icon(place.icon, color: AppColors.primaryGold, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (place.address.isNotEmpty) Text(place.address, style: AppTypography.caption.copyWith(color: AppColors.darkTextSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.darkTextTertiary, size: 20),
          ]),
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
          Text('Où allez-vous ?', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900, color: AppColors.darkTextPrimary)),
          const SizedBox(height: 20),
          _FullInput(controller: _pickupCtrl, focusNode: _pickupFocus, label: 'Départ', icon: Icons.my_location_rounded, iconColor: const Color(0xFF4C8DFF), onChanged: (q) => _onQueryChanged(q, forPickup: true)),
          const SizedBox(height: 6),
          Row(children: [
            const SizedBox(width: 20),
            Expanded(child: Divider(color: AppColors.darkBorder)),
            GestureDetector(
              onTap: _swapLocations,
              child: Container(margin: const EdgeInsets.symmetric(horizontal: 12), padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, shape: BoxShape.circle, border: Border.all(color: AppColors.darkBorder)), child: const Icon(Icons.swap_vert_rounded, size: 18, color: AppColors.darkTextSecondary)),
            ),
            Expanded(child: Divider(color: AppColors.darkBorder)),
            const SizedBox(width: 20),
          ]),
          const SizedBox(height: 6),
          _FullInput(controller: _destCtrl, focusNode: _destFocus, label: 'Destination', icon: Icons.location_on_rounded, iconColor: AppColors.error, onChanged: (q) => _onQueryChanged(q, forPickup: false)),
          if (_searching)
            Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold))))
          else if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Suggestions', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary)),
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
      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.darkBorder)), child: const Icon(Icons.location_on_outlined, color: AppColors.primaryGold, size: 20)),
      title: Text(p.mainText ?? p.description, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: (p.secondaryText ?? '').isEmpty ? null : Text(p.secondaryText!, style: AppTypography.caption.copyWith(color: AppColors.darkTextSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _selectPrediction(p, forPickup: _searchingPickup),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // VEHICLE SELECTION CONTENT
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildVehicleSelectionContent() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(onTap: _backToLocation, child: Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.darkBorder)), child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.darkTextPrimary))),
            const SizedBox(width: 12),
            Expanded(child: Text('Choisissez une course', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900, color: AppColors.darkTextPrimary))),
          ]),
          const SizedBox(height: 16),
          if (_pickup != null && _dropoff != null)
            _RouteSummaryPill(pickup: _pickupCtrl.text, dropoff: _destCtrl.text),
          const SizedBox(height: 16),
          if (_loadingPrices) _buildShimmerCards() else ..._vehicleTypes.map(_buildVehicleCard),
          const SizedBox(height: 8),
          Divider(height: 1, color: AppColors.darkDivider),
          const SizedBox(height: 16),
          Text('Mode de paiement', style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary)),
          const SizedBox(height: 10),
          _buildPaymentCards(),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.darkDivider),
          const SizedBox(height: 16),
          _buildPromoSection(),
          const SizedBox(height: 20),
          if (_selectedVehicle?.fareEstimate != null)
            _FareSummaryRow(base: _selectedVehicle!.fareEstimate!, discount: _promoApplied ? _promoDiscount : null, effective: _effectiveFare, label: _promoApplied ? _promoLabel : null),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _selectedVehicle != null && !_requesting && !_loadingPrices ? _requestRide : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold, disabledBackgroundColor: AppColors.darkSurfaceHigh, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
              child: _requesting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary)))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.local_taxi_rounded, color: AppColors.textPrimary, size: 20),
                const SizedBox(width: 10),
                Text('Commander', style: AppTypography.buttonLarge.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _togglePromoSection,
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: _promoApplied ? AppColors.success.withOpacity(0.16) : AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(8), border: Border.all(color: _promoApplied ? AppColors.success.withOpacity(0.4) : AppColors.darkBorder)),
              child: Icon(_promoApplied ? Icons.check_circle_rounded : Icons.local_offer_outlined, size: 18, color: _promoApplied ? AppColors.success : AppColors.darkTextSecondary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vous avez un code promo ?', style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary)),
              if (_promoApplied && _promoLabel != null)
                Text('$_promoLabel appliqué', style: AppTypography.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
            ])),
            AnimatedRotation(turns: _promoExpanded ? 0.5 : 0.0, duration: const Duration(milliseconds: 280), child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.darkTextTertiary, size: 22)),
          ]),
        ),
        SizeTransition(
          sizeFactor: _promoExpandAnim ?? const AlwaysStoppedAnimation(0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _promoApplied ? AppColors.success.withOpacity(0.6) : _promoError != null ? AppColors.error.withOpacity(0.6) : AppColors.darkBorder, width: (_promoApplied || _promoError != null) ? 1.5 : 1),
                    ),
                    child: TextField(
                      controller: _promoCtrl, textCapitalization: TextCapitalization.characters, enabled: !_promoApplied,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'ex. WEGO-ETE24', hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextTertiary),
                        border: InputBorder.none, isDense: true,
                        prefixIcon: Icon(_promoApplied ? Icons.check_circle_outline : Icons.local_offer_outlined, color: _promoApplied ? AppColors.success : AppColors.darkTextTertiary, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _promoLoading ? null : _promoApplied ? _removePromo : _applyPromoCode,
                    style: ElevatedButton.styleFrom(backgroundColor: _promoApplied ? AppColors.darkSurfaceHigh : AppColors.primaryGold, disabledBackgroundColor: AppColors.darkSurfaceHigh, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16)),
                    child: _promoLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold)))
                        : Text(_promoApplied ? 'Retirer' : 'Appliquer', style: TextStyle(color: _promoApplied ? AppColors.darkTextPrimary : AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ]),
              if (_promoError != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_promoError!, style: AppTypography.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.w500))),
                ]),
              ],
              if (_promoApplied && _promoDiscount != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.success.withOpacity(0.4))),
                  child: Row(children: [
                    Icon(Icons.celebration_outlined, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Vous économisez ${_promoDiscount!.toInt()} XAF sur cette course !', style: AppTypography.bodySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w600))),
                  ]),
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerCards() {
    if (_shimmerAnim == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _shimmerAnim!,
      builder: (_, __) => Column(
        children: List.generate(3, (_) => Container(
          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, stops: const [0.0, 0.5, 1.0], colors: [AppColors.darkSurfaceAlt, AppColors.darkSurfaceHigh, AppColors.darkSurfaceAlt], transform: GradientRotation(_shimmerAnim!.value))),
          child: Row(children: [
            Container(width: 72, height: 52, decoration: BoxDecoration(color: AppColors.darkSurfaceHigh, borderRadius: BorderRadius.circular(10))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 13, width: 70, color: AppColors.darkSurfaceHigh), const SizedBox(height: 8), Container(height: 10, width: 100, color: AppColors.darkSurfaceHigh)])),
            Container(height: 16, width: 56, color: AppColors.darkSurfaceHigh),
          ]),
        )),
      ),
    );
  }

  Widget _buildVehicleCard(VehicleType vehicle) {
    final isSelected = _selectedVehicle == vehicle;
    final hasPrice   = vehicle.fareEstimate != null;
    return GestureDetector(
      onTap: hasPrice ? () async { HapticFeedback.selectionClick(); setState(() => _selectedVehicle = vehicle); await _silentRevalidatePromo(vehicle); } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold.withOpacity(0.10) : AppColors.darkSurfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primaryGold : AppColors.darkBorder, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primaryGold.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 4))] : [],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(width: 76, height: 54, child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.darkSurfaceHigh, borderRadius: BorderRadius.circular(10)),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset(vehicle.assetImage, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.directions_car_rounded, size: 32, color: AppColors.darkTextTertiary))),
          )),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(vehicle.name, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800, color: hasPrice ? AppColors.darkTextPrimary : AppColors.darkTextTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 11, color: AppColors.darkTextTertiary), const SizedBox(width: 3),
              Flexible(child: Text(vehicle.etaLabel, style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Icon(Icons.person_outline, size: 11, color: AppColors.darkTextTertiary), const SizedBox(width: 3),
              Text('${vehicle.passengers}', style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary)),
            ]),
            if (vehicle.distanceText != null)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(vehicle.distanceText!, style: AppTypography.caption.copyWith(color: AppColors.darkTextTertiary), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ])),
          const SizedBox(width: 8),
          SizedBox(width: 76, child: Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.center, children: [
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              if (hasPrice) FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text('${vehicle.fareEstimate!.toInt()}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primaryGold)))
              else Text('N/D', style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextTertiary)),
              if (hasPrice) Text('XAF', style: AppTypography.caption.copyWith(color: AppColors.darkTextSecondary)),
            ])),
            if (isSelected) ...[const SizedBox(width: 6), Container(width: 20, height: 20, decoration: const BoxDecoration(color: AppColors.primaryGold, shape: BoxShape.circle), child: const Icon(Icons.check, size: 13, color: AppColors.textPrimary))],
          ])),
        ]),
      ),
    );
  }

  Widget _buildPaymentCards() {
    final methods = [
      _PaymentMethod(value: 'cash', label: 'Espèces', subtitle: 'En personne', icon: Icons.payments_outlined, iconColor: AppColors.success),
      _PaymentMethod(value: 'om',   label: 'Orange Money', subtitle: 'Paiement mobile', assetImage: 'assets/images/om.png', iconColor: Colors.orange),
      _PaymentMethod(value: 'momo', label: 'MTN MoMo', subtitle: 'Paiement mobile', assetImage: 'assets/images/momo.png', iconColor: AppColors.primaryGold),
    ];

    return Row(children: methods.map((m) {
      final selected = _selectedPaymentMethod == m.value;
      final isLast   = m.value == 'momo';
      return Expanded(child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedPaymentMethod = m.value); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(right: isLast ? 0 : 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryGold.withOpacity(0.10) : AppColors.darkSurfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primaryGold : AppColors.darkBorder, width: selected ? 2 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            m.assetImage != null
                ? SizedBox(width: 26, height: 26, child: Image.asset(m.assetImage!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.phone_android, color: m.iconColor, size: 22)))
                : Icon(m.icon ?? Icons.payments_outlined, color: m.iconColor, size: 24),
            const SizedBox(height: 5),
            Text(m.label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: selected ? AppColors.darkTextPrimary : AppColors.darkTextSecondary)),
          ]),
        ),
      ));
    }).toList());
  }

  // ═════════════════════════════════════════════════════════════════════════
  // FAVORITES DIALOGS
  // ═════════════════════════════════════════════════════════════════════════

  void _showAddFavoriteDialog(String name, String address) {
    final nameCtrl = TextEditingController(text: name);
    IconData selectedIcon = Icons.location_on;
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Ajouter aux favoris', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: nameCtrl,
          style: const TextStyle(color: AppColors.darkTextPrimary),
          decoration: InputDecoration(
            labelText: 'Nom du lieu',
            labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.darkBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGold)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Choisissez une icône', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [Icons.home, Icons.work, Icons.local_movies, Icons.local_cafe, Icons.shopping_cart, Icons.restaurant, Icons.local_hospital, Icons.school, Icons.location_on].map((icon) => GestureDetector(
          onTap: () => setS(() => selectedIcon = icon),
          child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: selectedIcon == icon ? AppColors.primaryGold : AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: selectedIcon == icon ? AppColors.primaryGold : AppColors.darkBorder)), child: Icon(icon, size: 22, color: selectedIcon == icon ? AppColors.textPrimary : AppColors.darkTextSecondary)),
        )).toList()),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: AppTypography.bodyLarge.copyWith(color: AppColors.darkTextSecondary))),
        ElevatedButton(
          onPressed: () async {
            setState(() { _favoritePlaces.add(FavoritePlace(name: nameCtrl.text.trim(), address: address, time: '', icon: selectedIcon)); });
            await _saveFavoritePlaces();
            Navigator.pop(ctx);
            _snack('Ajouté aux favoris');
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold, foregroundColor: AppColors.textPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    )));
  }

  void _showManageFavoritesDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Gérer les favoris', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.darkTextPrimary)),
      content: SizedBox(width: double.maxFinite, child: _favoritePlaces.isEmpty
          ? Padding(padding: const EdgeInsets.all(24), child: Text('Aucun favori à gérer', textAlign: TextAlign.center, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary)))
          : ListView.builder(shrinkWrap: true, itemCount: _favoritePlaces.length, itemBuilder: (ctx, i) {
        final p = _favoritePlaces[i];
        return ListTile(
          leading: Icon(p.icon, color: AppColors.primaryGold),
          title: Text(p.name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary)),
          subtitle: p.address.isNotEmpty ? Text(p.address, style: AppTypography.caption.copyWith(color: AppColors.darkTextSecondary)) : null,
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: () { _removeFavorite(i); Navigator.pop(context); }),
        );
      })),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer', style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary)))],
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MAP MARKER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _PulsingPickupMarker extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const _PulsingPickupMarker({required this.userData});

  @override
  State<_PulsingPickupMarker> createState() => _PulsingPickupMarkerState();
}

class _PulsingPickupMarkerState extends State<_PulsingPickupMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  Widget _ring(double t) {
    final size    = 38 + t * 54;
    final opacity = (1 - t).clamp(0.0, 1.0) * 0.55;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryGold.withOpacity(opacity * 0.22),
        border: Border.all(color: AppColors.primaryGold.withOpacity(opacity), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.userData?['first_name']?.toString() ?? 'U';
    final initial   = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';
    final avatarUrl = widget.userData?['avatar_url']?.toString();

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          _ring(_c.value),
          _ring((_c.value + 0.5) % 1.0),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryGold,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
            ),
            child: ClipOval(
              child: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => _initial(initial))
                  : _initial(initial),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initial(String initial) => Center(
    child: Text(initial, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
  );
}

class _NearbyCarMarker extends StatefulWidget {
  final double heading;
  const _NearbyCarMarker({required this.heading});

  @override
  State<_NearbyCarMarker> createState() => _NearbyCarMarkerState();
}

class _NearbyCarMarkerState extends State<_NearbyCarMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Subtle idle creep so cars feel alive without rebuilding the map.
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final forward = -1.5 + _c.value * 3.0; // ±1.5px along heading
        return Transform.rotate(
          angle: widget.heading * math.pi / 180,
          child: Transform.translate(
            offset: Offset(0, forward),
            child: CustomPaint(size: const Size(22, 38), painter: _CarPainter()),
          ),
        );
      },
    );
  }
}

class _CarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final body = Paint()..color = AppColors.primaryGold;
    final glass = Paint()..color = const Color(0xFF15151A).withOpacity(0.9);
    final light = Paint()..color = Colors.white.withOpacity(0.92);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.66, height: h * 0.92),
      Radius.circular(w * 0.24),
    );

    // drop shadow
    canvas.drawRRect(bodyRect.shift(const Offset(0, 1.6)), shadow);
    // body
    canvas.drawRRect(bodyRect, body);

    // windshield (front, top) + rear window
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, h * 0.31), width: w * 0.46, height: h * 0.17), const Radius.circular(2.5)),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, h * 0.67), width: w * 0.46, height: h * 0.15), const Radius.circular(2.5)),
      glass,
    );

    // headlights
    canvas.drawCircle(Offset(w * 0.40, h * 0.10), 1.3, light);
    canvas.drawCircle(Offset(w * 0.60, h * 0.10), 1.3, light);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: const Icon(Icons.flag_rounded, color: Colors.white, size: 15),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATELESS SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _ReferralCard extends StatelessWidget {
  const _ReferralCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(color: AppColors.textPrimary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.card_giftcard_rounded, color: AppColors.textPrimary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Parrainez & gagnez', style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Invitez un ami ou un chauffeur et recevez 1 000 XAF de bonus pour chaque inscription !', style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary.withOpacity(0.85))),
        ])),
      ]),
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.darkBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 5))],
        ),
        child: Row(children: [
          const Icon(Icons.search_rounded, color: AppColors.darkTextPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text('Où allez-vous ?', style: AppTypography.bodyLarge.copyWith(color: AppColors.darkTextSecondary, fontWeight: FontWeight.w500))),
          ClipOval(child: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? CachedNetworkImage(imageUrl: avatarUrl, width: 38, height: 38, fit: BoxFit.cover, placeholder: (_, __) => _InitialCircle(initial: initial, size: 38), errorWidget: (_, __, ___) => _InitialCircle(initial: initial, size: 38))
              : _InitialCircle(initial: initial, size: 38)),
        ]),
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
      width: size, height: size,
      decoration: const BoxDecoration(color: AppColors.primaryGold, shape: BoxShape.circle),
      child: Center(child: Text(initial, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: size * 0.42))),
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
  const _CompactInput({required this.controller, required this.focusNode, required this.hint, required this.icon, required this.iconColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkBorder)),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 18), const SizedBox(width: 10),
        Expanded(child: TextField(controller: controller, focusNode: focusNode, style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary), decoration: InputDecoration(hintText: hint, hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextTertiary), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero), onChanged: onChanged)),
      ]),
    );
  }
}

class _FullInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final Color iconColor;
  final ValueChanged<String> onChanged;
  const _FullInput({required this.controller, required this.focusNode, required this.label, required this.icon, required this.iconColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: focusNode.hasFocus ? AppColors.primaryGold : AppColors.darkBorder, width: focusNode.hasFocus ? 2 : 1),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 20), const SizedBox(width: 14),
        Expanded(child: TextField(controller: controller, focusNode: focusNode, style: AppTypography.bodyLarge.copyWith(color: AppColors.darkTextPrimary), decoration: InputDecoration(labelText: label, labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary), border: InputBorder.none, isDense: true), onChanged: onChanged)),
      ]),
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
      decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
      child: Row(children: [
        Column(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: const Color(0xFF4C8DFF), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
          Container(width: 1.5, height: 20, color: AppColors.darkBorder),
          Container(width: 9, height: 9, decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pickup, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Text(dropoff, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

class _FareSummaryRow extends StatelessWidget {
  final double  base;
  final double? discount;
  final double  effective;
  final String? label;
  const _FareSummaryRow({required this.base, required this.discount, required this.effective, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primaryGold.withOpacity(0.35))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Tarif estimé', style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary)),
          Text('${base.toInt()} XAF', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: discount != null ? AppColors.darkTextTertiary : AppColors.darkTextPrimary, decoration: discount != null ? TextDecoration.lineThrough : null)),
        ]),
        if (discount != null) ...[
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Text('Réduction promo', style: AppTypography.bodyMedium.copyWith(color: AppColors.success)),
              if (label != null) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.18), borderRadius: BorderRadius.circular(4)), child: Text(label!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)))],
            ]),
            Text('-${discount!.toInt()} XAF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
          ]),
          const SizedBox(height: 8), Divider(height: 1, color: AppColors.primaryGold.withOpacity(0.2)), const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total', style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w800, color: AppColors.darkTextPrimary)),
            Text('${effective.toInt()} XAF', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primaryGold)),
          ]),
        ],
      ]),
    );
  }
}

class _PaymentMethod {
  final String value, label, subtitle;
  final IconData? icon;
  final String? assetImage;
  final Color iconColor;
  const _PaymentMethod({required this.value, required this.label, required this.subtitle, this.icon, this.assetImage, required this.iconColor});
}
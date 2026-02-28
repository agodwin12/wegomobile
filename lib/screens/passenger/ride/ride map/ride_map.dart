// lib/presentation/screens/ride/ride_map_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

enum BottomSheetMode { minimized, location, vehicleSelection }

class VehicleType {
  final String id;
  final String name;
  final String description;
  final String assetImage;
  final int passengers;
  final String eta;

  // Pricing from backend
  double? fareEstimate;
  String? distanceText;
  String? durationText;

  VehicleType({
    required this.id,
    required this.name,
    required this.description,
    required this.assetImage,
    required this.passengers,
    required this.eta,
    this.fareEstimate,
    this.distanceText,
    this.durationText,
  });
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

class RideMapScreen extends StatefulWidget {
  final Map<String, dynamic>? prefilledDestination;

  const RideMapScreen({
    super.key,
    this.prefilledDestination,
  });

  @override
  State<RideMapScreen> createState() => _RideMapScreenState();
}

class _RideMapScreenState extends State<RideMapScreen>
    with TickerProviderStateMixin {
  // Config
  String get _baseUrl => dotenv.env['API_BASE_URL'] ?? '';
  String get _gmapsKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Services
  final SocketService _socketService = SocketService();

  // Controllers
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus = FocusNode();
  GoogleMapController? _mapCtrl;
  final DraggableScrollableController _sheetController =
  DraggableScrollableController();

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Auth
  String? _accessToken;
  Map<String, dynamic>? _userData;

  // State
  LatLng? _pickup;
  LatLng? _dropoff;
  bool _requesting = false;
  bool _locating = true;
  bool _loadingPrices = false;
  BottomSheetMode _currentMode = BottomSheetMode.minimized;
  VehicleType? _selectedVehicle;
  String _selectedPaymentMethod = 'cash';
  double _currentSheetSize = 0.15;

  // Autocomplete
  List<PlacePrediction> _suggestions = [];
  bool _searching = false;
  bool _searchingPickup = true;
  Timer? _debounce;

  final _markers = <MarkerId, Marker>{};
  static const LatLng _doualaCenter = LatLng(4.0511, 9.7679);

  // Vehicle types — NO hardcoded prices, fares come from backend
  final List<VehicleType> _vehicleTypes = [
    VehicleType(
      id: 'economy',
      name: 'Economy',
      description: 'Affordable rides',
      assetImage: 'assets/images/economy.png',
      passengers: 4,
      eta: '2 min',
    ),
    VehicleType(
      id: 'comfort',
      name: 'Comfort',
      description: 'Extra legroom',
      assetImage: 'assets/images/comfort.png',
      passengers: 4,
      eta: '3 min',
    ),
    VehicleType(
      id: 'luxury',
      name: 'Luxury',
      description: 'Premium experience',
      assetImage: 'assets/images/luxury.png',
      passengers: 4,
      eta: '5 min',
    ),
  ];

  List<FavoritePlace> _favoritePlaces = [];

  // ─────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🗺️ [RIDE_MAP] Initializing...');
    _initializeScreen();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pulseController.dispose();
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    _mapCtrl?.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────

  Future<void> _initializeScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');

      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        _userData = json.decode(userDataString);
        print('👤 [RIDE_MAP] User: ${_userData?['first_name']}');
        print('🖼️ [RIDE_MAP] Avatar: ${_userData?['avatar_url'] ?? "None"}');
      }

      _setupAnimations();
      _setupFocusListeners();
      await _initLocation();

      if (_accessToken != null && _accessToken!.isNotEmpty) {
        await _connectSocket();
      }

      await _loadFavoritePlaces();
      print('✅ [RIDE_MAP] Initialized\n');
    } catch (e) {
      print('❌ [RIDE_MAP] Init error: $e');
      _showErrorSnackBar('Some features may be limited');
    }
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  void _setupFocusListeners() {
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) {
        setState(() => _searchingPickup = true);
        _expandSheet();
      }
    });
    _destFocus.addListener(() {
      if (_destFocus.hasFocus) {
        setState(() => _searchingPickup = false);
        _expandSheet();
      }
    });
  }

  Future<void> _connectSocket() async {
    if (_accessToken == null || _userData == null) return;
    try {
      final userId = _userData!['uuid']?.toString() ??
          _userData!['id']?.toString() ??
          '';
      if (userId.isEmpty) return;
      await _socketService.connect(
        url: _baseUrl,
        accessToken: _accessToken!,
        userId: userId,
        userType: 'PASSENGER',
      );
    } catch (e) {
      print('❌ [RIDE_MAP] Socket failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LOCATION
  // ─────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    setState(() => _locating = true);
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _showLocationServiceSnackBar();
        _fallbackToDouala();
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        _showLocationPermissionSnackBar();
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
      setState(() => _locating = false);
      _animateTo(_pickup!, zoom: 15);
    } catch (e) {
      print('❌ Location error: $e');
      _fallbackToDouala();
    }
  }

  Future<void> _updateLocationName(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        String name = p.street ?? p.name ?? 'Current Location';
        if (p.locality != null && p.locality!.isNotEmpty) {
          name += ', ${p.locality}';
        }
        _pickupCtrl.text = name;
      } else {
        _pickupCtrl.text = 'Current Location';
      }
    } catch (_) {
      _pickupCtrl.text = 'Current Location';
    }
  }

  void _fallbackToDouala() {
    setState(() {
      _pickup = _doualaCenter;
      _locating = false;
    });
    _updateLocationName(_doualaCenter.latitude, _doualaCenter.longitude);
    _createUserMarker();
    _animateTo(_pickup!);
  }

  // ─────────────────────────────────────────────────────────────
  // MARKERS
  // ─────────────────────────────────────────────────────────────

  Future<void> _createUserMarker() async {
    if (_pickup == null) return;
    try {
      final firstName =
          _userData?['first_name']?.toString() ?? 'U';
      final initial =
      firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';
      final avatarUrl = _userData?['avatar_url']?.toString();

      BitmapDescriptor icon;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        icon = await _createAvatarMarker(avatarUrl, initial);
      } else {
        icon = await _createInitialMarker(initial);
      }

      const id = MarkerId('pickup');
      _markers[id] = Marker(
        markerId: id,
        position: _pickup!,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
      );
      setState(() {});
    } catch (e) {
      print('⚠️ [MARKER] Fallback to default: $e');
      _updatePickupMarker();
    }
  }

  /// Marker with the user's actual photo
  Future<BitmapDescriptor> _createAvatarMarker(
      String avatarUrl, String initial) async {
    try {
      final response = await http
          .get(Uri.parse(avatarUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return _createInitialMarker(initial);
      }

      final imageBytes = response.bodyBytes;
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 120,
        targetHeight: 120,
      );
      final frame = await codec.getNextFrame();
      final rawImage = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 120.0;

      // Gold glow ring
      final glowPaint = Paint()
        ..color = AppColors.primaryGold.withOpacity(0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          const Offset(size / 2, size / 2), size / 2, glowPaint);

      // White border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      canvas.drawCircle(
          const Offset(size / 2, size / 2), size / 2.3, borderPaint);

      // Clip to circle and draw photo
      final path = Path()
        ..addOval(Rect.fromCircle(
            center: const Offset(size / 2, size / 2), radius: size / 2.5));
      canvas.clipPath(path);

      final src = Rect.fromLTWH(
          0, 0, rawImage.width.toDouble(), rawImage.height.toDouble());
      final dst = Rect.fromCircle(
          center: const Offset(size / 2, size / 2), radius: size / 2.5);
      canvas.drawImageRect(rawImage, src, dst, Paint());

      final picture = recorder.endRecording();
      final img =
      await picture.toImage(size.toInt(), size.toInt());
      final bytes =
      await img.toByteData(format: ui.ImageByteFormat.png);

      return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
    } catch (e) {
      print('⚠️ [AVATAR_MARKER] Photo failed, using initial: $e');
      return _createInitialMarker(initial);
    }
  }

  /// Marker with the user's initial letter (fallback)
  Future<BitmapDescriptor> _createInitialMarker(String initial) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 120.0;

    final glowPaint = Paint()
      ..color = AppColors.primaryGold.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        const Offset(size / 2, size / 2), size / 2, glowPaint);

    final circlePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(size, size),
        [AppColors.primaryGold, AppColors.primaryYellow],
      );
    canvas.drawCircle(
        const Offset(size / 2, size / 2), size / 2.5, circlePaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(
        const Offset(size / 2, size / 2), size / 2.5, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: size / 3,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  void _updatePickupMarker() {
    if (_pickup == null) return;
    const id = MarkerId('pickup');
    _markers[id] = Marker(
      markerId: id,
      position: _pickup!,
      icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow),
    );
    setState(() {});
  }

  void _updateDropoffMarker() {
    if (_dropoff == null) return;
    const id = MarkerId('dropoff');
    _markers[id] = Marker(
      markerId: id,
      position: _dropoff!,
      icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed),
    );
    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────
  // CAMERA
  // ─────────────────────────────────────────────────────────────

  Future<void> _animateTo(LatLng target, {double zoom = 14}) async {
    if (_mapCtrl == null) return;
    await _mapCtrl!.animateCamera(
      CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom)),
    );
  }

  Future<void> _fitToBoth() async {
    if (_mapCtrl == null || _pickup == null || _dropoff == null) return;
    final sw = LatLng(
      _pickup!.latitude < _dropoff!.latitude
          ? _pickup!.latitude
          : _dropoff!.latitude,
      _pickup!.longitude < _dropoff!.longitude
          ? _pickup!.longitude
          : _dropoff!.longitude,
    );
    final ne = LatLng(
      _pickup!.latitude > _dropoff!.latitude
          ? _pickup!.latitude
          : _dropoff!.latitude,
      _pickup!.longitude > _dropoff!.longitude
          ? _pickup!.longitude
          : _dropoff!.longitude,
    );
    await _mapCtrl!
        .animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne), 100));
  }

  // ─────────────────────────────────────────────────────────────
  // BACKEND PRICING
  // ─────────────────────────────────────────────────────────────

  Future<void> _fetchPricesFromBackend() async {
    if (_pickup == null || _dropoff == null || _accessToken == null) return;

    setState(() => _loadingPrices = true);

    try {
      print('💰 [RIDE_MAP] Fetching prices from backend...');
      final response = await ApiService.getRideFareEstimates(
        token: _accessToken!,
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        dropoffLat: _dropoff!.latitude,
        dropoffLng: _dropoff!.longitude,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final estimates =
            data['estimates'] as Map<String, dynamic>? ?? {};

        setState(() {
          for (final vehicle in _vehicleTypes) {
            final est = estimates[vehicle.id] as Map<String, dynamic>?;
            if (est != null) {
              vehicle.fareEstimate =
                  (est['fare_estimate'] as num?)?.toDouble();
              vehicle.distanceText =
                  est['distance_text']?.toString();
              vehicle.durationText =
                  est['duration_text']?.toString();
            }
          }
          // Default selection to first vehicle with a price
          _selectedVehicle = _vehicleTypes.firstWhere(
                (v) => v.fareEstimate != null,
            orElse: () => _vehicleTypes[0],
          );
        });

        print('✅ [RIDE_MAP] Prices loaded');
      } else {
        print('⚠️ [RIDE_MAP] No price data in response');
        _showErrorSnackBar('Could not load prices. Please try again.');
      }
    } catch (e) {
      print('❌ [RIDE_MAP] Price fetch error: $e');
      _showErrorSnackBar('Could not load prices. Please try again.');
    } finally {
      if (mounted) setState(() => _loadingPrices = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // AUTOCOMPLETE
  // ─────────────────────────────────────────────────────────────

  void _onQueryChanged(String q, {required bool forPickup}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runAutocomplete(q, forPickup: forPickup);
    });
  }

  Future<void> _runAutocomplete(String q,
      {required bool forPickup}) async {
    if (!(_pickupFocus.hasFocus || _destFocus.hasFocus)) return;
    final query = q.trim();
    if (query.isEmpty) {
      _clearSuggestions();
      return;
    }

    setState(() {
      _searching = true;
      _searchingPickup = forPickup;
    });

    try {
      final location = _pickup != null
          ? '${_pickup!.latitude},${_pickup!.longitude}'
          : '';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=${Uri.encodeComponent(query)}'
            '&key=$_gmapsKey'
            '${location.isNotEmpty ? '&location=$location&radius=20000' : ''}'
            '',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = (data['predictions'] as List? ?? [])
            .map((p) => PlacePrediction.fromJson(p))
            .toList();
        setState(() => _suggestions = predictions);
      } else {
        setState(() => _suggestions = []);
      }
    } catch (e) {
      print('❌ Autocomplete error: $e');
      setState(() => _suggestions = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearSuggestions() {
    if (_suggestions.isNotEmpty || _searching) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
    }
  }

  Future<void> _selectPrediction(PlacePrediction p,
      {required bool forPickup}) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=${p.placeId}'
            '&key=$_gmapsKey'
            '&fields=geometry,name,formatted_address',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];
        if (result != null && result['geometry'] != null) {
          final location = result['geometry']['location'];
          final pos =
          LatLng(location['lat'], location['lng']);
          final name = result['name'] ?? p.description;
          final address =
              result['formatted_address'] ?? p.description;

          if (forPickup) {
            _pickup = pos;
            _pickupCtrl.text = name;
            await _createUserMarker();
            _pickupFocus.unfocus();
          } else {
            _dropoff = pos;
            _destCtrl.text = name;
            _updateDropoffMarker();
            _destFocus.unfocus();

            if (_pickup != null && _dropoff != null) {
              await _fitToBoth();
              _showAddToFavoritesOption(name, address);
              // Fetch prices THEN show vehicle selection
              await _fetchPricesFromBackend();
              _showVehicleSelection();
            }
          }

          _clearSuggestions();
          if (_pickup != null && _dropoff == null) {
            await _animateTo(pos, zoom: 15);
          }
        }
      }
    } catch (e) {
      print('❌ Place details error: $e');
      _showErrorSnackBar('Could not fetch location');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SHEET HELPERS
  // ─────────────────────────────────────────────────────────────

  void _expandSheet() {
    _sheetController.animateTo(0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
  }

  void _minimizeSheet() {
    _sheetController.animateTo(0.15,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic);
    _pickupFocus.unfocus();
    _destFocus.unfocus();
    _clearSuggestions();
  }

  void _showVehicleSelection() {
    setState(() => _currentMode = BottomSheetMode.vehicleSelection);
    _sheetController.animateTo(0.7,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic);
  }

  void _backToLocation() {
    setState(() => _currentMode = BottomSheetMode.minimized);
    _minimizeSheet();
  }

  // ─────────────────────────────────────────────────────────────
  // FAVORITES
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadFavoritePlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getString('favorite_places');
      if (favoritesJson != null && favoritesJson.isNotEmpty) {
        final list = json.decode(favoritesJson) as List<dynamic>;
        setState(() {
          _favoritePlaces = list.map((item) {
            return FavoritePlace(
              name: item['name'] ?? '',
              address: item['address'] ?? '',
              time: item['time'] ?? '',
              icon: _getIconFromString(item['icon'] ?? 'location_on'),
            );
          }).toList();
        });
      }
    } catch (e) {
      print('❌ [RIDE_MAP] Favorites error: $e');
    }
  }

  Future<void> _saveFavoritePlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _favoritePlaces.map((p) => {
      'name': p.name,
      'address': p.address,
      'time': p.time,
      'icon': _getStringFromIcon(p.icon),
    }).toList();
    await prefs.setString('favorite_places', json.encode(list));
  }

  Future<void> _addToFavorites(String name, String address) async {
    showDialog(
      context: context,
      builder: (context) => _buildAddFavoriteDialog(name, address),
    );
  }

  Future<void> _removeFavorite(int index) async {
    setState(() => _favoritePlaces.removeAt(index));
    await _saveFavoritePlaces();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Retiré des favoris'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
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
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Ajouter',
          textColor: AppColors.primaryGold,
          onPressed: () => _addToFavorites(name, address),
        ),
      ));
    }
  }

  IconData _getIconFromString(String name) {
    switch (name) {
      case 'home': return Icons.home;
      case 'work': return Icons.work;
      case 'local_movies': return Icons.local_movies;
      case 'local_cafe': return Icons.local_cafe;
      case 'shopping_cart': return Icons.shopping_cart;
      case 'restaurant': return Icons.restaurant;
      case 'local_hospital': return Icons.local_hospital;
      case 'school': return Icons.school;
      default: return Icons.location_on;
    }
  }

  String _getStringFromIcon(IconData icon) {
    if (icon == Icons.home) return 'home';
    if (icon == Icons.work) return 'work';
    if (icon == Icons.local_movies) return 'local_movies';
    if (icon == Icons.local_cafe) return 'local_cafe';
    if (icon == Icons.shopping_cart) return 'shopping_cart';
    if (icon == Icons.restaurant) return 'restaurant';
    if (icon == Icons.local_hospital) return 'local_hospital';
    if (icon == Icons.school) return 'school';
    return 'location_on';
  }

  // ─────────────────────────────────────────────────────────────
  // RIDE REQUEST
  // ─────────────────────────────────────────────────────────────

  Future<void> _requestRide() async {
    if (_pickup == null || _dropoff == null || _selectedVehicle == null) {
      _showErrorSnackBar('Please complete booking details');
      return;
    }
    if (_accessToken == null || _accessToken!.isEmpty) {
      _showErrorSnackBar('Session expired. Please login.');
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    if (!_socketService.isConnected) {
      await _connectSocket();
      if (!_socketService.isConnected) {
        _showErrorSnackBar('Connection error. Try again.');
        return;
      }
    }

    setState(() => _requesting = true);

    try {
      final response = await ApiService.createTrip(
        accessToken: _accessToken!,
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        pickupAddress: _pickupCtrl.text,
        dropoffLat: _dropoff!.latitude,
        dropoffLng: _dropoff!.longitude,
        dropoffAddress: _destCtrl.text,
        paymentMethod: _selectedPaymentMethod,
      );

      if (!mounted) return;

      final tripData = response['data']?['trip'];
      if (tripData == null) throw Exception('Invalid response from server');

      final tripId = tripData['id'];
      Provider.of<TripProvider>(context, listen: false)
          .setCurrentTrip(tripData);

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SearchingDriverScreen(
            tripId: tripId.toString(),
            pickupAddress: _pickupCtrl.text,
            dropoffAddress: _destCtrl.text,
            pickupLocation: _pickup!,
            dropoffLocation: _dropoff!,
          ),
        ),
      );
    } on Exception catch (e) {
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) msg = msg.substring(11);
      _showErrorSnackBar(msg,
          isWarning: msg.toLowerCase().contains('no driver'));
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SNACKBARS
  // ─────────────────────────────────────────────────────────────

  void _showErrorSnackBar(String message, {bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
      isWarning ? Colors.orange.shade700 : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showLocationServiceSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Location services disabled'),
      backgroundColor: AppColors.textPrimary,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Enable',
        textColor: AppColors.primaryGold,
        onPressed: Geolocator.openLocationSettings,
      ),
    ));
  }

  void _showLocationPermissionSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Location permission required'),
      backgroundColor: AppColors.textPrimary,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Settings',
        textColor: AppColors.primaryGold,
        onPressed: Geolocator.openAppSettings,
      ),
    ));
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          // ── Map ──
          GoogleMap(
            initialCameraPosition: const CameraPosition(
                target: _doualaCenter, zoom: 12),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: Set<Marker>.of(_markers.values),
            onMapCreated: (c) {
              _mapCtrl = c;
              if (_pickup != null) _animateTo(_pickup!, zoom: 15);
            },
          ),

          // ── Top search bar (minimized mode only) ──
          if (_currentMode == BottomSheetMode.minimized)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: _buildTopSearchBar(),
            ),

          // ── Bottom sheet ──
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.15,
            minChildSize: 0.15,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.15, 0.5, 0.9],
            builder: (context, scrollController) {
              return NotificationListener<DraggableScrollableNotification>(
                onNotification: (notification) {
                  setState(() {
                    _currentSheetSize = notification.extent;

                    if (_currentSheetSize < 0.3) {
                      _currentMode = BottomSheetMode.minimized;
                    } else if (_currentSheetSize < 0.6 &&
                        _currentMode != BottomSheetMode.vehicleSelection) {
                      _currentMode = BottomSheetMode.location;
                    }
                  });
                  return false; // allow bubbling
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (_currentMode == BottomSheetMode.minimized)
                        _buildMinimizedContent()
                      else if (_currentMode == BottomSheetMode.location)
                        _buildLocationContent()
                      else if (_currentMode == BottomSheetMode.vehicleSelection)
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

  // ─────────────────────────────────────────────────────────────
  // TOP SEARCH BAR — shows real avatar
  // ─────────────────────────────────────────────────────────────

  Widget _buildTopSearchBar() {
    final firstName =
        _userData?['first_name']?.toString() ?? 'U';
    final initial =
    firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';
    final avatarUrl = _userData?['avatar_url']?.toString();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.black87, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Où allons-nous?',
              style: AppTypography.bodyLarge.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // ── Avatar circle ──
          ClipOval(
            child: hasAvatar
                ? CachedNetworkImage(
              imageUrl: avatarUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildInitialAvatar(
                  initial, size: 40),
              errorWidget: (context, url, error) =>
                  _buildInitialAvatar(initial, size: 40),
            )
                : _buildInitialAvatar(initial, size: 40),
          ),
        ],
      ),
    );
  }

  /// Reusable gold circle with initial letter
  Widget _buildInitialAvatar(String initial, {double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MINIMIZED CONTENT
  // ─────────────────────────────────────────────────────────────

  Widget _buildMinimizedContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Planifiez votre trajet',
            style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 20),
          _buildCompactInput(
            controller: _pickupCtrl,
            focusNode: _pickupFocus,
            hint: 'Point de départ',
            icon: Icons.my_location,
          ),
          const SizedBox(height: 12),
          _buildCompactInput(
            controller: _destCtrl,
            focusNode: _destFocus,
            hint: 'Où allez-vous?',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 24),

          // Favorites
          if (_favoritePlaces.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Destinations favorites',
                  style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                TextButton.icon(
                  onPressed: _showManageFavoritesDialog,
                  icon: const Icon(Icons.edit,
                      size: 16, color: Colors.black54),
                  label: Text('Gérer',
                      style: AppTypography.caption
                          .copyWith(color: Colors.black54)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._favoritePlaces.asMap().entries.map(
                    (e) => _buildFavoriteCard(e.value, e.key)),
          ] else ...[
            _buildEmptyFavoritesCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: AppTypography.bodyMedium
                  .copyWith(color: Colors.black87),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.bodyMedium
                    .copyWith(color: Colors.black45),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (q) => _onQueryChanged(q,
                  forPickup: focusNode == _pickupFocus),
            ),
          ),
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
          Icon(Icons.star_border_rounded,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Aucun favori',
              style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(
            'Ajoutez vos destinations fréquentes\npour un accès rapide',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall
                .copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(FavoritePlace place, int index) {
    return Dismissible(
      key: Key('fav_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline,
            color: Colors.white, size: 28),
      ),
      onDismissed: (_) => _removeFavorite(index),
      child: GestureDetector(
        onTap: () {
          setState(() => _destCtrl.text = place.name);
          _destFocus.requestFocus();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9E6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(place.icon,
                    color: Colors.black87, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name,
                        style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (place.address.isNotEmpty)
                      Text(place.address,
                          style: AppTypography.caption
                              .copyWith(color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (place.time.isNotEmpty)
                Text(place.time,
                    style: AppTypography.bodyMedium
                        .copyWith(color: Colors.black54)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LOCATION CONTENT (expanded search)
  // ─────────────────────────────────────────────────────────────

  Widget _buildLocationContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Planifiez votre trajet',
              style: AppTypography.headlineSmall
                  .copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildFullInput(
              controller: _pickupCtrl,
              focusNode: _pickupFocus,
              label: 'Point de départ',
              icon: Icons.my_location),
          const SizedBox(height: 16),
          _buildFullInput(
              controller: _destCtrl,
              focusNode: _destFocus,
              label: 'Destination',
              icon: Icons.location_on),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Suggestions',
                style: AppTypography.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ..._suggestions
                .map((p) => _buildSuggestionTile(p)),
          ],
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildFullInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: AppTypography.bodyLarge
                  .copyWith(color: Colors.black87),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: AppTypography.bodySmall
                    .copyWith(color: Colors.black54),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (q) => _onQueryChanged(q,
                  forPickup: focusNode == _pickupFocus),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(PlacePrediction prediction) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: const Icon(Icons.location_on_outlined,
          color: Colors.black54),
      title: Text(
        prediction.mainText ?? prediction.description,
        style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600, color: Colors.black87),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: (prediction.secondaryText ?? '').isEmpty
          ? null
          : Text(prediction.secondaryText!,
          style: AppTypography.caption
              .copyWith(color: Colors.black54),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      onTap: () =>
          _selectPrediction(prediction, forPickup: _searchingPickup),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // VEHICLE SELECTION CONTENT
  // ─────────────────────────────────────────────────────────────

  Widget _buildVehicleSelectionContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _backToLocation,
                icon: const Icon(Icons.arrow_back,
                    color: Colors.black),
              ),
              Expanded(
                child: Text(
                  'Sélectionner le véhicule',
                  style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Loading prices state
          if (_loadingPrices)
            _buildPriceLoadingState()
          else
            ..._vehicleTypes.map(_buildVehicleCard),

          const SizedBox(height: 24),
          Text('Paiement par :',
              style: AppTypography.bodyLarge
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildPaymentSelector(),
          const SizedBox(height: 32),
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
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _requesting
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white),
                ),
              )
                  : Text(
                'Commander maintenant',
                style: AppTypography.buttonLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPriceLoadingState() {
    return Column(
      children: List.generate(
        3,
            (i) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 100,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 16,
                        width: 80,
                        color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Container(
                        height: 12,
                        width: 120,
                        color: Colors.grey.shade200),
                  ],
                ),
              ),
              Container(
                  height: 20,
                  width: 70,
                  color: Colors.grey.shade200),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(VehicleType vehicle) {
    final isSelected = _selectedVehicle == vehicle;
    final hasPrice = vehicle.fareEstimate != null;

    return GestureDetector(
      onTap: hasPrice
          ? () => setState(() => _selectedVehicle = vehicle)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF9E6)
              : hasPrice
              ? Colors.white
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGold
                : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Vehicle image
            Container(
              width: 100,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  vehicle.assetImage,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Center(
                    child: Icon(Icons.directions_car, size: 40),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Name + info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vehicle.name,
                      style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: hasPrice
                              ? Colors.black
                              : Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(vehicle.eta,
                          style: AppTypography.bodySmall
                              .copyWith(color: Colors.black54)),
                      const SizedBox(width: 16),
                      const Icon(Icons.person_outline,
                          size: 16, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text('${vehicle.passengers}',
                          style: AppTypography.bodySmall
                              .copyWith(color: Colors.black54)),
                    ],
                  ),
                  if (vehicle.distanceText != null &&
                      vehicle.durationText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${vehicle.distanceText} · ${vehicle.durationText}',
                        style: AppTypography.caption
                            .copyWith(color: Colors.black45),
                      ),
                    ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                hasPrice
                    ? Text(
                  '${vehicle.fareEstimate!.toInt()} XAF',
                  style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                )
                    : Text('N/A',
                    style: AppTypography.bodyMedium
                        .copyWith(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSelector() {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPaymentMethod,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Colors.black54),
          style: AppTypography.bodyLarge
              .copyWith(color: Colors.black87),
          isExpanded: true,
          items: [
            DropdownMenuItem(
              value: 'cash',
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.payments_outlined,
                      color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Cash', style: AppTypography.bodyLarge),
              ]),
            ),
            DropdownMenuItem(
              value: 'om',
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset('assets/images/om.png',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                          Icons.phone_android,
                          color: Colors.orange,
                          size: 20)),
                ),
                const SizedBox(width: 12),
                Text('Orange Money',
                    style: AppTypography.bodyLarge),
              ]),
            ),
            DropdownMenuItem(
              value: 'momo',
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset('assets/images/momo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                          Icons.phone_android,
                          color: Colors.yellow,
                          size: 20)),
                ),
                const SizedBox(width: 12),
                Text('MTN Mobile Money',
                    style: AppTypography.bodyLarge),
              ]),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _selectedPaymentMethod = v);
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FAVORITES DIALOG
  // ─────────────────────────────────────────────────────────────

  Widget _buildAddFavoriteDialog(String name, String address) {
    final nameController = TextEditingController(text: name);
    IconData selectedIcon = Icons.location_on;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Ajouter aux favoris',
              style: AppTypography.headlineSmall
                  .copyWith(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nom du lieu',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Choisir une icône',
                  style: AppTypography.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
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
                ].map((icon) {
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedIcon = icon),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectedIcon == icon
                            ? AppColors.primaryGold
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon,
                          color: selectedIcon == icon
                              ? Colors.black
                              : Colors.black54),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler',
                  style: AppTypography.bodyLarge
                      .copyWith(color: Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _favoritePlaces.add(FavoritePlace(
                    name: nameController.text.trim(),
                    address: address,
                    time: '',
                    icon: selectedIcon,
                  ));
                });
                await _saveFavoritePlaces();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Ajouté aux favoris'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Ajouter',
                  style: AppTypography.bodyLarge
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showManageFavoritesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Gérer les favoris',
            style: AppTypography.headlineSmall
                .copyWith(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: _favoritePlaces.isEmpty
              ? Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Aucun favori à gérer',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium
                    .copyWith(color: Colors.black54)),
          )
              : ListView.builder(
            shrinkWrap: true,
            itemCount: _favoritePlaces.length,
            itemBuilder: (context, index) {
              final place = _favoritePlaces[index];
              return ListTile(
                leading: Icon(place.icon,
                    color: AppColors.primaryGold),
                title: Text(place.name,
                    style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600)),
                subtitle: place.address.isNotEmpty
                    ? Text(place.address,
                    style: AppTypography.caption)
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  onPressed: () {
                    _removeFavorite(index);
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
            child: Text('Fermer',
                style: AppTypography.bodyLarge.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
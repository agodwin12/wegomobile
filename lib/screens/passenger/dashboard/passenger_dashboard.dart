// lib/presentation/screens/passenger/passenger_dashboard.dart
//
// CHANGES IN THIS VERSION:
//   ✅ Reads user_type + active_mode from SharedPreferences on init
//   ✅ Conditionally renders a frosted "⇄ Switch" pill in the map top bar
//      — only visible when user_type is DRIVER or DELIVERY_AGENT
//      — native PASSENGER accounts never see it
//      — taps showModeSwitchSheet() which auto-resolves correct targets
//   ✅ Service cards: images only (no icon overlay)
//   ✅ Service cards evenly spaced across full width (no horizontal scroll)

import 'dart:convert';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/profile_provider.dart';
import '../../../service/api_services.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';
import '../../../utils/map_style.dart';
import '../../../widgets/map_style_button.dart';
import '../../../widgets/mode_switch_sheet.dart';
import '../../notification/notification_badge.dart';
import '../../notification/notification_screen.dart';
import '../../profile/profile_screen.dart';
import '../../services/services_home_screen.dart';
import '../activity/activity_screen.dart';
import '../bottom_nav_bar/bottom_bar.dart';
import '../delivery/delivery_home_screen.dart';
import '../reservation/rental_screen.dart';
import '../ride/ride map/ride_map.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kMapHeight = 290.0;
const _kGold      = AppColors.primaryGold;
const _kDark      = Color(0xFF1A1A1A);

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class PassengerDashboard extends StatefulWidget {
  const PassengerDashboard({super.key});

  @override
  State<PassengerDashboard> createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard>
    with TickerProviderStateMixin {

  // ── Navigation ──────────────────────────────────────────────────
  int _selectedIndex = 0;

  // ── Promo pager ─────────────────────────────────────────────────
  late PageController _pageController;
  int _currentAdPage = 0;

  // ── Auth / user ─────────────────────────────────────────────────
  String? _accessToken;
  Map<String, dynamic>? _userData;

  // ── Mode switch ──────────────────────────────────────────────────
  bool _canSwitchMode = false;

  // ── Data ────────────────────────────────────────────────────────
  List<dynamic>?              _recentTrips;
  List<dynamic>?              _advertisements;
  List<Map<String, dynamic>>? _favoritePlaces;
  bool _isLoading  = true;
  int  _totalRides = 0;

  // ── Location / map ──────────────────────────────────────────────
  LatLng?         _currentLatLng;
  String          _locationLabel   = 'Locating…';
  bool            _locationLoading = true;
  final MapController _mapController = MapController();

  // ── Animations ──────────────────────────────────────────────────
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;
  late Animation<double>   _pulse;

  // ── Map style ───────────────────────────────────────────────────
  MapStyle _mapStyle = MapStyle.dark;
  String get _mapboxToken => dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  // ── Service press states ─────────────────────────────────────────
  final Map<String, bool> _servicePressed = {};

  // ─────────────────────────────────────────────────────────────────
  // INIT / DISPOSE
  // ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _setupAnimations();
    _initializeDashboard();
    _fetchLocation();
    loadMapStylePref().then((s) { if (mounted) setState(() => _mapStyle = s); });
  }

  void _setupAnimations() {
    _entryCtrl = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 1400), vsync: this)
      ..repeat(reverse: true);

    _entryFade = CurvedAnimation(
        parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _entryCtrl, curve: Curves.easeOutCubic));
    _pulse = Tween<double>(begin: 1.0, end: 1.6).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // LOCATION
  // ─────────────────────────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() {
          _locationLabel   = 'Location denied';
          _locationLoading = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final latlng = LatLng(pos.latitude, pos.longitude);

      String label =
          '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      try {
        // LocationIQ reverse (OSM) — accurate Cameroon place names.
        final key = dotenv.env['LOCATIONIQ_KEY'] ?? '';
        final url = Uri.parse(
          'https://us1.locationiq.com/v1/reverse'
          '?key=$key&lat=${pos.latitude}&lon=${pos.longitude}'
          '&format=json&normalizeaddress=1',
        );
        final response =
            await http.get(url).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final addr = data['address'] as Map<String, dynamic>? ?? {};
          final main = (addr['name'] ?? addr['road'] ?? addr['neighbourhood'] ??
                        addr['suburb'] ?? addr['quarter'] ?? '').toString();
          final area = (addr['suburb'] ?? addr['city_district'] ?? addr['city'] ?? '').toString();
          final name = [main, area].where((s) => s.isNotEmpty).toSet().take(2).join(', ');
          if (name.isNotEmpty) {
            label = name;
          } else {
            final dn = data['display_name']?.toString() ?? '';
            final parts = dn.split(',').take(2).map((s) => s.trim()).where((s) => s.isNotEmpty).join(', ');
            if (parts.isNotEmpty) label = parts;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _currentLatLng   = latlng;
          _locationLabel   = label;
          _locationLoading = false;
        });
        try { _mapController.move(latlng, 15.0); } catch (_) {}
      }
    } catch (e) {
      if (mounted) setState(() {
        _locationLabel   = 'Could not get location';
        _locationLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // DASHBOARD INIT
  // ─────────────────────────────────────────────────────────────────

  Future<void> _initializeDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');

      final userDataString = prefs.getString('user_data');
      if (userDataString != null) _userData = json.decode(userDataString);

      if (_accessToken == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final userType = prefs.getString('user_type') ?? '';
      if (mounted) {
        setState(() {
          _canSwitchMode =
              userType == 'DRIVER' || userType == 'DELIVERY_AGENT';
        });
      }

      await _loadProfileData();
      await Future.wait([_loadDashboardData(), _loadFavoritePlaces()]);

      _entryCtrl.forward();
    } catch (e) {
      debugPrint('❌ [DASHBOARD] Init error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final pp = Provider.of<ProfileProvider>(context, listen: false);
      await pp.loadProfile();
      if (mounted)
        setState(() => _totalRides = pp.profile?.stats?.totalRides ?? 0);
    } catch (e) {
      debugPrint('⚠️ [DASHBOARD] Profile: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    _advertisements = [
      {
        'id':          '1',
        'title':       'Summer Special',
        'description': 'Get 20% off on all rides this week',
        'gradient':    [const Color(0xFFFFB800), const Color(0xFFFF6B00)],
        'badge':       'LIMITED',
      },
      {
        'id':          '2',
        'title':       'New Routes',
        'description': 'Now available in 10 new cities',
        'gradient':    [const Color(0xFF059669), const Color(0xFF047857)],
        'badge':       'NEW',
      },
      {
        'id':          '3',
        'title':       'Safety First',
        'description': 'Verified drivers, secure rides',
        'gradient':    [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
        'badge':       'FEATURE',
      },
    ];

    try {
      if (_accessToken != null) {
        final res = await ApiService.getRecentTrips(_accessToken!);
        _recentTrips = res['data']?['trips'];
      }
    } catch (_) {
      _recentTrips = [];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadFavoritePlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json_ = prefs.getString('favorite_places');
      if (json_ != null) {
        final list = json.decode(json_) as List;
        if (mounted) {
          setState(() {
            _favoritePlaces = list.map((item) => {
              'name':    item['name']    ?? '',
              'address': item['address'] ?? '',
              'icon':    _getIconFromString(item['icon'] ?? 'location_on'),
            }).toList();
          });
        }
      } else {
        if (mounted) setState(() => _favoritePlaces = []);
      }
    } catch (_) {
      if (mounted) setState(() => _favoritePlaces = []);
    }
  }

  IconData _getIconFromString(String name) {
    switch (name) {
      case 'home':       return Icons.home_rounded;
      case 'work':       return Icons.work_rounded;
      case 'restaurant': return Icons.restaurant_rounded;
      case 'school':     return Icons.school_rounded;
      default:           return Icons.location_on_rounded;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────

  String _extractFirstName() =>
      _userData?['first_name']?.toString() ??
          _userData?['firstName']?.toString() ??
          'Guest';

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String? get _avatarUrl => _userData?['avatar_url']?.toString();

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text('$feature coming soon'),
      backgroundColor: _kDark,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      action: SnackBarAction(
          label: 'OK', textColor: _kGold, onPressed: () {}),
    ));
  }

  // ─────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────

  void _handleNavbarTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(context, _route(const ActivityScreen()));
        break;
      case 2:
        Navigator.push(context, _route(const ProfileScreen())).then((_) {
          _refreshUserData();
          setState(() => _selectedIndex = 0);
        });
        break;
    }
  }

  PageRoute _route(Widget page) =>
      MaterialPageRoute(builder: (_) => page);

  Future<void> _refreshUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final s     = prefs.getString('user_data');
    if (s != null && mounted) setState(() => _userData = json.decode(s));
    await _loadProfileData();
  }

  void _navigateToRide() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
          const RideMapScreen(prefilledDestination: {})),
    ).then((_) => _loadFavoritePlaces());
  }

  void _handleServiceTap(String action) {
    switch (action) {
      case 'Ride Now':
        _navigateToRide();
        break;
      case 'Rental':
        Navigator.push(
            context,
            _route(RentalScreen(
                user:        _userData ?? {},
                accessToken: _accessToken ?? '')));
        break;
      case 'Services':
        Navigator.push(
            context,
            _route(ServicesHomeScreen(
                user:        _userData,
                accessToken: _accessToken)));
        break;
      case 'Delivery':
        Navigator.push(
            context, _route(const DeliveryHomeScreen()));
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F2),
        extendBodyBehindAppBar: true,
        body: _isLoading ? _buildLoader() : _buildBody(),
        bottomNavigationBar: PassengerBottomNavbar(
          selectedIndex: _selectedIndex,
          onItemTapped:  _handleNavbarTap,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color:        _kGold,
      displacement: _kMapHeight - 40,
      onRefresh: () async {
        await _refreshUserData();
        await Future.wait(
            [_loadDashboardData(), _loadFavoritePlaces()]);
        await _fetchLocation();
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _buildMapHero()),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _entryFade,
              child: SlideTransition(
                position: _entrySlide,
                child: _buildScrollContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // LOADER
  // ─────────────────────────────────────────────────────────────────

  Widget _buildLoader() {
    return Container(
      color: _kDark,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  70,
              height: 70,
              decoration: BoxDecoration(
                color:  Colors.white.withOpacity(0.06),
                shape:  BoxShape.circle,
                border: Border.all(
                    color: _kGold.withOpacity(0.4), width: 1.5),
              ),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child:   CircularProgressIndicator(
                    color: _kGold, strokeWidth: 2.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading your dashboard…',
              style: TextStyle(
                fontSize:   14,
                color:      Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // MAP HERO
  // ─────────────────────────────────────────────────────────────────

  Widget _buildMapHero() {
    final defaultCenter =
        _currentLatLng ?? const LatLng(4.0511, 9.7679);

    return SizedBox(
      height: _kMapHeight,
      child: Stack(
        children: [
          // Map
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: defaultCenter,
                initialZoom:
                _currentLatLng != null ? 15.0 : 13.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapStyle.tileUrl(_mapboxToken),
                  userAgentPackageName: 'com.yourapp.passenger',
                ),
                if (_currentLatLng != null)
                  MarkerLayer(markers: [
                    Marker(
                      point:  _currentLatLng!,
                      width:  60,
                      height: 60,
                      child:  _buildMapPin(),
                    ),
                  ]),
              ],
            ),
          ),

          MapStyleButton(
            current: _mapStyle,
            onChanged: (s) { setState(() => _mapStyle = s); saveMapStylePref(s); },
            bottom: 14,
          ),

          // Top gradient
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Bottom gradient into white
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.bottomCenter,
                  end:    Alignment.topCenter,
                  colors: [Color(0xFFF2F2F2), Colors.transparent],
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child:  _buildMapTopBar(),
            ),
          ),

          // Location pill
          Positioned(
            bottom: 20, left: 16, right: 16,
            child:  _buildLocationPill(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPin() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width:  30 * _pulse.value,
            height: 30 * _pulse.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kGold.withOpacity(0.18 / _pulse.value),
            ),
          ),
          Container(
            width:  22,
            height: 22,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  _kGold.withOpacity(0.25),
              border: Border.all(color: _kGold, width: 1.5),
            ),
          ),
          Container(
            width:  10,
            height: 10,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: _kGold),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // MAP TOP BAR
  // ─────────────────────────────────────────────────────────────────

  Widget _buildMapTopBar() {
    final firstName = _extractFirstName();
    final greeting  = _getGreeting();
    final initial   = firstName.isNotEmpty
        ? firstName[0].toUpperCase()
        : 'G';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [

          // Frosted greeting chip
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:        Colors.black.withOpacity(0.38),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize:   10,
                        color:      Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      '$firstName 👋',
                      style: const TextStyle(
                        fontSize:   15,
                        color:      Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // ── Mode switch pill (only for DRIVER / DELIVERY_AGENT) ──
          if (_canSwitchMode) ...[
            GestureDetector(
              onTap: () => showModeSwitchSheet(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color:        Colors.black.withOpacity(0.38),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kGold.withOpacity(0.45), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.swap_horiz_rounded,
                            color: _kGold, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Switch',
                          style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w700,
                            color:      _kGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Notification button
          NotificationBadge(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationScreen(),
                ),
              ).then((_) => NotificationBadge.refresh());
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width:  42,
                  height: 42,
                  decoration: BoxDecoration(
                    color:        Colors.black.withOpacity(0.38),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: Colors.white.withOpacity(0.9),
                    size:  20,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Avatar
          _buildAvatar(initial),
        ],
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    final url = _avatarUrl;
    Widget fallback = Container(
      width:  42,
      height: 42,
      decoration: BoxDecoration(
        color:        _kGold,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
            color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.3),
              blurRadius: 8)
        ],
      ),
      child: Center(
        child: Text(initial,
            style: const TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.w800,
              color:      _kDark,
            )),
      ),
    );

    if (url == null || url.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: CachedNetworkImage(
        imageUrl:    url,
        width:       42,
        height:      42,
        fit:         BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _buildLocationPill() {
    return GestureDetector(
      onTap: _fetchLocation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:        Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width:  28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _kGold.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location_rounded,
                      color: _kGold, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _locationLoading
                      ? Row(children: [
                    SizedBox(
                      width:  10,
                      height: 10,
                      child:  CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Getting location…',
                        style: TextStyle(
                          fontSize: 12,
                          color:    Colors.white.withOpacity(0.55),
                        )),
                  ])
                      : Text(
                    _locationLabel,
                    style: const TextStyle(
                      fontSize:   12,
                      color:      Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.refresh_rounded,
                    color: Colors.white.withOpacity(0.4), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // SCROLLABLE CONTENT
  // ─────────────────────────────────────────────────────────────────

  Widget _buildScrollContent() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFF2F2F2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _buildSearchBar(),
          _buildQuickActions(),
          _buildStatsStrip(),
          if (_favoritePlaces != null && _favoritePlaces!.isNotEmpty)
            _buildSavedPlaces(),
          if (_advertisements != null && _advertisements!.isNotEmpty)
            _buildPromoBanner(),
          if (_recentTrips != null && _recentTrips!.isNotEmpty)
            _buildRecentTrips(),
          _buildSafetyBanner(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // SEARCH BAR
  // ─────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: _navigateToRide,
      child: Container(
        margin:  const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:        _kDark,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.search_rounded,
                  color: _kGold, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Where to?',
                      style: TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.w800,
                        color:      _kDark,
                        letterSpacing: -0.3,
                      )),
                  const SizedBox(height: 2),
                  Text('Enter your destination',
                      style: TextStyle(
                          fontSize: 12,
                          color:    Colors.grey.shade500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        _kGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Go →',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w800,
                    color:      _kDark,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // QUICK ACTIONS  ← FIXED: images only, no icon overlay, even layout
  // ─────────────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final actions = [
      {
        'label':   'Ride',
        'image':   'assets/images/ride.png',
        'action':  'Ride Now',
        'primary': true,
      },
      {
        'label':   'Rental',
        'image':   'assets/images/rental_service.png',
        'action':  'Rental',
        'primary': false,
      },
      {
        'label':   'Delivery',
        'image':   'assets/images/delivery.png',
        'action':  'Delivery',
        'primary': false,
      },
      {
        'label':   'Services',
        'image':   'assets/images/services.jpg',
        'action':  'Services',
        'primary': false,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'Services',
              style: TextStyle(
                fontSize:      18,
                fontWeight:    FontWeight.w800,
                color:         _kDark,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // ── Even row: each card takes equal width ──
          Row(
            children: List.generate(actions.length, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left:  i == 0 ? 0 : 6,
                    right: i == actions.length - 1 ? 0 : 6,
                  ),
                  child: _buildQuickActionItem(actions[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(Map<String, dynamic> item) {
    final isPrimary = item['primary'] as bool;
    final key       = item['action'] as String;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _servicePressed[key] = true);
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        setState(() => _servicePressed[key] = false);
        _handleServiceTap(key);
      },
      onTapCancel: () => setState(() => _servicePressed[key] = false),
      child: AnimatedScale(
        scale:    (_servicePressed[key] ?? false) ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve:    Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Square card with image only ──
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isPrimary
                      ? [BoxShadow(
                    color:      _kDark.withOpacity(0.22),
                    blurRadius: 14,
                    offset:     const Offset(0, 5),
                  )]
                      : [BoxShadow(
                    color:      Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset:     const Offset(0, 2),
                  )],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    item['image'] as String,
                    fit: BoxFit.cover,
                    // slight dark tint on primary card for contrast
                    color: isPrimary
                        ? Colors.black.withOpacity(0.15)
                        : null,
                    colorBlendMode: BlendMode.darken,
                    errorBuilder: (_, __, ___) => Container(
                      color: isPrimary
                          ? _kDark
                          : const Color(0xFFF0F0F0),
                      child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white38,
                          size: 24),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              item['label'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:      11,
                fontWeight:    isPrimary
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: isPrimary
                    ? _kDark
                    : Colors.grey.shade700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // STATS STRIP
  // ─────────────────────────────────────────────────────────────────

  Widget _buildStatsStrip() {
    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color:        _kDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      _kDark.withOpacity(0.22),
            blurRadius: 18,
            offset:     const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            '$_totalRides',
            _totalRides == 1 ? 'Total ride' : 'Total rides',
            Icons.directions_car_rounded,
          ),
          _buildStatDivider(),
          _buildStatItem('4.9★', 'Your rating', Icons.star_rounded),
          _buildStatDivider(),
          _buildStatItem(
              'Active', 'Status', Icons.check_circle_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: _kGold, size: 16),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w800,
                color:      Colors.white,
                letterSpacing: -0.4,
              )),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                fontSize:   10,
                color:      Colors.white.withOpacity(0.45),
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

  Widget _buildStatDivider() => Container(
      width: 1, height: 36, color: Colors.white.withOpacity(0.08));

  // ─────────────────────────────────────────────────────────────────
  // SAVED PLACES
  // ─────────────────────────────────────────────────────────────────

  Widget _buildSavedPlaces() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
          child: Text('Saved places',
              style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w700,
                color:      Colors.grey.shade600,
                letterSpacing: 0.2,
              )),
        ),
        SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:  const EdgeInsets.symmetric(horizontal: 16),
            physics:  const BouncingScrollPhysics(),
            itemCount: _favoritePlaces!.length,
            itemBuilder: (_, i) {
              final p = _favoritePlaces![i];
              return GestureDetector(
                onTap: _navigateToRide,
                child: Container(
                  margin:  const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 0),
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(
                      color:      Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                    )],
                  ),
                  child: Row(children: [
                    Icon(p['icon'] as IconData,
                        size: 15, color: _kDark),
                    const SizedBox(width: 7),
                    Text(p['name'] as String,
                        style: const TextStyle(
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                          color:      _kDark,
                        )),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // PROMO BANNER
  // ─────────────────────────────────────────────────────────────────

  Widget _buildPromoBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Offers',
                  style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.w800,
                    color:      _kDark,
                    letterSpacing: -0.3,
                  )),
              GestureDetector(
                onTap: () => _showComingSoon('All offers'),
                child: const Text('See all',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      _kGold,
                    )),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 130,
          child: Stack(children: [
            PageView.builder(
              controller:    _pageController,
              onPageChanged: (i) =>
                  setState(() => _currentAdPage = i),
              itemCount:  _advertisements!.length,
              itemBuilder: (_, i) =>
                  _buildAdCard(_advertisements![i]),
            ),
            Positioned(
              bottom: 10, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _advertisements!.length,
                      (i) {
                    final active = _currentAdPage == i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width:  active ? 18 : 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: active
                            ? _kGold
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  },
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final colors = ad['gradient'] as List<Color>;
    final badge  = ad['badge']   as String;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [BoxShadow(
          color:      colors[0].withOpacity(0.3),
          blurRadius: 14,
          offset:     const Offset(0, 5),
        )],
      ),
      child: Stack(children: [
        Positioned(
          top: -20, right: -10,
          child: Container(
            width:  110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          top: 15, right: 30,
          child: Container(
            width:  60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:  MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge,
                        style: const TextStyle(
                          fontSize:   9,
                          fontWeight: FontWeight.w700,
                          color:      Colors.white,
                          letterSpacing: 1.2,
                        )),
                  ),
                  const SizedBox(height: 8),
                  Text(ad['title'] as String,
                      style: const TextStyle(
                        fontSize:   18,
                        fontWeight: FontWeight.w800,
                        color:      Colors.white,
                        letterSpacing: -0.3,
                      )),
                  const SizedBox(height: 3),
                  Text(ad['description'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color:    Colors.white.withOpacity(0.8),
                      )),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Claim',
                  style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w800,
                    color:      colors[0],
                  )),
            ),
          ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // RECENT TRIPS
  // ─────────────────────────────────────────────────────────────────

  Widget _buildRecentTrips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent trips',
                  style: TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.w800,
                    color:      _kDark,
                    letterSpacing: -0.3,
                  )),
              GestureDetector(
                onTap: () => _showComingSoon('All trips'),
                child: const Text('See all',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      _kGold,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentTrips!.take(3).map(_buildTripCard),
        ],
      ),
    );
  }

  Widget _buildTripCard(dynamic trip) {
    final t = trip is Map<String, dynamic>
        ? trip
        : <String, dynamic>{};
    return Container(
      margin:  const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [BoxShadow(
          color:      Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset:     const Offset(0, 2),
        )],
      ),
      child: Row(children: [
        Container(
          width:  42,
          height: 42,
          decoration: BoxDecoration(
            color:        _kDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.directions_car_rounded,
              color: _kGold, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t['dropoff_address'] ?? 'Trip',
                style: const TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                  color:      _kDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(t['date_formatted'] ?? '',
                  style: TextStyle(
                      fontSize: 11,
                      color:    Colors.grey.shade500)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${t['fare'] ?? '0'} XAF',
                style: const TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w800,
                  color:      _kDark,
                )),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color:        const Color(0xFFEFFAF0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Completed',
                  style: TextStyle(
                    fontSize:   9,
                    fontWeight: FontWeight.w700,
                    color:      Color(0xFF22C55E),
                  )),
            ),
          ],
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // SAFETY BANNER
  // ─────────────────────────────────────────────────────────────────

  Widget _buildSafetyBanner() {
    return GestureDetector(
      onTap: () => _showComingSoon('Safety center'),
      child: Container(
        margin:  const EdgeInsets.fromLTRB(16, 24, 16, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [BoxShadow(
            color:      Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset:     const Offset(0, 3),
          )],
        ),
        child: Row(children: [
          Container(
            width:  4,
            height: 50,
            decoration: BoxDecoration(
              color:        _kGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width:  44,
            height: 44,
            decoration: BoxDecoration(
              color:        const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFEF3C7)),
            ),
            child: const Icon(Icons.shield_rounded,
                color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Safety Matters',
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      _kDark,
                    )),
                const SizedBox(height: 3),
                Text('24/7 support · Real-time tracking',
                    style: TextStyle(
                        fontSize: 12,
                        color:    Colors.grey.shade500)),
              ],
            ),
          ),
          Container(
            width:  30,
            height: 30,
            decoration: BoxDecoration(
              color:        const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.grey.shade400, size: 13),
          ),
        ]),
      ),
    );
  }
}
// lib/presentation/screens/passenger/passenger_dashboard.dart

import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/profile_provider.dart';
import '../../../service/api_services.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';
import '../../profile/profile_screen.dart';
import '../../services/services_home_screen.dart';
import '../activity/activity_screen.dart';
import '../bottom_nav_bar/bottom_bar.dart';
import '../reservation/rental_screen.dart';
import '../ride/ride map/ride_map.dart';

class PassengerDashboard extends StatefulWidget {
  const PassengerDashboard({super.key});

  @override
  _PassengerDashboardState createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  int _currentAdPage = 0;

  // Auth
  String? _accessToken;
  Map<String, dynamic>? _userData;

  // Data
  List<dynamic>? _recentTrips;
  List<dynamic>? _advertisements;
  List<Map<String, dynamic>>? _favoritePlaces;
  bool _isLoading = true;
  int _totalRides = 0;

  // Animations
  late AnimationController _headerController;
  late AnimationController _contentController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _setupAnimations();
    _initializeDashboard();
  }

  void _setupAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerFade = CurvedAnimation(
        parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _headerController, curve: Curves.easeOutCubic));

    _contentFade = CurvedAnimation(
        parent: _contentController, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _contentController, curve: Curves.easeOutCubic));
  }

  // ══════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════════════════════════════════════════

  Future<void> _initializeDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');

      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        _userData = json.decode(userDataString);
      }

      if (_accessToken == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Load profile via ProfileProvider to get real ride count
      await _loadProfileData();

      await Future.wait([
        _loadDashboardData(),
        _loadFavoritePlaces(),
      ]);

      // Animate in
      _headerController.forward();
      await Future.delayed(const Duration(milliseconds: 150));
      _contentController.forward();
    } catch (e) {
      debugPrint('❌ [DASHBOARD] Init error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final profileProvider =
      Provider.of<ProfileProvider>(context, listen: false);
      await profileProvider.loadProfile();

      if (mounted) {
        setState(() {
          _totalRides =
              profileProvider.profile?.stats?.totalRides ?? 0;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [DASHBOARD] Profile load error: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    _advertisements = [
      {
        'id': '1',
        'title': 'Summer Special',
        'description': 'Get 20% off on all rides this week',
        'gradient': [const Color(0xFFFFB800), const Color(0xFFFF8C00)],
      },
      {
        'id': '2',
        'title': 'New Routes',
        'description': 'Now available in 10 new cities',
        'gradient': [const Color(0xFF059669), const Color(0xFF047857)],
      },
      {
        'id': '3',
        'title': 'Safety First',
        'description': 'Verified drivers, secure rides',
        'gradient': [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
      },
    ];

    try {
      if (_accessToken != null) {
        final tripsResponse =
        await ApiService.getRecentTrips(_accessToken!);
        _recentTrips = tripsResponse['data']?['trips'];
      }
    } catch (e) {
      _recentTrips = [];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadFavoritePlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getString('favorite_places');
      if (favoritesJson != null) {
        final List<dynamic> list = json.decode(favoritesJson);
        if (mounted) {
          setState(() {
            _favoritePlaces = list.map((item) => {
              'name': item['name'] ?? '',
              'address': item['address'] ?? '',
              'icon': _getIconFromString(item['icon'] ?? 'location_on'),
            }).toList();
          });
        }
      } else {
        setState(() => _favoritePlaces = []);
      }
    } catch (e) {
      setState(() => _favoritePlaces = []);
    }
  }

  IconData _getIconFromString(String name) {
    switch (name) {
      case 'home': return Icons.home_rounded;
      case 'work': return Icons.work_rounded;
      case 'restaurant': return Icons.restaurant_rounded;
      case 'school': return Icons.school_rounded;
      default: return Icons.location_on_rounded;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════

  String _extractFirstName() {
    if (_userData == null) return 'Guest';
    return _userData!['first_name']?.toString() ??
        _userData!['firstName']?.toString() ??
        'Guest';
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String? get _avatarUrl => _userData?['avatar_url']?.toString();

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature coming soon'),
      backgroundColor: Colors.black,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: SnackBarAction(
          label: 'OK',
          textColor: AppColors.primaryGold,
          onPressed: () {}),
    ));
  }

  // ══════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ══════════════════════════════════════════════════════════════════

  void _handleNavbarTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0: break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ActivityScreen()),
        );
        break;
      case 2: _showComingSoon('Offers'); break;
      case 3:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()))
            .then((_) {
          _refreshUserData();
          setState(() => _selectedIndex = 0);
        });
        break;
    }
  }

  Future<void> _refreshUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('user_data');
    if (s != null && mounted) setState(() => _userData = json.decode(s));
    await _loadProfileData();
  }

  void _navigateToRide() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const RideMapScreen(prefilledDestination: {})),
    ).then((_) => _loadFavoritePlaces());
  }

  void _handleServiceTap(String action) {
    switch (action) {
      case 'Ride Now': _navigateToRide(); break;
      case 'Rental':
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => RentalScreen(
                user: _userData ?? {}, accessToken: _accessToken ?? '')));
        break;
      case 'Services':
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => ServicesHomeScreen(
                user: _userData, accessToken: _accessToken)));
        break;
      default: _showComingSoon(action);
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _isLoading
          ? _buildLoader()
          : SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGold,
          onRefresh: () async {
            await _refreshUserData();
            await Future.wait(
                [_loadDashboardData(), _loadFavoritePlaces()]);
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HEADER ──────────────────────────────────────
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: _buildHeader(),
                  ),
                ),
              ),

              // ── CONTENT ─────────────────────────────────────
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(),
                        if (_favoritePlaces != null &&
                            _favoritePlaces!.isNotEmpty)
                          _buildQuickDestinations(),
                        _buildServicesSection(),
                        if (_advertisements != null &&
                            _advertisements!.isNotEmpty)
                          _buildPromoSection(),
                        if (_recentTrips != null &&
                            _recentTrips!.isNotEmpty)
                          _buildRecentTrips(),
                        _buildSafetyBanner(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: PassengerBottomNavbar(
        selectedIndex: _selectedIndex,
        onItemTapped: _handleNavbarTap,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // LOADER
  // ══════════════════════════════════════════════════════════════════

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withOpacity(0.25),
                  blurRadius: 24,
                  spreadRadius: 4,
                )
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(
                color: AppColors.primaryGold,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Loading...',
              style: AppTypography.titleMedium
                  .copyWith(color: Colors.black54)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // HEADER — black card with avatar, greeting, ride pill
  // ══════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    final firstName = _extractFirstName();
    final greeting = _getGreeting();
    final avatarUrl = _avatarUrl;
    final initial =
    firstName.isNotEmpty ? firstName[0].toUpperCase() : 'G';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Avatar ───────────────────────────────────────────────
          _buildAvatar(avatarUrl, initial),
          const SizedBox(width: 14),

          // ── Greeting + Ride Pill ─────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Ride count pill ──────────────────────────────
                _buildRidePill(),
              ],
            ),
          ),

          // ── Notification bell ────────────────────────────────────
          GestureDetector(
            onTap: () => _showComingSoon('Notifications'),
            child: Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: Colors.white.withOpacity(0.85),
                    size: 20,
                  ),
                ),
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String initial) {
    Widget fallback = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primaryGold,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
    );

    if (avatarUrl == null || avatarUrl.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _buildRidePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryGold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primaryGold.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_car_rounded,
              color: AppColors.primaryGold, size: 13),
          const SizedBox(width: 5),
          Text(
            '$_totalRides ${_totalRides == 1 ? 'ride' : 'rides'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SEARCH BAR
  // ══════════════════════════════════════════════════════════════════

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: _navigateToRide,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.search_rounded,
                  color: AppColors.primaryGold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Where to?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Enter your destination',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Go',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // QUICK DESTINATIONS — horizontal chip scroll
  // ══════════════════════════════════════════════════════════════════

  Widget _buildQuickDestinations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            'Saved places',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _favoritePlaces!.length,
            itemBuilder: (_, i) {
              final place = _favoritePlaces![i];
              return GestureDetector(
                onTap: _navigateToRide,
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.shade200, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        place['icon'] as IconData,
                        size: 16,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        place['name'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SERVICES GRID — 2x2
  // ══════════════════════════════════════════════════════════════════

  Widget _buildServicesSection() {
    final services = [
      {
        'name': 'Ride',
        'desc': 'Book instantly',
        'image': 'assets/images/ride.png',
        'icon': Icons.directions_car_rounded,
        'action': 'Ride Now',
        'isPrimary': true,
      },
      {
        'name': 'Rental',
        'desc': 'Rent a car',
        'image': 'assets/images/rental_service.png',
        'icon': Icons.car_rental_rounded,
        'action': 'Rental',
        'isPrimary': false,
      },
      {
        'name': 'Services',
        'desc': 'Book experts',
        'image': 'assets/images/services.jpg',
        'icon': Icons.handyman_rounded,
        'action': 'Services',
        'isPrimary': false,
      },
      {
        'name': 'Delivery',
        'desc': 'Send packages',
        'image': 'assets/images/delivery.png',
        'icon': Icons.local_shipping_rounded,
        'action': 'Delivery',
        'isPrimary': false,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: services.length,
            itemBuilder: (_, i) => _buildServiceCard(services[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final isPrimary = service['isPrimary'] as bool;
    return GestureDetector(
      onTap: () => _handleServiceTap(service['action'] as String),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? AppColors.primaryGold.withOpacity(0.25)
                  : Colors.black.withOpacity(0.08),
              blurRadius: isPrimary ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: Image.asset(
                  service['image'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: isPrimary
                        ? Colors.black
                        : const Color(0xFF1A1A1A),
                  ),
                ),
              ),

              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isPrimary
                          ? [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.75),
                      ]
                          : [
                        Colors.black.withOpacity(0.15),
                        Colors.black.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // Gold accent line for primary
              if (isPrimary)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    color: AppColors.primaryGold,
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? AppColors.primaryGold
                            : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        service['icon'] as IconData,
                        color: isPrimary ? Colors.black : Colors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      service['name'] as String,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      service['desc'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isPrimary
                            ? AppColors.primaryGold
                            : Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // PROMO SECTION
  // ══════════════════════════════════════════════════════════════════

  Widget _buildPromoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 28, 16, 14),
          child: Text(
            'Offers',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(
          height: 150,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (i) =>
                    setState(() => _currentAdPage = i),
                itemCount: _advertisements!.length,
                itemBuilder: (_, i) =>
                    _buildAdCard(_advertisements![i]),
              ),
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _advertisements!.length,
                        (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentAdPage == i ? 20 : 6,
                      height: 6,
                      margin:
                      const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _currentAdPage == i
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final colors = ad['gradient'] as List<Color>;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'SPECIAL OFFER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ad['title'] as String,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ad['description'] as String,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // RECENT TRIPS
  // ══════════════════════════════════════════════════════════════════

  Widget _buildRecentTrips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent trips',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () => _showComingSoon('All trips'),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._recentTrips!.take(3).map(_buildTripCard),
        ],
      ),
    );
  }

  Widget _buildTripCard(dynamic trip) {
    final t = trip is Map<String, dynamic> ? trip : <String, dynamic>{};
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FFF4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF22C55E), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t['dropoff_address'] ?? 'Trip',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  t['date_formatted'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${t['fare'] ?? '0'} XAF',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGold,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SAFETY BANNER
  // ══════════════════════════════════════════════════════════════════

  Widget _buildSafetyBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: AppColors.primaryGold.withOpacity(0.3)),
            ),
            child: const Icon(Icons.shield_rounded,
                color: AppColors.primaryGold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Safety Matters',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '24/7 support · Real-time tracking',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.35), size: 14),
        ],
      ),
    );
  }
}
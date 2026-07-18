// lib/presentation/screens/passenger/activity/activity_screen.dart
// WEGO - Activity Screen — redesigned, backend-aligned
// Clean modern design: black/gold brand palette, sharp typography

import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/app_typography.dart';
import '../../../core/config.dart';

// ═══════════════════════════════════════════════════════════════════════
// MODELS — field names aligned to actual backend JSON (camelCase Trip,
//          snake_case DriverProfile / ServiceRequest / Vehicle)
// ═══════════════════════════════════════════════════════════════════════

class ActivityTrip {
  final String id;
  final String pickupAddress;
  final String dropoffAddress;
  final String status;           // uppercase: COMPLETED, CANCELED, etc.
  final int fareEstimate;        // XAF integer
  final int? fareFinal;
  final String paymentMethod;    // CASH | MOMO | OM
  final int? distanceM;          // metres
  final int? durationS;          // seconds
  final DateTime createdAt;
  final DateTime? tripCompletedAt;
  final DateTime? canceledAt;
  final String? cancelReason;
  final String? canceledBy;

  // driver association
  final String? driverName;
  final String? driverAvatar;
  final double? driverRating;
  final String? vehicleMakeModel;
  final String? vehicleColor;
  final String? vehiclePlate;
  final String? vehicleType;

  ActivityTrip({
    required this.id,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.status,
    required this.fareEstimate,
    this.fareFinal,
    required this.paymentMethod,
    this.distanceM,
    this.durationS,
    required this.createdAt,
    this.tripCompletedAt,
    this.canceledAt,
    this.cancelReason,
    this.canceledBy,
    this.driverName,
    this.driverAvatar,
    this.driverRating,
    this.vehicleMakeModel,
    this.vehicleColor,
    this.vehiclePlate,
    this.vehicleType,
  });

  // Convenience helpers
  int get displayFare => fareFinal ?? fareEstimate;
  double? get distanceKm => distanceM != null ? distanceM! / 1000.0 : null;
  int? get durationMin => durationS != null ? (durationS! / 60).round() : null;

  // backend usually uses "CANCELED" (US spelling). sometimes "CANCELLED" appears.
  bool get isCanceled => status == 'CANCELED' || status == 'CANCELLED';
  bool get isCompleted => status == 'COMPLETED';

  // ─────────────────────────────────────────────────────────────
  // ✅ Helpers (STATIC): usable inside factory constructor
  // ─────────────────────────────────────────────────────────────
  static String _asString(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final s = v.toString();
    return s.isEmpty ? fallback : s;
  }

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static double? _asDoubleNullable(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _asDateNullable(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  factory ActivityTrip.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;
    final dp = driver?['driver_profile'] as Map<String, dynamic>?;

    // support both camelCase + snake_case
    final fareEstimateRaw = json['fareEstimate'] ?? json['fare_estimate'];
    final fareFinalRaw    = json['fareFinal'] ?? json['fare_final'];
    final distanceRaw     = json['distanceM'] ?? json['distance_m'];
    final durationRaw     = json['durationS'] ?? json['duration_s'];

    final createdAtRaw = json['createdAt'] ?? json['created_at'];
    final tripCompletedAtRaw = json['tripCompletedAt'] ?? json['trip_completed_at'];
    final canceledAtRaw = json['canceledAt'] ?? json['canceled_at'];

    final cancelReasonRaw = json['cancelReason'] ?? json['cancel_reason'];
    final canceledByRaw = json['canceledBy'] ?? json['canceled_by'];

    return ActivityTrip(
      id: _asString(json['id']),
      pickupAddress: _asString(json['pickupAddress'] ?? json['pickup_address']),
      dropoffAddress: _asString(json['dropoffAddress'] ?? json['dropoff_address']),
      status: _asString(json['status'], fallback: 'SEARCHING').toUpperCase(),

      // ✅ guaranteed int (never null)
      fareEstimate: _asInt(fareEstimateRaw, fallback: 0),

      // ✅ nullable int
      fareFinal: fareFinalRaw == null ? null : _asInt(fareFinalRaw),

      paymentMethod: _asString(
        json['paymentMethod'] ?? json['payment_method'],
        fallback: 'CASH',
      ).toUpperCase(),

      distanceM: distanceRaw == null ? null : _asInt(distanceRaw),
      durationS: durationRaw == null ? null : _asInt(durationRaw),

      createdAt: DateTime.tryParse(_asString(createdAtRaw)) ?? DateTime.now(),
      tripCompletedAt: _asDateNullable(tripCompletedAtRaw),
      canceledAt: _asDateNullable(canceledAtRaw),

      cancelReason: _asString(cancelReasonRaw, fallback: '').trim().isEmpty
          ? null
          : _asString(cancelReasonRaw).trim(),

      canceledBy: _asString(canceledByRaw, fallback: '').trim().isEmpty
          ? null
          : _asString(canceledByRaw).trim(),

      driverName: driver != null
          ? '${driver['first_name'] ?? ''} ${driver['last_name'] ?? ''}'.trim()
          : null,
      driverAvatar: driver?['avatar_url']?.toString(),

      // dp is snake_case
      driverRating: _asDoubleNullable(dp?['rating_avg']),
      vehicleMakeModel: dp?['vehicle_make_model']?.toString(),
      vehicleColor: dp?['vehicle_color']?.toString(),
      vehiclePlate: dp?['vehicle_plate']?.toString(),
      vehicleType: dp?['vehicle_type']?.toString(),
    );
  }
}

class ActivityRental {
  final String id;
  final String rentalType;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final double totalPrice;
  final String paymentStatus;
  final String? paymentMethod;
  final String? cancellationReason;
  final DateTime createdAt;
  // vehicle fields — Vehicle uses underscored:true
  final String? vehicleMakeModel;     // make_model
  final String? vehicleColor;         // color
  final String? vehiclePlate;         // plate
  final List<String> vehicleImages;   // images (JSON array) ✅ was: image_url
  final double? pricePerHour;         // rental_price_per_hour ✅ was: price_per_hour
  final double? pricePerDay;          // rental_price_per_day ✅ was: price_per_day

  ActivityRental({
    required this.id,
    required this.rentalType,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalPrice,
    required this.paymentStatus,
    this.paymentMethod,
    this.cancellationReason,
    required this.createdAt,
    this.vehicleMakeModel,
    this.vehicleColor,
    this.vehiclePlate,
    this.vehicleImages = const [],
    this.pricePerHour,
    this.pricePerDay,
  });

  String? get firstImage => vehicleImages.isNotEmpty ? vehicleImages.first : null;

  factory ActivityRental.fromJson(Map<String, dynamic> json) {
    // ✅ Vehicle uses underscored:true → snake_case in JSON
    final v = json['vehicle'] as Map<String, dynamic>?;

    // ✅ images is a JSON array, not a string URL
    List<String> images = [];
    if (v?['images'] != null) {
      final raw = v!['images'];
      if (raw is List) {
        images = raw.map((e) => e.toString()).toList();
      } else if (raw is String) {
        try {
          final parsed = jsonDecode(raw) as List;
          images = parsed.map((e) => e.toString()).toList();
        } catch (_) {}
      }
    }

    return ActivityRental(
      id: json['id']?.toString() ?? '',
      rentalType: json['rentalType']?.toString() ?? 'DAY',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? '',
      totalPrice: double.tryParse(json['totalPrice']?.toString() ?? '0') ?? 0,
      paymentStatus: json['paymentStatus']?.toString() ?? 'unpaid',
      paymentMethod: json['paymentMethod']?.toString(),
      cancellationReason: json['cancellationReason']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      // ✅ FIXED: correct field names from Vehicle model (underscored:true)
      vehicleMakeModel: v?['make_model']?.toString(),        // ✅ was: brand + model
      vehicleColor: v?['color']?.toString(),
      vehiclePlate: v?['plate']?.toString(),
      vehicleImages: images,                                  // ✅ was: image_url
      pricePerHour: double.tryParse(v?['rental_price_per_hour']?.toString() ?? ''), // ✅
      pricePerDay: double.tryParse(v?['rental_price_per_day']?.toString() ?? ''),   // ✅
    );
  }
}

class ActivityService {
  final String id;
  final String requestId;
  final String description;
  final String status;
  final String neededWhen;
  final String serviceLocation;
  final double? customerBudget;
  final double? finalAmount;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? rejectionReason;
  final String? cancellationReason;
  final String customerId;
  final String providerId;
  // listing
  final String? listingTitle;
  final String? listingPricingType;
  final String? listingCategoryNameFr;  // ✅ was: listingCategory (flat string)
  final String? listingCategoryNameEn;
  // people
  final String? customerName;
  final String? customerAvatar;
  final String? providerName;
  final String? providerAvatar;

  ActivityService({
    required this.id,
    required this.requestId,
    required this.description,
    required this.status,
    required this.neededWhen,
    required this.serviceLocation,
    this.customerBudget,
    this.finalAmount,
    this.paymentMethod,
    required this.createdAt,
    this.completedAt,
    this.rejectionReason,
    this.cancellationReason,
    required this.customerId,
    required this.providerId,
    this.listingTitle,
    this.listingPricingType,
    this.listingCategoryNameFr,
    this.listingCategoryNameEn,
    this.customerName,
    this.customerAvatar,
    this.providerName,
    this.providerAvatar,
  });

  String? get listingCategoryDisplay => listingCategoryNameFr ?? listingCategoryNameEn;
  double? get displayAmount => finalAmount ?? customerBudget;

  factory ActivityService.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'] as Map<String, dynamic>?;
    // ✅ FIXED: category is a nested object, not a flat string
    final category = listing?['category'] as Map<String, dynamic>?;
    final customer = json['customer'] as Map<String, dynamic>?;
    final provider = json['provider'] as Map<String, dynamic>?;

    return ActivityService(
      id: json['id']?.toString() ?? '',
      requestId: json['request_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      neededWhen: json['needed_when']?.toString() ?? 'asap',
      serviceLocation: json['service_location']?.toString() ?? '',
      customerBudget: double.tryParse(json['customer_budget']?.toString() ?? ''),
      finalAmount: double.tryParse(json['final_amount']?.toString() ?? ''),
      paymentMethod: json['payment_method']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      rejectionReason: json['rejection_reason']?.toString(),
      cancellationReason: json['cancellation_reason']?.toString(),
      customerId: json['customer_id']?.toString() ?? '',
      providerId: json['provider_id']?.toString() ?? '',
      listingTitle: listing?['title']?.toString(),
      listingPricingType: listing?['pricing_type']?.toString(),
      // ✅ FIXED: nested category object, not flat string
      listingCategoryNameFr: category?['name_fr']?.toString(),
      listingCategoryNameEn: category?['name_en']?.toString(),
      customerName: customer != null
          ? '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim()
          : null,
      customerAvatar: customer?['avatar_url']?.toString(),
      providerName: provider != null
          ? '${provider['first_name'] ?? ''} ${provider['last_name'] ?? ''}'.trim()
          : null,
      providerAvatar: provider?['avatar_url']?.toString(),
    );
  }
}

class PaginationMeta {
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  PaginationMeta({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      totalPages: json['totalPages'] ?? 1,
      hasNextPage: json['hasNextPage'] ?? false,
      hasPrevPage: json['hasPrevPage'] ?? false,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ═══════════════════════════════════════════════════════════════════════

class _C {
  static const bg = Color(0xFFF7F7F8);
  static const card = Colors.white;
  static const black = Color(0xFF0A0A0A);
  static const gold = Color(0xFFFFDC71);
  static const goldDark = Color(0xFFD4A800);
  static const ink = Color(0xFF1A1A2E);
  static const muted = Color(0xFF8A8A9A);
  static const border = Color(0xFFEEEEF2);
  static const success = Color(0xFF00B37E);
  static const successBg = Color(0xFFE8FFF6);
  static const error = Color(0xFFFF4D4F);
  static const errorBg = Color(0xFFFFF0F0);
  static const warning = Color(0xFFFF8C00);
  static const warningBg = Color(0xFFFFF7E6);
  static const info = Color(0xFF1890FF);
  static const infoBg = Color(0xFFE8F4FF);
  static const purple = Color(0xFF7C3AED);
  static const purpleBg = Color(0xFFF5F3FF);
}

// ═══════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<ActivityTrip> _trips = [];
  PaginationMeta? _tripsMeta;
  bool _tripsLoading = false;
  bool _tripsLoadingMore = false;
  String _tripStatusFilter = 'all';
  int _tripsPage = 1;

  List<ActivityRental> _rentals = [];
  PaginationMeta? _rentalsMeta;
  bool _rentalsLoading = false;
  bool _rentalsLoadingMore = false;
  String _rentalStatusFilter = 'all';
  int _rentalsPage = 1;

  List<ActivityService> _services = [];
  PaginationMeta? _servicesMeta;
  bool _servicesLoading = false;
  bool _servicesLoadingMore = false;
  String _serviceStatusFilter = 'all';
  String _serviceRoleFilter = 'all';
  int _servicesPage = 1;

  int _totalTrips = 0;
  int _totalRentals = 0;
  int _totalServices = 0;

  String? _accessToken;
  String? _userId;

  final ScrollController _tripsScroll = ScrollController();
  final ScrollController _rentalsScroll = ScrollController();
  final ScrollController _servicesScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _tripsScroll.addListener(() => _onScroll(_tripsScroll, 'trips'));
    _rentalsScroll.addListener(() => _onScroll(_rentalsScroll, 'rentals'));
    _servicesScroll.addListener(() => _onScroll(_servicesScroll, 'services'));
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    final userData = prefs.getString('user_data');
    if (userData != null) {
      final decoded = json.decode(userData);
      _userId = decoded['uuid'] ?? decoded['id']?.toString();
    }
    _loadAll();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final tab = _tabController.index;
    if (tab == 1 && _trips.isEmpty && !_tripsLoading) _loadTrips(reset: true);
    if (tab == 2 && _rentals.isEmpty && !_rentalsLoading) _loadRentals(reset: true);
    if (tab == 3 && _services.isEmpty && !_servicesLoading) _loadServices(reset: true);
  }

  void _onScroll(ScrollController c, String type) {
    if (c.position.pixels >= c.position.maxScrollExtent - 200) {
      if (type == 'trips' && !_tripsLoadingMore && (_tripsMeta?.hasNextPage ?? false)) {
        _loadTrips(loadMore: true);
      } else if (type == 'rentals' && !_rentalsLoadingMore && (_rentalsMeta?.hasNextPage ?? false)) {
        _loadRentals(loadMore: true);
      } else if (type == 'services' && !_servicesLoadingMore && (_servicesMeta?.hasNextPage ?? false)) {
        _loadServices(loadMore: true);
      }
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadTrips(reset: true),
      _loadRentals(reset: true),
      _loadServices(reset: true),
    ]);
  }

  Future<void> _loadTrips({bool reset = false, bool loadMore = false}) async {
    if (_tripsLoading || _tripsLoadingMore) return;
    if (reset) {
      setState(() { _tripsLoading = true; _tripsPage = 1; _trips = []; });
    } else if (loadMore) {
      setState(() { _tripsLoadingMore = true; _tripsPage++; });
    }
    try {
      // ✅ Status values are uppercase to match Trip model ENUM
      final statusParam = _tripStatusFilter == 'all' ? '' : '&status=${_tripStatusFilter.toUpperCase()}';
      final url = '${AppConfig.apiBaseUrl}/activity/trips?page=$_tripsPage&limit=10$statusParam';
      final r = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final items = (data['data']['items'] as List).map((e) => ActivityTrip.fromJson(e)).toList();
        final meta = PaginationMeta.fromJson(data['data']['meta']);
        setState(() {
          _trips = reset ? items : [..._trips, ...items];
          _tripsMeta = meta;
          _totalTrips = meta.total;
        });
      }
    } catch (e) {
      debugPrint('❌ [ACTIVITY] Trips: $e');
    } finally {
      setState(() { _tripsLoading = false; _tripsLoadingMore = false; });
    }
  }

  Future<void> _loadRentals({bool reset = false, bool loadMore = false}) async {
    if (_rentalsLoading || _rentalsLoadingMore) return;
    if (reset) {
      setState(() { _rentalsLoading = true; _rentalsPage = 1; _rentals = []; });
    } else if (loadMore) {
      setState(() { _rentalsLoadingMore = true; _rentalsPage++; });
    }
    try {
      final statusParam = _rentalStatusFilter == 'all' ? '' : '&status=$_rentalStatusFilter';
      final url = '${AppConfig.apiBaseUrl}/activity/rentals?page=$_rentalsPage&limit=10$statusParam';
      final r = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final items = (data['data']['items'] as List).map((e) => ActivityRental.fromJson(e)).toList();
        final meta = PaginationMeta.fromJson(data['data']['meta']);
        setState(() {
          _rentals = reset ? items : [..._rentals, ...items];
          _rentalsMeta = meta;
          _totalRentals = meta.total;
        });
      }
    } catch (e) {
      debugPrint('❌ [ACTIVITY] Rentals: $e');
    } finally {
      setState(() { _rentalsLoading = false; _rentalsLoadingMore = false; });
    }
  }

  Future<void> _loadServices({bool reset = false, bool loadMore = false}) async {
    if (_servicesLoading || _servicesLoadingMore) return;
    if (reset) {
      setState(() { _servicesLoading = true; _servicesPage = 1; _services = []; });
    } else if (loadMore) {
      setState(() { _servicesLoadingMore = true; _servicesPage++; });
    }
    try {
      final statusParam = _serviceStatusFilter == 'all' ? '' : '&status=$_serviceStatusFilter';
      final roleParam = _serviceRoleFilter == 'all' ? '' : '&role=$_serviceRoleFilter';
      final url = '${AppConfig.apiBaseUrl}/activity/services?page=$_servicesPage&limit=10$statusParam$roleParam';
      final r = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        final items = (data['data']['items'] as List).map((e) => ActivityService.fromJson(e)).toList();
        final meta = PaginationMeta.fromJson(data['data']['meta']);
        setState(() {
          _services = reset ? items : [..._services, ...items];
          _servicesMeta = meta;
          _totalServices = meta.total;
        });
      }
    } catch (e) {
      debugPrint('❌ [ACTIVITY] Services: $e');
    } finally {
      setState(() { _servicesLoading = false; _servicesLoadingMore = false; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tripsScroll.dispose();
    _rentalsScroll.dispose();
    _servicesScroll.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [_buildSliverAppBar()],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildTripsTab(),
            _buildRentalsTab(),
            _buildServicesTab(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 148,
      pinned: true,
      elevation: 0,
      backgroundColor: _C.black,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF111111), Color(0xFF0A0A0A)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 64, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('nav.activity'),
                style: TextStyle(
                  fontFamily: 'LeagueSpartan',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _statPill('$_totalTrips', tr('activity.trips'), Icons.directions_car_rounded),
                  const SizedBox(width: 8),
                  _statPill('$_totalRentals', tr('activity.rentals'), Icons.car_rental_rounded),
                  const SizedBox(width: 8),
                  _statPill('$_totalServices', tr('activity.services'), Icons.handyman_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(46),
        child: Container(
          color: _C.black,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: _C.gold,
            unselectedLabelColor: Colors.white38,
            indicatorColor: _C.gold,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontFamily: 'LeagueSpartan',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'LeagueSpartan',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(text: tr('activity.overview')),
              Tab(text: tr('activity.trips')),
              Tab(text: tr('activity.rentals')),
              Tab(text: tr('activity.services')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statPill(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _C.gold),
          const SizedBox(width: 5),
          Text(
            '$value $label',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // OVERVIEW TAB
  // ══════════════════════════════════════════════════════════════════

  Widget _buildOverviewTab() {
    final loading = _tripsLoading && _rentalsLoading && _servicesLoading;
    if (loading) return _loader();
    final isEmpty = _trips.isEmpty && _rentals.isEmpty && _services.isEmpty;

    return RefreshIndicator(
      color: _C.gold,
      backgroundColor: _C.black,
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          // Summary cards
          _buildSummaryRow(),
          const SizedBox(height: 28),

          if (_trips.isNotEmpty) ...[
            _sectionHeader(tr('activity.trips'), _totalTrips, () => _tabController.animateTo(1)),
            const SizedBox(height: 12),
            ..._trips.take(3).map(_buildTripCard),
            const SizedBox(height: 28),
          ],
          if (_rentals.isNotEmpty) ...[
            _sectionHeader(tr('activity.rentals'), _totalRentals, () => _tabController.animateTo(2)),
            const SizedBox(height: 12),
            ..._rentals.take(2).map(_buildRentalCard),
            const SizedBox(height: 28),
          ],
          if (_services.isNotEmpty) ...[
            _sectionHeader(tr('activity.services'), _totalServices, () => _tabController.animateTo(3)),
            const SizedBox(height: 12),
            ..._services.take(2).map((s) => _buildServiceCard(s)),
            const SizedBox(height: 28),
          ],
          if (isEmpty) _emptyState(
            icon: Icons.history_rounded,
            title: tr('activity.noActivity'),
            subtitle: tr('activity.noActivitySub'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        _summaryCard('$_totalTrips', tr('activity.trips'), Icons.route_rounded, _C.black),
        const SizedBox(width: 10),
        _summaryCard('$_totalRentals', tr('activity.rentals'), Icons.car_rental_rounded, _C.gold,
            valueColor: _C.black, labelColor: Colors.black54),
        const SizedBox(width: 10),
        _summaryCard('$_totalServices', tr('activity.services'), Icons.handyman_rounded, _C.black),
      ],
    );
  }

  Widget _summaryCard(String value, String label, IconData icon, Color bg,
      {Color valueColor = Colors.white, Color labelColor = Colors.white54}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: valueColor.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: valueColor,
                letterSpacing: -1,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count, VoidCallback onAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'LeagueSpartan',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _C.ink,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _C.ink,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: onAll,
          child: const Text(
            'See all →',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _C.goldDark,
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // TRIPS TAB
  // ══════════════════════════════════════════════════════════════════

  Widget _buildTripsTab() {
    return Column(
      children: [
        _filterRow(
          filters: const [
            ('all', 'All'),
            ('completed', 'Completed'),
            ('canceled', 'Cancelled'),
            ('in_progress', 'In Progress'),
            ('searching', 'Searching'),
          ],
          selected: _tripStatusFilter,
          onSelect: (v) { setState(() => _tripStatusFilter = v); _loadTrips(reset: true); },
        ),
        Expanded(
          child: _tripsLoading
              ? _loader()
              : _trips.isEmpty
              ? _emptyState(icon: Icons.directions_car_outlined, title: tr('activity.noTrips'), subtitle: tr('activity.tryDifferentFilter'))
              : RefreshIndicator(
            color: _C.gold,
            backgroundColor: _C.black,
            onRefresh: () => _loadTrips(reset: true),
            child: ListView.builder(
              controller: _tripsScroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              itemCount: _trips.length + (_tripsLoadingMore ? 1 : 0),
              itemBuilder: (_, i) => i == _trips.length
                  ? _loadMoreSpinner()
                  : _buildTripCard(_trips[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // RENTALS TAB
  // ══════════════════════════════════════════════════════════════════

  Widget _buildRentalsTab() {
    return Column(
      children: [
        _filterRow(
          filters: const [
            ('all', 'All'),
            ('PENDING', 'Pending'),
            ('CONFIRMED', 'Confirmed'),
            ('COMPLETED', 'Completed'),
            ('CANCELLED', 'Cancelled'),
          ],
          selected: _rentalStatusFilter,
          onSelect: (v) { setState(() => _rentalStatusFilter = v); _loadRentals(reset: true); },
        ),
        Expanded(
          child: _rentalsLoading
              ? _loader()
              : _rentals.isEmpty
              ? _emptyState(icon: Icons.car_rental_outlined, title: tr('activity.noRentals'), subtitle: tr('activity.rentToStart'))
              : RefreshIndicator(
            color: _C.gold,
            backgroundColor: _C.black,
            onRefresh: () => _loadRentals(reset: true),
            child: ListView.builder(
              controller: _rentalsScroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              itemCount: _rentals.length + (_rentalsLoadingMore ? 1 : 0),
              itemBuilder: (_, i) => i == _rentals.length
                  ? _loadMoreSpinner()
                  : _buildRentalCard(_rentals[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SERVICES TAB
  // ══════════════════════════════════════════════════════════════════

  Widget _buildServicesTab() {
    return Column(
      children: [
        _filterRow(
          filters: const [
            ('all', 'All Roles'),
            ('customer', 'Customer'),
            ('provider', 'Provider'),
          ],
          selected: _serviceRoleFilter,
          onSelect: (v) { setState(() => _serviceRoleFilter = v); _loadServices(reset: true); },
          bg: _C.black,
          chipBg: Colors.white10,
          chipLabel: Colors.white54,
          selBg: _C.gold,
          selLabel: _C.black,
        ),
        _filterRow(
          filters: const [
            ('all', 'All'),
            ('pending', 'Pending'),
            ('accepted', 'Accepted'),
            ('in_progress', 'In Progress'),
            ('completed', 'Completed'),
            ('cancelled', 'Cancelled'),
            ('disputed', 'Disputed'),
          ],
          selected: _serviceStatusFilter,
          onSelect: (v) { setState(() => _serviceStatusFilter = v); _loadServices(reset: true); },
        ),
        Expanded(
          child: _servicesLoading
              ? _loader()
              : _services.isEmpty
              ? _emptyState(icon: Icons.handyman_outlined, title: tr('activity.noServices'), subtitle: tr('activity.postServiceHint'))
              : RefreshIndicator(
            color: _C.gold,
            backgroundColor: _C.black,
            onRefresh: () => _loadServices(reset: true),
            child: ListView.builder(
              controller: _servicesScroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              itemCount: _services.length + (_servicesLoadingMore ? 1 : 0),
              itemBuilder: (_, i) => i == _services.length
                  ? _loadMoreSpinner()
                  : _buildServiceCard(_services[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // FILTER ROW
  // ══════════════════════════════════════════════════════════════════

  Widget _filterRow({
    required List<(String, String)> filters,
    required String selected,
    required void Function(String) onSelect,
    Color bg = const Color(0xFFF7F7F8),
    Color chipBg = Colors.transparent,
    Color chipLabel = const Color(0xFF8A8A9A),
    Color selBg = const Color(0xFF0A0A0A),
    Color selLabel = Colors.white,
  }) {
    return Container(
      color: bg,
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        itemCount: filters.length,
        itemBuilder: (_, i) {
          final (val, label) = filters[i];
          final sel = selected == val;
          return GestureDetector(
            onTap: () => onSelect(val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 7),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? selBg : chipBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? selBg : chipLabel.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? selLabel : chipLabel,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // TRIP CARD
  // ══════════════════════════════════════════════════════════════════

  Widget _buildTripCard(ActivityTrip trip) {
    final badge = _tripBadge(trip.status);
    final fare = trip.displayFare;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _badge(badge.$1, badge.$2, badge.$3),
                const SizedBox(width: 8),
                Text(_relativeDate(trip.createdAt),
                    style: const TextStyle(fontSize: 11, color: _C.muted)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${fare.toString()} XAF',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _C.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      _formatPayment(trip.paymentMethod),
                      style: const TextStyle(fontSize: 10, color: _C.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Route ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 9, height: 9,
                      decoration: BoxDecoration(
                        color: _C.ink,
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.ink, width: 2),
                      ),
                    ),
                    Container(width: 1.5, height: 26, color: _C.border),
                    Container(
                      width: 9, height: 9,
                      decoration: BoxDecoration(
                        color: _C.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.goldDark, width: 1.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.pickupAddress.isNotEmpty ? trip.pickupAddress : 'Pickup location',
                        style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        trip.dropoffAddress.isNotEmpty ? trip.dropoffAddress : 'Dropoff location',
                        style: const TextStyle(fontSize: 13, color: _C.ink, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Divider(color: _C.border, height: 1),
          ),

          // ── Footer ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                _avatar(trip.driverAvatar, trip.driverName, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.driverName?.isNotEmpty == true ? trip.driverName! : 'No driver assigned',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.ink),
                      ),
                      if ((trip.vehicleMakeModel?.isNotEmpty ?? false) || (trip.vehiclePlate?.isNotEmpty ?? false))
                        Text(
                          [trip.vehicleMakeModel, trip.vehiclePlate]
                              .where((e) => e != null && e.isNotEmpty).join(' · '),
                          style: const TextStyle(fontSize: 11, color: _C.muted),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (trip.distanceKm != null)
                      _chip('${trip.distanceKm!.toStringAsFixed(1)} km'),
                    if (trip.durationMin != null) ...[
                      const SizedBox(width: 5),
                      _chip('${trip.durationMin} min'),
                    ],
                    if (trip.driverRating != null) ...[
                      const SizedBox(width: 5),
                      _ratingChip(trip.driverRating!),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Cancel reason ────────────────────────────────────────
          if (trip.isCanceled && trip.cancelReason != null && trip.cancelReason!.isNotEmpty)
            _reasonBanner(trip.cancelReason!),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // RENTAL CARD
  // ══════════════════════════════════════════════════════════════════

  Widget _buildRentalCard(ActivityRental rental) {
    final badge = _rentalBadge(rental.status);
    final name = rental.vehicleMakeModel ?? 'Vehicle';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Image / placeholder ──────────────────────────────────
          rental.firstImage != null && rental.firstImage!.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: rental.firstImage!,
            height: 110,
            width: double.infinity,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _vehiclePlaceholder(name),
          )
              : _vehiclePlaceholder(name),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Status + price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      _badge(badge.$1, badge.$2, badge.$3),
                      const SizedBox(width: 8),
                      _chip(rental.rentalType),
                    ]),
                    Text(
                      '${rental.totalPrice.toStringAsFixed(0)} XAF',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _C.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Name + color dot
                Row(
                  children: [
                    const Icon(Icons.directions_car_rounded, size: 15, color: _C.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink),
                      ),
                    ),
                    if (rental.vehiclePlate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rental.vehiclePlate!,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _C.ink, letterSpacing: 0.5),
                        ),
                      ),
                    if (rental.vehicleColor != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 13, height: 13,
                        decoration: BoxDecoration(
                          color: _parseColor(rental.vehicleColor!),
                          shape: BoxShape.circle,
                          border: Border.all(color: _C.border),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                // Dates
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: _C.muted),
                    const SizedBox(width: 6),
                    Text(
                      '${_shortDate(rental.startDate)}  →  ${_shortDate(rental.endDate)}',
                      style: const TextStyle(fontSize: 12, color: _C.muted),
                    ),
                    const Spacer(),
                    _paymentBadge(rental.paymentStatus),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehiclePlaceholder(String name) {
    return Container(
      height: 90,
      width: double.infinity,
      color: _C.ink,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car_rounded, color: Colors.white24, size: 28),
            const SizedBox(width: 10),
            Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white38)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SERVICE CARD
  // ══════════════════════════════════════════════════════════════════

  Widget _buildServiceCard(ActivityService service) {
    final isProvider = service.providerId == _userId;
    final badge = _serviceBadge(service.status);
    final otherName = isProvider ? service.customerName : service.providerName;
    final otherAvatar = isProvider ? service.customerAvatar : service.providerAvatar;
    final amount = service.displayAmount;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: isProvider
            ? Border.all(color: _C.gold.withOpacity(0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row ──────────────────────────────────────────
            Row(
              children: [
                _roleBadge(isProvider),
                const SizedBox(width: 8),
                _badge(badge.$1, badge.$2, badge.$3),
                const Spacer(),
                if (amount != null)
                  Text(
                    '${amount.toStringAsFixed(0)} XAF',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Listing title ─────────────────────────────────────
            Text(
              service.listingTitle ?? 'Service Request',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.ink),
            ),
            if (service.listingCategoryDisplay != null) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.category_outlined, size: 11, color: _C.muted),
                  const SizedBox(width: 4),
                  Text(
                    service.listingCategoryDisplay!,
                    style: const TextStyle(fontSize: 11, color: _C.muted),
                  ),
                  if (service.listingPricingType != null) ...[
                    const SizedBox(width: 8),
                    _chip(service.listingPricingType!),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 10),

            // ── Description ───────────────────────────────────────
            Text(
              service.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF555566), height: 1.45),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            Divider(color: _C.border, height: 1),
            const SizedBox(height: 10),

            // ── Footer ───────────────────────────────────────────
            Row(
              children: [
                _avatar(otherAvatar, otherName, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isProvider
                            ? 'From ${otherName ?? 'Customer'}'
                            : 'By ${otherName ?? 'Provider'}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.ink),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 11, color: _C.muted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              service.serviceLocation,
                              style: const TextStyle(fontSize: 11, color: _C.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(_relativeDate(service.createdAt),
                    style: const TextStyle(fontSize: 11, color: _C.muted)),
              ],
            ),

            // ── Reason banner ─────────────────────────────────────
            if ((service.status == 'rejected' || service.status == 'cancelled') &&
                (service.rejectionReason != null || service.cancellationReason != null)) ...[
              const SizedBox(height: 10),
              _reasonBanner(service.rejectionReason ?? service.cancellationReason ?? ''),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // SHARED SMALL WIDGETS
  // ══════════════════════════════════════════════════════════════════

  Widget _avatar(String? url, String? name, {double size = 34}) {
    final initial = (name?.isNotEmpty ?? false) ? name![0].toUpperCase() : '?';
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.3),
        child: CachedNetworkImage(
          imageUrl: url, width: size, height: size, fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _avatarFallback(initial, size),
        ),
      );
    }
    return _avatarFallback(initial, size);
  }

  Widget _avatarFallback(String initial, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: _C.ink,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: _C.gold,
        ),
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _roleBadge(bool isProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isProvider ? _C.ink : _C.infoBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isProvider ? 'Provider' : 'Customer',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isProvider ? _C.gold : _C.info,
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.muted)),
    );
  }

  Widget _ratingChip(double r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: _C.gold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 11, color: _C.goldDark),
          const SizedBox(width: 3),
          Text(r.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.goldDark)),
        ],
      ),
    );
  }

  Widget _paymentBadge(String status) {
    final (label, bg, fg) = switch (status.toLowerCase()) {
      'paid' => ('Paid', _C.successBg, _C.success),
      'refunded' => ('Refunded', _C.infoBg, _C.info),
      _ => ('Unpaid', _C.warningBg, _C.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _reasonBanner(String reason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _C.errorBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: _C.error),
          const SizedBox(width: 7),
          Expanded(
            child: Text(reason, style: const TextStyle(fontSize: 12, color: _C.error)),
          ),
        ],
      ),
    );
  }

  Widget _loader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _C.gold),
          ),
          const SizedBox(height: 14),
          Text(tr('common.loading'), style: TextStyle(fontSize: 13, color: _C.muted)),
        ],
      ),
    );
  }

  Widget _loadMoreSpinner() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: _C.gold),
        ),
      ),
    );
  }

  Widget _emptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76, height: 76,
              decoration: BoxDecoration(color: _C.ink, borderRadius: BorderRadius.circular(22)),
              child: Icon(icon, size: 34, color: Colors.white24),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.ink)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(fontSize: 13, color: _C.muted, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STATUS BADGE HELPERS  →  (label, bgColor, textColor)
  // ══════════════════════════════════════════════════════════════════

  (String, Color, Color) _tripBadge(String status) => switch (status) {
    'COMPLETED'       => ('Completed',   _C.successBg, _C.success),
    'CANCELED'        => ('Cancelled',   _C.errorBg,   _C.error),
    'IN_PROGRESS'     => ('In Progress', _C.infoBg,    _C.info),
    'DRIVER_EN_ROUTE' => ('En Route',    _C.infoBg,    _C.info),
    'DRIVER_ARRIVED'  => ('Arrived',     _C.warningBg, _C.warning),
    'MATCHED'         => ('Matched',     _C.warningBg, _C.warning),
    'SEARCHING'       => ('Searching',   const Color(0xFFF0F0F5), _C.muted),
    _                 => (status,        const Color(0xFFF0F0F5), _C.muted),
  };

  (String, Color, Color) _rentalBadge(String status) => switch (status.toUpperCase()) {
    'COMPLETED' => ('Completed', _C.successBg, _C.success),
    'CANCELLED' => ('Cancelled', _C.errorBg,   _C.error),
    'CONFIRMED' => ('Confirmed', _C.infoBg,    _C.info),
    'PENDING'   => ('Pending',   _C.warningBg, _C.warning),
    _           => (status,      const Color(0xFFF0F0F5), _C.muted),
  };

  (String, Color, Color) _serviceBadge(String status) => switch (status) {
    'completed'                    => ('Completed',       _C.successBg, _C.success),
    'cancelled'                    => ('Cancelled',       _C.errorBg,   _C.error),
    'rejected'                     => ('Rejected',        _C.errorBg,   _C.error),
    'in_progress'                  => ('In Progress',     _C.infoBg,    _C.info),
    'accepted'                     => ('Accepted',        _C.successBg, _C.success),
    'payment_pending'              => ('Pay Pending',     _C.warningBg, _C.warning),
    'payment_confirmation_pending' => ('Confirming',      _C.warningBg, _C.warning),
    'payment_confirmed'            => ('Paid',            _C.successBg, _C.success),
    'disputed'                     => ('Disputed',        _C.purpleBg,  _C.purple),
    _                              => ('Pending',         const Color(0xFFF0F0F5), _C.muted),
  };

  // ══════════════════════════════════════════════════════════════════
  // UTIL
  // ══════════════════════════════════════════════════════════════════

  String _relativeDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatPayment(String m) => switch (m.toUpperCase()) {
    'CASH' => 'Cash',
    'MOMO' => 'MTN MoMo',
    'OM'   => 'Orange Money',
    _      => m,
  };

  Color _parseColor(String c) => switch (c.toLowerCase()) {
    'red'    => Colors.red.shade600,
    'blue'   => Colors.blue.shade600,
    'black'  => Colors.black87,
    'white'  => Colors.grey.shade200,
    'silver' => Colors.grey.shade400,
    'grey' || 'gray' => Colors.grey,
    'green'  => Colors.green.shade600,
    'yellow' => Colors.amber,
    'orange' => Colors.orange,
    'brown'  => Colors.brown,
    _        => Colors.grey.shade300,
  };
}
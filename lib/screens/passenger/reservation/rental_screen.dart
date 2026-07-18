import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import 'package:flutter/services.dart';
import 'package:wego_v1/screens/passenger/reservation/rent%20details/vehicle_details_screen.dart';
import 'dart:convert';
import '../../../service/rental_api_service.dart';
import '../../../utils/app_colors.dart';
import 'my rentals/my_rentals_screen.dart';

class RentalScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String accessToken;

  const RentalScreen({
    super.key,
    required this.user,
    required this.accessToken,
  });

  @override
  State<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends State<RentalScreen>
    with TickerProviderStateMixin {

  bool _loading = true;
  List<dynamic> _vehicles = [];
  List<dynamic> _categories = [];
  String _searchQuery = '';
  String _selectedCategoryId = 'ALL';
  Set<String> _favorites = {};

  // Pagination — load the fleet page by page (scales to 50k+ vehicles).
  int _page = 1;
  int _totalPages = 1;
  bool _loadingMore = false;
  final ScrollController _scroll = ScrollController();
  bool get _hasMore => _page < _totalPages;

  // Nullable so dispose() never throws if initState fails mid-way
  AnimationController? _headerController;
  AnimationController? _staggerController;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _staggerController = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);

    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });

    _scroll.addListener(_onScroll);

    _initData();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400 &&
        _hasMore && !_loadingMore && !_loading) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _headerController?.dispose();
    _staggerController?.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _initData() async {
    if (mounted) setState(() => _loading = true);
    await Future.wait([_fetchCategories(), _fetchVehicles()]);
  }

  Future<void> _fetchCategories() async {
    final r = await RentalApiService.fetchCategories(widget.accessToken);
    if (!mounted) return;
    if (r['success'] == true) {
      final d = r['data'];
      setState(() => _categories = d['categories'] ?? (d is List ? d : []));
    }
  }

  Future<void> _fetchVehicles() async {
    final r = await RentalApiService.fetchAvailableVehicles(
        widget.accessToken, page: 1, limit: 20);
    if (!mounted) return;
    setState(() => _loading = false);

    if (r['success'] == true) {
      final d = r['data'];
      setState(() {
        _vehicles = (d['vehicles'] ?? (d is List ? d : [])) as List<dynamic>;
        _page = (d is Map && d['page'] is int) ? d['page'] as int : 1;
        _totalPages = (d is Map && d['totalPages'] is int) ? d['totalPages'] as int : 1;
      });
      _headerController?.forward();
      _staggerController?.forward();
    } else {
      _showError(
        title: r['statusCode'] == 0 ? 'Connection Error' : 'Error',
        message: r['statusCode'] == 0
            ? 'Unable to connect. Check your internet connection.'
            : r['error'] ?? 'Failed to load vehicles',
      );
    }
  }

  // Append the next page when the user scrolls near the bottom.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final next = _page + 1;
    final r = await RentalApiService.fetchAvailableVehicles(
        widget.accessToken, page: next, limit: 20);
    if (!mounted) return;
    if (r['success'] == true && r['data'] is Map) {
      final d = r['data'] as Map;
      final more = (d['vehicles'] ?? []) as List<dynamic>;
      setState(() {
        _vehicles = [..._vehicles, ...more];
        _page = (d['page'] is int) ? d['page'] as int : next;
        _totalPages = (d['totalPages'] is int) ? d['totalPages'] as int : _totalPages;
        _loadingMore = false;
      });
    } else {
      setState(() => _loadingMore = false);
    }
  }

  List<dynamic> get _filtered => _vehicles.where((v) {
    final s = _searchQuery.isEmpty ||
        (v['makeModel'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
    final c = _selectedCategoryId == 'ALL' ||
        v['category']?['id'] == _selectedCategoryId;
    return s && c;
  }).toList();

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openVehicle(Map<String, dynamic> vehicle) {
    HapticFeedback.lightImpact();
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, a, __) => VehicleDetailsScreen(
          vehicle: vehicle, user: widget.user, accessToken: widget.accessToken),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: a.drive(Tween(
              begin: const Offset(1.0, 0.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))),
          child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  void _openMyRentals() {
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, a, __) => MyRentalsScreen(
          user: widget.user, accessToken: widget.accessToken),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: a.drive(Tween(
              begin: const Offset(1.0, 0.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))),
          child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<dynamic> _parseImages(dynamic raw) {
    if (raw == null) return [];
    if (raw is String) {
      try { final d = json.decode(raw); if (d is List) return d; } catch (_) {}
      return [];
    }
    return raw is List ? raw : [];
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    try {
      final v = double.parse(price.toString());
      if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
      return v.toStringAsFixed(0);
    } catch (_) { return price.toString(); }
  }

  IconData _categoryIcon(String? icon) {
    switch (icon) {
      case 'electric': return Icons.electric_car_rounded;
      case 'luxury':   return Icons.car_rental_rounded;
      case 'truck':    return Icons.local_shipping_rounded;
      default:         return Icons.directions_car_rounded;
    }
  }

  void _showError({required String title, required String message}) {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.backgroundWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 72, height: 72,
                decoration: BoxDecoration(color: AppColors.errorLight, shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40)),
            const SizedBox(height: 18),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(fontSize: 13,
                color: AppColors.textSecondary, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity,
                child: ElevatedButton(onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(tr('common.close'), style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700, color: Colors.white)))),
          ])),
    ));
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildCategoryRow(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _initData,
              color: AppColors.primaryGold,
              displacement: 20,
              child: _loading
                  ? _buildSkeleton()
                  : _filtered.isEmpty
                  ? _buildEmpty()
                  : _buildGrid(),
            ),
          ),
        ]),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70, size: 16),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.primaryGold.withOpacity(0.6), blurRadius: 6)],
                      )),
                  const SizedBox(width: 6),
                  Text(tr('rental.title'), style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: AppColors.primaryGold, letterSpacing: 1.2)),
                ]),
                const SizedBox(height: 4),
                Text(tr('rental.rentCar'), style: TextStyle(fontSize: 24,
                    fontWeight: FontWeight.w900, color: Colors.white,
                    letterSpacing: -0.6, height: 1.1)),
              ]),
            ),
            GestureDetector(
              onTap: _openMyRentals,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: AppColors.primaryGold.withOpacity(0.35),
                      blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_rounded, color: AppColors.primaryDark, size: 16),
                  SizedBox(width: 6),
                  Text(tr('rental.myRentals'), style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── SEARCH BAR ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          color: _searchFocused ? Colors.white : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _searchFocused
                  ? AppColors.primaryGold.withOpacity(0.6)
                  : Colors.white.withOpacity(0.12),
              width: 1.5),
          boxShadow: _searchFocused
              ? [BoxShadow(color: AppColors.primaryGold.withOpacity(0.15),
              blurRadius: 16, offset: const Offset(0, 4))]
              : null,
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
              color: _searchFocused ? AppColors.textPrimary : Colors.white.withOpacity(0.85)),
          decoration: InputDecoration(
            hintText: tr('rental.searchHint'),
            hintStyle: TextStyle(fontSize: 14,
                color: _searchFocused ? AppColors.textLight : Colors.white.withOpacity(0.4)),
            prefixIcon: Icon(Icons.search_rounded, size: 20,
                color: _searchFocused ? AppColors.primaryGold : Colors.white.withOpacity(0.5)),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                child: Icon(Icons.close_rounded, size: 18,
                    color: _searchFocused ? AppColors.textSecondary : Colors.white54))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── CATEGORY ROW ───────────────────────────────────────────────────────────

  Widget _buildCategoryRow() {
    return Container(
      color: const Color(0xFFF5F5F7),
      padding: const EdgeInsets.fromLTRB(20, 14, 0, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(right: 20, bottom: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(width: 3, height: 16,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(tr('rental.browseByType'), style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w800, color: Color(0xFF0D0D1A), letterSpacing: -0.3)),
            ]),
            if (!_loading)
              Text('${_filtered.length} vehicle${_filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight,
                      fontWeight: FontWeight.w600)),
          ]),
        ),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) return _chip(label: tr('common.all'), icon: Icons.apps_rounded,
                  selected: _selectedCategoryId == 'ALL',
                  onTap: () => setState(() => _selectedCategoryId = 'ALL'));
              final cat = _categories[i - 1];
              return _chip(label: cat['name'] ?? '', icon: _categoryIcon(cat['icon']),
                  selected: _selectedCategoryId == cat['id'],
                  onTap: () => setState(() => _selectedCategoryId = cat['id']));
            },
          ),
        ),
      ]),
    );
  }

  Widget _chip({required String label, required IconData icon,
    required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? Colors.transparent : AppColors.borderLight, width: 1.5),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.primaryGold.withOpacity(0.3),
              blurRadius: 8, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13,
              color: selected ? AppColors.primaryDark : AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: selected ? AppColors.primaryDark : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  // ── GRID ───────────────────────────────────────────────────────────────────

  Widget _buildGrid() {
    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              // image=160 + info=110 = 270 total
              // card width on 360px = (360-32-12)/2 = 158
              // ratio = 158/270 = 0.585
              childAspectRatio: 0.585,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate(
                  (_, i) {
                final stagger = _staggerController;
                if (stagger == null) return _buildCard(_filtered[i]);
                return AnimatedBuilder(
                  animation: stagger,
                  builder: (_, child) {
                    final t = Curves.easeOutCubic.transform(
                        (stagger.value - i * 0.07).clamp(0.0, 1.0));
                    return Transform.translate(
                        offset: Offset(0, 20 * (1 - t)),
                        child: Opacity(opacity: t, child: child));
                  },
                  child: _buildCard(_filtered[i]),
                );
              },
              childCount: _filtered.length,
            ),
          ),
        ),
        if (_loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 28),
              child: Center(
                child: SizedBox(
                  width: 26, height: 26,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: AppColors.primaryGold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── CARD ───────────────────────────────────────────────────────────────────
  // Layout: image(160px fixed) + info(110px fixed) = 270px total ✅

  Widget _buildCard(Map<String, dynamic> vehicle) {
    final id = vehicle['uuid']?.toString() ?? vehicle['id']?.toString() ?? '';
    final isFav = _favorites.contains(id);
    final images = _parseImages(vehicle['images']);
    final img = images.isNotEmpty ? images[0] as String? : null;
    final price = vehicle['rentalPricePerDay'];
    final category = vehicle['category']?['name'] as String?;

    return GestureDetector(
      onTap: () => _openVehicle(vehicle),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── IMAGE — 160px fixed ──────────────────────────────────
            SizedBox(
              height: 160,
              child: Stack(children: [
                // Photo
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    width: double.infinity, height: 160,
                    child: img != null
                        ? Image.network(img, fit: BoxFit.cover,
                        loadingBuilder: (_, child, prog) =>
                        prog == null ? child : const _Shimmer(),
                        errorBuilder: (_, __, ___) =>
                            _placeholder(vehicle['makeModel']))
                        : _placeholder(vehicle['makeModel']),
                  ),
                ),

                // Gradient overlay
                Positioned(bottom: 0, left: 0, right: 0, height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
                        gradient: LinearGradient(
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.52)])),
                  ),
                ),

                // Category chip — top left
                if (category != null)
                  Positioned(top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(7)),
                      child: Text(category, style: const TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
                    ),
                  ),

                // Favorite — top right
                Positioned(top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => isFav ? _favorites.remove(id) : _favorites.add(id));
                    },
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15),
                              blurRadius: 6, offset: const Offset(0, 2))]),
                      child: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                          size: 15, color: isFav ? AppColors.error : Colors.grey),
                    ),
                  ),
                ),

                // Price — bottom left
                Positioned(bottom: 8, left: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('XAF ${_formatPrice(price)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                              color: AppColors.primaryGold, letterSpacing: -0.3)),
                      Text(tr('rental.perDay'), style: TextStyle(fontSize: 9,
                          color: Colors.white70, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ]),
            ),

            // ── INFO — 110px fixed ───────────────────────────────────
            SizedBox(
              height: 110,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Name
                    Text(vehicle['makeModel'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                            color: Color(0xFF0D0D1A), letterSpacing: -0.3, height: 1.2),
                        maxLines: 1, overflow: TextOverflow.ellipsis),

                    const SizedBox(height: 5),

                    // Location + seats row
                    Row(children: [
                      Icon(Icons.location_on_rounded, size: 11, color: AppColors.textLight),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(vehicle['region'] ?? 'Douala',
                            style: TextStyle(fontSize: 11, color: AppColors.textLight,
                                fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.airline_seat_recline_normal_rounded,
                          size: 11, color: AppColors.textLight),
                      const SizedBox(width: 2),
                      Text('${vehicle['seats'] ?? 4}',
                          style: TextStyle(fontSize: 11, color: AppColors.textLight,
                              fontWeight: FontWeight.w500)),
                    ]),

                    const Spacer(),

                    // CTA button — 34px
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: ElevatedButton(
                        onPressed: () => _openVehicle(vehicle),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D0D1A),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(tr('rental.viewDetails'),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: 0.2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SKELETON ───────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 0.585,
                crossAxisSpacing: 12, mainAxisSpacing: 14),
            delegate: SliverChildBuilderDelegate((_, __) => _skeletonCard(), childCount: 6),
          ),
        ),
      ],
    );
  }

  Widget _skeletonCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: const SizedBox(width: double.infinity, height: 160, child: _Shimmer())),
        SizedBox(height: 110,
            child: Padding(padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max, children: [
                      _shimmerLine(110, 11),
                      const SizedBox(height: 8),
                      _shimmerLine(75, 9),
                      const Spacer(),
                      _shimmerLine(double.infinity, 34),
                    ]))),
      ]),
    );
  }

  Widget _shimmerLine(double width, double height) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(width: width, height: height, child: const _Shimmer()));
  }

  // ── EMPTY ──────────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
      SizedBox(height: 360,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 100, height: 100,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                        blurRadius: 20, offset: const Offset(0, 6))]),
                child: Icon(Icons.car_rental_rounded, size: 44, color: AppColors.textLight)),
            const SizedBox(height: 24),
            Text(tr('rental.noVehicles'), style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.w800, color: Color(0xFF0D0D1A))),
            const SizedBox(height: 8),
            Text(tr('rental.adjustFilters'),
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => setState(() {
                _searchQuery = ''; _searchController.clear(); _selectedCategoryId = 'ALL'; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppColors.primaryGold.withOpacity(0.3),
                        blurRadius: 12, offset: const Offset(0, 4))]),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.refresh_rounded, color: AppColors.primaryDark, size: 18),
                  SizedBox(width: 8),
                  Text(tr('rental.clearFilters'), style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                ]),
              ),
            ),
          ])),
    ]);
  }

  Widget _placeholder(String? name) {
    return Container(
      width: double.infinity, height: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFFEEEEF2), Color(0xFFF5F5F8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
                    blurRadius: 10, offset: const Offset(0, 3))]),
            child: const Icon(Icons.directions_car_rounded, size: 22, color: AppColors.primaryGold)),
        if (name != null) ...[
          const SizedBox(height: 8),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(name.split(' ').first, style: TextStyle(fontSize: 9,
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
        ],
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER — own lifecycle, no parent controller dependency
// ─────────────────────────────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  const _Shimmer();
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<Color?> _color;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(milliseconds: 900), vsync: this)
      ..repeat(reverse: true);
    _color = ColorTween(
      begin: const Color(0xFFE8E8EC),
      end: const Color(0xFFF4F4F8),
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _color,
        builder: (_, __) => Container(color: _color.value));
  }
}
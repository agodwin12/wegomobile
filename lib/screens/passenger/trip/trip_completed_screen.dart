// lib/presentation/screens/trip/trip_completed_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../utils/app_colors.dart';

class TripCompletedScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> driver;
  final Map<String, dynamic> tripDetails;

  const TripCompletedScreen({
    super.key,
    required this.tripId,
    required this.driver,
    required this.tripDetails,
  });

  @override
  State<TripCompletedScreen> createState() => _TripCompletedScreenState();
}

class _TripCompletedScreenState extends State<TripCompletedScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _checkController;
  late AnimationController _celebrationController;
  late AnimationController _starController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _celebrationAnimation;

  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  late List<_Particle> _particles;
  static const int _particleCount = 22;

  @override
  void initState() {
    super.initState();
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🏁 [TRIP_COMPLETED] Screen initializing...');
    debugPrint('📦 Trip ID: ${widget.tripId}');
    debugPrint('👤 Driver: ${_getDriverName()}');
    debugPrint('💰 Fare: ${_getFareEstimate()} XAF');
    debugPrint('🖼️  Avatar URL: ${_driverAvatarUrl ?? "none"}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    _generateParticles();
    _setupAnimations();
  }

  void _generateParticles() {
    final rng = math.Random();
    _particles = List.generate(_particleCount, (_) => _Particle(rng));
  }

  void _setupAnimations() {
    _entryController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnimation = CurvedAnimation(
        parent: _entryController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _entryController, curve: Curves.easeOutCubic));

    _checkController = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _checkAnimation = CurvedAnimation(
        parent: _checkController, curve: Curves.easeOutCirc);

    _celebrationController = AnimationController(
        duration: const Duration(milliseconds: 1400), vsync: this);
    _celebrationAnimation = CurvedAnimation(
        parent: _celebrationController, curve: Curves.easeOut);

    _starController = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);

    _entryController.forward().then((_) {
      _checkController.forward().then((_) {
        _celebrationController.forward();
      });
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _checkController.dispose();
    _celebrationController.dispose();
    _starController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _submitRating() async {
    setState(() => _errorMessage = null);

    if (_selectedRating == 0) {
      _showErrorSnackBar('Please select a rating');
      return;
    }
    if (_commentController.text.length > 500) {
      _showErrorSnackBar('Comment must be 500 characters or less');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      debugPrint('⭐ [TRIP_COMPLETED] Submitting rating: $_selectedRating stars');

      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final success = await tripProvider.submitRating(
        tripId: widget.tripId,
        stars: _selectedRating,
        comment: _commentController.text.isNotEmpty
            ? _commentController.text
            : null,
      );

      if (!mounted) return;

      if (success) {
        _showSuccessDialog();
      } else {
        final msg = tripProvider.errorMessage ?? 'Failed to submit rating';
        setState(() => _errorMessage = msg);
        _showErrorSnackBar(msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'An unexpected error occurred');
        _showErrorSnackBar('An unexpected error occurred');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade500, size: 52),
            ),
            const SizedBox(height: 20),
            const Text('Thank you!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black)),
            const SizedBox(height: 8),
            Text('Your feedback has been saved.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade500)),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Done',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 4),
    ));
  }

  void _skipRating() =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  // ══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════

  String? _getField(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final k in keys) {
      final v = map[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }

  String _getDriverName() {
    final first = _getField(widget.driver, ['firstName', 'first_name']) ?? '';
    final last = _getField(widget.driver, ['lastName', 'last_name']) ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty
        ? full
        : (_getField(widget.driver, ['name']) ?? 'Driver');
  }

  /// Checks all possible avatar field names the backend might send
  String? get _driverAvatarUrl => _getField(widget.driver, [
    'avatar',
    'avatar_url',
    'photo',
    'picture',
    'profilePhoto',
    'profile_photo',
  ]);

  String _getDriverRating() =>
      _getField(widget.driver, ['rating', 'rating_avg', 'ratingAvg']) ?? '4.8';

  Map<String, String> get _vehicleInfo {
    final v = widget.driver['vehicle'] as Map<String, dynamic>?;
    return {
      'plate': _getField(v ?? widget.driver,
          ['plate', 'vehiclePlate', 'vehicle_plate']) ??
          'N/A',
      'makeModel': _getField(v ?? widget.driver, [
        'makeModel',
        'vehicle_make_model',
        'vehicleMakeModel',
      ]) ??
          'Vehicle',
      'color': _getField(
          v ?? widget.driver, ['color', 'vehicleColor', 'vehicle_color']) ??
          'Unknown',
      'year':
      _getField(v ?? widget.driver, ['year', 'vehicleYear', 'vehicle_year']) ??
          '',
    };
  }

  String _getPickupAddress() =>
      _getField(widget.tripDetails,
          ['pickup_address', 'pickupAddress', 'pickup']) ??
          'Pickup location';

  String _getDropoffAddress() =>
      _getField(widget.tripDetails,
          ['dropoff_address', 'dropoffAddress', 'dropoff']) ??
          'Dropoff location';

  int _getFareEstimate() {
    final fare = widget.tripDetails['fare_estimate'] ??
        widget.tripDetails['fareEstimate'] ??
        widget.tripDetails['final_fare'] ??
        widget.tripDetails['finalFare'] ??
        3500;
    if (fare is int) return fare;
    if (fare is double) return fare.toInt();
    if (fare is String) return int.tryParse(fare) ?? 3500;
    return 3500;
  }

  String _getDistanceKm() {
    final d = widget.tripDetails['distance_m'] ??
        widget.tripDetails['distanceM'] ??
        5000;
    int dist = 5000;
    if (d is int) dist = d;
    else if (d is double) dist = d.toInt();
    else if (d is String) dist = int.tryParse(d) ?? 5000;
    return (dist / 1000).toStringAsFixed(1);
  }

  // ══════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final driverName = _getDriverName();
    final rating = _getDriverRating();
    final vehicle = _vehicleInfo;
    final fare = _getFareEstimate();
    final dist = _getDistanceKm();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroHeader(
                  checkAnimation: _checkAnimation,
                  celebrationAnimation: _celebrationAnimation,
                  particles: _particles,
                  fare: fare,
                  dist: dist,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),
                    _RouteCard(
                      pickup: _getPickupAddress(),
                      dropoff: _getDropoffAddress(),
                    ),
                    const SizedBox(height: 16),

                    // ── Driver card with real avatar ─────────────────
                    _DriverCard(
                      name: driverName,
                      avatarUrl: _driverAvatarUrl,
                      rating: rating,
                      vehicle: vehicle,
                    ),
                    const SizedBox(height: 24),

                    Row(children: [
                      Expanded(child: Divider(color: Colors.grey.shade200)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Rate your trip',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w600)),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade200)),
                    ]),
                    const SizedBox(height: 24),

                    _RatingSection(
                      selectedRating: _selectedRating,
                      errorMessage: _errorMessage,
                      isSubmitting: _isSubmitting,
                      commentController: _commentController,
                      starController: _starController,
                      driverName: driverName,
                      onStarTap: (i) {
                        setState(() {
                          _selectedRating = i + 1;
                          _errorMessage = null;
                        });
                        _starController
                          ..reset()
                          ..forward();
                      },
                      onSubmit: _submitRating,
                      onSkip: _skipRating,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// DRIVER AVATAR — photo with fallback initial (reusable)
// ════════════════════════════════════════════════════════════════════════

class _DriverAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;
  final double radius;

  const _DriverAvatar({
    required this.name,
    this.avatarUrl,
    this.size = 56,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryGold,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.43,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
      ),
    );

    if (avatarUrl == null || avatarUrl!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// HERO HEADER
// ════════════════════════════════════════════════════════════════════════

class _HeroHeader extends StatelessWidget {
  final Animation<double> checkAnimation;
  final Animation<double> celebrationAnimation;
  final List<_Particle> particles;
  final int fare;
  final String dist;

  const _HeroHeader({
    required this.checkAnimation,
    required this.celebrationAnimation,
    required this.particles,
    required this.fare,
    required this.dist,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
          child: Column(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ...particles.map((p) => AnimatedBuilder(
                      animation: celebrationAnimation,
                      builder: (_, __) {
                        final t = celebrationAnimation.value;
                        final x = p.dx * t * 60;
                        final y = p.dy * t * 60 + 30 * t * t;
                        final opacity = (1.0 - t * 1.2).clamp(0.0, 1.0);
                        return Positioned(
                          left: 65 + x,
                          top: 65 + y,
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: p.size,
                              height: p.size,
                              decoration: BoxDecoration(
                                color: p.color,
                                shape: p.isCircle
                                    ? BoxShape.circle
                                    : BoxShape.rectangle,
                                borderRadius: p.isCircle
                                    ? null
                                    : BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        );
                      },
                    )),
                    AnimatedBuilder(
                      animation: checkAnimation,
                      builder: (_, __) => Transform.scale(
                        scale: checkAnimation.value,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryGold.withOpacity(0.35),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: checkAnimation,
                      builder: (_, __) => Transform.scale(
                        scale: checkAnimation.value,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryGold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.black, size: 52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Trip Complete',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3)),
              const SizedBox(height: 6),
              Text('Thanks for riding with WEGO',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _StatPill(
                      icon: Icons.payments_rounded,
                      label: 'Total fare',
                      value: '$fare XAF',
                      valueColor: AppColors.primaryGold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatPill(
                      icon: Icons.route_rounded,
                      label: 'Distance',
                      value: '$dist km',
                      valueColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border:
        Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: valueColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// ROUTE CARD
// ════════════════════════════════════════════════════════════════════════

class _RouteCard extends StatelessWidget {
  final String pickup;
  final String dropoff;

  const _RouteCard({required this.pickup, required this.dropoff});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: Color(0xFF22C55E), shape: BoxShape.circle)),
              Container(
                  width: 2,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF22C55E), Color(0xFFEF4444)],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  )),
              Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: Color(0xFFEF4444), shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AddrRow(label: 'Pickup', address: pickup),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Colors.grey.shade100),
                ),
                _AddrRow(label: 'Dropoff', address: dropoff),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddrRow extends StatelessWidget {
  final String label;
  final String address;

  const _AddrRow({required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        const SizedBox(height: 2),
        Text(
          address.length > 42 ? '${address.substring(0, 42)}…' : address,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// DRIVER CARD — with real photo
// ════════════════════════════════════════════════════════════════════════

class _DriverCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String rating;
  final Map<String, String> vehicle;

  const _DriverCard({
    required this.name,
    required this.avatarUrl,
    required this.rating,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // ── Real photo or gold initial fallback ─────────────
              _DriverAvatar(
                name: name,
                avatarUrl: avatarUrl,
                size: 56,
                radius: 14,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.primaryGold, size: 17),
                        const SizedBox(width: 4),
                        Text(rating,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        const SizedBox(width: 6),
                        Text('Your driver',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_car_rounded,
                    color: Colors.black54, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle['makeModel']!,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    Text(
                      vehicle['year']!.isNotEmpty
                          ? '${vehicle['color']} · ${vehicle['year']}'
                          : vehicle['color']!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vehicle['plate']!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: Colors.white,
                    fontFamily: 'Courier',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// RATING SECTION
// ════════════════════════════════════════════════════════════════════════

class _RatingSection extends StatelessWidget {
  final int selectedRating;
  final String? errorMessage;
  final bool isSubmitting;
  final TextEditingController commentController;
  final AnimationController starController;
  final String driverName;
  final ValueChanged<int> onStarTap;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;

  const _RatingSection({
    required this.selectedRating,
    required this.errorMessage,
    required this.isSubmitting,
    required this.commentController,
    required this.starController,
    required this.driverName,
    required this.onStarTap,
    required this.onSubmit,
    required this.onSkip,
  });

  String get _ratingLabel {
    switch (selectedRating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Great';
      case 5: return 'Excellent!';
      default: return 'Tap to rate';
    }
  }

  Color get _ratingColor {
    switch (selectedRating) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.blue;
      case 4: return Colors.green;
      case 5: return AppColors.primaryGold;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Text(
            'How was ${driverName.split(' ').first}?',
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black),
          ),
          const SizedBox(height: 6),
          Text('Your feedback helps improve the service',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          const SizedBox(height: 28),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < selectedRating;
              return GestureDetector(
                onTap: isSubmitting ? null : () => onStarTap(i),
                child: AnimatedScale(
                  scale: (filled && i == selectedRating - 1) ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      filled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 48,
                      color: filled
                          ? AppColors.primaryGold
                          : Colors.grey.shade200,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _ratingLabel,
              key: ValueKey(_ratingLabel),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _ratingColor),
            ),
          ),

          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade600, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(errorMessage!,
                        style: TextStyle(
                            color: Colors.red.shade600, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),

          // Comment box
          TextField(
            controller: commentController,
            enabled: !isSubmitting,
            maxLines: 3,
            maxLength: 500,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Leave a comment (optional)',
              hintStyle:
              TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: Colors.grey.shade50,
              counterText: '',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                const BorderSide(color: AppColors.primaryGold, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Submit
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: isSubmitting
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white)),
              )
                  : const Text('Submit Rating',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),

          // Skip
          TextButton(
            onPressed: isSubmitting ? null : onSkip,
            child: Text('Skip',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade400)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// CONFETTI PARTICLE
// ════════════════════════════════════════════════════════════════════════

class _Particle {
  final double dx;
  final double dy;
  final double size;
  final Color color;
  final bool isCircle;

  _Particle(math.Random rng)
      : dx = (rng.nextDouble() - 0.5) * 2.0,
        dy = -(rng.nextDouble() * 1.5 + 0.5),
        size = rng.nextDouble() * 6 + 4,
        isCircle = rng.nextBool(),
        color = const [
          AppColors.primaryGold,
          Colors.white,
          Color(0xFFFFEA80),
          Color(0xFFFFF3B0),
          Colors.white70,
        ][rng.nextInt(5)];
}
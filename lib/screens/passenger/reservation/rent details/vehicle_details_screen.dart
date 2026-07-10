import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wego_v1/screens/passenger/reservation/rent%20details/rental_payment_waiting_screen.dart';
import 'dart:convert';
import '../../../../service/rental_api_service.dart';
import '../../../../utils/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VEHICLE DETAILS SCREEN
// Aesthetic: Editorial luxury — dark hero image, generous white space,
// gold accents, layered depth. Every section feels like a magazine spread.
// ─────────────────────────────────────────────────────────────────────────────

class VehicleDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  final Map<String, dynamic> user;
  final String accessToken;

  const VehicleDetailsScreen({
    super.key,
    required this.vehicle,
    required this.user,
    required this.accessToken,
  });

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen>
    with TickerProviderStateMixin {

  // ── State ──────────────────────────────────────────────────────────────────
  int _selectedImageIndex = 0;
  String _selectedRentalType = 'DAY';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  String? _selectedPaymentMethod;
  final TextEditingController _rentalPhoneController = TextEditingController();
  bool _isFavorite = false;

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  late PageController _pageController;

  final Map<String, String> _rentalTypes = {
    'HOUR': 'Hourly',
    'DAY': 'Daily',
    'WEEK': 'Weekly',
    'MONTH': 'Monthly',
  };

  // ── Price key mapping ──────────────────────────────────────────────────────
  String _priceKey(String type) {
    switch (type) {
      case 'HOUR':  return 'rentalPricePerHour';
      case 'DAY':   return 'rentalPricePerDay';
      case 'WEEK':  return 'rentalPricePerWeek';
      case 'MONTH': return 'rentalPricePerMonth';
      default:      return 'rentalPricePerDay';
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Prefill the Mobile Money number with the account phone (editable — the
    // payer may want to charge a different MTN/Orange number than the one on file).
    _rentalPhoneController.text =
        (widget.user['phone_e164'] as String? ?? '').replaceAll('+', '').replaceAll('237', '');

    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    _rentalPhoneController.dispose();
    super.dispose();
  }

  // ── Computed ───────────────────────────────────────────────────────────────

  List<dynamic> get _images {
    final raw = widget.vehicle['images'];
    if (raw == null) return [];
    if (raw is String) {
      try {
        final d = json.decode(raw);
        if (d is List) return d;
      } catch (_) {}
      return [];
    }
    if (raw is List) return raw;
    return [];
  }

  String get _vehicleId =>
      widget.vehicle['uuid']?.toString() ??
          widget.vehicle['id']?.toString() ??
          '';

  double get _totalPrice {
    final key = _priceKey(_selectedRentalType);
    final unitPrice =
        double.tryParse(widget.vehicle[key]?.toString() ?? '0') ?? 0;

    switch (_selectedRentalType) {
      case 'HOUR':
        final h = _endDate.difference(_startDate).inHours;
        return (h < 1 ? 1 : h) * unitPrice;
      case 'DAY':
        final d = _endDate.difference(_startDate).inDays;
        return (d < 1 ? 1 : d) * unitPrice;
      case 'WEEK':
        final w = (_endDate.difference(_startDate).inDays / 7).ceil();
        return (w < 1 ? 1 : w) * unitPrice;
      case 'MONTH':
        final m = (_endDate.difference(_startDate).inDays / 30).ceil();
        return (m < 1 ? 1 : m) * unitPrice;
      default:
        return 0;
    }
  }

  int get _durationDays => _endDate.difference(_startDate).inDays < 1
      ? 1
      : _endDate.difference(_startDate).inDays;

  bool _hasPrice(String type) {
    final v = widget.vehicle[_priceKey(type)];
    if (v == null) return false;
    return (double.tryParse(v.toString()) ?? 0) > 0;
  }

  // ── Date Picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart ? _startDate : _endDate;
    final first = isStart ? now : _startDate.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primaryGold,
            onPrimary: AppColors.primaryDark,
            surface: AppColors.backgroundWhite,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate.add(const Duration(days: 1)))) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // ── Booking flow ───────────────────────────────────────────────────────────

  Future<void> _confirmBooking() async {
    if (_selectedPaymentMethod == null) {
      _snackError('Please select a payment method');
      return;
    }

    HapticFeedback.mediumImpact();
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    _showLoading('Creating your rental...');

    final rentalResp = await RentalApiService.createRental(
      accessToken: widget.accessToken,
      userId: widget.user['uuid'],
      vehicleId: _vehicleId,
      rentalRegion: widget.vehicle['region'] ?? 'Douala',
      rentalType: _selectedRentalType,
      startDate: _startDate,
      endDate: _endDate,
      userNotes: '',
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    debugPrint('🔍 RENTAL RESPONSE: $rentalResp');

    if (rentalResp['success'] != true) {
      _showErrorDialog(
        title: 'Booking Failed',
        message: rentalResp['error'] ?? 'Unable to process your booking',
      );
      return;
    }

    final rentalId =
    rentalResp['data']?['rental']?['id'] as String?;

    // Cash — done
    if (_selectedPaymentMethod == 'CASH') {
      _showSuccessDialog(
        title: 'Request Submitted!',
        message:
        'Your rental request is pending approval. Our team will contact you shortly to confirm and arrange cash payment on pickup.',
        onClose: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      );
      return;
    }

    // MoMo
    if (rentalId == null) {
      _showErrorDialog(
          title: 'Unexpected Error',
          message:
          'Rental was created but ID was not returned. Please contact support.');
      return;
    }

    // Mobile-money number to charge — the number that receives the PIN prompt and
    // which decides MTN vs Orange (CamPay detects the operator from the number).
    final phone = _rentalPhoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length < 9) {
      _showErrorDialog(
          title: 'Mobile Money Number Required',
          message:
          'Enter the MTN or Orange number that will receive the payment prompt.');
      return;
    }

    _showLoading('Initiating payment...');

    final payResp = await RentalApiService.initiatePayment(
      accessToken: widget.accessToken,
      rentalId: rentalId,
      phone: phone,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (payResp['success'] != true) {
      _showErrorDialog(
          title: 'Payment Failed',
          message:
          payResp['error'] ?? 'Could not initiate payment. Please try again.');
      return;
    }

    final campayRef =
        payResp['data']?['campayRef'] as String? ?? '';
    final paymentId =
        payResp['data']?['paymentId'] as String? ?? '';
    final operator =
        payResp['data']?['operator'] as String? ?? _selectedPaymentMethod!;

    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => RentalPaymentWaitingScreen(
          campayRef: campayRef,
          paymentId: paymentId,
          totalPrice: _totalPrice,
          vehicleName: widget.vehicle['makeModel'] ?? 'Vehicle',
          accessToken: widget.accessToken,
          operator: operator,
          user: widget.user,
        ),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: a.drive(Tween(
              begin: const Offset(0.0, 1.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showLoading(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                  color: AppColors.primaryGold, strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            Text(msg,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: AppColors.backgroundWhite,
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: AppColors.primaryDark, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Booking Summary',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    Text('Review before confirming',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ]),

              const SizedBox(height: 22),
              Divider(color: AppColors.borderLight, height: 1),
              const SizedBox(height: 18),

              _confirmRow(Icons.directions_car_rounded, 'Vehicle',
                  widget.vehicle['makeModel'] ?? 'N/A'),
              _confirmRow(Icons.calendar_today_rounded, 'Start',
                  DateFormat('EEE, MMM dd yyyy').format(_startDate)),
              _confirmRow(Icons.event_rounded, 'End',
                  DateFormat('EEE, MMM dd yyyy').format(_endDate)),
              _confirmRow(Icons.access_time_rounded, 'Duration',
                  '$_durationDays ${_durationDays == 1 ? 'day' : 'days'}'),
              _confirmRow(Icons.payments_rounded, 'Payment',
                  _paymentLabel(_selectedPaymentMethod)),

              const SizedBox(height: 16),

              // Total
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark)),
                    Text(
                      'XAF ${_totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.textLight),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                        'Subject to admin approval before confirmation.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      )),
                ]),
              ),

              const SizedBox(height: 22),

              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                          color: AppColors.borderLight, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Confirm Booking',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ) ??
        false;
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Text('$label  ',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  void _showSuccessDialog(
      {required String title,
        required String message,
        required VoidCallback onClose}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: AppColors.backgroundWhite,
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                  color: Color(0xFFE8F9F0), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 44),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(message,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Great!',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showErrorDialog({required String title, required String message, String? details}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: AppColors.backgroundWhite,
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.errorLight, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 44),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(message,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6),
                textAlign: TextAlign.center),
            if (details != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.errorLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(details,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.error,
                        fontFamily: 'monospace')),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Close',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _snackError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  String _paymentLabel(String? method) {
    switch (method) {
      case 'CASH':         return 'Cash on Pickup';
      case 'ORANGE_MONEY': return 'Orange Money';
      case 'MTN_MOMO':     return 'MTN Mobile Money';
      default:             return 'Not selected';
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildHero(),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVehicleHeader(),
                        _buildSpecsRow(),
                        _buildRentalTypeSelector(),
                        _buildDatePeriod(),
                        _buildPaymentSection(),
                        _buildPriceCard(),
                        const SizedBox(height: 110),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          _buildFloatingBar(),
        ],
      ),
    );
  }

  // ── HERO ───────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    final images = _images;
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF1A1A2E),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _circleButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: _circleButton(
            icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
            iconColor:
            _isFavorite ? AppColors.error : AppColors.primaryDark,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _isFavorite = !_isFavorite);
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Main image / PageView
            images.isNotEmpty
                ? PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (i) =>
                  setState(() => _selectedImageIndex = i),
              itemBuilder: (_, i) => Image.network(
                images[i],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _heroPlaceholder(),
              ),
            )
                : _heroPlaceholder(),

            // Bottom gradient
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF1A1A2E).withOpacity(0.7),
                      const Color(0xFF1A1A2E),
                    ],
                  ),
                ),
              ),
            ),

            // Image dots + availability chip
            Positioned(
              bottom: 16,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dot indicators
                  if (images.length > 1)
                    Row(
                      children: List.generate(
                        images.length,
                            (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 5),
                          width: _selectedImageIndex == i ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _selectedImageIndex == i
                                ? AppColors.primaryGold
                                : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(),

                  // Available badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D084).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF00D084).withOpacity(0.5),
                          width: 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: Color(0xFF00D084),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      const Text('Available',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00D084))),
                    ]),
                  ),
                ],
              ),
            ),

            // Thumbnail strip
            if (images.length > 1)
              Positioned(
                bottom: 48,
                left: 20,
                child: SizedBox(
                  height: 54,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    itemCount: images.length,
                    itemBuilder: (_, i) {
                      final sel = i == _selectedImageIndex;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(i,
                              duration:
                              const Duration(milliseconds: 300),
                              curve: Curves.easeInOut);
                          setState(() => _selectedImageIndex = i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 54,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel
                                  ? AppColors.primaryGold
                                  : Colors.white.withOpacity(0.3),
                              width: sel ? 2.5 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(images[i],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(
                                        color: Colors.white12,
                                        child: const Icon(
                                            Icons.image,
                                            color: Colors.white38,
                                            size: 18))),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _heroPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.directions_car_rounded,
            size: 80, color: AppColors.primaryGold.withOpacity(0.4)),
        const SizedBox(height: 12),
        Text(
          widget.vehicle['makeModel'] ?? 'Vehicle',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.6)),
        ),
      ]),
    );
  }

  Widget _circleButton(
      {required IconData icon,
        required VoidCallback onTap,
        Color? iconColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon,
            color: iconColor ?? AppColors.primaryDark, size: 18),
      ),
    );
  }

  // ── VEHICLE HEADER ─────────────────────────────────────────────────────────

  Widget _buildVehicleHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.vehicle['makeModel'] ?? 'Unknown Vehicle',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0D0D1A),
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Price badge
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                'XAF ${_formatPrice(widget.vehicle['rentalPricePerDay'])}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryGold,
                  letterSpacing: -0.5,
                ),
              ),
              Text('/day',
                  style:
                  TextStyle(fontSize: 11, color: AppColors.textLight)),
            ]),
          ],
        ),

        const SizedBox(height: 12),

        // Location + rating row
        Row(children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              borderRadius: BorderRadius.circular(20),
              border:
              Border.all(color: AppColors.borderLight, width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on_rounded,
                  size: 13, color: AppColors.primaryGold),
              const SizedBox(width: 4),
              Text(
                widget.vehicle['region'] ?? 'Douala',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              borderRadius: BorderRadius.circular(20),
              border:
              Border.all(color: AppColors.borderLight, width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star_rounded,
                  size: 13, color: AppColors.primaryGold),
              SizedBox(width: 4),
              Text('4.8',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text(' · 124 reviews',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ── SPECS ROW ──────────────────────────────────────────────────────────────

  Widget _buildSpecsRow() {
    final specs = [
      {
        'icon': Icons.airline_seat_recline_normal_rounded,
        'label': 'Seats',
        'value': '${widget.vehicle['seats'] ?? 4}'
      },
      {
        'icon': Icons.palette_rounded,
        'label': 'Color',
        'value': widget.vehicle['color'] ?? 'N/A'
      },
      {
        'icon': Icons.pin_rounded,
        'label': 'Plate',
        'value': widget.vehicle['plate'] ?? 'N/A'
      },
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: specs.asMap().entries.map((e) {
          final s = e.value;
          return Expanded(
            child: Column(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(s['icon'] as IconData,
                    color: AppColors.primaryGold, size: 22),
              ),
              const SizedBox(height: 8),
              Text(s['label'] as String,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textLight)),
              const SizedBox(height: 2),
              Text(s['value'] as String,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── RENTAL TYPE SELECTOR ───────────────────────────────────────────────────

  Widget _buildRentalTypeSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Rental Duration'),
        const SizedBox(height: 12),
        Row(
          children: _rentalTypes.entries.map((e) {
            final available = _hasPrice(e.key);
            if (!available) return const SizedBox.shrink();
            final sel = _selectedRentalType == e.key;
            final unitPrice = double.tryParse(
                widget.vehicle[_priceKey(e.key)]?.toString() ??
                    '0') ??
                0;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedRentalType = e.key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: sel ? AppColors.primaryGradient : null,
                    color: sel ? null : AppColors.backgroundWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel
                          ? Colors.transparent
                          : AppColors.borderLight,
                      width: 1.5,
                    ),
                    boxShadow: sel
                        ? [
                      BoxShadow(
                          color: AppColors.primaryGold
                              .withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ]
                        : null,
                  ),
                  child: Column(children: [
                    Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? AppColors.primaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatPrice(unitPrice),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sel
                            ? AppColors.primaryDark.withOpacity(0.7)
                            : AppColors.textLight,
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ── DATE PERIOD ────────────────────────────────────────────────────────────

  Widget _buildDatePeriod() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Rental Period'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(20),
            border:
            Border.all(color: AppColors.borderLight, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(children: [
            Expanded(child: _dateTile('Pick-up', _startDate, true)),
            Container(
              width: 1,
              height: 44,
              color: AppColors.borderLight,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Expanded(child: _dateTile('Drop-off', _endDate, false)),
            // Duration bubble
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Text(
                  '$_durationDays',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark),
                ),
                Text(
                  _durationDays == 1 ? 'day' : 'days',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _dateTile(String label, DateTime date, bool isStart) {
    return GestureDetector(
      onTap: () => _pickDate(isStart),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          DateFormat('MMM dd').format(date),
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        Text(
          DateFormat('yyyy · EEE').format(date),
          style: TextStyle(
              fontSize: 11, color: AppColors.textSecondary),
        ),
      ]),
    );
  }

  // ── PAYMENT SECTION ────────────────────────────────────────────────────────

  Widget _buildPaymentSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Payment Method'),
        const SizedBox(height: 12),
        _paymentOption(
          value: 'MTN_MOMO',
          title: 'MTN Mobile Money',
          subtitle: 'Instant mobile payment',
          icon: Icons.phone_android_rounded,
          accent: const Color(0xFFFFCC00),
          imagePath: 'assets/images/momo.png',
        ),
        const SizedBox(height: 10),
        _paymentOption(
          value: 'ORANGE_MONEY',
          title: 'Orange Money',
          subtitle: 'Instant mobile payment',
          icon: Icons.phone_android_rounded,
          accent: const Color(0xFFFF6600),
          imagePath: 'assets/images/om.png',
        ),
        const SizedBox(height: 10),
        _paymentOption(
          value: 'CASH',
          title: 'Cash on Pickup',
          subtitle: 'Pay when you collect the car',
          icon: Icons.payments_rounded,
          accent: const Color(0xFF6B7280),
          imagePath: null,
        ),

        // Mobile Money number entry — shown for MTN/Orange. This is the number
        // the CamPay PIN prompt is sent to; the operator (MTN vs Orange) is
        // detected automatically from the number, so the selection above is only
        // a hint. Prefilled from the account but editable.
        if (_selectedPaymentMethod == 'MTN_MOMO' ||
            _selectedPaymentMethod == 'ORANGE_MONEY') ...[
          const SizedBox(height: 16),
          _sectionLabel('Mobile Money Number'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              const Text('+237',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D0D1A))),
              Container(
                width: 1,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: AppColors.borderLight,
              ),
              Expanded(
                child: TextField(
                  controller: _rentalPhoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: '6XX XXX XXX',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(
            'The payment prompt is sent to this number. MTN or Orange is detected automatically.',
            style: TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
        ],
      ]),
    );
  }

  Widget _paymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required String? imagePath,
  }) {
    final sel = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPaymentMethod = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? accent.withOpacity(0.07) : AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sel ? accent.withOpacity(0.6) : AppColors.borderLight,
            width: sel ? 2 : 1.5,
          ),
          boxShadow: sel
              ? [
            BoxShadow(
                color: accent.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ]
              : null,
        ),
        child: Row(children: [
          // Icon / logo
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: sel ? accent.withOpacity(0.15) : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: imagePath != null
                ? Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Icon(icon, color: accent, size: 22)),
            )
                : Icon(icon, color: sel ? accent : AppColors.textSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          // Labels
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: sel
                              ? const Color(0xFF0D0D1A)
                              : AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textLight)),
                ]),
          ),
          // Check
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? accent : Colors.transparent,
              border: Border.all(
                  color: sel ? accent : AppColors.borderMedium, width: 2),
            ),
            child: sel
                ? Icon(Icons.check_rounded,
                size: 13,
                color: value == 'MTN_MOMO'
                    ? AppColors.primaryDark
                    : Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }

  // ── PRICE CARD ─────────────────────────────────────────────────────────────

  Widget _buildPriceCard() {
    final unitPrice = double.tryParse(
        widget.vehicle[_priceKey(_selectedRentalType)]?.toString() ??
            '0') ??
        0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0D0D1A).withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Stack(children: [
        // Subtle gold arc decoration
        Positioned(
          top: -30,
          right: -30,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.primaryGold.withOpacity(0.08),
                  width: 30),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            // Header
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Price Breakdown',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primaryGold.withOpacity(0.3),
                          width: 1),
                    ),
                    child: Text(
                      _rentalTypes[_selectedRentalType] ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGold),
                    ),
                  ),
                ]),

            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),

            // Rows
            _priceRow('Unit Price',
                'XAF ${_formatPrice(unitPrice)} / ${_rentalTypes[_selectedRentalType]?.toLowerCase()}'),
            const SizedBox(height: 10),
            _priceRow('Duration', '$_durationDays ${_durationDays == 1 ? "day" : "days"}'),

            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),

            // Total
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text(
                    'XAF ${_totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryGold,
                      letterSpacing: -1,
                    ),
                  ),
                ]),
          ]),
        ),
      ]),
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.5))),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ]);
  }

  // ── FLOATING BOTTOM BAR ────────────────────────────────────────────────────

  Widget _buildFloatingBar() {
    final hasMethod = _selectedPaymentMethod != null;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 24,
                offset: const Offset(0, -6))
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              // Price preview
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'XAF ${_totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryGold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '$_durationDays ${_durationDays == 1 ? "day" : "days"} · ${_rentalTypes[_selectedRentalType]}',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textLight),
                ),
              ]),

              const SizedBox(width: 16),

              // CTA button
              Expanded(
                child: GestureDetector(
                  onTap: hasMethod ? _confirmBooking : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: hasMethod
                          ? AppColors.primaryGradient
                          : null,
                      color: hasMethod
                          ? null
                          : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: hasMethod
                          ? [
                        BoxShadow(
                            color: AppColors.primaryGold
                                .withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4))
                      ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        hasMethod
                            ? 'Book Now'
                            : 'Select Payment Method',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: hasMethod
                              ? AppColors.primaryDark
                              : AppColors.textLight,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Row(children: [
      Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          )),
      const SizedBox(width: 8),
      Text(text,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D0D1A),
              letterSpacing: -0.3)),
    ]);
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    try {
      return double.parse(price.toString()).toStringAsFixed(0);
    } catch (_) {
      return price.toString();
    }
  }
}
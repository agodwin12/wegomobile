// lib/presentation/screens/passenger/delivery/steps/delivery_step3_confirm.dart
//
// STEP 3 — Recipient · Payment · Fare Estimate · Book
// Fetches live estimate on mount. Submits to POST /api/deliveries/book.

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../l10n/tr.dart';
import 'package:http/http.dart' as http;
import '../../../../../utils/app_colors.dart';
import '../../../../../utils/app_typography.dart';
import '../../../../../core/config.dart';
import '../../../../../widgets/phone/country_code_field.dart';
import '../driver searching/delivery_searching_screen.dart';

class _Estimate {
  final double totalPrice;
  final double expressSurcharge;
  final double distanceKm;
  final String? distanceText;
  final String? durationText;
  final bool   surgeActive;
  final String? surgeRuleName;
  final double surgeMultiplier;

  _Estimate({
    required this.totalPrice,
    required this.expressSurcharge,
    required this.distanceKm,
    this.distanceText,
    this.durationText,
    required this.surgeActive,
    this.surgeRuleName,
    required this.surgeMultiplier,
  });

  factory _Estimate.fromJson(Map<String, dynamic> j) => _Estimate(
    totalPrice:       (j['totalPrice']       as num).toDouble(),
    expressSurcharge: (j['expressSurcharge']  as num? ?? 0).toDouble(),
    distanceKm:       (j['distanceKm']        as num).toDouble(),
    distanceText:     j['distanceText'],
    durationText:     j['durationText'],
    surgeActive:      j['surgeActive']        ?? false,
    surgeRuleName:    j['surgeRuleName'],
    surgeMultiplier:  (j['surgeMultiplier']   as num? ?? 1.0).toDouble(),
  );
}

class DeliveryStep3Confirm extends StatefulWidget {
  // From Step 1
  final String deliveryType;
  final String accessToken;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final String pickupLandmark;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final String dropoffLandmark;
  // From Step 2
  final String packageSize;
  final String packageCategory;
  final String packagePhotoUrl;
  final bool   isFragile;
  final String description;

  const DeliveryStep3Confirm({
    super.key,
    required this.deliveryType,
    required this.accessToken,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.pickupLandmark,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    required this.dropoffLandmark,
    required this.packageSize,
    required this.packageCategory,
    required this.packagePhotoUrl,
    required this.isFragile,
    required this.description,
  });

  @override
  State<DeliveryStep3Confirm> createState() => _DeliveryStep3ConfirmState();
}

class _DeliveryStep3ConfirmState extends State<DeliveryStep3Confirm>
    with SingleTickerProviderStateMixin {

  // ── Recipient ────────────────────────────────────────────────────────────────
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();      // LOCAL part only
  final _noteCtrl  = TextEditingController();
  // Country dial code prepended to the recipient number so the SMS PIN is sent
  // in international format (Techsoft can't deliver a bare local number).
  DialingCountry _recipientCountry = kFrancophoneAfricaCountries.first; // Cameroun

  // ── Coupon ────────────────────────────────────────────────────────────────────
  final _couponCtrl   = TextEditingController();
  bool    _applyingCoupon = false;
  bool    _couponValid    = false;
  double  _couponDiscount = 0;
  String? _couponMessage;

  // ── Payment ───────────────────────────────────────────────────────────────────
  String _paymentMethod = 'mtn_mobile_money';

  // ── Estimate ──────────────────────────────────────────────────────────────────
  _Estimate? _estimate;
  bool       _estimating   = true;
  String?    _estimateError;

  // ── Booking ───────────────────────────────────────────────────────────────────
  bool    _booking     = false;
  String? _bookingError;

  // ── Animation ─────────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  bool get _isExpress => widget.deliveryType == 'express';
  bool get _canBook   =>
      _nameCtrl.text.trim().isNotEmpty &&
          _phoneCtrl.text.trim().isNotEmpty &&
          _estimate != null &&
          !_booking;

  static const _categoryEmoji = {
    'document': '📄', 'food': '🍱', 'electronics': '📱',
    'clothing': '👕', 'medicine': '💊', 'fragile': '🏺',
    'groceries': '🛒', 'other': '📦',
  };

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _fetchEstimate();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    _couponCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _fetchEstimate() async {
    setState(() { _estimating = true; _estimateError = null; });
    try {
      final params = {
        'pickup_lat':    widget.pickupLat.toString(),
        'pickup_lng':    widget.pickupLng.toString(),
        'dropoff_lat':   widget.dropoffLat.toString(),
        'dropoff_lng':   widget.dropoffLng.toString(),
        'package_size':  widget.packageSize,
        'delivery_type': widget.deliveryType,
      };
      final couponCode = _couponCtrl.text.trim();
      if (couponCode.isNotEmpty) params['coupon_code'] = couponCode;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/deliveries/estimate')
          .replace(queryParameters: params);

      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final est  = data['estimate'] as Map<String, dynamic>;
        // Read the optional coupon preview the backend attaches.
        final coupon = est['coupon'] as Map<String, dynamic>?;
        if (mounted) setState(() {
          _estimate  = _Estimate.fromJson(est);
          if (coupon != null) {
            _couponValid    = coupon['valid'] == true;
            _couponDiscount = (coupon['discount'] as num?)?.toDouble() ?? 0;
            _couponMessage  = coupon['message'] as String?;
          } else {
            _couponValid = false; _couponDiscount = 0; _couponMessage = null;
          }
          _estimating = false;
        });
        return;
      }
      final err = jsonDecode(res.body)['message'] ?? 'Could not calculate fare';
      if (mounted) setState(() { _estimateError = err; _estimating = false; });
    } catch (_) {
      if (mounted) setState(() {
        _estimateError = 'Network error. Pull to retry.';
        _estimating    = false;
      });
    }
  }

  // Re-run the estimate with the entered coupon so the backend validates it and
  // returns the discount preview. Keeps one source of truth (the server).
  Future<void> _applyCoupon() async {
    if (_couponCtrl.text.trim().isEmpty) return;
    setState(() => _applyingCoupon = true);
    await _fetchEstimate();
    if (mounted) setState(() => _applyingCoupon = false);
  }

  Future<void> _book() async {
    if (!_canBook) return;

    setState(() { _booking = true; _bookingError = null; });

    try {
      final body = <String, dynamic>{
        'delivery_type':     widget.deliveryType,
        'pickup_address':    widget.pickupAddress,
        'pickup_latitude':   widget.pickupLat,
        'pickup_longitude':  widget.pickupLng,
        'dropoff_address':   widget.dropoffAddress,
        'dropoff_latitude':  widget.dropoffLat,
        'dropoff_longitude': widget.dropoffLng,
        'recipient_name':    _nameCtrl.text.trim(),
        // Full international number (e.g. 237690000000) so the PIN SMS is
        // actually delivered — the backend/SMS provider adds no country code.
        'recipient_phone':   buildInternationalNumber(
            _recipientCountry, _phoneCtrl.text),
        'package_size':      widget.packageSize,
        'package_category':  widget.packageCategory,
        'package_photo_url': widget.packagePhotoUrl,
        'is_fragile':        widget.isFragile,
        'payment_method':    _paymentMethod,
      };
      if (widget.pickupLandmark.isNotEmpty)
        body['pickup_landmark']  = widget.pickupLandmark;
      if (widget.dropoffLandmark.isNotEmpty)
        body['dropoff_landmark'] = widget.dropoffLandmark;
      if (widget.description.isNotEmpty)
        body['package_description'] = widget.description;
      if (_noteCtrl.text.trim().isNotEmpty)
        body['recipient_note']   = _noteCtrl.text.trim();
      if (_couponValid && _couponCtrl.text.trim().isNotEmpty)
        body['coupon_code']      = _couponCtrl.text.trim();

      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/book'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type':  'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(res.body);

      if (res.statusCode == 201 && data['success'] == true) {
        final delivery = data['delivery'] as Map<String, dynamic>;
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => DeliverySearchingScreen(
              delivery: delivery,
              accessToken: widget.accessToken,
            ),
          ),
              (r) => r.isFirst,
        );
        return;  // nothing else — no dialog
      }

      final msg = data['message'] ?? 'Booking failed. Please try again.';
      if (mounted) setState(() { _bookingError = msg; _booking = false; });
      _showError(msg);

    } catch (e) {
      if (mounted) setState(() { _booking = false; });
      _showError('Network error. Check your connection.');
    }
  }

  void _showBookingSuccess(Map<String, dynamic> delivery) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: AppColors.successLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 32),
            ),
            const SizedBox(height: 16),
            Text(tr('delivery.booked'),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Code: ${delivery['deliveryCode']}',
                style: TextStyle(fontFamily: 'Roboto', fontSize: 14,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(tr('ride.searchingDriver'),
                style: TextStyle(fontFamily: 'Roboto', fontSize: 13,
                    color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(tr('delivery.track'),
                  style: TextStyle(fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fade,
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryGold,
                onRefresh: _fetchEstimate,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildFareCard(),
                      const SizedBox(height: 16),
                      _buildRecipientCard(),
                      const SizedBox(height: 16),
                      _buildCouponCard(),
                      const SizedBox(height: 16),
                      _buildPaymentCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            _buildBookBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _isExpress ? AppColors.primaryDark : Colors.white,
      foregroundColor: _isExpress ? Colors.white : AppColors.textPrimary,
      elevation: 0,
      title: Text(
        _isExpress ? '⚡ Express Delivery' : '📦 Regular Delivery',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _isExpress ? Colors.white : AppColors.textPrimary),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: List.generate(3, (i) {
          final step   = i + 1;
          final done   = step < 3;
          final active = step == 3;
          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.success
                        : active ? AppColors.primaryDark : AppColors.borderLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check_rounded, size: 14,
                        color: Colors.white)
                        : Text('$step',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : AppColors.textLight)),
                  ),
                ),
                const SizedBox(width: 6),
                Text(['Location', 'Package', 'Confirm'][i],
                    style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? AppColors.textPrimary : AppColors.textLight)),
                if (i < 2) ...[
                  const SizedBox(width: 6),
                  Expanded(child: Container(
                      height: 1,
                      color: done ? AppColors.success : AppColors.borderLight)),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Summary card ───────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    final emoji = _categoryEmoji[widget.packageCategory] ?? '📦';
    return _card(
      child: Column(
        children: [
          // Route row
          Row(
            children: [
              Expanded(child: _locationPin(
                icon: Icons.my_location_rounded,
                color: AppColors.primaryDark,
                address: widget.pickupAddress,
                label: tr('ride.pickup'),
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: List.generate(3, (_) => Container(
                    width: 2, height: 6,
                    margin: const EdgeInsets.only(bottom: 3),
                    color: AppColors.borderMedium,
                  )),
                ),
              ),
              Expanded(child: _locationPin(
                icon: Icons.flag_rounded,
                color: _isExpress ? AppColors.primaryGold : AppColors.success,
                address: widget.dropoffAddress,
                label: tr('driver.dropoff'),
              )),
            ],
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 14),

          // Package row
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${widget.packageCategory[0].toUpperCase()}'
                            '${widget.packageCategory.substring(1)} · '
                            '${widget.packageSize[0].toUpperCase()}'
                            '${widget.packageSize.substring(1)}',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    if (widget.isFragile)
                      Text('🏺 Fragile',
                          style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500)),
                    if (widget.description.isNotEmpty)
                      Text(widget.description,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
                              color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (_isExpress)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(tr('delivery.expressBadge'),
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationPin({
    required IconData icon,
    required Color color,
    required String address,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontFamily: 'Roboto', fontSize: 10,
                  fontWeight: FontWeight.w600, color: color)),
        ]),
        const SizedBox(height: 4),
        Text(address,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Roboto', fontSize: 12,
                color: AppColors.textPrimary)),
      ],
    );
  }

  // ── Fare card ──────────────────────────────────────────────────────────────

  Widget _buildFareCard() {
    if (_estimating) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryDark)),
            const SizedBox(width: 12),
            Text(tr('delivery.calculatingFare'),
                style: TextStyle(fontFamily: 'Roboto', fontSize: 13,
                    color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_estimateError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(_estimateError!,
                style: const TextStyle(fontSize: 12, color: AppColors.error))),
            TextButton(
              onPressed: _fetchEstimate,
              child: Text(tr('common.retry'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.error)),
            ),
          ],
        ),
      );
    }

    final e = _estimate!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          // Price hero
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.totalPrice.toStringAsFixed(0)} XAF',
                        style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGold,
                          letterSpacing: -1,
                        )),
                    Text(tr('delivery.totalFare'),
                        style: TextStyle(fontFamily: 'Roboto', fontSize: 12,
                            color: Colors.white.withOpacity(0.5))),
                  ],
                ),
                const Spacer(),
                if (e.surgeActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      const Icon(Icons.bolt_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 3),
                      Text('Surge ×${e.surgeMultiplier.toStringAsFixed(1)}',
                          style: const TextStyle(fontFamily: 'Roboto', fontSize: 11,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(height: 1, color: Colors.white.withOpacity(0.08)),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(children: [
              _eRow('Distance',
                  e.distanceText ?? '${e.distanceKm.toStringAsFixed(1)} km'),
              if (e.durationText != null)
                _eRow('Est. duration', e.durationText!),
              if (_isExpress && e.expressSurcharge > 0)
                _eRow('Express surcharge',
                    '+${e.expressSurcharge.toStringAsFixed(0)} XAF',
                    highlight: true),
              if (e.surgeActive && e.surgeRuleName != null)
                _eRow('Surge rule', e.surgeRuleName!),
              _eRow('Tracking mode',
                  _isExpress ? '🗺 Live map' : '📋 Stage updates'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _eRow(String label, String value, {bool highlight = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontFamily: 'Roboto', fontSize: 12,
                    color: Colors.white.withOpacity(0.5))),
            Text(value,
                style: TextStyle(fontFamily: 'Roboto', fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: highlight ? AppColors.primaryGold : Colors.white)),
          ],
        ),
      );

  // ── Recipient card ─────────────────────────────────────────────────────────

  Widget _buildRecipientCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('delivery.recipientDetails'),
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _input(_nameCtrl,  'Full name *',
              icon: Icons.person_outline_rounded),
          const SizedBox(height: 10),
          CountryCodePhoneField(
            controller: _phoneCtrl,
            country: _recipientCountry,
            hint: 'Phone number *',
            onCountryChanged: (c) => setState(() => _recipientCountry = c),
            onChanged: () => setState(() {}), // refresh _canBook
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Select the recipient\'s country, then enter the number '
              'without the country code.',
              style: TextStyle(
                  fontFamily: 'Roboto', fontSize: 11,
                  color: AppColors.textLight),
            ),
          ),
          const SizedBox(height: 10),
          _input(_noteCtrl,  'Note (optional)',
              icon: Icons.note_outlined, maxLines: 2),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.lock_rounded, color: AppColors.info, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'A 4-digit PIN will be sent to the recipient\'s number '
                        'to confirm delivery.',
                    style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
                        color: AppColors.info, height: 1.4)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Coupon card ────────────────────────────────────────────────────────────

  Widget _buildCouponCard() {
    final applied = _couponValid && _couponDiscount > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.local_offer_outlined, size: 18, color: AppColors.primaryGold),
            SizedBox(width: 8),
            Text(tr('ride.promoQuestion'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _couponCtrl,
                textCapitalization: TextCapitalization.characters,
                enabled: !applied,
                decoration: InputDecoration(
                  hintText: tr('delivery.enterCode'),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            applied
                ? TextButton(
                    onPressed: () => setState(() {
                      _couponCtrl.clear();
                      _couponValid = false;
                      _couponDiscount = 0;
                      _couponMessage = null;
                      _fetchEstimate();
                    }),
                    child: Text(tr('common.remove')),
                  )
                : ElevatedButton(
                    onPressed: _applyingCoupon ? null : _applyCoupon,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: Colors.black,
                    ),
                    child: _applyingCoupon
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(tr('ride.promoApply')),
                  ),
          ]),
          if (_couponMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              applied
                  ? '✓ Coupon applied — you save ${_couponDiscount.toStringAsFixed(0)} XAF'
                  : _couponMessage!,
              style: TextStyle(
                fontSize: 12.5,
                color: applied ? Colors.green.shade700 : Colors.red.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Payment card ───────────────────────────────────────────────────────────

  Widget _buildPaymentCard() {
    const methods = [
      ('mtn_mobile_money', 'MTN MoMo',    '🟡'),
      ('orange_money',     'Orange Money','🟠'),
      ('cash',             'Cash',        '💵'),
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('payment.title'),
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...methods.map((m) {
            final selected = _paymentMethod == m.$1;
            return GestureDetector(
              onTap: () => setState(() => _paymentMethod = m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryDark
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.borderLight),
                ),
                child: Row(children: [
                  Text(m.$3, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(m.$2,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary))),
                  if (selected)
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.primaryGold, size: 20),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Book bar ───────────────────────────────────────────────────────────────

  Widget _buildBookBar() {
    final price = _estimate?.totalPrice.toStringAsFixed(0);
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: SizedBox(
        width: double.infinity, height: 56,
        child: ElevatedButton(
          onPressed: _canBook ? _book : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isExpress
                ? AppColors.primaryGold : AppColors.primaryDark,
            foregroundColor: _isExpress ? AppColors.primaryDark : Colors.white,
            disabledBackgroundColor: AppColors.buttonDisabled,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: _booking
              ? SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5,
                  color: _isExpress ? AppColors.primaryDark : Colors.white))
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_isExpress
                  ? Icons.bolt_rounded
                  : Icons.local_shipping_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                  price != null
                      ? 'Confirm Booking · $price XAF'
                      : 'Confirm Booking',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 15, fontWeight: FontWeight.w700,
                      letterSpacing: 0.1)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _input(TextEditingController ctrl, String hint,
      {IconData? icon, int maxLines = 1,
        TextInputType inputType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: inputType,
        onChanged: (_) => setState(() {}), // rebuild to update _canBook
        style: AppTypography.inputText.copyWith(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.inputHint.copyWith(fontSize: 13),
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: AppColors.textLight) : null,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    );
  }
}
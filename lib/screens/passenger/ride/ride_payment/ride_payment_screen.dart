// lib/presentation/screens/trip/ride_payment_screen.dart
//
// Shown after createTrip returns requiresPayment: true (MoMo / OM).
//
// Flow:
//   1. Passenger enters their mobile money phone number
//   2. Taps "Pay" → POST /api/payments/initiate  (CamPay fires USSD prompt)
//   3. "Check your phone" waiting UI shown
//   4. Listens for socket event  payment:confirmed  → go to SearchingDriverScreen
//                                payment:failed     → show retry UI
//   5. Fallback: polls GET /api/payments/:campayRef/status every 8 s
//      in case the socket event was missed (app backgrounded, etc.)
//   6. 15-minute timeout → show expired UI with retry option

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../service/api_services.dart';
import '../../../../service/socket_service.dart';
import '../../../../utils/app_colors.dart';
import '../../trip/searching_driver_screen.dart';


// ─── Payment state machine ────────────────────────────────────────────────────
enum _PayState {
  phoneEntry,    // initial — enter phone number
  initiating,    // calling POST /api/payments/initiate
  waiting,       // USSD sent, waiting for customer PIN + webhook
  failed,        // payment:failed received
  expired,       // 15-minute timeout
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class RidePaymentScreen extends StatefulWidget {
  /// Trip ID returned by createTrip — used to associate the payment.
  final String tripId;

  /// Fare in XAF — displayed to the user (informational only;
  /// backend always re-validates the amount from DB).
  final int fareAmount;

  /// 'momo' or 'om' — determines label & logo shown.
  final String paymentMethod;

  // Route context — passed straight through to SearchingDriverScreen
  final String  pickupAddress;
  final String  dropoffAddress;
  final LatLng  pickupLocation;
  final LatLng  dropoffLocation;
  final String  vehicleType;
  final String  accessToken;

  const RidePaymentScreen({
    super.key,
    required this.tripId,
    required this.fareAmount,
    required this.paymentMethod,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.vehicleType,
    required this.accessToken,
  });

  @override
  State<RidePaymentScreen> createState() => _RidePaymentScreenState();
}

class _RidePaymentScreenState extends State<RidePaymentScreen>
    with TickerProviderStateMixin {

  // ── Socket ───────────────────────────────────────────────────────────
  final SocketService _socket = SocketService();

  // ── State machine ────────────────────────────────────────────────────
  _PayState _state = _PayState.phoneEntry;

  // ── Phone input ──────────────────────────────────────────────────────
  final _phoneCtrl  = TextEditingController();
  final _phoneFocus = FocusNode();
  String? _phoneError;

  // ── CamPay refs (set after initiate succeeds) ─────────────────────
  String? _campayRef;
  String? _ussdCode;
  String? _operator;

  // ── Error / info message ─────────────────────────────────────────────
  String? _errorMessage;

  // ── Timers ───────────────────────────────────────────────────────────
  Timer? _pollTimer;
  Timer? _expiryTimer;

  // ── Animations ───────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _entryCtrl;
  late Animation<double>   _pulse;
  late Animation<double>   _entryFade;
  late Animation<Offset>   _entrySlide;

  // ─────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _connectSocket();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    _removeSocketListeners();
    super.dispose();
  }

  // ── Animations ────────────────────────────────────────────────────────

  void _setupAnimations() {
    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 1600), vsync: this)
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entryCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  // ── Socket ────────────────────────────────────────────────────────────

  Future<void> _connectSocket() async {
    try {
      final prefs  = await SharedPreferences.getInstance();
      final uStr   = prefs.getString('user_data') ?? '{}';
      final user   = json.decode(uStr) as Map<String, dynamic>;
      final userId = user['uuid']?.toString() ?? user['id']?.toString() ?? '';
      final base   = dotenv.env['API_BASE_URL'] ?? '';

      if (userId.isEmpty || base.isEmpty) return;

      if (!_socket.isConnected) {
        await _socket.connect(
          url:         base,
          accessToken: widget.accessToken,
          userId:      userId,
          userType:    'PASSENGER',
        );
      }

      _socket.on('payment:confirmed', _onPaymentConfirmed);
      _socket.on('payment:failed',    _onPaymentFailed);

      debugPrint('✅ [RIDE_PAYMENT] Socket listeners registered');
    } catch (e) {
      debugPrint('⚠️  [RIDE_PAYMENT] Socket connect failed: $e');
    }
  }

  void _removeSocketListeners() {
    try {
      _socket.off('payment:confirmed');
      _socket.off('payment:failed');
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────
  // SOCKET EVENT HANDLERS
  // ─────────────────────────────────────────────────────────────────────

  void _onPaymentConfirmed(dynamic data) {
    debugPrint('✅ [RIDE_PAYMENT] payment:confirmed received: $data');
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    if (!mounted) return;
    _navigateToSearching();
  }

  void _onPaymentFailed(dynamic data) {
    debugPrint('❌ [RIDE_PAYMENT] payment:failed received: $data');
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    if (!mounted) return;

    final msg = (data is Map) ? data['message']?.toString() : null;
    setState(() {
      _state        = _PayState.failed;
      _errorMessage = msg ?? 'Your payment was not completed. Please try again.';
    });
    HapticFeedback.vibrate();
  }

  // ─────────────────────────────────────────────────────────────────────
  // INITIATE PAYMENT
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _initiatePayment() async {
    // Validate phone
    final rawPhone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (rawPhone.isEmpty) {
      setState(() => _phoneError = 'Please enter your phone number');
      return;
    }
    // Accept 9-digit (670000000) or full (237670000000)
    final phoneDigits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length != 9 && phoneDigits.length != 12) {
      setState(() => _phoneError = 'Enter a valid 9-digit Cameroon number');
      return;
    }

    setState(() {
      _phoneError = null;
      _state      = _PayState.initiating;
    });

    try {
      final result = await ApiService.initiatePayment(
        accessToken: widget.accessToken,
        vertical:    'trip',
        verticalId:  widget.tripId,
        phone:       phoneDigits.length == 12 ? phoneDigits.substring(3) : phoneDigits,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _campayRef = result['campayRef']?.toString();
        _ussdCode  = result['ussdCode']?.toString();
        _operator  = result['operator']?.toString();

        setState(() => _state = _PayState.waiting);
        _startPolling();
        _startExpiryTimer();
        debugPrint('💳 [RIDE_PAYMENT] Payment initiated — campayRef: $_campayRef');
      } else {
        setState(() {
          _state        = _PayState.failed;
          _errorMessage = result['message']?.toString()
              ?? 'Could not initiate payment. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _state        = _PayState.failed;
        _errorMessage = msg.isNotEmpty ? msg : 'Payment failed. Please try again.';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // POLLING FALLBACK
  // Fires every 8 seconds while waiting.
  // Catches the case where the socket event was missed
  // (app backgrounded, brief disconnect, etc.)
  // ─────────────────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (_campayRef == null) return;
      try {
        final result = await ApiService.checkPaymentStatus(
          accessToken: widget.accessToken,
          campayRef:   _campayRef!,
        );
        if (!mounted) return;

        final status = result['status']?.toString().toUpperCase();
        debugPrint('🔄 [RIDE_PAYMENT] Poll status: $status');

        if (status == 'SUCCESSFUL') {
          _pollTimer?.cancel();
          _expiryTimer?.cancel();
          _navigateToSearching();
        } else if (status == 'FAILED' || status == 'EXPIRED') {
          _pollTimer?.cancel();
          _expiryTimer?.cancel();
          setState(() {
            _state = status == 'EXPIRED'
                ? _PayState.expired
                : _PayState.failed;
            _errorMessage = 'Your payment was not completed. Please try again.';
          });
        }
      } catch (e) {
        debugPrint('⚠️  [RIDE_PAYMENT] Poll error: $e');
        // Non-fatal — keep polling
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // EXPIRY TIMER — 15 minutes
  // ─────────────────────────────────────────────────────────────────────

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer(const Duration(minutes: 15), () {
      _pollTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _state        = _PayState.expired;
        _errorMessage = 'Your payment session has expired. Please try again.';
      });
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────────

  void _navigateToSearching() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SearchingDriverScreen(
          tripId:          widget.tripId,
          pickupAddress:   widget.pickupAddress,
          dropoffAddress:  widget.dropoffAddress,
          pickupLocation:  widget.pickupLocation,
          dropoffLocation: widget.dropoffLocation,
          fareEstimate:    '${widget.fareAmount} XAF',
          vehicleType:     widget.vehicleType,
          paymentMethod:   widget.paymentMethod,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // RETRY
  // ─────────────────────────────────────────────────────────────────────

  void _retry() {
    _pollTimer?.cancel();
    _expiryTimer?.cancel();
    setState(() {
      _state        = _PayState.phoneEntry;
      _errorMessage = null;
      _campayRef    = null;
      _ussdCode     = null;
      _operator     = null;
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────

  bool get _isMomo => widget.paymentMethod == 'momo';

  String get _methodLabel => _isMomo ? 'MTN MoMo' : 'Orange Money';

  Color get _methodColor => _isMomo
      ? const Color(0xFFFFCC00)   // MTN yellow
      : const Color(0xFFFF6600);  // Orange orange

  String get _methodAsset => _isMomo
      ? 'assets/images/momo.png'
      : 'assets/images/om.png';

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation:       0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () {
            // Only allow back nav from phone entry — once payment is initiated
            // the trip exists on the backend, navigating back would orphan it.
            if (_state == _PayState.phoneEntry) {
              Navigator.pop(context);
            } else {
              _showCancelWarning();
            }
          },
        ),
        title: const Text(
          'Mobile Payment',
          style: TextStyle(
            color:      Colors.black,
            fontSize:   17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _entryFade,
          child: SlideTransition(
            position: _entrySlide,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _PayState.phoneEntry:
        return _buildPhoneEntry();
      case _PayState.initiating:
        return _buildInitiating();
      case _PayState.waiting:
        return _buildWaiting();
      case _PayState.failed:
      case _PayState.expired:
        return _buildError();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // PHONE ENTRY
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildPhoneEntry() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // ── Method header ──────────────────────────────────────────
          Center(
            child: Container(
              width:  88,
              height: 88,
              decoration: BoxDecoration(
                color:        _methodColor.withOpacity(0.12),
                shape:        BoxShape.circle,
                border: Border.all(
                    color: _methodColor.withOpacity(0.3), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Image.asset(
                  _methodAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.phone_android_rounded,
                    color: _methodColor,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Center(
            child: Text(
              'Pay with $_methodLabel',
              style: const TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.w800,
                color:      Colors.black,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'You will receive a prompt on your phone\nto confirm the payment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:    Colors.grey.shade600,
                height:   1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Fare summary card ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:        const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primaryGold.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width:  44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:        AppColors.primaryGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_taxi_rounded,
                      color: AppColors.primaryGold, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.vehicleType} ride',
                        style: TextStyle(
                          fontSize: 13,
                          color:    Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.fareAmount} XAF',
                        style: const TextStyle(
                          fontSize:   20,
                          fontWeight: FontWeight.w900,
                          color:      Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _methodColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _methodLabel,
                    style: TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                      color:      _methodColor == const Color(0xFFFFCC00)
                          ? Colors.black
                          : _methodColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Phone input ────────────────────────────────────────────
          Text(
            'Your $_methodLabel number',
            style: const TextStyle(
              fontSize:   14,
              fontWeight: FontWeight.w700,
              color:      Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color:        Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _phoneError != null
                    ? Colors.red.shade400
                    : _phoneFocus.hasFocus
                    ? AppColors.primaryGold
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Country code pill
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Text(
                    '🇨🇲 +237',
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller:  _phoneCtrl,
                    focusNode:   _phoneFocus,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    style: const TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w600,
                      color:      Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText:        '6XX XXX XXX',
                      hintStyle:       TextStyle(
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w400),
                      border:          InputBorder.none,
                      isDense:         true,
                      contentPadding:  const EdgeInsets.symmetric(
                          vertical: 14),
                    ),
                    onChanged: (_) {
                      if (_phoneError != null) {
                        setState(() => _phoneError = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),

          if (_phoneError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 14, color: Colors.red.shade600),
                const SizedBox(width: 6),
                Text(
                  _phoneError!,
                  style: TextStyle(
                    fontSize: 12,
                    color:    Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Text(
            _isMomo
                ? 'Enter the MTN number registered for MoMo'
                : 'Enter the Orange number registered for OM',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),

          const SizedBox(height: 32),

          // ── Pay button ─────────────────────────────────────────────
          SizedBox(
            width:  double.infinity,
            height: 56,
            child:  ElevatedButton(
              onPressed: _initiatePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded,
                      color: AppColors.primaryGold, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Pay ${widget.fareAmount} XAF',
                    style: const TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                      color:      Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Security note ──────────────────────────────────────────
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Secured by CamPay · No PIN shared with WeGo',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // INITIATING (brief spinner while API call runs)
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildInitiating() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width:  56,
            height: 56,
            child:  CircularProgressIndicator(
              strokeWidth: 3,
              color:       _methodColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sending payment request…',
            style: TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.w600,
              color:      Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // WAITING
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildWaiting() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // ── Pulsing phone icon ─────────────────────────────────────
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width:  100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _methodColor.withOpacity(0.12),
                border: Border.all(
                    color: _methodColor.withOpacity(0.35), width: 2.5),
              ),
              child: Icon(
                Icons.phone_android_rounded,
                size:  44,
                color: _methodColor == const Color(0xFFFFCC00)
                    ? Colors.black87
                    : _methodColor,
              ),
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'Check your phone',
            style: TextStyle(
              fontSize:   24,
              fontWeight: FontWeight.w800,
              color:      Colors.black,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A payment prompt has been sent to\n+237 ${_phoneCtrl.text.trim()}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color:    Colors.grey.shade600,
              height:   1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your $_methodLabel PIN to confirm',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize:   14,
              fontWeight: FontWeight.w600,
              color:      Colors.black87,
            ),
          ),

          if (_ussdCode != null && _ussdCode!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color:        Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dialpad_rounded,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Or dial $_ussdCode',
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                      color:      Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),

          // ── Fare reminder ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primaryGold.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount to pay',
                  style: TextStyle(
                    fontSize: 14,
                    color:    Colors.grey.shade600,
                  ),
                ),
                Text(
                  '${widget.fareAmount} XAF',
                  style: const TextStyle(
                    fontSize:   18,
                    fontWeight: FontWeight.w900,
                    color:      Colors.black,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Waiting indicator ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width:  16,
                height: 16,
                child:  CircularProgressIndicator(
                  strokeWidth: 2,
                  color:       _methodColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Waiting for payment confirmation…',
                style: TextStyle(
                  fontSize: 13,
                  color:    Colors.grey.shade500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── Cancel / use different number ──────────────────────────
          TextButton(
            onPressed: _showCancelWarning,
            child: Text(
              'Use a different number',
              style: TextStyle(
                fontSize:   14,
                color:      Colors.grey.shade500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // ERROR / EXPIRED
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildError() {
    final isExpired = _state == _PayState.expired;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width:  90,
              height: 90,
              decoration: BoxDecoration(
                color:  isExpired
                    ? Colors.orange.shade50
                    : Colors.red.shade50,
                shape:  BoxShape.circle,
              ),
              child: Icon(
                isExpired
                    ? Icons.timer_off_rounded
                    : Icons.error_outline_rounded,
                size:  44,
                color: isExpired
                    ? Colors.orange.shade600
                    : Colors.red.shade500,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isExpired ? 'Session Expired' : 'Payment Failed',
              style: const TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.w800,
                color:      Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ??
                  (isExpired
                      ? 'Your payment session has expired.'
                      : 'Your payment could not be completed.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color:    Colors.grey.shade600,
                height:   1.5,
              ),
            ),
            const SizedBox(height: 36),

            SizedBox(
              width:  double.infinity,
              height: 52,
              child:  ElevatedButton(
                onPressed: _retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                    color:      Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel ride',
                style: TextStyle(
                  fontSize: 14,
                  color:    Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // CANCEL WARNING DIALOG
  // ─────────────────────────────────────────────────────────────────────

  void _showCancelWarning() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel payment?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'If you cancel, your ride request will be cancelled and '
              'no charge will be made. You can book again anytime.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to map
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Cancel Ride',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
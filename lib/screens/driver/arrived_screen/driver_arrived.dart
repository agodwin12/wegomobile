// lib/screens/driver/arrived_screen/driver_arrived.dart
//
// Mapbox migration: flutter_map + latlong2 replacing google_maps_flutter.
// BitmapDescriptor / dart:ui removed — car shown via CarMarkerWidget.
// All other logic preserved: waiting timer, no-show, start trip,
// DraggableScrollableSheet, PopScope back-guard.

import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wego_v1/main.dart';
import 'package:wego_v1/utils/app_colors.dart';
import 'package:wego_v1/utils/car_marker_painter.dart';
import 'package:wego_v1/utils/map_style.dart';
import 'package:wego_v1/widgets/map_style_button.dart';

import '../Trip in progress/driver_trip_in_progress_screen.dart';

// ═══════════════════════════════════════════════════════════════
// LOCAL COLOUR CONSTANTS
// ═══════════════════════════════════════════════════════════════

const Color _kSuccess       = Color(0xFF16A34A);
const Color _kWarning       = Color(0xFFF59E0B);
const Color _kError         = Color(0xFFDC2626);
const Color _kInfo          = Color(0xFF2563EB);
const Color _kSuccessLight  = Color(0xFFDCFCE7);
const Color _kWarningLight  = Color(0xFFFEF3C7);
const Color _kErrorLight    = Color(0xFFFEE2E2);
const Color _kBgWhite       = Colors.white;
const Color _kBgLight       = Color(0xFFF8F8F8);
const Color _kBorder        = Color(0xFFE5E7EB);
const Color _kShadow        = Color(0x1A000000);
const Color _kTextSecondary = Color(0xFF6B7280);

const LinearGradient _kGoldGradient = LinearGradient(
  colors: [AppColors.primaryGold, Color(0xFFFFD000)],
  begin:  Alignment.topLeft,
  end:    Alignment.bottomRight,
);

// ═══════════════════════════════════════════════════════════════
// DRIVER ARRIVED SCREEN
// ═══════════════════════════════════════════════════════════════

class DriverArrivedScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> trip;
  final Map<String, dynamic> passenger;

  const DriverArrivedScreen({
    Key? key,
    required this.tripId,
    required this.trip,
    required this.passenger,
  }) : super(key: key);

  @override
  State<DriverArrivedScreen> createState() => _DriverArrivedScreenState();
}

class _DriverArrivedScreenState extends State<DriverArrivedScreen>
    with TickerProviderStateMixin {

  // ── Map ──────────────────────────────────────────────────────
  final MapController _mapCtrl = MapController();

  // ── Draggable sheet ──────────────────────────────────────────
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // ── Animations ───────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _timerPulseController;
  late Animation<double>   _pulseAnimation;

  // ── Timer ────────────────────────────────────────────────────
  Timer? _waitingTimer;
  int    _waitingSeconds = 0;
  bool   _canShowNoShow  = false;

  // ── State ────────────────────────────────────────────────────
  bool _hasNavigated = false;
  bool _isStarting   = false;
  bool _isCanceling  = false;

  // ── Locations ────────────────────────────────────────────────
  late LatLng _pickupLocation;
  late LatLng _dropoffLocation;
  late String _pickupAddress;
  late String _dropoffAddress;

  // ── Token ────────────────────────────────────────────────────
  String get _liqKey => dotenv.env['LOCATIONIQ_KEY'] ?? '';
  MapStyle _mapStyle = MapStyle.navigationDay;

  // ════════════════════════════════════════════════════════════
  // INIT
  // ════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📍 [DRIVER-ARRIVED] Screen initialized');
    debugPrint('📦 Trip ID: ${widget.tripId}');
    debugPrint('👤 Passenger: $_passengerName');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    _parseLocations();
    _setupAnimations();
    _startWaitingTimer();
    _notifyPassenger();
    loadMapStylePref().then((s) { if (mounted) setState(() => _mapStyle = s); });
  }

  void _parseLocations() {
    final pickup  =
        widget.trip['pickup']  ?? widget.trip['pickup_location']  ?? {};
    final dropoff =
        widget.trip['dropoff'] ?? widget.trip['dropoff_location'] ?? {};

    _pickupLocation = LatLng(
      double.tryParse(pickup['lat']?.toString()
          ?? pickup['latitude']?.toString()  ?? '0') ?? 0,
      double.tryParse(pickup['lng']?.toString()
          ?? pickup['longitude']?.toString() ?? '0') ?? 0,
    );
    _pickupAddress = pickup['address']?.toString()
        ?? widget.trip['pickupAddress']?.toString()
        ?? 'Pickup Location';

    _dropoffLocation = LatLng(
      double.tryParse(dropoff['lat']?.toString()
          ?? dropoff['latitude']?.toString()  ?? '0') ?? 0,
      double.tryParse(dropoff['lng']?.toString()
          ?? dropoff['longitude']?.toString() ?? '0') ?? 0,
    );
    _dropoffAddress = dropoff['address']?.toString()
        ?? widget.trip['dropoffAddress']?.toString()
        ?? 'Destination';
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(
            parent: _pulseController, curve: Curves.easeInOut));
    _pulseController.repeat(reverse: true);

    _timerPulseController = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
    _timerPulseController.repeat(reverse: true);
  }

  void _startWaitingTimer() {
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _waitingSeconds++);
      if (_waitingSeconds == 300 && !_canShowNoShow) {
        setState(() => _canShowNoShow = true);
        _showNoShowAvailableSnackBar();
        _timerPulseController.duration =
            const Duration(milliseconds: 500);
        _timerPulseController.repeat(reverse: true);
      }
    });
  }

  void _notifyPassenger() {
    // No-op: the HTTP /arrived call is authoritative and the backend emits
    // trip:driver_arrived to the passenger. Kept so existing call sites compile.
  }

  // ════════════════════════════════════════════════════════════
  // MARKERS
  // ════════════════════════════════════════════════════════════

  List<Marker> _buildMarkers() {
    return [
      // Car at pickup (driver has arrived)
      Marker(
        point:  _pickupLocation,
        width:  60,
        height: 60,
        child: const CarMarkerWidget(
          heading: 0,
          color:   Color(0xFF1A1A1A),
        ),
      ),
      // Red dropoff pin
      Marker(
        point:  _dropoffLocation,
        width:  40,
        height: 50,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      ),
    ];
  }

  // ════════════════════════════════════════════════════════════
  // PASSENGER HELPERS
  // ════════════════════════════════════════════════════════════

  String get _passengerName {
    final direct = widget.passenger['name']?.toString() ?? '';
    if (direct.isNotEmpty) return direct;
    final first = widget.passenger['firstName']?.toString()
        ?? widget.passenger['first_name']?.toString() ?? '';
    final last  = widget.passenger['lastName']?.toString()
        ?? widget.passenger['last_name']?.toString()  ?? '';
    final full  = '$first $last'.trim();
    return full.isNotEmpty ? full : 'Passenger';
  }

  String get _passengerInitial {
    final firstName = widget.passenger['firstName']?.toString().trim()
        ?? widget.passenger['first_name']?.toString().trim() ?? '';
    if (firstName.isNotEmpty) return firstName[0].toUpperCase();
    final name = _passengerName.trimLeft();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return 'P';
  }

  String? get _passengerAvatarUrl {
    final candidates = [
      widget.passenger['avatar_url'],
      widget.passenger['avatarUrl'],
      widget.passenger['profile_photo'],
      widget.passenger['photo'],
      widget.passenger['avatar'],
    ];
    for (final c in candidates) {
      final url = c?.toString().trim() ?? '';
      if (url.startsWith('http://') || url.startsWith('https://')) return url;
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════

  Future<void> _startTrip() async {
    if (_hasNavigated || _isStarting) return;
    setState(() => _isStarting = true);

    const maxRetries = 2;
    int retryCount   = 0;

    while (retryCount <= maxRetries) {
      try {
        final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
        final token      = await _getAccessToken();
        if (token.isEmpty) throw Exception('No access token available');

        final response = await http
            .post(
              Uri.parse('$apiBaseUrl/driver/trips/${widget.tripId}/start'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type':  'application/json',
              },
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () =>
                  throw TimeoutException('Request timed out after 30s'),
            );

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          // HTTP /start is authoritative; backend emits trip:started to passenger.

          _hasNavigated = true;
          _showSuccessSnackBar('Trip started! Navigate to destination.');
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DriverTripInProgressScreen(
                tripId:    widget.tripId,
                trip:      responseData['data']?['trip'] ?? widget.trip,
                passenger: widget.passenger,
              ),
            ),
          );
          return;

        } else if (response.statusCode == 409) {
          final data = json.decode(response.body);
          if (mounted) {
            setState(() { _isStarting = false; _hasNavigated = false; });
            _showErrorSnackBar(data['message'] ?? 'Trip already started');
          }
          return;

        } else {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }

      } on TimeoutException catch (e) {
        debugPrint('⏱️ Timeout attempt ${retryCount + 1}: $e');
        retryCount++;
        if (retryCount > maxRetries) {
          if (mounted) {
            setState(() { _isStarting = false; _hasNavigated = false; });
            final shouldRetry = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text('Connection Timeout'),
                content: const Text(
                  'The request is taking longer than expected. '
                  'The trip may have started on the server. '
                  'Do you want to try again?',
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold),
                    child: const Text('Retry',
                        style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            );
            if (shouldRetry == true) {
              retryCount = 0;
              setState(() => _isStarting = true);
              continue;
            }
          }
          return;
        }
        await Future.delayed(const Duration(seconds: 3));

      } catch (e, st) {
        debugPrint('❌ Start trip error: $e\n$st');
        if (mounted) {
          setState(() { _isStarting = false; _hasNavigated = false; });
          _showErrorSnackBar('Failed to start trip: ${e.toString()}');
        }
        return;
      }
    }
  }

  Future<void> _handleNoShow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _kWarningLight,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.person_off,
                color: _kWarning, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Report No-Show?',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure the passenger did not show up?',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color:        _kWarningLight,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: _kWarning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You\'ve waited ${_formatWaitingTime(_waitingSeconds)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kWarning,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm No-Show',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final token      = await _getAccessToken();

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/driver/trips/${widget.tripId}/no-show'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type':  'application/json',
            },
            body: json.encode({
              'waitingTime': _waitingSeconds,
              'reason':      'Passenger did not show up',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // HTTP /no-show is authoritative; backend emits trip:no_show to passenger.
        _showSuccessSnackBar('No-show reported. Trip canceled.');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to report no-show. Please try again.');
    }
  }

  Future<void> _callPassenger() async {
    final phone = widget.passenger['phone']?.toString()
        ?? widget.passenger['phone_e164']?.toString() ?? '';
    if (phone.isEmpty) {
      _showErrorSnackBar('Passenger phone number not available');
      return;
    }
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
      else _showErrorSnackBar('Cannot launch phone dialer');
    } catch (_) {
      _showErrorSnackBar('Failed to make call');
    }
  }

  Future<void> _sendSMS() async {
    final phone = widget.passenger['phone']?.toString()
        ?? widget.passenger['phone_e164']?.toString() ?? '';
    if (phone.isEmpty) {
      _showErrorSnackBar('Passenger phone number not available');
      return;
    }
    final uri = Uri.parse(
        'sms:$phone?body=I have arrived at the pickup location.');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
      else _showErrorSnackBar('Cannot open SMS app');
    } catch (_) {
      _showErrorSnackBar('Failed to send SMS');
    }
  }

  Future<void> _cancelTrip() async {
    final reason = await showDialog<String>(
        context: context, builder: (_) => _CancelDialog());
    if (reason == null || reason.isEmpty) return;

    setState(() => _isCanceling = true);

    try {
      final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final token      = await _getAccessToken();

      final response = await http
          .post(
            Uri.parse(
                '$apiBaseUrl/driver/trips/${widget.tripId}/cancel'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type':  'application/json',
            },
            body: json.encode({
              'reason':      reason,
              'waitingTime': _waitingSeconds,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // HTTP /cancel is authoritative; backend emits trip:canceled to passenger.
        _showSuccessSnackBar('Trip canceled');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCanceling = false);
        _showErrorSnackBar('Failed to cancel trip. Please try again.');
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  Future<String> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? '';
  }

  String _formatWaitingTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '$s seconds';
    if (m == 1) return '1 minute $s seconds';
    return '$m minutes $s seconds';
  }

  Color _getTimerColor() {
    if (_waitingSeconds < 180) return _kSuccess;
    if (_waitingSeconds < 300) return _kWarning;
    return _kError;
  }

  void _showNoShowAvailableSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.info_outline, color: Colors.white),
        SizedBox(width: 12),
        Expanded(
          child: Text('You can now report passenger as no-show',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]),
      backgroundColor: _kWarning,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 5),
    ));
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(message),
      backgroundColor: _kError,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(message),
      backgroundColor: _kSuccess,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ════════════════════════════════════════════════════════════
  // DISPOSE
  // ════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _pulseController.dispose();
    _timerPulseController.dispose();
    _sheetController.dispose();
    _waitingTimer?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final double minFraction  =
        (120 / MediaQuery.of(context).size.height).clamp(0.14, 0.20);
    final double initFraction = 0.52;
    final double maxFraction  = _canShowNoShow ? 0.80 : 0.72;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title:   const Text('Leave Screen?'),
            content: const Text(
                'You are waiting for the passenger. Go back?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Stay')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Leave')),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [

            // ── FULL-SCREEN MAP ──────────────────────────────
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: _pickupLocation,
                  initialZoom:   15.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: _mapStyle.tileUrl(_liqKey),
                    userAgentPackageName: 'com.wego.app',
                    tileProvider: NetworkTileProvider(),
                  ),
                  MarkerLayer(markers: _buildMarkers()),
                ],
              ),
            ),

            MapStyleButton(
              current: _mapStyle,
              onChanged: (s) { setState(() => _mapStyle = s); saveMapStylePref(s); },
            ),

            // ── TOP GRADIENT SCRIM ───────────────────────────
            Positioned(
              top: 0, left: 0, right: 0, height: 180,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin:  Alignment.topCenter,
                      end:    Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.88),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── TOP BAR ─────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(children: [
                  _TopBarBtn(
                      icon: Icons.support_agent_rounded, onTap: () {}),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color:        _getTimerColor(),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color:      _getTimerColor().withOpacity(0.40),
                              blurRadius: 12,
                              offset:     const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 7),
                            Text(
                              'Waiting  '
                              '${_waitingSeconds ~/ 60}:'
                              '${(_waitingSeconds % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  color:      Colors.white,
                                  fontSize:   13,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),

            // ── RE-CENTER FAB ────────────────────────────────
            Positioned(
              right:  16,
              bottom: MediaQuery.of(context).size.height * initFraction + 16,
              child: FloatingActionButton.small(
                heroTag:         'recenter_fab',
                backgroundColor: Colors.white,
                elevation:       4,
                onPressed: () {
                  try {
                    _mapCtrl.move(_pickupLocation, 15.5);
                  } catch (_) {}
                },
                child: const Icon(Icons.my_location_rounded,
                    color: Colors.black87),
              ),
            ),

            // ── DRAGGABLE BOTTOM SHEET ───────────────────────
            DraggableScrollableSheet(
              controller:       _sheetController,
              initialChildSize: initFraction,
              minChildSize:     minFraction,
              maxChildSize:     maxFraction,
              snap:             true,
              snapSizes:        [minFraction, initFraction, maxFraction],
              builder: (context, scrollController) {
                return _SheetContent(
                  scrollController: scrollController,
                  passengerName:    _passengerName,
                  passengerInitial: _passengerInitial,
                  passengerAvatar:  _passengerAvatarUrl,
                  waitingSeconds:   _waitingSeconds,
                  pickupAddress:    _pickupAddress,
                  dropoffAddress:   _dropoffAddress,
                  canShowNoShow:    _canShowNoShow,
                  isStarting:       _isStarting,
                  isCanceling:      _isCanceling,
                  formatWaiting:    _formatWaitingTime,
                  onStartTrip:      _startTrip,
                  onCancel:         _cancelTrip,
                  onNoShow:         _handleNoShow,
                  onCall:           _callPassenger,
                  onSMS:            _sendSMS,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TOP BAR BUTTON
// ════════════════════════════════════════════════════════════════

class _TopBarBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _TopBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _kBgWhite,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color:      _kShadow,
                blurRadius: 12,
                offset:     const Offset(0, 4))
          ],
        ),
        child: Icon(icon, size: 22, color: Colors.black87),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SHEET CONTENT
// ════════════════════════════════════════════════════════════════

class _SheetContent extends StatelessWidget {
  final ScrollController     scrollController;
  final String               passengerName;
  final String               passengerInitial;
  final String?              passengerAvatar;
  final int                  waitingSeconds;
  final String               pickupAddress;
  final String               dropoffAddress;
  final bool                 canShowNoShow;
  final bool                 isStarting;
  final bool                 isCanceling;
  final String Function(int) formatWaiting;
  final VoidCallback         onStartTrip;
  final VoidCallback         onCancel;
  final VoidCallback         onNoShow;
  final VoidCallback         onCall;
  final VoidCallback         onSMS;

  const _SheetContent({
    required this.scrollController,
    required this.passengerName,
    required this.passengerInitial,
    required this.passengerAvatar,
    required this.waitingSeconds,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.canShowNoShow,
    required this.isStarting,
    required this.isCanceling,
    required this.formatWaiting,
    required this.onStartTrip,
    required this.onCancel,
    required this.onNoShow,
    required this.onCall,
    required this.onSMS,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        _kBgWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: _kShadow, blurRadius: 24, offset: Offset(0, -6))
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding:    EdgeInsets.zero,
        physics:    const ClampingScrollPhysics(),
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20,
                MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // STATUS BANNER
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient:     _kGoldGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color:      AppColors.primaryGold.withOpacity(0.30),
                        blurRadius: 16,
                        offset:     const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:        Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_pin_circle_rounded,
                          color: Colors.black, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Waiting for Passenger',
                              style: TextStyle(
                                  fontSize:   17,
                                  fontWeight: FontWeight.w800,
                                  color:      Colors.black)),
                          SizedBox(height: 3),
                          Text('Stay at the pickup point',
                              style: TextStyle(
                                  fontSize: 13,
                                  color:    Colors.black54)),
                        ],
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 18),

                // PASSENGER ROW
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _kBgLight,
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    _PassengerAvatar(
                        initial: passengerInitial,
                        avatarUrl: passengerAvatar),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(passengerName,
                              style: const TextStyle(
                                  fontSize:   17,
                                  fontWeight: FontWeight.w700)),
                          Text('Your passenger',
                              style: TextStyle(
                                  fontSize: 13,
                                  color:    _kTextSecondary)),
                        ],
                      ),
                    ),
                    _SmallBtn(
                        icon:      Icons.call_rounded,
                        iconColor: _kSuccess,
                        bgColor:   _kSuccessLight,
                        onTap:     onCall),
                    const SizedBox(width: 8),
                    _SmallBtn(
                        icon:      Icons.sms_rounded,
                        iconColor: _kInfo,
                        bgColor:   const Color(0xFFEFF6FF),
                        onTap:     onSMS),
                  ]),
                ),

                const SizedBox(height: 14),

                _RouteSummary(
                    pickup: pickupAddress, dropoff: dropoffAddress),

                const SizedBox(height: 20),

                // NO-SHOW (after 5 min)
                if (canShowNoShow) ...[
                  SizedBox(
                    width:  double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: onNoShow,
                      icon: const Icon(Icons.person_off_rounded,
                          color: _kWarning),
                      label: const Text('Report Passenger No-Show',
                          style: TextStyle(
                              color:      _kWarning,
                              fontWeight: FontWeight.w700,
                              fontSize:   15)),
                      style: OutlinedButton.styleFrom(
                        side:  const BorderSide(color: _kWarning, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // CANCEL / START
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isCanceling ? null : onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side:    const BorderSide(color: _kError, width: 2),
                        shape:   RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isCanceling
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(_kError)))
                          : const Text('Cancel',
                              style: TextStyle(
                                  color:      _kError,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient:     _kGoldGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:      AppColors.primaryGold.withOpacity(0.3),
                            blurRadius: 12,
                            offset:     const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: isStarting ? null : onStartTrip,
                        icon: isStarting
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.black)))
                            : const Icon(Icons.play_arrow_rounded,
                                color: Colors.black, size: 24),
                        label: Text(
                          isStarting ? 'Starting…' : 'Start Trip',
                          style: const TextStyle(
                              fontSize:   16,
                              fontWeight: FontWeight.w800,
                              color:      Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor:     Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PASSENGER AVATAR
// ════════════════════════════════════════════════════════════════

class _PassengerAvatar extends StatelessWidget {
  final String  initial;
  final String? avatarUrl;
  final double  size;

  const _PassengerAvatar({
    required this.initial,
    required this.avatarUrl,
    this.size = 52,
  });

  bool get _hasValidPhoto {
    if (avatarUrl == null) return false;
    final url = avatarUrl!.trim();
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape:  BoxShape.circle,
        border: Border.all(
            color: AppColors.primaryGold.withOpacity(0.5), width: 2),
      ),
      child: ClipOval(
        child: _hasValidPhoto
            ? CachedNetworkImage(
                imageUrl:    avatarUrl!,
                width:       size,
                height:      size,
                fit:         BoxFit.cover,
                placeholder: (_, __) =>
                    _Fallback(initial: initial, size: size),
                errorWidget: (_, __, ___) =>
                    _Fallback(initial: initial, size: size),
              )
            : _Fallback(initial: initial, size: size),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String initial;
  final double size;
  const _Fallback({required this.initial, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      color:     AppColors.primaryGold,
      alignment: Alignment.center,
      child: Text(initial,
          style: TextStyle(
              fontSize:   size * 0.42,
              fontWeight: FontWeight.w800,
              color:      Colors.black)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ROUTE SUMMARY
// ════════════════════════════════════════════════════════════════

class _RouteSummary extends StatelessWidget {
  final String pickup;
  final String dropoff;
  const _RouteSummary({required this.pickup, required this.dropoff});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: _kBgLight, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Column(children: [
          Container(
              width: 9, height: 9,
              decoration: const BoxDecoration(
                  color: Color(0xFF22C55E), shape: BoxShape.circle)),
          Container(
            width: 2, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [Color(0xFF22C55E), Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Container(
              width: 9, height: 9,
              decoration: const BoxDecoration(
                  color: Color(0xFFEF4444), shape: BoxShape.circle)),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AddrLine(label: 'Pickup',   address: pickup),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(height: 1, color: _kBorder),
              ),
              _AddrLine(label: 'Drop-off', address: dropoff),
            ],
          ),
        ),
      ]),
    );
  }
}

class _AddrLine extends StatelessWidget {
  final String label;
  final String address;
  const _AddrLine({required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: _kTextSecondary)),
        Text(
          address.length > 40 ? '${address.substring(0, 40)}…' : address,
          style: const TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w600,
              color:      Colors.black87),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SMALL ACTION BUTTON
// ════════════════════════════════════════════════════════════════

class _SmallBtn extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final Color        bgColor;
  final VoidCallback onTap;
  const _SmallBtn({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CANCEL DIALOG
// ════════════════════════════════════════════════════════════════

class _CancelDialog extends StatefulWidget {
  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  static const _reasons = [
    'Passenger not responding',
    'Passenger requested cancellation',
    'Safety concern',
    'Vehicle issue',
    'Other',
  ];
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: _kErrorLight, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.cancel_rounded, color: _kError, size: 24),
        ),
        const SizedBox(width: 12),
        const Text('Cancel Trip?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Please select a reason:',
              style: TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          ..._reasons.map((r) => RadioListTile<String>(
            title:       Text(r, style: const TextStyle(fontSize: 14)),
            value:       r,
            groupValue:  _selected,
            dense:       true,
            activeColor: AppColors.primaryGold,
            onChanged:   (v) => setState(() => _selected = v),
          )),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back')),
        ElevatedButton(
          onPressed: _selected != null
              ? () => Navigator.pop(context, _selected)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kError,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Confirm Cancel',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

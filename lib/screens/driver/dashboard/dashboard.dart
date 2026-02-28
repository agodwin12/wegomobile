import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wego_v1/main.dart';
import 'package:wego_v1/utils/app_colors.dart';
import 'package:wego_v1/utils/app_typography.dart';
import '../../../service/socket_service.dart';
import '../en_route_screen/driver_en_route_screen.dart';
import '../offer/trip_request_screen.dart';
import '../trip history/driver_trips_screen.dart';

class DriverMainScreen extends StatefulWidget {
  final String? initialAccessToken;

  const DriverMainScreen({
    Key? key,
    this.initialAccessToken,
  }) : super(key: key);

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // ─── Auth & profile ──────────────────────────────────────────────
  String? accessToken;
  String? driverName;
  String? driverFirstName;
  String? avatarUrl;

  // ─── Driver state ─────────────────────────────────────────────────
  bool isOnline = false;
  bool isLoading = false;
  bool isInitialized = false;
  bool _isDisposed = false;
  Position? currentPosition;
  GoogleMapController? mapController;

  // ─── Trip state ───────────────────────────────────────────────────
  Map<String, dynamic>? activeTripOffer;
  Map<String, dynamic>? currentTrip;

  // ─── Earnings ────────────────────────────────────────────────────
  double todayEarnings = 0.0;
  double weekEarnings = 0.0;
  int tripsToday = 0;

  // ─── Animations ──────────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _toggleController;
  late AnimationController _fadeInController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _toggleAnimation;
  late Animation<double> _fadeInAnimation;

  // ─── Socket subs ─────────────────────────────────────────────────
  StreamSubscription? _tripOfferSub;
  StreamSubscription? _tripCanceledSub;
  StreamSubscription? _tripMatchedSub;
  StreamSubscription? _socketConnectionSub;

  // ─── Location ────────────────────────────────────────────────────
  Timer? locationTimer;
  Timer? statsRefreshTimer;
  bool _isLocationUpdateInProgress = false;
  DateTime? _lastLocationUpdate;
  int reconnectAttempts = 0;
  final int maxReconnectAttempts = 5;

  // ─── Audio ───────────────────────────────────────────────────────
  late AudioPlayer audioPlayer;
  bool _isAudioPlaying = false;

  // ─── Lifecycle ───────────────────────────────────────────────────
  bool _isAppActive = true;
  bool _isInBackground = false;
  int _locationFailureCount = 0;
  final int _maxLocationFailures = 3;
  Timer? _keepAliveTimer;

  String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:4000/api';

  // ════════════════════════════════════════════════════════════════
  // INIT
  // ════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    audioPlayer = AudioPlayer();
    _configureAudioPlayer();
    _setupAnimations();
    _initializeDriver();
    _startKeepAliveTimer();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _toggleController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _toggleAnimation = CurvedAnimation(
      parent: _toggleController,
      curve: Curves.easeInOutCubic,
    );
    _fadeInAnimation = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    );
  }

  Future<void> _initializeDriver() async {
    if (_isDisposed) return;
    try {
      await _loadAccessToken();
      if (_isDisposed) return;

      if (accessToken == null && widget.initialAccessToken != null) {
        accessToken = widget.initialAccessToken;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken!);
      }

      if (accessToken == null) {
        if (mounted) _showSnackBar('Please login again', SnackBarType.error);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_isDisposed) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        });
        return;
      }

      await _loadDriverInfo();
      if (_isDisposed) return;

      await _connectSocket();
      if (_isDisposed) return;

      await _getCurrentLocation(isInitialFetch: true);
      if (_isDisposed) return;

      _setupSocketListeners();
      _loadDriverStats();
      _checkCurrentTrip();
      await _restoreDriverState();
      if (_isDisposed) return;

      _startStatsRefresh();

      if (mounted && !_isDisposed) {
        setState(() => isInitialized = true);
        _fadeInController.forward();
      }
    } catch (e) {
      debugPrint('❌ [DRIVER-DASHBOARD] Init error: $e');
      if (mounted && !_isDisposed) {
        _showSnackBar('Initialization failed. Please restart.', SnackBarType.error);
      }
    }
  }

  Future<void> _loadAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      accessToken = prefs.getString('access_token');
    } catch (e) {
      debugPrint('❌ Token load error: $e');
    }
  }

  Future<void> _loadDriverInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ Load avatar URL — saved in login as 'avatar_url'
      avatarUrl = prefs.getString('avatar_url');

      // ✅ Load name — saved in login as 'first_name' / 'last_name'
      final firstName = prefs.getString('first_name');
      final lastName = prefs.getString('last_name');

      driverFirstName = firstName?.isNotEmpty == true ? firstName : 'Driver';
      driverName = [firstName, lastName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');

      if (driverName?.isEmpty ?? true) driverName = 'Driver';

      debugPrint('✅ Driver: $driverName | avatar: $avatarUrl');
    } catch (e) {
      driverFirstName = 'Driver';
      driverName = 'Driver';
    }
  }

  void _goToTripsScreen() {
    if (!mounted || _isDisposed) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverTripsScreen()),
    ).then((_) {
      if (!mounted || _isDisposed) return;
      _loadDriverStats();
      _checkCurrentTrip();
    });
  }

  // ════════════════════════════════════════════════════════════════
  // ALL EXISTING LOGIC (unchanged — socket, location, trips, audio)
  // ════════════════════════════════════════════════════════════════

  void _configureAudioPlayer() {
    try {
      audioPlayer.setReleaseMode(ReleaseMode.stop);
      audioPlayer.setVolume(1.0);
      audioPlayer.onPlayerStateChanged.listen((state) {
        if (!_isDisposed && mounted) {
          _isAudioPlaying = (state == PlayerState.playing);
        }
      });
    } catch (e) {
      debugPrint('⚠️ Audio config error: $e');
    }
  }

  Future<void> _playTripNotificationSound() async {
    if (_isDisposed) return;
    try {
      audioPlayer.stop().then((_) async {
        if (!_isDisposed) {
          try {
            await audioPlayer.play(AssetSource('sounds/trip_notification.mp3'));
          } catch (e) {
            debugPrint('⚠️ Audio play error: $e');
          }
        }
      }).catchError((e) => debugPrint('⚠️ Audio stop error: $e'));
    } catch (e) {
      debugPrint('⚠️ Audio init error: $e');
    }
  }

  Future<void> _stopNotificationSound() async {
    if (_isDisposed) return;
    try {
      if (_isAudioPlaying) {
        audioPlayer.stop().catchError((e) => debugPrint('⚠️ Stop error: $e'));
      }
    } catch (e) {
      debugPrint('⚠️ Stop error: $e');
    }
  }

  Future<void> _restoreDriverState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasOnline = prefs.getBool('driver_was_online') ?? false;
      if (_isDisposed || !mounted) return;
      if (wasOnline && currentPosition != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposed) _toggleOnlineStatus();
        });
      }
    } catch (e) {
      debugPrint('⚠️ Restore state error: $e');
    }
  }

  void _startStatsRefresh() {
    statsRefreshTimer?.cancel();
    if (_isDisposed) return;
    statsRefreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted && !_isDisposed && _isAppActive) {
        _loadDriverStats();
      } else {
        statsRefreshTimer?.cancel();
      }
    });
  }

  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    if (_isDisposed || _isInBackground) return;
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isDisposed && mounted && _isAppActive) {
        if (isOnline && SocketService.instance.isConnected) {
          SocketService.instance.socket?.emit('driver:heartbeat', {
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      } else {
        _keepAliveTimer?.cancel();
        _keepAliveTimer = null;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isDisposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _isInBackground = false;
        _locationFailureCount = 0;
        _reconnectSocket();
        if (isOnline && mounted) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isDisposed && isOnline && _isAppActive) {
              _getCurrentLocation(isInitialFetch: true);
              _startLocationUpdates();
            }
          });
        }
        _startKeepAliveTimer();
        break;
      case AppLifecycleState.inactive:
        _isAppActive = false;
        break;
      case AppLifecycleState.paused:
        _isAppActive = false;
        _isInBackground = true;
        _stopLocationUpdates();
        _keepAliveTimer?.cancel();
        _keepAliveTimer = null;
        break;
      case AppLifecycleState.detached:
        _cleanup();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _connectSocket() async {
    if (_isDisposed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_uuid');
      final userType = prefs.getString('user_type');
      if (accessToken == null || userId == null || userType == null) return;
      String socketUrl = apiBaseUrl;
      if (socketUrl.contains('/api')) {
        socketUrl = socketUrl.substring(0, socketUrl.indexOf('/api'));
      }
      await SocketService.instance.connect(
        url: socketUrl,
        accessToken: accessToken!,
        userId: userId,
        userType: userType,
      );
    } catch (e) {
      debugPrint('❌ Socket error: $e');
    }
  }

  void _setupSocketListeners() {
    _tripOfferSub?.cancel();
    _tripCanceledSub?.cancel();
    _tripMatchedSub?.cancel();
    _socketConnectionSub?.cancel();
    if (_isDisposed) return;

    final s = SocketService.instance;

    _socketConnectionSub = s.connectionStateStream.listen((connected) {
      if (_isDisposed || !mounted) return;
      if (connected) {
        reconnectAttempts = 0;
        if (isOnline && currentPosition != null && _isAppActive) _emitDriverOnline();
      } else {
        _handleSocketDisconnection();
      }
    });

    _tripOfferSub = s.tripOfferStream.listen((data) {
      if (_isDisposed || !mounted) return;
      _handleTripOffer(data);
    });

    _tripCanceledSub = s.tripCanceledStream.listen((data) {
      if (_isDisposed || !mounted) return;
      _handleTripCanceled(data);
    });

    _tripMatchedSub = s.tripMatchedStream.listen((data) {
      if (_isDisposed || !mounted) return;
      _handleTripMatched(data);
    });
  }

  void _handleSocketDisconnection() {
    if (!mounted || _isDisposed) return;
    if (reconnectAttempts < maxReconnectAttempts) {
      reconnectAttempts++;
      Future.delayed(Duration(seconds: 2 * reconnectAttempts), () {
        if (mounted && !_isDisposed && _isAppActive) _reconnectSocket();
      });
    }
  }

  void _reconnectSocket() {
    if (_isDisposed) return;
    SocketService.instance.reconnect();
  }

  void _handleTripOffer(Map<String, dynamic> offer) {
    if (_isDisposed || !mounted) return;
    final isDashboardCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isDashboardCurrent || !isOnline || currentTrip != null || activeTripOffer != null) return;

    setState(() => activeTripOffer = offer);
    _playTripNotificationSound();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripRequestScreen(
          offer: offer,
          onAccept: _acceptTrip,
          onDecline: _declineTrip,
        ),
      ),
    ).then((_) {
      _stopNotificationSound();
      if (mounted && !_isDisposed) setState(() => activeTripOffer = null);
    });
  }

  void _handleTripCanceled(Map<String, dynamic> data) {
    if (_isDisposed || !mounted) return;
    final canceledTripId = data['tripId']?.toString();
    if (activeTripOffer != null &&
        activeTripOffer!['tripId']?.toString() == canceledTripId) {
      setState(() => activeTripOffer = null);
      _stopNotificationSound();
      _showSnackBar('Trip was canceled by passenger', SnackBarType.info);
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
    if (currentTrip != null && currentTrip!['uuid']?.toString() == canceledTripId) {
      setState(() => currentTrip = null);
      _showSnackBar('Your current trip was canceled', SnackBarType.warning);
    }
  }

  void _handleTripMatched(Map<String, dynamic> data) {
    if (_isDisposed || !mounted) return;
    setState(() { currentTrip = data; activeTripOffer = null; });
    _stopNotificationSound();
    _showSnackBar('Trip matched!', SnackBarType.success);
  }

  Future<String?> _getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    } catch (e) {
      return null;
    }
  }

  Future<bool> _acceptTrip(Map<String, dynamic> offer) async {
    try {
      final token = await _getAccessToken();
      final tripId = offer['tripId'] ?? offer['id'];

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      _stopNotificationSound();
      if (mounted && !_isDisposed) setState(() => activeTripOffer = null);
      if (mounted) _showSnackBar('Accepting trip...', SnackBarType.info);

      final response = await http.post(
        Uri.parse('$apiBaseUrl/driver/trips/$tripId/accept'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tripData = Map<String, dynamic>.from(data['data']['trip'] ?? {});
        final passengerData = Map<String, dynamic>.from(data['data']['passenger'] ?? {});

        SocketService.instance.socket?.emit('trip:accept', {
          'tripId': tripId,
          'driverId': tripData['driver_id'] ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        });

        if (mounted && !_isDisposed) {
          setState(() { currentTrip = tripData; activeTripOffer = null; });
        }
        if (mounted) _showSnackBar('Trip accepted!', SnackBarType.success);

        if (mounted && !_isDisposed) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted && !_isDisposed) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverEnRouteScreen(
                  tripId: tripId.toString(),
                  trip: tripData,
                  passenger: passengerData,
                ),
              ),
            ).then((_) {
              // ✅ Driver returned from trip flow (completed OR cancelled)
              // Clear trip state and re-sync with server
              if (mounted && !_isDisposed) {
                setState(() => currentTrip = null);
                _checkCurrentTrip();  // re-fetch in case trip is still active
                _loadDriverStats();   // refresh earnings
              }
            });
          }
        }
        return true;
      } else if (response.statusCode == 409) {
        final data = json.decode(response.body);
        if (mounted) _showSnackBar(data['message'] ?? 'Trip no longer available', SnackBarType.warning);
        return false;
      } else {
        if (mounted) _showSnackBar('Failed to accept trip (${response.statusCode})', SnackBarType.error);
        return false;
      }
    } on TimeoutException {
      if (mounted) _showSnackBar('Request timeout. Please try again.', SnackBarType.error);
      return false;
    } catch (e) {
      if (mounted) _showSnackBar('An error occurred', SnackBarType.error);
      return false;
    }
  }

  Future<void> _declineTrip(Map<String, dynamic> offer) async {
    if (_isDisposed) return;
    final tripId = (offer['tripId'] ?? offer['id'] ?? offer['uuid'])?.toString();
    if (tripId == null || tripId.isEmpty) return;

    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    _stopNotificationSound();
    if (mounted && !_isDisposed) setState(() => activeTripOffer = null);

    http.post(
      Uri.parse('$apiBaseUrl/driver/trips/$tripId/decline'),
      headers: {
        'Authorization': 'Bearer ${accessToken ?? ''}',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10)).then((r) {
      if (r.statusCode == 200) {
        SocketService.instance.socket?.emit('trip:decline', {
          'tripId': tripId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }).catchError((e) => debugPrint('⚠️ Decline error: $e'));

    if (mounted) _showSnackBar('Trip declined', SnackBarType.info);
  }

  Future<void> _toggleOnlineStatus() async {
    if (isLoading || _isDisposed || !_isAppActive) return;
    if (mounted) setState(() => isLoading = true);

    try {
      if (!isOnline) {
        if (currentPosition == null) await _getCurrentLocation(isInitialFetch: true);
        if (currentPosition == null) throw Exception('Unable to get location');
        if (_isDisposed || !mounted) return;

        final response = await http.post(
          Uri.parse('$apiBaseUrl/driver/online'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'lat': currentPosition!.latitude,
            'lng': currentPosition!.longitude,
            'heading': currentPosition!.heading,
          }),
        ).timeout(const Duration(seconds: 15));

        if (_isDisposed || !mounted) return;

        if (response.statusCode == 200) {
          setState(() => isOnline = true);
          _toggleController.forward();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('driver_was_online', true);
          _emitDriverOnline();
          if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
          if (_isAppActive) _startLocationUpdates();
          _showSnackBar('You are now online!', SnackBarType.success);
        } else {
          throw Exception('Failed: ${response.statusCode}');
        }
      } else {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/driver/offline'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        if (_isDisposed || !mounted) return;

        if (response.statusCode == 200) {
          setState(() => isOnline = false);
          _toggleController.reverse();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('driver_was_online', false);
          SocketService.instance.socket?.emit('driver:offline', {
            'timestamp': DateTime.now().toIso8601String(),
          });
          _pulseController.stop();
          _pulseController.reset();
          _stopLocationUpdates();
          _showSnackBar('You are now offline.', SnackBarType.info);
        } else {
          throw Exception('Failed: ${response.statusCode}');
        }
      }
    } on TimeoutException {
      if (mounted) _showSnackBar('Request timeout.', SnackBarType.error);
    } catch (e) {
      if (mounted) _showSnackBar('Failed to update status', SnackBarType.error);
    } finally {
      if (mounted && !_isDisposed) setState(() => isLoading = false);
    }
  }

  void _emitDriverOnline() {
    if (_isDisposed || currentPosition == null) return;
    SocketService.instance.socket?.emit('driver:online', {
      'lat': currentPosition!.latitude,
      'lng': currentPosition!.longitude,
      'heading': currentPosition!.heading,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _getCurrentLocation({bool isInitialFetch = false}) async {
    if (_isDisposed || (!_isAppActive && !isInitialFetch)) return;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (_isDisposed) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        forceAndroidLocationManager: false,
      ).timeout(isInitialFetch
          ? const Duration(seconds: 15)
          : const Duration(seconds: 10));
      if (_isDisposed) return;
      _locationFailureCount = 0;
      if (mounted) setState(() {});
    } catch (e) {
      _locationFailureCount++;
      if (_locationFailureCount >= _maxLocationFailures) await _tryGetLastKnownLocation();
    }
  }

  Future<void> _tryGetLastKnownLocation() async {
    if (_isDisposed) return;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && !_isDisposed) {
        currentPosition = last;
        _locationFailureCount = 0;
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Last known location error: $e');
    }
  }

  void _startLocationUpdates() {
    locationTimer?.cancel();
    locationTimer = null;
    _isLocationUpdateInProgress = false;
    _lastLocationUpdate = null;
    _locationFailureCount = 0;
    if (_isDisposed || !_isAppActive) return;

    locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!isOnline || !mounted || _isDisposed || !_isAppActive || _isInBackground) {
        _stopLocationUpdates();
        return;
      }
      if (_isLocationUpdateInProgress) return;
      if (_lastLocationUpdate != null &&
          DateTime.now().difference(_lastLocationUpdate!).inSeconds < 8) return;

      _isLocationUpdateInProgress = true;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          forceAndroidLocationManager: false,
        ).timeout(const Duration(seconds: 8), onTimeout: () async {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) return last;
          throw TimeoutException('Location timeout');
        });

        if (!mounted || _isDisposed || !isOnline || !_isAppActive) return;

        currentPosition = pos;
        _lastLocationUpdate = DateTime.now();
        _locationFailureCount = 0;
        _sendLocationToServer(pos);

        if (isOnline && !_isDisposed && _isAppActive) {
          SocketService.instance.socket?.emit('driver:location', {
            'lat': pos.latitude,
            'lng': pos.longitude,
            'heading': pos.heading,
            'speed': pos.speed,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        _locationFailureCount++;
        if (_locationFailureCount >= _maxLocationFailures) {
          _stopLocationUpdates();
          if (mounted) _showSnackBar('Location updates paused.', SnackBarType.warning);
        }
      } finally {
        _isLocationUpdateInProgress = false;
      }
    });
  }

  Future<void> _sendLocationToServer(Position pos) async {
    if (_isDisposed || !_isAppActive) return;
    try {
      http.post(
        Uri.parse('$apiBaseUrl/driver/location'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'heading': pos.heading,
          'speed': pos.speed,
          'accuracy': pos.accuracy,
        }),
      ).timeout(const Duration(seconds: 5)).then((r) {
        debugPrint('📤 Location sent: ${r.statusCode}');
      }).catchError((e) => debugPrint('⚠️ Location server error: $e'));
    } catch (e) {
      debugPrint('⚠️ Send location error: $e');
    }
  }

  void _stopLocationUpdates() {
    locationTimer?.cancel();
    locationTimer = null;
    _isLocationUpdateInProgress = false;
    _lastLocationUpdate = null;
  }

  Future<void> _loadDriverStats() async {
    if (_isDisposed || !_isAppActive) return;
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/driver/stats'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 10));
      if (_isDisposed || !mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stats = data['data'];
        if (mounted && !_isDisposed) {
          setState(() {
            todayEarnings = (stats['today']['earnings'] ?? 0).toDouble();
            tripsToday = stats['today']['trips'] ?? 0;
            weekEarnings = (stats['week']['earnings'] ?? 0).toDouble();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Stats error: $e');
    }
  }

  Future<void> _checkCurrentTrip() async {
    if (_isDisposed) return;
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/driver/current-trip'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 10));
      if (_isDisposed || !mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final trip = data['data']['currentTrip'];
        if (trip != null && mounted && !_isDisposed) {
          setState(() => currentTrip = trip);
        }
      }
    } catch (e) {
      debugPrint('❌ Trip check error: $e');
    }
  }

  void _cleanup() {
    _stopLocationUpdates();
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    statsRefreshTimer?.cancel();
    statsRefreshTimer = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isAppActive = false;
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _toggleController.dispose();
    _fadeInController.dispose();
    mapController?.dispose();
    mapController = null;
    locationTimer?.cancel();
    statsRefreshTimer?.cancel();
    _keepAliveTimer?.cancel();
    _tripOfferSub?.cancel();
    _tripCanceledSub?.cancel();
    _tripMatchedSub?.cancel();
    _socketConnectionSub?.cancel();
    try {
      audioPlayer.stop();
      audioPlayer.dispose();
    } catch (e) {
      debugPrint('⚠️ Audio dispose error: $e');
    }
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good morning';
    if (h >= 12 && h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getAvatarLetter() =>
      (driverFirstName?.isNotEmpty ?? false)
          ? driverFirstName![0].toUpperCase()
          : 'D';

  /// Formats a UUID for display: first 8 chars uppercase
  String _formatTripId(Map<String, dynamic> trip) {
    // ✅ Tries id, uuid, tripId, trip_id in order
    final raw = (trip['id'] ?? trip['uuid'] ?? trip['tripId'] ?? trip['trip_id'])
        ?.toString() ?? '';
    if (raw.isEmpty) return 'Unknown';
    return '#${raw.substring(0, raw.length >= 8 ? 8 : raw.length).toUpperCase()}';
  }

  void _showSnackBar(String message, SnackBarType type) {
    if (!mounted || _isDisposed) return;
    Color bg;
    IconData icon;
    switch (type) {
      case SnackBarType.success: bg = AppColors.success; icon = Icons.check_circle; break;
      case SnackBarType.error:   bg = AppColors.error;   icon = Icons.error;         break;
      case SnackBarType.info:    bg = AppColors.info;    icon = Icons.info;           break;
      case SnackBarType.warning: bg = AppColors.warning; icon = Icons.warning;        break;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: AppTypography.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) return _buildLoadingScreen();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: FadeTransition(
        opacity: _fadeInAnimation,
        child: RefreshIndicator(
          color: AppColors.primaryGold,
          backgroundColor: AppColors.primaryDark,
          onRefresh: () async {
            _locationFailureCount = 0;
            if (isOnline && locationTimer == null) _startLocationUpdates();
            await _loadDriverStats();
            if (!_isDisposed && mounted) await _checkCurrentTrip();
            if (!_isDisposed && mounted && isOnline) await _getCurrentLocation();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildDarkHeader(),
                _buildBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading screen ──────────────────────────────────────────────
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primaryGold),
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Loading dashboard…',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  // ── Dark header panel ───────────────────────────────────────────
  Widget _buildDarkHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: avatar + greeting + notification ──────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          driverFirstName ?? 'Driver',
                          style: AppTypography.headlineMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification bell
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Online/Offline toggle ──────────────────────────
              _buildToggleCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Driver avatar ───────────────────────────────────────────────
  Widget _buildAvatar() {
    final letter = _getAvatarLetter();
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isOnline ? AppColors.success : AppColors.primaryGold,
              width: 2.5,
            ),
          ),
          child: ClipOval(
            child: hasAvatar
                ? CachedNetworkImage(
              imageUrl: avatarUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => _avatarFallback(letter),
              errorWidget: (_, __, ___) => _avatarFallback(letter),
            )
                : _avatarFallback(letter),
          ),
        ),
        // Online indicator dot
        Positioned(
          bottom: 2,
          right: 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.success : AppColors.secondaryGrey,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0A0A0A), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String letter) {
    return Container(
      color: AppColors.primaryDark,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTypography.headlineMedium.copyWith(
          color: AppColors.primaryGold,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ── Toggle card ─────────────────────────────────────────────────
  Widget _buildToggleCard() {
    return GestureDetector(
      onTap: _toggleOnlineStatus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: isOnline
              ? const LinearGradient(
            colors: [Color(0xFF1B6B3A), Color(0xFF22C55E)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
              : LinearGradient(
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOnline
                ? Colors.green.withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Status icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isOnline
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isOnline ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                color: isOnline ? Colors.white : Colors.white38,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'You are Online' : 'You are Offline',
                    style: AppTypography.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isOnline
                        ? 'Ready to receive trip requests'
                        : 'Tap to go online and start earning',
                    style: AppTypography.bodySmall.copyWith(
                      color: isOnline ? Colors.white70 : Colors.white30,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle switch visual
            if (isLoading)
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else
              _buildToggleSwitch(),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      width: 52,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isOnline ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOnline ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isOnline ? Colors.white : Colors.white38,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Light body section ──────────────────────────────────────────
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        children: [
          // Active trip banner
          if (currentTrip != null) ...[
            _buildActiveTripCard(),
            const SizedBox(height: 20),
          ],

          // Stats row
          _buildStatsRow(),
          const SizedBox(height: 20),

          // Status info card
          _buildStatusInfoCard(),
        ],
      ),
    );
  }

  // ── Active trip card ─────────────────────────────────────────────
  Widget _buildActiveTripCard() {
    // ✅ Trip ID correctly fetched using multiple fallbacks
    final tripIdDisplay = _formatTripId(currentTrip!);

    // Attempt to get passenger name from nested data
    final passenger = currentTrip!['passenger'] as Map<String, dynamic>?;
    final passengerName = passenger != null
        ? '${passenger['first_name'] ?? ''} ${passenger['last_name'] ?? ''}'.trim()
        : null;

    final pickupAddress = currentTrip!['pickupAddress']?.toString()
        ?? currentTrip!['pickup_address']?.toString()
        ?? '';

    return GestureDetector(
      onTap: () {
        // ✅ Navigate to en-route / active trip screen on tap
        if (currentTrip != null) {
          final tripId = (currentTrip!['id'] ?? currentTrip!['uuid']
              ?? currentTrip!['tripId'])?.toString() ?? '';
          final passengerMap = Map<String, dynamic>.from(
              currentTrip!['passenger'] as Map? ?? {});
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriverEnRouteScreen(
                tripId: tripId,
                trip: currentTrip!,
                passenger: passengerMap,
              ),
            ),
          ).then((_) {
            // ✅ Driver returned from active trip (completed OR cancelled)
            if (mounted && !_isDisposed) {
              setState(() => currentTrip = null);
              _checkCurrentTrip();  // re-sync with server
              _loadDriverStats();   // refresh earnings
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primaryGold.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGold.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Pulsing icon
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_taxi_rounded,
                  color: AppColors.primaryGold,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Trip info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Active Trip',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tripIdDisplay,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (passengerName != null && passengerName.isNotEmpty)
                    Text(
                      passengerName,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else if (pickupAddress.isNotEmpty)
                    Text(
                      pickupAddress,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primaryDark,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard(
          label: 'Today',
          value: '${todayEarnings.toInt()}',
          unit: 'XAF',
          icon: Icons.account_balance_wallet_rounded,
          accent: AppColors.primaryGold,
          bg: AppColors.primaryDark,
          valueColor: Colors.white,
          labelColor: Colors.white54,
        ),
        const SizedBox(width: 10),
        _statCard(
          label: 'Trips',
          value: '$tripsToday',
          unit: 'today',
          icon: Icons.route_rounded,
          accent: AppColors.info,
          bg: AppColors.backgroundWhite,
          valueColor: AppColors.textPrimary,
          labelColor: AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        _statCard(
          label: 'This week',
          value: '${weekEarnings.toInt()}',
          unit: 'XAF',
          icon: Icons.trending_up_rounded,
          accent: AppColors.success,
          bg: AppColors.backgroundWhite,
          valueColor: AppColors.textPrimary,
          labelColor: AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color accent,
    required Color bg,
    required Color valueColor,
    required Color labelColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(bg == AppColors.primaryDark ? 0.2 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTypography.headlineMedium.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: AppTypography.labelSmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(color: labelColor),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status info card ─────────────────────────────────────────────
  Widget _buildStatusInfoCard() {
    final locationText = currentPosition != null
        ? '${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)}'
        : 'Locating…';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          _statusRow(
            icon: Icons.circle,
            iconColor: isOnline ? AppColors.success : AppColors.secondaryGrey,
            label: isOnline ? 'Online — accepting trips' : 'Offline',
            trailing: isOnline
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('LIVE',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  )),
            )
                : null,
          ),

          const SizedBox(height: 14),
          Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: 14),

          _statusRow(
            icon: Icons.location_on_rounded,
            iconColor: AppColors.info,
            label: locationText,
          ),

          const SizedBox(height: 14),
          Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: 14),

          _statusRow(
            icon: Icons.wifi_rounded,
            iconColor: SocketService.instance.isConnected
                ? AppColors.success
                : AppColors.error,
            label: SocketService.instance.isConnected
                ? 'Connected to server'
                : 'Disconnected',
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}

enum SnackBarType { success, error, info, warning }
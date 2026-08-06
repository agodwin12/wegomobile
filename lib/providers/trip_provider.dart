// lib/providers/trip_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wego_v1/core/config.dart';

import '../service/socket_service.dart';

enum TripStatus {
  idle,
  searching,
  matched,
  driverEnRoute,
  arrivedPickup,
  inProgress,
  completed,
  canceled,
}

class TripProvider with ChangeNotifier {
  final SocketService _socketService = SocketService();

  // ✅ Navigation callback for driver assignment
  void Function(Map<String, dynamic> driverData, Map<String, dynamic>? driverLocation)? onDriverAssigned;

  // Trip state
  TripStatus _status = TripStatus.idle;
  Map<String, dynamic>? _currentTrip;
  Map<String, dynamic>? _driver;
  Map<String, dynamic>? _driverLocation;
  String? _errorMessage;
  bool _isLoading = false;

  // Stream subscriptions
  StreamSubscription? _driverAssignedSub;
  StreamSubscription? _statusChangedSub;
  StreamSubscription? _canceledSub;
  StreamSubscription? _noShowSub;
  StreamSubscription? _noDriversSub;
  StreamSubscription? _driverLocationSub;
  StreamSubscription? _errorSub;
  StreamSubscription<bool>? _connectionSub;

  // Guards a resync so a flapping connection can't stack refetches.
  bool _resyncing = false;

  // Getters
  TripStatus get status => _status;
  Map<String, dynamic>? get currentTrip => _currentTrip;
  Map<String, dynamic>? get driver => _driver;
  Map<String, dynamic>? get driverLocation => _driverLocation;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get hasActiveTrip =>
      _currentTrip != null &&
          _status != TripStatus.idle &&
          _status != TripStatus.completed &&
          _status != TripStatus.canceled;

  TripProvider() {
    _initializeSocketListeners();
  }

  /// Cancels every stream subscription. Safe to call repeatedly.
  void _cancelSubs() {
    _driverAssignedSub?.cancel();
    _statusChangedSub?.cancel();
    _canceledSub?.cancel();
    _noShowSub?.cancel();
    _noDriversSub?.cancel();
    _driverLocationSub?.cancel();
    _errorSub?.cancel();
    _connectionSub?.cancel();
  }

  /// (Re)initialize all socket event listeners. Idempotent — cancels any
  /// existing subscriptions first — so it can be called again after logout or
  /// a mode switch to bring a dead pipeline back to life.
  void _initializeSocketListeners() {
    _cancelSubs();
    debugPrint('🎧 [TRIP_PROVIDER] (Re)initializing socket listeners...');

    // On every reconnect, the events that fired while we were offline are
    // gone. Re-fetch the authoritative trip state so the screen can't sit on
    // a stale "searching" or miss a driver-arrived it never received.
    _connectionSub = _socketService.connectionStream.listen((connected) {
      if (connected && hasActiveTrip) {
        debugPrint('🔌 [TRIP_PROVIDER] Reconnected — resyncing active trip');
        resyncActiveTrip();
      }
    });

    // ═══════════════════════════════════════════════════════════════
    // DRIVER ASSIGNED (PASSENGER)
    // ═══════════════════════════════════════════════════════════════
    _driverAssignedSub = _socketService.tripAssignedStream.listen((data) {
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ [TRIP_PROVIDER] Driver assigned event received');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📦 [TRIP_PROVIDER] Full data:');
      debugPrint(const JsonEncoder.withIndent('  ').convert(data));
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      _driver = data['driver'] as Map<String, dynamic>?;
      _driverLocation = data['driverLocation'] as Map<String, dynamic>?;

      if (_driver != null) {
        debugPrint('👤 [TRIP_PROVIDER] Driver: ${_driver!['name']}');
        final vehicle = _driver!['vehicle'] as Map<String, dynamic>?;
        if (vehicle != null) {
          debugPrint('   Plate: ${vehicle['plate']}');
          debugPrint('   Make/Model: ${vehicle['makeModel']}');
          debugPrint('   Color: ${vehicle['color']}');
        }
      }

      if (data['trip'] != null) {
        _currentTrip = Map<String, dynamic>.from(data['trip']);
        debugPrint('📦 [TRIP_PROVIDER] Trip ID: ${_currentTrip!['id']}');
      }

      _status = TripStatus.matched;
      _errorMessage = null;
      notifyListeners();

      // Trigger navigation callback
      if (onDriverAssigned != null && _driver != null) {
        debugPrint('🚀 [TRIP_PROVIDER] Triggering navigation callback...');
        try {
          onDriverAssigned!(_driver!, _driverLocation);
          debugPrint('✅ [TRIP_PROVIDER] Navigation callback executed\n');
        } catch (e) {
          debugPrint('❌ [TRIP_PROVIDER] Navigation callback error: $e\n');
        }
      } else {
        debugPrint('⚠️ [TRIP_PROVIDER] Cannot navigate:');
        debugPrint('   Callback: ${onDriverAssigned != null ? "YES" : "NO"}');
        debugPrint('   Driver:   ${_driver != null ? "YES" : "NO"}\n');
      }
    });

    // ═══════════════════════════════════════════════════════════════
    // TRIP LIFECYCLE (driver arrived / started / completed / any status)
    // ═══════════════════════════════════════════════════════════════
    // SocketService funnels trip:driver_arrived, trip:started, trip:completed
    // and trip:status_changed all into tripStatusStream (with the full payload
    // spread in), and RE-REGISTERS them on every reconnect. Listening to the
    // broadcast stream — instead of the raw socket, which is null at startup
    // and replaced on every token-refresh reconnect — is what makes these
    // events survive a reconnect. Timestamps and finalFare ride along in the
    // same payload, so they are captured here too.
    _statusChangedSub = _socketService.tripStatusStream.listen((data) {
      final newStatus = data['status']?.toString() ?? '';
      if (newStatus.isEmpty) return;

      debugPrint('🔄 [TRIP_PROVIDER] Lifecycle status: $newStatus');
      _updateStatus(newStatus);

      if (_currentTrip != null) {
        _currentTrip!['status'] = newStatus;
        // Capture the fields the dedicated handlers used to grab.
        for (final key in ['arrivedAt', 'startedAt', 'completedAt', 'finalFare']) {
          if (data[key] != null) _currentTrip![key] = data[key];
        }
      }

      notifyListeners();
    });

    // ═══════════════════════════════════════════════════════════════
    // TRIP CANCELED
    // ═══════════════════════════════════════════════════════════════
    _canceledSub = _socketService.tripCanceledStream.listen((data) {
      debugPrint('\n🚫 [TRIP_PROVIDER] Trip canceled!');
      debugPrint('📦 [TRIP_PROVIDER] Data: $data\n');

      _status = TripStatus.canceled;
      _errorMessage = data['reason']?.toString() ?? 'Trip was canceled';
      notifyListeners();

      Future.delayed(const Duration(seconds: 3), () {
        if (_status == TripStatus.canceled) clearTrip();
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // TRIP NO-SHOW (driver reported the passenger never showed up)
    // ═══════════════════════════════════════════════════════════════
    // Terminal, driver-initiated — same outcome as trip:canceled from the
    // passenger's point of view, so it reuses TripStatus.canceled to drive
    // the exact same UI handling (dialog + navigate off the active-trip
    // screen) that every screen's _checkTripStatus switch already has.
    _noShowSub = _socketService.tripNoShowStream.listen((data) {
      debugPrint('\n🚫 [TRIP_PROVIDER] Trip no-show reported by driver!');
      debugPrint('📦 [TRIP_PROVIDER] Data: $data\n');

      _status = TripStatus.canceled;
      _errorMessage = data['reason']?.toString() ??
          'Your driver reported you as a no-show';
      notifyListeners();

      Future.delayed(const Duration(seconds: 3), () {
        if (_status == TripStatus.canceled) clearTrip();
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // NO DRIVERS AVAILABLE
    // ═══════════════════════════════════════════════════════════════
    _noDriversSub = _socketService.noDriversStream.listen((data) {
      debugPrint('\n⚠️ [TRIP_PROVIDER] No drivers available');
      debugPrint('📦 [TRIP_PROVIDER] Data: $data\n');

      _status = TripStatus.idle;
      _errorMessage = data['message']?.toString() ?? 'No drivers available in your area';
      _currentTrip = null;
      _driver = null;
      _driverLocation = null;
      notifyListeners();
    });

    // ═══════════════════════════════════════════════════════════════
    // DRIVER LOCATION UPDATES
    // ═══════════════════════════════════════════════════════════════
    _driverLocationSub = _socketService.driverLocationStream.listen((data) {
      if (DateTime.now().second % 10 == 0) {
        debugPrint('📍 [TRIP_PROVIDER] Driver location: (${data['lat']}, ${data['lng']})');
      }

      _driverLocation = {
        'lat': data['lat'],
        'lng': data['lng'],
        'heading': data['heading'] ?? 0,
        'speed': data['speed'] ?? 0,
      };

      notifyListeners();
    });

    // ═══════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════
    _errorSub = _socketService.errorStream.listen((error) {
      debugPrint('\n❌ [TRIP_PROVIDER] Error: $error\n');
      _errorMessage = error;
      _isLoading = false;
      notifyListeners();
    });

    debugPrint('✅ [TRIP_PROVIDER] All socket listeners initialized\n');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATUS HELPER
  // ═══════════════════════════════════════════════════════════════════════

  void _updateStatus(String statusString) {
    final oldStatus = _status;

    switch (statusString.toLowerCase()) {
      case 'searching':
        _status = TripStatus.searching;
        break;
      case 'matched':
        _status = TripStatus.matched;
        break;
      case 'driver_en_route':
      case 'driver_assigned':
        _status = TripStatus.driverEnRoute;
        break;
      case 'driver_arrived':
      case 'arrived_pickup':
        _status = TripStatus.arrivedPickup;
        break;
      case 'in_progress':
        _status = TripStatus.inProgress;
        break;
      case 'completed':
        _status = TripStatus.completed;
        break;
      case 'canceled':
        _status = TripStatus.canceled;
        break;
      default:
        debugPrint('⚠️ [TRIP_PROVIDER] Unknown status: $statusString');
    }

    if (oldStatus != _status) {
      debugPrint('📊 [TRIP_PROVIDER] Status: $oldStatus → $_status');
    }
  }

  /// Clears trip state (called on logout). Crucially it then RE-SUBSCRIBES:
  /// the provider is a single app-root instance that survives logout→login, so
  /// if it left the streams cancelled the next ride in the same app run would
  /// never receive driver-assigned / status / cancel events and would hang on
  /// "searching" forever.
  void reset() {
    debugPrint('🔄 [TRIP_PROVIDER] Resetting state and re-arming listeners...');

    _status         = TripStatus.idle;
    _currentTrip    = null;
    _driver         = null;
    _driverLocation = null;
    _errorMessage   = null;
    _isLoading      = false;
    onDriverAssigned = null;

    _initializeSocketListeners(); // cancels + re-subscribes
    notifyListeners();
    debugPrint('✅ [TRIP_PROVIDER] Reset complete (pipeline live)');
  }

  /// Re-fetches the authoritative trip state from the server and reconciles it
  /// into the provider. Used after a socket reconnect so events missed while
  /// offline (driver-arrived, started, completed, cancel) don't leave the UI
  /// stale. Never throws — a failed resync simply leaves current state.
  Future<void> resyncActiveTrip() async {
    if (_resyncing) return;
    _resyncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) return;

      final resp = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/trips/active'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return;
      final body = jsonDecode(resp.body);
      final trip = body['data']?['trip'];

      if (trip == null) {
        // The server says there is no live trip — it ended while we were
        // offline. Settle to a terminal state instead of spinning forever.
        if (hasActiveTrip) {
          _status = TripStatus.completed;
          notifyListeners();
        }
        return;
      }

      final status = (trip['status'] ?? '').toString();
      _currentTrip = Map<String, dynamic>.from(trip as Map);
      if (trip['driver'] is Map) {
        _driver = Map<String, dynamic>.from(trip['driver'] as Map);
      }
      if (status.isNotEmpty) _updateStatus(status);
      notifyListeners();
      debugPrint('✅ [TRIP_PROVIDER] Resynced trip → $status');
    } catch (e) {
      debugPrint('ℹ️ [TRIP_PROVIDER] Resync skipped: $e');
    } finally {
      _resyncing = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SUBMIT RATING
  // ═══════════════════════════════════════════════════════════════════════

  Future<bool> submitRating({
    required String tripId,
    required int stars,
    String? comment,
  }) async {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('⭐ [TRIP_PROVIDER] Submitting rating...');
    debugPrint('   Trip: $tripId | Stars: $stars');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    if (stars < 1 || stars > 5) {
      _errorMessage = 'Rating must be between 1 and 5 stars';
      notifyListeners();
      return false;
    }

    if (comment != null && comment.length > 500) {
      _errorMessage = 'Comment must be 500 characters or less';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        _errorMessage = 'Authentication required. Please log in again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final body = {
        'tripId': tripId,
        'stars': stars,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/ratings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      debugPrint('📥 [TRIP_PROVIDER] Rating response: ${response.statusCode}');

      _isLoading = false;

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ [TRIP_PROVIDER] Rating submitted successfully!');
        notifyListeners();
        return true;
      } else {
        final responseData = json.decode(response.body);
        _errorMessage = responseData['message'] ?? 'Failed to submit rating';
        notifyListeners();
        return false;
      }
    } on TimeoutException {
      _errorMessage = 'Request timed out. Please check your connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    } on http.ClientException {
      _errorMessage = 'Network error. Please check your internet connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ [TRIP_PROVIDER] Rating error: $e');
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PUBLIC METHODS
  // ═══════════════════════════════════════════════════════════════════════

  void setCurrentTrip(Map<String, dynamic> trip) {
    debugPrint('📝 [TRIP_PROVIDER] Setting current trip: ${trip['id']}');
    _currentTrip = trip;
    _status = TripStatus.searching;
    _errorMessage = null;
    _driver = null;
    _driverLocation = null;
    notifyListeners();
  }

  void updateTripStatus(String tripId, String status) {
    debugPrint('🔄 [TRIP_PROVIDER] Updating trip status to: $status');
    _socketService.updateTripStatus(tripId, status);
  }

  /// Cancels the trip through the HTTP endpoint, which is authoritative and
  /// works even when the socket is down. Returns true only when the SERVER
  /// confirms — the old version emitted over the socket (silently dropped
  /// while disconnected) and then optimistically told the passenger the ride
  /// was cancelled, so a cancel could "succeed" on screen while the driver was
  /// still on the way. The socket emit is kept as a best-effort fast path for
  /// instant realtime, but the HTTP result is what decides.
  Future<bool> cancelTrip(String tripId, String reason) async {
    debugPrint('🚫 [TRIP_PROVIDER] Canceling trip: $tripId | $reason');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Best-effort realtime nudge (no-op if disconnected).
    _socketService.cancelTrip(tripId, reason);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) {
        _isLoading = false;
        _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
        notifyListeners();
        return false;
      }

      final resp = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/trips/$tripId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason}),
      ).timeout(const Duration(seconds: 15));

      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (ok) {
        _status = TripStatus.canceled;
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Server refused (e.g. already started / too late). Do NOT lie — keep
      // the trip on screen and surface the reason.
      String msg = 'Impossible d\'annuler la course.';
      try {
        final body = jsonDecode(resp.body);
        if (body['message'] != null) msg = body['message'].toString();
      } catch (_) {}
      _isLoading = false;
      _errorMessage = msg;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Réseau indisponible. Réessayez.';
      notifyListeners();
      debugPrint('❌ [TRIP_PROVIDER] Cancel failed: $e');
      return false;
    }
  }

  void clearTrip() {
    debugPrint('🗑️ [TRIP_PROVIDER] Clearing trip data');
    _status = TripStatus.idle;
    _currentTrip = null;
    _driver = null;
    _driverLocation = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String error) {
    debugPrint('❌ [TRIP_PROVIDER] Error: $error');
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void updateDriverInfo(Map<String, dynamic> driver) {
    _driver = driver;
    notifyListeners();
  }

  void updateDriverLocation(Map<String, dynamic>? location) {
    _driverLocation = location;
    notifyListeners();
  }

  void setStatus(TripStatus status) {
    debugPrint('📊 [TRIP_PROVIDER] Manual status set: $status');
    _status = status;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATUS DISPLAY HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  String get statusText {
    switch (_status) {
      case TripStatus.idle:         return 'Ready to go';
      case TripStatus.searching:    return 'Finding a driver...';
      case TripStatus.matched:      return 'Driver found!';
      case TripStatus.driverEnRoute:return 'Driver is on the way';
      case TripStatus.arrivedPickup:return 'Driver has arrived';
      case TripStatus.inProgress:   return 'Trip in progress';
      case TripStatus.completed:    return 'Trip completed';
      case TripStatus.canceled:     return 'Trip canceled';
    }
  }

  String get statusColor {
    switch (_status) {
      case TripStatus.idle:         return 'gray';
      case TripStatus.searching:    return 'blue';
      case TripStatus.matched:      return 'green';
      case TripStatus.driverEnRoute:return 'orange';
      case TripStatus.arrivedPickup:return 'purple';
      case TripStatus.inProgress:   return 'yellow';
      case TripStatus.completed:    return 'green';
      case TripStatus.canceled:     return 'red';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    debugPrint('🗑️ [TRIP_PROVIDER] Disposing...');
    _cancelSubs(); // includes _connectionSub
    super.dispose();
  }
}
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
  StreamSubscription? _noDriversSub;
  StreamSubscription? _driverLocationSub;
  StreamSubscription? _errorSub;

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

  /// Initialize all socket event listeners
  void _initializeSocketListeners() {
    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🎧 [TRIP_PROVIDER] Initializing socket listeners...');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

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
    // DRIVER ARRIVED AT PICKUP
    // This is the key fix — trip:driver_arrived was never listened to
    // ═══════════════════════════════════════════════════════════════
    _socketService.socket?.on('trip:driver_arrived', (data) {
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📍 [TRIP_PROVIDER] Driver arrived at pickup!');
      debugPrint('📦 [TRIP_PROVIDER] Data: $data');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      _status = TripStatus.arrivedPickup;

      if (data is Map && _currentTrip != null) {
        _currentTrip!['arrivedAt'] = data['arrivedAt'];
        _currentTrip!['status'] = 'DRIVER_ARRIVED';
      }

      notifyListeners();
    });

    // ═══════════════════════════════════════════════════════════════
    // TRIP STARTED
    // ═══════════════════════════════════════════════════════════════
    _socketService.socket?.on('trip:started', (data) {
      debugPrint('\n🚀 [TRIP_PROVIDER] Trip started!');
      debugPrint('📦 [TRIP_PROVIDER] Data: $data\n');

      _status = TripStatus.inProgress;

      if (data is Map && _currentTrip != null) {
        _currentTrip!['startedAt'] = data['startedAt'];
        _currentTrip!['status'] = 'IN_PROGRESS';
      }

      notifyListeners();
    });

    // ═══════════════════════════════════════════════════════════════
    // TRIP COMPLETED
    // ═══════════════════════════════════════════════════════════════
    _socketService.socket?.on('trip:completed', (data) {
      debugPrint('\n✅ [TRIP_PROVIDER] Trip completed!');
      debugPrint('📦 [TRIP_PROVIDER] Data: $data\n');

      _status = TripStatus.completed;

      if (data is Map && _currentTrip != null) {
        _currentTrip!['completedAt'] = data['completedAt'];
        _currentTrip!['finalFare'] = data['finalFare'];
        _currentTrip!['status'] = 'COMPLETED';
      }

      notifyListeners();
    });

    // ═══════════════════════════════════════════════════════════════
    // GENERIC STATUS CHANGES (fallback for anything not handled above)
    // ═══════════════════════════════════════════════════════════════
    _statusChangedSub = _socketService.tripStatusStream.listen((data) {
      debugPrint('\n🔄 [TRIP_PROVIDER] Status changed event received');
      debugPrint('📦 [TRIP_PROVIDER] Data: $data\n');

      final newStatus = data['status']?.toString() ?? '';

      // Skip statuses handled by dedicated listeners above
      if (newStatus.isEmpty) return;

      _updateStatus(newStatus);

      if (_currentTrip != null) {
        _currentTrip!['status'] = newStatus;
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

  void cancelTrip(String tripId, String reason) {
    debugPrint('\n🚫 [TRIP_PROVIDER] Canceling trip: $tripId | Reason: $reason\n');
    _isLoading = true;
    notifyListeners();
    _socketService.cancelTrip(tripId, reason);
    _status = TripStatus.canceled;
    _errorMessage = 'Trip canceled';
    _isLoading = false;
    notifyListeners();
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
    _driverAssignedSub?.cancel();
    _statusChangedSub?.cancel();
    _canceledSub?.cancel();
    _noDriversSub?.cancel();
    _driverLocationSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }
}
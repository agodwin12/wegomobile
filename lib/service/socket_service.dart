// lib/service/socket_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

// ═══════════════════════════════════════════════════════════════════════
// SOCKET SERVICE - PRODUCTION READY
// ═══════════════════════════════════════════════════════════════════════

class SocketService {
  // ═══════════════════════════════════════════════════════════════
  // SINGLETON PATTERN
  // ═══════════════════════════════════════════════════════════════

  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  static SocketService get instance => _instance;

  // ═══════════════════════════════════════════════════════════════
  // PRIVATE PROPERTIES
  // ═══════════════════════════════════════════════════════════════

  IO.Socket? _socket;
  String? _userId;
  String? _userType;
  String? _currentToken;
  String? _serverUrl;
  bool _isConnected = false;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;

  Future<String?> Function()? _onTokenExpired;

  // ═══════════════════════════════════════════════════════════════
  // STREAM CONTROLLERS
  // ═══════════════════════════════════════════════════════════════

  final _connectionStateController = StreamController<bool>.broadcast();

  // Passenger events
  final _tripAssignedController       = StreamController<Map<String, dynamic>>.broadcast();
  final _tripStatusController         = StreamController<Map<String, dynamic>>.broadcast();
  final _tripCanceledController       = StreamController<Map<String, dynamic>>.broadcast();
  final _noDriversController          = StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocationController     = StreamController<Map<String, dynamic>>.broadcast();
  final _tripRequestExpiredController = StreamController<Map<String, dynamic>>.broadcast();

  // ✅ NEW: dedicated stream for driver arrived event
  final _driverArrivedController = StreamController<Map<String, dynamic>>.broadcast();

  // Driver events
  final _tripOfferController        = StreamController<Map<String, dynamic>>.broadcast();
  final _tripMatchedController      = StreamController<Map<String, dynamic>>.broadcast();
  final _tripAcceptSuccessController = StreamController<Map<String, dynamic>>.broadcast();
  final _tripAcceptFailedController  = StreamController<Map<String, dynamic>>.broadcast();

  // General events
  final _errorController   = StreamController<String>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  // ═══════════════════════════════════════════════════════════════
  // STREAM GETTERS
  // ═══════════════════════════════════════════════════════════════

  Stream<bool> get connectionStream      => _connectionStateController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  // Passenger streams
  Stream<Map<String, dynamic>> get tripAssignedStream       => _tripAssignedController.stream;
  Stream<Map<String, dynamic>> get tripStatusStream         => _tripStatusController.stream;
  Stream<Map<String, dynamic>> get tripCanceledStream       => _tripCanceledController.stream;
  Stream<Map<String, dynamic>> get noDriversStream          => _noDriversController.stream;
  Stream<Map<String, dynamic>> get driverLocationStream     => _driverLocationController.stream;
  Stream<Map<String, dynamic>> get tripRequestExpiredStream => _tripRequestExpiredController.stream;

  // ✅ NEW: driver arrived stream
  Stream<Map<String, dynamic>> get driverArrivedStream => _driverArrivedController.stream;

  // Driver streams
  Stream<Map<String, dynamic>> get tripOfferStream         => _tripOfferController.stream;
  Stream<Map<String, dynamic>> get tripMatchedStream       => _tripMatchedController.stream;
  Stream<Map<String, dynamic>> get newTripRequestStream    => _tripOfferController.stream;
  Stream<Map<String, dynamic>> get tripAcceptSuccessStream => _tripAcceptSuccessController.stream;
  Stream<Map<String, dynamic>> get tripAcceptFailedStream  => _tripAcceptFailedController.stream;

  // General streams
  Stream<String> get errorStream                       => _errorController.stream;
  Stream<Map<String, dynamic>> get messageStream       => _messageController.stream;

  // ═══════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════

  bool get isConnected      => _isConnected;
  bool get isReconnecting   => _isReconnecting;
  IO.Socket? get socket     => _socket;
  String? get userId        => _userId;
  String? get userType      => _userType;
  String? get socketId      => _socket?.id;
  int get reconnectAttempts => _reconnectAttempts;

  // ═══════════════════════════════════════════════════════════════
  // CONNECT
  // ═══════════════════════════════════════════════════════════════

  Future<void> connect({
    required String url,
    required String accessToken,
    required String userId,
    required String userType,
    Future<String?> Function()? onTokenExpired,
  }) async {
    if (_isConnected && _socket != null) {
      debugPrint('✅ [SOCKET] Already connected');
      return;
    }

    _userId           = userId;
    _userType         = userType;
    _currentToken     = accessToken;
    _serverUrl        = url;
    _onTokenExpired   = onTokenExpired;
    _reconnectAttempts = 0;

    try {
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔌 [SOCKET] Connecting to: $url');
      debugPrint('👤 [SOCKET] User ID: $_userId | Type: $_userType');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // Strip /api from URL — Socket.IO needs base server URL
      String baseUrl = url;
      if (url.contains('/api')) {
        baseUrl = url.substring(0, url.indexOf('/api'));
        debugPrint('⚠️ [SOCKET] Adjusted URL: $baseUrl\n');
      }

      final completer = Completer<void>();
      bool completed = false;

      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(5000)
            .setTimeout(20000)
            .setAuth({
          'token': accessToken,
          'userId': userId,
          'userType': userType,
        })
            .setExtraHeaders({'Authorization': 'Bearer $accessToken'})
            .build(),
      );

      _setupEventListeners();

      _socket!.once('connect', (_) {
        if (!completed) {
          completed = true;
          completer.complete();
        }
      });

      _socket!.once('connect_error', (error) {
        if (!completed) {
          completed = true;
          completer.completeError('Connection failed: $error');
        }
      });

      _socket!.connect();

      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (!_isConnected) throw Exception('Connection timeout');
        },
      );

      debugPrint('✅ [SOCKET] Connected successfully!\n');
    } catch (e, stackTrace) {
      debugPrint('❌ [SOCKET] Connection error: $e');
      debugPrint('Stack: $stackTrace\n');
      _isConnected = false;
      _errorController.add('Failed to connect: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // EVENT LISTENERS
  // ═══════════════════════════════════════════════════════════════

  void _setupEventListeners() {
    if (_socket == null) return;

    debugPrint('📡 [SOCKET] Setting up event listeners...');

    // ── CONNECTION ──────────────────────────────────────────────

    _socket!.onConnect((_) {
      _isConnected       = true;
      _isReconnecting    = false;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);

      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ [SOCKET] Connected!');
      debugPrint('🆔 Socket ID: ${_socket!.id}');
      debugPrint('👤 User: $_userType $_userId');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      _startHeartbeat();
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      _connectionStateController.add(false);
      _stopHeartbeat();
      debugPrint('\n⚠️ [SOCKET] Disconnected — Reason: $reason\n');
    });

    _socket!.onConnectError((error) {
      debugPrint('\n❌ [SOCKET] Connect error: $error\n');
      _errorController.add('Connection error: $error');
    });

    _socket!.onError((error) async {
      debugPrint('\n❌ [SOCKET] Error: $error');
      if (error is Map && error['message'] != null) {
        final msg = error['message'].toString();
        if (msg.contains('Authentication') ||
            msg.contains('expired') ||
            msg.contains('invalid') ||
            msg.contains('token')) {
          await _handleTokenExpiration();
        } else {
          _errorController.add(msg);
        }
      } else {
        _errorController.add('Socket error: $error');
      }
    });

    _socket!.onReconnect((attempt) {
      debugPrint('🔄 [SOCKET] Reconnected (attempt: $attempt)');
      _isReconnecting    = false;
      _reconnectAttempts = 0;
    });

    _socket!.onReconnecting((attempt) {
      debugPrint('🔄 [SOCKET] Reconnecting... (attempt: $attempt)');
      _isReconnecting    = true;
      _reconnectAttempts = attempt;
    });

    _socket!.onReconnectError((error) {
      debugPrint('❌ [SOCKET] Reconnect error: $error');
    });

    _socket!.onReconnectFailed((_) {
      debugPrint('❌ [SOCKET] Reconnection failed');
      _errorController.add('Failed to reconnect. Please check your connection.');
    });

    // ── SYSTEM ───────────────────────────────────────────────────

    _socket!.on('connection:success', (data) {
      debugPrint('✅ [SOCKET] Server confirmed connection: $data');
    });

    _socket!.on('pong', (_) {
      debugPrint('💓 [SOCKET] Heartbeat pong');
    });

    // ── PASSENGER EVENTS ─────────────────────────────────────────

    _socket!.on('trip:driver_assigned', (data) {
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ [SOCKET] trip:driver_assigned received');
      debugPrint('📦 [DATA]: $data');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      if (data is Map) {
        _tripAssignedController.add(Map<String, dynamic>.from(data));
      }
    });

    // ✅ KEY FIX: trip:driver_arrived was missing — now handled properly
    _socket!.on('trip:driver_arrived', (data) {
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📍 [SOCKET] trip:driver_arrived received');
      debugPrint('📦 [DATA]: $data');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      if (data is Map) {
        // Push to dedicated stream (TripProvider listens here)
        _driverArrivedController.add(Map<String, dynamic>.from(data));
        // Also push to status stream as fallback with status field set
        _tripStatusController.add({
          ...Map<String, dynamic>.from(data),
          'status': 'DRIVER_ARRIVED',
        });
      }
    });

    _socket!.on('trip:status_changed', (data) {
      debugPrint('\n🔄 [SOCKET] trip:status_changed: $data\n');
      if (data is Map) {
        _tripStatusController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip:started', (data) {
      debugPrint('\n🚀 [SOCKET] trip:started: $data\n');
      if (data is Map) {
        _tripStatusController.add({
          ...Map<String, dynamic>.from(data),
          'status': 'IN_PROGRESS',
        });
      }
    });

    _socket!.on('trip:completed', (data) {
      debugPrint('\n✅ [SOCKET] trip:completed: $data\n');
      if (data is Map) {
        _tripStatusController.add({
          ...Map<String, dynamic>.from(data),
          'status': 'COMPLETED',
        });
      }
    });

    _socket!.on('trip:canceled', (data) {
      debugPrint('\n🚫 [SOCKET] trip:canceled: $data\n');
      if (data is Map) {
        _tripCanceledController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip:no_drivers', (data) {
      debugPrint('\n⚠️ [SOCKET] trip:no_drivers: $data\n');
      if (data is Map) {
        _noDriversController.add(Map<String, dynamic>.from(data));
      } else {
        _noDriversController.add({'message': 'No drivers available in your area'});
      }
    });

    _socket!.on('trip:request_expired', (data) {
      debugPrint('\n⏰ [SOCKET] trip:request_expired: $data\n');
      if (data is Map) {
        _tripRequestExpiredController.add(Map<String, dynamic>.from(data));
      } else {
        _tripRequestExpiredController.add({
          'tripId': data,
          'message': 'Request expired. No drivers accepted.',
        });
      }
    });

    _socket!.on('driver:location_update', (data) {
      if (DateTime.now().second % 15 == 0) {
        debugPrint('📍 [SOCKET] driver:location_update received');
      }
      if (data is Map) {
        _driverLocationController.add(Map<String, dynamic>.from(data));
      }
    });

    // Legacy alias
    _socket!.on('driver:location', (data) {
      if (data is Map) {
        _driverLocationController.add(Map<String, dynamic>.from(data));
      }
    });

    // ── DRIVER EVENTS ────────────────────────────────────────────

    _socket!.on('trip:offer', (data) {
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🚨 [SOCKET] trip:offer received');
      debugPrint('📦 [DATA]: $data');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      if (data is Map) {
        _tripOfferController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip:new_request', (data) {
      debugPrint('\n🚨 [SOCKET] trip:new_request: $data\n');
      if (data is Map) {
        _tripOfferController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip:matched', (data) {
      debugPrint('\n✅ [SOCKET] trip:matched: $data\n');
      if (data is Map) {
        _tripMatchedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip:accept:success', (data) {
      debugPrint('\n✅ [SOCKET] trip:accept:success: $data\n');
      if (data is Map) {
        _tripAcceptSuccessController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip:accept:failed', (data) {
      debugPrint('\n❌ [SOCKET] trip:accept:failed: $data\n');
      if (data is Map) {
        _tripAcceptFailedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('trip:status:success', (data) {
      debugPrint('✅ [SOCKET] trip:status:success: $data');
    });

    _socket!.on('trip:cancel:success', (data) {
      debugPrint('✅ [SOCKET] trip:cancel:success: $data');
    });

    _socket!.on('trip:decline:success', (data) {
      debugPrint('✅ [SOCKET] trip:decline:success: $data');
    });

    // ── GENERIC ──────────────────────────────────────────────────

    _socket!.on('error', (data) {
      debugPrint('\n❌ [SOCKET] Error event: $data\n');
      if (data is Map) {
        _errorController.add(data['message']?.toString() ?? 'Unknown error');
      } else {
        _errorController.add(data.toString());
      }
    });

    _socket!.on('message', (data) {
      debugPrint('💬 [SOCKET] Message: $data');
      if (data is Map) {
        _messageController.add(Map<String, dynamic>.from(data));
      }
    });

    debugPrint('✅ [SOCKET] All event listeners registered\n');
  }

  // ═══════════════════════════════════════════════════════════════
  // HEARTBEAT
  // ═══════════════════════════════════════════════════════════════

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _socket != null) {
        _socket!.emit('ping');
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ═══════════════════════════════════════════════════════════════
  // TOKEN EXPIRATION HANDLER
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleTokenExpiration() async {
    if (_isReconnecting) return;
    _isReconnecting = true;

    try {
      debugPrint('🔄 [SOCKET] Token expired — attempting refresh...');

      if (_onTokenExpired == null) {
        _errorController.add('Session expired. Please login again.');
        disconnect();
        return;
      }

      final newToken = await _onTokenExpired!();
      if (newToken == null || newToken.isEmpty) {
        _errorController.add('Session expired. Please login again.');
        disconnect();
        return;
      }

      _currentToken = newToken;
      disconnect();
      await Future.delayed(const Duration(milliseconds: 500));

      if (_serverUrl != null && _userId != null && _userType != null) {
        await connect(
          url: _serverUrl!,
          accessToken: newToken,
          userId: _userId!,
          userType: _userType!,
          onTokenExpired: _onTokenExpired,
        );
      }
    } catch (e) {
      debugPrint('❌ [SOCKET] Token refresh error: $e');
      _errorController.add('Session expired. Please login again.');
      disconnect();
    } finally {
      _isReconnecting = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // EMIT METHODS
  // ═══════════════════════════════════════════════════════════════

  void emitDriverOnline({
    required double lat,
    required double lng,
    double heading = 0,
    double speed = 0,
  }) {
    if (!_canEmit('driver:online')) return;
    _socket!.emit('driver:online', {
      'lat': lat, 'lng': lng,
      'heading': heading, 'speed': speed,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void emitDriverOffline() {
    if (!_canEmit('driver:offline')) return;
    _socket!.emit('driver:offline', {'timestamp': DateTime.now().toIso8601String()});
  }

  void updateDriverLocation({
    required double lat,
    required double lng,
    double heading = 0,
    double speed = 0,
  }) {
    if (!_canEmit('driver:location', silent: true)) return;
    _socket!.emit('driver:location', {
      'lat': lat, 'lng': lng,
      'heading': heading, 'speed': speed,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void acceptTrip(String tripId) {
    if (!_canEmit('trip:accept')) return;
    debugPrint('📤 [SOCKET] trip:accept — $tripId');
    _socket!.emit('trip:accept', {
      'tripId': tripId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void declineTrip(String tripId, {String? reason}) {
    if (!_canEmit('trip:decline')) return;
    debugPrint('📤 [SOCKET] trip:decline — $tripId');
    _socket!.emit('trip:decline', {
      'tripId': tripId,
      'reason': reason ?? 'Driver declined',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void arrivedAtPickup(String tripId) {
    if (!_canEmit('trip:arrived')) return;
    debugPrint('📤 [SOCKET] trip:arrived — $tripId');
    _socket!.emit('trip:arrived', {
      'tripId': tripId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void startTrip(String tripId) {
    if (!_canEmit('trip:start')) return;
    debugPrint('📤 [SOCKET] trip:start — $tripId');
    _socket!.emit('trip:start', {
      'tripId': tripId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void completeTrip(String tripId, {double? finalFare}) {
    if (!_canEmit('trip:complete')) return;
    debugPrint('📤 [SOCKET] trip:complete — $tripId');
    _socket!.emit('trip:complete', {
      'tripId': tripId,
      'finalFare': finalFare,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void cancelTrip(String tripId, String reason) {
    if (!_canEmit('trip:cancel')) return;
    debugPrint('📤 [SOCKET] trip:cancel — $tripId');
    _socket!.emit('trip:cancel', {
      'tripId': tripId,
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void updateTripStatus(String tripId, String status) {
    if (!_canEmit('trip:update_status')) return;
    debugPrint('📤 [SOCKET] trip:update_status — $tripId → $status');
    _socket!.emit('trip:update_status', {
      'tripId': tripId,
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void sendTripMessage(String tripId, String message) {
    if (!_canEmit('trip:message')) return;
    _socket!.emit('trip:message', {
      'tripId': tripId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void requestTrip({
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> dropoff,
    required String vehicleType,
    String? notes,
  }) {
    if (!_canEmit('trip:request')) return;
    debugPrint('📤 [SOCKET] trip:request — ${pickup['address']} → ${dropoff['address']}');
    _socket!.emit('trip:request', {
      'pickup': pickup,
      'dropoff': dropoff,
      'vehicleType': vehicleType,
      'notes': notes,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void emit(String event, dynamic data) {
    if (!_canEmit(event)) return;
    debugPrint('📤 [SOCKET] Custom emit: $event');
    _socket!.emit(event, data);
  }

  void on(String event, Function(dynamic) handler) {
    if (_socket == null) {
      debugPrint('⚠️ [SOCKET] Cannot register listener — socket null');
      return;
    }
    _socket!.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  bool _canEmit(String eventName, {bool silent = false}) {
    if (_socket == null) {
      if (!silent) debugPrint('❌ [SOCKET] Cannot emit $eventName — socket null');
      return false;
    }
    if (!_isConnected) {
      if (!silent) {
        debugPrint('❌ [SOCKET] Cannot emit $eventName — not connected');
        _errorController.add('Not connected to server');
      }
      return false;
    }
    return true;
  }

  void testConnection() {
    if (!_canEmit('connection:test')) return;
    _socket!.emit('connection:test', {'timestamp': DateTime.now().toIso8601String()});
  }

  Future<void> reconnect() async {
    if (_serverUrl == null || _currentToken == null ||
        _userId == null || _userType == null) {
      debugPrint('❌ [SOCKET] Cannot reconnect — missing details');
      return;
    }
    debugPrint('🔄 [SOCKET] Manual reconnect...');
    disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await connect(
      url: _serverUrl!,
      accessToken: _currentToken!,
      userId: _userId!,
      userType: _userType!,
      onTokenExpired: _onTokenExpired,
    );
  }

  Map<String, dynamic> getConnectionInfo() => {
    'isConnected':       _isConnected,
    'isReconnecting':    _isReconnecting,
    'reconnectAttempts': _reconnectAttempts,
    'socketId':          _socket?.id,
    'userId':            _userId,
    'userType':          _userType,
    'serverUrl':         _serverUrl,
  };

  // ═══════════════════════════════════════════════════════════════
  // DISCONNECT & CLEANUP
  // ═══════════════════════════════════════════════════════════════

  void disconnect() {
    if (_socket != null) {
      debugPrint('🔌 [SOCKET] Disconnecting...');
      _stopHeartbeat();
      _socket!.disconnect();
      _socket!.dispose();
      _socket             = null;
      _isConnected        = false;
      _isReconnecting     = false;
      _reconnectAttempts  = 0;
      _connectionStateController.add(false);
    }
  }

  void dispose() {
    debugPrint('🗑️ [SOCKET] Disposing...');
    disconnect();
    _connectionStateController.close();
    _tripAssignedController.close();
    _tripStatusController.close();
    _tripCanceledController.close();
    _noDriversController.close();
    _driverLocationController.close();
    _tripRequestExpiredController.close();
    _driverArrivedController.close();
    _tripOfferController.close();
    _tripMatchedController.close();
    _tripAcceptSuccessController.close();
    _tripAcceptFailedController.close();
    _errorController.close();
    _messageController.close();
    debugPrint('✅ [SOCKET] Disposed');
  }
}
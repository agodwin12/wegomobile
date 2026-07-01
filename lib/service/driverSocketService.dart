// lib/services/driver_socket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

typedef OfferHandler = void Function(Map<String, dynamic> offer);
typedef GenericAck = void Function(Map<String, dynamic> result);

class DriverSocketService with ChangeNotifier {
  static final DriverSocketService _instance = DriverSocketService._internal();
  factory DriverSocketService() => _instance;
  DriverSocketService._internal();

  IO.Socket? _socket;
  String? _token;
  String? _socketUrl;

  final _connectedCtl = StreamController<bool>.broadcast();
  final _offerCtl     = StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool>              get connectedStream => _connectedCtl.stream;
  Stream<Map<String,dynamic>> get offerStream   => _offerCtl.stream;

  bool get isConnected => _socket?.connected ?? false;

  // ── Connect ──────────────────────────────────────────────────────────────
  void connect({ required String socketUrl, required String token }) {
    _token     = token;
    _socketUrl = socketUrl;

    if (_socket != null) {
      if (_socket!.connected) return;
      _socket!.dispose();
      _socket = null;
    }

    _buildAndConnect(socketUrl, token);
  }

  void _buildAndConnect(String socketUrl, String token) {
    _socket = IO.io(
      '$socketUrl/driver',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()           // we call connect() manually
          .setAuth({'token': token})      // ← auth via handshake, not query
          .build(),
    );

    _socket!.on('connect', (_) {
      debugPrint('✅ [DRIVER SOCKET] Connected — id: ${_socket!.id}');
      _connectedCtl.add(true);
      notifyListeners();
    });

    _socket!.on('disconnect', (reason) {
      debugPrint('🔌 [DRIVER SOCKET] Disconnected — reason: $reason');
      _connectedCtl.add(false);
      notifyListeners();
    });

    _socket!.on('connect_error', (err) {
      debugPrint('❌ [DRIVER SOCKET] connect_error: $err');
      _connectedCtl.add(false);
    });

    // Incoming trip offer
    _socket!.on('trip.offer', (data) {
      Map<String, dynamic> payload;
      if (data is String) {
        try { payload = json.decode(data); }
        catch (e) { payload = {'raw': data}; }
      } else {
        payload = Map<String, dynamic>.from(data);
      }
      _offerCtl.add(payload);
    });

    _socket!.on('trip.assigned', (data) { /* optional */ });
    _socket!.on('trip.matched',  (data) { /* optional */ });

    _socket!.connect();
  }

  // ── Token refresh ─────────────────────────────────────────────────────────
  /// Call this immediately after a successful token refresh so the socket
  /// reconnects with the new token instead of retrying with the expired one.
  ///
  /// Called from AuthService.refreshAccessToken() after saving to prefs.
  void updateAuthToken(String newToken) {
    debugPrint('🔑 [DRIVER SOCKET] Updating auth token');
    _token = newToken;

    if (_socket == null || _socketUrl == null) return;

    // Update the auth object on the existing socket instance.
    // socket_io_client exposes this through the `auth` setter.
    _socket!.auth = {'token': newToken};

    if (!_socket!.connected) {
      debugPrint('🔄 [DRIVER SOCKET] Was disconnected — reconnecting with new token');
      // Dispose and rebuild so the handshake uses the updated auth.
      _socket!.dispose();
      _socket = null;
      _buildAndConnect(_socketUrl!, newToken);
    }
  }

  // ── Disconnect ────────────────────────────────────────────────────────────
  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _connectedCtl.add(false);
  }

  // ── Location ──────────────────────────────────────────────────────────────
  bool sendLocation(double lat, double lng) {
    if (_socket == null || !_socket!.connected) return false;
    _socket!.emit('location.update', {'lat': lat, 'lng': lng});
    return true;
  }

  // ── Accept trip ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> acceptTrip({ required String tripId }) async {
    final completer = Completer<Map<String, dynamic>>();
    if (_socket == null || !_socket!.connected) {
      return {'ok': false, 'error': 'NOT_CONNECTED'};
    }
    try {
      _socket!.emitWithAck('trip.accept', {'tripId': tripId}, ack: (data) {
        Map<String, dynamic> res;
        if (data == null) {
          res = {'ok': false, 'error': 'NO_ACK'};
        } else if (data is String) {
          try { res = json.decode(data); } catch(e) { res = {'ok': false, 'raw': data}; }
        } else {
          res = Map<String, dynamic>.from(data);
        }
        completer.complete(res);
      });
    } catch (e) {
      completer.complete({'ok': false, 'error': e.toString()});
    }
    return completer.future;
  }

  // ── Decline trip ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> declineTrip({ required String tripId }) async {
    final completer = Completer<Map<String, dynamic>>();
    if (_socket == null || !_socket!.connected) {
      return {'ok': false, 'error': 'NOT_CONNECTED'};
    }
    try {
      _socket!.emitWithAck('trip.decline', {'tripId': tripId}, ack: (data) {
        if (data == null) return completer.complete({'ok': false, 'error': 'NO_ACK'});
        final Map<String, dynamic> res =
        data is Map<String, dynamic> ? data : {'ok': !!data};
        completer.complete(res);
      });
    } catch (e) {
      completer.complete({'ok': false, 'error': e.toString()});
    }
    return completer.future;
  }

  // ── Update trip status ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> updateTripStatus({
    required String tripId,
    required String status,
    Map<String, dynamic>? location,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    if (_socket == null || !_socket!.connected) {
      return {'ok': false, 'error': 'NOT_CONNECTED'};
    }
    try {
      final payload = {'tripId': tripId, 'status': status, 'location': location};
      _socket!.emitWithAck('trip.status_update', payload, ack: (data) {
        if (data == null) return completer.complete({'ok': false, 'error': 'NO_ACK'});
        completer.complete(Map<String, dynamic>.from(data));
      });
    } catch (e) {
      completer.complete({'ok': false, 'error': e.toString()});
    }
    return completer.future;
  }

  void disposeStreams() {
    _connectedCtl.close();
    _offerCtl.close();
  }
}
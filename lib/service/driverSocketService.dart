// lib/services/driver_socket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

typedef OfferHandler = void Function(Map<String, dynamic> offer);
typedef GenericAck = void Function(Map<String,dynamic> result);

class DriverSocketService with ChangeNotifier {
  static final DriverSocketService _instance = DriverSocketService._internal();
  factory DriverSocketService() => _instance;
  DriverSocketService._internal();

  IO.Socket? _socket;
  String? _token;
  final _connectedCtl = StreamController<bool>.broadcast();
  final _offerCtl = StreamController<Map<String, dynamic>>.broadcast();

  Stream<bool> get connectedStream => _connectedCtl.stream;
  Stream<Map<String,dynamic>> get offerStream => _offerCtl.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect({ required String socketUrl, required String token }) {
    _token = token;
    if (_socket != null) {
      if (_socket!.connected) return;
      _socket!.dispose();
      _socket = null;
    }

    _socket = IO.io(
        socketUrl + '/driver',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew()
            .setExtraHeaders({}) // if you need headers
            .setQuery({'token': token}) // alternative; server expects handshake.auth – see below
            .build()
    );

    // authentication — if backend expects handshake.auth, you can set it like:
    // IO.io(url, OptionBuilder().setAuth({'token': token}).build());

    _socket!.on('connect', (_) {
      _connectedCtl.add(true);
      notifyListeners();
    });

    _socket!.on('disconnect', (reason) {
      _connectedCtl.add(false);
      notifyListeners();
    });

    _socket!.on('connect_error', (err) {
      _connectedCtl.add(false);
      if (kDebugMode) print('[socket] connect_error: $err');
    });

    // Incoming trip offer
    _socket!.on('trip.offer', (data) {
      // data is likely already a Map via socket.io
      Map<String, dynamic> payload;
      if (data is String) {
        try {
          payload = json.decode(data);
        } catch (e) {
          payload = {'raw': data};
        }
      } else {
        payload = Map<String,dynamic>.from(data);
      }
      _offerCtl.add(payload);
    });

    // Other events you may want to handle
    _socket!.on('trip.assigned', (data) { /* optional */ });
    _socket!.on('trip.matched', (data) { /* optional */ });

    _socket!.connect();
  }

  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (e) {}
    _socket = null;
    _connectedCtl.add(false);
  }

  bool sendLocation(double lat, double lng) {
    if (_socket == null || !_socket!.connected) return false;
    _socket!.emit('location.update', {'lat': lat, 'lng': lng});
    return true;
  }

  /// Accept trip — uses acknowledgement callback from socket server
  Future<Map<String,dynamic>> acceptTrip({ required String tripId }) async {
    final completer = Completer<Map<String,dynamic>>();
    if (_socket == null || !_socket!.connected) {
      completer.complete({'ok': false, 'error': 'NOT_CONNECTED'});
      return completer.future;
    }

    try {
      _socket!.emitWithAck('trip.accept', {'tripId': tripId}, ack: (data) {
        Map<String,dynamic> res;
        if (data == null) {
          res = {'ok': false, 'error': 'NO_ACK'};
        } else if (data is String) {
          try { res = json.decode(data); } catch(e) { res = {'ok': false, 'raw': data}; }
        } else {
          res = Map<String,dynamic>.from(data);
        }
        completer.complete(res);
      });
    } catch (e) {
      completer.complete({'ok': false, 'error': e.toString()});
    }

    return completer.future;
  }

  /// Decline trip
  Future<Map<String,dynamic>> declineTrip({ required String tripId }) async {
    final completer = Completer<Map<String,dynamic>>();
    if (_socket == null || !_socket!.connected) {
      completer.complete({'ok': false, 'error': 'NOT_CONNECTED'});
      return completer.future;
    }

    try {
      _socket!.emitWithAck('trip.decline', {'tripId': tripId}, ack: (data) {
        if (data == null) return completer.complete({'ok': false, 'error': 'NO_ACK'});
        final Map<String,dynamic> res = data is Map<String,dynamic> ? data : {'ok': !!data};
        completer.complete(res);
      });
    } catch (e) {
      completer.complete({'ok': false, 'error': e.toString()});
    }
    return completer.future;
  }

  /// Update trip status (en_route, arrived_pickup, in_progress, completed)
  Future<Map<String,dynamic>> updateTripStatus({ required String tripId, required String status, Map<String,dynamic>? location }) async {
    final completer = Completer<Map<String,dynamic>>();
    if (_socket == null || !_socket!.connected) {
      completer.complete({'ok': false, 'error': 'NOT_CONNECTED'});
      return completer.future;
    }
    try {
      final payload = {'tripId': tripId, 'status': status, 'location': location};
      _socket!.emitWithAck('trip.status_update', payload, ack: (data) {
        if (data == null) return completer.complete({'ok': false, 'error': 'NO_ACK'});
        completer.complete(Map<String,dynamic>.from(data));
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

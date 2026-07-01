// lib/service/api/service_socket_listener.dart
// ─────────────────────────────────────────────────────────────────────────────
// Services Marketplace — Socket.IO listener
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServiceSocketListener {
  static final ServiceSocketListener instance = ServiceSocketListener._internal();
  ServiceSocketListener._internal();

  IO.Socket? _socket;
  bool _connected = false;
  String? _lastUrl;

  // ── Callbacks ─────────────────────────────────────────────────────────────
  void Function(Map<String, dynamic> data)? onNewRequest;
  void Function(Map<String, dynamic> data)? onRequestAccepted;
  void Function(Map<String, dynamic> data)? onRequestRejected;
  void Function(Map<String, dynamic> data)? onServiceStarted;
  void Function(Map<String, dynamic> data)? onPaymentRequested;
  void Function(Map<String, dynamic> data)? onPaymentProofUploaded;
  void Function(Map<String, dynamic> data)? onPaymentConfirmed;
  void Function(Map<String, dynamic> data)? onRequestCancelled;
  void Function(Map<String, dynamic> data)? onDisputeFiled;
  void Function(Map<String, dynamic> data)? onDisputeResolved;

  // ── Connect ───────────────────────────────────────────────────────────────
  Future<void> connect() async {
    if (_connected && _socket != null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      debugPrint('⚠️ [SVC_SOCKET] No access token — skipping connect');
      return;
    }

    _lastUrl = dotenv.env['SOCKET_URL'] ??
        dotenv.env['API_BASE_URL']?.replaceAll('/api', '') ??
        'http://10.0.2.2:4000';

    _buildAndConnect(_lastUrl!, token);
  }

  void _buildAndConnect(String url, String token) {
    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      debugPrint('✅ [SVC_SOCKET] Connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      debugPrint('🔌 [SVC_SOCKET] Disconnected');
    });

    _socket!.onConnectError((err) => debugPrint('❌ [SVC_SOCKET] Connect error: $err'));
    _socket!.onError((err)        => debugPrint('❌ [SVC_SOCKET] Error: $err'));

    _registerEvents();
    _socket!.connect();
  }

  // ── Token refresh ─────────────────────────────────────────────────────────
  /// Called by AuthService after a successful token refresh.
  /// Updates the auth object and reconnects if the socket was disconnected.
  void updateAuthToken(String newToken) {
    debugPrint('🔑 [SVC_SOCKET] Updating auth token');

    if (_socket == null || _lastUrl == null) return;

    _socket!.auth = {'token': newToken};

    if (!_socket!.connected) {
      debugPrint('🔄 [SVC_SOCKET] Was disconnected — reconnecting with new token');
      _socket!.dispose();
      _socket = null;
      _connected = false;
      _buildAndConnect(_lastUrl!, newToken);
    }
  }

  // ── Disconnect ────────────────────────────────────────────────────────────
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket     = null;
    _connected  = false;
    _clearAllCallbacks();
    debugPrint('🔌 [SVC_SOCKET] Manually disconnected');
  }

  bool get isConnected => _connected;

  // ── Register events ───────────────────────────────────────────────────────
  void _registerEvents() {
    _socket!.on('service:new_request',           (r) { onNewRequest?.call(_toMap(r));           });
    _socket!.on('service:request_accepted',      (r) { onRequestAccepted?.call(_toMap(r));      });
    _socket!.on('service:request_rejected',      (r) { onRequestRejected?.call(_toMap(r));      });
    _socket!.on('service:started',               (r) { onServiceStarted?.call(_toMap(r));       });
    _socket!.on('service:payment_requested',     (r) { onPaymentRequested?.call(_toMap(r));     });
    _socket!.on('service:payment_proof_uploaded',(r) { onPaymentProofUploaded?.call(_toMap(r)); });
    _socket!.on('service:payment_confirmed',     (r) { onPaymentConfirmed?.call(_toMap(r));     });
    _socket!.on('service:cancelled',             (r) { onRequestCancelled?.call(_toMap(r));     });
    _socket!.on('service:dispute_filed',         (r) { onDisputeFiled?.call(_toMap(r));         });
    _socket!.on('service:dispute_resolved',      (r) { onDisputeResolved?.call(_toMap(r));      });
  }

  // ── Banner helper ─────────────────────────────────────────────────────────
  void showBanner({
    required BuildContext context,
    required String message,
    Color backgroundColor = const Color(0xFF53C28B),
    IconData icon = Icons.notifications_rounded,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ServiceBanner(
        message:         message,
        backgroundColor: backgroundColor,
        icon:            icon,
        onTap:   () { entry.remove(); onTap?.call(); },
        onDismiss: ()  { entry.remove(); },
      ),
    );

    overlay.insert(entry);
    Future.delayed(duration, () { if (entry.mounted) entry.remove(); });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Map<String, dynamic> _toMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
    return {};
  }

  void _clearAllCallbacks() {
    onNewRequest           = null;
    onRequestAccepted      = null;
    onRequestRejected      = null;
    onServiceStarted       = null;
    onPaymentRequested     = null;
    onPaymentProofUploaded = null;
    onPaymentConfirmed     = null;
    onRequestCancelled     = null;
    onDisputeFiled         = null;
    onDisputeResolved      = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING BANNER WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceBanner extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _ServiceBanner({
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_ServiceBanner> createState() => _ServiceBannerState();
}

class _ServiceBannerState extends State<_ServiceBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, -1.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade  = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _dismiss() async { await _ctrl.reverse(); widget.onDismiss(); }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragUpdate: (d) { if ((d.primaryDelta ?? 0) < -4) _dismiss(); },
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(14),
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: widget.backgroundColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: Icon(widget.icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(widget.message,
                          style: const TextStyle(fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
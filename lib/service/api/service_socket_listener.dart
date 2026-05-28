
import 'package:flutter/material.dart';
import '../../service/socket_service.dart';

class ServiceSocketListener {
  static ServiceSocketListener? _instance;
  static ServiceSocketListener get instance {
    _instance ??= ServiceSocketListener._();
    return _instance!;
  }

  ServiceSocketListener._();

  bool _isListening = false;

  // Callbacks — screens register these to react to events
  Function(Map<String, dynamic>)? onNewRequest;
  Function(Map<String, dynamic>)? onRequestAccepted;
  Function(Map<String, dynamic>)? onRequestRejected;
  Function(Map<String, dynamic>)? onServiceStarted;
  Function(Map<String, dynamic>)? onPaymentRequested;
  Function(Map<String, dynamic>)? onPaymentProofUploaded;
  Function(Map<String, dynamic>)? onPaymentConfirmed;
  Function(Map<String, dynamic>)? onRequestCancelled;
  Function(Map<String, dynamic>)? onDisputeFiled;
  Function(Map<String, dynamic>)? onDisputeResolved;

  // ═══════════════════════════════════════════════════════════════════
  // START LISTENING
  // Call this once after user logs in
  // ═══════════════════════════════════════════════════════════════════

  void startListening() {
    if (_isListening) return;

    final socket = SocketService.instance.socket;
    if (socket == null) {
      debugPrint('⚠️ [SERVICE_SOCKET_LISTENER] Socket not available');
      return;
    }

    debugPrint('🔌 [SERVICE_SOCKET_LISTENER] Starting service socket listeners...');

    // ─────────────────────────────────────────────────────────────────
    // NEW SERVICE REQUEST (Provider receives this)
    // ─────────────────────────────────────────────────────────────────
    socket.on('service:new_request', (data) {
      debugPrint('📥 [SERVICE_SOCKET] New request received');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        onNewRequest?.call(payload);
      } catch (e) {
        debugPrint('❌ [SERVICE_SOCKET] Error parsing new_request: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────
    // REQUEST ACCEPTED (Customer receives this)
    // ─────────────────────────────────────────────────────────────────
    socket.on('service:request_accepted', (data) {
      debugPrint('✅ [SERVICE_SOCKET] Request accepted');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        onRequestAccepted?.call(payload);
      } catch (e) {
        debugPrint('❌ [SERVICE_SOCKET] Error parsing request_accepted: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────
    // REQUEST REJECTED (Customer receives this)
    // ─────────────────────────────────────────────────────────────────
    socket.on('service:request_rejected', (data) {
      debugPrint('❌ [SERVICE_SOCKET] Request rejected');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        onRequestRejected?.call(payload);
      } catch (e) {
        debugPrint('❌ [SERVICE_SOCKET] Error parsing request_rejected: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────
    // SERVICE STARTED (Customer receives this)
    // ─────────────────────────────────────────────────────────────────
    socket.on('service:started', (data) {
      debugPrint('🚀 [SERVICE_SOCKET] Service started');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        onServiceStarted?.call(payload);
      } catch (e) {
        debugPrint('❌ [SERVICE_SOCKET] Error parsing service_started: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────
    // PAYMENT REQUESTED (Customer receives this when service completed)
    // ─────────────────────────────────────────────────────────────────
    socket.on('service:payment_requested', (data) {
      debugPrint('💰 [SERVICE_SOCKET] Payment requested');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        onPaymentRequested?.call(payload);
      } catch (e) {
        debugPrint('❌ [SERVICE_SOCKET] Error parsing payment_requested: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────
    // PAYMENT PROOF UPLOADED (Provider receives this)
    // ─────────────────────────────────────────────────────────────────
    socket.on('service:payment_proof_uploaded', (data) {
      debugPrint('📸 [SERVICE_SOCKET] Payment proof uploaded');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        onPaymentProofUploaded?.call(payload);
      } catch (e) {
        debugPrint('❌ [SERVICE_SOCKET] Error parsing payment_proof_uploaded: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────
    // PAYMENT CONFIRMED (Customer receives this)
    // ─────────────────────────────────────────────────────────────────
    socket.on('service:payment_confirmed', (data) {
      debugPrint('✅ [SERVICE_SOCKET] Payment confirmed');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        onPaymentConfirmed?.call(payload);
      } catch (e) {
        debugPrint('❌ [SERVICE_SOCKET] Error parsing payment_confirmed: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────
    // REQUEST CANCELLED (Other party receives this)
    // ─────────────────────────────────────────────────────────────────
    socket.on('service:cancelled', (data) {
      debugPrint('🚫 [SERVICE_SOCKET] Request cancelled');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        onRequestCancelled?.call(payload);
      } catch (e) {
        debugPrint('❌ [SERVICE_SOCKET] Error parsing cancelled: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────
    // DISPUTE FILED (Other party receives this)
    // ─────────────────────────────────────────────────────────────────
    socket.on('service:dispute_filed', (data) {
      debugPrint('⚠️ [SERVICE_SOCKET] Dispute filed');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        onDisputeFiled?.call(payload);
      } catch (e) {
        debugPrint('❌ [SERVICE_SOCKET] Error parsing dispute_filed: $e');
      }
    });

    // ─────────────────────────────────────────────────────────────────
    // DISPUTE RESOLVED (Both parties receive this)
    // ─────────────────────────────────────────────────────────────────
    socket.on('service:dispute_resolved', (data) {
      debugPrint('✅ [SERVICE_SOCKET] Dispute resolved');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        onDisputeResolved?.call(payload);
      } catch (e) {
        debugPrint('❌ [SERVICE_SOCKET] Error parsing dispute_resolved: $e');
      }
    });

    _isListening = true;
    debugPrint('✅ [SERVICE_SOCKET_LISTENER] All service listeners registered');
  }

  // ═══════════════════════════════════════════════════════════════════
  // STOP LISTENING
  // Call this when user logs out
  // ═══════════════════════════════════════════════════════════════════

  void stopListening() {
    if (!_isListening) return;

    final socket = SocketService.instance.socket;
    if (socket == null) return;

    socket.off('service:new_request');
    socket.off('service:request_accepted');
    socket.off('service:request_rejected');
    socket.off('service:started');
    socket.off('service:payment_requested');
    socket.off('service:payment_proof_uploaded');
    socket.off('service:payment_confirmed');
    socket.off('service:cancelled');
    socket.off('service:dispute_filed');
    socket.off('service:dispute_resolved');

    _isListening = false;
    debugPrint('🔌 [SERVICE_SOCKET_LISTENER] All service listeners removed');
  }

  // ═══════════════════════════════════════════════════════════════════
  // CLEAR ALL CALLBACKS
  // Call this when leaving the services section
  // ═══════════════════════════════════════════════════════════════════

  void clearCallbacks() {
    onNewRequest = null;
    onRequestAccepted = null;
    onRequestRejected = null;
    onServiceStarted = null;
    onPaymentRequested = null;
    onPaymentProofUploaded = null;
    onPaymentConfirmed = null;
    onRequestCancelled = null;
    onDisputeFiled = null;
    onDisputeResolved = null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHOW IN-APP NOTIFICATION BANNER
  // Call this from any callback to show a banner to the user
  // ═══════════════════════════════════════════════════════════════════

  void showBanner({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    IconData icon = Icons.notifications,
    VoidCallback? onTap,
  }) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              onTap?.call();
            },
            child: const Text(
              'VIEW',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text(
              'DISMISS',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      try {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      } catch (_) {}
    });
  }
}
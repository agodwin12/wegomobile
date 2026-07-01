// lib/services/notification_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../firebase_options.dart';

// ═══════════════════════════════════════════════════════════════════════
// BACKGROUND MESSAGE HANDLER
// Must be a top-level function
// ═══════════════════════════════════════════════════════════════════════

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('🔔 [NOTIF] Background message: ${message.data['type']}');
}

// ═══════════════════════════════════════════════════════════════════════
// NOTIFICATION TYPES
// ═══════════════════════════════════════════════════════════════════════

enum NotificationType {
  rideDriverMatched,
  rideDriverArrived,
  rideCancelled,
  rideTripOffer,
  rideOfferExpired,
  ridePaymentReceived,

  deliveryAgentAssigned,
  deliveryPickedUp,
  deliveryCancelled,
  deliveryOffer,
  deliveryOfferExpired,
  deliveryPaymentReceived,

  serviceRequestAccepted,
  serviceRequestRejected,
  serviceDisputeResolved,
  serviceNewRequest,

  walletTopupSuccess,
  walletTopupFailed,
  walletWithdrawalRequested,
  walletWithdrawalCompleted,
  walletWithdrawalFailed,

  rentalApproved,
  rentalExpiryReminder,

  accountApproved,
  accountSuspended,
  accountPasswordChanged,
  accountNewDeviceLogin,

  supportTicketReply,
  supportTicketResolved,

  broadcast,
  unknown,
}

NotificationType _typeFromString(String? type) {
  switch (type) {
    case 'RIDE_DRIVER_MATCHED':
      return NotificationType.rideDriverMatched;
    case 'RIDE_DRIVER_ARRIVED':
      return NotificationType.rideDriverArrived;
    case 'RIDE_CANCELLED':
      return NotificationType.rideCancelled;
    case 'RIDE_TRIP_OFFER':
      return NotificationType.rideTripOffer;
    case 'RIDE_OFFER_EXPIRED':
      return NotificationType.rideOfferExpired;
    case 'RIDE_PAYMENT_RECEIVED':
      return NotificationType.ridePaymentReceived;

    case 'DELIVERY_AGENT_ASSIGNED':
      return NotificationType.deliveryAgentAssigned;
    case 'DELIVERY_PICKED_UP':
      return NotificationType.deliveryPickedUp;
    case 'DELIVERY_CANCELLED':
      return NotificationType.deliveryCancelled;
    case 'DELIVERY_OFFER':
      return NotificationType.deliveryOffer;
    case 'DELIVERY_OFFER_EXPIRED':
      return NotificationType.deliveryOfferExpired;
    case 'DELIVERY_PAYMENT_RECEIVED':
      return NotificationType.deliveryPaymentReceived;

    case 'SERVICE_REQUEST_ACCEPTED':
      return NotificationType.serviceRequestAccepted;
    case 'SERVICE_REQUEST_REJECTED':
      return NotificationType.serviceRequestRejected;
    case 'SERVICE_DISPUTE_RESOLVED':
      return NotificationType.serviceDisputeResolved;
    case 'SERVICE_NEW_REQUEST':
      return NotificationType.serviceNewRequest;

    case 'WALLET_TOPUP_SUCCESS':
      return NotificationType.walletTopupSuccess;
    case 'WALLET_TOPUP_FAILED':
      return NotificationType.walletTopupFailed;
    case 'WALLET_WITHDRAWAL_REQUESTED':
      return NotificationType.walletWithdrawalRequested;
    case 'WALLET_WITHDRAWAL_COMPLETED':
      return NotificationType.walletWithdrawalCompleted;
    case 'WALLET_WITHDRAWAL_FAILED':
      return NotificationType.walletWithdrawalFailed;

    case 'RENTAL_APPROVED':
      return NotificationType.rentalApproved;
    case 'RENTAL_EXPIRY_REMINDER':
      return NotificationType.rentalExpiryReminder;

    case 'ACCOUNT_APPROVED':
      return NotificationType.accountApproved;
    case 'ACCOUNT_SUSPENDED':
      return NotificationType.accountSuspended;
    case 'ACCOUNT_PASSWORD_CHANGED':
      return NotificationType.accountPasswordChanged;
    case 'ACCOUNT_NEW_DEVICE_LOGIN':
      return NotificationType.accountNewDeviceLogin;

    case 'SUPPORT_TICKET_REPLY':
      return NotificationType.supportTicketReply;
    case 'SUPPORT_TICKET_RESOLVED':
      return NotificationType.supportTicketResolved;

    case 'BROADCAST':
      return NotificationType.broadcast;

    default:
      return NotificationType.unknown;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// NOTIFICATION SERVICE
// ═══════════════════════════════════════════════════════════════════════

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
  AndroidNotificationChannel(
    'wego_high_importance',
    'WeGo Notifications',
    description: 'Trip offers, delivery updates, wallet activity and more.',
    importance: Importance.high,
  );

  void Function(NotificationType type, Map<String, dynamic> data)?
  onNotificationTap;

  Future<void> init() async {
    debugPrint('🔔 [NOTIF] Initialising notification service...');

    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('🔔 [NOTIF] Permission: ${settings.authorizationStatus}');

    await _local
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _local.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _handlePayload(payload);
        }
      },
    );

    FirebaseMessaging.onMessage.listen(_handleForeground);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    final initialMessage = await _fcm.getInitialMessage();

    if (initialMessage != null) {
      Future.delayed(
        const Duration(milliseconds: 500),
            () => _handleTap(initialMessage),
      );
    }

    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint('🔔 [NOTIF] Token refreshed — re-registering...');
      _registerToken(newToken);
    });

    debugPrint('✅ [NOTIF] Notification service ready');
  }

  void _handleForeground(RemoteMessage message) {
    debugPrint('🔔 [NOTIF] Foreground message: ${message.data['type']}');

    final title =
        message.notification?.title ?? message.data['title'] ?? 'WeGo';

    final body =
        message.notification?.body ?? message.data['body'] ?? '';

    _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleTap(RemoteMessage message) {
    debugPrint('🔔 [NOTIF] Notification tapped: ${message.data['type']}');
    _route(message.data);
  }

  void _handlePayload(String payload) {
    try {
      final decoded = jsonDecode(payload);

      if (decoded is Map<String, dynamic>) {
        _route(decoded);
      } else {
        debugPrint('❌ [NOTIF] Invalid payload format');
      }
    } catch (e) {
      debugPrint('❌ [NOTIF] Failed to parse payload: $e');
    }
  }

  void _route(Map<String, dynamic> data) {
    final type = _typeFromString(data['type']?.toString());

    debugPrint('🔔 [NOTIF] Routing type: $type | data: $data');

    onNotificationTap?.call(type, data);
  }

  Future<void> registerTokenOnLogin() async {
    try {
      final token = await _fcm.getToken();

      if (token == null || token.isEmpty) {
        debugPrint('⚠️ [NOTIF] No FCM token available');
        return;
      }

      debugPrint('🔔 [NOTIF] Registering FCM token on login...');
      await _registerToken(token);
    } catch (e) {
      debugPrint('❌ [NOTIF] registerTokenOnLogin error: $e');
    }
  }

  Future<void> deactivateTokenOnLogout() async {
    try {
      final deviceId = await _getDeviceId();

      final prefs = await SharedPreferences.getInstance();
      final apiToken = prefs.getString('access_token') ?? '';

      if (apiToken.isEmpty) {
        debugPrint('⚠️ [NOTIF] No access token — skipping token deactivation');
        return;
      }

      final baseUrl = _baseUrl();

      final res = await http.delete(
        Uri.parse('$baseUrl/api/device-tokens'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
        },
        body: jsonEncode({
          'device_id': deviceId,
        }),
      );

      if (res.statusCode == 200) {
        debugPrint('✅ [NOTIF] FCM token deactivated on logout');
      } else {
        debugPrint(
          '⚠️ [NOTIF] Token deactivation returned ${res.statusCode}: ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [NOTIF] deactivateTokenOnLogout error: $e');
    }
  }

  Future<void> _registerToken(String fcmToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiToken = prefs.getString('access_token') ?? '';

      if (apiToken.isEmpty) {
        debugPrint('⚠️ [NOTIF] No access token — skipping FCM registration');
        return;
      }

      final deviceId = await _getDeviceId();

      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
          ? 'ios'
          : 'unknown';

      final baseUrl = _baseUrl();

      final res = await http.post(
        Uri.parse('$baseUrl/api/device-tokens'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
        },
        body: jsonEncode({
          'fcm_token': fcmToken,
          'device_id': deviceId,
          'platform': platform,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        debugPrint('✅ [NOTIF] FCM token registered with backend');
      } else {
        debugPrint(
          '⚠️ [NOTIF] Token registration returned ${res.statusCode}: ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ [NOTIF] _registerToken error: $e');
    }
  }

  Future<String> _getDeviceId() async {
    final info = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return android.id;
    }

    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return ios.identifierForVendor ?? 'unknown_ios';
    }

    return 'unknown_platform';
  }

  String _baseUrl() {
    final base = AppConfig.apiBaseUrl.trim();

    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }

    return base;
  }
}
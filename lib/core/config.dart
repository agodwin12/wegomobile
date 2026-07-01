// lib/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // ═══════════════════════════════════════════════════════════════
  // API CONFIGURATION
  // ═══════════════════════════════════════════════════════════════
  static String get apiBaseUrl => dotenv.get('API_BASE_URL', fallback: 'http://10.0.2.2:4000/api');
  static int get apiTimeout => int.parse(dotenv.get('API_TIMEOUT', fallback: '30000'));

  // ═══════════════════════════════════════════════════════════════
  // AUTHENTICATION
  // ═══════════════════════════════════════════════════════════════
  // NOTE: the JWT *secret* lives on the server only. A mobile app never
  // signs or verifies tokens itself — it just stores the access/refresh
  // tokens the API returns. Never ship a signing secret inside the binary.
  static String get refreshTokenExpiry => dotenv.get('REFRESH_TOKEN_EXPIRY', fallback: '90d');
  static String get accessTokenExpiry => dotenv.get('ACCESS_TOKEN_EXPIRY', fallback: '24h');

  // ═══════════════════════════════════════════════════════════════
  // MAPBOX
  // ═══════════════════════════════════════════════════════════════
  static String get mapboxToken => dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: '');

  // ═══════════════════════════════════════════════════════════════
  // FIREBASE
  // ═══════════════════════════════════════════════════════════════
  static String get firebaseApiKey => dotenv.get('FIREBASE_API_KEY', fallback: '');
  static String get firebaseProjectId => dotenv.get('FIREBASE_PROJECT_ID', fallback: '');
  static String get firebaseStorageBucket => dotenv.get('FIREBASE_STORAGE_BUCKET', fallback: '');
  static String get firebaseMessagingSenderId => dotenv.get('FIREBASE_MESSAGING_SENDER_ID', fallback: '');
  static String get firebaseAppId => dotenv.get('FIREBASE_APP_ID', fallback: '');

  // ═══════════════════════════════════════════════════════════════
  // PAYMENT GATEWAY
  // ═══════════════════════════════════════════════════════════════
  // Only the *publishable* key is client-safe. The Stripe secret key and
  // the FCM server key are server-side credentials and were removed —
  // payments are charged and pushes are sent by the backend, not the app.
  static String get stripePublishableKey => dotenv.get('STRIPE_PUBLISHABLE_KEY', fallback: '');

  // ═══════════════════════════════════════════════════════════════
  // IMAGE UPLOAD
  // ═══════════════════════════════════════════════════════════════
  static int get maxImageSize => int.parse(dotenv.get('MAX_IMAGE_SIZE', fallback: '5242880'));
  static List<String> get allowedImageFormats {
    final formats = dotenv.get('ALLOWED_IMAGE_FORMATS', fallback: 'jpg,jpeg,png,webp');
    return formats.split(',');
  }

  // ═══════════════════════════════════════════════════════════════
  // OTP CONFIGURATION
  // ═══════════════════════════════════════════════════════════════
  static int get otpExpiryMinutes => int.parse(dotenv.get('OTP_EXPIRY_MINUTES', fallback: '10'));
  static int get otpLength => int.parse(dotenv.get('OTP_LENGTH', fallback: '6'));

  // ═══════════════════════════════════════════════════════════════
  // APP CONFIGURATION
  // ═══════════════════════════════════════════════════════════════
  static String get appName => dotenv.get('APP_NAME', fallback: 'WEGO');
  static String get appVersion => dotenv.get('APP_VERSION', fallback: '1.0.0');
  static String get environment => dotenv.get('ENVIRONMENT', fallback: 'development');

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';

  // ═══════════════════════════════════════════════════════════════
  // SOCKET/WEBSOCKET
  // ═══════════════════════════════════════════════════════════════
  static String get socketUrl => dotenv.get('SOCKET_URL', fallback: 'ws://10.0.2.2:4000');
  static int get socketReconnectDelay => int.parse(dotenv.get('SOCKET_RECONNECT_DELAY', fallback: '5000'));

  // ═══════════════════════════════════════════════════════════════
  // SOCIAL MEDIA LOGIN
  // ═══════════════════════════════════════════════════════════════
  static String get googleClientId => dotenv.get('GOOGLE_CLIENT_ID', fallback: '');
  static String get facebookAppId => dotenv.get('FACEBOOK_APP_ID', fallback: '');

  // ═══════════════════════════════════════════════════════════════
  // SUPPORT
  // ═══════════════════════════════════════════════════════════════
  static String get supportEmail => dotenv.get('SUPPORT_EMAIL', fallback: 'support@wegoapp.com');
  static String get supportPhone => dotenv.get('SUPPORT_PHONE', fallback: '+237677777777');

  // ═══════════════════════════════════════════════════════════════
  // TERMS & PRIVACY
  // ═══════════════════════════════════════════════════════════════
  static String get termsUrl => dotenv.get('TERMS_URL', fallback: 'https://wegoapp.com/terms');
  static String get privacyUrl => dotenv.get('PRIVACY_URL', fallback: 'https://wegoapp.com/privacy');

  // ═══════════════════════════════════════════════════════════════
  // DEBUGGING
  // ═══════════════════════════════════════════════════════════════
  static void printConfig() {
    if (!isDevelopment) return;

    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('⚙️  [APP CONFIG] Configuration Loaded');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🌍 Environment: $environment');
    print('📱 App Name: $appName');
    print('📌 Version: $appVersion');
    print('🔗 API Base URL: $apiBaseUrl');
    print('⏱️  API Timeout: ${apiTimeout}ms');
    print('🔌 Socket URL: $socketUrl');
    print('🗺️  Mapbox Token: ${mapboxToken.isNotEmpty ? "Configured ✓" : "Not configured ✗"}');
    print('🔥 Firebase: ${firebaseApiKey.isNotEmpty ? "Configured ✓" : "Not configured ✗"}');
    print('💳 Stripe: ${stripePublishableKey.isNotEmpty ? "Configured ✓" : "Not configured ✗"}');
    print('📧 Support Email: $supportEmail');
    print('📞 Support Phone: $supportPhone');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }
}
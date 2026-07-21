// lib/main.dart
// WEGO App - Complete Main Entry Point
// Includes: Ride Booking + Services Marketplace + Profile Management

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wego_v1/screens/delivery%20agent/dashboard/delivery_agent_dashboard.dart';
import 'package:wego_v1/screens/notification/notification_badge.dart';
import 'package:wego_v1/screens/notification/notification_screen.dart';
import 'package:wego_v1/screens/services/edit_listing_screen.dart';
import 'package:wego_v1/screens/services/search_screen.dart';
import 'package:wego_v1/screens/splash/splash.dart';
import 'package:wego_v1/service/notification_service.dart';

// ═══════════════════════════════════════════════════════════════════════
// SCREENS - AUTHENTICATION
// ═══════════════════════════════════════════════════════════════════════
import 'core/app_settings.dart';
import 'firebase_options.dart';
import 'utils/app_colors.dart';
import 'models/services/service_listing_model.dart';
import 'screens/login/login_screen.dart';
import 'screens/signup/sign_up_passenger/signup_passenger_screen.dart';
import 'screens/signup/driver sign up/signup_driver_screen.dart';
import 'screens/forgot_password/forgot_password_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// SCREENS - DASHBOARDS
// ═══════════════════════════════════════════════════════════════════════
import 'screens/passenger/dashboard/passenger_dashboard.dart';
import 'screens/driver/navigation_wrapper/driver_navigation_wrapper.dart';
import 'screens/driver/dashboard/dashboard.dart';

// ═══════════════════════════════════════════════════════════════════════
// SCREENS - ACCOUNT
// ═══════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════
// SCREENS - PROFILE MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/change_password_screen.dart';
import 'screens/profile/change_avatar_screen.dart';
import 'screens/profile/help_faq_screen.dart';
import 'screens/profile/privacy_security_screen.dart';
import 'screens/profile/support_screens.dart';
import 'screens/profile/driver/vehicle_info_screen.dart';
import 'screens/profile/driver/driver_documents_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// SCREENS - NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════
// SCREENS - SERVICES MARKETPLACE
// ═══════════════════════════════════════════════════════════════════════
import 'screens/services/services_home_screen.dart';
import 'screens/services/service_detail_screen.dart';
import 'screens/services/all_categories_screen.dart';
import 'screens/services/category_listings_screen.dart';
import 'screens/services/listing_plan_screen.dart';
import 'screens/services/my_listings_screen.dart';
import 'screens/services/post_service_screen.dart';
import 'screens/services/my_subscription_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// SERVICES
// ═══════════════════════════════════════════════════════════════════════
import 'service/chat_service.dart';
import 'service/socket_service.dart';

// ═══════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════
import 'providers/trip_provider.dart';
import 'providers/services.dart';
import 'providers/profile_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════
import 'models/services/category_model.dart';

// ═══════════════════════════════════════════════════════════════════════
// FIREBASE
// ═══════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════
// MAIN ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════
  // LOAD ENVIRONMENT VARIABLES
  // ═══════════════════════════════════════════════════════════════
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    debugPrint("✅ [STARTUP] .env file loaded successfully");
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    debugPrint("📍 API Base URL: ${dotenv.env['API_BASE_URL']}");
    debugPrint("🗺️  LocationIQ Key: ${dotenv.env['LOCATIONIQ_KEY']?.substring(0, 10)}...");
    debugPrint("🔌 Socket URL: ${dotenv.env['SOCKET_URL']}");
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  } catch (e) {
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    debugPrint("❌ [STARTUP ERROR] Failed to load .env file");
    debugPrint("   Error: $e");
    debugPrint("⚠️  Make sure .env file exists in project root");
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  }

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZE FIREBASE
  // ═══════════════════════════════════════════════════════════════
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ [STARTUP] Firebase initialized");
  } catch (e) {
    debugPrint("❌ [STARTUP] Firebase initialization failed: $e");
  }

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZE NOTIFICATION SERVICE
  // Must be after Firebase.initializeApp()
  // ═══════════════════════════════════════════════════════════════
  try {
    await NotificationService.instance.init();
    debugPrint("✅ [STARTUP] NotificationService initialized");
  } catch (e) {
    debugPrint("❌ [STARTUP] NotificationService init failed: $e");
  }

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZE SOCKET HELPER
  // ═══════════════════════════════════════════════════════════════
  await SocketHelper.initialize();

  // ═══════════════════════════════════════════════════════════════
  // SET SYSTEM UI OVERLAY STYLE
  // ═══════════════════════════════════════════════════════════════
  // (Re-applied theme-aware after settings load, below.)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // SET PREFERRED ORIENTATIONS (Portrait only)
  // ═══════════════════════════════════════════════════════════════
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ═══════════════════════════════════════════════════════════════
  // LOAD USER SETTINGS (language + dark mode) BEFORE FIRST FRAME
  // Applies the palette so the very first frame is themed correctly.
  // ═══════════════════════════════════════════════════════════════
  await AppSettings.instance.load();
  debugPrint("🎨 [STARTUP] Theme: ${AppSettings.instance.isDark ? 'dark' : 'light'} | Lang: ${AppSettings.instance.lang}");

  // Theme-aware status/navigation bars.
  final dark = AppSettings.instance.isDark;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: dark ? const Color(0xFF1A1A1D) : Colors.white,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    ),
  );

  runApp(const RestartWidget(child: WegoApp()));
}

// ═══════════════════════════════════════════════════════════════════════
// RESTART WIDGET
// Remounts the entire tree (new Key) when settings change so every screen
// repaints with the new AppColors palette / language. The splash screen's
// persistent-session logic then routes straight back into the app.
// ═══════════════════════════════════════════════════════════════════════

class RestartWidget extends StatefulWidget {
  final Widget child;
  const RestartWidget({super.key, required this.child});

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restart();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

// ═══════════════════════════════════════════════════════════════════════
// MAIN APP
// ═══════════════════════════════════════════════════════════════════════

class WegoApp extends StatefulWidget {
  const WegoApp({super.key});

  @override
  State<WegoApp> createState() => _WegoAppState();
}

class _WegoAppState extends State<WegoApp> {

  // ── Global navigator key — needed for notification deep-link routing ─────
  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupNotificationRouting();
  }

  // ── Wire up NotificationService tap callback ──────────────────────────────
  // This runs when user taps a notification (foreground or background).
  // Add more cases here as you build out screens.
  void _setupNotificationRouting() {
    NotificationService.instance.onNotificationTap = (type, data) {
      final nav = _navigatorKey.currentState;
      if (nav == null) return;

      debugPrint('🔔 [NAV] Notification tap → type: $type | data: $data');

      // Refresh badge count on any notification tap
      NotificationBadge.refresh();

      switch (type) {
        case NotificationType.rideDriverMatched:
        case NotificationType.rideDriverArrived:
        case NotificationType.rideCancelled:
          nav.pushNamed('/dashboard/passenger');
          break;

        case NotificationType.rideTripOffer:
        case NotificationType.rideOfferExpired:
        case NotificationType.ridePaymentReceived:
          nav.pushNamed('/dashboard/driver');
          break;

        case NotificationType.deliveryAgentAssigned:
        case NotificationType.deliveryPickedUp:
        case NotificationType.deliveryCancelled:
        // Navigate to delivery tracking — update when screen exists
          nav.pushNamed('/notifications');
          break;

        case NotificationType.deliveryOffer:
        case NotificationType.deliveryOfferExpired:
        case NotificationType.deliveryPaymentReceived:
          nav.pushNamed('/dashboard/delivery-agent');
          break;

        case NotificationType.walletTopupSuccess:
        case NotificationType.walletTopupFailed:
        case NotificationType.walletWithdrawalRequested:
        case NotificationType.walletWithdrawalCompleted:
        case NotificationType.walletWithdrawalFailed:
          nav.pushNamed('/notifications');
          break;

        case NotificationType.serviceRequestAccepted:
        case NotificationType.serviceRequestRejected:
        case NotificationType.serviceDisputeResolved:
        case NotificationType.serviceNewRequest:
          nav.pushNamed('/services/my-listings');
          break;

        case NotificationType.rentalApproved:
        case NotificationType.rentalExpiryReminder:
          nav.pushNamed('/notifications');
          break;

        case NotificationType.accountApproved:
        case NotificationType.accountSuspended:
        case NotificationType.accountPasswordChanged:
        case NotificationType.accountNewDeviceLogin:
          nav.pushNamed('/profile');
          break;

        case NotificationType.supportTicketReply:
        case NotificationType.supportTicketResolved:
          nav.pushNamed('/notifications');
          break;

        case NotificationType.broadcast:
        case NotificationType.unknown:
        default:
          nav.pushNamed('/notifications');
          break;
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => ChatService(SocketHelper.socketService!)),
        ChangeNotifierProvider(create: (_) => ServicesProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: MaterialApp(
        title: 'WEGO',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,

        // ════════════════════════════════════════════════════════
        // THEME CONFIGURATION (WEGO Gold & Black)
        // ════════════════════════════════════════════════════════
        theme: ThemeData(
          useMaterial3: true,
          brightness: AppSettings.instance.isDark ? Brightness.dark : Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor:  const Color(0xFFFFDC71),
            primary:    const Color(0xFFFFDC71),
            secondary:  const Color(0xFFF5C844),
            surface:    AppColors.surface,
            background: AppColors.background,
            brightness: AppSettings.instance.isDark ? Brightness.dark : Brightness.light,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            titleTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDC71),
              foregroundColor: Colors.black87,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // ── Global text defaults ──────────────────────────────────────
          // TextFields WITHOUT an explicit style: inherit textTheme.bodyLarge.
          // The fill below was hardcoded white while the text color followed
          // brightness — in dark mode that meant WHITE text on a WHITE fill
          // (invisible typing). Explicit colors fix all ~50 unstyled fields
          // at once, in both modes.
          textTheme: TextTheme(
            bodyLarge:   TextStyle(color: AppColors.textPrimary),
            bodyMedium:  TextStyle(color: AppColors.textPrimary),
            bodySmall:   TextStyle(color: AppColors.textSecondary),
            titleLarge:  TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            titleMedium: TextStyle(color: AppColors.textPrimary),
            titleSmall:  TextStyle(color: AppColors.textPrimary),
            labelLarge:  TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: AppColors.textPrimary,
            selectionColor: const Color(0xFFFFDC71).withOpacity(0.35),
            selectionHandleColor: const Color(0xFFFFC107),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.inputBackground,
            hintStyle: TextStyle(color: AppColors.textHint),
            labelStyle: TextStyle(color: AppColors.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFFDC71), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor:   Color(0xFFFFDC71),
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
          ),
        ),

        // ════════════════════════════════════════════════════════
        // ROUTING
        // ════════════════════════════════════════════════════════
        initialRoute: '/',
        onGenerateRoute: (settings) {
          debugPrint('🧭 [NAVIGATION] Route: ${settings.name}');

          switch (settings.name) {

          // ── Auth ────────────────────────────────────────────
            case '/':
              return MaterialPageRoute(builder: (_) => const SplashScreen());

            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());

            case '/signup/passenger':
              return MaterialPageRoute(builder: (_) => const SignupPassengerScreen());

            case '/signup/driver':
              return MaterialPageRoute(builder: (_) => const SignupDriverScreen());

            case '/forgot-password':
              return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

          // ── Dashboards ──────────────────────────────────────
            case '/dashboard/passenger':
              return MaterialPageRoute(builder: (_) => const PassengerDashboard());

            case '/dashboard/driver':
              return MaterialPageRoute(
                builder: (_) => DriverNavigationWrapper(
                  initialAccessToken: settings.arguments as String?,
                ),
              );

            case '/dashboard/delivery-agent':
              return MaterialPageRoute(builder: (_) => const DeliveryAgentDashboard());

          // ── Profile ─────────────────────────────────────────
            case '/profile':
              return MaterialPageRoute(builder: (_) => const ProfileScreen());

            case '/profile/edit':
              return MaterialPageRoute(builder: (_) => const EditProfileScreen());

            case '/profile/change-password':
              return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());

            case '/profile/avatar':
              return MaterialPageRoute(builder: (_) => const ChangeAvatarScreen());

            case '/profile/help':
              return MaterialPageRoute(builder: (_) => const HelpFAQScreen());

            case '/profile/notifications':
              return MaterialPageRoute(builder: (_) => const NotificationScreen());

            case '/profile/privacy':
              return MaterialPageRoute(builder: (_) => const PrivacySecurityScreen());

            case '/profile/support':
              return MaterialPageRoute(builder: (_) => const ContactSupportScreen());

            case '/profile/report-problem':
              return MaterialPageRoute(builder: (_) => const ReportProblemScreen());

            case '/profile/vehicle':
              return MaterialPageRoute(builder: (_) => const VehicleInfoScreen());

            case '/profile/documents':
              return MaterialPageRoute(builder: (_) => const DriverDocumentsScreen());

          // ── Notifications ────────────────────────────────────
            case '/notifications':
              return MaterialPageRoute(
                builder: (_) => const NotificationScreen(),
              );

          // ── Services Marketplace ────────────────────────────
            case '/services':
              return MaterialPageRoute(builder: (_) => const ServicesHomeScreen());

            case '/services/detail':
              final args    = settings.arguments as Map<String, dynamic>?;
              final listingId = args?['listingId'] as int?;
              return MaterialPageRoute(
                builder: (_) => ServiceDetailScreen(listingId: listingId),
              );

            case '/services/listing-plan':
              return MaterialPageRoute(builder: (_) => const ListingPlanScreen());

            case '/services/post':
              return MaterialPageRoute(builder: (_) => PostServiceScreen());

            case '/services/my-listings':
              return MaterialPageRoute(builder: (_) => MyListingsScreen());

            case '/services/my-subscription':
              return MaterialPageRoute(builder: (_) => const MySubscriptionScreen());

            case '/services/categories':
              return MaterialPageRoute(builder: (_) => const AllCategoriesScreen());

            case '/services/category-listings':
              final args     = settings.arguments as Map<String, dynamic>;
              final category = args['category'] as ServiceCategory;
              return MaterialPageRoute(
                builder: (_) => CategoryListingsScreen(category: category),
              );

            case '/services/search':
              final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => ServiceSearchScreen(
                  initialQuery: args?['query'] as String?,
                ),
              );

            case '/services/edit-listing':
              final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => EditListingScreen(
                  listing: args?['listing'] as ServiceListing,
                ),
              );

          // ── Default ─────────────────────────────────────────
            default:
              return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SOCKET HELPER (unchanged)
// ═══════════════════════════════════════════════════════════════════════

class SocketHelper {
  static SocketHelper? _instance;
  static SocketService? _socketService;

  SocketHelper._();

  static SocketHelper get instance {
    _instance ??= SocketHelper._();
    return _instance!;
  }

  static SocketService? get socketService => _socketService;

  static Future<void> initialize() async {
    debugPrint('🔌 [SOCKET-HELPER] Initializing...');
    _socketService = SocketService();
    debugPrint('✅ [SOCKET-HELPER] Initialized successfully');
  }

  static Future<void> connect({
    required String accessToken,
    required String userId,
    required String userType,
    Future<String?> Function()? onTokenExpired,
  }) async {
    if (_socketService == null) {
      debugPrint('❌ [SOCKET-HELPER] Socket service not initialized');
      return;
    }

    final socketUrl = dotenv.env['SOCKET_URL'] ?? 'http://10.0.2.2:4000';

    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔌 [SOCKET-HELPER] Connecting to socket...');
    debugPrint('   URL: $socketUrl | User: $userId | Type: $userType');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    try {
      await _socketService!.connect(
        url:          socketUrl,
        accessToken:  accessToken,
        userId:       userId,
        userType:     userType,
        onTokenExpired: onTokenExpired,
      );
      debugPrint('✅ [SOCKET-HELPER] Connected successfully\n');
    } catch (e) {
      debugPrint('❌ [SOCKET-HELPER] Connection failed: $e\n');
    }
  }

  static void disconnect() {
    if (_socketService == null) return;
    debugPrint('🔌 [SOCKET-HELPER] Disconnecting...');
    _socketService!.disconnect();
    debugPrint('✅ [SOCKET-HELPER] Disconnected\n');
  }

  void reconnect() {
    if (_socketService == null) return;
    _attemptReconnectWithStoredCredentials();
  }

  Future<void> _attemptReconnectWithStoredCredentials() async {
    try {
      final prefs       = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final userId      = prefs.getString('user_uuid');
      final userType    = prefs.getString('user_type');
      if (accessToken != null && userId != null && userType != null) {
        await connect(accessToken: accessToken, userId: userId, userType: userType);
      }
    } catch (e) {
      debugPrint('❌ [SOCKET-HELPER] Reconnect failed: $e');
    }
  }

  dynamic get socket                                    => _socketService?.socket;
  Stream<bool> get connectionStateStream                => _socketService?.connectionStateStream ?? Stream.value(false);
  Stream<Map<String, dynamic>> get tripOfferStream      => _socketService?.tripOfferStream ?? const Stream.empty();
  Stream<Map<String, dynamic>> get tripCanceledStream   => _socketService?.tripCanceledStream ?? const Stream.empty();
  Stream<Map<String, dynamic>> get tripMatchedStream    => _socketService?.tripMatchedStream ?? const Stream.empty();
  Stream<Map<String, dynamic>> get tripStatusStream     => _socketService?.tripStatusStream ?? const Stream.empty();
  Stream<Map<String, dynamic>> get driverLocationStream => _socketService?.driverLocationStream ?? const Stream.empty();
  bool get isConnected                                  => socket?.connected ?? false;

  void emit(String event, dynamic data) {
    if (socket == null) return;
    socket.emit(event, data);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AUTO-CONNECT ON APP STARTUP
// ═══════════════════════════════════════════════════════════════════════

Future<void> autoConnectIfLoggedIn() async {
  try {
    final prefs       = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final userId      = prefs.getString('user_uuid');
    final userType    = prefs.getString('user_type');
    if (accessToken != null && userId != null && userType != null) {
      await SocketHelper.connect(
        accessToken: accessToken,
        userId:      userId,
        userType:    userType,
      );
    }
  } catch (e) {
    debugPrint('❌ [AUTO-CONNECT] Failed: $e');
  }
}
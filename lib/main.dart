// lib/main.dart
// WEGO App - Complete Main Entry Point
// Includes: Ride Booking + Services Marketplace + Profile Management

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wego_v1/screens/delivery%20agent/dashboard/delivery_agent_dashboard.dart';
import 'package:wego_v1/screens/services/dispute_filling_screen.dart';
import 'package:wego_v1/screens/services/edit_listing_screen.dart';
import 'package:wego_v1/screens/services/search_screen.dart';
import 'package:wego_v1/screens/splash/splash.dart';

// ═══════════════════════════════════════════════════════════════════════
// SCREENS - AUTHENTICATION
// ═══════════════════════════════════════════════════════════════════════
import 'models/services/service_listing_model.dart';
import 'models/services/service_request_model.dart';
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
import 'screens/driver/driver_container/driver_container_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// SCREENS - ACCOUNT
// ═══════════════════════════════════════════════════════════════════════
import 'screens/passenger/account/my_account/account_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// SCREENS - PROFILE MANAGEMENT ✅ NEW
// ═══════════════════════════════════════════════════════════════════════
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/change_password_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// SCREENS - SERVICES MARKETPLACE
// ═══════════════════════════════════════════════════════════════════════
import 'screens/services/services_home_screen.dart';
import 'screens/services/service_detail_screen.dart';
import 'screens/services/contact_provider_screen.dart';
import 'screens/services/all_categories_screen.dart';
import 'screens/services/category_listings_screen.dart';
import 'screens/services/incoming_requests_screen.dart';
import 'screens/services/my_bookings_screen.dart';
import 'screens/services/my_listings_screen.dart';
import 'screens/services/post_service_screen.dart';

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
    debugPrint("🗺️  Google Maps Key: ${dotenv.env['GOOGLE_MAPS_API_KEY']?.substring(0, 10)}...");
    debugPrint("🔌 Socket URL: ${dotenv.env['SOCKET_URL']}");
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  } catch (e) {
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    debugPrint("❌ [STARTUP ERROR] Failed to load .env file");
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    debugPrint("Error: $e");
    debugPrint("⚠️  Make sure .env file exists in project root");
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
  }

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZE SOCKET HELPER
  // ═══════════════════════════════════════════════════════════════
  await SocketHelper.initialize();

  // ═══════════════════════════════════════════════════════════════
  // SET SYSTEM UI OVERLAY STYLE
  // ═══════════════════════════════════════════════════════════════
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

  runApp(const WegoApp());
}

// ═══════════════════════════════════════════════════════════════════════
// MAIN APP
// ═══════════════════════════════════════════════════════════════════════

class WegoApp extends StatelessWidget {
  const WegoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ═══════════════════════════════════════════════════════════════
        // RIDE BOOKING PROVIDERS
        // ═══════════════════════════════════════════════════════════════

        /// Trip Provider for real-time trip management
        ChangeNotifierProvider(
          create: (_) => TripProvider(),
        ),

        /// Chat Service for in-app messaging
        ChangeNotifierProvider(
          create: (_) => ChatService(SocketHelper.socketService!),
        ),

        // ═══════════════════════════════════════════════════════════════
        // SERVICES MARKETPLACE & PROFILE PROVIDERS
        // ═══════════════════════════════════════════════════════════════

        /// Services Provider for marketplace (categories, listings, requests, ratings, disputes)
        ChangeNotifierProvider(
          create: (_) => ServicesProvider(),
        ),

        /// Profile Provider for user profile management ✅ NEW
        ChangeNotifierProvider(
          create: (_) => ProfileProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'WEGO',
        debugShowCheckedModeBanner: false,

        // ════════════════════════════════════════════════════════
        // THEME CONFIGURATION (WEGO Gold & Black)
        // ════════════════════════════════════════════════════════
        theme: ThemeData(
          useMaterial3: true,

          // WEGO Gold color scheme
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFDC71), // WEGO Gold
            primary: const Color(0xFFFFDC71),
            secondary: const Color(0xFFF5C844),
            surface: Colors.white,
            background: const Color(0xFFF5F5F5),
          ),

          scaffoldBackgroundColor: const Color(0xFFF5F5F5),

          // AppBar Theme
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            titleTextStyle: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Elevated Button Theme
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDC71), // WEGO Gold
              foregroundColor: Colors.black87,
              elevation: 2,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Input Decoration Theme
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFFFDC71), // WEGO Gold
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),

          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),

          // Bottom Navigation Bar Theme
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: Color(0xFFFFDC71),
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
          // ══════════════════════════════════════════════════
          // AUTHENTICATION ROUTES
          // ══════════════════════════════════════════════════

            case '/':
              return MaterialPageRoute(
                builder: (_) => const SplashScreen(),
              );
            case '/login':
              return MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              );

            case '/signup/passenger':
              return MaterialPageRoute(
                builder: (_) => const SignupPassengerScreen(),
              );

            case '/signup/driver':
              return MaterialPageRoute(
                builder: (_) => const SignupDriverScreen(),
              );

            case '/forgot-password':
              return MaterialPageRoute(
                builder: (_) => const ForgotPasswordScreen(),
              );

          // ══════════════════════════════════════════════════
          // DASHBOARD ROUTES
          // ══════════════════════════════════════════════════
            case '/dashboard/passenger':
              return MaterialPageRoute(
                builder: (_) => const PassengerDashboard(),
              );

            case '/dashboard/driver':
              return MaterialPageRoute(
                builder: (_) => DriverNavigationWrapper(
                  initialAccessToken: settings.arguments as String?,
                ),
              );
            case '/dashboard/delivery-agent':
              return MaterialPageRoute(
                builder: (_) => DeliveryAgentDashboard(
                ),
              );

          // ══════════════════════════════════════════════════
          // ACCOUNT ROUTES
          // ══════════════════════════════════════════════════
            case '/account':
              return MaterialPageRoute(
                builder: (_) => const AccountScreen(
                  user: {},
                  accessToken: '',
                ),
              );

          // ══════════════════════════════════════════════════
          // PROFILE
          // ══════════════════════════════════════════════════
            case '/profile':
              return MaterialPageRoute(
                builder: (_) => const ProfileScreen(),
              );

            case '/profile/edit':
              return MaterialPageRoute(
                builder: (_) => const EditProfileScreen(),
              );

            case '/profile/change-password':
              return MaterialPageRoute(
                builder: (_) => const ChangePasswordScreen(),
              );

            case '/profile/avatar':
              return MaterialPageRoute(
                builder: (_) => const _ComingSoonScreen(
                  title: 'Change Avatar',
                  message: 'Upload or change your profile picture',
                ),
              );

            case '/profile/help':
              return MaterialPageRoute(
                builder: (_) => const _ComingSoonScreen(
                  title: 'Help & FAQ',
                  message: 'Get answers to common questions',
                ),
              );

            case '/profile/notifications':
              return MaterialPageRoute(
                builder: (_) => const _ComingSoonScreen(
                  title: 'Notification Settings',
                  message: 'Manage your notification preferences',
                ),
              );

            case '/profile/privacy':
              return MaterialPageRoute(
                builder: (_) => const _ComingSoonScreen(
                  title: 'Privacy & Security',
                  message: 'Control your privacy settings',
                ),
              );

            case '/profile/support':
              return MaterialPageRoute(
                builder: (_) => const _ComingSoonScreen(
                  title: 'Contact Support',
                  message: 'Get help from our support team',
                ),
              );

            case '/profile/report-problem':
              return MaterialPageRoute(
                builder: (_) => const _ComingSoonScreen(
                  title: 'Report a Problem',
                  message: 'Let us know about any issues',
                ),
              );

            case '/profile/vehicle':
              return MaterialPageRoute(
                builder: (_) => const _ComingSoonScreen(
                  title: 'Vehicle Information',
                  message: 'Manage your vehicle details',
                ),
              );

            case '/profile/documents':
              return MaterialPageRoute(
                builder: (_) => const _ComingSoonScreen(
                  title: 'Driver Documents',
                  message: 'Manage your license, CNI, and insurance',
                ),
              );

          // ══════════════════════════════════════════════════
          // SERVICES MARKETPLACE ROUTES
          // ══════════════════════════════════════════════════

          // Services Home
            case '/services':
              return MaterialPageRoute(
                builder: (_) => const ServicesHomeScreen(),
              );

          // Service Detail
            case '/services/detail':
              final args = settings.arguments as Map<String, dynamic>?;
              final listingId = args?['listingId'] as int?;

              return MaterialPageRoute(
                builder: (_) => ServiceDetailScreen(
                  listingId: listingId,
                ),
              );

          // Contact Provider / Book Service
            case '/services/contact':
              final args = settings.arguments as Map<String, dynamic>?;
              final listing = args?['listing'];

              return MaterialPageRoute(
                builder: (_) => ContactProviderScreen(
                  listing: listing,
                ),
              );

          // Incoming Requests (Provider View)
            case '/services/incoming-requests':
              return MaterialPageRoute(
                builder: (_) => const IncomingRequestsScreen(),
              );

          // Post Service
            case '/services/post':
              return MaterialPageRoute(
                builder: (_) => PostServiceScreen(),
              );

          // My Bookings
            case '/services/my-bookings':
              return MaterialPageRoute(
                builder: (_) => MyBookingsScreen(),
              );

          // My Listings
            case '/services/my-listings':
              return MaterialPageRoute(
                builder: (_) => MyListingsScreen(),
              );

          // All Categories
            case '/services/categories':
              return MaterialPageRoute(
                builder: (_) => const AllCategoriesScreen(),
              );

          // Category Listings
            case '/services/category-listings':
              final args = settings.arguments as Map<String, dynamic>;
              final category = args['category'] as ServiceCategory;
              return MaterialPageRoute(
                builder: (_) => CategoryListingsScreen(
                  category: category,
                ),
              );

          // All Services (Coming Soon)
            case '/services/all':
              return MaterialPageRoute(
                builder: (_) => const _ComingSoonScreen(
                  title: 'All Services',
                  message: 'Browse all available services',
                ),
              );
            case '/services/search':
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => ServiceSearchScreen(
                  initialQuery: args?['query'] as String?,
                ),
              );

          // All Reviews (Coming Soon)
            case '/services/reviews':
              return MaterialPageRoute(
                builder: (_) => const _ComingSoonScreen(
                  title: 'Reviews',
                  message: 'Read all reviews for this service',
                ),
              );
            case '/services/dispute':
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => DisputeFilingScreen(
                  request: args?['request'] as ServiceRequest,
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

          // ══════════════════════════════════════════════════
          // DEFAULT ROUTE
          // ══════════════════════════════════════════════════
            default:
              return MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              );
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COMING SOON SCREEN (Placeholder for unimplemented screens)
// ═══════════════════════════════════════════════════════════════════════

class _ComingSoonScreen extends StatelessWidget {
  final String title;
  final String message;

  const _ComingSoonScreen({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFDC71), Color(0xFFF5C844)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFDC71).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.construction,
                  size: 64,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Coming Soon!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFDC71),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text(
                  'Go Back',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SOCKET HELPER (Existing)
// ═══════════════════════════════════════════════════════════════════════

class SocketHelper {
  // ═══════════════════════════════════════════════════════════════
  // SINGLETON PATTERN
  // ═══════════════════════════════════════════════════════════════

  static SocketHelper? _instance;
  static SocketService? _socketService;

  SocketHelper._();

  static SocketHelper get instance {
    _instance ??= SocketHelper._();
    return _instance!;
  }

  /// Expose socket service for ChatService
  static SocketService? get socketService => _socketService;

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════

  static Future<void> initialize() async {
    debugPrint('🔌 [SOCKET-HELPER] Initializing...');
    _socketService = SocketService();
    debugPrint('✅ [SOCKET-HELPER] Initialized successfully');
  }

  // ═══════════════════════════════════════════════════════════════
  // CONNECTION MANAGEMENT
  // ═══════════════════════════════════════════════════════════════

  /// Connect to the socket server after login
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
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🌐 URL: $socketUrl');
    debugPrint('👤 User ID: $userId');
    debugPrint('🎭 User Type: $userType');
    debugPrint('🎫 Token: ${accessToken.substring(0, 20)}...');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    try {
      await _socketService!.connect(
        url: socketUrl,
        accessToken: accessToken,
        userId: userId,
        userType: userType,
        onTokenExpired: onTokenExpired,
      );

      debugPrint('✅ [SOCKET-HELPER] Connected successfully\n');
    } catch (e) {
      debugPrint('❌ [SOCKET-HELPER] Connection failed: $e\n');
    }
  }

  /// Disconnect from the socket server
  static void disconnect() {
    if (_socketService == null) return;

    debugPrint('🔌 [SOCKET-HELPER] Disconnecting...');
    _socketService!.disconnect();
    debugPrint('✅ [SOCKET-HELPER] Disconnected\n');
  }

  /// Reconnect to the socket server
  void reconnect() {
    if (_socketService == null) {
      debugPrint('❌ [SOCKET-HELPER] Cannot reconnect - service not initialized');
      return;
    }

    debugPrint('🔄 [SOCKET-HELPER] Attempting to reconnect...');
    _attemptReconnectWithStoredCredentials();
  }

  Future<void> _attemptReconnectWithStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final userId = prefs.getString('user_uuid');
      final userType = prefs.getString('user_type');

      if (accessToken != null && userId != null && userType != null) {
        debugPrint('🔑 [SOCKET-HELPER] Found stored credentials, reconnecting...');
        await connect(
          accessToken: accessToken,
          userId: userId,
          userType: userType,
        );
      } else {
        debugPrint('❌ [SOCKET-HELPER] Cannot reconnect - missing connection details');
      }
    } catch (e) {
      debugPrint('❌ [SOCKET-HELPER] Reconnect failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // GETTERS FOR SOCKET ACCESS
  // ═══════════════════════════════════════════════════════════════

  /// Get the underlying socket instance (for emit operations)
  dynamic get socket => _socketService?.socket;

  /// Get connection state stream
  Stream<bool> get connectionStateStream {
    if (_socketService == null) {
      debugPrint('⚠️ [SOCKET-HELPER] Socket service not initialized');
      return Stream.value(false);
    }
    return _socketService!.connectionStateStream;
  }

  /// Get trip offer stream (for drivers)
  Stream<Map<String, dynamic>> get tripOfferStream {
    if (_socketService == null) {
      debugPrint('⚠️ [SOCKET-HELPER] Socket service not initialized');
      return const Stream.empty();
    }
    return _socketService!.tripOfferStream;
  }

  /// Get trip canceled stream
  Stream<Map<String, dynamic>> get tripCanceledStream {
    if (_socketService == null) {
      debugPrint('⚠️ [SOCKET-HELPER] Socket service not initialized');
      return const Stream.empty();
    }
    return _socketService!.tripCanceledStream;
  }

  /// Get trip matched stream (for drivers)
  Stream<Map<String, dynamic>> get tripMatchedStream {
    if (_socketService == null) {
      debugPrint('⚠️ [SOCKET-HELPER] Socket service not initialized');
      return const Stream.empty();
    }
    return _socketService!.tripMatchedStream;
  }

  /// Get trip status stream (for passengers)
  Stream<Map<String, dynamic>> get tripStatusStream {
    if (_socketService == null) {
      debugPrint('⚠️ [SOCKET-HELPER] Socket service not initialized');
      return const Stream.empty();
    }
    return _socketService!.tripStatusStream;
  }

  /// Get driver location stream (for passengers)
  Stream<Map<String, dynamic>> get driverLocationStream {
    if (_socketService == null) {
      debugPrint('⚠️ [SOCKET-HELPER] Socket service not initialized');
      return const Stream.empty();
    }
    return _socketService!.driverLocationStream;
  }

  // ═══════════════════════════════════════════════════════════════
  // CONVENIENCE METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Check if socket is connected
  bool get isConnected => socket?.connected ?? false;

  /// Emit an event to the server
  void emit(String event, dynamic data) {
    if (socket == null) {
      debugPrint('⚠️ [SOCKET-HELPER] Cannot emit - socket not connected');
      return;
    }

    debugPrint('📤 [SOCKET-HELPER] Emitting event: $event');
    socket.emit(event, data);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AUTO-CONNECT ON APP STARTUP (OPTIONAL)
// ═══════════════════════════════════════════════════════════════════════

/// Auto-connect to socket if user is already logged in
Future<void> autoConnectIfLoggedIn() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    final userId = prefs.getString('user_uuid');
    final userType = prefs.getString('user_type');

    if (accessToken != null && userId != null && userType != null) {
      debugPrint('🔑 [AUTO-CONNECT] Found stored credentials');
      await SocketHelper.connect(
        accessToken: accessToken,
        userId: userId,
        userType: userType,
      );
    } else {
      debugPrint('ℹ️ [AUTO-CONNECT] No stored credentials found');
    }
  } catch (e) {
    debugPrint('❌ [AUTO-CONNECT] Failed: $e');
  }
}
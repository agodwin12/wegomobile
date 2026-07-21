// lib/screens/driver/navigation_wrapper/driver_navigation_wrapper.dart

import 'package:flutter/material.dart';

import '../dashboard/dashboard.dart'; // DriverMainScreen
import '../driver earnings/driver_earnings_screen.dart';
import '../navigation bar/bottom_navigation.dart'; // WegoBottomNavigation
import '../trip history/driver_trips_screen.dart'; // DriverTripsScreen
import 'package:wego_v1/screens/notification/notification_screen.dart';
import 'package:wego_v1/screens/profile/profile_screen.dart';

class DriverNavigationWrapper extends StatefulWidget {
  final String? initialAccessToken;

  const DriverNavigationWrapper({
    super.key,
    this.initialAccessToken,
  });

  @override
  State<DriverNavigationWrapper> createState() => _DriverNavigationWrapperState();
}

class _DriverNavigationWrapperState extends State<DriverNavigationWrapper> {
  int _selectedIndex = 0;

  // ✅ Keep dashboard alive (socket + online state)
  late final Widget _dashboardScreen;

  // ✅ Trips is lazy-created only when user opens Trips
  Widget? _tripsScreen;

  @override
  void initState() {
    super.initState();

    _dashboardScreen = DriverMainScreen(
      initialAccessToken: widget.initialAccessToken,
    );
  }

  void _handleNavbarTap(int index) {
    debugPrint('🚕 [DRIVER-NAV] Tab tapped: $index');
    if (!mounted) return;

    switch (index) {
      case 0: // Home
        setState(() => _selectedIndex = 0);
        break;

      case 1: // Trips
        setState(() {
          _selectedIndex = 1;
          _tripsScreen ??= const DriverTripsScreen(); // ✅ no onBack param
        });
        break;

      case 2: // Earnings
        setState(() => _selectedIndex = 2);
        break;

      case 3: // Alerts
        _navigateToNotifications();
        break;

      case 4: // Profile (push route)
        _navigateToProfile();
        break;

      default:
        setState(() => _selectedIndex = 0);
    }
  }

  void _navigateToProfile() {
    debugPrint('👤 [DRIVER-NAV] Navigating to profile...');

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    ).then((_) {
      if (!mounted) return;
      setState(() => _selectedIndex = 0);
    });
  }

  void _navigateToNotifications() {
    debugPrint('🔔 [DRIVER-NAV] Navigating to notifications...');

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    ).then((_) {
      if (!mounted) return;
      setState(() => _selectedIndex = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Guard to avoid index overflow
    final safeIndex = (_selectedIndex < 0 || _selectedIndex > 4) ? 0 : _selectedIndex;

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: [
          _dashboardScreen, // 0 Home
          _tripsScreen ?? const SizedBox.shrink(), // 1 Trips (lazy)
          const DriverEarningsScreen(),
          const SizedBox.shrink(), // 3 Alerts
          const SizedBox.shrink(), // 4 Profile (pushed)
        ],
      ),
      bottomNavigationBar: WegoBottomNavigation(
        currentIndex: safeIndex,
        onTabSelected: _handleNavbarTap,
      ),
    );
  }
}
// lib/screens/driver/driver_container_screen.dart
// Driver Container with Bottom Navigation + Services Marketplace

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/services_home_screen.dart';
import '../dashboard/dashboard.dart';


class DriverContainerScreen extends StatefulWidget {
  final String? initialAccessToken;

  const DriverContainerScreen({
    Key? key,
    this.initialAccessToken,
  }) : super(key: key);

  @override
  State<DriverContainerScreen> createState() => _DriverContainerScreenState();
}

class _DriverContainerScreenState extends State<DriverContainerScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      // 0: Home - Driver Dashboard
      DriverMainScreen(initialAccessToken: widget.initialAccessToken),

      // 1: Trips - (Keep existing trips screen or placeholder)
      _buildPlaceholderScreen('Courses', Icons.directions_car),

      // 2: Services - NEW! Services Marketplace
      const ServicesHomeScreen(),

      // 3: Earnings - (Keep existing or placeholder)
      _buildPlaceholderScreen('Gains', Icons.attach_money),

      // 4: Profile - (Keep existing or placeholder)
      _buildPlaceholderScreen('Profil', Icons.person),
    ];
  }

  void _onTabSelected(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: const Color(0xFFFFDC71),
            width: 2,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                label: 'Accueil',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.directions_car_outlined,
                label: 'Courses',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.construction_outlined, // Services icon
                label: 'Services',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.attach_money_outlined,
                label: 'Gains',
                index: 3,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                label: 'Profil',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _onTabSelected(index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFFFFDC71) : Colors.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? const Color(0xFFFFDC71) : Colors.white,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder screen for tabs not yet implemented
  Widget _buildPlaceholderScreen(String title, IconData icon) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: const Color(0xFFFFDC71),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              '$title - Coming Soon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
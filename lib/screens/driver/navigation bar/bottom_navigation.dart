// lib/widgets/wego_bottom_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WegoBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const WegoBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: Color(0xFFFFDC71),
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
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.directions_car_outlined,
                label: 'Trips',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.attach_money_outlined,
                label: 'Earnings',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.notifications_outlined,
                label: 'Alerts',
                index: 3,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
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
    final isSelected = currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // ✅ full tappable area
      onTap: () {
        debugPrint(
            'WegoBottomNav: Tab tapped - switching from $currentIndex to $index ($label)');
        HapticFeedback.lightImpact();
        onTabSelected(index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
      ),
    );
  }
}
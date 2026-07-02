// lib/presentation/widgets/passenger_bottom_navbar.dart

import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';

class PassengerBottomNavbar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const PassengerBottomNavbar({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final navItems = [
      {'icon': Icons.home_rounded, 'label': tr('nav.home'), 'index': 0},
      {'icon': Icons.receipt_long_rounded, 'label': tr('nav.activity'), 'index': 1},
      {'icon': Icons.person_rounded, 'label': tr('nav.account'), 'index': 2},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: navItems.map((item) {
              final isSelected = selectedIndex == item['index'] as int;

              return GestureDetector(
                onTap: () {
                  print('📱 [NAVBAR] Nav item tapped: ${item['label']}');
                  final index = item['index'] as int;

                  // Always call the callback - parent handles navigation
                  onItemTapped(index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGold.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: isSelected
                            ? AppColors.primaryGold
                            : const Color(0xFF9CA3AF),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['label'] as String,
                        style: AppTypography.caption.copyWith(
                          color: isSelected
                              ? AppColors.primaryGold
                              : const Color(0xFF9CA3AF),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../l10n/tr.dart';
import '../../../utils/app_colors.dart';

/// Shown when matching finishes with no available driver (backend emits
/// `trip:no_drivers`). Replaces the searching screen so the passenger is never
/// stuck on an infinite spinner. Pops with `true` (retry) or `false` (cancel) —
/// both return to the ride map, where the passenger can request again.
class NoDriversScreen extends StatelessWidget {
  /// Optional server message. When null we fall back to the localized default so
  /// the language switcher always applies.
  final String? message;
  const NoDriversScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final body = (message != null && message!.trim().isNotEmpty)
        ? message!
        : tr('trip.noDriversMessage');

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              // Branded Lottie instead of a flat icon.
              Lottie.asset(
                'assets/lottie/ride_no_drivers.json',
                width: 200,
                height: 200,
                repeat: true,
                errorBuilder: (_, __, ___) => Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.no_transfer_rounded,
                      color: AppColors.primaryGold, size: 52),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr('trip.noDriversTitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.darkTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.darkTextSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    tr('common.retry'),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    tr('common.cancel'),
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

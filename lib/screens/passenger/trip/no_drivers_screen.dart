import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';

/// Shown when matching finishes with no available driver (backend emits
/// `trip:no_drivers`). Replaces the searching screen so the passenger is never
/// stuck on an infinite spinner. Pops with `true` (retry) or `false` (cancel) —
/// both return to the ride map, where the passenger can request again.
class NoDriversScreen extends StatelessWidget {
  final String message;
  const NoDriversScreen({
    super.key,
    this.message = 'Aucun chauffeur disponible pour le moment. Veuillez réessayer dans un instant.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.no_transfer_rounded,
                    color: AppColors.primaryGold, size: 52),
              ),
              const SizedBox(height: 28),
              const Text(
                'Aucun chauffeur disponible',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.darkTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
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
                    'Réessayer',
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
                  child: const Text(
                    'Annuler',
                    style: TextStyle(
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

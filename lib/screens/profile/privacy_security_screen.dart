// lib/screens/profile/privacy_security_screen.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// PRIVACY & SECURITY
// ═══════════════════════════════════════════════════════════════════════════
// Replaces the "Coming Soon" placeholder behind /profile/privacy. Every control
// here is backed by something real — the change-password screen, the actual OS
// permission state, and the terms/privacy URLs from AppConfig. Nothing is a
// decorative toggle that silently does nothing.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../l10n/tr.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import 'change_password_screen.dart';

const Color _kCanvas = Color(0xFFF5F4F0);
const Color _kBorder = Color(0xFFE8E6E0);

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen>
    with WidgetsBindingObserver {
  bool? _locationGranted;
  bool? _notificationsGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have flipped a permission in the OS settings and come back.
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final location = await Geolocator.checkPermission();
    final notifications = await Permission.notification.status;
    if (!mounted) return;
    setState(() {
      _locationGranted = location == LocationPermission.always ||
          location == LocationPermission.whileInUse;
      _notificationsGranted = notifications.isGranted;
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showDataDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('priv.dataUse'),
          style: TextStyle(
            fontFamily: AppTypography.primaryFont,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            tr('priv.dataDialogBody'),
            style: TextStyle(
              fontFamily: AppTypography.secondaryFont,
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              tr('common.close'),
              style: const TextStyle(
                fontFamily: AppTypography.secondaryFont,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGoldDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        title: Text(
          tr('priv.title'),
          style: const TextStyle(
            fontFamily: AppTypography.primaryFont,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _SectionTitle(tr('priv.accountSection')),
          _Card(
            children: [
              _Row(
                icon: Icons.lock_outline_rounded,
                title: tr('priv.changePassword'),
                subtitle: tr('priv.changePasswordSub'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _SectionTitle(tr('priv.permSection')),
          _Card(
            children: [
              _Row(
                icon: Icons.my_location_rounded,
                title: tr('priv.location'),
                subtitle: tr('priv.locationSub'),
                trailing: _StatusBadge(granted: _locationGranted),
                onTap: () => Geolocator.openAppSettings(),
              ),
              const _Divider(),
              _Row(
                icon: Icons.notifications_none_rounded,
                title: tr('priv.notifications'),
                subtitle: tr('priv.notificationsSub'),
                trailing: _StatusBadge(granted: _notificationsGranted),
                onTap: openAppSettings,
              ),
            ],
          ),
          const SizedBox(height: 24),

          _SectionTitle(tr('priv.dataSection')),
          _Card(
            children: [
              _Row(
                icon: Icons.shield_outlined,
                title: tr('priv.dataUse'),
                subtitle: tr('priv.dataUseSub'),
                onTap: _showDataDialog,
              ),
              const _Divider(),
              _Row(
                icon: Icons.description_outlined,
                title: tr('priv.terms'),
                onTap: () => _openUrl(AppConfig.termsUrl),
              ),
              const _Divider(),
              _Row(
                icon: Icons.privacy_tip_outlined,
                title: tr('priv.privacyPolicy'),
                onTap: () => _openUrl(AppConfig.privacyUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PIECES
// ═══════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: AppTypography.secondaryFont,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 60),
      child: Divider(height: 1, thickness: 1, color: _kBorder),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primaryGoldDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTypography.secondaryFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: AppTypography.secondaryFont,
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  /// null while the permission state is still being read.
  final bool? granted;

  const _StatusBadge({required this.granted});

  @override
  Widget build(BuildContext context) {
    if (granted == null) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final ok = granted!;
    final color = ok ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ok ? tr('priv.granted') : tr('priv.denied'),
        style: TextStyle(
          fontFamily: AppTypography.secondaryFont,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

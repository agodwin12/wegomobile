// lib/screens/profile/profile_screen.dart
// WEGO - Main Profile Screen (Beautiful Black & White Design)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../core/app_settings.dart';
import '../../l10n/tr.dart';
import '../../providers/profile_provider.dart';
import '../../models/user_profile_model.dart';
import '../../providers/services.dart';
import '../../providers/trip_provider.dart';
import '../../service/notification_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      print('❌ [PROFILE SCREEN] No token found - redirecting to login');
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
      return;
    }

    print('✅ [PROFILE SCREEN] Token found, loading profile...');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      final provider = context.read<ProfileProvider>();
      await provider.loadProfile();
    } catch (e) {
      print('❌ [PROFILE SCREEN] Error loading data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingProfile) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
              ),
            );
          }

          if (provider.profile == null) {
            return _buildErrorState();
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primaryGold,
            child: CustomScrollView(
              slivers: [
                _buildModernAppBar(provider.profile!),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildProfileCard(provider.profile!),
                      const SizedBox(height: 16),
                      _buildStatsCard(provider.profile!.stats),
                      const SizedBox(height: 16),
                      if (provider.isDriver) ...[
                        _buildDriverCard(),
                        const SizedBox(height: 16),
                      ],
                      _buildMenuSection('Account', _buildAccountItems()),
                      const SizedBox(height: 16),
                      _buildMenuSection('Settings', _buildSettingsItems()),
                      const SizedBox(height: 16),
                      _buildMenuSection('Help & Support', _buildSupportItems()),
                      const SizedBox(height: 16),
                      _buildDangerZone(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // MODERN APP BAR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildModernAppBar(UserProfile profile) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primaryBlack,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textWhite),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: AppColors.primaryGold),
          onPressed: () => _navigateTo('/profile/edit'),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Profile',
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.textWhite,
          ),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PROFILE CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildProfileCard(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryBlack, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _navigateTo('/profile/avatar'),
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'profile_avatar',
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryGold,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGold.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                                ? Image.network(
                              profile.avatarUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                        : null,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryGold,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('❌ [PROFILE] Error loading avatar: $error');
                                return Container(
                                  color: AppColors.primaryGold,
                                  child: Center(
                                    child: Text(
                                      profile.getInitials(),
                                      style: AppTypography.displayMedium.copyWith(
                                        color: AppColors.primaryBlack,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                                : Container(
                              color: AppColors.primaryGold,
                              child: Center(
                                child: Text(
                                  profile.getInitials(),
                                  style: AppTypography.displayMedium.copyWith(
                                    color: AppColors.primaryBlack,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryBlack,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: AppColors.primaryBlack,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.fullName,
                  style: AppTypography.displaySmall.copyWith(
                    color: AppColors.textWhite,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (profile.isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryGold,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified,
                              size: 14,
                              color: AppColors.primaryGold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primaryGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Info Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Role Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildModernBadge(
                      profile.role.toUpperCase(),
                      AppColors.primaryGold,
                      AppColors.primaryBlack,
                    ),
                    if (profile.isDriver)
                      _buildModernBadge(
                        'DRIVER',
                        AppColors.info,
                        AppColors.backgroundWhite,
                      ),
                    if (profile.isServiceProvider)
                      _buildModernBadge(
                        'SERVICE PROVIDER',
                        AppColors.success,
                        AppColors.backgroundWhite,
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Contact Info
                _buildInfoItem(Icons.email_outlined, profile.email),
                const SizedBox(height: 12),
                _buildInfoItem(Icons.phone_outlined, profile.getFormattedPhone()),
                if (profile.city != null && profile.city!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoItem(Icons.location_city_outlined, profile.city!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primaryBlack,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATS CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildStatsCard(UserStats? stats) {
    if (stats == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlack, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowDark,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Overview',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.textWhite,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Rides',
                stats.totalRides.toString(),
                Icons.directions_car_outlined,
              ),
              _buildStatDivider(),
              _buildStatItem(
                'Services',
                stats.totalServices.toString(),
                Icons.build_outlined,
              ),
              _buildStatDivider(),
              _buildStatItem(
                'Rating',
                stats.getOverallRating() ?? 'N/A',
                Icons.star_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryGold.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryGold,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 60,
      color: AppColors.borderLight.withOpacity(0.2),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DRIVER CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDriverCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: AppColors.info,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Driver Information',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildModernMenuItem(
            icon: Icons.directions_car_outlined,
            title: 'Vehicle Information',
            subtitle: 'Manage your vehicle details',
            onTap: () => _navigateTo('/profile/vehicle'),
          ),
          _buildModernMenuItem(
            icon: Icons.description_outlined,
            title: 'Driver Documents',
            subtitle: 'License, CNI, Insurance',
            onTap: () => _navigateTo('/profile/documents'),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // MENU SECTIONS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          ...items,
        ],
      ),
    );
  }

  List<Widget> _buildAccountItems() {
    return [
      _buildModernMenuItem(
        icon: Icons.person_outline,
        title: 'Edit Profile',
        subtitle: 'Update your personal information',
        onTap: () => _navigateTo('/profile/edit'),
      ),
      _buildModernMenuItem(
        icon: Icons.lock_outline,
        title: 'Change Password',
        subtitle: 'Update your password',
        onTap: () => _navigateTo('/profile/change-password'),
        showDivider: false,
      ),
    ];
  }

  List<Widget> _buildSettingsItems() {
    return [
      _buildModernMenuItem(
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        subtitle: 'Manage notification preferences',
        onTap: () => _navigateTo('/profile/notifications'),
      ),
      _buildModernMenuItem(
        icon: Icons.privacy_tip_outlined,
        title: 'Privacy & Security',
        subtitle: 'Control your privacy settings',
        onTap: () => _navigateTo('/profile/privacy'),
      ),
      _buildModernMenuItem(
        icon: Icons.language_outlined,
        title: tr('profile.language'),
        subtitle: AppSettings.instance.isFr ? 'Français 🇫🇷' : 'English 🇬🇧',
        onTap: _showLanguagePicker,
      ),
      _buildModernMenuItem(
        icon: AppSettings.instance.isDark
            ? Icons.dark_mode_outlined
            : Icons.light_mode_outlined,
        title: tr('profile.darkMode'),
        subtitle: tr('profile.darkMode.subtitle'),
        trailing: Switch(
          value: AppSettings.instance.isDark,
          activeColor: AppColors.primaryGold,
          onChanged: (v) => _applyThemeChange(v),
        ),
        onTap: () => _applyThemeChange(!AppSettings.instance.isDark),
        showDivider: false,
      ),
    ];
  }

  // ── Language & theme handling ───────────────────────────────────────────────

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text(tr('profile.language'),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            _langTile(ctx, 'fr', 'Français', '🇫🇷'),
            _langTile(ctx, 'en', 'English', '🇬🇧'),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _langTile(BuildContext ctx, String code, String label, String flag) {
    final selected = AppSettings.instance.lang == code;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 22)),
      title: Text(label,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.primaryGold)
          : null,
      onTap: () async {
        Navigator.pop(ctx);
        if (AppSettings.instance.lang == code) return;
        await AppSettings.instance.setLang(code);
        if (!mounted) return;
        RestartWidget.restartApp(context); // repaint the whole app in the new language
      },
    );
  }

  Future<void> _applyThemeChange(bool dark) async {
    await AppSettings.instance.setDark(dark);
    if (!mounted) return;
    RestartWidget.restartApp(context); // repaint every screen with the new palette
  }

  List<Widget> _buildSupportItems() {
    return [
      _buildModernMenuItem(
        icon: Icons.help_outline,
        title: 'Help & FAQ',
        subtitle: 'Get answers to common questions',
        onTap: () => _navigateTo('/profile/help'),
      ),
      _buildModernMenuItem(
        icon: Icons.support_agent_outlined,
        title: 'Contact Support',
        subtitle: 'Get help from our team',
        onTap: () => _navigateTo('/profile/support'),
      ),
      _buildModernMenuItem(
        icon: Icons.bug_report_outlined,
        title: 'Report a Problem',
        subtitle: 'Let us know about issues',
        onTap: () => _navigateTo('/profile/report-problem'),
        showDivider: false,
      ),
    ];
  }

  Widget _buildModernMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
    Widget? trailing,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.primaryBlack,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.textLight,
                        size: 24,
                      ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 72),
            child: Divider(height: 1),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DANGER ZONE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDangerZone() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.error.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: AppColors.error,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Danger Zone',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildDangerMenuItem(
            icon: Icons.power_settings_new,
            title: 'Deactivate Account',
            subtitle: 'Temporarily disable your account',
            onTap: _showDeactivateDialog,
            color: AppColors.warning,
          ),
          _buildDangerMenuItem(
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            subtitle: 'Permanently remove your account',
            onTap: _showDeleteDialog,
            color: AppColors.error,
          ),
          _buildDangerMenuItem(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            onTap: _showLogoutDialog,
            color: AppColors.textSecondary,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.titleMedium.copyWith(
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: color,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 72),
            child: Divider(height: 1),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ERROR STATE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load profile',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.primaryBlack,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/login',
                            (route) => false,
                      );
                    }
                  },
                  child: Text(
                    'Back to Login',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.logout,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlack,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showDeactivateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.power_settings_new,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Deactivate Account'),
          ],
        ),
        content: const Text(
          'Your account will be temporarily disabled. You can reactivate it anytime by logging in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<ProfileProvider>();
              final success = await provider.deactivateAccount();

              if (success && mounted) {
                _handleLogout();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_forever,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Account'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. All your data will be permanently deleted.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<ProfileProvider>();
              final success = await provider.requestAccountDeletion(
                reasonController.text.isEmpty
                    ? 'No reason provided'
                    : reasonController.text,
              );

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Account deletion request submitted'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _handleLogout();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  void _navigateTo(String route) async {
    switch (route) {
      case '/profile/edit':
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
        );
        // Reload profile if changes were made
        if (result == true && mounted) {
          _loadData();
        }
        break;

      case '/profile/change-password':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
        );
        break;

      case '/profile/avatar':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Avatar upload screen coming soon'),
            backgroundColor: AppColors.primaryGold,
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Navigate to: $route (Coming Soon)'),
            backgroundColor: AppColors.primaryGold,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _handleLogout() async {
    // ═══════════════════════════════════════════════════════════════
    // STEP 1: Disconnect socket FIRST (before clearing tokens)
    // ═══════════════════════════════════════════════════════════════
    try {
      SocketHelper.disconnect();
      debugPrint('✅ [LOGOUT] Socket disconnected');
    } catch (e) {
      debugPrint('⚠️  [LOGOUT] Socket disconnect error (non-fatal): $e');
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 2: Deactivate FCM token on backend
    // Must happen BEFORE clearing SharedPrefs — token still available
    // ═══════════════════════════════════════════════════════════════
    try {
      await NotificationService.instance.deactivateTokenOnLogout();
      debugPrint('✅ [LOGOUT] FCM token deactivated');
    } catch (e) {
      debugPrint('⚠️  [LOGOUT] FCM token deactivation error (non-fatal): $e');
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Clear ALL SharedPreferences
    // ═══════════════════════════════════════════════════════════════
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('✅ [LOGOUT] SharedPreferences cleared');
    } catch (e) {
      debugPrint('❌ [LOGOUT] Failed to clear prefs: $e');
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 4: Reset all providers
    // ═══════════════════════════════════════════════════════════════
    if (!mounted) return;
    try {
      context.read<ProfileProvider>().reset();
      context.read<TripProvider>().reset();
      context.read<ServicesProvider>().reset();
      debugPrint('✅ [LOGOUT] All providers reset');
    } catch (e) {
      debugPrint('⚠️  [LOGOUT] Provider reset error (non-fatal): $e');
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 5: Navigate to login, wipe entire stack
    // ═══════════════════════════════════════════════════════════════
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
          (route) => false,
    );

    // ═══════════════════════════════════════════════════════════════
    // STEP 6: Show confirmation snackbar
    // ═══════════════════════════════════════════════════════════════
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Logged out successfully',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );

    debugPrint('✅ [LOGOUT] Complete — navigated to /login');
  }
}
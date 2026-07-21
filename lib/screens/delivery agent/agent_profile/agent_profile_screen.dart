// lib/presentation/screens/delivery_agent/agent_profile_screen.dart
//
// Delivery Agent / Driver — Profile Screen
// API: GET/PUT /api/deliveries/agent/profile

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';

// ── Model ──────────────────────────────────────────────────────────────────────

class _Profile {
  final String  uuid;
  final String  userType;
  final String  firstName;
  final String  lastName;
  final String  fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final bool    phoneVerified;
  final bool    emailVerified;
  final String  accountStatus;
  final String  driverStatus;
  final String  currentMode;
  final double  driverRating;
  final bool    canSwitchMode;
  final String? vehicleMakeModel;
  final String? vehicleColor;
  final int?    vehicleYear;
  final String? vehiclePlate;
  final String? vehicleType;
  final String? vehiclePhotoUrl;
  final String? verificationState;
  final String? licenseNumber;
  final String? licenseExpiry;
  final String? insuranceNumber;
  final String? insuranceExpiry;
  final double  ratingAverage;
  final int     ratingCount;
  final int     totalDeliveries;
  final int     completedDeliveries;
  final int     cancelledDeliveries;

  const _Profile({
    required this.uuid, required this.userType,
    required this.firstName, required this.lastName, required this.fullName,
    required this.phoneVerified, required this.emailVerified,
    required this.accountStatus, required this.driverStatus,
    required this.currentMode, required this.driverRating,
    required this.canSwitchMode, required this.ratingAverage,
    required this.ratingCount, required this.totalDeliveries,
    required this.completedDeliveries, required this.cancelledDeliveries,
    this.email, this.phone, this.avatarUrl,
    this.vehicleMakeModel, this.vehicleColor, this.vehicleYear,
    this.vehiclePlate, this.vehicleType, this.vehiclePhotoUrl,
    this.verificationState, this.licenseNumber, this.licenseExpiry,
    this.insuranceNumber, this.insuranceExpiry,
  });

  factory _Profile.fromJson(Map<String, dynamic> j) {
    final v  = (j['vehicle']      as Map<String, dynamic>?) ?? {};
    final vf = j['verification']  as Map<String, dynamic>?;
    final r  = (j['rating']       as Map<String, dynamic>?) ?? {};
    final s  = (j['stats']        as Map<String, dynamic>?) ?? {};
    return _Profile(
      uuid:                j['uuid']          as String?  ?? '',
      userType:            j['userType']       as String?  ?? '',
      firstName:           j['firstName']      as String?  ?? '',
      lastName:            j['lastName']       as String?  ?? '',
      fullName:            j['fullName']       as String?  ?? '',
      email:               j['email']          as String?,
      phone:               j['phone']          as String?,
      avatarUrl:           j['avatarUrl']      as String?,
      phoneVerified:       j['phoneVerified']  as bool?    ?? false,
      emailVerified:       j['emailVerified']  as bool?    ?? false,
      accountStatus:       j['accountStatus']  as String?  ?? '',
      driverStatus:        j['driverStatus']   as String?  ?? 'offline',
      currentMode:         j['currentMode']    as String?  ?? 'delivery',
      driverRating:        (j['driverRating']  as num?     ?? 5.0).toDouble(),
      canSwitchMode:       j['canSwitchMode']  as bool?    ?? false,
      vehicleMakeModel:    v['makeModel']      as String?,
      vehicleColor:        v['color']          as String?,
      vehicleYear:         v['year']           as int?,
      vehiclePlate:        v['plate']          as String?,
      vehicleType:         v['type']           as String?,
      vehiclePhotoUrl:     v['photoUrl']       as String?,
      verificationState:   vf?['state']        as String?,
      licenseNumber:       vf?['licenseNumber']    as String?,
      licenseExpiry:       vf?['licenseExpiry']    as String?,
      insuranceNumber:     vf?['insuranceNumber']  as String?,
      insuranceExpiry:     vf?['insuranceExpiry']  as String?,
      ratingAverage:       (r['average']       as num?     ?? 5.0).toDouble(),
      ratingCount:         (r['count']         as num?     ?? 0).toInt(),
      totalDeliveries:     (s['totalDeliveries']     as num? ?? 0).toInt(),
      completedDeliveries: (s['completedDeliveries'] as num? ?? 0).toInt(),
      cancelledDeliveries: (s['cancelledDeliveries'] as num? ?? 0).toInt(),
    );
  }

  bool get isOnline => driverStatus == 'online' || driverStatus == 'busy';
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class AgentProfileScreen extends StatefulWidget {
  const AgentProfileScreen({super.key});

  @override
  State<AgentProfileScreen> createState() => _State();
}

class _State extends State<AgentProfileScreen> {
  String    _token   = '';
  _Profile? _profile;
  bool      _loading = true;
  bool      _saving  = false;
  String?   _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _token = prefs.getString('access_token') ?? '');
    await _load();
  }

  Map<String, String> get _h =>
      {'Authorization': 'Bearer $_token', 'Content-Type': 'application/json'};

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/deliveries/agent/profile'), headers: _h)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _profile = _Profile.fromJson(body['profile'] as Map<String, dynamic>));
      } else {
        setState(() => _error = 'Failed to load profile (${res.statusCode})');
      }
    } catch (_) {
      setState(() => _error = 'Network error. Check your connection.');
    }
    setState(() => _loading = false);
  }

  Future<bool> _save(Map<String, dynamic> updates) async {
    setState(() => _saving = true);
    try {
      final res = await http
          .put(Uri.parse('${AppConfig.apiBaseUrl}/deliveries/agent/profile'),
          headers: _h, body: jsonEncode(updates))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _profile = _Profile.fromJson(body['profile'] as Map<String, dynamic>));
        setState(() => _saving = false);
        return true;
      }
      final err = jsonDecode(res.body) as Map<String, dynamic>;
      _snack(err['message'] as String? ?? 'Update failed', isError: true);
    } catch (_) {
      _snack('Network error. Try again.', isError: true);
    }
    setState(() => _saving = false);
    return false;
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView()
          : CustomScrollView(slivers: [
        _appBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _heroCard(),
              const SizedBox(height: 16),
              _statsRow(),
              const SizedBox(height: 16),
              _section('Contact',   _contactContent()),
              const SizedBox(height: 12),
              _section('Vehicle',   _vehicleContent()),
              if (_profile!.verificationState != null) ...[
                const SizedBox(height: 12),
                _section('Verification', _verificationContent()),
              ],
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }

  SliverAppBar _appBar() => SliverAppBar(
    pinned: true,
    backgroundColor: AppColors.backgroundWhite,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      color: AppColors.primaryDark,
      onPressed: () => Navigator.pop(context),
    ),
    title: Text(tr('agent.myProfile'),
        style: AppTypography.titleLarge.copyWith(color: AppColors.primaryDark)),
    actions: [
      if (_saving)
        Padding(padding: EdgeInsets.all(16),
            child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)))
      else
        IconButton(
          icon: const Icon(Icons.edit_rounded),
          color: AppColors.primaryGold,
          onPressed: _editSheet,
        ),
      const SizedBox(width: 4),
    ],
  );

  // ── Hero card ────────────────────────────────────────────────────────────────

  Widget _heroCard() {
    final p = _profile!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Avatar
        Stack(alignment: Alignment.bottomRight, children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primaryGold.withOpacity(0.15),
            backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
            child: p.avatarUrl == null
                ? Text(
                p.firstName.isNotEmpty ? p.firstName[0].toUpperCase() : '?',
                style: AppTypography.displaySmall.copyWith(
                    color: AppColors.primaryGold, fontWeight: FontWeight.w800))
                : null,
          ),
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: p.isOnline ? AppColors.success : AppColors.secondaryGrey,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.backgroundWhite, width: 2),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // Name
        Text(p.fullName.isNotEmpty ? p.fullName : tr('agent.noNameSet'),
            style: AppTypography.headlineSmall.copyWith(
                color: AppColors.primaryDark, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),

        // Role badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: p.userType == 'DRIVER'
                ? AppColors.info.withOpacity(0.12)
                : AppColors.primaryGold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            p.userType == 'DRIVER' ? '🚗 Driver · Ride & Delivery' : '🛵 Delivery Agent',
            style: AppTypography.labelSmall.copyWith(
              color: p.userType == 'DRIVER' ? AppColors.info : AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Stars
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ...List.generate(5, (i) => Icon(
            i < p.ratingAverage.floor() ? Icons.star_rounded
                : i < p.ratingAverage ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            color: AppColors.primaryGold, size: 20,
          )),
          const SizedBox(width: 6),
          Text('${p.ratingAverage.toStringAsFixed(1)} (${p.ratingCount})',
              style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
        ]),

        // Mode chip — only for drivers who can switch
        if (p.canSwitchMode) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: p.currentMode == 'delivery'
                  ? AppColors.primaryGold.withOpacity(0.12)
                  : AppColors.info.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              p.currentMode == 'delivery'
                  ? '📦 Currently in Delivery mode'
                  : '🚗 Currently in Ride mode',
              style: AppTypography.labelSmall.copyWith(
                color: p.currentMode == 'delivery'
                    ? AppColors.primaryDark : AppColors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────────

  Widget _statsRow() {
    final p = _profile!;
    return Row(children: [
      _statCard('Total',     '${p.totalDeliveries}',     Icons.local_shipping_rounded, AppColors.info),
      const SizedBox(width: 10),
      _statCard('Delivered', '${p.completedDeliveries}', Icons.check_circle_rounded,   AppColors.success),
      const SizedBox(width: 10),
      _statCard('Cancelled', '${p.cancelledDeliveries}', Icons.cancel_rounded,         AppColors.error),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: AppTypography.titleLarge.copyWith(
                    color: AppColors.primaryDark, fontWeight: FontWeight.w800)),
            Text(label,
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.secondaryGrey, fontSize: 10)),
          ]),
        ),
      );

  // ── Section ───────────────────────────────────────────────────────────────────

  Widget _section(String title, Widget content) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.backgroundWhite,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: AppTypography.titleSmall.copyWith(
              color: AppColors.secondaryGrey,
              fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      const SizedBox(height: 12),
      content,
    ]),
  );

  // ── Contact content ───────────────────────────────────────────────────────────

  Widget _contactContent() {
    final p = _profile!;
    return Column(children: [
      _infoRow(Icons.phone_rounded,  'Phone', p.phone ?? 'Not set', verified: p.phoneVerified),
      const SizedBox(height: 10),
      _infoRow(Icons.email_rounded,  'Email', p.email ?? 'Not set', verified: p.emailVerified),
    ]);
  }

  // ── Vehicle content ───────────────────────────────────────────────────────────

  Widget _vehicleContent() {
    final p = _profile!;
    final hasVehicle = p.vehicleMakeModel != null || p.vehiclePlate != null;
    if (!hasVehicle) {
      return Row(children: [
        Icon(Icons.directions_bike_rounded, color: AppColors.secondaryLightGrey, size: 18),
        const SizedBox(width: 8),
        Text(tr('agent.noVehicleInfo'),
            style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryGrey)),
      ]);
    }
    return Column(children: [
      if (p.vehicleMakeModel != null)
        _infoRow(Icons.directions_car_rounded, 'Make / Model', p.vehicleMakeModel!),
      if (p.vehiclePlate != null) ...[
        const SizedBox(height: 10),
        _infoRow(Icons.pin_rounded, 'Plate', p.vehiclePlate!),
      ],
      if (p.vehicleColor != null) ...[
        const SizedBox(height: 10),
        _infoRow(Icons.palette_rounded, 'Color', p.vehicleColor!),
      ],
      if (p.vehicleYear != null) ...[
        const SizedBox(height: 10),
        _infoRow(Icons.calendar_today_rounded, 'Year', '${p.vehicleYear}'),
      ],
    ]);
  }

  // ── Verification content ──────────────────────────────────────────────────────

  Widget _verificationContent() {
    final p     = _profile!;
    final state = p.verificationState ?? 'PENDING';
    final color = switch (state) {
      'VERIFIED'  => AppColors.success,
      'REJECTED'  => AppColors.error,
      'PENDING'   => AppColors.warning,
      _           => AppColors.secondaryGrey,
    };
    final icon = switch (state) {
      'VERIFIED'  => Icons.verified_rounded,
      'REJECTED'  => Icons.cancel_rounded,
      'PENDING'   => Icons.hourglass_empty_rounded,
      _           => Icons.help_outline_rounded,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(state,
              style: AppTypography.labelSmall
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
      if (p.licenseNumber != null) ...[
        const SizedBox(height: 12),
        _infoRow(Icons.badge_rounded, 'License No.', p.licenseNumber!,
            sub: p.licenseExpiry != null ? 'Expires ${p.licenseExpiry}' : null),
      ],
      if (p.insuranceNumber != null) ...[
        const SizedBox(height: 10),
        _infoRow(Icons.health_and_safety_rounded, 'Insurance No.',
            p.insuranceNumber!,
            sub: p.insuranceExpiry != null ? 'Expires ${p.insuranceExpiry}' : null),
      ],
    ]);
  }

  // ── Info row ──────────────────────────────────────────────────────────────────

  Widget _infoRow(IconData icon, String label, String value,
      {bool? verified, String? sub}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.secondaryGrey, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.secondaryGrey, fontSize: 10)),
          Row(children: [
            Expanded(
              child: Text(value,
                  style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primaryDark, fontWeight: FontWeight.w500)),
            ),
            if (verified == true)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 14),
            if (verified == false)
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.warning, size: 14),
          ]),
          if (sub != null)
            Text(sub,
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.secondaryGrey, fontSize: 10)),
        ]),
      ),
    ]);
  }

  // ── Error ──────────────────────────────────────────────────────────────────────

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off_rounded,
            size: 56, color: AppColors.secondaryLightGrey),
        const SizedBox(height: 16),
        Text(_error ?? 'Something went wrong',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.secondaryGrey),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGold, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(tr('common.retry'),
              style: AppTypography.labelMedium.copyWith(
                  color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
        ),
      ]),
    ),
  );

  // ── Edit sheet ────────────────────────────────────────────────────────────────

  void _editSheet() {
    final p = _profile!;
    final firstCtrl = TextEditingController(text: p.firstName);
    final lastCtrl  = TextEditingController(text: p.lastName);
    final emailCtrl = TextEditingController(text: p.email ?? '');
    final phoneCtrl = TextEditingController(text: p.phone ?? '');
    final makeCtrl  = TextEditingController(text: p.vehicleMakeModel ?? '');
    final colorCtrl = TextEditingController(text: p.vehicleColor ?? '');
    final plateCtrl = TextEditingController(text: p.vehiclePlate ?? '');
    final yearCtrl  = TextEditingController(
        text: p.vehicleYear != null ? '${p.vehicleYear}' : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(tr('agent.editProfile'),
                    style: AppTypography.titleLarge.copyWith(color: AppColors.primaryDark)),
                const SizedBox(height: 20),

                _label('Personal Info'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _field('First name', firstCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Last name', lastCtrl)),
                ]),
                const SizedBox(height: 10),
                _field('Email', emailCtrl, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _field('Phone', phoneCtrl, keyboardType: TextInputType.phone),
                const SizedBox(height: 20),

                _label('Vehicle Info'),
                const SizedBox(height: 8),
                _field('Make / Model (e.g. Toyota Hilux)', makeCtrl),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _field('Color', colorCtrl)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Year', yearCtrl,
                      keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                _field('Plate number', plateCtrl, hint: 'e.g. LT-1234-A'),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final updates = <String, dynamic>{};
                      if (firstCtrl.text.trim() != p.firstName)
                        updates['first_name'] = firstCtrl.text.trim();
                      if (lastCtrl.text.trim() != p.lastName)
                        updates['last_name']  = lastCtrl.text.trim();
                      final em = emailCtrl.text.trim();
                      if (em.isNotEmpty && em != (p.email ?? ''))
                        updates['email'] = em;
                      final ph = phoneCtrl.text.trim();
                      if (ph.isNotEmpty && ph != (p.phone ?? ''))
                        updates['phone'] = ph;
                      final mk = makeCtrl.text.trim();
                      if (mk.isNotEmpty && mk != (p.vehicleMakeModel ?? ''))
                        updates['vehicle_make_model'] = mk;
                      final cl = colorCtrl.text.trim();
                      if (cl.isNotEmpty && cl != (p.vehicleColor ?? ''))
                        updates['vehicle_color'] = cl;
                      final pl = plateCtrl.text.trim();
                      if (pl.isNotEmpty && pl != (p.vehiclePlate ?? ''))
                        updates['vehicle_plate'] = pl;
                      final yr = int.tryParse(yearCtrl.text.trim());
                      if (yr != null && yr != p.vehicleYear)
                        updates['vehicle_year'] = yr;

                      if (updates.isEmpty) { Navigator.pop(context); return; }
                      final ok = await _save(updates);
                      if (ok && mounted) {
                        Navigator.pop(context);
                        _snack('Profile updated ✓');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold, elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(tr('agent.saveChanges'),
                        style: AppTypography.labelLarge.copyWith(
                            color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: AppTypography.labelMedium.copyWith(
          color: AppColors.secondaryGrey, fontWeight: FontWeight.w700));

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType, String? hint}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.primaryDark),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          labelStyle: AppTypography.labelSmall.copyWith(color: AppColors.secondaryGrey),
          hintStyle:  AppTypography.bodySmall.copyWith(color: AppColors.secondaryLightGrey),
          filled: true, fillColor: AppColors.backgroundLight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.borderLight)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.borderLight)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5)),
        ),
      );
}
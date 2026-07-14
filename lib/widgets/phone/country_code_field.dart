// lib/widgets/phone/country_code_field.dart
//
// A phone-number input with a country-dial-code selector in front of it.
//
// WHY THIS EXISTS:
// SMS (delivery PIN / OTP) is sent through Techsoft, which needs the recipient
// in full international format (e.g. 237690000000). If a user types only the
// local part (690000000), the provider reports "sent" but the message never
// arrives. This widget forces a country code, so the number handed to the
// backend is always international.
//
// SCOPE: for now the list is limited to francophone African countries, with
// Cameroon (+237) as the default — WEGO's primary market.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

/// A single dialing country (flag + international dial code, no '+').
class DialingCountry {
  final String name;
  final String flag;
  final String dialCode; // digits only, e.g. '237'
  final String iso;      // ISO-3166 alpha-2, e.g. 'CM'

  const DialingCountry({
    required this.name,
    required this.flag,
    required this.dialCode,
    required this.iso,
  });
}

/// Francophone African countries. Cameroon is first so it is the default.
const List<DialingCountry> kFrancophoneAfricaCountries = [
  DialingCountry(name: 'Cameroun',                  flag: '🇨🇲', dialCode: '237', iso: 'CM'),
  DialingCountry(name: 'Sénégal',                   flag: '🇸🇳', dialCode: '221', iso: 'SN'),
  DialingCountry(name: "Côte d'Ivoire",             flag: '🇨🇮', dialCode: '225', iso: 'CI'),
  DialingCountry(name: 'Mali',                      flag: '🇲🇱', dialCode: '223', iso: 'ML'),
  DialingCountry(name: 'Burkina Faso',              flag: '🇧🇫', dialCode: '226', iso: 'BF'),
  DialingCountry(name: 'Niger',                     flag: '🇳🇪', dialCode: '227', iso: 'NE'),
  DialingCountry(name: 'Guinée',                    flag: '🇬🇳', dialCode: '224', iso: 'GN'),
  DialingCountry(name: 'Bénin',                     flag: '🇧🇯', dialCode: '229', iso: 'BJ'),
  DialingCountry(name: 'Togo',                      flag: '🇹🇬', dialCode: '228', iso: 'TG'),
  DialingCountry(name: 'Gabon',                     flag: '🇬🇦', dialCode: '241', iso: 'GA'),
  DialingCountry(name: 'Congo',                     flag: '🇨🇬', dialCode: '242', iso: 'CG'),
  DialingCountry(name: 'RD Congo',                  flag: '🇨🇩', dialCode: '243', iso: 'CD'),
  DialingCountry(name: 'Tchad',                     flag: '🇹🇩', dialCode: '235', iso: 'TD'),
  DialingCountry(name: 'Centrafrique',              flag: '🇨🇫', dialCode: '236', iso: 'CF'),
  DialingCountry(name: 'Guinée équatoriale',        flag: '🇬🇶', dialCode: '240', iso: 'GQ'),
  DialingCountry(name: 'Mauritanie',                flag: '🇲🇷', dialCode: '222', iso: 'MR'),
  DialingCountry(name: 'Djibouti',                  flag: '🇩🇯', dialCode: '253', iso: 'DJ'),
  DialingCountry(name: 'Madagascar',                flag: '🇲🇬', dialCode: '261', iso: 'MG'),
  DialingCountry(name: 'Rwanda',                    flag: '🇷🇼', dialCode: '250', iso: 'RW'),
  DialingCountry(name: 'Burundi',                   flag: '🇧🇮', dialCode: '257', iso: 'BI'),
  DialingCountry(name: 'Comores',                   flag: '🇰🇲', dialCode: '269', iso: 'KM'),
];

/// Build the full international number (digits only, no '+') from a selected
/// country and a locally-typed number. Safe to call anywhere.
///
/// Rules:
///  • strips everything that is not a digit from the local part
///  • if the user already typed the dial code (or a leading '+dial'), it is
///    not duplicated
///  • otherwise the country dial code is prepended
String buildInternationalNumber(DialingCountry country, String localInput) {
  final digits = localInput.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith(country.dialCode)) return digits;
  return '${country.dialCode}$digits';
}

/// A labelled row: [ 🇨🇲 +237 ▾ ] [ phone number ............ ]
///
/// Tapping the country chip opens a searchable bottom sheet. The parent owns
/// the local-number [controller] and the selected [country]; call
/// [buildInternationalNumber] at submit time to get the value to send.
class CountryCodePhoneField extends StatelessWidget {
  final TextEditingController controller;
  final DialingCountry country;
  final ValueChanged<DialingCountry> onCountryChanged;
  final VoidCallback? onChanged;
  final String hint;

  const CountryCodePhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.onChanged,
    this.hint = 'Phone number *',
  });

  Future<void> _pickCountry(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<DialingCountry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(selected: country),
    );
    if (selected != null) onCountryChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          // ── Country chip ──────────────────────────────────────────────
          InkWell(
            onTap: () => _pickCountry(context),
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(country.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text('+${country.dialCode}',
                      style: TextStyle(
                        fontFamily: AppTypography.primaryFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  Icon(Icons.arrow_drop_down_rounded,
                      size: 20, color: AppColors.textLight),
                ],
              ),
            ),
          ),
          // ── Divider ───────────────────────────────────────────────────
          Container(width: 1, height: 26, color: AppColors.borderLight),
          // ── Local number ──────────────────────────────────────────────
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                LengthLimitingTextInputFormatter(15),
              ],
              onChanged: (_) => onChanged?.call(),
              style: AppTypography.inputText.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTypography.inputHint.copyWith(fontSize: 13),
                prefixIcon: Icon(Icons.phone_outlined,
                    size: 18, color: AppColors.textLight),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom-sheet country picker (searchable)
// ═══════════════════════════════════════════════════════════════════════════

class _CountryPickerSheet extends StatefulWidget {
  final DialingCountry selected;
  const _CountryPickerSheet({required this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DialingCountry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return kFrancophoneAfricaCountries;
    return kFrancophoneAfricaCountries.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.dialCode.contains(q) ||
          c.iso.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42, height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Choisir le pays',
                style: TextStyle(
                  fontFamily: AppTypography.primaryFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
          ),
          const SizedBox(height: 12),
          // ── Search ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: AppTypography.inputText.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Rechercher un pays ou un indicatif',
                  hintStyle: AppTypography.inputHint.copyWith(fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textLight),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ── List ────────────────────────────────────────────────────
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.borderLight),
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final isSel = c.iso == widget.selected.iso;
                return ListTile(
                  onTap: () => Navigator.pop(context, c),
                  leading:
                      Text(c.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(c.name,
                      style: TextStyle(
                        fontFamily: AppTypography.primaryFont,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('+${c.dialCode}',
                          style: TextStyle(
                            fontFamily: AppTypography.primaryFont,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          )),
                      if (isSel) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle_rounded,
                            size: 20, color: AppColors.primaryGold),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

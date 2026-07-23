// lib/screens/services/edit_listing_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Edit Listing Screen  (Provider — update an existing listing)
// Overflow-fixed + aligned to AppColors / AppTypography
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

import '../../models/services/service_listing_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

// ─── Local design tokens ──────────────────────────────────────────────────────
const _kPrimary      = AppColors.primaryGold;
const _kPrimaryDark  = AppColors.primaryGoldDark;
const _kPrimaryLight = Color(0xFFFFFDE7);
const _kPrimaryMid   = Color(0xFFFFECB3);
Color get _kSurface => AppColors.backgroundWhite;
Color get _kPageBg => AppColors.backgroundLight;
Color get _kInputBg => AppColors.inputBackground;
Color get _kBorder => AppColors.borderLight;
Color get _kTextPrimary => AppColors.textPrimary;
Color get _kTextSecond => AppColors.textSecondary;
Color get _kTextLight => AppColors.textLight;
const _kError        = AppColors.error;
Color get _kErrorLight => AppColors.errorLight;
const _kSuccess      = AppColors.success;
Color get _kSuccessLight => AppColors.successLight;
const _kWarning      = AppColors.warning;
Color get _kWarningLight => AppColors.warningLight;

const double _rSm   = 4.0;
const double _rMd   = 12.0;
const double _rLg   = 16.0;
const double _rXl   = 24.0;
const double _rPill = 999.0;

const List<BoxShadow> _kBottomShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -3)),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class EditListingScreen extends StatefulWidget {
  final ServiceListing listing;
  const EditListingScreen({Key? key, required this.listing}) : super(key: key);

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker  = ImagePicker();
  bool _isSubmitting = false;

  // ── Controllers ───────────────────────────────────────────────────────────
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _minChargeCtrl;
  late TextEditingController _hoursCtrl;
  late TextEditingController _experienceCtrl;
  late TextEditingController _certsCtrl;

  // ── State ─────────────────────────────────────────────────────────────────
  late String       _pricingType;
  late String       _selectedCity;
  late bool         _emergency;
  late List<String> _selectedDays;
  late List<String> _selectedNeighborhoods;

  late List<String> _existingPhotos;
  final List<File>  _newPhotos = [];

  String?                _existingVideoUrl;
  File?                  _newVideo;
  VideoPlayerController? _videoController;

  static const _cities = [
    'Douala', 'Yaoundé', 'Bafoussam', 'Bamenda',
    'Garoua', 'Maroua', 'Ngaoundéré', 'Kribi', 'Limbé',
  ];

  static const _neighborhoods = {
    'Douala':    ['Akwa', 'Bonanjo', 'Bassa', 'Bonabéri', 'Deido', 'Makepe', 'PK8', 'Logbaba'],
    'Yaoundé':   ['Centre-Ville', 'Bastos', 'Mimboman', 'Nsam', 'Emana', 'Essos', 'Nlongkak'],
    'Bafoussam': ['Centre', 'Famla', 'Tamdja', 'Tougang'],
    'Bamenda':   ['Commercial Avenue', 'Mile 3', 'Nkwen', 'Up Station'],
    'Garoua':    ['Centre', 'Doualaré', 'Roumde Adjia'],
  };

  static const _days = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
    'Vendredi', 'Samedi', 'Dimanche',
  ];

  @override
  void initState() {
    super.initState();
    _initFromListing();
  }

  void _initFromListing() {
    final l = widget.listing;

    _titleCtrl      = TextEditingController(text: l.title);
    _descCtrl       = TextEditingController(text: l.description);
    _hoursCtrl      = TextEditingController(text: l.availableHours ?? '');
    _experienceCtrl = TextEditingController(
        text: l.yearsExperience?.toString() ?? '');
    _certsCtrl      = TextEditingController(text: l.certifications ?? '');

    _pricingType  = _pricingTypeString(l.pricingType);
    _selectedCity = _cities.contains(l.city) ? l.city : 'Douala';
    _emergency    = l.emergencyService;

    switch (l.pricingType) {
      case PricingType.hourly:
        _priceCtrl     = TextEditingController(
            text: l.hourlyRate?.toStringAsFixed(0) ?? '');
        _minChargeCtrl = TextEditingController(
            text: l.minimumCharge?.toStringAsFixed(0) ?? '');
        break;
      case PricingType.fixed:
        _priceCtrl     = TextEditingController(
            text: l.fixedPrice?.toStringAsFixed(0) ?? '');
        _minChargeCtrl = TextEditingController();
        break;
      default:
        _priceCtrl     = TextEditingController();
        _minChargeCtrl = TextEditingController();
    }

    _selectedDays          = _parseDays(l.availableDays);
    _selectedNeighborhoods = List<String>.from(l.neighborhoods);
    _existingPhotos        = List<String>.from(l.photos);

    _existingVideoUrl = _extractVideoUrl(_existingPhotos);
    if (_existingVideoUrl != null) {
      _existingPhotos.remove(_existingVideoUrl);
    }
  }

  String _pricingTypeString(PricingType t) {
    switch (t) {
      case PricingType.hourly:     return 'hourly';
      case PricingType.fixed:      return 'fixed';
      case PricingType.negotiable: return 'negotiable';
    }
  }

  List<String> _parseDays(String? value) {
    if (value == null || value.isEmpty) return [];
    if (value.startsWith('[')) {
      return value
          .replaceAll(RegExp(r'[\[\]"]'), '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value.contains(',')) {
      return value.split(',').map((e) => e.trim()).toList();
    }
    return [value.trim()];
  }

  String? _extractVideoUrl(List<String> urls) {
    final ext = RegExp(r'\.(mp4|mov|avi|mkv|webm)$',
        caseSensitive: false);
    for (final url in urls) {
      if (ext.hasMatch(url)) return url;
    }
    return null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _minChargeCtrl.dispose();
    _hoursCtrl.dispose();
    _experienceCtrl.dispose();
    _certsCtrl.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ── Media helpers ─────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final total = _existingPhotos.length + _newPhotos.length;
    if (total >= 5) {
      _snack('Maximum 5 photos autorisées', isError: true);
      return;
    }
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (img != null && mounted) {
      setState(() => _newPhotos.add(File(img.path)));
    }
  }

  Future<void> _pickVideo() async {
    if (_existingVideoUrl != null || _newVideo != null) {
      _snack('Supprimez la vidéo actuelle d\'abord', isError: true);
      return;
    }
    final vid = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (vid != null && mounted) {
      final file  = File(vid.path);
      final bytes = await file.length();
      if (bytes > 100 * 1024 * 1024) {
        _snack('La vidéo doit faire moins de 100 Mo', isError: true);
        return;
      }
      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      setState(() {
        _newVideo = file;
        _videoController?.dispose();
        _videoController = ctrl;
      });
    }
  }

  void _removeExistingPhoto(int i) =>
      setState(() => _existingPhotos.removeAt(i));
  void _removeNewPhoto(int i) =>
      setState(() => _newPhotos.removeAt(i));
  void _removeExistingVideo() =>
      setState(() => _existingVideoUrl = null);
  void _removeNewVideo() {
    _videoController?.dispose();
    setState(() { _newVideo = null; _videoController = null; });
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pricingType != 'negotiable' && _priceCtrl.text.trim().isEmpty) {
      _snack('Veuillez saisir un prix', isError: true);
      return;
    }
    if (_selectedNeighborhoods.isEmpty) {
      _snack('Veuillez sélectionner au moins une zone', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final provider = context.read<ServicesProvider>();
      final ok = await provider.updateListing(
        id: widget.listing.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        pricingType: _pricingType,
        price: _pricingType != 'negotiable'
            ? int.tryParse(_priceCtrl.text.trim())
            : null,
        minCharge: _pricingType == 'hourly'
            ? int.tryParse(_minChargeCtrl.text.trim())
            : null,
        city: _selectedCity,
        emergencyService: _emergency,
        photos: _newPhotos.isNotEmpty ? _newPhotos : null,
      );

      if (!mounted) return;
      if (ok) {
        _snack('Annonce mise à jour !');
        Navigator.pop(context, true);
      } else {
        _snack(provider.listingsError ?? 'Échec de la mise à jour',
            isError: true);
      }
    } catch (e) {
      if (mounted) _snack('Erreur : $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _kError : _kSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kPageBg,
        appBar: _buildAppBar(),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusBanner(),
              const SizedBox(height: 20),
              _buildSection('Titre du service *', _buildTitleField()),
              const SizedBox(height: 20),
              _buildSection('Description *', _buildDescField()),
              const SizedBox(height: 20),
              _buildSection('Tarification *', _buildPricingSection()),
              const SizedBox(height: 20),
              _buildSection('Ville *', _buildCityDropdown()),
              const SizedBox(height: 20),
              _buildSection('Zones desservies * (au moins une)',
                  _buildNeighborhoodChips()),
              const SizedBox(height: 20),
              _buildSection('Jours disponibles', _buildDayChips()),
              const SizedBox(height: 20),
              _buildSection(
                  'Horaires (optionnel)',
                  _buildTextField(
                    controller: _hoursCtrl,
                    hint: 'ex. 08:00 – 18:00',
                  )),
              const SizedBox(height: 20),
              _buildEmergencyToggle(),
              const SizedBox(height: 20),
              _buildSection(
                  'Photos (${_existingPhotos.length + _newPhotos.length}/5)',
                  _buildPhotoManager()),
              const SizedBox(height: 20),
              _buildSection('Vidéo (1 max)', _buildVideoManager()),
              const SizedBox(height: 20),
              _buildSection(
                  'Années d\'expérience',
                  _buildTextField(
                    controller: _experienceCtrl,
                    hint: 'ex. 5',
                    keyboardType: TextInputType.number,
                    suffix: 'ans',
                  )),
              const SizedBox(height: 20),
              _buildSection(
                  'Certifications',
                  _buildTextField(
                    controller: _certsCtrl,
                    hint: 'ex. CAP Plombier',
                    maxLines: 3,
                  )),
              const SizedBox(height: 32),
              _buildSaveButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kSurface,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back_rounded, color: _kTextPrimary),
      ),
      title: Text('Modifier l\'annonce', style: AppTypography.titleLarge),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(
            'Sauver',
            style: AppTypography.labelMedium.copyWith(
              color: _isSubmitting ? _kTextLight : _kPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ── Status banner ─────────────────────────────────────────────────────────
  Widget _buildStatusBanner() {
    Color bg; Color fg; IconData icon; String msg;

    switch (widget.listing.status) {
      case ListingStatus.active:
        bg = _kSuccessLight; fg = _kSuccess;
        icon = Icons.check_circle_rounded;
        msg = 'Cette annonce est active. Les modifications sont sauvegardées immédiatement.';
        break;
      case ListingStatus.pending:
        bg = _kWarningLight; fg = _kWarning;
        icon = Icons.pending_rounded;
        msg = 'En cours d\'examen. Les modifications nécessiteront une nouvelle approbation.';
        break;
      case ListingStatus.rejected:
        bg = _kErrorLight; fg = _kError;
        icon = Icons.cancel_rounded;
        msg = widget.listing.rejectionReason != null
            ? 'Rejeté : ${widget.listing.rejectionReason}'
            : 'Rejeté. Modifiez et resoumettez pour approbation.';
        break;
      default:
        bg = _kInputBg; fg = _kTextSecond;
        icon = Icons.info_outline_rounded;
        msg = 'Modifiez les détails de votre annonce ci-dessous.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_rLg),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: AppTypography.bodySmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section wrapper ───────────────────────────────────────────────────────
  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FIX: overflow ellipsis so long section titles (e.g. "Photos (5/5)")
        // never overflow past the screen edge
        Text(
          title,
          style: AppTypography.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  // ── Title field ───────────────────────────────────────────────────────────
  Widget _buildTitleField() {
    return _buildTextField(
      controller: _titleCtrl,
      hint: 'ex. Plombier professionnel — Urgence 24h/24',
      maxLength: 200,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Titre requis';
        if (v.trim().length < 5) return 'Min 5 caractères';
        return null;
      },
    );
  }

  // ── Description field ─────────────────────────────────────────────────────
  Widget _buildDescField() {
    return _buildTextField(
      controller: _descCtrl,
      hint: 'Décrivez votre service en détail…',
      maxLines: 6,
      maxLength: 2000,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Description requise';
        if (v.trim().length < 20) return 'Min 20 caractères';
        return null;
      },
    );
  }

  // ── Pricing section ───────────────────────────────────────────────────────
  Widget _buildPricingSection() {
    return Column(
      children: [
        // Type selector
        // FIX: LayoutBuilder gives bounded width so each Expanded child has a
        // concrete max-width — prevents unbounded-width RenderFlex crash
        LayoutBuilder(
          builder: (context, constraints) {
            final types  = ['fixed', 'hourly', 'negotiable'];
            final labels = ['Fixe', 'Horaire', 'Négociable'];
            final itemW  = (constraints.maxWidth) / 3;

            return Container(
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(_rLg),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: List.generate(types.length, (i) {
                  final sel = _pricingType == types[i];
                  return GestureDetector(
                    onTap: () => setState(() {
                      _pricingType = types[i];
                      if (types[i] == 'negotiable') {
                        _priceCtrl.clear();
                        _minChargeCtrl.clear();
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: itemW,
                      padding:
                      const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? _kPrimary : Colors.transparent,
                        borderRadius:
                        BorderRadius.circular(_rLg - 1),
                      ),
                      child: Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'LeagueSpartan',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          // FIX: dark text on gold (correct contrast)
                          color: sel ? _kTextPrimary : _kTextSecond,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        if (_pricingType == 'fixed') ...[
          _buildTextField(
            controller: _priceCtrl,
            hint: 'ex. 15 000',
            label: 'Prix fixe',
            keyboardType: TextInputType.number,
            suffix: 'XAF',
          ),
        ] else if (_pricingType == 'hourly') ...[
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _priceCtrl,
                  hint: '5 000',
                  label: 'Taux/heure',
                  keyboardType: TextInputType.number,
                  suffix: 'XAF',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  controller: _minChargeCtrl,
                  hint: '10 000',
                  label: 'Minimum',
                  keyboardType: TextInputType.number,
                  suffix: 'XAF',
                ),
              ),
            ],
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.circular(_rMd),
              border: Border.all(color: _kPrimaryMid),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: _kPrimaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le prix sera discuté directement avec le client.',
                    style: AppTypography.bodySmall
                        .copyWith(color: _kPrimaryDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── City dropdown ─────────────────────────────────────────────────────────
  Widget _buildCityDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_rLg),
        border: Border.all(color: _kBorder),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedCity,
        isExpanded: true, // FIX: prevents long city names overflowing
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: const Icon(Icons.location_on_outlined,
              color: _kPrimary, size: 20),
        ),
        items: _cities
            .map((c) => DropdownMenuItem(
          value: c,
          child: Text(
            c,
            style: AppTypography.bodySmall
                .copyWith(color: _kTextPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() {
              _selectedCity = v;
              _selectedNeighborhoods.clear();
            });
          }
        },
        dropdownColor: _kSurface,
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            color: _kTextSecond),
      ),
    );
  }

  // ── Neighborhoods ─────────────────────────────────────────────────────────
  Widget _buildNeighborhoodChips() {
    final hoods = _neighborhoods[_selectedCity] ?? [];
    if (hoods.isEmpty) {
      return Text(
        'Pas de zones prédéfinies pour $_selectedCity.',
        style: AppTypography.bodySmall.copyWith(color: _kTextSecond),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hoods.map((h) {
        final sel = _selectedNeighborhoods.contains(h);
        return GestureDetector(
          onTap: () => setState(() {
            sel
                ? _selectedNeighborhoods.remove(h)
                : _selectedNeighborhoods.add(h);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? _kPrimary : _kSurface,
              borderRadius: BorderRadius.circular(_rPill),
              border: Border.all(
                  color: sel ? _kPrimary : _kBorder),
            ),
            child: Text(
              h,
              style: AppTypography.labelMedium.copyWith(
                // FIX: dark text on gold (correct contrast)
                color: sel ? _kTextPrimary : _kTextSecond,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Day chips ─────────────────────────────────────────────────────────────
  Widget _buildDayChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _days.map((d) {
        final sel = _selectedDays.contains(d);
        return GestureDetector(
          onTap: () => setState(() {
            sel ? _selectedDays.remove(d) : _selectedDays.add(d);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? _kPrimary : _kSurface,
              borderRadius: BorderRadius.circular(_rPill),
              border: Border.all(
                  color: sel ? _kPrimary : _kBorder),
            ),
            child: Text(
              d.length > 3 ? d.substring(0, 3) : d,
              style: AppTypography.labelMedium.copyWith(
                color: sel ? _kTextPrimary : _kTextSecond,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Emergency toggle ──────────────────────────────────────────────────────
  Widget _buildEmergencyToggle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _emergency ? _kErrorLight : _kSurface,
        borderRadius: BorderRadius.circular(_rLg),
        border: Border.all(
          color: _emergency ? _kError.withOpacity(0.4) : _kBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _emergency
                  ? _kError.withOpacity(0.12)
                  : _kInputBg,
              borderRadius: BorderRadius.circular(_rMd),
            ),
            child: Icon(Icons.emergency_rounded,
                color: _emergency ? _kError : _kTextSecond, size: 20),
          ),
          const SizedBox(width: 12),
          // FIX: Expanded so text never pushes the Switch off-screen
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service d\'urgence 24h/24',
                  style: AppTypography.titleSmall.copyWith(
                    color: _emergency ? _kError : _kTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Disponible pour les demandes urgentes à toute heure',
                  style: AppTypography.labelSmall
                      .copyWith(color: _kTextSecond),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: _emergency,
            onChanged: (v) => setState(() => _emergency = v),
            activeColor: _kError,
            activeTrackColor: _kError.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  // ── Photo manager ─────────────────────────────────────────────────────────
  Widget _buildPhotoManager() {
    final total = _existingPhotos.length + _newPhotos.length;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ..._existingPhotos.asMap().entries.map((e) => _NetworkPhotoTile(
          url: e.value,
          onRemove: () => _removeExistingPhoto(e.key),
        )),
        ..._newPhotos.asMap().entries.map((e) => _LocalPhotoTile(
          file: e.value,
          onRemove: () => _removeNewPhoto(e.key),
          isNew: true,
        )),
        if (total < 5)
          _AddMediaTile(
            icon: Icons.add_photo_alternate_outlined,
            label: 'Ajouter',
            onTap: _pickPhoto,
          ),
      ],
    );
  }

  // ── Video manager ─────────────────────────────────────────────────────────
  Widget _buildVideoManager() {
    if (_existingVideoUrl != null) {
      return _ExistingVideoTile(
        url: _existingVideoUrl!,
        onRemove: _removeExistingVideo,
      );
    }
    if (_newVideo != null && _videoController != null) {
      return _NewVideoPreview(
        controller: _videoController!,
        onRemove: _removeNewVideo,
      );
    }
    return _AddMediaTile(
      icon: Icons.videocam_outlined,
      label: 'Ajouter une vidéo\n(3 min max · 100 Mo)',
      onTap: _pickVideo,
      height: 100,
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: _kTextPrimary,
          disabledBackgroundColor: _kBorder,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rLg)),
        ),
        icon: _isSubmitting
            ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: _kTextPrimary),
        )
            : const Icon(Icons.save_rounded, size: 20),
        label: Text(
          'Sauvegarder les modifications',
          style: AppTypography.buttonMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ── Shared text field ─────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? label,
    String? suffix,
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_rLg),
        border: Border.all(color: _kBorder),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        style: AppTypography.bodyMedium.copyWith(color: _kTextPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTypography.labelMedium,
          hintText: hint,
          hintStyle: AppTypography.bodySmall.copyWith(color: _kTextLight),
          suffixText: suffix,
          suffixStyle: AppTypography.labelSmall,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
          counterStyle: AppTypography.labelSmall,
        ),
        validator: validator,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NETWORK PHOTO TILE
// ─────────────────────────────────────────────────────────────────────────────
class _NetworkPhotoTile extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;
  const _NetworkPhotoTile({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_rLg),
          child: Image.network(
            url,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 96,
              height: 96,
              color: _kInputBg,
              child: Icon(Icons.image_not_supported,
                  color: _kTextLight),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('sauvé',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        Positioned(top: 4, right: 4, child: _RemoveBtn(onTap: onRemove)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL PHOTO TILE
// ─────────────────────────────────────────────────────────────────────────────
class _LocalPhotoTile extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  final bool isNew;
  const _LocalPhotoTile(
      {required this.file, required this.onRemove, this.isNew = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_rLg),
          child: Image.file(file, width: 96, height: 96, fit: BoxFit.cover),
        ),
        if (isNew)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _kSuccess.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('nouveau',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        Positioned(top: 4, right: 4, child: _RemoveBtn(onTap: onRemove)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXISTING VIDEO TILE
// ─────────────────────────────────────────────────────────────────────────────
class _ExistingVideoTile extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;
  const _ExistingVideoTile({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    // Truncate filename safely
    final filename = url.split('/').last;
    final display  = filename.length > 30
        ? '…${filename.substring(filename.length - 20)}'
        : filename;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(_rLg),
        border: Border.all(color: _kPrimary, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_rounded,
                  color: Colors.white54, size: 32),
              const SizedBox(height: 6),
              Text('Vidéo sauvegardée',
                  style: AppTypography.labelSmall
                      .copyWith(color: Colors.white54)),
              const SizedBox(height: 2),
              // FIX: constrained so the filename never causes a horizontal overflow
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  display,
                  style: AppTypography.labelSmall
                      .copyWith(color: Colors.white38, fontSize: 9),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Positioned(top: 8, right: 8, child: _RemoveBtn(onTap: onRemove)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEW VIDEO PREVIEW
// ─────────────────────────────────────────────────────────────────────────────
class _NewVideoPreview extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onRemove;
  const _NewVideoPreview(
      {required this.controller, required this.onRemove});

  @override
  State<_NewVideoPreview> createState() => _NewVideoPreviewState();
}

class _NewVideoPreviewState extends State<_NewVideoPreview> {
  bool _playing = false;

  void _toggle() {
    setState(() {
      _playing = !_playing;
      _playing ? widget.controller.play() : widget.controller.pause();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dur   = widget.controller.value.duration;
    final label =
        '${dur.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${dur.inSeconds.remainder(60).toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(_rLg),
        border: Border.all(color: _kPrimary, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_rLg - 2),
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
          ),
          GestureDetector(
            onTap: _toggle,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(_rSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_rounded,
                      size: 10, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: _kSuccess.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('nouveau',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
              top: 8,
              right: 8,
              child: _RemoveBtn(onTap: widget.onRemove)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD MEDIA TILE
// ─────────────────────────────────────────────────────────────────────────────
class _AddMediaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double height;

  const _AddMediaTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.height = 96,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  height == 96 ? 96 : double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: _kInputBg,
          borderRadius: BorderRadius.circular(_rLg),
          border: Border.all(
              color: _kPrimary.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _kPrimary, size: 28),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: _kPrimary,
                  fontWeight: FontWeight.w600,
                ),
                // FIX: ellipsis so multi-line label doesn't overflow the tile
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REMOVE BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _RemoveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
            color: _kError, shape: BoxShape.circle),
        child: const Icon(Icons.close, color: Colors.white, size: 14),
      ),
    );
  }
}
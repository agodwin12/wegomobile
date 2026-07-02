// lib/screens/services/post_service_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Post Service Screen  (Provider — create a new listing)
// Overflow-fixed + aligned to AppColors / AppTypography
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

import '../../models/listing_plan_model.dart';
import '../../models/services/category_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

// ─── Local design tokens ──────────────────────────────────────────────────────
const _kPrimary      = AppColors.primaryGold;
const _kPrimaryLight = Color(0xFFFFFDE7);
const _kPrimaryMid   = Color(0xFFFFECB3);
const _kPrimaryDark  = AppColors.primaryGoldDark;
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

const double _rSm   = 6.0;
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
class PostServiceScreen extends StatefulWidget {
  const PostServiceScreen({Key? key}) : super(key: key);

  @override
  State<PostServiceScreen> createState() => _PostServiceScreenState();
}

class _PostServiceScreenState extends State<PostServiceScreen> {
  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  final _pageController = PageController();
  int  _currentStep  = 0;
  bool _isSubmitting = false;

  // ── Step 1 ────────────────────────────────────────────────────────────────
  ServiceCategory? _parentCategory;
  ServiceCategory? _subcategory;
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();

  // ── Step 2 ────────────────────────────────────────────────────────────────
  String _pricingType  = 'fixed';
  final _priceCtrl     = TextEditingController();
  final _minChargeCtrl = TextEditingController();
  String _selectedCity = 'Douala';
  final List<String> _selectedNeighborhoods = [];
  final List<String> _selectedDays          = [];
  final _hoursCtrl     = TextEditingController();
  bool _emergency      = false;

  // ── Step 3 ────────────────────────────────────────────────────────────────
  final List<File> _photos = [];
  File? _video;
  VideoPlayerController? _videoController;
  final _experienceCtrl = TextEditingController();
  final _certsCtrl      = TextEditingController();

  final _picker = ImagePicker();

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

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicesProvider>().fetchParentCategories();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  // ── Navigation ────────────────────────────────────────────────────────────
  void _next() {
    if (!_formKeys[_currentStep].currentState!.validate()) return;

    if (_currentStep == 0 && _parentCategory == null) {
      _snack('Veuillez sélectionner une catégorie', isError: true);
      return;
    }

    if (_currentStep == 1) {
      if (_pricingType != 'negotiable' &&
          (_priceCtrl.text.trim().isEmpty ||
              double.tryParse(_priceCtrl.text.trim()) == null)) {
        _snack('Veuillez saisir un prix valide', isError: true);
        return;
      }
      if (_selectedNeighborhoods.isEmpty) {
        _snack('Veuillez sélectionner au moins une zone', isError: true);
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _confirmDiscard();
    }
  }

  void _confirmDiscard() {
    final hasData = _titleCtrl.text.isNotEmpty ||
        _descCtrl.text.isNotEmpty ||
        _parentCategory != null;
    if (!hasData) {
      Navigator.pop(context);
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rXl)),
        title: Text('Abandonner le brouillon ?',
            style: AppTypography.titleLarge),
        content: Text('Vos modifications seront perdues.',
            style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continuer l\'édition',
              style: AppTypography.labelMedium
                  .copyWith(color: _kTextSecond),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_rMd)),
            ),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final provider = context.read<ServicesProvider>();
      final price     = int.tryParse(_priceCtrl.text.trim());
      final minCharge = int.tryParse(_minChargeCtrl.text.trim());


      final args  = ModalRoute.of(context)?.settings.arguments
      as Map<String, dynamic>?;
      final plan  = args?['plan']  as ListingPlan?;
      final phone = args?['phone'] as String?;
      final isFree = plan == null || plan.isFree;

      // ── 1. Create the listing ─────────────────────────────────────────────
      final newListingId = await provider.createListing(
        categoryId: (_subcategory ?? _parentCategory)!.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        pricingType: _pricingType,
        price: _pricingType != 'negotiable' ? price : null,
        minCharge: _pricingType == 'hourly' ? minCharge : null,
        city: _selectedCity,
        neighborhoods: _selectedNeighborhoods,
        emergencyService: _emergency,
        photos: _photos.isNotEmpty ? _photos : null,
      );

      if (newListingId == null || !mounted) {
        if (mounted) {
          _snack(provider.listingsError ?? 'Échec de la création',
              isError: true);
        }
        return;
      }

      // ── 2a. Free plan — activate immediately, pop back with listingId ─────
      // ListingPlanScreen receives { listingId } and shows its success dialog.
      if (isFree) {
        await provider.activateFreePlan(newListingId);
        if (!mounted) return;
        Navigator.pop(context, {'listingId': newListingId});
        return;
      }

      // ── 2b. Paid plan — initiate CamPay USSD push, then hand back ─────────
      // ListingPlanScreen is already polling checkAdPaymentStatus(listingId)
      // every 3 s. We just need to trigger the payment and return the id.
      await provider.initiateListingPayment(
        listingId: newListingId,
        planId:    plan!.id,
        phone:     phone ?? '',
      );
      if (!mounted) return;
      Navigator.pop(context, {'listingId': newListingId});

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

  // ── Media helpers ─────────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    if (_photos.length >= 5) {
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
      setState(() => _photos.add(File(img.path)));
    }
  }

  Future<void> _pickVideo() async {
    if (_video != null) {
      _snack('Supprimez la vidéo actuelle avant d\'en ajouter une autre',
          isError: true);
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
        _video = file;
        _videoController?.dispose();
        _videoController = ctrl;
      });
    }
  }

  void _removePhoto(int i)  => setState(() => _photos.removeAt(i));
  void _removeVideo() {
    _videoController?.dispose();
    setState(() { _video = null; _videoController = null; });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kPageBg,
        // FIX: explicit true so the keyboard never obscures the active field
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            _buildHeader(),
            _buildStepper(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final topPad = MediaQuery.of(context).padding.top;
    final subtitles = [
      'Catégorie & Description',
      'Tarification & Localisation',
      'Photos, Vidéo & Détails',
    ];

    return Container(
      color: _kSurface,
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: _back,
            child: Icon(Icons.arrow_back_rounded,
                color: _kTextPrimary, size: 24),
          ),
          const SizedBox(width: 16),
          // FIX: Expanded on the title column so the "Step X/3" badge
          // never gets pushed off-screen by a long subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Publier un service',
                    style: AppTypography.titleLarge),
                Text(
                  subtitles[_currentStep],
                  style: AppTypography.bodySmall
                      .copyWith(color: _kTextSecond),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // FIX: badge has fixed intrinsic width — no flex needed
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.circular(_rPill),
              border: Border.all(color: _kPrimaryMid),
            ),
            child: Text(
              'Étape ${_currentStep + 1}/3',
              style: AppTypography.labelSmall.copyWith(
                color: _kPrimaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step progress bar ─────────────────────────────────────────────────────
  Widget _buildStepper() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: List.generate(3, (i) {
          final active = i <= _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: active ? _kPrimary : _kBorder,
                      borderRadius: BorderRadius.circular(_rPill),
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — Category + Title + Description
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Form(
      key: _formKeys[0],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('Catégorie de service *'),
          const SizedBox(height: 10),
          _buildCategoryPicker(),
          const SizedBox(height: 20),
          _sectionLabel('Titre du service *'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _titleCtrl,
            hint: 'ex. Plombier professionnel — Urgence 24h/24',
            maxLength: 200,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Veuillez saisir un titre';
              }
              if (v.trim().length < 5) {
                return 'Le titre doit contenir au moins 5 caractères';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _sectionLabel('Description *'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _descCtrl,
            hint: 'Décrivez votre service en détail — expérience, ce que vous offrez…',
            maxLines: 6,
            maxLength: 2000,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Veuillez saisir une description';
              }
              if (v.trim().length < 20) {
                return 'La description doit contenir au moins 20 caractères';
              }
              return null;
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Consumer<ServicesProvider>(
      builder: (_, provider, __) {
        final parents = provider.parentCategories;
        final subs    = provider.subcategories ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown<ServiceCategory>(
              value: _parentCategory,
              hint: 'Sélectionner une catégorie',
              items: parents,
              labelBuilder: (c) => c.getLocalizedName(useFrench: true),
              onChanged: (c) async {
                setState(() {
                  _parentCategory = c;
                  _subcategory    = null;
                });
                if (c != null) {
                  await provider.fetchSubcategories(c.id);
                }
              },
            ),
            if (_parentCategory != null && subs.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildDropdown<ServiceCategory>(
                value: _subcategory,
                hint: 'Sous-catégorie (optionnel)',
                items: subs,
                labelBuilder: (c) => c.getLocalizedName(useFrench: true),
                onChanged: (c) => setState(() => _subcategory = c),
              ),
            ],
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — Pricing + Location + Availability
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Form(
      key: _formKeys[1],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('Type de tarification *'),
          const SizedBox(height: 10),
          _buildPricingTypeRow(),
          const SizedBox(height: 16),
          _buildPricingFields(),
          const SizedBox(height: 20),
          _sectionLabel('Ville *'),
          const SizedBox(height: 8),
          _buildDropdown<String>(
            value: _selectedCity,
            hint: 'Sélectionner une ville',
            items: _cities,
            labelBuilder: (c) => c,
            onChanged: (c) {
              if (c != null) {
                setState(() {
                  _selectedCity = c;
                  _selectedNeighborhoods.clear();
                });
              }
            },
          ),
          const SizedBox(height: 20),
          _sectionLabel('Zones desservies * (au moins une)'),
          const SizedBox(height: 10),
          _buildNeighborhoodChips(),
          const SizedBox(height: 20),
          _sectionLabel('Jours disponibles'),
          const SizedBox(height: 10),
          _buildDayChips(),
          const SizedBox(height: 20),
          _sectionLabel('Horaires (optionnel)'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _hoursCtrl,
            hint: 'ex. 08:00 – 18:00',
            maxLines: 1,
          ),
          const SizedBox(height: 20),
          _buildEmergencyToggle(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPricingTypeRow() {
    const types = [
      ('fixed',      'Prix fixe'),
      ('hourly',     'Taux horaire'),
      ('negotiable', 'Négociable'),
    ];

    // FIX: LayoutBuilder gives us bounded width so each Expanded child
    // has a concrete max-width; prevents unbounded-width RenderFlex crash
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemW = (constraints.maxWidth - 16) / 3;
        return Row(
          children: types.map((t) {
            final selected = _pricingType == t.$1;
            final isLast   = t.$1 == 'negotiable';
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _pricingType = t.$1;
                      if (t.$1 == 'negotiable') {
                        _priceCtrl.clear();
                        _minChargeCtrl.clear();
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: itemW,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? _kPrimary : _kSurface,
                      borderRadius: BorderRadius.circular(_rLg),
                      border: Border.all(
                        color: selected ? _kPrimary : _kBorder,
                      ),
                    ),
                    child: Text(
                      t.$2,
                      textAlign: TextAlign.center,
                      // FIX: overflow ellipsis so long labels never cause
                      // RenderFlex overflow on small screens
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        // FIX: dark text on gold (correct contrast)
                        color: selected ? _kTextPrimary : _kTextSecond,
                      ),
                    ),
                  ),
                ),
                if (!isLast) const SizedBox(width: 8),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPricingFields() {
    if (_pricingType == 'negotiable') {
      return Container(
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
      );
    }

    if (_pricingType == 'fixed') {
      return _buildTextField(
        controller: _priceCtrl,
        hint: 'ex. 15 000',
        label: 'Prix fixe (XAF) *',
        keyboardType: TextInputType.number,
        suffix: 'XAF',
      );
    }

    // hourly — two fields side by side
    // FIX: use a Row with two Expanded children instead of nested
    // Expanded inside a Column, which had no bounded width constraint
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _priceCtrl,
            hint: '5 000',
            label: 'Taux/heure *',
            keyboardType: TextInputType.number,
            suffix: 'XAF/h',
          ),
        ),
        const SizedBox(width: 12),
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
    );
  }

  Widget _buildNeighborhoodChips() {
    final hoods = _neighborhoods[_selectedCity] ?? [];
    if (hoods.isEmpty) {
      return Text(
        'Pas de zones prédéfinies pour cette ville — les clients verront votre ville.',
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
                // FIX: dark text on gold
                color: sel ? _kTextPrimary : _kTextSecond,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

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
              // Abbreviate to 3 chars to keep chips narrow
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

  Widget _buildEmergencyToggle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _emergency ? _kErrorLight : _kSurface,
        borderRadius: BorderRadius.circular(_rLg),
        border: Border.all(
          color: _emergency
              ? _kError.withOpacity(0.4)
              : _kBorder,
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
            child: Icon(
              Icons.emergency_rounded,
              color: _emergency ? _kError : _kTextSecond,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // FIX: Expanded so the text column never overflows past the Switch
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

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3 — Photos + Video + Extras
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Form(
      key: _formKeys[2],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Photos header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // FIX: Flexible so "Photos (5/5)" doesn't push "Optionnel" off
              Flexible(
                child: Text(
                  'Photos (${_photos.length}/5)',
                  style: AppTypography.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('Optionnel',
                  style: AppTypography.labelSmall
                      .copyWith(color: _kTextLight)),
            ],
          ),
          const SizedBox(height: 10),
          _buildPhotoGrid(),

          const SizedBox(height: 24),

          // Video header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Vidéo (1 max)',
                  style: AppTypography.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(_rPill),
                  border: Border.all(color: _kPrimaryMid),
                ),
                child: Text(
                  '3 min · 100 Mo',
                  style: AppTypography.labelSmall
                      .copyWith(color: _kPrimaryDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildVideoSection(),

          const SizedBox(height: 24),

          _sectionLabel('Années d\'expérience (optionnel)'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _experienceCtrl,
            hint: 'ex. 5',
            keyboardType: TextInputType.number,
            suffix: 'ans',
            maxLines: 1,
          ),

          const SizedBox(height: 20),

          _sectionLabel('Certifications (optionnel)'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _certsCtrl,
            hint: 'ex. CAP Plombier, Diplôme ISTDI',
            maxLines: 3,
          ),

          const SizedBox(height: 20),

          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.circular(_rLg),
              border: Border.all(color: _kPrimaryMid),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: _kPrimaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Votre annonce sera examinée par notre équipe sous 24 h. Vous recevrez une notification une fois approuvée.',
                    style: AppTypography.bodySmall
                        .copyWith(color: _kPrimaryDark),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ..._photos.asMap().entries.map((e) => _PhotoTile(
          file: e.value,
          onRemove: () => _removePhoto(e.key),
        )),
        if (_photos.length < 5)
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _kInputBg,
                borderRadius: BorderRadius.circular(_rLg),
                border: Border.all(
                    color: _kPrimary.withOpacity(0.4), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined,
                      color: _kPrimary, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    'Ajouter',
                    style: AppTypography.labelSmall
                        .copyWith(color: _kPrimary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoSection() {
    if (_video != null && _videoController != null) {
      return _VideoPreview(
        controller: _videoController!,
        onRemove: _removeVideo,
      );
    }

    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _kInputBg,
          borderRadius: BorderRadius.circular(_rLg),
          border: Border.all(
              color: _kPrimary.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: _kPrimaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_outlined,
                  color: _kPrimary, size: 32),
            ),
            const SizedBox(height: 10),
            Text(
              'Appuyez pour ajouter une vidéo',
              style: AppTypography.titleSmall
                  .copyWith(color: _kPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Montrez votre travail — 3 min max, 100 Mo',
              style: AppTypography.labelSmall
                  .copyWith(color: _kTextSecond),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isLast     = _currentStep == 2;
    final bottomPad  = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 12),
      decoration: BoxDecoration(
        color: _kSurface,
        boxShadow: _kBottomShadow,
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            // Back button — fixed-width, never Expanded
            OutlinedButton(
              onPressed: _back,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kTextSecond,
                side: BorderSide(color: _kBorder),
                minimumSize: const Size(50, 50),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_rLg)),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
            const SizedBox(width: 12),
          ],

          // Next / Submit button — Expanded so it fills remaining width
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _next,
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
                    strokeWidth: 2,
                    color: _kTextPrimary,
                  ),
                )
                    : Icon(
                  isLast
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  size: 20,
                ),
                label: Text(
                  isLast ? 'Envoyer pour approbation' : 'Suivant',
                  style: AppTypography.buttonMedium,
                  // FIX: ellipsis so "Envoyer pour approbation" doesn't
                  // overflow on 320 dp wide screens
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _sectionLabel(String t) => Text(t,
      style: AppTypography.titleSmall,
      overflow: TextOverflow.ellipsis);

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
          hintStyle: AppTypography.bodyMedium.copyWith(color: _kTextLight),
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

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_rLg),
        border: Border.all(color: _kBorder),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true, // FIX: prevents dropdown label from overflowing
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        hint: Text(hint,
            style: AppTypography.bodySmall.copyWith(color: _kTextLight)),
        items: items
            .map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(
            labelBuilder(item),
            style: AppTypography.bodySmall
                .copyWith(color: _kTextPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ))
            .toList(),
        onChanged: onChanged,
        dropdownColor: _kSurface,
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            color: _kTextSecond),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHOTO TILE
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoTile extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _PhotoTile({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_rLg),
          child: Image.file(
            file,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: _kError,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VIDEO PREVIEW
// ─────────────────────────────────────────────────────────────────────────────
class _VideoPreview extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onRemove;
  const _VideoPreview({required this.controller, required this.onRemove});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  bool _playing = false;

  void _togglePlay() {
    setState(() {
      _playing = !_playing;
      _playing ? widget.controller.play() : widget.controller.pause();
    });
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.controller.value.duration;
    final mins = duration.inMinutes.remainder(60)
        .toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60)
        .toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(_rLg),
        border: Border.all(color: _kPrimary, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video frame
          ClipRRect(
            borderRadius: BorderRadius.circular(_rLg - 2),
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
          ),

          // Play/pause overlay
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),

          // Duration badge
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(_rSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_rounded,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '$mins:$secs',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Remove button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: widget.onRemove,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: _kError,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
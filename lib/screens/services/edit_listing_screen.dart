// lib/screens/services/edit_listing_screen.dart
// WEGO Services Marketplace - Edit Listing Screen
// ✅ FIXED: Matches exact provider.updateListing signature

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../models/services/service_listing_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class EditListingScreen extends StatefulWidget {
  final ServiceListing listing;

  const EditListingScreen({
    Key? key,
    required this.listing,
  }) : super(key: key);

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _minChargeController;

  // State
  late String _selectedPricingType;
  late String _selectedCity;
  late bool _emergencyService;
  final List<File> _newPhotos = [];
  late List<String> _existingPhotos;
  bool _isSubmitting = false;

  final List<String> _cities = [
    'Douala',
    'Yaoundé',
    'Bafoussam',
    'Bamenda',
    'Garoua',
    'Maroua',
    'Ngaoundéré',
    'Kribi',
    'Limbe',
  ];

  final List<String> _availableDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late List<String> _selectedDays;

  // ─── Convert PricingType enum to string ──────────────────────────
  String _pricingTypeToString(PricingType type) {
    switch (type) {
      case PricingType.hourly:
        return 'hourly';
      case PricingType.fixed:
        return 'fixed';
      case PricingType.negotiable:
        return 'negotiable';
    }
  }

  // ─── Get the current price value from listing ────────────────────
  String _getCurrentPrice() {
    switch (widget.listing.pricingType) {
      case PricingType.hourly:
        return widget.listing.hourlyRate?.toStringAsFixed(0) ?? '';
      case PricingType.fixed:
        return widget.listing.fixedPrice?.toStringAsFixed(0) ?? '';
      case PricingType.negotiable:
        return '';
    }
  }

  String _getCurrentMinCharge() {
    return widget.listing.minimumCharge?.toStringAsFixed(0) ?? '';
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _titleController = TextEditingController(text: widget.listing.title);
    _descriptionController =
        TextEditingController(text: widget.listing.description);
    _priceController = TextEditingController(text: _getCurrentPrice());
    _minChargeController =
        TextEditingController(text: _getCurrentMinCharge());

    _selectedPricingType =
        _pricingTypeToString(widget.listing.pricingType);
    _selectedCity = widget.listing.city;
    _emergencyService = widget.listing.emergencyService;
    _existingPhotos = List<String>.from(widget.listing.photos);

    // ✅ FIX: availableDays is String? not List<String>
    // Parse it from JSON string "[\"Monday\",\"Tuesday\"]" or plain "Monday,Tuesday"
    _selectedDays = _parseDaysFromString(widget.listing.availableDays);
  }

  /// Parse available days from the String? field in the model
  List<String> _parseDaysFromString(String? value) {
    if (value == null || value.isEmpty) return [];

    // Try JSON array format: ["Monday","Tuesday"]
    if (value.startsWith('[')) {
      try {
        final cleaned = value
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return cleaned;
      } catch (_) {
        return [];
      }
    }

    // Try comma-separated format: "Monday,Tuesday"
    if (value.contains(',')) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    // Single day
    return [value.trim()];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _minChargeController.dispose();
    super.dispose();
  }

  // ─── Pick new photo ───────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    final total = _existingPhotos.length + _newPhotos.length;
    if (total >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 photos allowed'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null && mounted) {
      setState(() => _newPhotos.add(File(image.path)));
    }
  }

  void _removeExistingPhoto(int index) {
    setState(() => _existingPhotos.removeAt(index));
  }

  void _removeNewPhoto(int index) {
    setState(() => _newPhotos.removeAt(index));
  }

  // ─── Submit update ────────────────────────────────────────────────
  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPricingType != 'negotiable' &&
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedPricingType == 'hourly'
                ? 'Please enter your hourly rate'
                : 'Please enter your fixed price',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ServicesProvider>();

      // ✅ Match exact provider signature: price (int) and minCharge (int)
      int? price = int.tryParse(_priceController.text.trim());
      int? minCharge = int.tryParse(_minChargeController.text.trim());

      final success = await provider.updateListing(
        id: widget.listing.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        pricingType: _selectedPricingType,
        price: _selectedPricingType != 'negotiable' ? price : null,
        minCharge:
        _selectedPricingType == 'hourly' ? minCharge : null,
        city: _selectedCity,
        emergencyService: _emergencyService,
        photos: _newPhotos.isNotEmpty ? _newPhotos : null,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Listing updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.listingsError ?? 'Failed to update listing',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusBanner(isTablet),
              const SizedBox(height: 24),
              _buildSectionTitle('Service Title *'),
              const SizedBox(height: 8),
              _buildTitleField(),
              const SizedBox(height: 20),
              _buildSectionTitle('Description *'),
              const SizedBox(height: 8),
              _buildDescriptionField(),
              const SizedBox(height: 20),
              _buildSectionTitle('Pricing *'),
              const SizedBox(height: 8),
              _buildPricingSection(isTablet),
              const SizedBox(height: 20),
              _buildSectionTitle('City *'),
              const SizedBox(height: 8),
              _buildCityDropdown(),
              const SizedBox(height: 20),
              _buildSectionTitle('Available Days'),
              const SizedBox(height: 8),
              _buildAvailabilitySection(),
              const SizedBox(height: 20),
              _buildEmergencyToggle(isTablet),
              const SizedBox(height: 20),
              _buildSectionTitle(
                'Photos (${_existingPhotos.length + _newPhotos.length}/5)',
              ),
              const SizedBox(height: 8),
              _buildPhotosSection(isTablet),
              const SizedBox(height: 32),
              _buildSubmitButton(isTablet),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.backgroundWhite,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon:
        const Icon(Icons.arrow_back, color: AppColors.textPrimary),
      ),
      title: Text(
        'Edit Listing',
        style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : _submitUpdate,
          child: Text(
            'Save',
            style: AppTypography.labelLarge.copyWith(
              color: _isSubmitting
                  ? AppColors.textSecondary
                  : AppColors.primaryGold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATUS BANNER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStatusBanner(bool isTablet) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String message;

    switch (widget.listing.status) {
      case ListingStatus.pending:
        bgColor = AppColors.warningLight;
        textColor = AppColors.warning;
        icon = Icons.pending_rounded;
        message =
        'This listing is pending approval. Changes will require re-approval.';
        break;
      case ListingStatus.active:
        bgColor = AppColors.successLight;
        textColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        message =
        'This listing is active. Saving changes will keep it active.';
        break;
      case ListingStatus.rejected:
        bgColor = AppColors.errorLight;
        textColor = AppColors.error;
        icon = Icons.cancel_rounded;
        message =
        'This listing was rejected. Edit and resubmit for approval.';
        break;
      case ListingStatus.inactive:
        bgColor = AppColors.backgroundLight;
        textColor = AppColors.textSecondary;
        icon = Icons.pause_circle_rounded;
        message = 'This listing is inactive. Changes will be saved.';
        break;
      default:
        bgColor = AppColors.infoLight;
        textColor = AppColors.info;
        icon = Icons.info_rounded;
        message = 'Edit your listing details below.';
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.titleSmall.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TITLE FIELD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTitleField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: TextFormField(
        controller: _titleController,
        maxLength: 200,
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(
          hintText: 'e.g., Plombier professionnel - Urgences 24/7',
          hintStyle: AppTypography.inputHint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          counterStyle: AppTypography.caption
              .copyWith(color: AppColors.textSecondary),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a title';
          }
          if (value.trim().length < 10) {
            return 'Title must be at least 10 characters';
          }
          return null;
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DESCRIPTION FIELD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: TextFormField(
        controller: _descriptionController,
        maxLines: 6,
        maxLength: 2000,
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Describe your service in detail...',
          hintStyle: AppTypography.inputHint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          counterStyle: AppTypography.caption
              .copyWith(color: AppColors.textSecondary),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a description';
          }
          if (value.trim().length < 50) {
            return 'Description must be at least 50 characters';
          }
          return null;
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRICING SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildPricingSection(bool isTablet) {
    return Column(
      children: [
        // Pricing type selector
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children:
            ['hourly', 'fixed', 'negotiable'].map((type) {
              final isSelected = _selectedPricingType == type;
              final label = type == 'hourly'
                  ? 'Hourly'
                  : type == 'fixed'
                  ? 'Fixed'
                  : 'Negotiable';

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                          () => _selectedPricingType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                    const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGold
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelMedium.copyWith(
                        color: isSelected
                            ? AppColors.primaryBlack
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Price inputs
        if (_selectedPricingType == 'hourly') ...[
          Row(
            children: [
              Expanded(
                child: _buildPriceField(
                  controller: _priceController,
                  label: 'Rate per hour *',
                  hint: '5000',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriceField(
                  controller: _minChargeController,
                  label: 'Minimum charge',
                  hint: '10000',
                ),
              ),
            ],
          ),
        ] else if (_selectedPricingType == 'fixed') ...[
          _buildPriceField(
            controller: _priceController,
            label: 'Fixed price *',
            hint: '15000',
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.info, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Price will be discussed with the customer directly.',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: AppTypography.bodyMedium,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.inputHint,
              suffixText: 'FCFA',
              suffixStyle: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CITY DROPDOWN
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildCityDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: DropdownButtonFormField<String>(
        value: _cities.contains(_selectedCity) ? _selectedCity : null,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding:
          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          prefixIcon: Icon(
            Icons.location_on_outlined,
            color: AppColors.primaryGold,
          ),
        ),
        hint: Text('Select city', style: AppTypography.inputHint),
        items: _cities.map((city) {
          return DropdownMenuItem(
            value: city,
            child: Text(city, style: AppTypography.bodyMedium),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) setState(() => _selectedCity = value);
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a city';
          }
          return null;
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // AVAILABILITY SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildAvailabilitySection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableDays.map((day) {
        final isSelected = _selectedDays.contains(day);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedDays.remove(day);
              } else {
                _selectedDays.add(day);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGold
                  : AppColors.backgroundWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryGold
                    : AppColors.borderLight,
              ),
            ),
            child: Text(
              day.substring(0, 3),
              style: AppTypography.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.primaryBlack
                    : AppColors.textSecondary,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // EMERGENCY TOGGLE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildEmergencyToggle(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: _emergencyService
            ? AppColors.errorLight
            : AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _emergencyService
              ? AppColors.error.withOpacity(0.4)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _emergencyService
                  ? AppColors.error.withOpacity(0.15)
                  : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.emergency_rounded,
              color: _emergencyService
                  ? AppColors.error
                  : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Service (24/7)',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _emergencyService
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Customers can reach you any time for urgent needs',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _emergencyService,
            onChanged: (value) =>
                setState(() => _emergencyService = value),
            activeColor: AppColors.error,
            activeTrackColor: AppColors.error.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PHOTOS SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildPhotosSection(bool isTablet) {
    final totalPhotos = _existingPhotos.length + _newPhotos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._existingPhotos.asMap().entries.map((entry) =>
                  _buildExistingPhotoTile(entry.key, entry.value)),
              ..._newPhotos.asMap().entries.map((entry) =>
                  _buildNewPhotoTile(entry.key, entry.value)),
              if (totalPhotos < 5) _buildAddPhotoTile(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$totalPhotos/5 photos · Existing: ${_existingPhotos.length} · New: ${_newPhotos.length}',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildExistingPhotoTile(int index, String url) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 100,
                height: 100,
                color: AppColors.backgroundLight,
                child: const Icon(Icons.image_not_supported,
                    color: AppColors.textLight),
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 14,
          child: GestureDetector(
            onTap: () => _removeExistingPhoto(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  color: Colors.white, size: 14),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 4,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Existing',
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontSize: 9,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPhotoTile(int index, File file) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              file,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 14,
          child: GestureDetector(
            onTap: () => _removeNewPhoto(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  color: Colors.white, size: 14),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 4,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'New',
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontSize: 9,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoTile() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primaryGold.withOpacity(0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.primaryGold,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              'Add Photo',
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SUBMIT BUTTON
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSubmitButton(bool isTablet) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitUpdate,
        icon: _isSubmitting
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryBlack,
          ),
        )
            : const Icon(Icons.save_rounded),
        label: Text(
          _isSubmitting ? 'Saving...' : 'Save Changes',
          style: AppTypography.buttonLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGold,
          foregroundColor: AppColors.primaryBlack,
          disabledBackgroundColor: AppColors.borderLight,
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 18 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
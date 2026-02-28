

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/services/service_listing_model.dart';

import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class ContactProviderScreen extends StatefulWidget {
  final ServiceListing? listing;

  const ContactProviderScreen({
    Key? key,
    this.listing,
  }) : super(key: key);

  @override
  State<ContactProviderScreen> createState() => _ContactProviderScreenState();
}

class _ContactProviderScreenState extends State<ContactProviderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  List<File> _selectedImages = [];

  String _selectedTiming = 'asap'; // asap, today, tomorrow, scheduled
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    if (widget.listing == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: const Center(
          child: Text('Service not found'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          children: [
            // ═══════════════════════════════════════════════════════
            // SERVICE SUMMARY CARD
            // ═══════════════════════════════════════════════════════
            _buildServiceSummaryCard(isTablet),

            const SizedBox(height: 24),

            // ═══════════════════════════════════════════════════════
            // SECTION TITLE
            // ═══════════════════════════════════════════════════════
            Text(
              'Request Details',
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 16),

            // ═══════════════════════════════════════════════════════
            // DESCRIPTION FIELD
            // ═══════════════════════════════════════════════════════
            _buildDescriptionField(isTablet),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════════════
            // PHOTO UPLOAD
            // ═══════════════════════════════════════════════════════
            _buildPhotoUpload(isTablet),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════════════
            // WHEN NEEDED
            // ═══════════════════════════════════════════════════════
            _buildWhenNeeded(isTablet),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════════════
            // LOCATION FIELD
            // ═══════════════════════════════════════════════════════
            _buildLocationField(isTablet),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════════════
            // BUDGET FIELD (OPTIONAL)
            // ═══════════════════════════════════════════════════════
            _buildBudgetField(isTablet),

            const SizedBox(height: 32),

            // ═══════════════════════════════════════════════════════
            // SUBMIT BUTTON
            // ═══════════════════════════════════════════════════════
            _buildSubmitButton(isTablet),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════════════
            // INFO TEXT
            // ═══════════════════════════════════════════════════════
            _buildInfoText(),
          ],
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
      title: const Text('Request Service'),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SERVICE SUMMARY CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildServiceSummaryCard(bool isTablet) {
    final listing = widget.listing!;

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Service Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: listing.mainPhoto != null
                ? Image.network(
              listing.mainPhoto!,
              width: isTablet ? 80 : 64,
              height: isTablet ? 80 : 64,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage(isTablet);
              },
            )
                : _buildPlaceholderImage(isTablet),
          ),

          SizedBox(width: isTablet ? 16 : 12),

          // Service Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: (isTablet
                      ? AppTypography.titleLarge
                      : AppTypography.titleMedium)
                      .copyWith(
                    color: AppColors.primaryBlack,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${listing.provider?.fullName ?? "Provider"}',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlack.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    listing.priceDisplay,
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(bool isTablet) {
    return Container(
      width: isTablet ? 80 : 64,
      height: isTablet ? 80 : 64,
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.image_outlined,
        size: isTablet ? 32 : 24,
        color: AppColors.textLight,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DESCRIPTION FIELD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDescriptionField(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _descriptionController,
        maxLines: 5,
        maxLength: 1000,
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(
          labelText: 'Describe your need *',
          labelStyle: AppTypography.inputLabel,
          hintText: 'Please describe what you need help with...',
          hintStyle: AppTypography.inputHint,
          prefixIcon: const Padding(
            padding: EdgeInsets.only(bottom: 60),
            child: Icon(
              Icons.description_outlined,
              color: AppColors.primaryGold,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.backgroundWhite,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please describe your need';
          }
          if (value.trim().length < 20) {
            return 'Please provide at least 20 characters';
          }
          return null;
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PHOTO UPLOAD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildPhotoUpload(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primaryGold,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Add Photos (Optional)',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Upload up to 3 photos to help explain the problem',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Photo Grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Selected Images
              ..._selectedImages.asMap().entries.map((entry) {
                final index = entry.key;
                final image = entry.value;
                return _buildImagePreview(image, index, isTablet);
              }),

              // Add Button (if less than 3 images)
              if (_selectedImages.length < 3)
                _buildAddPhotoButton(isTablet),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(File image, int index, bool isTablet) {
    return Stack(
      children: [
        Container(
          width: isTablet ? 120 : 100,
          height: isTablet ? 120 : 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(image),
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Remove Button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton(bool isTablet) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: isTablet ? 120 : 100,
        height: isTablet ? 120 : 100,
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderLight,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: isTablet ? 32 : 28,
              color: AppColors.primaryGold,
            ),
            const SizedBox(height: 4),
            Text(
              'Add Photo',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // WHEN NEEDED SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildWhenNeeded(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: AppColors.primaryGold,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'When do you need this? *',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Timing Options
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTimingChip('ASAP', 'asap', Icons.bolt, isTablet),
              _buildTimingChip('Today', 'today', Icons.today, isTablet),
              _buildTimingChip('Tomorrow', 'tomorrow', Icons.event, isTablet),
              _buildTimingChip('Schedule', 'scheduled', Icons.calendar_month, isTablet),
            ],
          ),

          // Date/Time Picker (if scheduled)
          if (_selectedTiming == 'scheduled') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Select Date',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primaryGold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _selectedTime != null
                          ? _selectedTime!.format(context)
                          : 'Select Time',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primaryGold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimingChip(String label, String value, IconData icon, bool isTablet) {
    final isSelected = _selectedTiming == value;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isTablet ? 20 : 18,
            color: isSelected ? AppColors.primaryBlack : AppColors.textSecondary,
          ),
          SizedBox(width: isTablet ? 8 : 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTiming = value;
          if (value != 'scheduled') {
            _selectedDate = null;
            _selectedTime = null;
          }
        });
      },
      selectedColor: AppColors.primaryGold,
      backgroundColor: AppColors.backgroundLight,
      labelStyle: AppTypography.labelLarge.copyWith(
        fontWeight: FontWeight.w600,
        color: isSelected ? AppColors.primaryBlack : AppColors.textSecondary,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 16 : 12,
        vertical: isTablet ? 12 : 10,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LOCATION FIELD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildLocationField(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _locationController,
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(
          labelText: 'Service Location *',
          labelStyle: AppTypography.inputLabel,
          hintText: 'e.g., Akwa, Douala',
          hintStyle: AppTypography.inputHint,
          prefixIcon: const Icon(
            Icons.location_on_outlined,
            color: AppColors.primaryGold,
          ),
          suffixIcon: IconButton(
            onPressed: _useCurrentLocation,
            icon: const Icon(
              Icons.my_location,
              color: AppColors.primaryGold,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.backgroundWhite,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter service location';
          }
          return null;
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUDGET FIELD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildBudgetField(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _budgetController,
        keyboardType: TextInputType.number,
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(
          labelText: 'Your Budget (Optional)',
          labelStyle: AppTypography.inputLabel,
          hintText: 'e.g., 15000',
          hintStyle: AppTypography.inputHint,
          prefixIcon: const Icon(
            Icons.attach_money,
            color: AppColors.primaryGold,
          ),
          suffixText: 'FCFA',
          suffixStyle: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.backgroundWhite,
          contentPadding: const EdgeInsets.all(16),
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
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGold,
          foregroundColor: AppColors.primaryBlack,
          padding: EdgeInsets.symmetric(vertical: isTablet ? 20 : 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isSubmitting
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            color: AppColors.primaryBlack,
            strokeWidth: 2,
          ),
        )
            : Text(
          'Send Request',
          style: (isTablet
              ? AppTypography.buttonLarge
              : AppTypography.buttonMedium)
              .copyWith(
            color: AppColors.primaryBlack,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // INFO TEXT
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildInfoText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.info,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'The provider will review your request and respond within 24 hours. You can track the status in "My Bookings".',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.info,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGold,
              onPrimary: AppColors.primaryBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGold,
              onPrimary: AppColors.primaryBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _useCurrentLocation() {
    // TODO: Implement geolocation
    _showInfoSnackBar('Geolocation coming soon. Please enter manually.');
  }

  Future<void> _submitRequest() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate scheduled date/time
    if (_selectedTiming == 'scheduled') {
      if (_selectedDate == null || _selectedTime == null) {
        _showErrorSnackBar('Please select both date and time');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ServicesProvider>();

      // Prepare date/time strings
      String? scheduledDate;
      String? scheduledTime;

      if (_selectedTiming == 'scheduled' && _selectedDate != null && _selectedTime != null) {
        scheduledDate = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
        scheduledTime = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';
      }

      // Submit request
      final success = await provider.createRequest(
        listingId: widget.listing!.id,
        description: _descriptionController.text.trim(),
        neededWhen: _selectedTiming,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        serviceLocation: _locationController.text.trim(),
        photos: _selectedImages.isNotEmpty ? _selectedImages : null,
      );

      if (success && mounted) {
        // Show success dialog
        _showSuccessDialog();
      } else if (mounted) {
        _showErrorSnackBar(
          provider.requestsError ?? 'Failed to send request. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 64,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Request Sent!',
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.listing!.provider?.fullName ?? "The provider"} will review your request and respond soon.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to detail screen
                  // Navigate to My Bookings
                  Navigator.pushReplacementNamed(
                    context,
                    '/services/my-bookings',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: AppColors.primaryBlack,
                ),
                child: const Text('View My Bookings'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to detail screen
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
// lib/screens/services/dispute_filing_screen.dart
// WEGO Services Marketplace - Dispute Filing Screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/services/service_request_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class DisputeFilingScreen extends StatefulWidget {
  final ServiceRequest request;

  const DisputeFilingScreen({
    Key? key,
    required this.request,
  }) : super(key: key);

  @override
  State<DisputeFilingScreen> createState() => _DisputeFilingScreenState();
}

class _DisputeFilingScreenState extends State<DisputeFilingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _refundAmountController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _selectedDisputeType;
  String? _selectedResolution;
  final List<File> _evidencePhotos = [];
  bool _isSubmitting = false;

  // ─── Dispute types ────────────────────────────────────────────────
  final List<Map<String, dynamic>> _disputeTypes = [
    {
      'value': 'service_not_provided',
      'label': 'Service Not Provided',
      'description': 'Provider never showed up or did not perform the service',
      'icon': Icons.cancel_schedule_send_outlined,
    },
    {
      'value': 'poor_quality',
      'label': 'Poor Quality Work',
      'description': 'Service was performed but quality was unacceptable',
      'icon': Icons.thumb_down_outlined,
    },
    {
      'value': 'payment_dispute',
      'label': 'Payment Issue',
      'description': 'Charged more than agreed or payment not acknowledged',
      'icon': Icons.payment_outlined,
    },
    {
      'value': 'behavior',
      'label': 'Inappropriate Behavior',
      'description': 'Provider behaved inappropriately or unprofessionally',
      'icon': Icons.warning_amber_outlined,
    },
    {
      'value': 'fraud',
      'label': 'Fraud or Scam',
      'description': 'Provider was deceptive or fraudulent',
      'icon': Icons.gavel_outlined,
    },
    {
      'value': 'other',
      'label': 'Other',
      'description': 'Another issue not listed above',
      'icon': Icons.help_outline,
    },
  ];

  // ─── Resolution options ───────────────────────────────────────────
  final List<Map<String, dynamic>> _resolutionOptions = [
    {
      'value': 'full_refund',
      'label': 'Full Refund',
      'description': 'Get a full refund for this service',
      'icon': Icons.money_off,
    },
    {
      'value': 'partial_refund',
      'label': 'Partial Refund',
      'description': 'Get a partial refund for the issues',
      'icon': Icons.monetization_on_outlined,
    },
    {
      'value': 'redo_service',
      'label': 'Redo the Service',
      'description': 'Ask provider to redo the work correctly',
      'icon': Icons.replay,
    },
    {
      'value': 'report_only',
      'label': 'Report Only',
      'description': 'Report for review without financial claim',
      'icon': Icons.flag_outlined,
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _refundAmountController.dispose();
    super.dispose();
  }

  // ─── Pick evidence photo ──────────────────────────────────────────
  Future<void> _pickPhoto() async {
    if (_evidencePhotos.length >= 5) {
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
      setState(() => _evidencePhotos.add(File(image.path)));
    }
  }

  void _removePhoto(int index) {
    setState(() => _evidencePhotos.removeAt(index));
  }

  // ─── Submit dispute ───────────────────────────────────────────────
  Future<void> _submitDispute() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDisputeType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select what went wrong'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedResolution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your desired resolution'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ServicesProvider>();

      double? refundAmount;
      if (_selectedResolution == 'partial_refund' &&
          _refundAmountController.text.isNotEmpty) {
        refundAmount = double.tryParse(_refundAmountController.text.trim());
      } else if (_selectedResolution == 'full_refund' &&
          widget.request.finalAmount != null) {
        refundAmount = widget.request.finalAmount;
      }

      final success = await provider.fileDispute(
        requestId: widget.request.id,
        disputeType: _selectedDisputeType!,
        description: _descriptionController.text.trim(),
        resolutionRequested: _selectedResolution!,
        refundAmount: refundAmount,
        evidencePhotos: _evidencePhotos.isNotEmpty ? _evidencePhotos : null,
      );

      if (mounted) {
        if (success) {
          _showSuccessDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.disputesError ?? 'Failed to file dispute',
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Dispute Filed!',
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your dispute has been submitted. Our team will review it within 24 hours and contact both parties.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
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
                      'Keep all communication records until resolved.',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Back to previous screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.primaryBlack,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
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
              // Warning banner
              _buildWarningBanner(isTablet),

              const SizedBox(height: 24),

              // Service info card
              _buildServiceInfoCard(isTablet),

              const SizedBox(height: 24),

              // Step 1 - What went wrong
              _buildSectionHeader(
                '1',
                'What went wrong?',
                'Select the type of issue',
              ),
              const SizedBox(height: 12),
              _buildDisputeTypeSelector(isTablet),

              const SizedBox(height: 24),

              // Step 2 - Description
              _buildSectionHeader(
                '2',
                'Describe the problem',
                'Minimum 50 characters',
              ),
              const SizedBox(height: 12),
              _buildDescriptionField(isTablet),

              const SizedBox(height: 24),

              // Step 3 - Evidence photos
              _buildSectionHeader(
                '3',
                'Add evidence (optional)',
                'Up to 5 photos',
              ),
              const SizedBox(height: 12),
              _buildEvidencePhotos(isTablet),

              const SizedBox(height: 24),

              // Step 4 - Desired resolution
              _buildSectionHeader(
                '4',
                'What resolution do you want?',
                'Select your preferred outcome',
              ),
              const SizedBox(height: 12),
              _buildResolutionSelector(isTablet),

              // Refund amount field (only for partial refund)
              if (_selectedResolution == 'partial_refund') ...[
                const SizedBox(height: 16),
                _buildRefundAmountField(isTablet),
              ],

              const SizedBox(height: 32),

              // Submit button
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
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
      ),
      title: Text(
        'File a Dispute',
        style: AppTypography.titleLarge.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // WARNING BANNER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildWarningBanner(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Before filing a dispute',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We recommend trying to resolve the issue directly with the provider first. Disputes are reviewed by our team within 24-48 hours.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warning,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SERVICE INFO CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildServiceInfoCard(bool isTablet) {
    String providerName = 'Provider';
    String serviceTitle = 'Service';

    if (widget.request.listing != null) {
      final listingMap = widget.request.listing as Map<String, dynamic>;
      serviceTitle = listingMap['title']?.toString() ?? 'Service';
      if (listingMap['provider'] != null) {
        final providerMap = listingMap['provider'] as Map<String, dynamic>;
        providerName = providerMap['full_name']?.toString() ??
            providerMap['first_name']?.toString() ??
            'Provider';
      }
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dispute for:',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.gavel,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceTitle,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Provider: $providerName',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.request.finalAmount != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Amount',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${widget.request.finalAmount!.toStringAsFixed(0)} FCFA',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSectionHeader(
      String step, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: AppColors.primaryGold,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DISPUTE TYPE SELECTOR
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDisputeTypeSelector(bool isTablet) {
    return Column(
      children: _disputeTypes.map((type) {
        final isSelected = _selectedDisputeType == type['value'];

        return GestureDetector(
          onTap: () => setState(() => _selectedDisputeType = type['value']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(isTablet ? 16 : 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryDark
                  : AppColors.backgroundWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryGold
                    : AppColors.borderLight,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: AppColors.primaryGold.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGold.withOpacity(0.15)
                        : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    type['icon'] as IconData,
                    size: 20,
                    color: isSelected
                        ? AppColors.primaryGold
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type['label'] as String,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.backgroundWhite
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        type['description'] as String,
                        style: AppTypography.bodySmall.copyWith(
                          color: isSelected
                              ? AppColors.backgroundWhite.withOpacity(0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primaryGold,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
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
        border: Border.all(color: AppColors.borderLight),
      ),
      child: TextFormField(
        controller: _descriptionController,
        maxLines: 6,
        maxLength: 2000,
        style: AppTypography.bodyMedium,
        decoration: InputDecoration(
          hintText:
          'Describe the problem in detail. Include what happened, when it happened, and how it affected you...',
          hintStyle: AppTypography.inputHint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          counterStyle: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please describe the problem';
          }
          if (value.trim().length < 50) {
            return 'Please provide at least 50 characters (${value.trim().length}/50)';
          }
          return null;
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // EVIDENCE PHOTOS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildEvidencePhotos(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo grid
        if (_evidencePhotos.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _evidencePhotos.length + 1,
              itemBuilder: (context, index) {
                if (index == _evidencePhotos.length) {
                  // Add more button
                  if (_evidencePhotos.length < 5) {
                    return _buildAddPhotoButton();
                  }
                  return const SizedBox.shrink();
                }

                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _evidencePhotos[index],
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
                        onTap: () => _removePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ] else ...[
          _buildAddPhotoButton(full: true),
        ],

        const SizedBox(height: 8),
        Text(
          '${_evidencePhotos.length}/5 photos added',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton({bool full = false}) {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: full ? double.infinity : 100,
        height: full ? 80 : 100,
        margin: full ? EdgeInsets.zero : const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primaryGold.withOpacity(0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.primaryGold,
              size: full ? 28 : 24,
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
  // RESOLUTION SELECTOR
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildResolutionSelector(bool isTablet) {
    return Column(
      children: _resolutionOptions.map((option) {
        final isSelected = _selectedResolution == option['value'];

        // Hide full refund if no final amount
        if (option['value'] == 'full_refund' &&
            widget.request.finalAmount == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => setState(() => _selectedResolution = option['value']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(isTablet ? 16 : 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGold.withOpacity(0.08)
                  : AppColors.backgroundWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryGold
                    : AppColors.borderLight,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGold.withOpacity(0.15)
                        : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    option['icon'] as IconData,
                    size: 20,
                    color: isSelected
                        ? AppColors.primaryGold
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            option['label'] as String,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : AppColors.textPrimary,
                            ),
                          ),
                          // Show amount for full refund
                          if (option['value'] == 'full_refund' &&
                              widget.request.finalAmount != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${widget.request.finalAmount!.toStringAsFixed(0)} FCFA',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primaryGold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option['description'] as String,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primaryGold,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // REFUND AMOUNT FIELD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildRefundAmountField(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How much refund are you requesting?',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: TextFormField(
            controller: _refundAmountController,
            keyboardType: TextInputType.number,
            style: AppTypography.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Enter amount in FCFA',
              hintStyle: AppTypography.inputHint,
              prefixIcon: const Icon(
                Icons.payments_outlined,
                color: AppColors.textSecondary,
              ),
              suffixText: 'FCFA',
              suffixStyle: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (_selectedResolution == 'partial_refund') {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter refund amount';
                }
                final amount = double.tryParse(value.trim());
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                if (widget.request.finalAmount != null &&
                    amount > widget.request.finalAmount!) {
                  return 'Cannot exceed total amount of ${widget.request.finalAmount!.toStringAsFixed(0)} FCFA';
                }
              }
              return null;
            },
          ),
        ),
        if (widget.request.finalAmount != null) ...[
          const SizedBox(height: 6),
          Text(
            'Total service amount: ${widget.request.finalAmount!.toStringAsFixed(0)} FCFA',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SUBMIT BUTTON
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSubmitButton(bool isTablet) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitDispute,
        icon: _isSubmitting
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryBlack,
          ),
        )
            : const Icon(Icons.gavel),
        label: Text(
          _isSubmitting ? 'Submitting...' : 'Submit Dispute',
          style: AppTypography.buttonLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
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
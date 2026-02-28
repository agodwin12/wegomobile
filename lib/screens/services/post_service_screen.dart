
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../models/services/category_model.dart';
import '../../providers/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';


class PostServiceScreen extends StatefulWidget {
  const PostServiceScreen({Key? key}) : super(key: key);

  @override
  State<PostServiceScreen> createState() => _PostServiceScreenState();
}

class _PostServiceScreenState extends State<PostServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _minChargeController = TextEditingController();
  final _experienceController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  List<File> _selectedImages = [];

  // Form state
  ServiceCategory? _selectedParentCategory;
  ServiceCategory? _selectedSubcategory;
  String _pricingType = 'hourly'; // hourly, fixed, negotiable
  String _selectedCity = 'Douala';
  List<String> _selectedNeighborhoods = [];
  bool _emergencyService = false;
  bool _isSubmitting = false;
  bool _isLoadingCategories = true;

  // Cities in Cameroon
  final List<String> _cities = [
    'Douala',
    'Yaoundé',
    'Bafoussam',
    'Bamenda',
    'Garoua',
    'Maroua',
    'Ngaoundéré',
    'Bertoua',
    'Kribi',
    'Limbe',
  ];

  // Neighborhoods per city (simplified)
  final Map<String, List<String>> _neighborhoodsByCity = {
    'Douala': ['Akwa', 'Bonanjo', 'Bassa', 'Bonabéri', 'Deido', 'Makepe', 'PK8', 'Logbaba'],
    'Yaoundé': ['Centre-Ville', 'Bastos', 'Mimboman', 'Nsam', 'Emana', 'Essos', 'Nlongkak'],
    'Bafoussam': ['Centre', 'Famla', 'Tamdja', 'Tougang'],
    'Bamenda': ['Commercial Avenue', 'Mile 3', 'Nkwen', 'Up Station'],
    'Garoua': ['Centre', 'Doualaré', 'Roumde Adjia'],
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _minChargeController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);

    final provider = context.read<ServicesProvider>();
    await provider.fetchParentCategories();

    if (mounted) {
      setState(() => _isLoadingCategories = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: _isLoadingCategories
          ? _buildLoadingState()
          : Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          children: [
            // Header
            _buildHeader(isTablet),

            const SizedBox(height: 24),

            // Category Selection
            _buildCategorySection(isTablet),

            const SizedBox(height: 24),

            // Service Details
            _buildServiceDetailsSection(isTablet),

            const SizedBox(height: 24),

            // Pricing
            _buildPricingSection(isTablet),

            const SizedBox(height: 24),

            // Photos
            _buildPhotosSection(isTablet),

            const SizedBox(height: 24),

            // Location
            _buildLocationSection(isTablet),

            const SizedBox(height: 24),

            // Additional Info
            _buildAdditionalInfoSection(isTablet),

            const SizedBox(height: 32),

            // Submit Button
            _buildSubmitButton(isTablet),

            const SizedBox(height: 24),

            // Info Text
            _buildInfoText(),

            const SizedBox(height: 32),
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
      title: const Text('Post a Service'),
      leading: IconButton(
        onPressed: () => _handleBackPress(),
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }

  void _handleBackPress() {
    if (_hasUnsavedChanges()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Discard Changes?'),
          content: const Text('You have unsaved changes. Are you sure you want to leave?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close screen
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  bool _hasUnsavedChanges() {
    return _titleController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty ||
        _selectedImages.isNotEmpty ||
        _selectedParentCategory != null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildHeader(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryBlack.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.add_business_rounded,
              size: isTablet ? 40 : 32,
              color: AppColors.primaryBlack,
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offer Your Service',
                  style: (isTablet
                      ? AppTypography.headlineMedium
                      : AppTypography.titleLarge)
                      .copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fill in the details below',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primaryDark,
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
  // CATEGORY SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildCategorySection(bool isTablet) {
    return Consumer<ServicesProvider>(
      builder: (context, provider, child) {
        final parentCategories = provider.parentCategories ?? [];

        return Container(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.category_rounded,
                    color: AppColors.primaryGold,
                    size: isTablet ? 28 : 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Category',
                    style: (isTablet
                        ? AppTypography.titleLarge
                        : AppTypography.titleMedium)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Text(' *', style: TextStyle(color: AppColors.error)),
                ],
              ),
              const SizedBox(height: 16),

              // Parent Category Dropdown
              DropdownButtonFormField<ServiceCategory>(
                value: _selectedParentCategory,
                decoration: InputDecoration(
                  labelText: 'Select Category',
                  hintText: 'Choose a category',
                  prefixIcon: const Icon(Icons.grid_view_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: parentCategories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.nameEn),
                  );
                }).toList(),
                onChanged: (value) async {
                  setState(() {
                    _selectedParentCategory = value;
                    _selectedSubcategory = null;
                  });

                  if (value != null) {
                    await provider.fetchSubcategories(value.id);
                  }
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),

              // Subcategory Dropdown (if parent selected)
              if (_selectedParentCategory != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<ServiceCategory>(
                  value: _selectedSubcategory,
                  decoration: InputDecoration(
                    labelText: 'Select Subcategory',
                    hintText: 'Choose a subcategory',
                    prefixIcon: const Icon(Icons.subdirectory_arrow_right),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: (provider.subcategories ?? []).map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.nameEn),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedSubcategory = value);
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a subcategory';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SERVICE DETAILS SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildServiceDetailsSection(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_rounded,
                color: AppColors.primaryGold,
                size: isTablet ? 28 : 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Service Details',
                style: (isTablet
                    ? AppTypography.titleLarge
                    : AppTypography.titleMedium)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Title
          TextFormField(
            controller: _titleController,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'Service Title *',
              hintText: 'e.g., Professional Plumber - 24/7 Emergency',
              prefixIcon: const Icon(Icons.title_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              counterText: '${_titleController.text.length}/200',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a service title';
              }
              if (value.trim().length < 5) {
                return 'Title must be at least 5 characters';
              }
              return null;
            },
            onChanged: (value) => setState(() {}),
          ),

          const SizedBox(height: 20),

          // Description
          TextFormField(
            controller: _descriptionController,
            maxLines: 6,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: 'Description *',
              hintText: 'Describe your service, experience, and what makes you unique...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              counterText: '${_descriptionController.text.length}/2000',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              if (value.trim().length < 5) {
                return 'Description must be at least 5 characters';
              }
              return null;
            },
            onChanged: (value) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRICING SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildPricingSection(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payments_rounded,
                color: AppColors.primaryGold,
                size: isTablet ? 28 : 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Pricing',
                style: (isTablet
                    ? AppTypography.titleLarge
                    : AppTypography.titleMedium)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const Text(' *', style: TextStyle(color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 20),

          // Pricing Type
          Text(
            'Pricing Type',
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildPricingTypeChip('Hourly Rate', 'hourly', Icons.access_time),
              _buildPricingTypeChip('Fixed Price', 'fixed', Icons.attach_money),
              _buildPricingTypeChip('Negotiable', 'negotiable', Icons.handshake),
            ],
          ),

          const SizedBox(height: 20),

          // Price Fields
          if (_pricingType == 'hourly') ...[
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Hourly Rate (FCFA) *',
                hintText: 'e.g., 5000',
                prefixIcon: const Icon(Icons.money),
                suffixText: 'FCFA/hour',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter hourly rate';
                }
                final price = int.tryParse(value);
                if (price == null || price < 500) {
                  return 'Minimum rate is 500 FCFA';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minChargeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minimum Charge (FCFA)',
                hintText: 'e.g., 10000',
                prefixIcon: const Icon(Icons.money_off),
                suffixText: 'FCFA',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ] else if (_pricingType == 'fixed') ...[
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Fixed Price (FCFA) *',
                hintText: 'e.g., 25000',
                prefixIcon: const Icon(Icons.money),
                suffixText: 'FCFA',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter fixed price';
                }
                final price = int.tryParse(value);
                if (price == null || price < 500) {
                  return 'Minimum price is 500 FCFA';
                }
                return null;
              },
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Price will be discussed with customer',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPricingTypeChip(String label, String value, IconData icon) {
    final isSelected = _pricingType == value;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? AppColors.primaryBlack : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _pricingType = value;
          if (value == 'negotiable') {
            _priceController.clear();
            _minChargeController.clear();
          }
        });
      },
      selectedColor: AppColors.primaryGold,
      backgroundColor: AppColors.backgroundLight,
      labelStyle: AppTypography.labelLarge.copyWith(
        fontWeight: FontWeight.w600,
        color: isSelected ? AppColors.primaryBlack : AppColors.textSecondary,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PHOTOS SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildPhotosSection(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_library_rounded,
                color: AppColors.primaryGold,
                size: isTablet ? 28 : 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Photos',
                style: (isTablet
                    ? AppTypography.titleLarge
                    : AppTypography.titleMedium)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${_selectedImages.length}/5',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add up to 5 photos (Optional but recommended)',
            style: AppTypography.bodyMedium.copyWith(
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

              // Add Button
              if (_selectedImages.length < 5)
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
            color: AppColors.primaryGold.withOpacity(0.5),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_rounded,
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
  // LOCATION SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildLocationSection(bool isTablet) {
    final availableNeighborhoods = _neighborhoodsByCity[_selectedCity] ?? [];

    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: AppColors.primaryGold,
                size: isTablet ? 28 : 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Service Location',
                style: (isTablet
                    ? AppTypography.titleLarge
                    : AppTypography.titleMedium)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const Text(' *', style: TextStyle(color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 20),

          // City Dropdown
          DropdownButtonFormField<String>(
            value: _selectedCity,
            decoration: InputDecoration(
              labelText: 'City',
              prefixIcon: const Icon(Icons.location_city_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _cities.map((city) {
              return DropdownMenuItem(
                value: city,
                child: Text(city),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCity = value!;
                _selectedNeighborhoods.clear();
              });
            },
          ),

          const SizedBox(height: 20),

          // Neighborhoods
          Text(
            'Service Areas (Select at least one)',
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableNeighborhoods.map((neighborhood) {
              final isSelected = _selectedNeighborhoods.contains(neighborhood);
              return FilterChip(
                label: Text(neighborhood),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedNeighborhoods.add(neighborhood);
                    } else {
                      _selectedNeighborhoods.remove(neighborhood);
                    }
                  });
                },
                selectedColor: AppColors.primaryGold,
                backgroundColor: AppColors.backgroundLight,
                labelStyle: AppTypography.labelMedium.copyWith(
                  color: isSelected
                      ? AppColors.primaryBlack
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),

          if (_selectedNeighborhoods.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Please select at least one service area',
              style: AppTypography.caption.copyWith(
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ADDITIONAL INFO SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildAdditionalInfoSection(bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primaryGold,
                size: isTablet ? 28 : 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Additional Information',
                style: (isTablet
                    ? AppTypography.titleLarge
                    : AppTypography.titleMedium)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Years of Experience
          TextFormField(
            controller: _experienceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Years of Experience (Optional)',
              hintText: 'e.g., 5',
              prefixIcon: const Icon(Icons.work_outline_rounded),
              suffixText: 'years',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Emergency Service Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _emergencyService
                  ? AppColors.errorLight
                  : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _emergencyService
                    ? AppColors.error.withOpacity(0.3)
                    : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emergency_rounded,
                  color: _emergencyService ? AppColors.error : AppColors.textSecondary,
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
                      Text(
                        'Available for urgent requests',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _emergencyService,
                  onChanged: (value) {
                    setState(() => _emergencyService = value);
                  },
                  activeColor: AppColors.error,
                ),
              ],
            ),
          ),
        ],
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
        onPressed: _isSubmitting ? null : _submitListing,
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
          'Submit for Approval',
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
              'Your listing will be reviewed by our team within 24 hours. You\'ll receive a notification once approved.',
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
  // LOADING STATE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(
                color: AppColors.primaryBlack,
                strokeWidth: 4,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Loading categories...',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
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

  Future<void> _submitListing() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill in all required fields');
      return;
    }

    // Validate neighborhoods
    if (_selectedNeighborhoods.isEmpty) {
      _showErrorSnackBar('Please select at least one service area');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<ServicesProvider>();

      // Prepare pricing data
      int? price;
      int? minCharge;

      if (_pricingType != 'negotiable') {
        price = int.tryParse(_priceController.text.trim());
        if (_pricingType == 'hourly') {
          minCharge = int.tryParse(_minChargeController.text.trim());
        }
      }

      // Create listing
      final success = await provider.createListing(
        categoryId: _selectedSubcategory!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        pricingType: _pricingType,
        price: price,
        minCharge: minCharge,
        city: _selectedCity,
        neighborhoods: _selectedNeighborhoods,
        emergencyService: _emergencyService,
        photos: _selectedImages.isNotEmpty ? _selectedImages : null,
      );

      if (success && mounted) {
        _showSuccessDialog();
      } else if (mounted) {
        _showErrorSnackBar(
          provider.listingsError ?? 'Failed to create listing. Please try again.',
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
              'Listing Submitted!',
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your service listing has been submitted for review. We\'ll notify you once approved!',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to previous screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: AppColors.primaryBlack,
                ),
                child: const Text('Done'),
              ),
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
}
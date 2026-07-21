// lib/presentation/screens/passenger/delivery/steps/delivery_step2_package.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../l10n/tr.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../../../utils/app_colors.dart';
import '../../../../../utils/app_typography.dart';
import '../../../../../core/config.dart';
import 'delivery_confirm.dart';

// ─────────────────────────────────────────────────────────────────────────────

class _Category {
  final String value;
  final String label;
  final String emoji;
  _Category({required this.value, required this.label, required this.emoji});
  factory _Category.fromJson(Map<String, dynamic> j) => _Category(
    value: j['value'] ?? '',
    label: j['label'] ?? '',
    emoji: j['emoji'] ?? '📦',
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class DeliveryStep2Package extends StatefulWidget {
  final String deliveryType;
  final String accessToken;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final String pickupLandmark;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffAddress;
  final String dropoffLandmark;

  const DeliveryStep2Package({
    super.key,
    required this.deliveryType,
    required this.accessToken,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.pickupLandmark,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.dropoffAddress,
    required this.dropoffLandmark,
  });

  @override
  State<DeliveryStep2Package> createState() => _DeliveryStep2PackageState();
}

class _DeliveryStep2PackageState extends State<DeliveryStep2Package>
    with SingleTickerProviderStateMixin {

  String  _packageSize     = 'small';
  String? _packageCategory;
  bool    _isFragile       = false;
  File?   _packagePhoto;
  String? _packagePhotoUrl;
  final   _descCtrl = TextEditingController();

  List<_Category> _categories    = [];
  bool            _loadingCats   = true;
  bool            _uploadingPhoto = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  bool get _isExpress  => widget.deliveryType == 'express';
  bool get _canProceed => _packageCategory != null && _packagePhotoUrl != null;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadCategories();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CATEGORIES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadCategories() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/categories'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body)['categories'] as List)
            .map((e) => _Category.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() { _categories = list; _loadingCats = false; });
        return;
      }
    } catch (_) {}
    // Hardcoded fallback
    if (mounted) setState(() {
      _categories = [
        _Category(value: 'document',    label: tr('pkg.document'),    emoji: '📄'),
        _Category(value: 'food',        label: tr('pkg.food'),        emoji: '🍱'),
        _Category(value: 'electronics', label: tr('pkg.electronics'), emoji: '📱'),
        _Category(value: 'clothing',    label: tr('pkg.clothing'),    emoji: '👕'),
        _Category(value: 'medicine',    label: tr('pkg.medicine'),    emoji: '💊'),
        _Category(value: 'fragile',     label: tr('pkg.fragile'),     emoji: '🏺'),
        _Category(value: 'groceries',   label: tr('pkg.groceries'),   emoji: '🛒'),
        _Category(value: 'other',       label: tr('pkg.other'),       emoji: '📦'),
      ];
      _loadingCats = false;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHOTO UPLOAD — fixed for Android NullPointerException
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();

      // Use try/catch around the pick call specifically —
      // the NullPointerException in Android happens when the activity
      // result bundle is null (killed in background). Catching it here
      // prevents the unhandled exception crash.
      XFile? picked;
      try {
        picked = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 80,
          requestFullMetadata: false, // ← reduces Android bundle issues
        );
      } catch (pickError) {
        debugPrint('Image picker error: $pickError');
        if (mounted) _showError('Could not open gallery. Please try again.');
        return;
      }

      if (picked == null) return; // user cancelled

      final file = File(picked.path);
      if (!await file.exists()) {
        if (mounted) _showError('Selected file not found. Please try again.');
        return;
      }

      setState(() {
        _packagePhoto   = file;
        _uploadingPhoto = true;
      });

      // Upload to /api/upload/package-photo
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiBaseUrl}/upload/package-photo'),
      )
        ..headers['Authorization'] = 'Bearer ${widget.accessToken}'
        ..files.add(await http.MultipartFile.fromPath(
          'image', // field name multer expects
          file.path,
        ));

      final streamed  = await request.send().timeout(const Duration(seconds: 30));
      final response  = await http.Response.fromStream(streamed);
      final body      = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final url = body['url'] as String?;
        if (url != null && mounted) {
          setState(() { _packagePhotoUrl = url; _uploadingPhoto = false; });
          return;
        }
      }

      final msg = body['message'] as String? ?? 'Upload failed';
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        _showError(msg);
      }

    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        _showError('Upload failed. Check your connection.');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────

  void _next() {
    if (!_canProceed) {
      _showError(_packageCategory == null
          ? 'Select what you are sending'
          : 'Upload a photo of your package');
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DeliveryStep3Confirm(
        deliveryType:    widget.deliveryType,
        accessToken:     widget.accessToken,
        pickupLat:       widget.pickupLat,
        pickupLng:       widget.pickupLng,
        pickupAddress:   widget.pickupAddress,
        pickupLandmark:  widget.pickupLandmark,
        dropoffLat:      widget.dropoffLat,
        dropoffLng:      widget.dropoffLng,
        dropoffAddress:  widget.dropoffAddress,
        dropoffLandmark: widget.dropoffLandmark,
        packageSize:     _packageSize,
        packageCategory: _packageCategory!,
        packagePhotoUrl: _packagePhotoUrl!,
        isFragile:       _isFragile,
        description:     _descCtrl.text.trim(),
      ),
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fade,
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSizeSection(),
                    const SizedBox(height: 18),
                    _buildCategorySection(),
                    const SizedBox(height: 18),
                    _buildPhotoSection(),
                    const SizedBox(height: 18),
                    _buildFragileSection(),
                    const SizedBox(height: 18),
                    _buildDescSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            _buildNextBar(),
          ],
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _isExpress ? AppColors.primaryDark : Colors.white,
      foregroundColor: _isExpress ? Colors.white : AppColors.textPrimary,
      elevation: 0,
      title: Text(
        _isExpress ? '⚡ Express Delivery' : '📦 Regular Delivery',
        style: TextStyle(
          fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w800,
          color: _isExpress ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }

  // ── Step indicator ─────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: List.generate(3, (i) {
          final step   = i + 1;
          final done   = step < 2;
          final active = step == 2;
          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: done ? AppColors.success
                        : active ? AppColors.primaryDark
                        : AppColors.borderLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : Text('$step', style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.textLight)),
                  ),
                ),
                const SizedBox(width: 6),
                Text(['Location', 'Package', 'Confirm'][i],
                    style: TextStyle(
                      fontFamily: 'Roboto', fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? AppColors.textPrimary : AppColors.textLight,
                    )),
                if (i < 2) ...[
                  const SizedBox(width: 6),
                  Expanded(child: Container(
                      height: 1,
                      color: done ? AppColors.success : AppColors.borderLight)),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Size section ───────────────────────────────────────────────────────────

  Widget _buildSizeSection() {
    return _card(
      title: 'Package size',
      child: Row(
        children: [
          _sizeCard('small',  'Small',  '< 1 kg',  '🟢'),
          const SizedBox(width: 10),
          _sizeCard('medium', 'Medium', '1–5 kg',  '🟡'),
          const SizedBox(width: 10),
          _sizeCard('large',  'Large',  '> 5 kg',  '🔴'),
        ],
      ),
    );
  }

  Widget _sizeCard(String value, String label, String weight, String dot) {
    final selected = _packageSize == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _packageSize = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryDark : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primaryDark : AppColors.borderLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(dot, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(weight, style: TextStyle(
                  fontFamily: 'Roboto', fontSize: 10,
                  color: selected ? Colors.white.withOpacity(0.6) : AppColors.textLight)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Category grid ──────────────────────────────────────────────────────────

  Widget _buildCategorySection() {
    return _card(
      title: tr('pkg.whatSending'),
      child: _loadingCats
          ? const Center(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primaryDark)))
          : GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat      = _categories[i];
          final selected = _packageCategory == cat.value;
          return GestureDetector(
            onTap: () => setState(() => _packageCategory = cat.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryDark : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primaryGold : AppColors.borderLight,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 5),
                  Text(cat.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Roboto', fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Photo section ──────────────────────────────────────────────────────────

  Widget _buildPhotoSection() {
    return _card(
      title: 'Package photo *',
      subtitle: 'Helps the driver identify your package',
      child: _packagePhotoUrl != null
          ? _buildPhotoSuccess()
          : _buildPhotoUploader(),
    );
  }

  Widget _buildPhotoSuccess() {
    return Row(
      children: [
        if (_packagePhoto != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(_packagePhoto!,
                width: 64, height: 64, fit: BoxFit.cover),
          ),
        if (_packagePhoto != null) const SizedBox(width: 12),
        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Photo uploaded ✓',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                      fontWeight: FontWeight.w600, color: AppColors.success)),
              Text(tr('pkg.driverWillSee'),
                  style: TextStyle(fontFamily: 'Roboto', fontSize: 11,
                      color: AppColors.textSecondary)),
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            _packagePhoto = null; _packagePhotoUrl = null;
          }),
          child: Text(tr('pkg.retake'),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildPhotoUploader() {
    return GestureDetector(
      onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderMedium),
        ),
        child: _uploadingPhoto
            ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryDark)),
              SizedBox(height: 8),
              Text(tr('pkg.uploading'), style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
            ])
            : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 30, color: AppColors.textLight),
              const SizedBox(height: 8),
              Text('Tap to add package photo',
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary, fontSize: 13)),
              Text('JPG · PNG · WEBP · max 5 MB',
                  style: AppTypography.caption.copyWith(fontSize: 10)),
            ]),
      ),
    );
  }

  // ── Fragile toggle ─────────────────────────────────────────────────────────

  Widget _buildFragileSection() {
    return GestureDetector(
      onTap: () => setState(() => _isFragile = !_isFragile),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isFragile ? AppColors.warningLight : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _isFragile
                  ? AppColors.warning.withOpacity(0.4)
                  : AppColors.borderLight),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Text('🏺', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fragile package',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700,
                          color: _isFragile ? AppColors.warning : AppColors.textPrimary)),
                  Text(tr('pkg.extraCare'),
                      style: AppTypography.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50, height: 28,
              decoration: BoxDecoration(
                color: _isFragile ? AppColors.warning : AppColors.borderMedium,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _isFragile ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24, height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.1), blurRadius: 3)]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Description ────────────────────────────────────────────────────────────

  Widget _buildDescSection() {
    return _card(
      title: tr('pkg.description'),
      subtitle: tr('pkg.descriptionSub'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: TextField(
          controller: _descCtrl,
          maxLines: 3,
          style: AppTypography.inputText.copyWith(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. "Handle with care — glass inside"',
            hintStyle: AppTypography.inputHint.copyWith(fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ),
    );
  }

  // ── Next bar ───────────────────────────────────────────────────────────────

  Widget _buildNextBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton(
          onPressed: _canProceed ? _next : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isExpress ? AppColors.primaryGold : AppColors.primaryDark,
            foregroundColor: _isExpress ? AppColors.primaryDark : Colors.white,
            disabledBackgroundColor: AppColors.buttonDisabled,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  _canProceed
                      ? 'Next — Review & Confirm'
                      : _packageCategory == null
                      ? 'Select what you are sending'
                      : 'Upload a photo to continue',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14,
                      fontWeight: FontWeight.w700)),
              if (_canProceed) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _card({required String title, String? subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
              fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle, style: AppTypography.caption.copyWith(fontSize: 11)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
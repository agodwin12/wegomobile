// lib/screens/profile/change_avatar_screen.dart
// WEGO - Change Avatar Screen
// Allows users to upload, view, and delete their profile picture

import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // ✅ ADDED
import '../../providers/profile_provider.dart';
import '../../models/user_profile_model.dart';

class ChangeAvatarScreen extends StatefulWidget {
  const ChangeAvatarScreen({Key? key}) : super(key: key);

  @override
  State<ChangeAvatarScreen> createState() => _ChangeAvatarScreenState();
}

class _ChangeAvatarScreenState extends State<ChangeAvatarScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile Picture',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          final profile = provider.profile;

          return Column(
            children: [
              Expanded(
                child: Center(
                  child: _buildAvatarPreview(profile),
                ),
              ),
              _buildActionButtons(provider, profile),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // AVATAR PREVIEW
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAvatarPreview(UserProfile? profile) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar Display
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFDC71),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFDC71).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 120,
                  backgroundColor: const Color(0xFFFFDC71),
                  child: _buildAvatarContent(profile),
                ),
              ),
              // Zoom Button (only if image exists)
              if (_selectedImage != null || profile?.avatarUrl != null)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => _showFullScreenImage(profile),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFDC71), width: 2),
                      ),
                      child: const Icon(
                        Icons.zoom_in,
                        color: Color(0xFFFFDC71),
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // User Name
          if (profile != null) ...[
            Text(
              profile.fullName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              profile.email,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarContent(UserProfile? profile) {
    if (_isProcessing) {
      return const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        strokeWidth: 3,
      );
    }

    if (_selectedImage != null) {
      return ClipOval(
        child: Image.file(
          _selectedImage!,
          width: 240,
          height: 240,
          fit: BoxFit.cover,
        ),
      );
    }

    if (profile?.avatarUrl != null) {
      return ClipOval(
        child: Image.network(
          profile!.avatarUrl!,
          width: 240,
          height: 240,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Text(
            profile.getInitials(),
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      );
    }

    // Default initials
    return Text(
      profile?.getInitials() ?? '?',
      style: const TextStyle(
        fontSize: 64,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTION BUTTONS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildActionButtons(ProfileProvider provider, UserProfile? profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Upload New Photo Button
            if (_selectedImage == null)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: provider.isUpdating ? null : _showImageSourceDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFDC71),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.camera_alt, size: 24),
                  label: Text(
                    'Upload New Photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Save & Cancel buttons (when image is selected)
            if (_selectedImage != null) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: provider.isUpdating ? null : _saveAvatar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFDC71),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: provider.isUpdating
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                      : const Icon(Icons.check, size: 24),
                  label: Text(
                    provider.isUpdating ? 'Uploading...' : 'Save Photo',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: provider.isUpdating ? null : _cancelSelection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 24),
                  label: Text(
                    tr('common.cancel'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            // Delete Photo Button (only if avatar exists and no new image selected)
            if (profile?.avatarUrl != null && _selectedImage == null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: provider.isUpdating ? null : _showDeleteDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.delete, size: 24),
                  label: Text(
                    tr('avatar.removePhoto'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // IMAGE SOURCE DIALOG
  // ═══════════════════════════════════════════════════════════════════

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Photo Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDC71).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFFFFDC71),
                  ),
                ),
                title: Text(
                  'Camera',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Take a new photo',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDC71).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: Color(0xFFFFDC71),
                  ),
                ),
                title: Text(
                  'Gallery',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Choose from your photos',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    tr('common.cancel'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // IMAGE PICKER & CROPPER
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isProcessing = true);

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        setState(() => _isProcessing = false);
        return;
      }

      // Crop the image
      final croppedFile = await _cropImage(File(image.path));

      if (croppedFile != null) {
        setState(() {
          _selectedImage = croppedFile;
          _isProcessing = false;
        });
      } else {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 90,
        maxWidth: 800,
        maxHeight: 800,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: tr('avatar.crop'),
            toolbarColor: Colors.black,
            toolbarWidgetColor: const Color(0xFFFFDC71),
            backgroundColor: Colors.black,
            activeControlsWidgetColor: const Color(0xFFFFDC71),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: tr('avatar.crop'),
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      }
      return null;
    } catch (e) {
      print('❌ Error cropping image: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // SAVE AVATAR
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _saveAvatar() async {
    if (_selectedImage == null) return;

    final provider = context.read<ProfileProvider>();
    final success = await provider.updateAvatar(_selectedImage!);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Profile picture updated'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() => _selectedImage = null);

      // Wait a moment then go back
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pop(context);
      }
    } else if (mounted) {
      _showErrorSnackBar(provider.error ?? 'Failed to update avatar');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // DELETE AVATAR
  // ═══════════════════════════════════════════════════════════════════

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('avatar.removePhoto')),
        content: Text(
          'Are you sure you want to remove your profile picture?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAvatar();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(tr('common.remove')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAvatar() async {
    final provider = context.read<ProfileProvider>();
    final success = await provider.deleteAvatar();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Profile picture removed'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      _showErrorSnackBar(provider.error ?? 'Failed to remove avatar');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // FULL SCREEN IMAGE
  // ═══════════════════════════════════════════════════════════════════

  void _showFullScreenImage(UserProfile? profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: _selectedImage != null
                  ? Image.file(_selectedImage!)
                  : profile?.avatarUrl != null
                  ? Image.network(profile!.avatarUrl!)
                  : const Icon(
                Icons.person,
                size: 200,
                color: Color(0xFFFFDC71),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════

  void _cancelSelection() {
    setState(() => _selectedImage = null);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
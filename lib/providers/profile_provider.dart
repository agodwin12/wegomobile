// lib/providers/profile_provider.dart
// WEGO - Profile Provider
// Manages profile state and operations

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/support_model.dart';
import '../models/user_profile_model.dart';
import '../models/vehicle_model.dart';
import '../models/driver_document_model.dart';
import '../models/user_preferences_model.dart';
import '../service/profile_api_service.dart';


class ProfileProvider extends ChangeNotifier {
  final ProfileApiService _apiService = ProfileApiService();

  // ═══════════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════════

  UserProfile? _profile;
  Vehicle? _vehicle;
  DriverDocument? _documents;
  UserPreferences? _preferences;

  // Loading states
  bool _isLoadingProfile = false;
  bool _isLoadingVehicle = false;
  bool _isLoadingDocuments = false;
  bool _isLoadingPreferences = false;
  bool _isUpdating = false;

  // Error states
  String? _error;

  // ═══════════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════════

  UserProfile? get profile => _profile;
  Vehicle? get vehicle => _vehicle;
  DriverDocument? get documents => _documents;
  UserPreferences? get preferences => _preferences;

  bool get isLoadingProfile => _isLoadingProfile;
  bool get isLoadingVehicle => _isLoadingVehicle;
  bool get isLoadingDocuments => _isLoadingDocuments;
  bool get isLoadingPreferences => _isLoadingPreferences;
  bool get isUpdating => _isUpdating;
  bool get hasError => _error != null;
  String? get error => _error;

  // Helper getters
  bool get isDriver => _profile?.isDriver ?? false;
  bool get isServiceProvider => _profile?.isServiceProvider ?? false;

  // ═══════════════════════════════════════════════════════════════════
  // PROFILE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Load user profile
  Future<void> loadProfile() async {
    _isLoadingProfile = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _apiService.getProfile();
      _error = null;
      print('✅ [PROFILE PROVIDER] Profile loaded: ${_profile?.fullName}');
    } catch (e) {
      _error = 'Failed to load profile: $e';
      print('❌ [PROFILE PROVIDER] Error loading profile: $e');
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  /// Update profile information
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? address,
    String? city,
    DateTime? dateOfBirth,
  }) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _apiService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        address: address,
        city: city,
        dateOfBirth: dateOfBirth,
      );
      _error = null;
      print('✅ [PROFILE PROVIDER] Profile updated');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update profile: $e';
      print('❌ [PROFILE PROVIDER] Error updating profile: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Update profile avatar
  Future<bool> updateAvatar(File imageFile) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      final avatarUrl = await _apiService.updateAvatar(imageFile);

      // Update local profile with new avatar URL
      if (_profile != null) {
        _profile = _profile!.copyWith(avatarUrl: avatarUrl);
      }

      _error = null;
      print('✅ [PROFILE PROVIDER] Avatar updated');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update avatar: $e';
      print('❌ [PROFILE PROVIDER] Error updating avatar: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete profile avatar
  Future<bool> deleteAvatar() async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteAvatar();

      // Update local profile - remove avatar
      if (_profile != null) {
        _profile = _profile!.copyWith(avatarUrl: null);
      }

      _error = null;
      print('✅ [PROFILE PROVIDER] Avatar deleted');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete avatar: $e';
      print('❌ [PROFILE PROVIDER] Error deleting avatar: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _error = null;
      print('✅ [PROFILE PROVIDER] Password changed');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      print('❌ [PROFILE PROVIDER] Error changing password: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Refresh profile statistics
  Future<void> refreshStats() async {
    if (_profile == null) return;

    try {
      final stats = await _apiService.getStats();
      _profile = _profile!.copyWith(stats: stats);
      notifyListeners();
      print('✅ [PROFILE PROVIDER] Stats refreshed');
    } catch (e) {
      print('❌ [PROFILE PROVIDER] Error refreshing stats: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // VEHICLE OPERATIONS (for drivers)
  // ═══════════════════════════════════════════════════════════════════

  /// Load driver's vehicle
  Future<void> loadVehicle() async {
    _isLoadingVehicle = true;
    _error = null;
    notifyListeners();

    try {
      _vehicle = await _apiService.getVehicle();
      _error = null;
      print('✅ [PROFILE PROVIDER] Vehicle loaded');
    } catch (e) {
      _error = 'Failed to load vehicle: $e';
      print('❌ [PROFILE PROVIDER] Error loading vehicle: $e');
    } finally {
      _isLoadingVehicle = false;
      notifyListeners();
    }
  }

  /// Update vehicle information
  Future<bool> updateVehicle({
    required String brand,
    required String model,
    required String year,
    required String color,
    required String licensePlate,
    String? vehicleType,
    required int capacity,
    String? insuranceNumber,
    DateTime? insuranceExpiry,
  }) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      _vehicle = await _apiService.updateVehicle(
        brand: brand,
        model: model,
        year: year,
        color: color,
        licensePlate: licensePlate,
        vehicleType: vehicleType,
        capacity: capacity,
        insuranceNumber: insuranceNumber,
        insuranceExpiry: insuranceExpiry,
      );
      _error = null;
      print('✅ [PROFILE PROVIDER] Vehicle updated');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update vehicle: $e';
      print('❌ [PROFILE PROVIDER] Error updating vehicle: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Upload insurance document
  Future<bool> uploadInsurance(File documentFile) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      final insuranceUrl = await _apiService.uploadInsuranceDoc(documentFile);

      // Update local vehicle
      if (_vehicle != null) {
        _vehicle = _vehicle!.copyWith(insuranceDoc: insuranceUrl);
      }

      _error = null;
      print('✅ [PROFILE PROVIDER] Insurance uploaded');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to upload insurance: $e';
      print('❌ [PROFILE PROVIDER] Error uploading insurance: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // DRIVER DOCUMENTS
  // ═══════════════════════════════════════════════════════════════════

  /// Load driver documents
  Future<void> loadDocuments() async {
    _isLoadingDocuments = true;
    _error = null;
    notifyListeners();

    try {
      _documents = await _apiService.getDriverDocuments();
      _error = null;
      print('✅ [PROFILE PROVIDER] Documents loaded');
    } catch (e) {
      _error = 'Failed to load documents: $e';
      print('❌ [PROFILE PROVIDER] Error loading documents: $e');
    } finally {
      _isLoadingDocuments = false;
      notifyListeners();
    }
  }

  /// Upload driver license
  Future<bool> uploadLicense(File licenseFile) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      final licenseUrl = await _apiService.uploadDriverLicense(licenseFile);

      // Update local documents
      if (_documents != null) {
        _documents = _documents!.copyWith(licenseUrl: licenseUrl);
      }

      _error = null;
      print('✅ [PROFILE PROVIDER] License uploaded');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to upload license: $e';
      print('❌ [PROFILE PROVIDER] Error uploading license: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Upload CNI (National ID)
  Future<bool> uploadCNI(File cniFile) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      final cniUrl = await _apiService.uploadCNI(cniFile);

      // Update local documents
      if (_documents != null) {
        _documents = _documents!.copyWith(cniUrl: cniUrl);
      }

      _error = null;
      print('✅ [PROFILE PROVIDER] CNI uploaded');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to upload CNI: $e';
      print('❌ [PROFILE PROVIDER] Error uploading CNI: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // PREFERENCES & SETTINGS
  // ═══════════════════════════════════════════════════════════════════

  /// Load user preferences
  Future<void> loadPreferences() async {
    _isLoadingPreferences = true;
    _error = null;
    notifyListeners();

    try {
      _preferences = await _apiService.getPreferences();
      _error = null;
      print('✅ [PROFILE PROVIDER] Preferences loaded');
    } catch (e) {
      _error = 'Failed to load preferences: $e';
      print('❌ [PROFILE PROVIDER] Error loading preferences: $e');
    } finally {
      _isLoadingPreferences = false;
      notifyListeners();
    }
  }

  /// Update notification settings
  Future<bool> updateNotificationSettings(NotificationSettings settings) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      final updatedSettings = await _apiService.updateNotificationSettings(settings);

      // Update local preferences
      if (_preferences != null) {
        _preferences = _preferences!.copyWith(notifications: updatedSettings);
      }

      _error = null;
      print('✅ [PROFILE PROVIDER] Notification settings updated');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update notification settings: $e';
      print('❌ [PROFILE PROVIDER] Error updating notifications: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Update privacy settings
  Future<bool> updatePrivacySettings(PrivacySettings settings) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      final updatedSettings = await _apiService.updatePrivacySettings(settings);

      // Update local preferences
      if (_preferences != null) {
        _preferences = _preferences!.copyWith(privacy: updatedSettings);
      }

      _error = null;
      print('✅ [PROFILE PROVIDER] Privacy settings updated');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update privacy settings: $e';
      print('❌ [PROFILE PROVIDER] Error updating privacy: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // SUPPORT OPERATIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Get FAQ categories
  Future<List<FAQCategory>> getFAQCategories() async {
    try {
      return await _apiService.getFAQCategories();
    } catch (e) {
      print('❌ [PROFILE PROVIDER] Error getting FAQ categories: $e');
      rethrow;
    }
  }

  /// Get FAQ items by category
  Future<List<FAQItem>> getFAQItems(String categoryId) async {
    try {
      return await _apiService.getFAQItems(categoryId);
    } catch (e) {
      print('❌ [PROFILE PROVIDER] Error getting FAQ items: $e');
      rethrow;
    }
  }

  /// Search FAQ
  Future<List<FAQItem>> searchFAQ(String query) async {
    try {
      return await _apiService.searchFAQ(query);
    } catch (e) {
      print('❌ [PROFILE PROVIDER] Error searching FAQ: $e');
      rethrow;
    }
  }

  /// Mark FAQ as helpful
  Future<void> markFAQHelpful(String faqId) async {
    try {
      await _apiService.markFAQHelpful(faqId);
      print('✅ [PROFILE PROVIDER] FAQ marked helpful');
    } catch (e) {
      print('❌ [PROFILE PROVIDER] Error marking FAQ helpful: $e');
    }
  }

  /// Create support ticket
  Future<SupportTicket?> createSupportTicket({
    required String subject,
    required String description,
    required String category,
    required String priority,
    List<File>? attachments,
  }) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      final ticket = await _apiService.createSupportTicket(
        subject: subject,
        description: description,
        category: category,
        priority: priority,
        attachments: attachments,
      );
      _error = null;
      print('✅ [PROFILE PROVIDER] Support ticket created');
      _isUpdating = false;
      notifyListeners();
      return ticket;
    } catch (e) {
      _error = 'Failed to create ticket: $e';
      print('❌ [PROFILE PROVIDER] Error creating ticket: $e');
      _isUpdating = false;
      notifyListeners();
      return null;
    }
  }

  /// Get support tickets
  Future<List<SupportTicket>> getSupportTickets({
    String? status,
    int page = 1,
  }) async {
    try {
      return await _apiService.getSupportTickets(
        status: status,
        page: page,
      );
    } catch (e) {
      print('❌ [PROFILE PROVIDER] Error getting tickets: $e');
      rethrow;
    }
  }

  /// Get single support ticket
  Future<SupportTicket?> getSupportTicket(String ticketId) async {
    try {
      return await _apiService.getSupportTicket(ticketId);
    } catch (e) {
      print('❌ [PROFILE PROVIDER] Error getting ticket: $e');
      return null;
    }
  }

  /// Add message to ticket
  Future<bool> addTicketMessage({
    required String ticketId,
    required String message,
    List<File>? attachments,
  }) async {
    try {
      await _apiService.addTicketMessage(
        ticketId: ticketId,
        message: message,
        attachments: attachments,
      );
      print('✅ [PROFILE PROVIDER] Ticket message added');
      return true;
    } catch (e) {
      print('❌ [PROFILE PROVIDER] Error adding message: $e');
      return false;
    }
  }

  /// Submit problem report
  Future<bool> submitProblemReport(ProblemReport report) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.submitProblemReport(report);
      _error = null;
      print('✅ [PROFILE PROVIDER] Problem report submitted');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to submit report: $e';
      print('❌ [PROFILE PROVIDER] Error submitting report: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACCOUNT MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Request account deletion
  Future<bool> requestAccountDeletion(String reason) async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.requestAccountDeletion(reason);
      _error = null;
      print('✅ [PROFILE PROVIDER] Account deletion requested');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to request deletion: $e';
      print('❌ [PROFILE PROVIDER] Error requesting deletion: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  /// Deactivate account
  Future<bool> deactivateAccount() async {
    _isUpdating = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.deactivateAccount();
      _error = null;
      print('✅ [PROFILE PROVIDER] Account deactivated');
      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to deactivate account: $e';
      print('❌ [PROFILE PROVIDER] Error deactivating: $e');
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════

  /// Load all profile data at once
  Future<void> loadAllData() async {
    await loadProfile();

    if (isDriver) {
      await Future.wait([
        loadVehicle(),
        loadDocuments(),
      ]);
    }

    await loadPreferences();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider (logout)
  void reset() {
    _profile = null;
    _vehicle = null;
    _documents = null;
    _preferences = null;
    _isLoadingProfile = false;
    _isLoadingVehicle = false;
    _isLoadingDocuments = false;
    _isLoadingPreferences = false;
    _isUpdating = false;
    _error = null;
    notifyListeners();
    print('✅ [PROFILE PROVIDER] Reset complete');
  }
}

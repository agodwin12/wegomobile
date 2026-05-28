// lib/providers/services.dart
// Complete Services Marketplace Provider - All Features in One File

import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/services/category_model.dart';
import '../models/services/service_listing_model.dart';
import '../models/services/service_request_model.dart';
import '../models/services/service_rating_model.dart';
import '../models/services/service_dispute_model.dart';
import '../service/api/services_api_service.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// SERVICES PROVIDER - COMPLETE STATE MANAGEMENT
/// Handles all services marketplace state in one provider
/// ═══════════════════════════════════════════════════════════════════════

class ServicesProvider with ChangeNotifier {
  final ServicesApiService _apiService = ServicesApiService();

  // ═══════════════════════════════════════════════════════════════════════
  // CATEGORIES STATE
  // ═══════════════════════════════════════════════════════════════════════

  List<ServiceCategory> _categories = [];
  List<ServiceCategory> _parentCategories = [];
  ServiceCategory? _selectedCategory;
  List<ServiceCategory> _subcategories = [];
  bool _categoriesLoading = false;
  String? _categoriesError;

  // Categories Getters
  List<ServiceCategory> get categories => _categories;
  List<ServiceCategory> get parentCategories => _parentCategories;
  ServiceCategory? get selectedCategory => _selectedCategory;
  List<ServiceCategory> get subcategories => _subcategories;
  bool get categoriesLoading => _categoriesLoading;
  String? get categoriesError => _categoriesError;

  void reset() {
    debugPrint('🔄 [SERVICES_PROVIDER] Resetting all state...');
    clearAllState();
    clearAllErrors();

    // Reset pagination
    _currentPage     = 1;
    _totalPages      = 1;
    _hasMoreListings = true;

    debugPrint('✅ [SERVICES_PROVIDER] Reset complete');
  }


  /// Fetch all categories with subcategories
  Future<void> fetchCategories() async {
    _categoriesLoading = true;
    _categoriesError = null;
    notifyListeners();

    try {
      final response = await _apiService.getCategories(limit: 100);

      if (response['success'] == true) {
        final data = response['data']['categories'] as List;
        _categories = data.map((json) {
          try {
            return ServiceCategory.fromJson(json);
          } catch (e) {
            print('❌ [PROVIDER] Error parsing category: $e');
            print('❌ [PROVIDER] Category JSON: $json');
            rethrow;
          }
        }).toList();

        // Filter parent categories
        _parentCategories = _categories.where((cat) => cat.isParent).toList();

        print('✅ [PROVIDER] Loaded ${_categories.length} categories');
      } else {
        _categoriesError = response['message'] ?? 'Failed to load categories';
      }
    } catch (e) {
      _categoriesError = 'Error loading categories: ${e.toString()}';
      print('❌ [PROVIDER] Categories error: $e');
    } finally {
      _categoriesLoading = false;
      notifyListeners();
    }
  }

  /// Fetch parent categories only
  Future<void> fetchParentCategories() async {
    _categoriesLoading = true;
    _categoriesError = null;
    notifyListeners();

    try {
      final response = await _apiService.getParentCategories();

      if (response['success'] == true) {
        final dataWrapper = response['data'];
        if (dataWrapper == null) {
          _categoriesError = 'No data returned from API';
          _parentCategories = [];
        } else {
          final categoriesList = dataWrapper['categories'];
          if (categoriesList == null) {
            _parentCategories = [];
            print('⚠️ [PROVIDER] No categories in response');
          } else {
            final data = categoriesList as List;
            _parentCategories = data.map((json) {
              try {
                return ServiceCategory.fromJson(json);
              } catch (e) {
                print('❌ [PROVIDER] Error parsing category: $e');
                print('❌ [PROVIDER] Category JSON: $json');
                rethrow;
              }
            }).toList();

            print('✅ [PROVIDER] Loaded ${_parentCategories.length} parent categories');
          }
        }
      } else {
        _categoriesError = response['message'] ?? 'Failed to load categories';
        _parentCategories = [];
      }
    } catch (e) {
      _categoriesError = 'Error loading categories: ${e.toString()}';
      _parentCategories = [];
      print('❌ [PROVIDER] Parent categories error: $e');
    } finally {
      _categoriesLoading = false;
      notifyListeners();
    }
  }

  /// Fetch subcategories for a parent
  Future<void> fetchSubcategories(int parentId) async {
    _categoriesLoading = true;
    _categoriesError = null;
    notifyListeners();

    try {
      final response = await _apiService.getSubcategories(parentId);

      if (response['success'] == true) {
        final data = response['data']['categories'] as List;
        _subcategories = data.map((json) {
          try {
            return ServiceCategory.fromJson(json);
          } catch (e) {
            print('❌ [PROVIDER] Error parsing subcategory: $e');
            print('❌ [PROVIDER] Subcategory JSON: $json');
            rethrow;
          }
        }).toList();

        print('✅ [PROVIDER] Loaded ${_subcategories.length} subcategories');
      } else {
        _categoriesError = response['message'] ?? 'Failed to load subcategories';
      }
    } catch (e) {
      _categoriesError = e.toString();
      print('❌ [PROVIDER] Subcategories error: $e');
    } finally {
      _categoriesLoading = false;
      notifyListeners();
    }
  }

  /// Select a category
  void selectCategory(ServiceCategory category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Clear selected category
  void clearSelectedCategory() {
    _selectedCategory = null;
    _subcategories = [];
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LISTINGS STATE
  // ═══════════════════════════════════════════════════════════════════════

  List<ServiceListing> _listings = [];
  List<ServiceListing> _myListings = [];
  ServiceListing? _selectedListing;
  bool _listingsLoading = false;
  bool _myListingsLoading = false;
  String? _listingsError;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMoreListings = true;

  // Listings Getters
  List<ServiceListing> get listings => _listings;
  List<ServiceListing> get myListings => _myListings;
  ServiceListing? get selectedListing => _selectedListing;
  bool get listingsLoading => _listingsLoading;
  bool get myListingsLoading => _myListingsLoading;
  String? get listingsError => _listingsError;
  bool get hasMoreListings => _hasMoreListings;
  int get currentPage => _currentPage;

  // ✅ FIX: Added property for general loading state
  bool get isLoading => _listingsLoading || _categoriesLoading;

  /// Fetch listings with filters
  /// ✅ FIXED: Added sortBy and sortOrder parameters
  Future<void> fetchListings({
    bool refresh = true,
    int? categoryId,
    String? city,
    String? search,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    if (refresh) {
      _currentPage = 1;
      _listings = [];
    }

    _listingsLoading = true;
    _listingsError = null;
    notifyListeners();

    try {
      final response = await _apiService.getListings(
        page: _currentPage,
        categoryId: categoryId,
        city: city,
        search: search,
        minPrice: minPrice,
        maxPrice: maxPrice,
        minRating: minRating,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

      if (response['success'] == true) {
        final dataWrapper = response['data'];
        if (dataWrapper == null) {
          _listingsError = 'No data returned from API';
          _listings = [];
        } else {
          final listingsList = dataWrapper['listings'];
          if (listingsList == null) {
            _listings = [];
            print('⚠️ [PROVIDER] No listings in response');
          } else {
            final data = listingsList as List;
            final newListings = data.map((json) {
              try {
                return ServiceListing.fromJson(json);
              } catch (e) {
                print('❌ [PROVIDER] Error parsing listing: $e');
                print('❌ [PROVIDER] Listing JSON: $json');
                rethrow;
              }
            }).toList();

            if (refresh) {
              _listings = newListings;
            } else {
              _listings.addAll(newListings);
            }

            // Update pagination
            final pagination = dataWrapper['pagination'];
            if (pagination != null) {
              _currentPage = pagination['page'] as int? ?? 1;
              _totalPages = pagination['total_pages'] as int? ?? 1;
              _hasMoreListings = _currentPage < _totalPages;
            }

            print('✅ [PROVIDER] Loaded ${newListings.length} listings (Page $_currentPage/$_totalPages)');
          }
        }
      } else {
        _listingsError = response['message'] ?? 'Failed to load listings';
        _listings = [];
      }
    } catch (e) {
      _listingsError = 'Error loading listings: ${e.toString()}';
      _listings = [];
      print('❌ [PROVIDER] Listings error: $e');
    } finally {
      _listingsLoading = false;
      notifyListeners();
    }
  }

  /// Load more listings (pagination)
  Future<void> loadMoreListings({
    int? categoryId,
    String? city,
    String? search,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    if (!_hasMoreListings || _listingsLoading) return;

    _currentPage++;
    await fetchListings(
      refresh: false,
      categoryId: categoryId,
      city: city,
      search: search,
      minPrice: minPrice,
      maxPrice: maxPrice,
      minRating: minRating,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
  }

  /// Fetch single listing by ID
  Future<ServiceListing?> fetchListingById(int id) async {
    _listingsLoading = true;
    _listingsError = null;
    notifyListeners();

    try {
      final response = await _apiService.getListingById(id);

      if (response['success'] == true) {
        final listing = ServiceListing.fromJson(response['data']['listing']);
        _selectedListing = listing;

        print('✅ [PROVIDER] Loaded listing: ${listing.title}');
        notifyListeners();
        return listing;
      } else {
        _listingsError = response['message'] ?? 'Failed to load listing';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _listingsError = e.toString();
      print('❌ [PROVIDER] Listing error: $e');
      notifyListeners();
      return null;
    } finally {
      _listingsLoading = false;
      notifyListeners();
    }
  }

  /// Fetch my listings (Provider)
  Future<void> fetchMyListings({String? status}) async {
    _myListingsLoading = true;
    _listingsError = null;
    notifyListeners();

    try {
      final response = await _apiService.getMyListings(status: status);

      if (response['success'] == true) {
        final dataWrapper = response['data'];
        if (dataWrapper == null) {
          _listingsError = 'No data returned from API';
          _myListings = [];
        } else {
          final listingsList = dataWrapper['listings'];
          if (listingsList == null) {
            _myListings = [];
            print('⚠️ [PROVIDER] No listings in response');
          } else {
            final data = listingsList as List;

            _myListings = [];
            for (var json in data) {
              try {
                final listing = ServiceListing.fromJson(json);
                _myListings.add(listing);
              } catch (e) {
                print('❌ [PROVIDER] Error parsing listing: $e');
                print('❌ [PROVIDER] Listing JSON: $json');
              }
            }

            print('✅ [PROVIDER] Loaded ${_myListings.length} my listings');
          }
        }
      } else {
        _listingsError = response['message'] ?? 'Failed to load my listings';
        _myListings = [];
      }
    } catch (e, stackTrace) {
      _listingsError = 'Error loading my listings: ${e.toString()}';
      print('❌ [PROVIDER] My listings error: $e');
      print('❌ [PROVIDER] Stack trace: $stackTrace');
      _myListings = [];
    } finally {
      _myListingsLoading = false;
      notifyListeners();
    }
  }

  /// Create new listing
  Future<bool> createListing({
    required int categoryId,
    required String title,
    required String description,
    required String pricingType,
    int? price,
    int? minCharge,
    required String city,
    List<String>? neighborhoods,
    List<File>? photos,
    bool emergencyService = false,
  }) async {
    _listingsLoading = true;
    _listingsError = null;
    notifyListeners();

    try {
      double? hourlyRate;
      double? minimumCharge;
      double? fixedPrice;

      if (pricingType == 'hourly') {
        hourlyRate = price?.toDouble();
        minimumCharge = minCharge?.toDouble();
        print('🟢 [PROVIDER] Hourly: rate=$hourlyRate, min=$minimumCharge');
      } else if (pricingType == 'fixed') {
        fixedPrice = price?.toDouble();
        print('🟢 [PROVIDER] Fixed: price=$fixedPrice');
      } else {
        print('🟢 [PROVIDER] Negotiable: no price set');
      }

      final response = await _apiService.createListing(
        categoryId: categoryId,
        title: title,
        description: description,
        pricingType: pricingType,
        hourlyRate: hourlyRate,
        minimumCharge: minimumCharge,
        fixedPrice: fixedPrice,
        city: city,
        neighborhoods: neighborhoods,
        photos: photos,
        emergencyService: emergencyService,
      );

      if (response['success'] == true) {
        print('✅ [PROVIDER] Listing created successfully');
        await fetchMyListings();
        _listingsLoading = false;
        notifyListeners();
        return true;
      } else {
        _listingsError = response['message'] ?? 'Failed to create listing';
        _listingsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _listingsError = e.toString();
      print('❌ [PROVIDER] Create listing error: $e');
      _listingsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update listing
  Future<bool> updateListing({
    required int id,
    String? title,
    String? description,
    String? pricingType,
    int? price,
    int? minCharge,
    String? city,
    List<String>? neighborhoods,
    bool? emergencyService,
    List<File>? photos,
  }) async {
    _listingsLoading = true;
    _listingsError = null;
    notifyListeners();

    try {
      double? hourlyRate;
      double? minimumCharge;
      double? fixedPrice;

      if (pricingType == 'hourly') {
        hourlyRate = price?.toDouble();
        minimumCharge = minCharge?.toDouble();
        print('🟢 [PROVIDER] Update Hourly: rate=$hourlyRate, min=$minimumCharge');
      } else if (pricingType == 'fixed') {
        fixedPrice = price?.toDouble();
        print('🟢 [PROVIDER] Update Fixed: price=$fixedPrice');
      }

      final response = await _apiService.updateListing(
        id: id,
        title: title,
        description: description,
        pricingType: pricingType,
        hourlyRate: hourlyRate,
        minimumCharge: minimumCharge,
        fixedPrice: fixedPrice,
        city: city,
        neighborhoods: neighborhoods,
        emergencyService: emergencyService,
        photos: photos,
      );

      if (response['success'] == true) {
        print('✅ [PROVIDER] Listing updated successfully');
        await fetchMyListings();
        _listingsLoading = false;
        notifyListeners();
        return true;
      } else {
        _listingsError = response['message'] ?? 'Failed to update listing';
        _listingsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _listingsError = e.toString();
      print('❌ [PROVIDER] Update listing error: $e');
      _listingsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete listing
  Future<bool> deleteListing(int id) async {
    _listingsLoading = true;
    _listingsError = null;
    notifyListeners();

    try {
      final response = await _apiService.deleteListing(id);

      if (response['success'] == true) {
        print('✅ [PROVIDER] Listing deleted successfully');
        _myListings.removeWhere((listing) => listing.id == id);
        _listingsLoading = false;
        notifyListeners();
        return true;
      } else {
        _listingsError = response['message'] ?? 'Failed to delete listing';
        _listingsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _listingsError = e.toString();
      print('❌ [PROVIDER] Delete listing error: $e');
      _listingsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Activate listing
  Future<bool> activateListing(int id) async {
    _listingsLoading = true;
    _listingsError = null;
    notifyListeners();

    try {
      final response = await _apiService.activateListing(id);

      if (response['success'] == true) {
        print('✅ [PROVIDER] Listing activated successfully');
        await fetchMyListings();
        _listingsLoading = false;
        notifyListeners();
        return true;
      } else {
        _listingsError = response['message'] ?? 'Failed to activate listing';
        _listingsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _listingsError = e.toString();
      print('❌ [PROVIDER] Activate listing error: $e');
      _listingsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Deactivate listing
  Future<bool> deactivateListing(int id) async {
    _listingsLoading = true;
    _listingsError = null;
    notifyListeners();

    try {
      final response = await _apiService.deactivateListing(id);

      if (response['success'] == true) {
        print('✅ [PROVIDER] Listing deactivated successfully');
        await fetchMyListings();
        _listingsLoading = false;
        notifyListeners();
        return true;
      } else {
        _listingsError = response['message'] ?? 'Failed to deactivate listing';
        _listingsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _listingsError = e.toString();
      print('❌ [PROVIDER] Deactivate listing error: $e');
      _listingsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Select a listing
  void selectListing(ServiceListing listing) {
    _selectedListing = listing;
    notifyListeners();
  }

  /// Clear selected listing
  void clearSelectedListing() {
    _selectedListing = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REQUESTS STATE (Booking Flow)
  // ═══════════════════════════════════════════════════════════════════════

  List<ServiceRequest> _myRequests = [];
  List<ServiceRequest> _incomingRequests = [];
  ServiceRequest? _activeRequest;
  ServiceRequest? _selectedRequest;
  bool _requestsLoading = false;
  String? _requestsError;

  // Requests Getters
  List<ServiceRequest> get myRequests => _myRequests;
  List<ServiceRequest> get incomingRequests => _incomingRequests;
  ServiceRequest? get activeRequest => _activeRequest;
  ServiceRequest? get selectedRequest => _selectedRequest;
  bool get requestsLoading => _requestsLoading;
  String? get requestsError => _requestsError;

  /// Create service request (Customer)
  Future<bool> createRequest({
    required int listingId,
    required String description,
    required String neededWhen,
    String? scheduledDate,
    String? scheduledTime,
    required String serviceLocation,
    List<File>? photos,
  }) async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    try {
      final response = await _apiService.createRequest(
        listingId: listingId,
        description: description,
        neededWhen: neededWhen,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        serviceLocation: serviceLocation,
        photos: photos,
      );

      if (response['success'] == true) {
        print('✅ [PROVIDER] Request created successfully');
        await fetchMyRequests();
        _requestsLoading = false;
        notifyListeners();
        return true;
      } else {
        _requestsError = response['message'] ?? 'Failed to create request';
        _requestsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _requestsError = e.toString();
      print('❌ [PROVIDER] Create request error: $e');
      _requestsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetch my requests (Customer)
  Future<void> fetchMyRequests({String? status}) async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    try {
      final response = await _apiService.getMyRequests(status: status);

      if (response['success'] == true) {
        final data = response['data'] as List;
        _myRequests = data.map((json) => ServiceRequest.fromJson(json)).toList();

        print('✅ [PROVIDER] Loaded ${_myRequests.length} my requests');
      } else {
        _requestsError = response['message'] ?? 'Failed to load requests';
        _myRequests = [];
      }
    } catch (e, stackTrace) {
      _requestsError = e.toString();
      print('❌ [PROVIDER] My requests error: $e');
      print('Stack trace: $stackTrace');
      _myRequests = [];
    } finally {
      _requestsLoading = false;
      notifyListeners();
    }
  }

  /// Fetch incoming requests (Provider)
  Future<void> fetchIncomingRequests({String? status}) async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    try {
      final response = await _apiService.getIncomingRequests(status: status);

      if (response['success'] == true) {
        final data = response['data'] as List;

        _incomingRequests = [];
        for (var json in data) {
          try {
            final request = ServiceRequest.fromJson(json);
            _incomingRequests.add(request);
          } catch (e) {
            print('❌ [PROVIDER] Error parsing incoming request: $e');
            print('❌ [PROVIDER] Request JSON: $json');
          }
        }

        print('✅ [PROVIDER] Loaded ${_incomingRequests.length} incoming requests');
      } else {
        _requestsError = response['message'] ?? 'Failed to load incoming requests';
        _incomingRequests = [];
      }
    } catch (e, stackTrace) {
      _requestsError = 'Error loading incoming requests: ${e.toString()}';
      print('❌ [PROVIDER] Incoming requests error: $e');
      print('❌ [PROVIDER] Stack trace: $stackTrace');
      _incomingRequests = [];
    } finally {
      _requestsLoading = false;
      notifyListeners();
    }
  }

  /// Fetch request by ID
  Future<ServiceRequest?> fetchRequestById(int id) async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    try {
      final response = await _apiService.getRequestById(id);

      if (response['success'] == true) {
        final request = ServiceRequest.fromJson(response['data']['request']);
        _selectedRequest = request;

        print('✅ [PROVIDER] Loaded request: ${request.requestId}');
        notifyListeners();
        return request;
      } else {
        _requestsError = response['message'] ?? 'Failed to load request';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _requestsError = e.toString();
      print('❌ [PROVIDER] Request error: $e');
      notifyListeners();
      return null;
    } finally {
      _requestsLoading = false;
      notifyListeners();
    }
  }

  /// Accept request (Provider)
  Future<bool> acceptRequest(int id, {String? providerResponse}) async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    try {
      final response = await _apiService.acceptRequest(id, providerResponse: providerResponse);

      if (response['success'] == true) {
        print('✅ [PROVIDER] Request accepted');
        await fetchIncomingRequests();
        _requestsLoading = false;
        notifyListeners();
        return true;
      } else {
        _requestsError = response['message'] ?? 'Failed to accept request';
        _requestsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _requestsError = e.toString();
      print('❌ [PROVIDER] Accept request error: $e');
      _requestsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reject request (Provider)
  Future<bool> rejectRequest(int id, String rejectionReason) async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    try {
      final response = await _apiService.rejectRequest(id, rejectionReason);

      if (response['success'] == true) {
        print('✅ [PROVIDER] Request rejected');
        await fetchIncomingRequests();
        _requestsLoading = false;
        notifyListeners();
        return true;
      } else {
        _requestsError = response['message'] ?? 'Failed to reject request';
        _requestsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _requestsError = e.toString();
      print('❌ [PROVIDER] Reject request error: $e');
      _requestsLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // SERVICE REQUEST STATUS MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════

  /// Start service (move to in_progress)
  Future<bool> startService(int id) async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    try {
      print('🔵 [PROVIDER] Starting service: $id');

      final response = await _apiService.startService(id);

      if (response['success'] == true) {
        print('✅ [PROVIDER] Service started successfully');
        await fetchIncomingRequests();
        _requestsLoading = false;
        notifyListeners();
        return true;
      }

      _requestsError = response['message'] ?? 'Failed to start service';
      print('❌ [PROVIDER] Start service error: $_requestsError');
      _requestsLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _requestsError = e.toString();
      print('❌ [PROVIDER] Start service error: $e');
      _requestsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Complete service (move to payment_pending)
  Future<bool> completeService({
    required int requestId,
    required double finalAmount,
    String? workSummary,
    double? hoursWorked,
    double? materialsCost,
    List<String>? afterPhotos,
  }) async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    try {
      print('🔵 [PROVIDER] Completing service: $requestId');

      final response = await _apiService.completeService(
        id: requestId,
        finalAmount: finalAmount,
        workSummary: workSummary,
        hoursWorked: hoursWorked,
        materialsCost: materialsCost,

      );

      if (response['success'] == true) {
        print('✅ [PROVIDER] Service completed successfully');
        await fetchIncomingRequests();
        _requestsLoading = false;
        notifyListeners();
        return true;
      }

      _requestsError = response['message'] ?? 'Failed to complete service';
      print('❌ [PROVIDER] Complete service error: $_requestsError');
      _requestsLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _requestsError = e.toString();
      print('❌ [PROVIDER] Complete service error: $e');
      _requestsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Confirm payment (provider confirms they received payment)
  Future<bool> confirmPayment(int id) async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    try {
      print('🔵 [PROVIDER] Confirming payment: $id');

      final response = await _apiService.confirmPayment(id);

      if (response['success'] == true) {
        print('✅ [PROVIDER] Payment confirmed successfully');
        await fetchIncomingRequests();
        _requestsLoading = false;
        notifyListeners();
        return true;
      }

      _requestsError = response['message'] ?? 'Failed to confirm payment';
      print('❌ [PROVIDER] Confirm payment error: $_requestsError');
      _requestsLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _requestsError = e.toString();
      print('❌ [PROVIDER] Confirm payment error: $e');
      _requestsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Upload payment proof (Customer)
  Future<bool> uploadPaymentProof({
    required int id,
    required String paymentMethod,
    required File paymentProof,
    String? paymentReference,
  }) async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    try {
      final response = await _apiService.uploadPaymentProof(
        id: id,
        paymentMethod: paymentMethod,
        paymentProof: paymentProof,
        paymentReference: paymentReference,
      );

      if (response['success'] == true) {
        print('✅ [PROVIDER] Payment proof uploaded');
        if (_selectedRequest?.id == id) {
          await fetchRequestById(id);
        }
        _requestsLoading = false;
        notifyListeners();
        return true;
      } else {
        _requestsError = response['message'] ?? 'Failed to upload payment proof';
        _requestsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _requestsError = e.toString();
      print('❌ [PROVIDER] Upload payment proof error: $e');
      _requestsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancel request
  Future<bool> cancelRequest(int id, String cancellationReason) async {
    _requestsLoading = true;
    _requestsError = null;
    notifyListeners();

    try {
      final response = await _apiService.cancelRequest(id, cancellationReason);

      if (response['success'] == true) {
        print('✅ [PROVIDER] Request cancelled');
        await fetchMyRequests();
        _requestsLoading = false;
        notifyListeners();
        return true;
      } else {
        _requestsError = response['message'] ?? 'Failed to cancel request';
        _requestsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _requestsError = e.toString();
      print('❌ [PROVIDER] Cancel request error: $e');
      _requestsLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Select a request
  void selectRequest(ServiceRequest request) {
    _selectedRequest = request;
    notifyListeners();
  }

  /// Clear selected request
  void clearSelectedRequest() {
    _selectedRequest = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RATINGS STATE
  // ═══════════════════════════════════════════════════════════════════════

  List<ServiceRating> _ratings = [];
  bool _ratingsLoading = false;
  String? _ratingsError;

  // Ratings Getters
  List<ServiceRating> get ratings => _ratings;
  bool get ratingsLoading => _ratingsLoading;
  String? get ratingsError => _ratingsError;

  /// Fetch ratings for a listing
  Future<void> fetchRatingsForListing(int listingId) async {
    _ratingsLoading = true;
    _ratingsError = null;
    notifyListeners();

    try {
      final response = await _apiService.getRatingsForListing(listingId);

      if (response['success'] == true) {
        // ✅ FIXED: Handle both direct array and wrapped response
        // Backend returns: { success: true, data: [...], statistics: {...} }
        // NOT: { success: true, data: { ratings: [...] } }

        final data = response['data'];

        if (data is List) {
          // Direct array response
          _ratings = data.map((json) {
            try {
              return ServiceRating.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              debugPrint('❌ [PROVIDER] Error parsing rating: $e');
              debugPrint('❌ [PROVIDER] Rating JSON: $json');
              return null;
            }
          }).whereType<ServiceRating>().toList();
        } else if (data is Map<String, dynamic>) {
          // Wrapped response with ratings key
          final rawList = data['ratings'] as List? ?? [];
          _ratings = rawList.map((json) {
            try {
              return ServiceRating.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              debugPrint('❌ [PROVIDER] Error parsing rating: $e');
              return null;
            }
          }).whereType<ServiceRating>().toList();
        } else {
          _ratings = [];
          debugPrint('⚠️ [PROVIDER] Unexpected ratings response format');
        }

        debugPrint('✅ [PROVIDER] Loaded ${_ratings.length} ratings');
      } else {
        _ratingsError = response['message'] ?? 'Failed to load ratings';
        _ratings = [];
      }
    } catch (e) {
      _ratingsError = e.toString();
      _ratings = [];
      debugPrint('❌ [PROVIDER] Ratings error: $e');
    } finally {
      _ratingsLoading = false;
      notifyListeners();
    }
  }

  /// Create rating (Customer)
  Future<bool> createRating({
    required int requestId,
    required int rating,
    String? reviewText,
    List<File>? reviewPhotos,
    required String review,
    String? comment,
  }) async {
    _ratingsLoading = true;
    _ratingsError = null;
    notifyListeners();

    try {
      final response = await _apiService.createRating(
        requestId: requestId,
        rating: rating,
        reviewText: reviewText ?? review,
        reviewPhotos: reviewPhotos,
      );

      if (response['success'] == true) {
        print('✅ [PROVIDER] Rating created successfully');
        _ratingsLoading = false;
        notifyListeners();
        return true;
      } else {
        _ratingsError = response['message'] ?? 'Failed to create rating';
        _ratingsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _ratingsError = e.toString();
      print('❌ [PROVIDER] Create rating error: $e');
      _ratingsLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DISPUTES STATE
  // ═══════════════════════════════════════════════════════════════════════

  List<ServiceDispute> _disputes = [];
  ServiceDispute? _selectedDispute;
  bool _disputesLoading = false;
  String? _disputesError;

  // Disputes Getters
  List<ServiceDispute> get disputes => _disputes;
  ServiceDispute? get selectedDispute => _selectedDispute;
  bool get disputesLoading => _disputesLoading;
  String? get disputesError => _disputesError;

  /// Fetch my disputes
  Future<void> fetchMyDisputes({String? status}) async {
    _disputesLoading = true;
    _disputesError = null;
    notifyListeners();

    try {
      final response = await _apiService.getMyDisputes(status: status);

      if (response['success'] == true) {
        final data = response['data']['disputes'] as List;
        _disputes = data.map((json) => ServiceDispute.fromJson(json)).toList();

        print('✅ [PROVIDER] Loaded ${_disputes.length} disputes');
      } else {
        _disputesError = response['message'] ?? 'Failed to load disputes';
      }
    } catch (e) {
      _disputesError = e.toString();
      print('❌ [PROVIDER] Disputes error: $e');
    } finally {
      _disputesLoading = false;
      notifyListeners();
    }
  }

  /// File dispute
  Future<bool> fileDispute({
    required int requestId,
    required String disputeType,
    required String description,
    required String resolutionRequested,
    List<File>? evidencePhotos, double? refundAmount,
  }) async {
    _disputesLoading = true;
    _disputesError = null;
    notifyListeners();

    try {
      final response = await _apiService.fileDispute(
        requestId: requestId,
        disputeType: disputeType,
        description: description,
        resolutionRequested: resolutionRequested,
        evidencePhotos: evidencePhotos,
      );

      if (response['success'] == true) {
        print('✅ [PROVIDER] Dispute filed successfully');
        await fetchMyDisputes();
        _disputesLoading = false;
        notifyListeners();
        return true;
      } else {
        _disputesError = response['message'] ?? 'Failed to file dispute';
        _disputesLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _disputesError = e.toString();
      print('❌ [PROVIDER] File dispute error: $e');
      _disputesLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Select a dispute
  void selectDispute(ServiceDispute dispute) {
    _selectedDispute = dispute;
    notifyListeners();
  }

  /// Clear selected dispute
  void clearSelectedDispute() {
    _selectedDispute = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GLOBAL STATE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  /// Clear all state
  void clearAllState() {
    _categories = [];
    _parentCategories = [];
    _selectedCategory = null;
    _subcategories = [];
    _listings = [];
    _myListings = [];
    _selectedListing = null;
    _myRequests = [];
    _incomingRequests = [];
    _activeRequest = null;
    _selectedRequest = null;
    _ratings = [];
    _disputes = [];
    _selectedDispute = null;

    notifyListeners();
  }

  /// Clear all errors
  void clearAllErrors() {
    _categoriesError = null;
    _listingsError = null;
    _requestsError = null;
    _ratingsError = null;
    _disputesError = null;

    notifyListeners();
  }

  /// Check if any operation is loading
  bool get isAnyLoading =>
      _categoriesLoading ||
          _listingsLoading ||
          _myListingsLoading ||
          _requestsLoading ||
          _ratingsLoading ||
          _disputesLoading;
}
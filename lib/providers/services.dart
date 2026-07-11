// lib/providers/services.dart
// Complete Services Marketplace Provider - All Features in One File

import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/listing_plan_model.dart';
import '../models/services/category_model.dart';
import '../models/services/service_listing_model.dart';
import '../models/services/service_rating_model.dart';
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
            debugPrint('❌ [PROVIDER] Error parsing category: $e');
            rethrow;
          }
        }).toList();
        _parentCategories = _categories.where((cat) => cat.isParent).toList();
        debugPrint('✅ [PROVIDER] Loaded ${_categories.length} categories');
      } else {
        _categoriesError = response['message'] ?? 'Failed to load categories';
      }
    } catch (e) {
      _categoriesError = 'Error loading categories: ${e.toString()}';
      debugPrint('❌ [PROVIDER] Categories error: $e');
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
          } else {
            final data = categoriesList as List;
            _parentCategories = data.map((json) {
              try {
                return ServiceCategory.fromJson(json);
              } catch (e) {
                debugPrint('❌ [PROVIDER] Error parsing category: $e');
                rethrow;
              }
            }).toList();
            debugPrint('✅ [PROVIDER] Loaded ${_parentCategories.length} parent categories');
          }
        }
      } else {
        _categoriesError = response['message'] ?? 'Failed to load categories';
        _parentCategories = [];
      }
    } catch (e) {
      _categoriesError = 'Error loading categories: ${e.toString()}';
      _parentCategories = [];
      debugPrint('❌ [PROVIDER] Parent categories error: $e');
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
            debugPrint('❌ [PROVIDER] Error parsing subcategory: $e');
            rethrow;
          }
        }).toList();
        debugPrint('✅ [PROVIDER] Loaded ${_subcategories.length} subcategories');
      } else {
        _categoriesError = response['message'] ?? 'Failed to load subcategories';
      }
    } catch (e) {
      _categoriesError = e.toString();
      debugPrint('❌ [PROVIDER] Subcategories error: $e');
    } finally {
      _categoriesLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(ServiceCategory category) {
    _selectedCategory = category;
    notifyListeners();
  }

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
  List<ServiceListing> _heroListings = [];
  ServiceListing? _selectedListing;
  bool _listingsLoading = false;
  bool _myListingsLoading = false;
  bool _heroLoading = false;
  String? _listingsError;

  int  _currentPage     = 1;
  int  _totalPages      = 1;
  bool _hasMoreListings = true;

  List<ServiceListing> get listings        => _listings;
  List<ServiceListing> get myListings      => _myListings;
  List<ServiceListing> get heroListings    => _heroListings;
  bool                 get heroLoading     => _heroLoading;
  ServiceListing?      get selectedListing => _selectedListing;
  bool                 get listingsLoading => _listingsLoading;
  bool                 get myListingsLoading => _myListingsLoading;
  String?              get listingsError   => _listingsError;
  bool                 get hasMoreListings => _hasMoreListings;
  int                  get currentPage     => _currentPage;
  bool                 get isLoading       => _listingsLoading || _categoriesLoading;

  Future<void> fetchListings({
    bool refresh = true,
    int? categoryId,
    String? city,
    String? search,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String sortBy    = 'created_at',
    String sortOrder = 'desc',
  }) async {
    if (refresh) {
      _currentPage = 1;
      _listings    = [];
    }

    _listingsLoading = true;
    _listingsError   = null;
    notifyListeners();

    try {
      final response = await _apiService.getListings(
        page:       _currentPage,
        categoryId: categoryId,
        city:       city,
        search:     search,
        minPrice:   minPrice,
        maxPrice:   maxPrice,
        minRating:  minRating,
        sortBy:     sortBy,
        sortOrder:  sortOrder,
      );

      if (response['success'] == true) {
        final dataWrapper  = response['data'];
        final listingsList = dataWrapper?['listings'];
        if (listingsList == null) {
          _listings = [];
        } else {
          final newListings = (listingsList as List).map((json) {
            try {
              return ServiceListing.fromJson(json);
            } catch (e) {
              debugPrint('❌ [PROVIDER] Error parsing listing: $e');
              rethrow;
            }
          }).toList();

          if (refresh) {
            _listings = newListings;
          } else {
            _listings.addAll(newListings);
          }

          final pagination = dataWrapper?['pagination'];
          if (pagination != null) {
            _currentPage     = pagination['page']        as int? ?? 1;
            _totalPages      = pagination['total_pages'] as int? ?? 1;
            _hasMoreListings = _currentPage < _totalPages;
          }
        }
      } else {
        _listingsError = response['message'] ?? 'Failed to load listings';
        _listings      = [];
      }
    } catch (e) {
      _listingsError = 'Error loading listings: ${e.toString()}';
      _listings      = [];
      debugPrint('❌ [PROVIDER] Listings error: $e');
    } finally {
      _listingsLoading = false;
      notifyListeners();
    }
  }

  /// Fetch the featured (hero) listings for the carousel. Backend returns only
  /// currently-featured, non-expired, active listings via ?hero=true.
  Future<void> fetchHeroListings({ int limit = 10 }) async {
    _heroLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.getListings(hero: true, limit: limit);
      if (response['success'] == true) {
        final list = response['data']?['listings'];
        if (list is List) {
          _heroListings = list
              .map((json) {
                try { return ServiceListing.fromJson(json); }
                catch (_) { return null; }
              })
              .whereType<ServiceListing>()
              .toList();
        } else {
          _heroListings = [];
        }
      } else {
        _heroListings = [];
      }
    } catch (e) {
      debugPrint('❌ [PROVIDER] Hero listings error: $e');
      _heroListings = [];
    } finally {
      _heroLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreListings({
    int?   categoryId,
    String? city,
    String? search,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    String sortBy    = 'created_at',
    String sortOrder = 'desc',
  }) async {
    if (!_hasMoreListings || _listingsLoading) return;
    _currentPage++;
    await fetchListings(
      refresh:    false,
      categoryId: categoryId,
      city:       city,
      search:     search,
      minPrice:   minPrice,
      maxPrice:   maxPrice,
      minRating:  minRating,
      sortBy:     sortBy,
      sortOrder:  sortOrder,
    );
  }

  Future<ServiceListing?> fetchListingById(int id) async {
    _listingsLoading = true;
    _listingsError   = null;
    notifyListeners();

    try {
      final response = await _apiService.getListingById(id);
      if (response['success'] == true) {
        final listing    = ServiceListing.fromJson(response['data']['listing']);
        _selectedListing = listing;
        notifyListeners();
        return listing;
      } else {
        _listingsError = response['message'] ?? 'Failed to load listing';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _listingsError = e.toString();
      debugPrint('❌ [PROVIDER] Listing error: $e');
      notifyListeners();
      return null;
    } finally {
      _listingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyListings({String? status}) async {
    _myListingsLoading = true;
    _listingsError     = null;
    notifyListeners();

    try {
      final response     = await _apiService.getMyListings(status: status);
      final listingsList = response['data']?['listings'];

      if (response['success'] == true && listingsList != null) {
        _myListings = [];
        for (final json in listingsList as List) {
          try {
            _myListings.add(ServiceListing.fromJson(json));
          } catch (e) {
            debugPrint('❌ [PROVIDER] Error parsing listing: $e');
          }
        }
        debugPrint('✅ [PROVIDER] Loaded ${_myListings.length} my listings');
      } else {
        _listingsError = response['message'] ?? 'Failed to load my listings';
        _myListings    = [];
      }
    } catch (e, st) {
      _listingsError = 'Error loading my listings: ${e.toString()}';
      _myListings    = [];
      debugPrint('❌ [PROVIDER] My listings error: $e\n$st');
    } finally {
      _myListingsLoading = false;
      notifyListeners();
    }
  }

  /// Create listing — returns the new listing's ID on success, null on failure.
  Future<int?> createListing({
    required int    categoryId,
    required String title,
    required String description,
    required String pricingType,
    int?            price,
    int?            minCharge,
    required String city,
    List<String>?   neighborhoods,
    List<File>?     photos,
    bool            emergencyService = false,
  }) async {
    _listingsLoading = true;
    _listingsError   = null;
    notifyListeners();

    try {
      double? hourlyRate;
      double? minimumCharge;
      double? fixedPrice;

      if (pricingType == 'hourly') {
        hourlyRate    = price?.toDouble();
        minimumCharge = minCharge?.toDouble();
      } else if (pricingType == 'fixed') {
        fixedPrice = price?.toDouble();
      }

      final response = await _apiService.createListing(
        categoryId:      categoryId,
        title:           title,
        description:     description,
        pricingType:     pricingType,
        hourlyRate:      hourlyRate,
        minimumCharge:   minimumCharge,
        fixedPrice:      fixedPrice,
        city:            city,
        neighborhoods:   neighborhoods,
        photos:          photos,
        emergencyService: emergencyService,
      );

      if (response['success'] == true) {
        debugPrint('✅ [PROVIDER] Listing created successfully');
        await fetchMyListings();
        _listingsLoading = false;
        notifyListeners();
        // Return the new listing's ID so callers can chain plan activation
        return response['data']?['listing']?['id'] as int?;
      } else {
        _listingsError   = response['message'] ?? 'Failed to create listing';
        _listingsLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _listingsError   = e.toString();
      _listingsLoading = false;
      debugPrint('❌ [PROVIDER] Create listing error: $e');
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateListing({
    required int    id,
    String?         title,
    String?         description,
    String?         pricingType,
    int?            price,
    int?            minCharge,
    String?         city,
    List<String>?   neighborhoods,
    bool?           emergencyService,
    List<File>?     photos,
  }) async {
    _listingsLoading = true;
    _listingsError   = null;
    notifyListeners();

    try {
      double? hourlyRate;
      double? minimumCharge;
      double? fixedPrice;

      if (pricingType == 'hourly') {
        hourlyRate    = price?.toDouble();
        minimumCharge = minCharge?.toDouble();
      } else if (pricingType == 'fixed') {
        fixedPrice = price?.toDouble();
      }

      final response = await _apiService.updateListing(
        id:              id,
        title:           title,
        description:     description,
        pricingType:     pricingType,
        hourlyRate:      hourlyRate,
        minimumCharge:   minimumCharge,
        fixedPrice:      fixedPrice,
        city:            city,
        neighborhoods:   neighborhoods,
        emergencyService: emergencyService,
        photos:          photos,
      );

      if (response['success'] == true) {
        debugPrint('✅ [PROVIDER] Listing updated successfully');
        await fetchMyListings();
        _listingsLoading = false;
        notifyListeners();
        return true;
      } else {
        _listingsError   = response['message'] ?? 'Failed to update listing';
        _listingsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _listingsError   = e.toString();
      _listingsLoading = false;
      debugPrint('❌ [PROVIDER] Update listing error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteListing(int id) async {
    _listingsLoading = true;
    _listingsError   = null;
    notifyListeners();

    try {
      final response = await _apiService.deleteListing(id);
      if (response['success'] == true) {
        _myListings.removeWhere((l) => l.id == id);
        _listingsLoading = false;
        notifyListeners();
        return true;
      } else {
        _listingsError   = response['message'] ?? 'Failed to delete listing';
        _listingsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _listingsError   = e.toString();
      _listingsLoading = false;
      debugPrint('❌ [PROVIDER] Delete listing error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> activateListing(int id) async {
    _listingsLoading = true;
    _listingsError   = null;
    notifyListeners();

    try {
      final response = await _apiService.activateListing(id);
      if (response['success'] == true) {
        await fetchMyListings();
        _listingsLoading = false;
        notifyListeners();
        return true;
      } else {
        _listingsError   = response['message'] ?? 'Failed to activate listing';
        _listingsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _listingsError   = e.toString();
      _listingsLoading = false;
      debugPrint('❌ [PROVIDER] Activate listing error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deactivateListing(int id) async {
    _listingsLoading = true;
    _listingsError   = null;
    notifyListeners();

    try {
      final response = await _apiService.deactivateListing(id);
      if (response['success'] == true) {
        await fetchMyListings();
        _listingsLoading = false;
        notifyListeners();
        return true;
      } else {
        _listingsError   = response['message'] ?? 'Failed to deactivate listing';
        _listingsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _listingsError   = e.toString();
      _listingsLoading = false;
      debugPrint('❌ [PROVIDER] Deactivate listing error: $e');
      notifyListeners();
      return false;
    }
  }

  void selectListing(ServiceListing listing) {
    _selectedListing = listing;
    notifyListeners();
  }

  void clearSelectedListing() {
    _selectedListing = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LISTING PLANS
  // ═══════════════════════════════════════════════════════════════════════

  /// GET /api/services/plans
  Future<List<ListingPlan>> fetchListingPlans() async {
    try {
      final response = await _apiService.getListingPlans();
      if (response['success'] == true) {
        final list = response['data']['plans'] as List<dynamic>;
        return list
            .map((p) => ListingPlan.fromJson(p as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ [PROVIDER] fetchListingPlans: $e');
    }
    return [];
  }

  /// POST /api/services/listings/:id/activate-free
  Future<bool> activateFreePlan(int listingId) async {
    try {
      final response = await _apiService.activateFreePlan(listingId);
      return response['success'] == true;
    } catch (e) {
      debugPrint('❌ [PROVIDER] activateFreePlan: $e');
      return false;
    }
  }

  /// POST /api/services/listings/:id/initiate-payment
  Future<Map<String, dynamic>?> initiateListingPayment({
    required int    listingId,
    required int    planId,
    required String phone,
  }) async {
    try {
      final response = await _apiService.initiateListingPayment(
        listingId: listingId,
        planId:    planId,
        phone:     phone,
      );
      if (response['success'] == true) return response;
    } catch (e) {
      debugPrint('❌ [PROVIDER] initiateListingPayment: $e');
    }
    return null;
  }

  // ── Provider subscription (buy a plan once, then post) ───────────────────

  /// GET /api/services/subscription/mine → the provider's active plan (or null).
  Future<Map<String, dynamic>?> getMySubscription() async {
    try {
      final response = await _apiService.getMySubscription();
      if (response['success'] == true) return response['data'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ [PROVIDER] getMySubscription: $e');
    }
    return null;
  }

  /// GET /api/services/subscription/history → list of the provider's payments.
  Future<List<Map<String, dynamic>>> getSubscriptionHistory() async {
    try {
      final response = await _apiService.getSubscriptionHistory();
      if (response['success'] == true && response['data'] is List) {
        return (response['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      debugPrint('❌ [PROVIDER] getSubscriptionHistory: $e');
    }
    return [];
  }

  /// POST /api/services/subscription/activate-free → instant free plan.
  Future<bool> activateFreeSubscription() async {
    try {
      final response = await _apiService.activateFreeSubscription();
      return response['success'] == true;
    } catch (e) {
      debugPrint('❌ [PROVIDER] activateFreeSubscription: $e');
      return false;
    }
  }

  /// POST /api/services/subscription/initiate-payment → paid plan via CamPay.
  Future<Map<String, dynamic>?> initiateSubscriptionPayment({
    required int    planId,
    required String phone,
  }) async {
    try {
      final response = await _apiService.initiateSubscriptionPayment(planId: planId, phone: phone);
      if (response['success'] == true) return response;
    } catch (e) {
      debugPrint('❌ [PROVIDER] initiateSubscriptionPayment: $e');
    }
    return null;
  }

  /// GET /api/services/listings/:id/ad-status
  /// Returns 'active', 'pending_payment', 'cancelled', or null on error.
  Future<String?> checkAdPaymentStatus(int listingId) async {
    try {
      final response = await _apiService.getAdStatus(listingId);
      if (response['success'] == true) {
        final data   = response['data'] as Map<String, dynamic>;
        final latest = data['latest_payment'] as Map<String, dynamic>?;
        return latest?['status'] as String?;
      }
    } catch (e) {
      debugPrint('❌ [PROVIDER] checkAdPaymentStatus: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RATINGS STATE
  // ═══════════════════════════════════════════════════════════════════════

  List<ServiceRating> _ratings       = [];
  bool                _ratingsLoading = false;
  String?             _ratingsError;

  List<ServiceRating> get ratings        => _ratings;
  bool                get ratingsLoading => _ratingsLoading;
  String?             get ratingsError   => _ratingsError;

  Future<void> fetchRatingsForListing(int listingId) async {
    _ratingsLoading = true;
    _ratingsError   = null;
    notifyListeners();

    try {
      final response = await _apiService.getRatingsForListing(listingId);

      if (response['success'] == true) {
        final data = response['data'];
        if (data is List) {
          _ratings = data.map((json) {
            try {
              return ServiceRating.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              debugPrint('❌ [PROVIDER] Error parsing rating: $e');
              return null;
            }
          }).whereType<ServiceRating>().toList();
        } else if (data is Map<String, dynamic>) {
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
        }
        debugPrint('✅ [PROVIDER] Loaded ${_ratings.length} ratings');
      } else {
        _ratingsError = response['message'] ?? 'Failed to load ratings';
        _ratings      = [];
      }
    } catch (e) {
      _ratingsError = e.toString();
      _ratings      = [];
      debugPrint('❌ [PROVIDER] Ratings error: $e');
    } finally {
      _ratingsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createRating({
    required int    listingId,
    required int    rating,
    String?         reviewText,
    List<File>?     reviewPhotos,
  }) async {
    _ratingsLoading = true;
    _ratingsError   = null;
    notifyListeners();

    try {
      final response = await _apiService.createRating(
        listingId:    listingId,
        rating:       rating,
        reviewText:   reviewText,
        reviewPhotos: reviewPhotos,
      );
      if (response['success'] == true) {
        _ratingsLoading = false;
        notifyListeners();
        return true;
      } else {
        _ratingsError   = response['message'] ?? 'Failed to create rating';
        _ratingsLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _ratingsError   = e.toString();
      _ratingsLoading = false;
      debugPrint('❌ [PROVIDER] Create rating error: $e');
      notifyListeners();
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GLOBAL STATE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  void clearAllState() {
    _categories       = [];
    _parentCategories = [];
    _selectedCategory = null;
    _subcategories    = [];
    _listings         = [];
    _myListings       = [];
    _selectedListing  = null;
    _ratings          = [];
    notifyListeners();
  }

  void clearAllErrors() {
    _categoriesError = null;
    _listingsError   = null;
    _ratingsError    = null;
    notifyListeners();
  }

  bool get isAnyLoading =>
      _categoriesLoading  ||
          _listingsLoading    ||
          _myListingsLoading  ||
          _ratingsLoading;
}
// lib/presentation/screens/passenger/delivery/steps/delivery_step1_location.dart
//
// STEP 1 — Pickup & Dropoff Locations  (Redesigned UI)
//
// Pickup  → auto-filled from device GPS + reverse geocoded to address
// Dropoff → Google Places Autocomplete biased to user's current position
//           Fallback: if Places fails, shows Logpom area suggestions

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../../../utils/app_colors.dart';
import '../../../../../utils/app_typography.dart';
import '../../../../../core/config.dart';
import 'delivery_package_selector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceSuggestion {
  final String  placeId;
  final String  mainText;
  final String  secondaryText;
  final bool    isFallback;
  final double? lat;
  final double? lng;

  _PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    this.isFallback = false,
    this.lat,
    this.lng,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// FALLBACK SUGGESTIONS
// ─────────────────────────────────────────────────────────────────────────────

const _kLogpomFallbacks = [
  _FallbackPlace('Logpom — Carrefour Total',       'Logpom, Douala',    4.0285, 9.7456),
  _FallbackPlace('Logpom — École Publique',         'Logpom, Douala',    4.0271, 9.7438),
  _FallbackPlace('Logpom — Marché',                 'Logpom, Douala',    4.0268, 9.7449),
  _FallbackPlace('Akwa — Boulevard de la Liberté',  'Akwa, Douala',      4.0511, 9.7007),
  _FallbackPlace('Bonanjo — Gouvernance',           'Bonanjo, Douala',   4.0432, 9.6922),
  _FallbackPlace('Makepe — Carrefour Shell',        'Makepe, Douala',    4.0700, 9.7650),
  _FallbackPlace('Bonapriso — Rue Pau',             'Bonapriso, Douala', 4.0389, 9.6967),
  _FallbackPlace('Bassa — Total Bassa',             'Bassa, Douala',     4.0150, 9.7550),
  _FallbackPlace('Deido — Carrefour Deido',         'Deido, Douala',     4.0589, 9.7156),
  _FallbackPlace('Ndokotti — Marché Ndokotti',      'Ndokotti, Douala',  4.0467, 9.7289),
];

class _FallbackPlace {
  final String name;
  final String area;
  final double lat;
  final double lng;
  const _FallbackPlace(this.name, this.area, this.lat, this.lng);
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryStep1Location extends StatefulWidget {
  final String deliveryType;
  final String accessToken;

  const DeliveryStep1Location({
    super.key,
    required this.deliveryType,
    required this.accessToken,
  });

  @override
  State<DeliveryStep1Location> createState() => _DeliveryStep1LocationState();
}

class _DeliveryStep1LocationState extends State<DeliveryStep1Location>
    with SingleTickerProviderStateMixin {

  // ── Pickup ───────────────────────────────────────────────────────────────
  double? _pickupLat;
  double? _pickupLng;
  bool    _gpsLoading = false;
  String? _gpsError;
  final   _pickupAddressCtrl = TextEditingController();

  // ── Dropoff ──────────────────────────────────────────────────────────────
  double? _dropoffLat;
  double? _dropoffLng;
  final   _dropoffSearchCtrl = TextEditingController();
  String? _dropoffAddress;

  // ── Autocomplete ──────────────────────────────────────────────────────────
  List<_PlaceSuggestion> _suggestions    = [];
  bool                   _loadingSuggest = false;
  bool                   _showDropdown   = false;
  bool                   _usedFallback   = false;
  Timer?                 _debounce;

  // ── Animation ────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  bool get _isExpress  => widget.deliveryType == 'express';
  bool get _canProceed => _pickupLat != null && _dropoffLat != null && _dropoffLng != null;

  // Express = gold accent; Regular = deep navy
  Color get _accentColor => _isExpress ? AppColors.primaryGold : AppColors.primaryDark;
  Color get _accentFg    => _isExpress ? AppColors.primaryDark : Colors.white;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _fetchGps();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupAddressCtrl.dispose();
    _dropoffSearchCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GPS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _fetchGps() async {
    setState(() { _gpsLoading = true; _gpsError = null; });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() { _gpsError = 'Location permission denied.'; _gpsLoading = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      final address = await _reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _pickupLat = pos.latitude;
          _pickupLng = pos.longitude;
          _gpsLoading = false;
          _pickupAddressCtrl.text = address ??
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        });
      }
    } catch (_) {
      if (mounted) setState(() { _gpsError = 'Could not get location.'; _gpsLoading = false; });
    }
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final token = AppConfig.mapboxToken;
      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '$lng,$lat.json'
        '?access_token=$token'
        '&country=cm&language=fr'
        '&types=address,neighborhood,locality,place,poi'
        '&limit=1',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final features =
            jsonDecode(res.body)['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          return features[0]['place_name'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PLACES AUTOCOMPLETE
  // ─────────────────────────────────────────────────────────────────────────

  void _onDropoffSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() { _suggestions = []; _showDropdown = false; _usedFallback = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String input) async {
    setState(() { _loadingSuggest = true; });
    try {
      final token   = AppConfig.mapboxToken;
      final biasLat = _pickupLat ?? 4.0280;
      final biasLng = _pickupLng ?? 9.7445;
      final encoded = Uri.encodeComponent(input);
      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '$encoded.json'
        '?access_token=$token'
        '&country=CM'
        '&language=fr'
        '&proximity=$biasLng,$biasLat'
        '&limit=5',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final features =
            jsonDecode(res.body)['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          final suggestions = features.map((f) {
            final coords = f['geometry']?['coordinates'] as List<dynamic>?;
            final lat = coords != null ? (coords[1] as num).toDouble() : null;
            final lng = coords != null ? (coords[0] as num).toDouble() : null;
            final placeName = f['place_name'] as String? ?? '';
            final parts     = placeName.split(',');
            return _PlaceSuggestion(
              placeId:       f['id'] as String? ?? placeName,
              mainText:      parts.isNotEmpty ? parts[0].trim() : placeName,
              secondaryText: parts.length > 1
                  ? parts.sublist(1).join(',').trim()
                  : '',
              lat: lat,
              lng: lng,
            );
          }).toList();
          if (mounted) {
            setState(() {
              _suggestions    = suggestions;
              _showDropdown   = true;
              _loadingSuggest = false;
              _usedFallback   = false;
            });
          }
          return;
        }
      }
      _showFallbacks(input);
    } catch (_) {
      _showFallbacks(input);
    }
  }

  void _showFallbacks(String query) {
    final q        = query.toLowerCase();
    final filtered = _kLogpomFallbacks
        .where((f) => f.name.toLowerCase().contains(q) || f.area.toLowerCase().contains(q))
        .map((f) => _PlaceSuggestion(
      placeId:       'fallback_${f.name}',
      mainText:      f.name,
      secondaryText: f.area,
      isFallback:    true,
    ))
        .toList();
    final results = filtered.isNotEmpty
        ? filtered
        : _kLogpomFallbacks
        .map((f) => _PlaceSuggestion(
      placeId:       'fallback_${f.name}',
      mainText:      f.name,
      secondaryText: f.area,
      isFallback:    true,
    ))
        .toList();
    if (mounted) {
      setState(() {
        _suggestions    = results;
        _showDropdown   = results.isNotEmpty;
        _loadingSuggest = false;
        _usedFallback   = true;
      });
    }
  }

  Future<void> _selectSuggestion(_PlaceSuggestion suggestion) async {
    setState(() { _showDropdown = false; });

    if (suggestion.isFallback) {
      final fb = _kLogpomFallbacks.firstWhere(
        (f) => 'fallback_${f.name}' == suggestion.placeId,
        orElse: () => const _FallbackPlace('', '', 4.0280, 9.7445),
      );
      if (mounted) {
        setState(() {
          _dropoffLat             = fb.lat;
          _dropoffLng             = fb.lng;
          _dropoffAddress         = '${suggestion.mainText}, ${suggestion.secondaryText}';
          _dropoffSearchCtrl.text = suggestion.mainText;
        });
      }
      return;
    }

    // Mapbox features already carry coordinates — no second API call needed.
    if (suggestion.lat != null && suggestion.lng != null) {
      if (mounted) {
        setState(() {
          _dropoffLat             = suggestion.lat;
          _dropoffLng             = suggestion.lng;
          _dropoffAddress         = suggestion.secondaryText.isNotEmpty
              ? '${suggestion.mainText}, ${suggestion.secondaryText}'
              : suggestion.mainText;
          _dropoffSearchCtrl.text = suggestion.mainText;
        });
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:         Text('Could not resolve address. Try searching again.'),
        backgroundColor: AppColors.error,
        behavior:        SnackBarBehavior.floating,
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────

  void _next() {
    if (!_canProceed) {
      _showError(_pickupLat == null
          ? 'Tap "Use my location" to set pickup'
          : 'Search and select a dropoff address');
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DeliveryStep2Package(
        deliveryType:    widget.deliveryType,
        accessToken:     widget.accessToken,
        pickupLat:       _pickupLat!,
        pickupLng:       _pickupLng!,
        pickupAddress:   _pickupAddressCtrl.text.trim(),
        pickupLandmark:  '',
        dropoffLat:      _dropoffLat!,
        dropoffLng:      _dropoffLng!,
        dropoffAddress:  _dropoffAddress ?? _dropoffSearchCtrl.text.trim(),
        dropoffLandmark: '',
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
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fade,
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showDropdown = false),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  child: Column(
                    children: [
                      _buildRouteCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
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
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isExpress ? '⚡' : '📦',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 8),
          Text(
            _isExpress ? 'Express Delivery' : 'Regular Delivery',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // ── Step indicator ─────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    const steps = ['Location', 'Package', 'Confirm'];
    return Container(
      color: AppColors.primaryDark,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Row(
        children: List.generate(3, (i) {
          final step   = i + 1;
          final done   = step < 1;
          final active = step == 1;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.success
                            : active
                            ? AppColors.primaryGold
                            : Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: active
                            ? Border.all(
                            color: AppColors.primaryGold.withOpacity(0.4),
                            width: 3)
                            : null,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                            : Text(
                          '$step',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? AppColors.primaryDark
                                : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10,
                        fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400,
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
                if (i < 2)
                  Expanded(
                    child: Container(
                      height: 1.5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: done
                              ? [AppColors.success, AppColors.success]
                              : [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.08),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Combined route card ────────────────────────────────────────────────────
  // Single unified card with pickup + visual connector + dropoff

  Widget _buildRouteCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header bar ───────────────────────────────────────────────────
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded,
                    color: AppColors.primaryGold, size: 18),
                const SizedBox(width: 10),
                const Text(
                  'Set Your Route',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (_canProceed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_rounded,
                            size: 12, color: AppColors.primaryDark),
                        SizedBox(width: 4),
                        Text(
                          'Route ready',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Timeline line ─────────────────────────────────────────
                  _buildTimeline(),
                  const SizedBox(width: 14),
                  // ── Fields ───────────────────────────────────────────────
                  Expanded(
                    child: Column(
                      children: [
                        _buildPickupSection(),
                        const SizedBox(height: 16),
                        _buildDropoffSection(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Timeline visual (dots + connector line) ──────────────────────────────

  Widget _buildTimeline() {
    final pickupSet = _pickupLat != null;
    final dropoffSet = _dropoffLat != null;

    return SizedBox(
      width: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pickupSet ? AppColors.primaryDark : Colors.white,
              border: Border.all(
                color: pickupSet
                    ? AppColors.primaryDark
                    : AppColors.borderLight,
                width: 2.5,
              ),
              boxShadow: pickupSet
                  ? [
                BoxShadow(
                  color: AppColors.primaryDark.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
                  : null,
            ),
            child: pickupSet
                ? const Icon(
              Icons.my_location_rounded,
              size: 11,
              color: Colors.white,
            )
                : null,
          ),

          const SizedBox(height: 8),

          SizedBox(
            height: 72,
            child: _DashedLine(
              color: _canProceed
                  ? AppColors.success
                  : AppColors.borderMedium,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dropoffSet ? _accentColor : Colors.white,
              border: Border.all(
                color: dropoffSet ? _accentColor : AppColors.borderLight,
                width: 2.5,
              ),
              boxShadow: dropoffSet
                  ? [
                BoxShadow(
                  color: _accentColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
                  : null,
            ),
            child: dropoffSet
                ? Icon(
              Icons.flag_rounded,
              size: 11,
              color: _isExpress
                  ? AppColors.primaryDark
                  : Colors.white,
            )
                : null,
          ),
        ],
      ),
    );
  }

  // ── Pickup section ──────────────────────────────────────────────────────

  Widget _buildPickupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PICKUP',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textLight,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        _buildGpsStatus(),
      ],
    );
  }

  Widget _buildGpsStatus() {
    // Loading state
    if (_gpsLoading) {
      return _locationTile(
        bg: const Color(0xFFF0F4FF),
        border: AppColors.info,
        leading: const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColors.info),
        ),
        text: 'Detecting your location…',
        subtext: 'Please wait',
        textColor: AppColors.info,
      );
    }

    // Set — show address + refresh button
    if (_pickupLat != null) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withOpacity(0.25)),
        ),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.my_location_rounded,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Location',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _pickupAddressCtrl.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _fetchGps,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Icon(Icons.refresh_rounded,
                    size: 14, color: AppColors.success),
              ),
            ),
          ],
        ),
      );
    }

    // Not yet set — tap to fetch
    return GestureDetector(
      onTap: _fetchGps,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryDark,
              AppColors.primaryDark.withOpacity(0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.25),
                blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.my_location_rounded,
                  color: AppColors.primaryGold, size: 17),
            ),
            const SizedBox(width: 12),
            const Text(
              'Use my current location',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: AppColors.primaryGold, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Dropoff section ──────────────────────────────────────────────────────

  Widget _buildDropoffSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DROPOFF',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textLight,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        // Confirmed state
        if (_dropoffLat != null && !_showDropdown) ...[
          Container(
            decoration: BoxDecoration(
              color: _isExpress
                  ? AppColors.primaryGold.withOpacity(0.08)
                  : AppColors.successLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isExpress
                    ? AppColors.primaryGold.withOpacity(0.35)
                    : AppColors.success.withOpacity(0.25),
              ),
            ),
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.flag_rounded,
                      size: 16, color: _accentFg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Destination Set',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isExpress
                              ? const Color(0xFFB8860B)
                              : AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dropoffAddress ?? _dropoffSearchCtrl.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _dropoffLat     = null;
                    _dropoffLng     = null;
                    _dropoffAddress = null;
                    _dropoffSearchCtrl.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.borderLight),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        size: 14, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Search field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _showDropdown
                    ? _accentColor.withOpacity(0.5)
                    : AppColors.borderLight,
                width: _showDropdown ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: _loadingSuggest
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryDark))
                      : Icon(Icons.search_rounded,
                      size: 18,
                      color: _showDropdown
                          ? _accentColor
                          : AppColors.textLight),
                ),
                Expanded(
                  child: TextField(
                    controller: _dropoffSearchCtrl,
                    onChanged: _onDropoffSearchChanged,
                    style: AppTypography.inputText
                        .copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search destination…',
                      hintStyle: AppTypography.inputHint
                          .copyWith(fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 14),
                    ),
                  ),
                ),
                if (_dropoffSearchCtrl.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _dropoffSearchCtrl.clear();
                      setState(() {
                        _suggestions  = [];
                        _showDropdown = false;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: AppColors.textLight),
                    ),
                  ),
              ],
            ),
          ),
        ],

        // Offline notice
        if (_usedFallback && _showDropdown) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 12, color: AppColors.warning),
              const SizedBox(width: 5),
              Text(
                'Offline — showing Douala landmarks',
                style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    color: AppColors.warning),
              ),
            ],
          ),
        ],

        // Suggestions dropdown
        if (_showDropdown && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16, offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: _suggestions
                    .asMap()
                    .entries
                    .map((e) => _buildSuggestionTile(
                    e.value, e.key == _suggestions.length - 1))
                    .toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestionTile(_PlaceSuggestion s, bool isLast) {
    return Column(
      children: [
        InkWell(
          onTap: () => _selectSuggestion(s),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: s.isFallback
                        ? AppColors.warning.withOpacity(0.1)
                        : AppColors.primaryDark.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    s.isFallback
                        ? Icons.push_pin_outlined
                        : Icons.location_on_outlined,
                    color: s.isFallback
                        ? AppColors.warning
                        : AppColors.primaryDark,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.mainText,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (s.secondaryText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.textLight),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 58, color: AppColors.borderLight),
      ],
    );
  }

  // ── Helper: generic location tile ──────────────────────────────────────────

  Widget _locationTile({
    required Color bg,
    required Color border,
    required Widget leading,
    required String text,
    required String subtext,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              Text(subtext,
                  style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11,
                      color: AppColors.textLight)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────

  Widget _buildNextBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: SizedBox(
        width: double.infinity, height: 54,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          child: ElevatedButton(
            onPressed: _canProceed ? _next : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canProceed ? _accentColor : const Color(0xFFE5E8EF),
              foregroundColor: _canProceed ? _accentFg : AppColors.textLight,
              disabledBackgroundColor: const Color(0xFFE5E8EF),
              elevation: _canProceed ? 2 : 0,
              shadowColor: _accentColor.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_canProceed)
                  const Icon(Icons.lock_outline_rounded, size: 16),
                if (!_canProceed) const SizedBox(width: 8),
                Text(
                  _canProceed
                      ? 'Continue to Package Details'
                      : 'Set both locations first',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                if (_canProceed) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHED LINE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final totalHeight = constraints.maxHeight;
      const dashH = 5.0;
      const gapH  = 4.0;
      final count = (totalHeight / (dashH + gapH)).floor();
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (_) => Container(
          width: 2,
          height: dashH,
          margin: const EdgeInsets.only(bottom: gapH),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        )),
      );
    });
  }
}
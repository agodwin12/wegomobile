import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MapStyle {
  streets,
  satellite,
  satelliteStreets,
  navigationDay,
  navigationNight,
  light,
  dark,
  outdoors,
}

extension MapStyleX on MapStyle {
  String get label => switch (this) {
    MapStyle.streets         => 'Streets',
    MapStyle.satellite       => 'Satellite',
    MapStyle.satelliteStreets=> 'Sat + Roads',
    MapStyle.navigationDay   => 'Nav Day',
    MapStyle.navigationNight => 'Nav Night',
    MapStyle.light           => 'Light',
    MapStyle.dark            => 'Dark',
    MapStyle.outdoors        => 'Outdoors',
  };

  // LocationIQ (OpenStreetMap) tile styles. LocationIQ offers streets / light /
  // dark; the Mapbox-only styles (satellite, navigation, outdoors) fall back to
  // the closest LocationIQ equivalent.
  String get _liqStyle => switch (this) {
    MapStyle.dark || MapStyle.navigationNight => 'dark',
    MapStyle.light || MapStyle.navigationDay  => 'light',
    _                                          => 'streets',
  };

  /// LocationIQ raster tiles. `key` is the LocationIQ access token.
  String tileUrl(String key) =>
      'https://tiles.locationiq.com/v3/$_liqStyle/r/{z}/{x}/{y}.png?key=$key';

  IconData get icon => switch (this) {
    MapStyle.streets         => Icons.map_outlined,
    MapStyle.satellite       => Icons.satellite_alt_outlined,
    MapStyle.satelliteStreets=> Icons.satellite_outlined,
    MapStyle.navigationDay   => Icons.wb_sunny_outlined,
    MapStyle.navigationNight => Icons.nights_stay_outlined,
    MapStyle.light           => Icons.brightness_5_outlined,
    MapStyle.dark            => Icons.brightness_2_outlined,
    MapStyle.outdoors        => Icons.terrain_outlined,
  };

  Color get swatch => switch (this) {
    MapStyle.streets         => const Color(0xFF4A90E2),
    MapStyle.satellite       => const Color(0xFF6B5E3E),
    MapStyle.satelliteStreets=> const Color(0xFF5C7A4E),
    MapStyle.navigationDay   => const Color(0xFFE8B84B),
    MapStyle.navigationNight => const Color(0xFF1A2F5E),
    MapStyle.light           => const Color(0xFFD0D8E8),
    MapStyle.dark            => const Color(0xFF2C2C3E),
    MapStyle.outdoors        => const Color(0xFF4E7A4A),
  };

  Color get labelColor => switch (this) {
    MapStyle.light           => const Color(0xFF333344),
    MapStyle.streets         => Colors.white,
    _                        => Colors.white,
  };
}

const _kPrefKey = 'wego_map_style';

Future<MapStyle> loadMapStylePref() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kPrefKey);
  return MapStyle.values.firstWhere(
    (s) => s.name == saved,
    orElse: () => MapStyle.streets,
  );
}

Future<void> saveMapStylePref(MapStyle style) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kPrefKey, style.name);
}

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

  String get _styleId => switch (this) {
    MapStyle.streets         => 'streets-v12',
    MapStyle.satellite       => 'satellite-v9',
    MapStyle.satelliteStreets=> 'satellite-streets-v12',
    MapStyle.navigationDay   => 'navigation-day-v1',
    MapStyle.navigationNight => 'navigation-night-v1',
    MapStyle.light           => 'light-v11',
    MapStyle.dark            => 'dark-v11',
    MapStyle.outdoors        => 'outdoors-v12',
  };

  String tileUrl(String token) =>
      'https://api.mapbox.com/styles/v1/mapbox/$_styleId/tiles/{z}/{x}/{y}?access_token=$token';

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

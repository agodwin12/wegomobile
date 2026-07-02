import 'package:flutter_tts/flutter_tts.dart';

/// Spoken guidance for the passenger during a ride.
///
/// French by default (the app's default language). Every method is safe to
/// call from anywhere — it lazily initialises TTS, never throws, and de-dupes
/// consecutive identical phrases so we don't repeat announcements.
class VoiceGuide {
  VoiceGuide._();
  static final VoiceGuide instance = VoiceGuide._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool enabled = true;
  String _lang = 'fr-FR';
  String? _last;

  /// Switch spoken language ('fr-FR' default, 'en-US' when the user picks EN).
  Future<void> setLanguage(String code) async {
    _lang = code;
    _ready = false; // re-init with the new language on next speak
  }

  Future<void> _init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage(_lang);
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _ready = true;
    } catch (_) {/* TTS unavailable — stay silent */}
  }

  Future<void> say(String phrase, {bool force = false}) async {
    if (!enabled || phrase.trim().isEmpty) return;
    if (!force && phrase == _last) return;
    _last = phrase;
    try {
      await _init();
      await _tts.stop();
      await _tts.speak(phrase);
    } catch (_) {}
  }

  bool get _fr => _lang.startsWith('fr');

  // ── Ride lifecycle phrases ────────────────────────────────────────────────
  Future<void> driverFound(String name) => say(_fr
      ? '$name a accepté votre course et arrive vers vous.'
      : '$name accepted your ride and is on the way.');

  Future<void> driverArriving() =>
      say(_fr ? 'Votre chauffeur approche.' : 'Your driver is approaching.');

  Future<void> driverArrived() =>
      say(_fr ? 'Votre chauffeur est arrivé.' : 'Your driver has arrived.');

  Future<void> tripStarted() => say(_fr
      ? 'Votre course a commencé. Bon voyage.'
      : 'Your trip has started. Enjoy your ride.');

  Future<void> approachingDestination() => say(_fr
      ? 'Vous approchez de votre destination.'
      : 'You are approaching your destination.');

  Future<void> tripCompleted() => say(_fr
      ? 'Vous êtes arrivé à destination.'
      : 'You have arrived at your destination.');

  /// Turn-by-turn line, e.g. maneuver "Tournez à droite" + distance 10 m.
  Future<void> maneuver(String instruction, {int? meters}) {
    if (meters != null && meters > 0) {
      final d = _fr ? 'dans $meters mètres' : 'in $meters meters';
      return say('$instruction $d');
    }
    return say(instruction);
  }

  Future<void> stop() async {
    try { await _tts.stop(); } catch (_) {}
  }
}

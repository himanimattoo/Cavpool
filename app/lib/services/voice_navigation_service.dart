import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:logger/logger.dart';
import '../utils/units_formatter.dart';
import '../models/user_model.dart';

class VoiceNavigationService {
  static final VoiceNavigationService _instance = VoiceNavigationService._internal();
  factory VoiceNavigationService() => _instance;
  VoiceNavigationService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final Logger _logger = Logger();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isEnabled = true;

  // Voice settings
  double _volume = 0.8;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  String _language = 'en-US';

  // Initialize TTS
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage(_language);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);

      // Set up completion handler
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _logger.d('TTS completion handler called');
      });

      // Set up error handler
      _flutterTts.setErrorHandler((message) {
        _isSpeaking = false;
        _logger.e('TTS error: $message');
      });

      _isInitialized = true;
      _logger.i('Voice Navigation Service initialized');
    } catch (e) {
      _logger.e('Error initializing TTS: $e');
    }
  }

  // Speak a navigation instruction
  Future<void> speak(String text) async {
    if (!_isEnabled || !_isInitialized) return;
    
    try {
      // Stop any current speech
      await stop();
      
      _isSpeaking = true;
      _logger.d('Speaking: $text');
      await _flutterTts.speak(text);
    } catch (e) {
      _logger.e('Error speaking: $e');
      _isSpeaking = false;
    }
  }

  // Stop current speech
  Future<void> stop() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
    }
  }

  // Pause current speech
  Future<void> pause() async {
    if (_isSpeaking) {
      await _flutterTts.pause();
    }
  }

  // Resume paused speech
  Future<void> resume() async {
    await _flutterTts.speak('');
  }

  // Navigation-specific voice instructions
  Future<void> announceInstruction(String instruction, {int? distanceMeters, UserPreferences? userPreferences}) async {
    if (!_isEnabled) return;

    String announcement = '';
    
    if (distanceMeters != null) {
      if (distanceMeters < 50) {
        announcement = 'Now, $instruction';
      } else {
        final formattedDistance = _formatDistance(distanceMeters, userPreferences);
        announcement = 'In $formattedDistance, $instruction';
      }
    } else {
      announcement = instruction;
    }

    await speak(announcement);
  }

  // Announce arrival
  Future<void> announceArrival(String destination) async {
    await speak('You have arrived at $destination');
  }

  // Announce route calculation
  Future<void> announceRouteCalculated(String duration, String distance, {UserPreferences? userPreferences}) async {
    // Convert distance to voice-friendly format if it contains abbreviations
    // Order matters: replace longer patterns first to avoid partial matches
    String voiceDistance = distance
        .replaceAll(' km', ' kilometers')
        .replaceAll(' mi', ' miles')
        .replaceAll(' ft', ' feet')
        .replaceAll(' m', ' meters');
    
    await speak('Route calculated. Your trip will take approximately $duration and cover $voiceDistance');
  }

  // Announce rerouting
  Future<void> announceRerouting() async {
    await speak('Recalculating route');
  }

  // Format distance for voice announcements using user's preferred units
  String _formatDistance(int meters, UserPreferences? userPreferences) {
    try {
      final unit = UnitsFormatter.getUnitFromPreferences(userPreferences);
      final formatted = UnitsFormatter.formatDistance(meters.toDouble(), unit: unit);
      
      // Make the announcement more natural for voice
      // Order matters: replace longer patterns first to avoid partial matches
      return formatted
          .replaceAll(' mi', ' miles')
          .replaceAll(' km', ' kilometers')
          .replaceAll(' ft', ' feet')
          .replaceAll(' m', ' meters');
    } catch (e) {
      // Fallback to metric if user preferences not available
      if (meters < 100) {
        final rounded = (meters / 10).round() * 10;
        return '$rounded meters';
      } else if (meters < 1000) {
        final rounded = (meters / 50).round() * 50;
        return '$rounded meters';
      } else {
        final km = meters / 1000;
        if (km < 10) {
          return '${km.toStringAsFixed(1)} kilometers';
        } else {
          return '${km.round()} kilometers';
        }
      }
    }
  }

  // Settings getters and setters
  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;
  double get volume => _volume;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  String get language => _language;

  set isEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stop();
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_isInitialized) {
      await _flutterTts.setVolume(_volume);
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    if (_isInitialized) {
      await _flutterTts.setSpeechRate(_speechRate);
    }
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    if (_isInitialized) {
      await _flutterTts.setPitch(_pitch);
    }
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    if (_isInitialized) {
      await _flutterTts.setLanguage(_language);
    }
  }

  // Get available languages
  Future<List<String>> getAvailableLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return List<String>.from(languages);
    } catch (e) {
      _logger.e('Error getting available languages: $e');
      return ['en-US'];
    }
  }

  // Test voice output
  Future<void> testVoice() async {
    await speak('Voice navigation is working correctly');
  }

  // Test distance announcement with user preferences
  Future<void> testDistanceAnnouncement({UserPreferences? userPreferences}) async {
    const testDistanceMeters = 500;
    final formattedDistance = _formatDistance(testDistanceMeters, userPreferences);
    await speak('Test: In $formattedDistance, turn right');
  }

  // Dispose resources
  Future<void> dispose() async {
    await stop();
    _isInitialized = false;
  }
}
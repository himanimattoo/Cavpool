import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:logger/logger.dart';
import '../services/directions_service.dart';
import '../services/voice_navigation_service.dart';
import '../models/user_model.dart';

enum NavigationState {
  idle,
  calculating,
  navigating,
  completed,
  error
}

class NavigationProvider with ChangeNotifier {
  final Logger _logger = Logger();
  final VoiceNavigationService _voiceService = VoiceNavigationService();
  
  // User preferences for unit formatting
  UserPreferences? _userPreferences;
  
  // Navigation state
  NavigationState _state = NavigationState.idle;
  DirectionsResult? _route;
  List<DirectionStep> _steps = [];
  int _currentStepIndex = 0;
  LatLng? _currentLocation;
  StreamSubscription<Position>? _locationSubscription;
  
  // Progress tracking
  double _totalDistanceMeters = 0;
  double _remainingDistanceMeters = 0;
  Duration _totalDuration = Duration.zero;
  Duration _remainingDuration = Duration.zero;
  DateTime? _estimatedArrival;
  double _progressPercentage = 0.0;
  DateTime? _navigationStartTime;
  
  // Settings
  bool _voiceEnabled = true;
  final double _stepAdvanceThreshold = 20.0; // meters
  final int _voiceAnnouncementDistance = 100; // meters
  bool _hasAnnouncedCurrentStep = false;

  // Getters
  NavigationState get state => _state;
  DirectionsResult? get route => _route;
  List<DirectionStep> get steps => _steps;
  int get currentStepIndex => _currentStepIndex;
  DirectionStep? get currentStep => _currentStepIndex < _steps.length ? _steps[_currentStepIndex] : null;
  DirectionStep? get nextStep => _currentStepIndex + 1 < _steps.length ? _steps[_currentStepIndex + 1] : null;
  LatLng? get currentLocation => _currentLocation;
  double get totalDistanceMeters => _totalDistanceMeters;
  double get remainingDistanceMeters => _remainingDistanceMeters;
  Duration get totalDuration => _totalDuration;
  Duration get remainingDuration => _remainingDuration;
  DateTime? get estimatedArrival => _estimatedArrival;
  double get progressPercentage => _progressPercentage;
  bool get voiceEnabled => _voiceEnabled;
  
  // Distance to next step
  double get distanceToNextStep {
    if (currentStep == null || _currentLocation == null) return 0.0;
    return Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      currentStep!.endLocation.latitude,
      currentStep!.endLocation.longitude,
    );
  }

  // Initialize navigation
  Future<bool> startNavigation(LatLng origin, LatLng destination) async {
    try {
      _setState(NavigationState.calculating);
      
      // Initialize voice service
      await _voiceService.initialize();
      
      // Get route
      final directionsService = DirectionsService();
      final result = await directionsService.getDirections(
        origin: origin,
        destination: destination,
      );
      
      if (result == null) {
        _setState(NavigationState.error);
        return false;
      }
      
      _route = result;
      _steps = result.steps;
      _currentStepIndex = 0;
      _hasAnnouncedCurrentStep = false;
      
      // Parse total distance and duration
      _totalDistanceMeters = _parseDistance(result.totalDistance);
      _remainingDistanceMeters = _totalDistanceMeters;
      _totalDuration = _parseDuration(result.totalDuration);
      _remainingDuration = _totalDuration;
      _navigationStartTime = DateTime.now();
      _updateEstimatedArrival();
      
      // Start location tracking
      await _startLocationTracking();
      
      // Announce route
      if (_voiceEnabled && _voiceService.isEnabled) {
        await _voiceService.announceRouteCalculated(
          result.totalDuration,
          result.totalDistance,
        );
      }
      
      _setState(NavigationState.navigating);
      _logger.i('Navigation started with ${_steps.length} steps');
      return true;
      
    } catch (e) {
      _logger.e('Error starting navigation: $e');
      _setState(NavigationState.error);
      return false;
    }
  }

  // Start location tracking
  Future<void> _startLocationTracking() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_onLocationUpdate);
  }

  // Handle location updates
  void _onLocationUpdate(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);
    _currentLocation = newLocation;
    
    if (_state != NavigationState.navigating || currentStep == null) return;
    
    // Calculate remaining distance to destination
    final destination = _steps.last.endLocation;
    _remainingDistanceMeters = Geolocator.distanceBetween(
      newLocation.latitude,
      newLocation.longitude,
      destination.latitude,
      destination.longitude,
    );
    
    // Update progress
    _progressPercentage = ((_totalDistanceMeters - _remainingDistanceMeters) / _totalDistanceMeters).clamp(0.0, 1.0);
    
    // Check if we should advance to next step
    _checkStepAdvancement(newLocation);
    
    // Check if we should announce the current step
    _checkVoiceAnnouncement(newLocation);
    
    // Update ETA
    _updateEstimatedArrival();
    
    // Check if we've arrived
    if (_remainingDistanceMeters < 20 && _currentStepIndex >= _steps.length - 1) {
      _completeNavigation();
    }
    
    _safeNotifyListeners();
  }

  // Check if we should advance to the next step
  void _checkStepAdvancement(LatLng currentLocation) {
    if (currentStep == null) return;
    
    final distanceToStepEnd = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      currentStep!.endLocation.latitude,
      currentStep!.endLocation.longitude,
    );
    
    if (distanceToStepEnd <= _stepAdvanceThreshold) {
      _advanceToNextStep();
    }
  }

  // Check if we should announce the current step
  void _checkVoiceAnnouncement(LatLng currentLocation) {
    if (!_voiceEnabled || !_voiceService.isEnabled || _hasAnnouncedCurrentStep) return;
    if (currentStep == null) return;
    
    final distanceToStepEnd = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      currentStep!.endLocation.latitude,
      currentStep!.endLocation.longitude,
    );
    
    if (distanceToStepEnd <= _voiceAnnouncementDistance) {
      _announceCurrentStep();
    }
  }

  // Advance to next navigation step
  void _advanceToNextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      _hasAnnouncedCurrentStep = false;
      _logger.d('Advanced to step ${_currentStepIndex + 1}/${_steps.length}');
      
      // Announce next step immediately if we're close
      if (_currentLocation != null && distanceToNextStep <= _voiceAnnouncementDistance) {
        _announceCurrentStep();
      }
    }
  }

  // Announce current step via voice
  Future<void> _announceCurrentStep() async {
    if (currentStep == null || _hasAnnouncedCurrentStep) return;
    
    final instruction = _cleanHtmlInstruction(currentStep!.instruction);
    final distance = distanceToNextStep.round();
    
    await _voiceService.announceInstruction(instruction, distanceMeters: distance, userPreferences: _userPreferences);
    _hasAnnouncedCurrentStep = true;
    _logger.d('Announced step: $instruction');
  }

  // Clean HTML from instruction text
  String _cleanHtmlInstruction(String htmlInstruction) {
    return htmlInstruction
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  // Update estimated arrival time
  void _updateEstimatedArrival() {
    if (_remainingDistanceMeters <= 0) {
      _estimatedArrival = DateTime.now();
      _remainingDuration = Duration.zero;
      return;
    }
    
    // Calculate time based on progress made and remaining distance
    final completedDistance = _totalDistanceMeters - _remainingDistanceMeters;
    
    if (completedDistance > 0) {
      // Use actual travel time to calculate realistic speed
      final elapsedTime = DateTime.now().difference(_navigationStartTime ?? DateTime.now());
      final actualSpeed = completedDistance / elapsedTime.inSeconds; // meters per second
      
      // Apply minimum speed of 5 m/s (18 km/h) to handle stopped/slow periods
      final effectiveSpeed = actualSpeed > 0 ? actualSpeed.clamp(5.0, 50.0) : 15.0; // Default 15 m/s (54 km/h)
      
      final remainingSeconds = (_remainingDistanceMeters / effectiveSpeed).round();
      _remainingDuration = Duration(seconds: remainingSeconds);
    } else {
      // Fallback to original route estimate if no progress made
      final progressRatio = _progressPercentage.clamp(0.01, 1.0);
      final estimatedRemainingSeconds = (_totalDuration.inSeconds * (1 - progressRatio)).round();
      _remainingDuration = Duration(seconds: estimatedRemainingSeconds);
    }
    
    _estimatedArrival = DateTime.now().add(_remainingDuration);
  }

  // Complete navigation
  void _completeNavigation() async {
    if (_state != NavigationState.navigating) return;
    
    _setState(NavigationState.completed);
    
    if (_voiceEnabled && _voiceService.isEnabled) {
      await _voiceService.announceArrival('your destination');
    }
    
    _logger.i('Navigation completed');
  }

  // Stop navigation
  Future<void> stopNavigation() async {
    try {
      // Stop location tracking first
      await _locationSubscription?.cancel();
      _locationSubscription = null;
      
      // Stop voice service
      await _voiceService.stop();
      
      // Reset state
      _setState(NavigationState.idle);
      _route = null;
      _steps = [];
      _currentStepIndex = 0;
      _currentLocation = null;
      _progressPercentage = 0.0;
      _remainingDistanceMeters = 0.0;
      _remainingDuration = Duration.zero;
      _estimatedArrival = null;
      _navigationStartTime = null;
      _hasAnnouncedCurrentStep = false;
      
      _logger.i('Navigation stopped');
    } catch (e) {
      _logger.e('Error stopping navigation: $e');
      // Force state reset even if there were errors
      _state = NavigationState.idle;
    }
  }

  // Settings
  void setUserPreferences(UserPreferences? preferences) {
    _userPreferences = preferences;
    _logger.d('Updated user preferences for navigation');
  }

  // Pause and resume navigation
  void pauseNavigation() {
    if (_state == NavigationState.navigating) {
      // Pause voice announcements
      _voiceService.stop();
      _logger.i('Navigation paused');
    }
  }
  
  void resumeNavigation() {
    if (_state == NavigationState.navigating) {
      // Reset voice announcement flag to allow new announcements
      _hasAnnouncedCurrentStep = false;
      _logger.i('Navigation resumed');
      
      // Announce current step if we're in range
      if (_currentLocation != null && distanceToNextStep <= _voiceAnnouncementDistance) {
        _announceCurrentStep();
      }
    }
  }

  void setVoiceEnabled(bool enabled) {
    _voiceEnabled = enabled;
    _voiceService.isEnabled = enabled;
    _safeNotifyListeners();
  }

  Future<void> setVoiceSettings({
    double? volume,
    double? speechRate,
    double? pitch,
  }) async {
    if (volume != null) await _voiceService.setVolume(volume);
    if (speechRate != null) await _voiceService.setSpeechRate(speechRate);
    if (pitch != null) await _voiceService.setPitch(pitch);
  }

  // Helper methods
  void _setState(NavigationState newState) {
    if (_state != newState) {
      _state = newState;
      _safeNotifyListeners();
    }
  }
  
  void _safeNotifyListeners() {
    try {
      notifyListeners();
    } catch (e) {
      // Ignore notification errors if listeners are disposed
      _logger.w('Error notifying listeners: $e');
    }
  }

  double _parseDistance(String distance) {
    final match = RegExp(r'([\d.]+)\s*(km|m)').firstMatch(distance.toLowerCase());
    if (match != null) {
      final value = double.tryParse(match.group(1) ?? '0') ?? 0;
      final unit = match.group(2);
      return unit == 'km' ? value * 1000 : value;
    }
    return 0;
  }

  Duration _parseDuration(String duration) {
    final hours = RegExp(r'(\d+)\s*hour').firstMatch(duration);
    final minutes = RegExp(r'(\d+)\s*min').firstMatch(duration);
    
    int totalMinutes = 0;
    if (hours != null) {
      totalMinutes += (int.tryParse(hours.group(1) ?? '0') ?? 0) * 60;
    }
    if (minutes != null) {
      totalMinutes += int.tryParse(minutes.group(1) ?? '0') ?? 0;
    }
    
    return Duration(minutes: totalMinutes);
  }

  // Update navigation to a new destination without resetting step index
  Future<bool> updateDestination(LatLng destination) async {
    try {
      if (_currentLocation == null) {
        _logger.w('Cannot update destination: current location not available');
        return false;
      }
      
      _setState(NavigationState.calculating);
      
      // Get route to new destination
      final directionsService = DirectionsService();
      final result = await directionsService.getDirections(
        origin: _currentLocation!,
        destination: destination,
      );
      
      if (result == null) {
        _setState(NavigationState.error);
        return false;
      }
      
      // Update route without resetting step index
      _route = result;
      _steps = result.steps;
      // Keep current step index for optimized route tracking
      _hasAnnouncedCurrentStep = false;
      
      // Parse total distance and duration for this segment
      _totalDistanceMeters = _parseDistance(result.totalDistance);
      _remainingDistanceMeters = _totalDistanceMeters;
      _totalDuration = _parseDuration(result.totalDuration);
      _remainingDuration = _totalDuration;
      _updateEstimatedArrival();
      
      _setState(NavigationState.navigating);
      _logger.i('Navigation updated to new destination with ${_steps.length} steps');
      return true;
      
    } catch (e) {
      _logger.e('Error updating navigation destination: $e');
      _setState(NavigationState.error);
      return false;
    }
  }

  // Method for simulation - update current location manually
  void updateCurrentLocation(LatLng location) {
    _currentLocation = location;
    
    if (_state == NavigationState.navigating && currentStep != null) {
      // Calculate remaining distance to destination
      final destination = _steps.last.endLocation;
      _remainingDistanceMeters = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        destination.latitude,
        destination.longitude,
      );
      
      // Update progress
      _progressPercentage = ((_totalDistanceMeters - _remainingDistanceMeters) / _totalDistanceMeters).clamp(0.0, 1.0);
      
      // Check if we should advance to next step
      _checkStepAdvancement(location);
      
      // Check if we should announce the current step
      _checkVoiceAnnouncement(location);
      
      // Update ETA
      _updateEstimatedArrival();
      
      // Check if we've arrived
      if (_remainingDistanceMeters < 20 && _currentStepIndex >= _steps.length - 1) {
        _completeNavigation();
      }
    }
    
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    stopNavigation();
    super.dispose();
  }
}
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:logger/logger.dart';
import '../models/ride_model.dart';
import '../services/driver_status_service.dart';
import '../services/request_notification_service.dart';
import '../services/active_ride_management_service.dart';
import '../services/ride_service.dart';
import '../services/message_service.dart';
import '../models/message_model.dart';

class DriverProvider extends ChangeNotifier {
  final DriverStatusService _driverStatusService = DriverStatusService();
  final RequestNotificationService _notificationService = RequestNotificationService();
  final ActiveRideManagementService _rideManagementService = ActiveRideManagementService();
  final RideService _rideService = RideService();
  final MessageService _messageService = MessageService();
  final Logger _logger = Logger();

  // Driver status state
  DriverStatus _currentStatus = DriverStatus.offline;
  bool _acceptingRequests = false;
  String? _currentDriverId;
  bool _isLoading = false;
  String? _errorMessage;

  // Active ride state
  ActiveRideInfo? _activeRide;
  String? _ignoredCompletedRideId;
  List<IncomingRequestNotification> _incomingRequests = [];

  // Subscriptions
  StreamSubscription? _statusSubscription;
  StreamSubscription? _requestsSubscription;
  StreamSubscription? _activeRideSubscription;

  // Getters
  DriverStatus get currentStatus => _currentStatus;
  bool get acceptingRequests => _acceptingRequests;
  bool get isOnline => _currentStatus == DriverStatus.online;
  bool get isBusy => _currentStatus == DriverStatus.busy;
  bool get isInRide => _currentStatus == DriverStatus.inRide;
  bool get isOffline => _currentStatus == DriverStatus.offline;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ActiveRideInfo? get activeRide => _activeRide;
  List<IncomingRequestNotification> get incomingRequests => _incomingRequests;
  bool get hasIncomingRequests => _incomingRequests.isNotEmpty;

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear active ride (used when ride is completed/cancelled)
  void clearActiveRide() {
    _activeRide = null;
    notifyListeners();
  }

  void finalizeCompletedRide(String rideId) {
    _ignoredCompletedRideId = rideId;
    clearActiveRide();
  }

  /// Initialize driver provider
  Future<void> initialize(String driverId) async {
    try {
      _isLoading = true;
      _currentDriverId = driverId;
      // Defer notification to prevent setState during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });

      // Note: Notification service doesn't need initialization

      // Get current driver status
      final status = await _driverStatusService.getCurrentDriverStatus();
      if (status != null) {
        _currentStatus = status.status;
        _acceptingRequests = status.acceptingRequests;
      }

      // Set up status monitoring
      _setupStatusMonitoring();

      // Set up request monitoring if online
      if (isOnline) {
        await _startRequestMonitoring();
      }

      // Set up active ride monitoring
      _setupActiveRideMonitoring();

      _isLoading = false;
      _errorMessage = null;
      
      // Defer final notification to prevent setState during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });

      _logger.i('Driver provider initialized for: $driverId');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to initialize driver: $e';
      
      // Defer error notification to prevent setState during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      _logger.e('Error initializing driver provider: $e');
    }
  }

  /// Set driver online
  Future<void> goOnline() async {
    if (_currentDriverId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      await _driverStatusService.setDriverOnline();
      await _startRequestMonitoring();

      _currentStatus = DriverStatus.online;
      _acceptingRequests = true;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();

      _logger.i('Driver is now online: $_currentDriverId');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to go online: $e';
      notifyListeners();
      _logger.e('Error going online: $e');
    }
  }

  /// Set driver offline
  Future<void> goOffline() async {
    if (_currentDriverId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      await _driverStatusService.setDriverOffline();
      await _stopRequestMonitoring();

      _currentStatus = DriverStatus.offline;
      _acceptingRequests = false;
      _incomingRequests.clear();
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();

      _logger.i('Driver is now offline: $_currentDriverId');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to go offline: $e';
      notifyListeners();
      _logger.e('Error going offline: $e');
    }
  }

  /// Toggle accepting requests
  Future<void> toggleAcceptingRequests() async {
    if (_currentDriverId == null) return;

    try {
      await _driverStatusService.toggleAcceptingRequests();
      _acceptingRequests = !_acceptingRequests;
      notifyListeners();

      _logger.i('Toggled accepting requests: $_acceptingRequests');
    } catch (e) {
      _errorMessage = 'Failed to toggle requests: $e';
      notifyListeners();
      _logger.e('Error toggling accepting requests: $e');
    }
  }

  /// Accept incoming request
  Future<void> acceptRequest(IncomingRequestNotification notification) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _notificationService.acceptRequest(notification.id);
      
      // Remove from incoming requests
      _incomingRequests.removeWhere((req) => req.id == notification.id);
      
      // Update status to busy
      await _driverStatusService.setDriverBusy(notification.requestId);
      _currentStatus = DriverStatus.busy;

      _isLoading = false;
      notifyListeners();

      _logger.i('Accepted request: ${notification.id}');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to accept request: $e';
      notifyListeners();
      _logger.e('Error accepting request: $e');
    }
  }

  /// Decline incoming request
  Future<void> declineRequest(IncomingRequestNotification notification, {String? reason}) async {
    try {
      await _notificationService.declineRequest(notification.id, reason: reason);
      
      // Remove from incoming requests
      _incomingRequests.removeWhere((req) => req.id == notification.id);
      notifyListeners();

      _logger.i('Declined request: ${notification.id}');
    } catch (e) {
      _errorMessage = 'Failed to decline request: $e';
      notifyListeners();
      _logger.e('Error declining request: $e');
    }
  }

  /// Start ride
  Future<void> startRide() async {
    if (_activeRide == null || _currentDriverId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Start the ride in the database and begin location sharing
      _logger.d('Starting ride with ID: ${_activeRide!.ride.id}');
      await _rideService.startRide(_activeRide!.ride.id, _currentDriverId!);
      
      // Update driver status
      await _driverStatusService.setDriverInRide(_activeRide!.ride.id);
      _currentStatus = DriverStatus.inRide;

      // Update local ride status to ensure immediate UI update
      if (_activeRide != null) {
        _activeRide = ActiveRideInfo(
          ride: _activeRide!.ride.copyWith(status: RideStatus.inProgress),
          passengers: _activeRide!.passengers,
          estimatedCompletion: _activeRide!.estimatedCompletion,
          totalDistance: _activeRide!.totalDistance,
          estimatedDuration: _activeRide!.estimatedDuration,
          driverInfo: _activeRide!.driverInfo,
        );
      }

      _isLoading = false;
      notifyListeners();

      _logger.i('Started ride: ${_activeRide!.ride.id}');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to start ride: $e';
      notifyListeners();
      _logger.e('Error starting ride: $e');
    }
  }

  /// Complete ride
  Future<void> completeRide() async {
    if (_activeRide == null || _currentDriverId == null) return;

    final rideId = _activeRide!.ride.id;
    final driverId = _currentDriverId!;

    try {
      _isLoading = true;
      _errorMessage = null; // Clear any previous errors
      notifyListeners();

      _logger.i('Starting ride completion for: $rideId');

      // Complete the ride in the database first
      await _rideService.completeRide(rideId, driverId);
      _logger.i('Ride completed in database');
      
      // Update driver status to available
      await _driverStatusService.setDriverAvailable();
      _logger.i('Driver status updated to available');
      
      // Update local state AFTER all async operations complete
      _currentStatus = DriverStatus.online;
      _acceptingRequests = true;
      
      // Clear loading state before clearing active ride to prevent UI race condition
      _isLoading = false;
      notifyListeners();
      
      // Brief delay to allow UI to update before clearing active ride
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Clear active ride last to prevent black screen
      _activeRide = null;
      notifyListeners();

      _logger.i('Ride completion successful for: $rideId');
    } catch (e) {
      _logger.e('Error completing ride $rideId: $e');
      
      // Even if there's an error, try to gracefully recover
      try {
        // Update status first, before clearing active ride
        _currentStatus = DriverStatus.online;
        _acceptingRequests = true;
        
        // Try to update driver status even if ride completion failed
        await _driverStatusService.setDriverAvailable();
        
        _logger.w('Graceful recovery completed despite error');
      } catch (recoveryError) {
        _logger.e('Recovery attempt also failed: $recoveryError');
      }
      
      _isLoading = false;
      _errorMessage = 'Ride completed with issues. Please check your status.';
      notifyListeners();
      
      // Brief delay before clearing active ride even in error case
      await Future.delayed(const Duration(milliseconds: 100));
      _activeRide = null;
      notifyListeners();
    }
  }

  /// Pick up passenger
  Future<void> pickupPassenger(String passengerId) async {
    if (_activeRide == null) return;

    try {
      await _rideManagementService.markPassengerPickedUp(_activeRide!.ride.id, passengerId);
      _logger.i('Picked up passenger: $passengerId');
    } catch (e) {
      _errorMessage = 'Failed to pickup passenger: $e';
      notifyListeners();
      _logger.e('Error picking up passenger: $e');
    }
  }

  /// Drop off passenger
  Future<void> dropoffPassenger(String passengerId) async {
    if (_activeRide == null) return;

    try {
      await _rideManagementService.markPassengerDroppedOff(_activeRide!.ride.id, passengerId);
      _logger.i('Dropped off passenger: $passengerId');
    } catch (e) {
      _errorMessage = 'Failed to dropoff passenger: $e';
      notifyListeners();
      _logger.e('Error dropping off passenger: $e');
    }
  }

  /// Call passenger
  Future<bool> callPassenger(String phoneNumber) async {
    try {
      return await _rideManagementService.callPassenger(phoneNumber);
    } catch (e) {
      _errorMessage = 'Failed to call passenger: $e';
      notifyListeners();
      _logger.e('Error calling passenger: $e');
      return false;
    }
  }

  /// Send message to passenger via in-app messaging
  Future<bool> sendSMSToPassenger(String phoneNumber, String message) async {
    if (_activeRide == null || _currentDriverId == null) {
      _errorMessage = 'No active ride to send message';
      notifyListeners();
      return false;
    }

    try {
      final rideId = _activeRide!.ride.id;
      await _messageService.sendMessage(
        rideId: rideId,
        senderId: _currentDriverId!,
        content: message,
      );
      
      _logger.i('Message sent to passenger: $message');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send message: $e';
      notifyListeners();
      _logger.e('Error sending message: $e');
      return false;
    }
  }

  /// Send message to a specific passenger
  Future<bool> sendMessageToPassenger(String passengerId, String message) async {
    if (_activeRide == null || _currentDriverId == null) {
      _errorMessage = 'No active ride to send message';
      notifyListeners();
      return false;
    }

    try {
      final rideId = _activeRide!.ride.id;
      await _messageService.sendMessage(
        rideId: rideId,
        senderId: _currentDriverId!,
        recipientId: passengerId, // Direct message to specific passenger
        content: message,
      );
      
      _logger.i('Message sent to passenger $passengerId: $message');
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send message: $e';
      notifyListeners();
      _logger.e('Error sending message: $e');
      return false;
    }
  }

  /// Get messages stream for the current ride
  Stream<List<Message>> getMessagesStream() {
    if (_activeRide == null) {
      return Stream.value([]);
    }
    
    try {
      return _messageService.getMessagesStream(_activeRide!.ride.id);
    } catch (e) {
      _logger.e('Error getting messages stream: $e');
      return Stream.value([]);
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead() async {
    if (_activeRide == null || _currentDriverId == null) return;
    
    try {
      await _messageService.markMessagesAsRead(
        _activeRide!.ride.id,
        _currentDriverId!,
      );
    } catch (e) {
      _logger.e('Error marking messages as read: $e');
    }
  }

  /// Set up status monitoring
  void _setupStatusMonitoring() {
    if (_currentDriverId == null) return;

    _statusSubscription?.cancel();
    _statusSubscription = _driverStatusService
        .getCurrentDriverStatusStream()
        .listen((status) {
      if (status != null) {
        _currentStatus = status.status;
        _acceptingRequests = status.acceptingRequests;
        notifyListeners();
      }
    });
  }

  /// Start request monitoring
  Future<void> _startRequestMonitoring() async {
    if (_currentDriverId == null) return;

    await _notificationService.startListeningForRequests(_currentDriverId!);
    
    _requestsSubscription?.cancel();
    _requestsSubscription = _notificationService
        .getActiveRequestsStream(_currentDriverId!)
        .listen((requests) {
      _incomingRequests = requests;
      notifyListeners();
    });
  }

  /// Stop request monitoring
  Future<void> _stopRequestMonitoring() async {
    if (_currentDriverId == null) return;

    await _notificationService.stopListeningForRequests(_currentDriverId!);
    _requestsSubscription?.cancel();
    _incomingRequests.clear();
  }

  /// Set up active ride monitoring
  void _setupActiveRideMonitoring() {
    if (_currentDriverId == null) return;

    _activeRideSubscription?.cancel();
    _activeRideSubscription = _rideManagementService
        .getActiveRideStream(_currentDriverId!)
        .listen((rideInfo) {
      if (_ignoredCompletedRideId != null) {
        if (rideInfo == null) {
          _ignoredCompletedRideId = null;
        } else if (rideInfo.ride.id == _ignoredCompletedRideId &&
            rideInfo.ride.status == RideStatus.completed) {
          _logger.d('Suppressing completed ride ${rideInfo.ride.id} after cleanup');
          return;
        } else {
          _ignoredCompletedRideId = null;
        }
      }

      _activeRide = rideInfo;
      
      // Update status based on ride state
      if (rideInfo != null) {
        if (rideInfo.ride.status == RideStatus.inProgress) {
          _currentStatus = DriverStatus.inRide;
        } else if (rideInfo.ride.status == RideStatus.active) {
          _currentStatus = DriverStatus.busy;
        }
      }
      
      notifyListeners();
    });
  }

  /// Cancel all subscriptions (for logout cleanup)
  void cancelAllSubscriptions() {
    _statusSubscription?.cancel();
    _requestsSubscription?.cancel();
    _activeRideSubscription?.cancel();
    _statusSubscription = null;
    _requestsSubscription = null;
    _activeRideSubscription = null;
  }

  @override
  void dispose() {
    cancelAllSubscriptions();
    _notificationService.dispose();
    super.dispose();
  }
}

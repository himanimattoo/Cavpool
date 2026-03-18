import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

enum DriverStatus {
  offline,
  online,
  busy,
  inRide,
}

class DriverStatusInfo {
  final DriverStatus status;
  final DateTime lastUpdated;
  final String? currentRideId;
  final bool acceptingRequests;
  final Map<String, dynamic> location;

  DriverStatusInfo({
    required this.status,
    required this.lastUpdated,
    this.currentRideId,
    required this.acceptingRequests,
    required this.location,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'currentRideId': currentRideId,
      'acceptingRequests': acceptingRequests,
      'location': location,
    };
  }

  factory DriverStatusInfo.fromMap(Map<String, dynamic> map) {
    return DriverStatusInfo(
      status: DriverStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DriverStatus.offline,
      ),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
      currentRideId: map['currentRideId'],
      acceptingRequests: map['acceptingRequests'] ?? false,
      location: Map<String, dynamic>.from(map['location'] ?? {}),
    );
  }
}

class DriverStatusService {
  static final DriverStatusService _instance = DriverStatusService._internal();
  factory DriverStatusService() => _instance;
  DriverStatusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Logger _logger = Logger();

  Timer? _heartbeatTimer;
  String? _currentDriverId;
  DriverStatus _currentStatus = DriverStatus.offline;

  CollectionReference get _driverStatusCollection => 
      _firestore.collection('driver_status');

  /// Set current driver online with location updates
  Future<void> setDriverOnline({Map<String, dynamic>? location}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');
    
    return setDriverOnlineById(uid, location: location);
  }
  
  /// Set specific driver online with location updates (for testing)
  Future<void> setDriverOnlineById(String driverId, {Map<String, dynamic>? location}) async {
    try {
      _logger.i('Setting driver online: $driverId');
      
      final statusInfo = DriverStatusInfo(
        status: DriverStatus.online,
        lastUpdated: DateTime.now(),
        acceptingRequests: true,
        location: location ?? {},
      );

      await _driverStatusCollection.doc(driverId).set(statusInfo.toMap());
      
      _currentDriverId = driverId;
      _currentStatus = DriverStatus.online;
      
      // Start heartbeat to maintain online status
      _startHeartbeat();
      
      _logger.i('Driver set online successfully: $driverId');
    } catch (e) {
      _logger.e('Error setting driver online: $e');
      rethrow;
    }
  }

  /// Set current driver offline
  Future<void> setDriverOffline() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');
    
    return setDriverOfflineById(uid);
  }
  
  /// Set specific driver offline (for testing)
  Future<void> setDriverOfflineById(String driverId) async {
    try {
      _logger.i('Setting driver offline: $driverId');
      
      final statusInfo = DriverStatusInfo(
        status: DriverStatus.offline,
        lastUpdated: DateTime.now(),
        acceptingRequests: false,
        location: {},
      );

      await _driverStatusCollection.doc(driverId).set(statusInfo.toMap());
      
      _currentDriverId = null;
      _currentStatus = DriverStatus.offline;
      
      // Stop heartbeat
      _stopHeartbeat();
      
      _logger.i('Driver set offline successfully: $driverId');
    } catch (e) {
      _logger.e('Error setting driver offline: $e');
      rethrow;
    }
  }

  /// Update driver status
  Future<void> updateDriverStatus(
    DriverStatus status, {
    String? currentRideId,
    bool? acceptingRequests,
    Map<String, dynamic>? location,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');
    
    try {
      final currentData = await _driverStatusCollection.doc(uid).get();
      DriverStatusInfo currentInfo;
      
      if (currentData.exists) {
        currentInfo = DriverStatusInfo.fromMap(currentData.data() as Map<String, dynamic>);
      } else {
        currentInfo = DriverStatusInfo(
          status: DriverStatus.offline,
          lastUpdated: DateTime.now(),
          acceptingRequests: false,
          location: {},
        );
      }

      final updatedInfo = DriverStatusInfo(
        status: status,
        lastUpdated: DateTime.now(),
        currentRideId: currentRideId ?? currentInfo.currentRideId,
        acceptingRequests: acceptingRequests ?? currentInfo.acceptingRequests,
        location: location ?? currentInfo.location,
      );

      await _driverStatusCollection.doc(uid).set(updatedInfo.toMap());
      
      _currentStatus = status;
      
      _logger.i('Driver status updated: $uid -> ${status.name}');
    } catch (e) {
      _logger.e('Error updating driver status: $e');
      rethrow;
    }
  }

  /// Set driver busy (not accepting new requests)
  Future<void> setDriverBusy(String rideId) async {
    await updateDriverStatus(
      DriverStatus.busy,
      currentRideId: rideId,
      acceptingRequests: false,
    );
  }

  /// Set driver in active ride
  Future<void> setDriverInRide(String rideId) async {
    await updateDriverStatus(
      DriverStatus.inRide,
      currentRideId: rideId,
      acceptingRequests: false,
    );
  }

  /// Set driver available (online and accepting requests)
  Future<void> setDriverAvailable() async {
    await updateDriverStatus(
      DriverStatus.online,
      currentRideId: null,
      acceptingRequests: true,
    );
  }

  /// Toggle driver accepting requests
  Future<void> toggleAcceptingRequests() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');
    
    try {
      final doc = await _driverStatusCollection.doc(uid).get();
      if (!doc.exists) return;
      
      final currentInfo = DriverStatusInfo.fromMap(doc.data() as Map<String, dynamic>);
      
      await updateDriverStatus(
        currentInfo.status,
        acceptingRequests: !currentInfo.acceptingRequests,
      );
      
      _logger.i('Toggled accepting requests for driver: $uid -> ${!currentInfo.acceptingRequests}');
    } catch (e) {
      _logger.e('Error toggling accepting requests: $e');
      rethrow;
    }
  }

  /// Update current driver location
  Future<void> updateDriverLocation(Map<String, dynamic> location) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');
    
    return updateDriverLocationById(uid, location);
  }
  
  /// Update specific driver location (for testing)
  Future<void> updateDriverLocationById(String driverId, Map<String, dynamic> location) async {
    try {
      await _driverStatusCollection.doc(driverId).update({
        'location': location,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Error updating driver location: $e');
    }
  }

  /// Get current driver's status
  Future<DriverStatusInfo?> getCurrentDriverStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    
    return getDriverStatus(uid);
  }
  
  /// Get driver status by ID (for viewing other drivers)
  Future<DriverStatusInfo?> getDriverStatus(String driverId) async {
    try {
      // Check if user is authenticated
      if (_auth.currentUser == null) {
        _logger.w('User not authenticated for driver status');
        return null;
      }

      final doc = await _driverStatusCollection.doc(driverId).get();
      if (doc.exists) {
        return DriverStatusInfo.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting driver status: $e');
      if (e.toString().contains('permission-denied')) {
        _logger.e('Permission denied - check Firestore rules and authentication');
      }
      return null;
    }
  }

  /// Get current driver's status stream
  Stream<DriverStatusInfo?> getCurrentDriverStatusStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    
    return getDriverStatusStream(uid);
  }
  
  /// Get driver status stream by ID (for viewing other drivers)
  Stream<DriverStatusInfo?> getDriverStatusStream(String driverId) {
    try {
      // Check if user is authenticated
      if (_auth.currentUser == null) {
        _logger.w('User not authenticated for driver status stream');
        return Stream.value(null);
      }

      // Start stream without forcing token refresh
      return _driverStatusCollection.doc(driverId).snapshots().map((doc) {
        if (doc.exists) {
          return DriverStatusInfo.fromMap(doc.data() as Map<String, dynamic>);
        }
        return null;
      }).handleError((error) {
        _logger.e('Firestore stream error: $error');
        if (error.toString().contains('permission-denied')) {
          _logger.e('Permission denied - check Firestore rules and authentication');
        }
        return null;
      });
    } catch (e) {
      _logger.e('Error getting driver status stream: $e');
      return Stream.value(null);
    }
  }


  /// Get all online drivers
  Stream<List<DriverStatusInfo>> getOnlineDriversStream() {
    try {
      return _driverStatusCollection
          .where('status', whereIn: [DriverStatus.online.name, DriverStatus.busy.name])
          .where('acceptingRequests', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => DriverStatusInfo.fromMap(doc.data() as Map<String, dynamic>))
            .where((info) => _isRecentlyActive(info.lastUpdated))
            .toList();
      });
    } catch (e) {
      _logger.e('Error getting online drivers stream: $e');
      return Stream.value([]);
    }
  }

  /// Check if current driver is accepting requests
  Future<bool> isCurrentDriverAcceptingRequests() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    
    return isDriverAcceptingRequests(uid);
  }
  
  /// Check if driver is accepting requests
  Future<bool> isDriverAcceptingRequests(String driverId) async {
    try {
      final status = await getDriverStatus(driverId);
      return status?.acceptingRequests == true && 
             (status?.status == DriverStatus.online || status?.status == DriverStatus.busy) &&
             _isRecentlyActive(status!.lastUpdated);
    } catch (e) {
      _logger.e('Error checking if driver is accepting requests: $e');
      return false;
    }
  }

  /// Start heartbeat to maintain online status
  void _startHeartbeat() {
    _stopHeartbeat();
    
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_currentDriverId != null && _currentStatus != DriverStatus.offline) {
        _driverStatusCollection.doc(_currentDriverId!).update({
          'lastUpdated': FieldValue.serverTimestamp(),
        }).catchError((e) {
          _logger.e('Heartbeat update error: $e');
        });
      }
    });
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Check if driver was recently active (within 5 minutes)
  bool _isRecentlyActive(DateTime lastUpdated) {
    return DateTime.now().difference(lastUpdated).inMinutes <= 5;
  }

  /// Clean up inactive drivers (call periodically)
  Future<void> cleanupInactiveDrivers() async {
    try {
      final cutoffTime = DateTime.now().subtract(const Duration(minutes: 10));
      final snapshot = await _driverStatusCollection
          .where('lastUpdated', isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': DriverStatus.offline.name,
          'acceptingRequests': false,
        });
      }

      await batch.commit();
      
      if (snapshot.docs.isNotEmpty) {
        _logger.i('Cleaned up ${snapshot.docs.length} inactive drivers');
      }
    } catch (e) {
      _logger.e('Error cleaning up inactive drivers: $e');
    }
  }

  /// Get current driver status
  DriverStatus get currentStatus => _currentStatus;
  String? get currentDriverId => _currentDriverId;

  /// Dispose resources
  void dispose() {
    _stopHeartbeat();
    if (_currentDriverId != null) {
      setDriverOffline();
    }
  }
}
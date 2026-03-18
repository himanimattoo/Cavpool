import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride_model.dart';

class UpcomingRideProvider with ChangeNotifier {
  RideOffer? _upcomingRide;
  bool _isLoading = false;

  RideOffer? get upcomingRide => _upcomingRide;
  bool get isLoading => _isLoading;

  Future<void> fetchUpcomingRide(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final snapshot = await FirebaseFirestore.instance
          .collection('ride_requests')
          .where('requesterId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .where('departureTime', isGreaterThan: now)
          .orderBy('departureTime')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        _upcomingRide = RideOffer.fromMap(data);
      } else {
        _upcomingRide = null;
      }
    } catch (e) {
      debugPrint('Error fetching upcoming ride: $e');
      _upcomingRide = null;
    }

    _isLoading = false;
    notifyListeners();
  }
}
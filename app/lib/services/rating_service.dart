import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class RatingService {
  static final RatingService _instance = RatingService._internal();
  factory RatingService() => _instance;
  RatingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  CollectionReference get _reviewsCollection => _firestore.collection('ride_reviews');
  CollectionReference get _usersCollection => _firestore.collection('users');

  Future<void> submitRating({
    required String rideId,
    required String reviewerId,
    required String revieweeId,
    required double rating,
    String? comment,
    required bool reviewerIsDriver,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5 stars');
    }

    final reviewDocId = '${rideId}_$reviewerId';
    final reviewRef = _reviewsCollection.doc(reviewDocId);
    final userRef = _usersCollection.doc(revieweeId);

    await _firestore.runTransaction((txn) async {
      final existingReview = await txn.get(reviewRef);
      if (existingReview.exists) {
        final reviewData = existingReview.data() as Map<String, dynamic>;
        final existingRating = reviewData['rating'] as double;
        throw Exception('You have already rated this ride with $existingRating star${existingRating != 1 ? 's' : ''}');
      }

      final userSnapshot = await txn.get(userRef);
      if (!userSnapshot.exists) {
        throw Exception('Reviewee profile missing');
      }

      final reviewData = {
        'rideId': rideId,
        'reviewerId': reviewerId,
        'revieweeId': revieweeId,
        'rating': rating,
        'comment': comment,
        'reviewerRole': reviewerIsDriver ? 'driver' : 'rider',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final userData = userSnapshot.data() as Map<String, dynamic>;
      final ratingsData = Map<String, dynamic>.from(userData['ratings'] ?? {});

      final currentOverallAvg = (ratingsData['averageRating'] ?? 0.0).toDouble();
      final currentOverallCount = (ratingsData['totalRatings'] ?? 0) as int;

      final newOverallAvg = _calculateAverage(currentOverallAvg, currentOverallCount, rating);
      final newOverallCount = currentOverallCount + 1;

      final asDriverData = Map<String, dynamic>.from(ratingsData['asDriver'] ?? {});
      final asRiderData = Map<String, dynamic>.from(ratingsData['asRider'] ?? {});

      double driverAvg = (asDriverData['averageRating'] ?? 0.0).toDouble();
      int driverCount = (asDriverData['totalRatings'] ?? 0) as int;
      double riderAvg = (asRiderData['averageRating'] ?? 0.0).toDouble();
      int riderCount = (asRiderData['totalRatings'] ?? 0) as int;

      if (reviewerIsDriver) {
        riderAvg = _calculateAverage(riderAvg, riderCount, rating);
        riderCount += 1;
      } else {
        driverAvg = _calculateAverage(driverAvg, driverCount, rating);
        driverCount += 1;
      }

      txn.set(reviewRef, reviewData);
      txn.update(userRef, {
        'ratings.averageRating': newOverallAvg,
        'ratings.totalRatings': newOverallCount,
        'ratings.asDriver.averageRating': driverAvg,
        'ratings.asDriver.totalRatings': driverCount,
        'ratings.asRider.averageRating': riderAvg,
        'ratings.asRider.totalRatings': riderCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    _logger.i('Rating submitted for $revieweeId by $reviewerId');
  }

  /// Check if a user has already submitted a rating for a specific ride
  Future<bool> hasUserRatedRide({
    required String rideId,
    required String reviewerId,
  }) async {
    try {
      final reviewDocId = '${rideId}_$reviewerId';
      final reviewDoc = await _reviewsCollection.doc(reviewDocId).get();
      return reviewDoc.exists;
    } catch (e) {
      _logger.w('Error checking if user rated ride: $e');
      return false; // Assume not rated if check fails
    }
  }

  /// Get existing rating details for a ride by a specific user
  Future<Map<String, dynamic>?> getUserRatingForRide({
    required String rideId,
    required String reviewerId,
  }) async {
    try {
      final reviewDocId = '${rideId}_$reviewerId';
      final reviewDoc = await _reviewsCollection.doc(reviewDocId).get();
      
      if (reviewDoc.exists) {
        return reviewDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      _logger.w('Error getting user rating for ride: $e');
      return null;
    }
  }

  /// Get all reviews for a specific user
  Future<List<Map<String, dynamic>>> getUserReviews({
    required String userId,
  }) async {
    try {
      final reviewsQuery = await _reviewsCollection
          .where('revieweeId', isEqualTo: userId)
          .get();
      
      final reviews = reviewsQuery.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
      
      // Sort by createdAt in memory to avoid needing a composite index
      reviews.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // Descending order (newest first)
      });
      
      return reviews;
    } catch (e) {
      _logger.w('Error getting user reviews: $e');
      return [];
    }
  }

  double _calculateAverage(double currentAverage, int currentCount, double newRating) {
    final total = (currentAverage * currentCount) + newRating;
    final newCount = currentCount + 1;
    return newCount == 0 ? 0 : total / newCount;
  }
}

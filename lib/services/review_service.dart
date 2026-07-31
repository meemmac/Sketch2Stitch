import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/review.dart';

class ReviewService {
  ReviewService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _reviewsCollection = 'Reviews';

  // ─── Customer Review Functions ───────────────────────────────────────────

  /// Fetches all reviews submitted by a specific customer.
  Future<List<Review>> fetchMyReviewHistory(String customerId) async {
    try {
      final snapshot = await _db
          .collection(_reviewsCollection)
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching review history: $e');
      return [];
    }
  }

  /// Calculates summary statistics for a customer's review history.
  Future<Map<String, dynamic>> getReviewSummaryStats(String customerId) async {
    try {
      final reviews = await fetchMyReviewHistory(customerId);
      if (reviews.isEmpty) {
        return {
          'totalReviews': 0,
          'averageRating': 0.0,
          'tailorReviews': 0,
          'retailerReviews': 0,
          'productReviews': 0,
        };
      }

      final total = reviews.length;
      final avg = reviews.fold(0.0, (sum, r) => sum + r.rating) / total;
      final tailorCount = reviews.where((r) => r.targetRole == ReviewTargetRole.tailor).length;
      final retailerCount = reviews.where((r) => r.targetRole == ReviewTargetRole.retailer).length;
      final productCount = reviews.where((r) => r.targetRole == ReviewTargetRole.product).length;

      return {
        'totalReviews': total,
        'averageRating': avg,
        'tailorReviews': tailorCount,
        'retailerReviews': retailerCount,
        'productReviews': productCount,
      };
    } catch (e) {
      debugPrint('Error getting review summary stats: $e');
      return {};
    }
  }

  /// Filters a customer's reviews by recipient type (tailor, retailer, product).
  Future<List<Review>> filterReviews(String customerId, ReviewTargetRole recipientType) async {
    try {
      final snapshot = await _db
          .collection(_reviewsCollection)
          .where('customerId', isEqualTo: customerId)
          .where('targetRole', isEqualTo: recipientType.name)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error filtering reviews: $e');
      return [];
    }
  }

  /// Submits a general review for an order recipient.
  Future<void> submitReview({
    required String orderId,
    required String customerId,
    required String recipientId,
    required double rating,
    required String comment,
    required ReviewTargetRole type,
  }) async {
    try {
      final data = {
        'orderId': orderId,
        'customerId': customerId,
        'targetId': recipientId,
        'rating': rating,
        'comment': comment,
        'targetRole': type.name,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _db.collection(_reviewsCollection).add(data);
    } catch (e) {
      debugPrint('Error submitting review: $e');
      rethrow;
    }
  }

  /// Specific helper to submit a tailor review.
  Future<void> submitTailorReview(
    String customerId,
    String tailorId,
    String orderId,
    double rating,
    String comment,
  ) async {
    await submitReview(
      orderId: orderId,
      customerId: customerId,
      recipientId: tailorId,
      rating: rating,
      comment: comment,
      type: ReviewTargetRole.tailor,
    );
  }

  // ─── Retailer Review Functions ───────────────────────────────────────────

  /// Fetches reviews for a specific retailer shop with optional filtering and sorting.
  Future<List<Review>> fetchShopReviews(
    String retailerId, {
    int? starFilter,
    String sortBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      Query query = _db
          .collection(_reviewsCollection)
          .where('targetId', isEqualTo: retailerId)
          .where('targetRole', isEqualTo: ReviewTargetRole.retailer.name);

      if (starFilter != null) {
        query = query.where('rating', isEqualTo: starFilter.toDouble());
      }

      // Note: top reviews sorting might involve multiple fields (rating, helpfulCount)
      if (sortBy == 'top') {
        query = query.orderBy('rating', descending: true).orderBy('helpfulCount', descending: true);
      } else {
        query = query.orderBy(sortBy, descending: descending);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Review.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching shop reviews: $e');
      return [];
    }
  }

  /// Gets review statistics for a retailer shop.
  Future<Map<String, dynamic>> getShopReviewStats(String retailerId) async {
    try {
      // We fetch all reviews to calculate stats. For very large numbers, 
      // this should be moved to a Cloud Function that updates a stats doc.
      final snapshot = await _db
          .collection(_reviewsCollection)
          .where('targetId', isEqualTo: retailerId)
          .where('targetRole', isEqualTo: ReviewTargetRole.retailer.name)
          .get();

      final reviews = snapshot.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      if (reviews.isEmpty) return {'total': 0, 'average': 0.0, 'distribution': {1:0, 2:0, 3:0, 4:0, 5:0}};

      final total = reviews.length;
      final avg = reviews.fold(0.0, (sum, r) => sum + r.rating) / total;
      
      final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (var r in reviews) {
        int star = r.rating.floor().clamp(1, 5);
        distribution[star] = (distribution[star] ?? 0) + 1;
      }

      return {
        'total': total,
        'average': avg,
        'distribution': distribution,
      };
    } catch (e) {
      debugPrint('Error getting shop review stats: $e');
      return {};
    }
  }

  /// Fetches all reviews associated with a specific order.
  Future<List<Review>> fetchReviewRelatedItems(String orderId) async {
    try {
      final snapshot = await _db
          .collection(_reviewsCollection)
          .where('orderId', isEqualTo: orderId)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching review related items: $e');
      return [];
    }
  }

  /// Responds to a review (Retailer functionality).
  Future<void> respondToReview(String reviewId, String retailerComment) async {
    try {
      await _db.collection(_reviewsCollection).doc(reviewId).update({
        'retailerResponse': retailerComment,
        'respondedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error responding to review: $e');
      rethrow;
    }
  }

  /// Marks a review as helpful for a user.
  Future<void> markReviewHelpful(String reviewId, String userId) async {
    try {
      await _db.collection(_reviewsCollection).doc(reviewId).update({
        'votedHelpfulBy': FieldValue.arrayUnion([userId]),
        'helpfulCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error marking review helpful: $e');
      rethrow;
    }
  }

  /// Unmarks a review as helpful for a user.
  Future<void> unmarkReviewHelpful(String reviewId, String userId) async {
    try {
      await _db.collection(_reviewsCollection).doc(reviewId).update({
        'votedHelpfulBy': FieldValue.arrayRemove([userId]),
        'helpfulCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('Error unmarking review helpful: $e');
      rethrow;
    }
  }

  // ─── Tailor Review Functions ─────────────────────────────────────────────

  /// Fetches reviews for a specific tailor with optional filtering and sorting.
  Future<List<Review>> fetchTailorReviews(
    String tailorId, {
    int? ratingFilter,
    String sortBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      Query query = _db
          .collection(_reviewsCollection)
          .where('targetId', isEqualTo: tailorId)
          .where('targetRole', isEqualTo: ReviewTargetRole.tailor.name);

      if (ratingFilter != null) {
        query = query.where('rating', isGreaterThanOrEqualTo: ratingFilter.toDouble());
      }

      query = query.orderBy(sortBy, descending: descending);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Review.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching tailor reviews: $e');
      return [];
    }
  }

  /// Gets reputation summary for a tailor.
  Future<Map<String, dynamic>> getTailorReputationSummary(String tailorId) async {
    try {
      final reviews = await fetchTailorReviews(tailorId);
      if (reviews.isEmpty) return {'total': 0, 'average': 0.0};

      final total = reviews.length;
      final avg = reviews.fold(0.0, (sum, r) => sum + r.rating) / total;

      return {
        'total': total,
        'average': avg,
      };
    } catch (e) {
      debugPrint('Error getting tailor reputation summary: $e');
      return {};
    }
  }

  /// Fetches a single review's detailed metadata.
  Future<Review?> fetchReviewMetadata(String reviewId) async {
    try {
      final doc = await _db.collection(_reviewsCollection).doc(reviewId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Review.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      debugPrint('Error fetching review metadata: $e');
      return null;
    }
  }

  /// General fetch for reviews by target (any role).
  Future<List<Review>> getReviewsByTargetId(
    String targetId, 
    ReviewTargetRole targetRole, {
    int? filter, 
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _db
          .collection(_reviewsCollection)
          .where('targetId', isEqualTo: targetId)
          .where('targetRole', isEqualTo: targetRole.name);

      if (filter != null) {
        query = query.where('rating', isGreaterThanOrEqualTo: filter.toDouble());
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Review.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching reviews by target: $e');
      return [];
    }
  }
}

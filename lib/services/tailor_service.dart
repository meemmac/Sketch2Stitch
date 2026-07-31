import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/tailor.dart';
import '../models/portfolio.dart';
import '../models/tailor_job.dart';

class TailorService {
  TailorService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ─── Tailor Profile ────────────────────────────────────────────────────────

  /// Fetches a specific tailor profile by ID.
  Future<Tailor?> getTailorByTailorId(String tailorId) async {
    try {
      final doc = await _db.collection('Tailor').doc(tailorId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Tailor.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching tailor profile: $e');
      return null;
    }
  }

  /// Alias for [getTailorByTailorId].
  Future<Tailor?> getTailorProfile(String tailorId) => getTailorByTailorId(tailorId);

  /// Updates tailor shop info, location, and other profile details.
  Future<void> updateTailorProfile(String tailorId, Map<String, dynamic> data) async {
    try {
      await _db.collection('Tailor').doc(tailorId).update(data);
    } catch (e) {
      debugPrint('Error updating tailor profile: $e');
      rethrow;
    }
  }

  // ─── Portfolio ─────────────────────────────────────────────────────────────

  /// Fetches the portfolio items for a specific tailor.
  Stream<List<Portfolio>> getPortfolioByTailorId(String tailorId) {
    return _db
        .collection('Portfolio')
        .where('tailorId', isEqualTo: tailorId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Portfolio.fromJson(doc.data())).toList());
  }

// ─── Tailor Jobs & Requests ────────────────────────────────────────────────


  /// Creates a new tailor job request (booking).
  Future<void> createTailorJobRequest(TailorJob job) async {
    try {
      await _db.collection('Tailor-jobs').doc(job.id).set(job.toJson());

      // Also update the main order status if necessary
      await _db.collection('Orders').doc(job.orderId).update({
        'status': 'tailor_pending',
      });
    } catch (e) {
      debugPrint('Error creating tailor job request: $e');
      rethrow;
    }
  }


  /// Convenience method to create a request using just the Order ID.
  Future<void> createTailorJobRequestByOrderId({
    required String orderId,
    required String tailorId,
    required String measurementId,
    List<String> designIds = const [],
    String specialInstructions = '',
  }) async {
    final docRef = _db.collection('Tailor-jobs').doc();
    final job = TailorJob(
      id: docRef.id,
      orderId: orderId,
      tailorId: tailorId,
      measurementId: measurementId,
      designIds: designIds,
      specialInstructions: specialInstructions,
      status: TailorJobStatus.pending,
      requestedAt: DateTime.now(),
      quoteStatus: QuoteStatus.notSent,
      tailorPaymentStatus: TailorPaymentStatus.unpaid,
    );
    return createTailorJobRequest(job);
  }


  /// Streams active jobs for a tailor to display on their dashboard.
  Stream<List<TailorJob>> streamTailorJobs(String tailorId) {
    return _db
        .collection('Tailor-jobs')
        .where('tailorId', isEqualTo: tailorId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => TailorJob.fromJson(doc.data())).toList());
  }


  /// Tailor sends a quote for a pending job.
  Future<void> submitQuote(
      String jobId, {
        required double quoteAmount,
        required DateTime estimatedDeliveryDate,
        String? note,
      }) async {
    try {
      await _db.collection('Tailor-jobs').doc(jobId).update({
        'status': TailorJobStatus.quoted.toValue,
        'quoteStatus': QuoteStatus.sent.toValue,
        'quoteAmount': quoteAmount,
        'estimatedDeliveryDate': Timestamp.fromDate(estimatedDeliveryDate),
        'quoteNote': note,
      });
    } catch (e) {
      debugPrint('Error submitting quote: $e');
      rethrow;
    }
  }


  /// Updates the status of a job (e.g., started, ready, completed).
  Future<void> updateJobStatus(String jobId, TailorJobStatus status) async {
    try {
      await _db.collection('Tailor-jobs').doc(jobId).update({
        'status': status.toValue,
      });
    } catch (e) {
      debugPrint('Error updating job status: $e');
      rethrow;
    }
  }


// ─── Geo-Queries ───────────────────────────────────────────────────────────


  /// Fetches tailors within a certain radius.
  /// Note: This is a basic implementation. For production, consider using
  /// geoflutterfire or a custom bounding box query.
  Stream<List<Tailor>> getNearbyTailors(GeoPoint center, double radiusKm) {
    // This simple query fetches all tailors; client-side filtering is applied.
    // For large datasets, a true geo-query using Geohashes is required.
    return _db.collection('Tailor').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Tailor.fromJson(doc.data())).where((tailor) {
        if (tailor.location == null) return false;

        // Simple distance approximation (Haversine formula could be used here)
        final distance = _calculateDistance(
          center.latitude,
          center.longitude,
          tailor.location!.latitude,
          tailor.location!.longitude,
        );
        return distance <= radiusKm;
      }).toList();
    });
  }


  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Very basic distance calculation (Euclidean) for demonstration.
    // In production, use a proper library like 'geolocator' or 'latlong2'.
    return (lat1 - lat2).abs() + (lon1 - lon2).abs() * 111.0; // Extremely rough estimate
  }

}

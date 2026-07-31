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
      final doc = await _db.collection('Tailors').doc(tailorId).get();
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
      await _db.collection('Tailors').doc(tailorId).update(data);
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



}


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/tailor.dart';
import '../models/retailer.dart';
import '../models/product.dart';
import '../models/favorite.dart';

/// Service class for customer-specific Firestore operations.
class CustomerService {
  CustomerService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ─── Service Providers ─────────────────────────────────────────────────────

  /// Fetches all tailors from the 'Tailors' collection.
  Stream<List<Tailor>> getTailors() {
    return _firestore.collection('Tailors').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Tailor.fromJson(doc.data())).toList();
    });
  }

  /// Fetches all retailers from the 'Retailers' collection.
  Stream<List<Retailer>> getRetailers() {
    return _firestore.collection('Retailers').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Retailer.fromJson(doc.data())).toList();
    });
  }
// ─── Profile Management ────────────────────────────────────────────────────


  /// Updates customer profile data.
  Future<void> updateCustomerProfile(String customerId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('Customers').doc(customerId).update(data);
    } catch (e) {
      debugPrint('Error updating customer profile: $e');
      rethrow;
    }
  }

/// Streams the customer profile for real-time updates.
Stream<Customer?> streamCustomerProfile(String uid) {
  return _firestore
      .collection('Customers')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? Customer.fromJson(doc.data()!) : null);
}

// ─── Favorites ─────────────────────────────────────────────────────────────


  /// Toggles a favorite status for a target (tailor, retailer, or product).
  Future<void> toggleFavorite(
      String customerId,
      String targetId,
      FavoriteTargetRole targetRole,
      ) async {
    try {
      final favoritesRef = _firestore.collection('Favorites');
      final query = await favoritesRef
          .where('customerId', isEqualTo: customerId)
          .where('targetId', isEqualTo: targetId)
          .where('targetRole', isEqualTo: targetRole.name)
          .limit(1)
          .get();


      if (query.docs.isNotEmpty) {
        // Remove from favorites
        await favoritesRef.doc(query.docs.first.id).delete();
      } else {
        // Add to favorites
        final newDoc = favoritesRef.doc();
        final favorite = Favorite(
          id: newDoc.id,
          customerId: customerId,
          targetId: targetId,
          targetRole: targetRole,
        );
        await newDoc.set(favorite.toJson());
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      rethrow;
    }
  }


  /// Streams a list of favorites for a customer.
  Stream<List<Favorite>> streamFavorites(String customerId) {
    return _firestore
        .collection('Favorites')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Favorite.fromJson(doc.data())).toList());
  }

}

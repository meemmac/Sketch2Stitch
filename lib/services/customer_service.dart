
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

  // ─── Last Viewed ───────────────────────────────────────────────────────────


  /// Records a product view for the customer.
  /// Keeps only the most recent views by updating a timestamp.
  Future<void> addToLastViewed(String uid, String productId) async {
    try {
      final lastViewedRef = _firestore
          .collection('Customers')
          .doc(uid)
          .collection('LastViewed')
          .doc(productId);


      await lastViewedRef.set({
        'productId': productId,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      // Optional: Logic to prune old entries could go here or in a Cloud Function
    } catch (e) {
      debugPrint('Error adding to last viewed: $e');
    }
  }


  /// Streams the list of recently viewed products.
  Stream<List<Product>> streamLastViewed(String uid) {
    return _firestore
        .collection('Customers')
        .doc(uid)
        .collection('LastViewed')
        .orderBy('viewedAt', descending: true)
        .limit(10)
        .snapshots()
        .asyncMap((snapshot) async {
      final productIds = snapshot.docs.map((doc) => doc['productId'] as String).toList();

      if (productIds.isEmpty) return [];


      // Fetch product details for these IDs
      final productsQuery = await _firestore
          .collection('Products')
          .where(FieldPath.documentId, whereIn: productIds)
          .get();


      final products = productsQuery.docs
          .map((doc) => Product.fromJson(doc.data()))
          .toList();


      // Sort products to match the order of productIds (recent first)
      products.sort((a, b) => productIds.indexOf(a.id).compareTo(productIds.indexOf(b.id)));

      return products;
    });
  }

}

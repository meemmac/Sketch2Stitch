import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/favorite.dart';
import '../models/tailor.dart';
import '../models/retailer.dart';
import '../models/product.dart';

class FavoriteService {
  FavoriteService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ─── Core Logic ────────────────────────────────────────────────────────────

  /// Adds a target to the customer's favorites.
  Future<void> addFavorite(
    String customerId,
    String targetId,
    FavoriteTargetRole targetRole,
  ) async {
    try {
      final docRef = _db.collection('Favorite').doc();
      final favorite = Favorite(
        id: docRef.id,
        customerId: customerId,
        targetId: targetId,
        targetRole: targetRole,
      );
      await docRef.set(favorite.toJson());
    } catch (e) {
      debugPrint('Error adding favorite: $e');
      rethrow;
    }
  }

  /// Removes a target from the customer's favorites.
  Future<void> removeFavorite(
    String customerId,
    String targetId,
    FavoriteTargetRole targetRole,
  ) async {
    try {
      final snapshot = await _db
          .collection('Favorite')
          .where('customerId', isEqualTo: customerId)
          .where('targetId', isEqualTo: targetId)
          .where('targetRole', isEqualTo: targetRole.name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.delete();
      }
    } catch (e) {
      debugPrint('Error removing favorite: $e');
      rethrow;
    }
  }

  /// Streams whether a specific target is favorited by a customer.
  Stream<bool> isFavorite(
    String customerId,
    String targetId,
    FavoriteTargetRole targetRole,
  ) {
    return _db
        .collection('Favorite')
        .where('customerId', isEqualTo: customerId)
        .where('targetId', isEqualTo: targetId)
        .where('targetRole', isEqualTo: targetRole.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // ─── Tailor Helpers ────────────────────────────────────────────────────────

  Future<void> toggleFavoriteTailor(String customerId, String tailorId) async {
    final status = await isFavorite(customerId, tailorId, FavoriteTargetRole.tailor).first;
    if (status) {
      await removeFavorite(customerId, tailorId, FavoriteTargetRole.tailor);
    } else {
      await addFavorite(customerId, tailorId, FavoriteTargetRole.tailor);
    }
  }

  Stream<bool> isFavoriteTailor(String customerId, String tailorId) {
    return isFavorite(customerId, tailorId, FavoriteTargetRole.tailor);
  }

  Stream<List<Tailor>> getFavoriteTailors(String customerId) {
    return _db
        .collection('Favorite')
        .where('customerId', isEqualTo: customerId)
        .where('targetRole', isEqualTo: FavoriteTargetRole.tailor.name)
        .snapshots()
        .asyncMap((snapshot) async {
      final ids = snapshot.docs.map((doc) => doc['targetId'] as String).toList();
      if (ids.isEmpty) return [];

      final tailorsQuery = await _db
          .collection('Tailor')
          .where(FieldPath.documentId, whereIn: ids)
          .get();

      return tailorsQuery.docs.map((doc) => Tailor.fromJson(doc.data())).toList();
    });
  }

  // ─── Retailer Helpers ──────────────────────────────────────────────────────


  Future<void> toggleFavoriteRetailer(String customerId, String retailerId) async {
    final status = await isFavorite(customerId, retailerId, FavoriteTargetRole.retailer).first;
    if (status) {
      await removeFavorite(customerId, retailerId, FavoriteTargetRole.retailer);
    } else {
      await addFavorite(customerId, retailerId, FavoriteTargetRole.retailer);
    }
  }


  Stream<bool> isFavoriteRetailer(String customerId, String retailerId) {
    return isFavorite(customerId, retailerId, FavoriteTargetRole.retailer);
  }


  Stream<List<Retailer>> getFavoriteRetailers(String customerId) {
    return _db
        .collection('Favorite')
        .where('customerId', isEqualTo: customerId)
        .where('targetRole', isEqualTo: FavoriteTargetRole.retailer.name)
        .snapshots()
        .asyncMap((snapshot) async {
      final ids = snapshot.docs.map((doc) => doc['targetId'] as String).toList();
      if (ids.isEmpty) return [];


      final retailersQuery = await _db
          .collection('Retailer')
          .where(FieldPath.documentId, whereIn: ids)
          .get();


      return retailersQuery.docs.map((doc) => Retailer.fromJson(doc.data())).toList();
    });
  }

  // ─── Product Helpers ───────────────────────────────────────────────────────


  Future<void> toggleFavoriteProduct(String customerId, String productId) async {
    final status = await isFavorite(customerId, productId, FavoriteTargetRole.product).first;
    if (status) {
      await removeFavorite(customerId, productId, FavoriteTargetRole.product);
    } else {
      await addFavorite(customerId, productId, FavoriteTargetRole.product);
    }
  }


  Stream<bool> isFavoriteProduct(String customerId, String productId) {
    return isFavorite(customerId, productId, FavoriteTargetRole.product);
  }


  Stream<List<Product>> getFavoriteProducts(String customerId) {
    return _db
        .collection('Favorite')
        .where('customerId', isEqualTo: customerId)
        .where('targetRole', isEqualTo: FavoriteTargetRole.product.name)
        .snapshots()
        .asyncMap((snapshot) async {
      final ids = snapshot.docs.map((doc) => doc['targetId'] as String).toList();
      if (ids.isEmpty) return [];


      final productsQuery = await _db
          .collection('Products')
          .where(FieldPath.documentId, whereIn: ids)
          .get();


      return productsQuery.docs.map((doc) => Product.fromJson(doc.data())).toList();
    });
  }

}

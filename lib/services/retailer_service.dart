import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/retailer.dart';
import '../models/product.dart';
import '../models/sub_order.dart';

class RetailerService {
  RetailerService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // ─── Retailer Profile ──────────────────────────────────────────────────────

  /// Fetches a specific retailer profile by ID.
  Future<Retailer?> getRetailerByRetailerId(String retailerId) async {
    try {
      final doc = await _db.collection('Retailer').doc(retailerId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Retailer.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error fetching retailer profile: $e');
      return null;
    }
  }

  /// Alias for [getRetailerByRetailerId].
  Future<Retailer?> getRetailerProfile(String retailerId) => 
      getRetailerByRetailerId(retailerId);

  /// Updates retailer shop info, location, and other profile details.
  Future<void> updateRetailerProfile(String retailerId, Map<String, dynamic> data) async {
    try {
      await _db.collection('Retailer').doc(retailerId).update(data);
    } catch (e) {
      debugPrint('Error updating retailer profile: $e');
      rethrow;
    }
  }

  /// Verifies if the current logged-in user has access to the retailer account.
  bool verifyRetailerAccess(String retailerId) {
    final user = _auth.currentUser;
    return user != null && user.uid == retailerId;
  }

  // ─── Inventory Management ──────────────────────────────────────────────────

  /// Streams products belonging to a specific retailer.
  Stream<List<Product>> getProductsByRetailerId(String retailerId) {
    return _db
        .collection('Products')
        .where('retailerId', isEqualTo: retailerId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Product.fromJson(doc.data())).toList());
  }

  /// Adds a new product to the retailer's inventory.
  Future<void> addProduct(Product product) async {
    try {
      await _db.collection('Products').doc(product.id).set(product.toJson());
    } catch (e) {
      debugPrint('Error adding product: $e');
      rethrow;
    }
  }

  /// Updates an existing product in the inventory.
  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      await _db.collection('Products').doc(productId).update(data);
    } catch (e) {
      debugPrint('Error updating product: $e');
      rethrow;
    }
  }

  /// Deletes a product from the inventory.
  Future<void> deleteProduct(String productId) async {
    try {
      await _db.collection('Products').doc(productId).delete();
    } catch (e) {
      debugPrint('Error deleting product: $e');
      rethrow;
    }
  }

  // ─── Sales & Sub-Orders ────────────────────────────────────────────────────

  /// Streams active sales (sub-orders) for a retailer.
  Stream<List<SubOrder>> streamRetailerSubOrders(String retailerId) {
    return _db
        .collection('Sub-orders')
        .where('retailerId', isEqualTo: retailerId)
        .orderBy('autoReleaseAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SubOrder.fromJson(doc.data())).toList());
  }

  /// Updates the status of a sub-order (e.g., Packed, Shipped).
  Future<void> updateSubOrderStatus(String subOrderId, SubOrderStatus status) async {
    try {
      await _db.collection('Sub-orders').doc(subOrderId).update({
        'status': status.name,
      });
    } catch (e) {
      debugPrint('Error updating sub-order status: $e');
      rethrow;
    }
  }
}

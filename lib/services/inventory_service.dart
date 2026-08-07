import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import 'Cloudinary_service.dart';

class InventoryService {
  InventoryService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final CloudinaryService _cloudinary = CloudinaryService();

  static const String _productsCollection = 'Products';

  // ─── getProducts ──────────────────────────────────────────────────────────

  /// Fetches inventory with search, category, and pagination support.
  /// Now scoped to a specific [retailerId] to match the Inventory Screen logic.
  Future<List<Product>> getProducts({
    String? retailerId,
    String? category,
    String? searchQuery,
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      Query query = _db.collection(_productsCollection);

      if (retailerId != null && retailerId.isNotEmpty) {
        query = query.where('retailerId', isEqualTo: retailerId);
      }

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      // Firestore does not support full-text search natively. 
      // We use a prefix range query on the productName field.
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .where('productName', isGreaterThanOrEqualTo: searchQuery)
            .where('productName', isLessThanOrEqualTo: '$searchQuery\uf8ff');
      }

      query = query.limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Product.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching products: $e');
      return [];
    }
  }

  // ─── streamRetailerProducts ───────────────────────────────────────────────

  /// Real-time stream of products for a specific retailer.
  /// Recommended for the Inventory Screen to show stock changes immediately.
  Stream<List<Product>> streamRetailerProducts(String retailerId) {
    return _db
        .collection(_productsCollection)
        .where('retailerId', isEqualTo: retailerId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // ─── createProduct ────────────────────────────────────────────────────────

  /// Create product with SKU validation.
  /// Note: The document ID in Firestore will be the auto-generated ID or SKU.
  /// Based on the schema provided, we will use auto-generated ID for document
  /// and store SKU in productCode.
  Future<void> createProduct(Map<String, dynamic> productData) async {
    try {
      // Ensure productCode (SKU) is unique if required, or just add.
      // For simplicity and better Firestore practice, we'll use add()
      await _db.collection(_productsCollection).add(productData);
    } catch (e) {
      debugPrint('Error creating product: $e');
      rethrow;
    }
  }

  // ─── updateProduct ────────────────────────────────────────────────────────

  /// Update existing product identified by Firestore ID.
  Future<void> updateProduct(String productId, Map<String, dynamic> productData) async {
    try {
      await _db.collection(_productsCollection).doc(productId).update(productData);
    } catch (e) {
      debugPrint('Error updating product: $e');
      rethrow;
    }
  }

  // ─── deleteProduct ────────────────────────────────────────────────────────

  /// Delete product identified by Firestore ID.
  Future<void> deleteProduct(String productId) async {
    try {
      await _db.collection(_productsCollection).doc(productId).delete();
    } catch (e) {
      debugPrint('Error deleting product: $e');
      rethrow;
    }
  }

  // ─── updateProductStock ──────────────────────────────────────────────────

  /// Quick stock update for specific color variants of a product.
  /// [variantStock] is a list of maps: {'optionId': int, 'stock': int}.
  Future<void> updateProductStock(
    String productId,
    List<Map<String, dynamic>> variantStock,
  ) async {
    try {
      final docRef = _db.collection(_productsCollection).doc(productId);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Product not found');
        }

        final productData = snapshot.data() as Map<String, dynamic>;
        final List<dynamic> colorOptions = List.from(productData['colorOptions'] ?? []);

        for (var update in variantStock) {
          final int optionId = update['optionId'];
          final int newStock = update['stock'];

          final index = colorOptions.indexWhere((opt) => opt['optionId'] == optionId);
          if (index != -1) {
            colorOptions[index]['stock'] = newStock;
          }
        }

        transaction.update(docRef, {'colorOptions': colorOptions});
      });
    } catch (e) {
      debugPrint('Error updating product stock: $e');
      rethrow;
    }
  }

  // ─── getLowStockProducts ──────────────────────────────────────────────────

  /// List low stock products (<5) for a specific [retailerId].
  Future<List<Product>> getLowStockProducts(String retailerId, {int threshold = 5}) async {
    try {
      // Fetches retailer-specific products and filters client-side 
      // due to Firestore nested array limitations.
      final snapshot = await _db
          .collection(_productsCollection)
          .where('retailerId', isEqualTo: retailerId)
          .get();

      final products = snapshot.docs
          .map((doc) => Product.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      return products.where((product) {
        return product.colorOptions.any((opt) => opt.stock < threshold);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching low stock products: $e');
      return [];
    }
  }

  // ─── uploadMedia ──────────────────────────────────────────────────────────

  /// Upload images/videos to Cloudinary.
  Future<List<String>> uploadMedia(List<String> filePaths, {String? folder}) async {
    final List<String> urls = [];
    for (final path in filePaths) {
      final cleanPath = path.trim();
      if (cleanPath.isEmpty) continue;

      // Check if it's already a URL
      if (cleanPath.startsWith('http')) {
        urls.add(cleanPath);
        continue;
      }
      
      final file = File(cleanPath);
      if (!await file.exists()) {
        debugPrint('File not found for upload: $cleanPath');
        continue;
      }

      final url = await _cloudinary.uploadImage(file, folder: folder);
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }

  // ─── deleteMedia ──────────────────────────────────────────────────────────

  /// Delete media from storage (Placeholder).
  Future<void> deleteMedia(String fileUrl) async {
    // Cloudinary deletion typically requires backend-signed requests for security.
    debugPrint('Media deletion requested for: $fileUrl');
  }
}

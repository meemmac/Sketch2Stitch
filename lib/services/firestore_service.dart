import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/tailor.dart';
import '../models/retailer.dart';
import '../models/portfolio.dart';
import '../models/review.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection names
  static const String productsCollection = 'products';
  static const String tailorsCollection = 'tailors';
  static const String retailersCollection = 'retailers';
  static const String portfoliosCollection = 'portfolios';
  static const String reviewsCollection = 'reviews';

  // ─── Products ─────────────────────────────────────────────────────────────

  Future<List<Product>> getProducts() async {
    try {
      final snapshot = await _firestore.collection(productsCollection).get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Product(
          id: doc.id,
          retailerId: data['retailerId'] ?? '',
          productName: data['productName'] ?? '',
          category: data['category'] ?? '',
          materialType: data['materialType'] ?? '',
          colorOptions: List<String>.from(data['colorOptions'] ?? []),
          description: data['description'] ?? '',
          careLevel: List<String>.from(data['careLevel'] ?? []),
        );
      }).toList();
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection(productsCollection)
          .where('category', isEqualTo: category)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Product(
          id: doc.id,
          retailerId: data['retailerId'] ?? '',
          productName: data['productName'] ?? '',
          category: data['category'] ?? '',
          materialType: data['materialType'] ?? '',
          colorOptions: List<String>.from(data['colorOptions'] ?? []),
          description: data['description'] ?? '',
          careLevel: List<String>.from(data['careLevel'] ?? []),
        );
      }).toList();
    } catch (e) {
      print('Error fetching products by category: $e');
      return [];
    }
  }

  Future<Product?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection(productsCollection).doc(productId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return Product(
        id: doc.id,
        retailerId: data['retailerId'] ?? '',
        productName: data['productName'] ?? '',
        category: data['category'] ?? '',
        materialType: data['materialType'] ?? '',
        colorOptions: List<String>.from(data['colorOptions'] ?? []),
        description: data['description'] ?? '',
        careLevel: List<String>.from(data['careLevel'] ?? []),
      );
    } catch (e) {
      print('Error fetching product: $e');
      return null;
    }
  }

  Stream<List<Product>> streamProducts() {
    return _firestore.collection(productsCollection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Product(
          id: doc.id,
          retailerId: data['retailerId'] ?? '',
          productName: data['productName'] ?? '',
          category: data['category'] ?? '',
          materialType: data['materialType'] ?? '',
          colorOptions: List<String>.from(data['colorOptions'] ?? []),
          description: data['description'] ?? '',
          careLevel: List<String>.from(data['careLevel'] ?? []),
        );
      }).toList();
    });
  }

  // ─── Tailors ───────────────────────────────────────────────────────────────

  Future<List<Tailor>> getTailors() async {
    try {
      final snapshot = await _firestore.collection(tailorsCollection).get();
      
      List<Tailor> tailors = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final tailor = Tailor(
          id: doc.id,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
          address: data['address'] ?? '',
          rating: (data['rating'] ?? 0).toDouble(),
        );
        
        // Fetch portfolio for this tailor
        final portfolio = await getPortfolioByTailorId(doc.id);
        tailors.add(tailor.copyWith(portfolio: portfolio));
      }
      
      return tailors;
    } catch (e) {
      print('Error fetching tailors: $e');
      return [];
    }
  }

  Future<Tailor?> getTailorById(String tailorId) async {
    try {
      final doc = await _firestore.collection(tailorsCollection).doc(tailorId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      final tailor = Tailor(
        id: doc.id,
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        address: data['address'] ?? '',
        rating: (data['rating'] ?? 0).toDouble(),
      );
      
      // Fetch portfolio for this tailor
      final portfolio = await getPortfolioByTailorId(doc.id);
      return tailor.copyWith(portfolio: portfolio);
    } catch (e) {
      print('Error fetching tailor: $e');
      return null;
    }
  }

  Stream<List<Tailor>> streamTailors() {
    return _firestore.collection(tailorsCollection).snapshots().asyncMap((snapshot) async {
      List<Tailor> tailors = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final tailor = Tailor(
          id: doc.id,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
          address: data['address'] ?? '',
          rating: (data['rating'] ?? 0).toDouble(),
        );
        
        // Fetch portfolio for this tailor
        final portfolio = await getPortfolioByTailorId(doc.id);
        tailors.add(tailor.copyWith(portfolio: portfolio));
      }
      return tailors;
    });
  }

  // ─── Retailers ─────────────────────────────────────────────────────────────

  Future<List<Retailer>> getRetailers() async {
    try {
      final snapshot = await _firestore.collection(retailersCollection).get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Retailer(
          id: doc.id,
          shopName: data['shopName'] ?? '',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
          address: data['address'] ?? '',
          rating: (data['rating'] ?? 0).toDouble(),
        );
      }).toList();
    } catch (e) {
      print('Error fetching retailers: $e');
      return [];
    }
  }

  Future<Retailer?> getRetailerById(String retailerId) async {
    try {
      final doc = await _firestore.collection(retailersCollection).doc(retailerId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return Retailer(
        id: doc.id,
        shopName: data['shopName'] ?? '',
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        address: data['address'] ?? '',
        rating: (data['rating'] ?? 0).toDouble(),
      );
    } catch (e) {
      print('Error fetching retailer: $e');
      return null;
    }
  }

  Stream<List<Retailer>> streamRetailers() {
    return _firestore.collection(retailersCollection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Retailer(
          id: doc.id,
          shopName: data['shopName'] ?? '',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
          address: data['address'] ?? '',
          rating: (data['rating'] ?? 0).toDouble(),
        );
      }).toList();
    });
  }

  // ─── Portfolio ─────────────────────────────────────────────────────────────

  Future<List<Portfolio>> getPortfolioByTailorId(String tailorId) async {
    try {
      final snapshot = await _firestore
          .collection(portfoliosCollection)
          .where('tailorId', isEqualTo: tailorId)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Portfolio(
          id: doc.id,
          tailorId: data['tailorId'] ?? '',
          image: data['image'],
          description: data['description'],
        );
      }).toList();
    } catch (e) {
      print('Error fetching portfolio: $e');
      return [];
    }
  }

  // ─── Reviews ─────────────────────────────────────────────────────────────

  Future<List<Review>> getReviewsByTargetId(String targetId, ReviewTargetRole targetRole) async {
    try {
      final snapshot = await _firestore
          .collection(reviewsCollection)
          .where('targetId', isEqualTo: targetId)
          .where('targetRole', isEqualTo: targetRole.index)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Review(
          id: doc.id,
          customerId: data['customerId'] ?? '',
          targetId: data['targetId'] ?? '',
          targetRole: ReviewTargetRole.values[data['targetRole'] ?? 0],
          orderId: data['orderId'],
          rating: (data['rating'] ?? 0).toDouble(),
          comment: data['comment'] ?? '',
        );
      }).toList();
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
    }
  }
}
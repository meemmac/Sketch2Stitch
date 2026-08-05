import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/product.dart';
import '../models/tailor.dart';
import '../models/retailer.dart';
import '../models/order.dart';

class BrowseService {
  BrowseService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ─── Products ─────────────────────────────────────────────────────────────

Stream<List<Product>> getProductsByFilter({
  String? category,
  String? materialType,
  double? minPrice,
  double? maxPrice,
  List<String>? colors,
  String sortBy = 'default',
  String? search,
}) {
  print('🔍 getProductsByFilter called');
  Query query = _db.collection('Products');
  print('📂 Querying Products collection');

  if (category != null && category != 'All') {
    query = query.where('category', isEqualTo: category);
    print('🔍 Filtering by category: $category');
  }

  return query.snapshots().map((snapshot) {
    print('📦 Received ${snapshot.docs.length} documents from Firestore');
    
    if (snapshot.docs.isEmpty) {
      print('⚠️ No documents found in Products collection');
      return <Product>[];
    }
    
    var products = snapshot.docs.map((doc) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        print('📄 Processing doc ${doc.id}: ${data['productName']}');
        print('📄 materialType value: ${data['materialType']}');
        print('📄 materialType type: ${data['materialType'].runtimeType}');
        return Product.fromJson(data);
      } catch (e) {
        print('❌ Error parsing product ${doc.id}: $e');
        print('📄 Raw data: ${doc.data()}');
        // Return a default product with error info
        return Product(
          id: doc.id,
          retailerId: '',
          productName: 'Error: ${doc.id}',
          productCode: '',
          category: '',
          materialTypes: [],
          colorOptions: [],
          description: '',
          careSymbol: [],
        );
      }
    }).toList();

    print('✅ Successfully parsed ${products.length} products');
    
    // Check if any products have errors
    final errorProducts = products.where((p) => p.productName.startsWith('Error:')).toList();
    if (errorProducts.isNotEmpty) {
      print('⚠️ ${errorProducts.length} products failed to parse');
    }
    
    return products;
  });
}

  /// Performs a prefix search on product names.
  Future<List<Product>> searchProductsByQuery(String query) async {
    if (query.isEmpty) return [];
    
    final normalizedQuery = query.toLowerCase();
    final snapshot = await _db.collection('Products')
        .where('productNameLower', isGreaterThanOrEqualTo: normalizedQuery)
        .where('productNameLower', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => Product.fromJson(doc.data())).toList();
  }

  // ─── Tailors ──────────────────────────────────────────────────────────────


  /// Filters tailors based on rating, location, and search terms.
  Stream<List<Tailor>> getTailorsByFilter({
    double? minRating,
    String? location,
    String sortBy = 'default',
    String? search,
  }) {
    Query query = _db.collection('Tailor');


    if (minRating != null && minRating > 0) {
      query = query.where('rating', isGreaterThanOrEqualTo: minRating);
    }


    if (sortBy == 'ratingHighToLow') {
      query = query.orderBy('rating', descending: true);
    }


    return query.snapshots().map((snapshot) {
      var tailors = snapshot.docs.map((doc) => Tailor.fromJson(doc.data() as Map<String, dynamic>)).toList();


      if (location != null && location != 'All') {
        tailors = tailors.where((t) => t.address.toLowerCase().contains(location.toLowerCase())).toList();
      }


      if (search != null && search.isNotEmpty) {
        tailors = tailors.where((t) => t.name.toLowerCase().contains(search.toLowerCase())).toList();
      }


      return tailors;
    });
  }


  /// Searches for tailors by name.
  Future<List<Tailor>> searchTailorsByQuery(String query) async {
    final normalizedQuery = query.toLowerCase();
    final snapshot = await _db.collection('Tailor')
        .where('nameLower', isGreaterThanOrEqualTo: normalizedQuery)
        .where('nameLower', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
        .get();


    return snapshot.docs.map((doc) => Tailor.fromJson(doc.data())).toList();
  }
// ─── Retailers ────────────────────────────────────────────────────────────


  /// Filters retailers based on rating, location, and search terms.
  Stream<List<Retailer>> getRetailersByFilter({
    double? minRating,
    String? location,
    String sortBy = 'default',
    String? search,
  }) {
    Query query = _db.collection('Retailer');


    if (minRating != null && minRating > 0) {
      query = query.where('rating', isGreaterThanOrEqualTo: minRating);
    }


    if (sortBy == 'ratingHighToLow') {
      query = query.orderBy('rating', descending: true);
    }


    return query.snapshots().map((snapshot) {
      var retailers = snapshot.docs.map((doc) => Retailer.fromJson(doc.data() as Map<String, dynamic>)).toList();


      if (location != null && location != 'All') {
        retailers = retailers.where((r) => r.address.toLowerCase().contains(location.toLowerCase())).toList();
      }


      if (search != null && search.isNotEmpty) {
        retailers = retailers.where((r) => r.shopName.toLowerCase().contains(search.toLowerCase())).toList();
      }


      return retailers;
    });
  }


  /// Searches for retailers by shop name.
  Future<List<Retailer>> searchRetailersByQuery(String query) async {
    final normalizedQuery = query.toLowerCase();
    final snapshot = await _db.collection('Retailer')
        .where('shopNameLower', isGreaterThanOrEqualTo: normalizedQuery)
        .where('shopNameLower', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
        .get();


    return snapshot.docs.map((doc) => Retailer.fromJson(doc.data())).toList();
  }


// ─── Orders ───────────────────────────────────────────────────────────────


  /// Searches through a customer's orders.
  Stream<List<Order>> searchOrders(String customerId, String query) {
    return _db.collection('Orders')
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => Order.fromJson(doc.data()))
          .toList();

      if (query.isEmpty) return orders;


      final lowerQuery = query.toLowerCase();
      return orders.where((o) {
        return o.id.toLowerCase().contains(lowerQuery) ||
            o.status.name.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

}

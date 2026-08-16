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

  /// Filters products based on multiple criteria.
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
    print('📊 category: $category, materialType: $materialType');
    print('📊 minPrice: $minPrice, maxPrice: $maxPrice');
    print('📊 colors: $colors, sortBy: $sortBy, search: $search');
    
    Query query = _db.collection('Products');

    if (category != null && category != 'All' && category != 'Elements') {
      query = query.where('category', isEqualTo: category);
      print('🔍 Filtering by category: $category');
    }

    // Apply sorting logic
    if (sortBy == 'lowToHigh') {
      query = query.orderBy('minPrice', descending: false);
    } else if (sortBy == 'highToLow') {
      query = query.orderBy('maxPrice', descending: true);
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
          return Product.fromJson(data, id: doc.id);
        } catch (e) {
          print('❌ Error parsing product ${doc.id}: $e');
          return Product(
            id: doc.id,
            retailerId: '',
            productName: 'Error: ${doc.id}',
            productCode: '',
            category: '',
            materialType: [],
            colorOptions: [],
            description: '',
            careSymbol: [],
          );
        }
      }).toList();

      // Client-side filtering for more complex logic
      
      // Filter by material type - updated for MaterialBlend
      if (materialType != null && materialType != 'All') {
        products = products.where((p) {
          // Check if any material type contains the filter string
          return p.materialType.any(
            (m) => m.type.toLowerCase().contains(materialType.toLowerCase())
          );
        }).toList();
        print('📊 After material filter: ${products.length} products');
      }

      // Filter by price
      if (minPrice != null || maxPrice != null) {
        products = products.where((p) {
          final price = p.minPrice;
          return (minPrice == null || price >= minPrice) && 
                 (maxPrice == null || price <= maxPrice);
        }).toList();
        print('📊 After price filter: ${products.length} products');
      }

      // Filter by colors
      if (colors != null && colors.isNotEmpty && !colors.contains('All')) {
        products = products.where((p) {
          final productColors = p.colorOptions
              .map((c) => c.color.toLowerCase())
              .toList();
          return colors.any((c) => productColors.contains(c.toLowerCase()));
        }).toList();
        print('📊 After color filter: ${products.length} products');
      }

      // Filter by search
      if (search != null && search.isNotEmpty) {
        final lowerSearch = search.toLowerCase();
        products = products.where((p) {
          return p.productName.toLowerCase().contains(lowerSearch) ||
                 p.description.toLowerCase().contains(lowerSearch);
        }).toList();
        print('📊 After search filter: ${products.length} products');
      }

      print('✅ Returning ${products.length} products');
      return products;
    });
  }

  /// Performs a prefix search on product names.
  Future<List<Product>> searchProductsByQuery(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final normalizedQuery = query.toLowerCase();
      final snapshot = await _db.collection('Products')
          .where('productNameLower', isGreaterThanOrEqualTo: normalizedQuery)
          .where('productNameLower', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        try {
          return Product.fromJson(doc.data(), id: doc.id);
        } catch (e) {
          print('❌ Error parsing product in search: $e');
          return Product(
            id: doc.id,
            retailerId: '',
            productName: 'Error',
            category: '',
            materialType: [],
            colorOptions: [],
            description: '',
            careSymbol: [],
          );
        }
      }).toList();
    } catch (e) {
      print('❌ Error in searchProductsByQuery: $e');
      return [];
    }
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
        tailors = tailors
            .where(
              (t) => t.address.toLowerCase().contains(location.toLowerCase()),
            )
            .toList();
      }

      if (search != null && search.isNotEmpty) {
        final lowerSearch = search.toLowerCase();
        tailors = tailors.where((t) => 
          t.name.toLowerCase().contains(lowerSearch) ||
          t.address.toLowerCase().contains(lowerSearch)
        ).toList();
      }

      return tailors;
    });
  }

  /// Searches for tailors by name.
  Future<List<Tailor>> searchTailorsByQuery(String query) async {
    try {
      final normalizedQuery = query.toLowerCase();
      final snapshot = await _db.collection('Tailor')
          .where('nameLower', isGreaterThanOrEqualTo: normalizedQuery)
          .where('nameLower', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
          .get();

      return snapshot.docs.map((doc) => Tailor.fromJson(doc.data())).toList();
    } catch (e) {
      print('❌ Error in searchTailorsByQuery: $e');
      return [];
    }
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
        retailers = retailers
            .where(
              (r) => r.address.toLowerCase().contains(location.toLowerCase()),
            )
            .toList();
      }

      if (search != null && search.isNotEmpty) {
        final lowerSearch = search.toLowerCase();
        retailers = retailers.where((r) => 
          r.shopName.toLowerCase().contains(lowerSearch) ||
          r.address.toLowerCase().contains(lowerSearch)
        ).toList();
      }

      return retailers;
    });
  }

  /// Searches for retailers by shop name.
  Future<List<Retailer>> searchRetailersByQuery(String query) async {
    try {
      final normalizedQuery = query.toLowerCase();
      final snapshot = await _db.collection('Retailer')
          .where('shopNameLower', isGreaterThanOrEqualTo: normalizedQuery)
          .where('shopNameLower', isLessThanOrEqualTo: '$normalizedQuery\uf8ff')
          .get();

      return snapshot.docs.map((doc) => Retailer.fromJson(doc.data())).toList();
    } catch (e) {
      print('❌ Error in searchRetailersByQuery: $e');
      return [];
    }
  }

  // ─── Orders ───────────────────────────────────────────────────────────────

  /// Searches through a customer's orders.
  Stream<List<Order>> searchOrders(String customerId, String query) {
    return _db
        .collection('Orders')
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
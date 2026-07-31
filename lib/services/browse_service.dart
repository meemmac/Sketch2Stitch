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
    Query query = _db.collection('Products');

    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    // Apply sorting logic
    if (sortBy == 'lowToHigh') {
      query = query.orderBy('minPrice', descending: false);
    } else if (sortBy == 'highToLow') {
      query = query.orderBy('maxPrice', descending: true);
    }

    return query.snapshots().map((snapshot) {
      var products = snapshot.docs.map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>)).toList();

      // Client-side filtering for more complex logic not easily handled by Firestore queries
      if (minPrice != null || maxPrice != null) {
        products = products.where((p) {
          final price = p.minPrice;
          return (minPrice == null || price >= minPrice) && (maxPrice == null || price <= maxPrice);
        }).toList();
      }

      if (materialType != null && materialType != 'All') {
        products = products.where((p) => p.materialType.toLowerCase().contains(materialType.toLowerCase())).toList();
      }

      if (colors != null && colors.isNotEmpty && !colors.contains('All')) {
        products = products.where((p) {
          final productColors = p.colorOptions.map((c) => c.color.toLowerCase()).toList();
          return colors.any((c) => productColors.contains(c.toLowerCase()));
        }).toList();
      }

      if (search != null && search.isNotEmpty) {
        products = products.where((p) => p.productName.toLowerCase().contains(search.toLowerCase())).toList();
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


}

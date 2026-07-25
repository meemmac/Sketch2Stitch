// lib/screens/customer/browsing/filter_data.dart

abstract class ProductFilterData {
  final double minPrice;
  final double maxPrice;
  final String color;
  final List<String> materialTypes; // Changed from String to List<String>
  final String sortBy; // 'default', 'lowToHigh', 'highToLow'

  ProductFilterData({
    required this.minPrice,
    required this.maxPrice,
    required this.color,
    required this.materialTypes,
    this.sortBy = 'default',
  });

  bool get hasFilters {
    return minPrice > 0 ||
        maxPrice < 5000 ||
        color != 'All' ||
        (materialTypes.isNotEmpty && !materialTypes.contains('All')) ||
        sortBy != 'default';
  }

  /// Check if a product matches any of the selected material types
  bool matchesMaterial(String? productMaterialType, List<String>? productMaterialBlends) {
    // If no material types selected or 'All' selected, return true
    if (materialTypes.isEmpty || materialTypes.contains('All')) {
      return true;
    }

    // Check if product has material blends (from FabricProductData)
    if (productMaterialBlends != null && productMaterialBlends.isNotEmpty) {
      // Check if any blend matches any selected material type
      for (final blend in productMaterialBlends) {
        for (final selectedType in materialTypes) {
          if (blend.toLowerCase().contains(selectedType.toLowerCase())) {
            return true;
          }
        }
      }
      return false;
    }

    // Fallback: check materialType field
    if (productMaterialType == null || productMaterialType.isEmpty) {
      return false;
    }

    // Check if product material type matches any selected type
    for (final selectedType in materialTypes) {
      if (productMaterialType.toLowerCase().contains(selectedType.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}

class FabricsFilterData extends ProductFilterData {
  FabricsFilterData({
    required super.minPrice,
    required super.maxPrice,
    required super.color,
    required super.materialTypes,
    super.sortBy = 'default',
  });
}

class ElementsFilterData extends ProductFilterData {
  ElementsFilterData({
    required super.minPrice,
    required super.maxPrice,
    required super.color,
    required super.materialTypes,
    super.sortBy = 'default',
  });
}

class TailorsFilterData {
  final double minRating;
  final String location;
  final String sortBy; // 'default', 'ratingHighToLow', 'ratingLowToHigh'

  TailorsFilterData({
    required this.minRating,
    required this.location,
    this.sortBy = 'default',
  });

  bool get hasFilters {
    return minRating > 0 || location != 'All' || sortBy != 'default';
  }
}

class RetailersFilterData {
  final double minRating;
  final String location;
  final String sortBy; // 'default', 'ratingHighToLow', 'ratingLowToHigh'

  RetailersFilterData({
    required this.minRating,
    required this.location,
    this.sortBy = 'default',
  });

  bool get hasFilters {
    return minRating > 0 || location != 'All' || sortBy != 'default';
  }
}

// ─── Material Filter Helper ────────────────────────────────────────────

/// Available material types for filtering (from material blends)
/// Removed 'Fasteners' and 'Lace' (Lace is now in fabrics)
class MaterialFilterOptions {
  static const List<String> allMaterials = [
    'All',
    'Cotton',
    'Silk',
    'Wool',
    'Linen',
    'Polyester',
    'Viscose',
    'Nylon',
    'Cashmere',
    'Spandex',
    'Khadi',
    'Muslin',
    'Jamdani',
    'Embroidery',
  ];

  /// Extract material types from product material blends
  static List<String> extractFromBlends(List<String> blends) {
    final Set<String> materials = {};
    for (final blend in blends) {
      // Try to extract material names from blend strings like "70% Silk" or "100% Cotton"
      final parts = blend.split(',').map((s) => s.trim()).toList();
      for (final part in parts) {
        // Remove percentage and clean up
        String cleanPart = part.replaceAll(RegExp(r'^\d+%'), '').trim();
        // Check if it matches any known material
        for (final material in allMaterials) {
          if (material != 'All' && cleanPart.toLowerCase().contains(material.toLowerCase())) {
            materials.add(material);
            break;
          }
        }
      }
    }
    return materials.toList();
  }

  /// Get material options for filter dropdown
  static List<String> getMaterialOptions() {
    return allMaterials;
  }
}
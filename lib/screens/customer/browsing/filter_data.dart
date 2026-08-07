// lib/screens/customer/browsing/filter_data.dart

abstract class ProductFilterData {
  final double minPrice;
  final double maxPrice;
  final List<String> colors; // Changed from String to List<String>
  final List<String> materialTypes;
  final String sortBy;
  final double minRating; // Added back as common field

  ProductFilterData({
    required this.minPrice,
    required this.maxPrice,
    required this.colors,
    required this.materialTypes,
    this.sortBy = 'default',
    this.minRating = 0.0,
  });

  bool get hasFilters {
    return minPrice > 0 ||
        maxPrice < 5000 ||
        (colors.isNotEmpty && !colors.contains('All')) ||
        (materialTypes.isNotEmpty && !materialTypes.contains('All')) ||
        sortBy != 'default' ||
        minRating > 0;
  }

  /// Check if a product matches any of the selected colors
  bool matchesColor(List<String>? productColors) {
    if (colors.isEmpty || colors.contains('All')) {
      return true;
    }

    if (productColors == null || productColors.isEmpty) {
      return false;
    }

    for (final productColor in productColors) {
      for (final selectedColor in colors) {
        if (productColor.toLowerCase().contains(selectedColor.toLowerCase())) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if a product matches any of the selected material types
  bool matchesMaterial(String? productMaterialType, List<String>? productMaterialBlends) {
    if (materialTypes.isEmpty || materialTypes.contains('All')) {
      return true;
    }

    if (productMaterialBlends != null && productMaterialBlends.isNotEmpty) {
      for (final blend in productMaterialBlends) {
        for (final selectedType in materialTypes) {
          if (blend.toLowerCase().contains(selectedType.toLowerCase())) {
            return true;
          }
        }
      }
      return false;
    }

    if (productMaterialType == null || productMaterialType.isEmpty) {
      return false;
    }

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
    required super.colors,
    required super.materialTypes,
    super.sortBy = 'default',
    super.minRating = 0.0,
  });
}

class ElementsFilterData extends ProductFilterData {
  ElementsFilterData({
    required super.minPrice,
    required super.maxPrice,
    required super.colors,
    required super.materialTypes,
    super.sortBy = 'default',
    super.minRating = 0.0,
  });
}

class TailorsFilterData {
  final double minRating;
  final String location;
  final String sortBy;

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
  final String sortBy;

  RetailersFilterData({
    required this.minRating,
    required this.location,
    this.sortBy = 'default',
  });

  bool get hasFilters {
    return minRating > 0 || location != 'All' || sortBy != 'default';
  }
}

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
    'Plastic',
    'Glass',
    'Satin',
    'Lace',
  ];

  static List<String> extractFromBlends(List<String> blends) {
    final Set<String> materials = {};
    for (final blend in blends) {
      final parts = blend.split(',').map((s) => s.trim()).toList();
      for (final part in parts) {
        String cleanPart = part.replaceAll(RegExp(r'^\d+%'), '').trim();
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

  static List<String> getMaterialOptions() {
    return allMaterials;
  }
}

class ColorFilterOptions {
  static const List<String> allColors = [
    'All',
    'White',
    'Black',
    'Red',
    'Blue',
    'Green',
    'Gold',
    'Silver',
    'Pink',
    'Beige',
    'Brown',
    'Purple',
  ];

  static List<String> extractFromProductColors(List<String> productColors) {
    final Set<String> colors = {};
    for (final color in productColors) {
      final cleanColor = color.trim();
      for (final availableColor in allColors) {
        if (availableColor != 'All' && 
            cleanColor.toLowerCase().contains(availableColor.toLowerCase())) {
          colors.add(availableColor);
          break;
        }
      }
    }
    return colors.toList();
  }

  static List<String> getColorOptions() {
    return allColors;
  }

  static bool matchesSelectedColors(String colorName, List<String> selectedColors) {
    if (selectedColors.isEmpty || selectedColors.contains('All')) {
      return true;
    }
    
    final cleanColorName = colorName.toLowerCase();
    for (final selected in selectedColors) {
      if (cleanColorName.contains(selected.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}

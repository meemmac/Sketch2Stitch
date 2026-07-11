// lib/screens/customer/browsing/filter_data.dart

class FabricsFilterData {
  final double minPrice;
  final double maxPrice;
  final String color;
  final String materialType;
  final String sortBy; // 'default', 'lowToHigh', 'highToLow'
  // NO RATING FOR FABRICS

  FabricsFilterData({
    required this.minPrice,
    required this.maxPrice,
    required this.color,
    required this.materialType,
    this.sortBy = 'default',
  });

  bool get hasFilters {
    return minPrice > 0 ||
        maxPrice < 5000 ||
        color != 'All' ||
        materialType != 'All' ||
        sortBy != 'default';
  }
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
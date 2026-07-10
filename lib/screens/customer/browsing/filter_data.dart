// lib/screens/customer/browsing/filter_data.dart

class FabricsFilterData {
  final double minPrice;
  final double maxPrice;
  final String color;
  final String materialType;
  // NO RATING FOR FABRICS

  FabricsFilterData({
    required this.minPrice,
    required this.maxPrice,
    required this.color,
    required this.materialType,
  });

  bool get hasFilters {
    return minPrice > 0 || 
           maxPrice < 5000 || 
           color != 'All' || 
           materialType != 'All';
  }
}

class TailorsFilterData {
  final double minRating;
  final String location;

  TailorsFilterData({
    required this.minRating,
    required this.location,
  });

  bool get hasFilters {
    return minRating > 0 || location != 'All';
  }
}

class RetailersFilterData {
  final double minRating;
  final String location;

  RetailersFilterData({
    required this.minRating,
    required this.location,
  });

  bool get hasFilters {
    return minRating > 0 || location != 'All';
  }
}
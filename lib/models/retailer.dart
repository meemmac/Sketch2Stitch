import 'review.dart';

class Retailer {
  final String id;
  final String shopName;
  final String email;
  final String phone;
  final String address;
  final List<String> licenses;
  final double rating;
  final int reviewCount;
  final String? logoUrl;
  final String? description;
  final List<Review> reviews;
  bool isFavorite;

  Retailer({
    required this.id,
    required this.shopName,
    required this.email,
    required this.phone,
    required this.address,
    required this.licenses,
    required this.rating,
    this.reviewCount = 0,
    this.logoUrl,
    this.description,
    this.reviews = const [],
    this.isFavorite = false,
  });

  bool get hasLicense => licenses.isNotEmpty;

  String get generalArea {
    final parts = address.split(',');
    if (parts.length > 1) {
      return parts[parts.length - 2].trim();
    }
    return address;
  }

  Retailer copyWith({
    String? id,
    String? shopName,
    String? email,
    String? phone,
    String? address,
    List<String>? licenses,
    double? rating,
    int? reviewCount,
    String? logoUrl,
    String? description,
    List<Review>? reviews,
    bool? isFavorite,
  }) {
    return Retailer(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      licenses: licenses ?? this.licenses,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      logoUrl: logoUrl ?? this.logoUrl,
      description: description ?? this.description,
      reviews: reviews ?? this.reviews,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
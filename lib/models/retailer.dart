import 'product.dart';
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
  final List<Product> products;
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
    this.products = const [],
    this.reviews = const [],
    this.isFavorite = false,
  });

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
    List<Product>? products,
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
      products: products ?? this.products,
      reviews: reviews ?? this.reviews,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'shopName': shopName,
    'email': email,
    'phone': phone,
    'address': address,
    'licenses': licenses,
    'rating': rating,
    'reviewCount': reviewCount,
    'logoUrl': logoUrl,
    'description': description,
    'isFavorite': isFavorite,
  };
}
import 'product.dart';
import 'sub_order.dart';

class Retailer {
  final String id;
  final String shopName;
  final String email;
  final String phone;
  final String address;
  final List<String> licenses;
  final double rating;
  
  // Relationships
  List<Product>? products;
  List<SubOrder>? suborders;


  Retailer({
    required this.id,
    required this.shopName,
    required this.email,
    required this.phone,
    required this.address,
    required this.licenses,
    required this.rating,
    this.products = const [],
    this.suborders = const [],
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
    String? logoUrl,
    String? description,
    List<Product>? products,
    List<SubOrder>? suborders,
  }) {
    return Retailer(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      licenses: licenses ?? this.licenses,
      rating: rating ?? this.rating,
      products: products ?? this.products,
      suborders: suborders ?? this.suborders,
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
  };

  factory Retailer.fromJson(Map<String, dynamic> json) {
    return Retailer(
      id: json['id'] ?? '',
      shopName: json['shopName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      licenses: List<String>.from(json['licenses'] ?? []),
      rating: (json['rating'] ?? 0).toDouble(),
    );
  }
}
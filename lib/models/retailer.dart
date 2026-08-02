import 'package:cloud_firestore/cloud_firestore.dart';
import 'product.dart';
import 'sub_order.dart';

class Retailer {
  final String id;
  final String shopName;
  final String email;
  final String phone;
  final String address;
  final double rating;
  final String? profilePicture;
  final String? about;
  final GeoPoint? location;

  // Relationships
  List<Product>? products;
  List<SubOrder>? suborders;

  Retailer({
    required this.id,
    required this.shopName,
    required this.email,
    required this.phone,
    required this.address,
    required this.rating,
    this.location,
    this.profilePicture,
    this.about,
    this.products = const [],
    this.suborders = const [],
  });

  double? get locationLat => location?.latitude;
  double? get locationLng => location?.longitude;

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
    double? rating,
    GeoPoint? location,
    String? profilePicture,
    String? about,
    List<Product>? products,
    List<SubOrder>? suborders,
  }) {
    return Retailer(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      location: location ?? this.location,
      profilePicture: profilePicture ?? this.profilePicture,
      about: about ?? this.about,
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
    'rating': rating,
    'location': location,
    'profilePicture': profilePicture,
    'about': about,
  };

  factory Retailer.fromJson(Map<String, dynamic> json, {String? id}) {
    return Retailer(
      id: id ?? json['id'] ?? '',
      shopName: json['shopName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address'] ?? '',
      rating: (json['rating'] ?? 5.0).toDouble(),
      location: json['location'] is GeoPoint ? json['location'] as GeoPoint : null,
      profilePicture: json['profilePicture'],
      about: json['about'],
    );
  }
}

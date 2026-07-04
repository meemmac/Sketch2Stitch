import 'portfolio.dart';
import 'review.dart';

class Tailor {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final List<String> licenses;
  final double rating;
  final int reviewCount;
  final String? profileImage;
  final String? description;
  final List<Portfolio> portfolio;
  final List<Review> reviews;
  bool isFavorite;

  Tailor({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.licenses,
    required this.rating,
    this.reviewCount = 0,
    this.profileImage,
    this.description,
    this.portfolio = const [],
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

  Tailor copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    List<String>? licenses,
    double? rating,
    int? reviewCount,
    String? profileImage,
    String? description,
    List<Portfolio>? portfolio,
    List<Review>? reviews,
    bool? isFavorite,
  }) {
    return Tailor(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      licenses: licenses ?? this.licenses,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      profileImage: profileImage ?? this.profileImage,
      description: description ?? this.description,
      portfolio: portfolio ?? this.portfolio,
      reviews: reviews ?? this.reviews,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
import 'portfolio.dart';
import 'tailor_job.dart';
import 'notification.dart';

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
  
  // Relationships
  List<Portfolio>? portfolio;
  List<Notifications>? notifications;  // Notifications for this tailor
  List<TailorJob>? jobs;

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
    this.notifications = const [],
    this.jobs = const [],
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
    List<Notifications>? notifications,
    List<TailorJob>? jobs,
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
      notifications: notifications ?? this.notifications,
      jobs: jobs ?? this.jobs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'licenses': licenses,
    'rating': rating,
    'reviewCount': reviewCount,
    'profileImage': profileImage,
    'description': description,
  };

  factory Tailor.fromJson(Map<String, dynamic> json) {
    return Tailor(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      licenses: List<String>.from(json['licenses'] ?? []),
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      profileImage: json['profileImage'],
      description: json['description'],
    );
  }
}
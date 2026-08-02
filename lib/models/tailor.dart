import 'package:cloud_firestore/cloud_firestore.dart';
import 'portfolio.dart';
import 'tailor_job.dart';
import 'notification.dart';

class Tailor {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final double rating;
  final String? profilePicture;
  final String? about;
  final GeoPoint? location;

  // Relationships
  List<Portfolio>? portfolio;
  List<AppNotification>? notifications;
  List<TailorJob>? jobs;

  Tailor({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.rating,
    this.location,
    this.profilePicture,
    this.about,
    this.portfolio = const [],
    this.notifications = const [],
    this.jobs = const [],
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

  Tailor copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    double? rating,
    GeoPoint? location,
    String? profilePicture,
    String? about,
    List<Portfolio>? portfolio,
    List<AppNotification>? notifications,
    List<TailorJob>? jobs,
  }) {
    return Tailor(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      rating: rating ?? this.rating,
      location: location ?? this.location,
      profilePicture: profilePicture ?? this.profilePicture,
      about: about ?? this.about,
      portfolio: portfolio ?? this.portfolio,
      notifications: notifications ?? this.notifications,
      jobs: jobs ?? this.jobs,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'rating': rating,
    'location': location,
    'profilePicture': profilePicture,
    'about': about,
  };

  factory Tailor.fromJson(Map<String, dynamic> json, {String? id}) {
    return Tailor(
      id: id ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      location: json['location'] is GeoPoint ? json['location'] as GeoPoint : null,
      profilePicture: json['profilePicture'],
      about: json['about'],
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'measurement.dart';
import 'design.dart';
import 'order.dart';
import 'review.dart';
import 'conversation.dart';
import 'favorite.dart';
import 'notification.dart';

class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final GeoPoint? location;

  // Relationships
  List<Measurement>? measurements;
  List<Order>? orders;
  List<Review>? reviews;
  List<Conversation>? conversations;
  List<Favorite>? favorites;
  List<Design>? designs;
  List<AppNotification>? notifications;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.location,
    this.measurements,
    this.designs,
    this.orders,
    this.reviews,
    this.conversations,
    this.favorites,
    this.notifications,
  });

  double? get locationLat => location?.latitude;
  double? get locationLng => location?.longitude;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'location': location,
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      location: json['location'] is GeoPoint ? json['location'] as GeoPoint : null,
    );
  }
}
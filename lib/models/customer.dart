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
  
  // Relationships
  List<Measurement>? measurements;
  List<Order>? orders;
  List<Review>? reviews;
  List<Conversation>? conversations;
  List<Favorite>? favorites;
  List<Design>? designs;
  List<Notifications>? notifications;


  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.measurements,
    this.designs,
    this.orders,
    this.reviews,
    this.conversations,
    this.favorites,
    this.notifications,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'measurement.dart';
import 'design.dart';
import 'order.dart';
import 'review.dart';
import 'conversation.dart';
import 'favorite.dart';
import 'notification.dart';

/// Flat monthly cap for Virtual Trial generations.
const int kVirtualTrialMonthlyLimit = 20;

class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final GeoPoint? location;

  // ── Virtual Trial usage tracking ──────────────────────────────
  final int vtUsed;
  final DateTime? vtResetDate;

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
    this.vtUsed = 0,
    this.vtResetDate,
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

  int get vtRemaining =>
      (kVirtualTrialMonthlyLimit - vtUsed).clamp(0, kVirtualTrialMonthlyLimit);

  bool get vtLimitReached => vtUsed >= kVirtualTrialMonthlyLimit;

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'location': location,
    'vtUsed': vtUsed,
    'vtResetDate':
        vtResetDate != null ? Timestamp.fromDate(vtResetDate!) : null,
  };

  factory Customer.fromJson(Map<String, dynamic> json, {String? id}) {
    return Customer(
      id: id ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address'] ?? '',
      location: json['location'] is GeoPoint
          ? json['location'] as GeoPoint
          : null,
      vtUsed: json['vtUsed'] ?? 0,
      vtResetDate: json['vtResetDate'] is Timestamp
          ? (json['vtResetDate'] as Timestamp).toDate()
          : null,
    );
  }

  Customer copyWith({int? vtUsed, DateTime? vtResetDate}) => Customer(
    id: id,
    name: name,
    email: email,
    phone: phone,
    address: address,
    location: location,
    vtUsed: vtUsed ?? this.vtUsed,
    vtResetDate: vtResetDate ?? this.vtResetDate,
    measurements: measurements,
    orders: orders,
    reviews: reviews,
    conversations: conversations,
    favorites: favorites,
    designs: designs,
    notifications: notifications,
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_item.dart';

enum SubOrderStatus {
  preparing,
  packed,
  delivered,
}

enum SubOrderDeliveryDestination {
  pending,
  customer,
  tailor,
}

class SubOrder {
  final String id;
  final String orderId;
  final String retailerId;
  final SubOrderStatus status;
  final SubOrderDeliveryDestination deliveryDestination;
  final GeoPoint? deliveryPoint; // snapshot of the exact coords used for the charge calc
  final DateTime? deliveryDate;
  final DateTime? autoReleaseAt;
  final double itemsSubtotal;
  final double deliveryCharge;     // computed from distance — not a base rate
  final double? deliveryDistanceKm;

  List<OrderItem>? items;

  SubOrder({
    required this.id,
    required this.orderId,
    required this.retailerId,
    required this.status,
    this.deliveryDestination = SubOrderDeliveryDestination.pending,
    this.deliveryPoint,
    this.deliveryDate,
    this.autoReleaseAt,
    this.itemsSubtotal = 0,
    this.deliveryCharge = 0,
    this.deliveryDistanceKm,
    this.items = const [],
  });

  double get total => itemsSubtotal + deliveryCharge;

  String get statusText {
    switch (status) {
      case SubOrderStatus.preparing:
        return 'Preparing';
      case SubOrderStatus.packed:
        return 'Packed';
      case SubOrderStatus.delivered:
        return 'Delivered';
    }
  }

  String get deliveryDestinationText {
    switch (deliveryDestination) {
      case SubOrderDeliveryDestination.pending:
        return 'Pending';
      case SubOrderDeliveryDestination.customer:
        return 'To Customer';
      case SubOrderDeliveryDestination.tailor:
        return 'To Tailor';
    }
  }

  SubOrder copyWith({
    String? id,
    String? orderId,
    String? retailerId,
    SubOrderStatus? status,
    SubOrderDeliveryDestination? deliveryDestination,
    GeoPoint? deliveryPoint,
    DateTime? deliveryDate,
    DateTime? autoReleaseAt,
    double? itemsSubtotal,
    double? deliveryCharge,
    double? deliveryDistanceKm,
    List<OrderItem>? items,
  }) {
    return SubOrder(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      retailerId: retailerId ?? this.retailerId,
      status: status ?? this.status,
      deliveryDestination: deliveryDestination ?? this.deliveryDestination,
      deliveryPoint: deliveryPoint ?? this.deliveryPoint,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      autoReleaseAt: autoReleaseAt ?? this.autoReleaseAt,
      itemsSubtotal: itemsSubtotal ?? this.itemsSubtotal,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      deliveryDistanceKm: deliveryDistanceKm ?? this.deliveryDistanceKm,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'retailerId': retailerId,
    'status': status.name,
    'deliveryDestination': deliveryDestination.name,
    'deliveryPoint': deliveryPoint,
    'deliveryDate': deliveryDate?.toIso8601String(),
    'autoReleaseAt': autoReleaseAt?.toIso8601String(),
    'itemsSubtotal': itemsSubtotal,
    'deliveryCharge': deliveryCharge,
    'deliveryDistanceKm': deliveryDistanceKm,
  };

  factory SubOrder.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }


    return SubOrder(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      retailerId: json['retailerId'] ?? '',
      status: SubOrderStatus.values.byName(json['status'] ?? 'preparing'),
      deliveryDestination: SubOrderDeliveryDestination.values.byName(
        json['deliveryDestination'] ?? 'pending',
      ),
      deliveryPoint: json['deliveryPoint'] as GeoPoint?,
      deliveryDate: parseDate(json['deliveryDate']),
      autoReleaseAt: parseDate(json['autoReleaseAt']),
      itemsSubtotal: (json['itemsSubtotal'] ?? 0).toDouble(),
      deliveryCharge: (json['deliveryCharge'] ?? 0).toDouble(),
      deliveryDistanceKm: (json['deliveryDistanceKm'] as num?)?.toDouble(),
    );
  }
}
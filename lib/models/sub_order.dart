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
  final DateTime? deliveryDate;
  final DateTime? autoReleaseAt;

  // Relationships
  List<OrderItem>? items;

  SubOrder({
    required this.id,
    required this.orderId,
    required this.retailerId,
    required this.status,
    this.deliveryDestination = SubOrderDeliveryDestination.pending,
    this.deliveryDate,
    this.autoReleaseAt,
    this.items = const [],
  });

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
    DateTime? deliveryDate,
    DateTime? autoReleaseAt,
    List<OrderItem>? items,
  }) {
    return SubOrder(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      retailerId: retailerId ?? this.retailerId,
      status: status ?? this.status,
      deliveryDestination: deliveryDestination ?? this.deliveryDestination,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      autoReleaseAt: autoReleaseAt ?? this.autoReleaseAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'retailerId': retailerId,
    'status': status.name,
    'deliveryDestination': deliveryDestination.name,
    'deliveryDate': deliveryDate?.toIso8601String(),
    'autoReleaseAt': autoReleaseAt?.toIso8601String(),
  };

  factory SubOrder.fromJson(Map<String, dynamic> json) {
    return SubOrder(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      retailerId: json['retailerId'] ?? '',
      status: SubOrderStatus.values.byName(json['status'] ?? 'preparing'),
      deliveryDestination: SubOrderDeliveryDestination.values.byName(
        json['deliveryDestination'] ?? 'pending',
      ),
      deliveryDate: json['deliveryDate'] != null
          ? DateTime.parse(json['deliveryDate'])
          : null,
      autoReleaseAt: json['autoReleaseAt'] != null
          ? DateTime.parse(json['autoReleaseAt'])
          : null,
    );
  }
}
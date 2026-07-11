import 'order_item.dart';
import 'order.dart';  // For PaymentStatus enum

enum SubOrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  delivered,
  cancelled,
  rejected,
}

class SubOrder {
  final String id;
  final String orderId;
  final String retailerId;
  final SubOrderStatus status;
  final DateTime? deliveryDate;
  final DateTime? confirmedAt;
  final String? rejectionReason;
  final PaymentStatus paymentStatus;  // From order.dart
  final DateTime? paymentReleaseDeadline;
  final DateTime? autoReleaseAt;
  
  // Relationships
  List<OrderItem>? items;

  SubOrder({
    required this.id,
    required this.orderId,
    required this.retailerId,
    required this.status,
    this.deliveryDate,
    this.confirmedAt,
    this.rejectionReason,
    required this.paymentStatus,
    this.paymentReleaseDeadline,
    this.autoReleaseAt,
    this.items = const [],
  });

  String get statusText {
    switch (status) {
      case SubOrderStatus.pending:
        return 'Pending';
      case SubOrderStatus.confirmed:
        return 'Confirmed';
      case SubOrderStatus.processing:
        return 'Processing';
      case SubOrderStatus.shipped:
        return 'Shipped';
      case SubOrderStatus.delivered:
        return 'Delivered';
      case SubOrderStatus.cancelled:
        return 'Cancelled';
      case SubOrderStatus.rejected:
        return 'Rejected';
    }
  }

  String get paymentStatusText {
    switch (paymentStatus) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  SubOrder copyWith({
    String? id,
    String? orderId,
    String? retailerId,
    SubOrderStatus? status,
    DateTime? deliveryDate,
    DateTime? confirmedAt,
    String? rejectionReason,
    PaymentStatus? paymentStatus,
    DateTime? paymentReleaseDeadline,
    DateTime? autoReleaseAt,
    List<OrderItem>? items,
  }) {
    return SubOrder(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      retailerId: retailerId ?? this.retailerId,
      status: status ?? this.status,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentReleaseDeadline: paymentReleaseDeadline ?? this.paymentReleaseDeadline,
      autoReleaseAt: autoReleaseAt ?? this.autoReleaseAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'retailerId': retailerId,
    'status': status.index,
    'deliveryDate': deliveryDate?.toIso8601String(),
    'confirmedAt': confirmedAt?.toIso8601String(),
    'rejectionReason': rejectionReason,
    'paymentStatus': paymentStatus.index,
    'paymentReleaseDeadline': paymentReleaseDeadline?.toIso8601String(),
    'autoReleaseAt': autoReleaseAt?.toIso8601String(),
  };

  factory SubOrder.fromJson(Map<String, dynamic> json) {
    return SubOrder(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      retailerId: json['retailerId'] ?? '',
      status: SubOrderStatus.values[json['status'] ?? 0],
      deliveryDate: json['deliveryDate'] != null 
          ? DateTime.parse(json['deliveryDate']) 
          : null,
      confirmedAt: json['confirmedAt'] != null 
          ? DateTime.parse(json['confirmedAt']) 
          : null,
      rejectionReason: json['rejectionReason'],
      paymentStatus: PaymentStatus.values[json['paymentStatus'] ?? 0],
      paymentReleaseDeadline: json['paymentReleaseDeadline'] != null 
          ? DateTime.parse(json['paymentReleaseDeadline']) 
          : null,
      autoReleaseAt: json['autoReleaseAt'] != null 
          ? DateTime.parse(json['autoReleaseAt']) 
          : null,
    );
  }
}
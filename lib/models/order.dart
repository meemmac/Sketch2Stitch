import 'package:flutter/material.dart';
import 'sub_order.dart';
import 'payment.dart';
import 'tailor_job.dart';
import 'conversation.dart';
import 'review.dart';

enum OrderStatus {
  pending,
  confirmed,
  tailoring,
  ready,
  delivered,
  cancelled,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

class Order {
  final String id;
  final String customerId;
  final DateTime orderDate;
  final double totalPrice;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final DateTime? paymentDeadline;
  final DateTime? tailorSelectionDeadline;
  
  // Relationships
  List<SubOrder>? subOrders;
  List<Payment>? payments;
  List<TailorJob>? tailorJobs;
  List<Conversation>? conversations;
  List<Review>? reviews;

  Order({
    required this.id,
    required this.customerId,
    required this.orderDate,
    required this.totalPrice,
    required this.status,
    required this.paymentStatus,
    this.paymentDeadline,
    this.tailorSelectionDeadline,
    this.subOrders = const [],
    this.payments = const [],
    this.tailorJobs = const [],
    this.conversations = const [],
    this.reviews = const [],
  });

  String get statusText {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.tailoring:
        return 'In Tailoring';
      case OrderStatus.ready:
        return 'Ready for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get statusColor {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.tailoring:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.delivered:
        return Colors.teal;
      case OrderStatus.cancelled:
        return Colors.red;
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

  Order copyWith({
    String? id,
    String? customerId,
    DateTime? orderDate,
    double? totalPrice,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    DateTime? paymentDeadline,
    DateTime? tailorSelectionDeadline,
    List<SubOrder>? subOrders,
    List<Payment>? payments,
    List<TailorJob>? tailorJobs,
    List<Conversation>? conversations,
    List<Review>? reviews,
  }) {
    return Order(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      orderDate: orderDate ?? this.orderDate,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentDeadline: paymentDeadline ?? this.paymentDeadline,
      tailorSelectionDeadline: tailorSelectionDeadline ?? this.tailorSelectionDeadline,
      subOrders: subOrders ?? this.subOrders,
      payments: payments ?? this.payments,
      tailorJobs: tailorJobs ?? this.tailorJobs,
      conversations: conversations ?? this.conversations,
      reviews: reviews ?? this.reviews,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'orderDate': orderDate.toIso8601String(),
    'totalPrice': totalPrice,
    'status': status.index,
    'paymentStatus': paymentStatus.index,
    'paymentDeadline': paymentDeadline?.toIso8601String(),
    'tailorSelectionDeadline': tailorSelectionDeadline?.toIso8601String(),
  };

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      orderDate: json['orderDate'] != null 
          ? DateTime.parse(json['orderDate']) 
          : DateTime.now(),
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      status: OrderStatus.values[json['status'] ?? 0],
      paymentStatus: PaymentStatus.values[json['paymentStatus'] ?? 0],
      paymentDeadline: json['paymentDeadline'] != null 
          ? DateTime.parse(json['paymentDeadline']) 
          : null,
      tailorSelectionDeadline: json['tailorSelectionDeadline'] != null 
          ? DateTime.parse(json['tailorSelectionDeadline']) 
          : null,
    );
  }
}
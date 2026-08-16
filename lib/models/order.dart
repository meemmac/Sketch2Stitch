import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'sub_order.dart';
import 'payment.dart';
import 'tailor_job.dart';
import 'conversation.dart';
import 'review.dart';

enum OrderStatus {
  awaitingConfirmation,
  processing,
  awaitingTailorSearch,
  tailorPending,
  completed,
  cancelled;

  String get toValue => const {
    OrderStatus.awaitingConfirmation: 'awaiting_confirmation',
    OrderStatus.processing: 'processing',
    OrderStatus.awaitingTailorSearch: 'awaiting_tailor_search',
    OrderStatus.tailorPending: 'tailor_pending',
    OrderStatus.completed: 'completed',
    OrderStatus.cancelled: 'cancelled',
  }[this]!;

  static OrderStatus fromValue(String v) => const {
    'awaiting_confirmation': OrderStatus.awaitingConfirmation,
    'processing': OrderStatus.processing,
    'awaiting_tailor_search': OrderStatus.awaitingTailorSearch,
    'tailor_pending': OrderStatus.tailorPending,
    'completed': OrderStatus.completed,
    'cancelled': OrderStatus.cancelled,
  }[v] ?? OrderStatus.awaitingConfirmation;
}

/// Used for Payments.status — separate from TailorJob's tailorPaymentStatus.
enum PaymentStatus {
  pending,
  completed,
  failed,
  refunded;

  String get toValue => name; // values already match Firestore strings

  static PaymentStatus fromValue(String v) =>
      PaymentStatus.values.byName(v);
}

class Order {
  final String id;
  final String customerId;
  final DateTime orderDate;
  final OrderStatus status;
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
    required this.status,
    this.tailorSelectionDeadline,
    this.subOrders = const [],
    this.payments = const [],
    this.tailorJobs = const [],
    this.conversations = const [],
    this.reviews = const [],
  });

  String get statusText {
    // 🧠 Derived Status Logic
    // If we have detailed lists, calculate the "final" status based on progress
    if (subOrders != null && subOrders!.isNotEmpty) {
      bool allDelivered = subOrders!.every((so) => so.status == SubOrderStatus.delivered);
      bool allPacked = subOrders!.every((so) => so.status == SubOrderStatus.packed || so.status == SubOrderStatus.delivered);
      
      bool hasTailor = tailorJobs != null && tailorJobs!.isNotEmpty;
      if (hasTailor) {
        final tj = tailorJobs!.first;
        if (tj.status == TailorJobStatus.confirmed) {
          if (orderDate.isAfter(tj.confirmedAt ?? DateTime(2000))) {
             // Basic confirmed
          } else {
            return "Tailor Confirmed — Stitching Started";
          }
        }
        if (tj.status == TailorJobStatus.quoted) return "Quote Received from Tailor";
        if (tj.status == TailorJobStatus.pending) return "Requested Master Tailor";
      }

      if (allDelivered) return "Delivered";
      if (allPacked) return "Order Packed";
      return "Preparing Order";
    }

    switch (status) {
      case OrderStatus.awaitingConfirmation:
        return 'Awaiting Confirmation';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.awaitingTailorSearch:
        return 'Awaiting Tailor Search';
      case OrderStatus.tailorPending:
        return 'Tailor Pending';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  int get itemCount => (subOrders?.length ?? 0) + (tailorJobs?.length ?? 0);

  double get totalAmount {
    double total = 0;
    subOrders?.forEach((so) {
      total += so.itemsSubtotal + so.deliveryCharge;
    });
    tailorJobs?.forEach((tj) {
      total += (tj.quoteAmount ?? 0) + (tj.deliveryCharge ?? 0);
    });
    return total;
  }

  Color get statusColor {
    switch (status) {
      case OrderStatus.awaitingConfirmation:
        return Colors.orange;
      case OrderStatus.processing:
        return Colors.blue;
      case OrderStatus.awaitingTailorSearch:
        return Colors.purple;
      case OrderStatus.tailorPending:
        return Colors.amber;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  Order copyWith({
    String? id,
    String? customerId,
    DateTime? orderDate,
    OrderStatus? status,
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
      status: status ?? this.status,
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
    'orderDate': Timestamp.fromDate(orderDate),
    'status': status.toValue,
    'tailorSelectionDeadline': tailorSelectionDeadline != null 
        ? Timestamp.fromDate(tailorSelectionDeadline!) 
        : null,
  };

  factory Order.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }


    // 🧠 Flexible field detection
    // Try to find the customer ID even if the user named it slightly differently
    final customerId = json['customerId'] ?? json['userId'] ?? json['uid'] ?? '';


    return Order(
      id: json['id'] ?? '',
      customerId: customerId,
      orderDate: parseDate(json['orderDate'] ?? json['date']),
      status: OrderStatus.fromValue(json['status'] ?? 'awaiting_confirmation'),
      tailorSelectionDeadline: json['tailorSelectionDeadline'] != null
          ? parseDate(json['tailorSelectionDeadline'])
          : null,
    );
  }
}
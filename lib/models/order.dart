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

  // In-memory only (not in Firestore document)
  String? tailorName;

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
    this.tailorName,
  });

  /// Job statuses that describe a job nobody is working any more. A dead
  /// job must not price the order, count towards its deliveries, or name
  /// the tailor — an order picks up a fresh job every time one is declined
  /// or a quote is turned down and the customer hires someone else.
  static const Set<TailorJobStatus> deadJobStatuses = {
    TailorJobStatus.rejected,
    TailorJobStatus.tailorDeclined,
    TailorJobStatus.expired,
    TailorJobStatus.cancelled,
  };

  /// The newest job on this order, dead or alive. Callers get it sorted
  /// newest-first by whichever OrderService stream loaded them.
  TailorJob? get latestTailorJob =>
      (tailorJobs == null || tailorJobs!.isEmpty) ? null : tailorJobs!.first;

  /// The newest job that is still live, or null if the order currently has
  /// no tailor working it.
  TailorJob? get activeTailorJob {
    final job = latestTailorJob;
    if (job == null || deadJobStatuses.contains(job.status)) return null;
    return job;
  }

  String get statusText {
    // 1. Check for Terminal Statuses First
    if (status == OrderStatus.completed) return 'Delivered';
    if (status == OrderStatus.cancelled) return 'Cancelled';

    // 2. A live tailor job is the most specific thing we can say.
    final tj = activeTailorJob;
    if (tj != null) {
      switch (tj.status) {
        case TailorJobStatus.jobCompleted:
          return "Stitching Completed";
        case TailorJobStatus.inProgress:
        case TailorJobStatus.confirmed:
          return "Tailor Confirmed — Stitching Started";
        case TailorJobStatus.quoted:
          return "Quote Received from Tailor";
        case TailorJobStatus.pending:
          return "Requested Tailor";
        default:
          break;
      }
    }

    // 3. Decisions the customer still owes. These have to be answered
    // BEFORE the sub-order derivation below: every order always has
    // sub-orders, so deriving first collapsed the entire front half of the
    // funnel — "choose tailor or skip" and "pick a tailor" alike — into a
    // single misleading "Preparing Order".
    if (status == OrderStatus.awaitingConfirmation) {
      return 'Awaiting Confirmation';
    }
    if (status == OrderStatus.awaitingTailorSearch) {
      return 'Awaiting Tailor Selection';
    }
    if (status == OrderStatus.tailorPending) {
      return 'Tailor Pending';
    }

    // 4. Derived progress for an order whose tailoring question is settled.
    if (subOrders != null && subOrders!.isNotEmpty) {
      bool allDelivered = subOrders!.every((so) => so.status == SubOrderStatus.delivered);
      bool allPacked = subOrders!.every((so) => so.status == SubOrderStatus.packed || so.status == SubOrderStatus.delivered);

      if (allDelivered) return "Items Delivered";
      if (allPacked) return "Order Packed";
      return "Preparing Order";
    }

    return 'Processing';
  }

  /// How many separate parties are delivering something. Only a LIVE tailor
  /// job counts — a declined one is not a delivery.
  int get itemCount =>
      (subOrders?.length ?? 0) + (activeTailorJob != null ? 1 : 0);

  double get totalAmount {
    double total = 0;
    subOrders?.forEach((so) {
      total += so.itemsSubtotal + so.deliveryCharge;
    });
    // Only the live job is billable. Summing every job charged a re-hired
    // order once per tailor it had ever asked.
    final tj = activeTailorJob;
    if (tj != null) {
      total += (tj.quoteAmount ?? 0) + (tj.deliveryCharge ?? 0);
    }
    return total;
  }

  /// Keyed off [statusText], not the raw status field — the two are derived
  /// differently, so switching on `status` here painted "Stitching
  /// Completed" with the blue `processing` dot.
  Color get statusColor {
    switch (statusText) {
      case 'Delivered':
      case 'Items Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      case 'Awaiting Confirmation':
        return Colors.orange;
      case 'Awaiting Tailor Selection':
        return Colors.purple;
      case 'Requested Tailor':
      case 'Tailor Pending':
        return Colors.amber;
      case 'Quote Received from Tailor':
        return Colors.deepOrange;
      case 'Tailor Confirmed — Stitching Started':
        return Colors.indigo;
      case 'Stitching Completed':
        return Colors.teal;
      case 'Order Packed':
        return Colors.teal.shade700;
      default:
        return Colors.blue;
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
    String? tailorName,
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
      tailorName: tailorName ?? this.tailorName,
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
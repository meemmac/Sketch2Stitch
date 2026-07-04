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

  Order({
    required this.id,
    required this.customerId,
    required this.orderDate,
    required this.totalPrice,
    required this.status,
    required this.paymentStatus,
    this.paymentDeadline,
    this.tailorSelectionDeadline,
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
}
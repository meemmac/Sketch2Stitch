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
  final PaymentStatus paymentStatus;
  final DateTime? paymentReleaseDeadline;
  final DateTime? autoReleaseAt;

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
}
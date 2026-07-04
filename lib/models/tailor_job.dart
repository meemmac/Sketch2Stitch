enum TailorJobStatus {
  pending,
  accepted,
  inProgress,
  completed,
  rejected,
  cancelled,
}

enum QuoteStatus {
  pending,
  quoted,
  approved,
  rejected,
}

class TailorJob {
  final String id;
  final String orderId;
  final String tailorId;
  final String measurementId;
  final List<String> designIds;
  final TailorJobStatus status;
  final DateTime? confirmedAt;
  final String? specialInstructions;
  final String? rejectionReason;
  final double? quoteAmount;
  final String? quoteNote;
  final QuoteStatus quoteStatus;
  final PaymentStatus tailorPaymentStatus;
  final DateTime? tailorSelectionDeadline;
  final DateTime? quoteResponseDeadline;
  final DateTime? quoteApprovalDeadline;
  final DateTime? paymentReleaseDeadline;
  final DateTime? autoReleaseAt;

  TailorJob({
    required this.id,
    required this.orderId,
    required this.tailorId,
    required this.measurementId,
    this.designIds = const [],
    required this.status,
    this.confirmedAt,
    this.specialInstructions,
    this.rejectionReason,
    this.quoteAmount,
    this.quoteNote,
    required this.quoteStatus,
    required this.tailorPaymentStatus,
    this.tailorSelectionDeadline,
    this.quoteResponseDeadline,
    this.quoteApprovalDeadline,
    this.paymentReleaseDeadline,
    this.autoReleaseAt,
  });

  String get statusText {
    switch (status) {
      case TailorJobStatus.pending:
        return 'Pending';
      case TailorJobStatus.accepted:
        return 'Accepted';
      case TailorJobStatus.inProgress:
        return 'In Progress';
      case TailorJobStatus.completed:
        return 'Completed';
      case TailorJobStatus.rejected:
        return 'Rejected';
      case TailorJobStatus.cancelled:
        return 'Cancelled';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'tailorId': tailorId,
    'measurementId': measurementId,
    'designIds': designIds,
    'status': status.index,
    'confirmedAt': confirmedAt?.toIso8601String(),
    'specialInstructions': specialInstructions,
    'rejectionReason': rejectionReason,
    'quoteAmount': quoteAmount,
    'quoteNote': quoteNote,
    'quoteStatus': quoteStatus.index,
    'tailorPaymentStatus': tailorPaymentStatus.index,
    'tailorSelectionDeadline': tailorSelectionDeadline?.toIso8601String(),
    'quoteResponseDeadline': quoteResponseDeadline?.toIso8601String(),
    'quoteApprovalDeadline': quoteApprovalDeadline?.toIso8601String(),
    'paymentReleaseDeadline': paymentReleaseDeadline?.toIso8601String(),
    'autoReleaseAt': autoReleaseAt?.toIso8601String(),
  };
}
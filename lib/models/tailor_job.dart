import 'order.dart';
import 'design.dart';
import 'measurement.dart';

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

  // Relationships (lazy loaded)
  List<Design>? designs;
  List<Measurement>? measurements;

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
    this.designs,
    this.measurements,
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

  String get quoteStatusText {
    switch (quoteStatus) {
      case QuoteStatus.pending:
        return 'Pending';
      case QuoteStatus.quoted:
        return 'Quoted';
      case QuoteStatus.approved:
        return 'Approved';
      case QuoteStatus.rejected:
        return 'Rejected';
    }
  }

  String get paymentStatusText {
    switch (tailorPaymentStatus) {
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

  TailorJob copyWith({
    String? id,
    String? orderId,
    String? tailorId,
    String? measurementId,
    List<String>? designIds,
    TailorJobStatus? status,
    DateTime? confirmedAt,
    String? specialInstructions,
    String? rejectionReason,
    double? quoteAmount,
    String? quoteNote,
    QuoteStatus? quoteStatus,
    PaymentStatus? tailorPaymentStatus,
    DateTime? tailorSelectionDeadline,
    DateTime? quoteResponseDeadline,
    DateTime? quoteApprovalDeadline,
    DateTime? paymentReleaseDeadline,
    DateTime? autoReleaseAt,
    List<Design>? designs,
    List<Measurement>? measurements,
  }) {
    return TailorJob(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      tailorId: tailorId ?? this.tailorId,
      measurementId: measurementId ?? this.measurementId,
      designIds: designIds ?? this.designIds,
      status: status ?? this.status,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      quoteAmount: quoteAmount ?? this.quoteAmount,
      quoteNote: quoteNote ?? this.quoteNote,
      quoteStatus: quoteStatus ?? this.quoteStatus,
      tailorPaymentStatus: tailorPaymentStatus ?? this.tailorPaymentStatus,
      tailorSelectionDeadline: tailorSelectionDeadline ?? this.tailorSelectionDeadline,
      quoteResponseDeadline: quoteResponseDeadline ?? this.quoteResponseDeadline,
      quoteApprovalDeadline: quoteApprovalDeadline ?? this.quoteApprovalDeadline,
      paymentReleaseDeadline: paymentReleaseDeadline ?? this.paymentReleaseDeadline,
      autoReleaseAt: autoReleaseAt ?? this.autoReleaseAt,
      designs: designs ?? this.designs,
      measurements: measurements ?? this.measurements,
    );
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

  factory TailorJob.fromJson(Map<String, dynamic> json) {
    return TailorJob(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      tailorId: json['tailorId'] ?? '',
      measurementId: json['measurementId'] ?? '',
      designIds: List<String>.from(json['designIds'] ?? []),
      status: TailorJobStatus.values[json['status'] ?? 0],
      confirmedAt: json['confirmedAt'] != null 
          ? DateTime.parse(json['confirmedAt']) 
          : null,
      specialInstructions: json['specialInstructions'],
      rejectionReason: json['rejectionReason'],
      quoteAmount: json['quoteAmount']?.toDouble(),
      quoteNote: json['quoteNote'],
      quoteStatus: QuoteStatus.values[json['quoteStatus'] ?? 0],
      tailorPaymentStatus: PaymentStatus.values[json['tailorPaymentStatus'] ?? 0],
      tailorSelectionDeadline: json['tailorSelectionDeadline'] != null 
          ? DateTime.parse(json['tailorSelectionDeadline']) 
          : null,
      quoteResponseDeadline: json['quoteResponseDeadline'] != null 
          ? DateTime.parse(json['quoteResponseDeadline']) 
          : null,
      quoteApprovalDeadline: json['quoteApprovalDeadline'] != null 
          ? DateTime.parse(json['quoteApprovalDeadline']) 
          : null,
      paymentReleaseDeadline: json['paymentReleaseDeadline'] != null 
          ? DateTime.parse(json['paymentReleaseDeadline']) 
          : null,
      autoReleaseAt: json['autoReleaseAt'] != null 
          ? DateTime.parse(json['autoReleaseAt']) 
          : null,
    );
  }
}
import 'design.dart';
import 'measurement.dart';

enum TailorJobStatus {
  pending,
  rejected,
  quoted,
  confirmed,
  expired,
  cancelled;

  String get toValue => name; // all match Firestore strings directly

  static TailorJobStatus fromValue(String v) =>
      TailorJobStatus.values.byName(v);
}

enum QuoteStatus {
  notSent,
  sent,
  accepted,
  expired;

  String get toValue => const {
    QuoteStatus.notSent: 'not_sent',
    QuoteStatus.sent: 'sent',
    QuoteStatus.accepted: 'accepted',
    QuoteStatus.expired: 'expired',
  }[this]!;

  static QuoteStatus fromValue(String v) => const {
    'not_sent': QuoteStatus.notSent,
    'sent': QuoteStatus.sent,
    'accepted': QuoteStatus.accepted,
    'expired': QuoteStatus.expired,
  }[v] ?? QuoteStatus.notSent;
}

/// Separate from Payments.status — only "unpaid" / "paid" apply to tailor jobs.
enum TailorPaymentStatus {
  unpaid,
  paid;

  String get toValue => name; // already match Firestore strings

  static TailorPaymentStatus fromValue(String v) =>
      TailorPaymentStatus.values.byName(v);
}

class TailorJob {
  final String id;
  final String orderId;
  final String tailorId;
  final String measurementId;
  final List<String> designIds;
  final TailorJobStatus status;
  final DateTime? confirmedAt;
  final DateTime? estimatedDeliveryDate;
  final String? specialInstructions;
  final String? rejectionReason;
  final double? quoteAmount;
  final String? quoteNote;
  final QuoteStatus quoteStatus;
  final TailorPaymentStatus tailorPaymentStatus;
  final DateTime? quoteResponseDeadline;
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
    this.estimatedDeliveryDate,
    this.specialInstructions,
    this.rejectionReason,
    this.quoteAmount,
    this.quoteNote,
    required this.quoteStatus,
    required this.tailorPaymentStatus,
    this.quoteResponseDeadline,
    this.autoReleaseAt,
    this.designs,
    this.measurements,
  });

  String get statusText {
    switch (status) {
      case TailorJobStatus.pending:
        return 'Pending';
      case TailorJobStatus.rejected:
        return 'Rejected';
      case TailorJobStatus.quoted:
        return 'Quoted';
      case TailorJobStatus.confirmed:
        return 'Confirmed';
      case TailorJobStatus.expired:
        return 'Expired';
      case TailorJobStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get quoteStatusText {
    switch (quoteStatus) {
      case QuoteStatus.notSent:
        return 'Not Sent';
      case QuoteStatus.sent:
        return 'Sent';
      case QuoteStatus.accepted:
        return 'Accepted';
      case QuoteStatus.expired:
        return 'Expired';
    }
  }

  String get tailorPaymentStatusText {
    switch (tailorPaymentStatus) {
      case TailorPaymentStatus.unpaid:
        return 'Unpaid';
      case TailorPaymentStatus.paid:
        return 'Paid';
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
    DateTime? estimatedDeliveryDate,
    String? specialInstructions,
    String? rejectionReason,
    double? quoteAmount,
    String? quoteNote,
    QuoteStatus? quoteStatus,
    TailorPaymentStatus? tailorPaymentStatus,
    DateTime? quoteResponseDeadline,
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
      estimatedDeliveryDate: estimatedDeliveryDate ?? this.estimatedDeliveryDate,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      quoteAmount: quoteAmount ?? this.quoteAmount,
      quoteNote: quoteNote ?? this.quoteNote,
      quoteStatus: quoteStatus ?? this.quoteStatus,
      tailorPaymentStatus: tailorPaymentStatus ?? this.tailorPaymentStatus,
      quoteResponseDeadline: quoteResponseDeadline ?? this.quoteResponseDeadline,
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
    'status': status.toValue,
    'confirmedAt': confirmedAt?.toIso8601String(),
    'estimatedDeliveryDate': estimatedDeliveryDate?.toIso8601String(),
    'specialInstructions': specialInstructions,
    'rejectionReason': rejectionReason,
    'quoteAmount': quoteAmount,
    'quoteNote': quoteNote,
    'quoteStatus': quoteStatus.toValue,
    'tailorPaymentStatus': tailorPaymentStatus.toValue,
    'quoteResponseDeadline': quoteResponseDeadline?.toIso8601String(),
    'autoReleaseAt': autoReleaseAt?.toIso8601String(),
  };

  factory TailorJob.fromJson(Map<String, dynamic> json) {
    return TailorJob(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      tailorId: json['tailorId'] ?? '',
      measurementId: json['measurementId'] ?? '',
      designIds: List<String>.from(json['designIds'] ?? []),
      status: TailorJobStatus.fromValue(json['status'] ?? 'pending'),
      confirmedAt: json['confirmedAt'] != null
          ? DateTime.parse(json['confirmedAt'])
          : null,
      estimatedDeliveryDate: json['estimatedDeliveryDate'] != null
          ? DateTime.parse(json['estimatedDeliveryDate'])
          : null,
      specialInstructions: json['specialInstructions'],
      rejectionReason: json['rejectionReason'],
      quoteAmount: json['quoteAmount']?.toDouble(),
      quoteNote: json['quoteNote'],
      quoteStatus: QuoteStatus.fromValue(json['quoteStatus'] ?? 'not_sent'),
      tailorPaymentStatus: TailorPaymentStatus.fromValue(
        json['tailorPaymentStatus'] ?? 'unpaid',
      ),
      quoteResponseDeadline: json['quoteResponseDeadline'] != null
          ? DateTime.parse(json['quoteResponseDeadline'])
          : null,
      autoReleaseAt: json['autoReleaseAt'] != null
          ? DateTime.parse(json['autoReleaseAt'])
          : null,
    );
  }
}
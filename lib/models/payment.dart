import 'order.dart';  // Import PaymentStatus from order.dart

enum PaymentMethod {
  bKash,
  nagad,
  rocket,
  creditCard,
  bankTransfer,
}

enum PaymentTargetType {
  order,
  subOrder,
  tailorJob,
}

class Payment {
  final String id;
  final String orderId;
  final PaymentMethod method;
  final double amount;
  final PaymentStatus status;  // Uses PaymentStatus from order.dart
  final DateTime date;
  final String? transactionId;
  final PaymentTargetType targetType;
  final String targetId;

  Payment({
    required this.id,
    required this.orderId,
    required this.method,
    required this.amount,
    required this.status,
    required this.date,
    this.transactionId,
    required this.targetType,
    required this.targetId,
  });

  String get methodText {
    switch (method) {
      case PaymentMethod.bKash:
        return 'bKash';
      case PaymentMethod.nagad:
        return 'Nagad';
      case PaymentMethod.rocket:
        return 'Rocket';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }

  String get statusText {
    switch (status) {
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

  String get targetTypeText {
    switch (targetType) {
      case PaymentTargetType.order:
        return 'Order';
      case PaymentTargetType.subOrder:
        return 'Sub Order';
      case PaymentTargetType.tailorJob:
        return 'Tailor Job';
    }
  }

  Payment copyWith({
    String? id,
    String? orderId,
    PaymentMethod? method,
    double? amount,
    PaymentStatus? status,
    DateTime? date,
    String? transactionId,
    PaymentTargetType? targetType,
    String? targetId,
  }) {
    return Payment(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      method: method ?? this.method,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      date: date ?? this.date,
      transactionId: transactionId ?? this.transactionId,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'method': method.index,
    'amount': amount,
    'status': status.index,
    'date': date.toIso8601String(),
    'transactionId': transactionId,
    'targetType': targetType.index,
    'targetId': targetId,
  };

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      method: PaymentMethod.values[json['method'] ?? 0],
      amount: (json['amount'] ?? 0).toDouble(),
      status: PaymentStatus.values[json['status'] ?? 0],
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      transactionId: json['transactionId'],
      targetType: PaymentTargetType.values[json['targetType'] ?? 0],
      targetId: json['targetId'] ?? '',
    );
  }
}
import 'order.dart'; // For PaymentStatus

enum PaymentMethod {
  card,
  mobileBanking,
  cashOnDelivery;

  String get toValue => const {
    PaymentMethod.card: 'card',
    PaymentMethod.mobileBanking: 'mobile_banking',
    PaymentMethod.cashOnDelivery: 'cash_on_delivery',
  }[this]!;

  static PaymentMethod fromValue(String v) => const {
    'card': PaymentMethod.card,
    'mobile_banking': PaymentMethod.mobileBanking,
    'cash_on_delivery': PaymentMethod.cashOnDelivery,
  }[v] ?? PaymentMethod.card;
}

enum PaymentTargetType {
  retailer,
  tailor;

  String get toValue => name; // already match Firestore strings

  static PaymentTargetType fromValue(String v) =>
      PaymentTargetType.values.byName(v);
}

class Payment {
  final String id;
  final String orderId;
  final PaymentMethod method;
  final double amount;
  final PaymentStatus status; // Uses PaymentStatus from order.dart
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
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.mobileBanking:
        return 'Mobile Banking';
      case PaymentMethod.cashOnDelivery:
        return 'Cash on Delivery';
    }
  }

  String get statusText {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  String get targetTypeText {
    switch (targetType) {
      case PaymentTargetType.retailer:
        return 'Retailer';
      case PaymentTargetType.tailor:
        return 'Tailor';
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
    'method': method.toValue,
    'amount': amount,
    'status': status.toValue,
    'date': date.toIso8601String(),
    'transactionId': transactionId,
    'targetType': targetType.toValue,
    'targetId': targetId,
  };

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      method: PaymentMethod.fromValue(json['method'] ?? 'card'),
      amount: (json['amount'] ?? 0).toDouble(),
      status: PaymentStatus.fromValue(json['status'] ?? 'pending'),
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : DateTime.now(),
      transactionId: json['transactionId'],
      targetType: PaymentTargetType.fromValue(json['targetType'] ?? 'retailer'),
      targetId: json['targetId'] ?? '',
    );
  }
}
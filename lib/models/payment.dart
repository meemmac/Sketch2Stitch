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
  final PaymentStatus status;
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
}
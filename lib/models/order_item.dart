class OrderItem {
  final String id;
  final String subOrderId;
  final String productId;
  final int optionId; // matches Firestore "number" type
  final int quantity;

  OrderItem({
    required this.id,
    required this.subOrderId,
    required this.productId,
    required this.optionId,
    required this.quantity,
  });

  OrderItem copyWith({
    String? id,
    String? subOrderId,
    String? productId,
    int? optionId,
    int? quantity,
  }) {
    return OrderItem(
      id: id ?? this.id,
      subOrderId: subOrderId ?? this.subOrderId,
      productId: productId ?? this.productId,
      optionId: optionId ?? this.optionId,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subOrderId': subOrderId,
    'productId': productId,
    'optionId': optionId,
    'quantity': quantity,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? '',
      subOrderId: json['subOrderId'] ?? '',
      productId: json['productId'] ?? '',
      optionId: (json['optionId'] ?? 0) as int,
      quantity: (json['quantity'] ?? 1) as int,
    );
  }
}
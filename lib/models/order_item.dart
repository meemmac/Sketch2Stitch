class OrderItem {
  final String id;
  final String subOrderId;
  final String productId;
  final int optionId; // matches Firestore "number" type
  final int quantity;
  final String? instruction;

  OrderItem({
    required this.id,
    required this.subOrderId,
    required this.productId,
    required this.optionId,
    required this.quantity,
    this.instruction,
  });

  OrderItem copyWith({
    String? id,
    String? subOrderId,
    String? productId,
    int? optionId,
    int? quantity,
    String? instruction,
  }) {
    return OrderItem(
      id: id ?? this.id,
      subOrderId: subOrderId ?? this.subOrderId,
      productId: productId ?? this.productId,
      optionId: optionId ?? this.optionId,
      quantity: quantity ?? this.quantity,
      instruction: instruction ?? this.instruction,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subOrderId': subOrderId,
    'productId': productId,
    'optionId': optionId,
    'quantity': quantity,
    'instruction': instruction,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? '',
      subOrderId: json['subOrderId'] ?? '',
      productId: json['productId'] ?? '',
      optionId: (json['optionId'] ?? 0) as int,
      quantity: (json['quantity'] ?? 1) as int,
      instruction: json['instruction'],
    );
  }
}
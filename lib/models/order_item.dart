class OrderItem {
  final String id;
  final String subOrderId;
  final String productId;
  final String optionId;
  final int quantity;
  final double price;
  final String? instruction;

  OrderItem({
    required this.id,
    required this.subOrderId,
    required this.productId,
    required this.optionId,
    required this.quantity,
    required this.price,
    this.instruction,
  });

  double get totalPrice => price * quantity;

  OrderItem copyWith({
    String? id,
    String? subOrderId,
    String? productId,
    String? optionId,
    int? quantity,
    double? price,
    String? instruction,
  }) {
    return OrderItem(
      id: id ?? this.id,
      subOrderId: subOrderId ?? this.subOrderId,
      productId: productId ?? this.productId,
      optionId: optionId ?? this.optionId,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      instruction: instruction ?? this.instruction,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subOrderId': subOrderId,
    'productId': productId,
    'optionId': optionId,
    'quantity': quantity,
    'price': price,
    'instruction': instruction,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? '',
      subOrderId: json['subOrderId'] ?? '',
      productId: json['productId'] ?? '',
      optionId: json['optionId'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0).toDouble(),
      instruction: json['instruction'],
    );
  }
}
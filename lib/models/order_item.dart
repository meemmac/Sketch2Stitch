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

  Map<String, dynamic> toJson() => {
    'id': id,
    'subOrderId': subOrderId,
    'productId': productId,
    'optionId': optionId,
    'quantity': quantity,
    'price': price,
    'instruction': instruction,
  };
}
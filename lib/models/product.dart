import 'order_item.dart';

class Product {
  final String id;
  final String retailerId;
  final String productName;
  final String category;
  final String materialType;
  final List<String> colorOptions;
  final String description;
  final List<String> careLevel;
  
  // Relationships
  List<OrderItem>? orderItems;

  Product({
    required this.id,
    required this.retailerId,
    required this.productName,
    required this.category,
    required this.materialType,
    required this.colorOptions,
    required this.description,
    required this.careLevel,
    this.orderItems = const [],
  });

  Product copyWith({
    String? id,
    String? retailerId,
    String? productName,
    String? category,
    String? materialType,
    List<String>? colorOptions,
    String? description,
    List<String>? careLevel,
    List<OrderItem>? orderItems,
  }) {
    return Product(
      id: id ?? this.id,
      retailerId: retailerId ?? this.retailerId,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      materialType: materialType ?? this.materialType,
      colorOptions: colorOptions ?? this.colorOptions,
      description: description ?? this.description,
      careLevel: careLevel ?? this.careLevel,
      orderItems: orderItems ?? this.orderItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'retailerId': retailerId,
    'productName': productName,
    'category': category,
    'materialType': materialType,
    'colorOptions': colorOptions,
    'description': description,
    'careLevel': careLevel,
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      retailerId: json['retailerId'] ?? '',
      productName: json['productName'] ?? '',
      category: json['category'] ?? '',
      materialType: json['materialType'] ?? '',
      colorOptions: List<String>.from(json['colorOptions'] ?? []),
      description: json['description'] ?? '',
      careLevel: List<String>.from(json['careLevel'] ?? []),
    );
  }
}

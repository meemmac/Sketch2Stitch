// lib/models/product.dart
import 'order_item.dart';

/// Represents a color option for a product
class ColorOption {
  final int optionId;
  final String color;
  final String? image;
  final double price;
  final int stock;

  ColorOption({
    required this.optionId,
    required this.color,
    this.image,
    required this.price,
    this.stock = 0,
  });

  ColorOption copyWith({
    int? optionId,
    String? color,
    String? image,
    double? price,
    int? stock,
  }) {
    return ColorOption(
      optionId: optionId ?? this.optionId,
      color: color ?? this.color,
      image: image ?? this.image,
      price: price ?? this.price,
      stock: stock ?? this.stock,
    );
  }

  Map<String, dynamic> toJson() => {
    'optionId': optionId,
    'color': color,
    if (image != null) 'image': image,
    'price': price,
    'stock': stock,
  };

  factory ColorOption.fromJson(Map<String, dynamic> json) {
    return ColorOption(
      optionId: json['optionId'] ?? 0,
      color: json['color'] ?? '',
      image: json['image'],
      price: (json['price'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
    );
  }
}

class Product {
  final String id;
  final String retailerId;
  final String productName;
  final String category;
  final String materialType;
  final List<ColorOption> colorOptions; // Changed from List<String> to List<ColorOption>
  final String description;
  final List<String> careSymbol;
  
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
    required this.careSymbol,
    this.orderItems = const [],
  });

  /// Get all available colors as strings (for backward compatibility)
  List<String> get colorNames => colorOptions.map((c) => c.color).toList();
  
  /// Get the minimum price across all color options
  double get minPrice {
    if (colorOptions.isEmpty) return 0.0;
    return colorOptions.map((c) => c.price).reduce((a, b) => a < b ? a : b);
  }
  
  /// Get the maximum price across all color options
  double get maxPrice {
    if (colorOptions.isEmpty) return 0.0;
    return colorOptions.map((c) => c.price).reduce((a, b) => a > b ? a : b);
  }
  
  /// Get price range as string (e.g., "Tk 650 - 700")
  String get priceRange {
    if (colorOptions.isEmpty) return 'Tk 0';
    if (minPrice == maxPrice) return 'Tk ${minPrice.toStringAsFixed(0)}';
    return 'Tk ${minPrice.toStringAsFixed(0)} - ${maxPrice.toStringAsFixed(0)}';
  }

  Product copyWith({
    String? id,
    String? retailerId,
    String? productName,
    String? category,
    String? materialType,
    List<ColorOption>? colorOptions,
    String? description,
    List<String>? careSymbol,
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
      careSymbol: careSymbol ?? this.careSymbol,
      orderItems: orderItems ?? this.orderItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'retailerId': retailerId,
    'productName': productName,
    'category': category,
    'materialType': materialType,
    'colorOptions': colorOptions.map((c) => c.toJson()).toList(),
    'description': description,
    'careSymbol': careSymbol,
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    // Parse colorOptions - could be List<Map> (new format) or List<String> (old format)
    List<ColorOption> colorOptionsList = [];
    
    final rawColorOptions = json['colorOptions'];
    if (rawColorOptions != null && rawColorOptions is List) {
      colorOptionsList = rawColorOptions.map((item) {
        if (item is Map<String, dynamic>) {
          // New format: ColorOption object
          return ColorOption.fromJson(item);
        } else if (item is String) {
          // Old format: just color names (fallback)
          return ColorOption(
            optionId: colorOptionsList.length + 1,
            color: item,
            price: 0.0,
            stock: 0,
          );
        }
        return ColorOption(
          optionId: 0,
          color: item.toString(),
          price: 0.0,
          stock: 0,
        );
      }).toList();
    }

    return Product(
      id: json['id'] ?? '',
      retailerId: json['retailerId'] ?? '',
      productName: json['productName'] ?? '',
      category: json['category'] ?? '',
      materialType: json['materialType'] ?? '',
      colorOptions: colorOptionsList,
      description: json['description'] ?? '',
      careSymbol: List<String>.from(json['careSymbol'] ?? []),
    );
  }
}
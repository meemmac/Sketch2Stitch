// lib/models/product.dart
import 'order_item.dart';

/// Represents a color option for a product
class ColorOption {
  final int optionId;
  final String color;
  final List<String> images; // Changed from String? image to List<String>
  final List<String> videos; // Changed from String? video to List<String>
  final double price;
  final int stock;

  ColorOption({
    required this.optionId,
    required this.color,
    required this.images,
    required this.videos,
    required this.price,
    this.stock = 0,
  });

  ColorOption copyWith({
    int? optionId,
    String? color,
    List<String>? images,
    List<String>? videos,
    double? price,
    int? stock,
  }) {
    return ColorOption(
      optionId: optionId ?? this.optionId,
      color: color ?? this.color,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      price: price ?? this.price,
      stock: stock ?? this.stock,
    );
  }

  Map<String, dynamic> toJson() => {
    'optionId': optionId,
    'color': color,
    'images': images,
    'videos': videos,
    'price': price,
    'stock': stock,
  };

  factory ColorOption.fromJson(Map<String, dynamic> json) {
    // Handle migration from single image/video if necessary, or just use lists
    List<String> imageList = [];
    if (json['images'] is List) {
      imageList = List<String>.from(json['images']);
    } else if (json['image'] != null) {
      imageList = [json['image'].toString()];
    }

    List<String> videoList = [];
    if (json['videos'] is List) {
      videoList = List<String>.from(json['videos']);
    } else if (json['video'] != null) {
      videoList = [json['video'].toString()];
    }

    return ColorOption(
      optionId: json['optionId'] ?? 0,
      color: json['color'] ?? '',
      images: imageList,
      videos: videoList,
      price: (json['price'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
    );
  }
}

/// Represents a material component of a fabric
class MaterialBlend {
  final String type;
  final double blend;

  MaterialBlend({required this.type, required this.blend});

  Map<String, dynamic> toJson() => {
    'type': type,
    'blend': blend,
  };

  factory MaterialBlend.fromJson(Map<String, dynamic> json) {
    return MaterialBlend(
      type: json['type'] ?? '',
      blend: (json['blend'] ?? 0).toDouble(),
    );
  }
}

class Product {
  final String id;
  final String retailerId;
  final String productName;
  final String category;
  final String productCode;
  final List<MaterialBlend> materialType;
  final List<ColorOption> colorOptions;
  final String description;
  final List<String> careSymbol;
  
  // Relationships
  List<OrderItem>? orderItems;

  Product({
    required this.id,
    required this.retailerId,
    required this.productName,
    required this.category,
    required this.productCode,
    required this.materialType,
    required this.colorOptions,
    required this.description,
    required this.careSymbol,
    this.orderItems = const [],
  });

  /// Get all available colors as strings
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
  
  /// Get price range as string
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
    String? productCode,
    List<MaterialBlend>? materialType,
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
      productCode: productCode ?? this.productCode,
      materialType: materialType ?? this.materialType,
      colorOptions: colorOptions ?? this.colorOptions,
      description: description ?? this.description,
      careSymbol: careSymbol ?? this.careSymbol,
      orderItems: orderItems ?? this.orderItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'productName': productName,
    'retailerId': retailerId,
    'category': category,
    'productCode': productCode,
    'materialType': materialType.map((m) => m.toJson()).toList(),
    'colorOptions': colorOptions.map((c) => c.toJson()).toList(),
    'description': description,
    'careSymbol': careSymbol,
  };

  factory Product.fromJson(Map<String, dynamic> json, {String? id}) {
    // Parse colorOptions
    List<ColorOption> colorOptionsList = [];
    final rawColorOptions = json['colorOptions'];
    if (rawColorOptions != null && rawColorOptions is List) {
      colorOptionsList = rawColorOptions.map((item) {
        if (item is Map<String, dynamic>) {
          return ColorOption.fromJson(item);
        }
        return ColorOption(
          optionId: 0,
          color: item.toString(),
          images: [],
          videos: [],
          price: 0.0,
          stock: 0,
        );
      }).toList();
    }

    // Parse materialType
    List<MaterialBlend> materialTypeItems = [];
    final rawMaterialType = json['materialType'];
    if (rawMaterialType != null && rawMaterialType is List) {
      materialTypeItems = rawMaterialType
          .map((item) => MaterialBlend.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return Product(
      id: id ?? json['id'] ?? '',
      retailerId: json['retailerId'] ?? '',
      productName: json['productName'] ?? '',
      category: json['category'] ?? '',
      productCode: json['productCode'] ?? '',
      materialType: materialTypeItems,
      colorOptions: colorOptionsList,
      description: json['description'] ?? '',
      careSymbol: List<String>.from(json['careSymbol'] ?? []),
    );
  }
}

// lib/models/product.dart
import 'order_item.dart';

/// Represents a color option for a product
class ColorOption {
  final int optionId;
  final String color;
  final String? image;
  final String? video;
  final double price;
  final int stock;

  ColorOption({
    required this.optionId,
    required this.color,
    this.image,
    this.video,
    required this.price,
    this.stock = 0,
  });

  ColorOption copyWith({
    int? optionId,
    String? color,
    String? image,
    String? video,
    double? price,
    int? stock,
  }) {
    return ColorOption(
      optionId: optionId ?? this.optionId,
      color: color ?? this.color,
      image: image ?? this.image,
      video: video ?? this.video,
      price: price ?? this.price,
      stock: stock ?? this.stock,
    );
  }

  Map<String, dynamic> toJson() => {
    'optionId': optionId,
    'color': color,
    if (image != null) 'image': image,
    if (video != null && video!.isNotEmpty) 'video': video,
    'price': price,
    'stock': stock,
  };

  factory ColorOption.fromJson(Map<String, dynamic> json) {
    return ColorOption(
      optionId: json['optionId'] ?? 0,
      color: json['color'] ?? '',
      image: json['image'],
      video: json['video'],
      price: (json['price'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
    );
  }
}

/// Represents a material type with blend percentage
class MaterialType {
  final String type;
  final double? blend;

  MaterialType({
    required this.type,
    this.blend,
  });

  String get displayText {
    if (blend != null && blend! > 0) {
      return '${blend!.toInt()}% $type';
    }
    return type;
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (blend != null) 'blend': blend,
  };

  factory MaterialType.fromJson(Map<String, dynamic> json) {
    return MaterialType(
      type: json['type'] ?? '',
      blend: json['blend']?.toDouble(),
    );
  }
}

class Product {
  final String id;
  final String retailerId;
  final String productName;
  final String? productCode; // Added productCode
  final String category;
  final List<MaterialType> materialTypes; // Array of material types
  final List<ColorOption> colorOptions;
  final String description;
  final List<String> careSymbol;
  
  // Relationships
  List<OrderItem>? orderItems;

  Product({
    required this.id,
    required this.retailerId,
    required this.productName,
    this.productCode,
    required this.category,
    required this.materialTypes,
    required this.colorOptions,
    required this.description,
    required this.careSymbol,
    this.orderItems = const [],
  });

  /// Get material type as string for display
  String get materialType {
    if (materialTypes.isEmpty) return 'N/A';
    return materialTypes.map((m) => m.displayText).join(', ');
  }

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
    String? productCode,
    String? category,
    List<MaterialType>? materialTypes,
    List<ColorOption>? colorOptions,
    String? description,
    List<String>? careSymbol,
    List<OrderItem>? orderItems,
  }) {
    return Product(
      id: id ?? this.id,
      retailerId: retailerId ?? this.retailerId,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      category: category ?? this.category,
      materialTypes: materialTypes ?? this.materialTypes,
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
    if (productCode != null) 'productCode': productCode,
    'category': category,
    'materialTypes': materialTypes.map((m) => m.toJson()).toList(),
    'colorOptions': colorOptions.map((c) => c.toJson()).toList(),
    'description': description,
    'careSymbol': careSymbol,
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    print('📦 Parsing product: ${json['productName'] ?? json['id']}');
    
    // Parse colorOptions
    List<ColorOption> colorOptionsList = [];
    final rawColorOptions = json['colorOptions'];
    if (rawColorOptions != null && rawColorOptions is List) {
      colorOptionsList = rawColorOptions.map((item) {
        if (item is Map<String, dynamic>) {
          return ColorOption.fromJson(item);
        } else if (item is String) {
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

    // Parse materialTypes - handles BOTH array and string formats
    List<MaterialType> materialTypes = [];
    
    // Check for materialType (array format from your schema)
    final rawMaterialType = json['materialType'];
    if (rawMaterialType != null && rawMaterialType is List) {
      print('📦 Found materialType array with ${rawMaterialType.length} items');
      materialTypes = rawMaterialType.map((item) {
        if (item is Map<String, dynamic>) {
          return MaterialType.fromJson(item);
        } else if (item is String) {
          return MaterialType(type: item);
        }
        return MaterialType(type: item.toString());
      }).toList();
    } 
    // Check for materialTypes (plural array format)
    else {
      final rawMaterialTypes = json['materialTypes'];
      if (rawMaterialTypes != null && rawMaterialTypes is List) {
        print('📦 Found materialTypes array with ${rawMaterialTypes.length} items');
        materialTypes = rawMaterialTypes.map((item) {
          if (item is Map<String, dynamic>) {
            return MaterialType.fromJson(item);
          } else if (item is String) {
            return MaterialType(type: item);
          }
          return MaterialType(type: item.toString());
        }).toList();
      }
      // Fallback for old string format
      else if (rawMaterialType != null && rawMaterialType is String) {
        print('📦 Found materialType string: $rawMaterialType');
        final parts = rawMaterialType.split(',').map((s) => s.trim()).toList();
        for (final part in parts) {
          if (part.contains('%')) {
            final match = RegExp(r'(\d+)%\s*(.+)').firstMatch(part);
            if (match != null) {
              materialTypes.add(MaterialType(
                type: match.group(2)?.trim() ?? part,
                blend: double.tryParse(match.group(1) ?? '0'),
              ));
            } else {
              materialTypes.add(MaterialType(type: part));
            }
          } else {
            materialTypes.add(MaterialType(type: part));
          }
        }
      }
    }

    // Parse careSymbol from Firestore array safely
    List<String> careSymbols = [];
    final rawCareSymbol = json['careSymbol'];
    
    if (rawCareSymbol != null) {
      if (rawCareSymbol is List) {
        for (var item in rawCareSymbol) {
          if (item != null) {
            careSymbols.add(item.toString());
          }
        }
      } else if (rawCareSymbol is String) {
        careSymbols = [rawCareSymbol];
      }
    }

    print('✅ Product parsed: ${json['productName']}, materialTypes: ${materialTypes.length}');
    
    return Product(
      id: json['id'] ?? '',
      retailerId: json['retailerId'] ?? '',
      productName: json['productName'] ?? '',
      productCode: json['productCode'],
      category: json['category'] ?? '',
      materialTypes: materialTypes,
      colorOptions: colorOptionsList,
      description: json['description'] ?? '',
      careSymbol: careSymbols,
    );
  }
}
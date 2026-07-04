class Product {
  final String id;
  final String retailerId;
  final String productName;
  final String category;
  final String materialType;
  final List<String> colorOptions;
  final String description;
  final double price;
  final double rating;
  final int reviewCount;
  final String? imageUrl;
  final int stock;

  Product({
    required this.id,
    required this.retailerId,
    required this.productName,
    required this.category,
    required this.materialType,
    required this.colorOptions,
    required this.description,
    required this.price,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.imageUrl,
    this.stock = 10,
  });

  Product copyWith({
    String? id,
    String? retailerId,
    String? productName,
    String? category,
    String? materialType,
    List<String>? colorOptions,
    String? description,
    double? price,
    double? rating,
    int? reviewCount,
    String? imageUrl,
    int? stock,
  }) {
    return Product(
      id: id ?? this.id,
      retailerId: retailerId ?? this.retailerId,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      materialType: materialType ?? this.materialType,
      colorOptions: colorOptions ?? this.colorOptions,
      description: description ?? this.description,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      imageUrl: imageUrl ?? this.imageUrl,
      stock: stock ?? this.stock,
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
    'price': price,
    'rating': rating,
    'reviewCount': reviewCount,
    'imageUrl': imageUrl,
    'stock': stock,
  };
}
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
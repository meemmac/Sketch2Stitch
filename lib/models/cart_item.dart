// lib/models/cart_item.dart

// ─── Cart Models ────────────────────────────────────────────────────────
//
// CartItem is the raw `Cart-Items` document: exactly what is persisted
// (customerId, productId, optionId, quantity). It deliberately mirrors the
// `Order-Items` shape so checkout can hand the same tuples straight to
// CheckoutService.createOrderItems.
//
// CartLine is the *hydrated* view of a cart item: the raw document joined
// with `Products` (name / colorOptions / retailerId) and `Retailer`
// (shopName), so the cart screen can render a row without re-fetching.

/// A single persisted `Cart-Items` document.
class CartItem {
  final String id;
  final String customerId;
  final String productId;
  final int optionId;
  final int quantity;
  final DateTime? addedAt;

  const CartItem({
    required this.id,
    required this.customerId,
    required this.productId,
    required this.optionId,
    required this.quantity,
    this.addedAt,
  });

  CartItem copyWith({
    String? id,
    String? customerId,
    String? productId,
    int? optionId,
    int? quantity,
    DateTime? addedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      productId: productId ?? this.productId,
      optionId: optionId ?? this.optionId,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'productId': productId,
        'optionId': optionId,
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> json, {String? id}) {
    return CartItem(
      id: id ?? json['id'] ?? '',
      customerId: json['customerId'] ?? '',
      productId: json['productId'] ?? '',
      optionId: (json['optionId'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      addedAt: json['addedAt'] is String
          ? DateTime.tryParse(json['addedAt'] as String)
          : null,
    );
  }
}

/// A cart item joined with its product, chosen colour option and retailer.
///
/// [image] is resolved from the **chosen** colour option — i.e. the first
/// image of `Products.colorOptions[optionId].image`, run through the
/// Cloudinary CDN/optimisation helpers. [isAsset] is only true for legacy
/// seed data whose path points into the bundled `assets/` folder.
class CartLine {
  /// `Cart-Items` document id — needed to update/remove this exact line.
  final String id;

  final String productId;
  final int optionId;
  int quantity;

  final String retailerId;
  final String productName;
  final String colorName;
  final String image;

  /// The same chosen-option image at its original (untransformed) size.
  /// [image] is a 200×200 thumbnail for cart rows; anything that displays the
  /// garment large — the Virtual Trial reference grid, its full-screen viewer
  /// — should use this instead so it isn't upscaling a thumbnail.
  final String fullImage;

  final bool isAsset;
  final double price;

  /// Stock available for the chosen option, used to cap quantity increments.
  final int stock;

  CartLine({
    required this.id,
    required this.productId,
    required this.optionId,
    required this.quantity,
    required this.retailerId,
    required this.productName,
    required this.colorName,
    required this.image,
    String? fullImage,
    required this.price,
    this.stock = 0,
    this.isAsset = false,
  }) : fullImage = fullImage ?? image;

  double get lineTotal => price * quantity;

  /// True when the customer already holds every remaining unit in the cart.
  bool get atStockLimit => quantity >= stock;
}

/// Retailer details needed to render a cart section (one section per
/// retailer == one future `Sub-order`).
class RetailerInfo {
  final String id;
  final String shopName;

  /// Distance-based delivery fee charged once per retailer (i.e. per
  /// Sub-order), computed by `CartService` from the customer's and the
  /// retailer's saved locations. Mirrors `Sub-orders.deliveryCharge`.
  final double deliveryCharge;

  /// Distance used for [deliveryCharge], or null when either party has no
  /// saved location and the base fee was applied instead.
  final double? distanceKm;

  const RetailerInfo({
    required this.id,
    required this.shopName,
    this.deliveryCharge = 0,
    this.distanceKm,
  });
}

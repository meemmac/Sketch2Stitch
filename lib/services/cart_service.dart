import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart_item.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/retailer.dart';
import '../utils/geo_utils.dart';
import 'Cloudinary_service.dart';
import 'checkout_service.dart';

/// Thrown by [CartService] with a user-friendly message so callers can
/// surface `e.message` directly without knowing Firestore error codes.
class CartServiceException implements Exception {
  const CartServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Everything the cart screen needs for one render pass: the hydrated lines
/// plus the retailer lookup (shop name + computed delivery charge) they are
/// grouped by.
class CartSnapshot {
  final List<CartLine> lines;
  final Map<String, RetailerInfo> retailers;

  /// The customer's saved location at the time the snapshot was built — the
  /// exact coordinates the per-retailer delivery charges were computed from.
  /// Persisted onto each `Sub-orders.deliveryPoint` at checkout so the charge
  /// can be audited later. Null when the customer has no saved location.
  final GeoPoint? customerLocation;

  /// How many `Cart-Items` rows were dropped while building this snapshot
  /// because their product was deleted, or their colour option retired, by
  /// the retailer since they were added. They used to vanish with no
  /// explanation; the cart screen surfaces this so the customer knows why
  /// their basket shrank. Not persisted anywhere — purely per-render.
  final int unavailableCount;

  const CartSnapshot({
    required this.lines,
    required this.retailers,
    this.customerLocation,
    this.unavailableCount = 0,
  });

  static const empty = CartSnapshot(lines: [], retailers: {});

  bool get isEmpty => lines.isEmpty;
}

/// Wraps all Firestore operations for the customer's cart.
///
/// Collections touched: `Cart-Items` (owned by this service), plus read-only
/// joins against `Products`, `Retailer` and `Customer`.
///
/// **Cart-Items** fields: customerId, productId, optionId, quantity, addedAt.
/// A cart line is uniquely identified by (customerId, productId, optionId) —
/// adding the same colour option again bumps `quantity` rather than creating
/// a second document.
class CartService {
  CartService({FirebaseFirestore? firestore, CloudinaryService? cloudinary})
      : _db = firestore ?? FirebaseFirestore.instance,
        _cloudinary = cloudinary ?? CloudinaryService();

  final FirebaseFirestore _db;
  final CloudinaryService _cloudinary;

  static const _cartItems = 'Cart-Items';
  static const _products = 'Products';
  static const _retailers = 'Retailer';
  static const _customers = 'Customer';

  /// Delivery pricing rules. Charged once per retailer (i.e. per Sub-order),
  /// derived from the straight-line distance between the customer's and the
  /// retailer's saved locations. The base fee applies when either side has
  /// no location on record yet.
  static const double baseDeliveryCharge = 60;
  static const double deliveryChargePerKm = 4;
  static const double maxDeliveryCharge = 300;

  // ── streamCart ─────────────────────────────────────────────────────────────

  /// Streams the customer's cart, fully hydrated and ready to render.
  ///
  /// Each `Cart-Items` document is joined with its `Products` doc to resolve
  /// the product name, the chosen colour option (price, colour name, stock)
  /// and that option's Cloudinary image. Retailers are fetched once per
  /// snapshot and their delivery charge computed from the customer's
  /// location.
  ///
  /// Lines whose product or chosen option no longer exists are dropped — the
  /// retailer may have deleted them since they were added.
  Stream<CartSnapshot> streamCart(String customerId) {
    return _db
        .collection(_cartItems)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .asyncMap((snap) async {
      final items = snap.docs
          .map((d) => CartItem.fromJson(d.data(), id: d.id))
          .toList();
      return _hydrate(customerId, items);
    });
  }

  /// One-shot equivalent of [streamCart].
  Future<CartSnapshot> getCart(String customerId) async {
    try {
      final snap = await _db
          .collection(_cartItems)
          .where('customerId', isEqualTo: customerId)
          .get();

      final items = snap.docs
          .map((d) => CartItem.fromJson(d.data(), id: d.id))
          .toList();
      return _hydrate(customerId, items);
    } on FirebaseException catch (e) {
      throw CartServiceException('Failed to load cart: ${e.message ?? e.code}');
    }
  }

  /// Streams the total number of units in the cart, for badge counts.
  Stream<int> streamCartCount(String customerId) {
    return _db
        .collection(_cartItems)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) => snap.docs.fold<int>(
              0,
              (total, d) => total + ((d.data()['quantity'] as num?)?.toInt() ?? 0),
            ));
  }

  // ── addToCart ──────────────────────────────────────────────────────────────

  /// Adds [quantity] units of [productId] / [optionId] to the customer's cart.
  ///
  /// If the same product + colour option is already in the cart, its quantity
  /// is increased instead of adding a duplicate line. Throws a
  /// [CartServiceException] when the requested total exceeds available stock.
  Future<void> addToCart(
    String customerId,
    String productId,
    int optionId,
    int quantity,
  ) async {
    if (quantity < 1) {
      throw const CartServiceException('Quantity must be at least 1.');
    }

    try {
      final option = await _getOption(productId, optionId);

      final existing = await _findLine(customerId, productId, optionId);
      final currentQty =
          existing == null ? 0 : (existing.data()['quantity'] as num?)?.toInt() ?? 0;
      final newQty = currentQty + quantity;

      if (newQty > option.stock) {
        throw CartServiceException(
          option.stock == 0
              ? 'This option is out of stock.'
              : 'Only ${option.stock} left in stock'
                  '${currentQty > 0 ? ' — you already have $currentQty in your cart.' : '.'}',
        );
      }

      if (existing != null) {
        await existing.reference.update({'quantity': newQty});
        return;
      }

      await _db.collection(_cartItems).add({
        'customerId': customerId,
        'productId': productId,
        'optionId': optionId,
        'quantity': quantity,
        'addedAt': Timestamp.now(),
      });
    } on CartServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw CartServiceException('Failed to add to cart: ${e.message ?? e.code}');
    }
  }

  // ── updateQuantity ─────────────────────────────────────────────────────────

  /// Sets the quantity of an existing cart line. A [quantity] of 0 or less
  /// removes the line, matching the cart's "decrement past 1 deletes" UX.
  Future<void> updateQuantity(String cartItemId, int quantity) async {
    if (quantity < 1) {
      await removeItem(cartItemId);
      return;
    }

    try {
      final ref = _db.collection(_cartItems).doc(cartItemId);
      final snap = await ref.get();
      if (!snap.exists) {
        throw const CartServiceException('This item is no longer in your cart.');
      }

      final data = snap.data()!;
      final option = await _getOption(
        data['productId'] as String,
        (data['optionId'] as num?)?.toInt() ?? 0,
      );

      if (quantity > option.stock) {
        throw CartServiceException('Only ${option.stock} left in stock.');
      }

      await ref.update({'quantity': quantity});
    } on CartServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw CartServiceException(
        'Failed to update quantity: ${e.message ?? e.code}',
      );
    }
  }

  // ── removeItem / clearCart ─────────────────────────────────────────────────

  /// Deletes a single cart line.
  Future<void> removeItem(String cartItemId) async {
    try {
      await _db.collection(_cartItems).doc(cartItemId).delete();
    } on FirebaseException catch (e) {
      throw CartServiceException('Failed to remove item: ${e.message ?? e.code}');
    }
  }

  /// Deletes every cart line belonging to [customerId]. Called after an order
  /// is successfully placed.
  Future<void> clearCart(String customerId) async {
    try {
      final snap = await _db
          .collection(_cartItems)
          .where('customerId', isEqualTo: customerId)
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw CartServiceException('Failed to clear cart: ${e.message ?? e.code}');
    }
  }

  // ── toOrderItemInputs ──────────────────────────────────────────────────────

  /// Converts hydrated cart lines into the payload
  /// [CheckoutService.createOrderItems] expects.
  List<OrderItemInput> toOrderItemInputs(List<CartLine> lines) {
    return lines
        .map((l) => OrderItemInput(
              productId: l.productId,
              optionId: l.optionId,
              quantity: l.quantity,
            ))
        .toList();
  }

  // ── Hydration ──────────────────────────────────────────────────────────────

  Future<CartSnapshot> _hydrate(String customerId, List<CartItem> items) async {
    if (items.isEmpty) return CartSnapshot.empty;

    final productIds = items.map((i) => i.productId).toSet().toList();
    final products = await _fetchProducts(productIds);

    final lines = <CartLine>[];
    var unavailable = 0;
    for (final item in items) {
      final product = products[item.productId];
      if (product == null) {
        unavailable++; // product deleted since it was added
        continue;
      }

      final option = product.colorOptions
          .cast<ColorOption?>()
          .firstWhere((o) => o?.optionId == item.optionId, orElse: () => null);
      if (option == null) {
        unavailable++; // colour option retired since it was added
        continue;
      }

      final fullImage = _resolveOptionImage(option);
      final image = _thumbnail(fullImage);

      lines.add(CartLine(
        id: item.id,
        productId: item.productId,
        optionId: item.optionId,
        quantity: item.quantity,
        retailerId: product.retailerId,
        productName: product.productName,
        colorName: option.color,
        image: image,
        fullImage: fullImage,
        isAsset: _isAssetPath(fullImage),
        price: option.price,
        stock: option.stock,
      ));
    }

    final customer = await _fetchCustomer(customerId);
    final retailerIds = lines.map((l) => l.retailerId).toSet().toList();
    final retailers = await _fetchRetailerInfo(customer, retailerIds);

    return CartSnapshot(
      lines: lines,
      retailers: retailers,
      customerLocation: customer?.location,
      unavailableCount: unavailable,
    );
  }

  /// Picks the image for the **chosen** colour option and turns it into a
  /// fully-qualified Cloudinary URL at its **original** size.
  ///
  /// `ColorOption.image` holds either full Cloudinary secure URLs (as written
  /// by [CloudinaryService.uploadImage]), bare Cloudinary public IDs, or —
  /// for seeded demo products — a bundled `assets/` path, which is passed
  /// through untouched.
  String _resolveOptionImage(ColorOption option) {
    final raw = option.image
        .map((p) => p.trim().replaceAll("'", '').replaceAll('"', ''))
        .firstWhere((p) => p.isNotEmpty, orElse: () => '');

    if (raw.isEmpty || _isAssetPath(raw)) return raw;

    return raw.contains('cloudinary.com') ? raw : _cdnUrl(raw);
  }

  /// Cart rows render at 64pt, so they ask Cloudinary for a square thumbnail
  /// rather than the full-size original. Asset paths pass through untouched.
  String _thumbnail(String url) {
    if (url.isEmpty || _isAssetPath(url)) return url;
    return _cloudinary.getOptimizedImageUrl(url, width: 200, height: 200);
  }

  bool _isAssetPath(String path) => path.toLowerCase().startsWith('assets/');

  String _cdnUrl(String publicId) {
    final cleaned = publicId.startsWith('/') ? publicId.substring(1) : publicId;
    return 'https://res.cloudinary.com/${CloudinaryService.cloudName}'
        '/image/upload/$cleaned';
  }

  Future<Map<String, Product>> _fetchProducts(List<String> ids) async {
    final products = <String, Product>{};

    for (final chunk in _chunk(ids, 30)) {
      final snap = await _db
          .collection(_products)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snap.docs) {
        products[doc.id] = Product.fromJson(doc.data(), id: doc.id);
      }
    }

    return products;
  }

  Future<Customer?> _fetchCustomer(String customerId) async {
    final snap = await _db.collection(_customers).doc(customerId).get();
    return snap.exists ? Customer.fromJson(snap.data()!, id: snap.id) : null;
  }

  /// Loads each retailer's shop name and computes its delivery charge from
  /// the distance to the customer's saved location.
  Future<Map<String, RetailerInfo>> _fetchRetailerInfo(
    Customer? customer,
    List<String> retailerIds,
  ) async {
    if (retailerIds.isEmpty) return {};

    final info = <String, RetailerInfo>{};

    for (final chunk in _chunk(retailerIds, 30)) {
      final snap = await _db
          .collection(_retailers)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snap.docs) {
        final retailer = Retailer.fromJson(doc.data(), id: doc.id);
        final distanceKm = (customer?.location != null &&
                retailer.location != null)
            ? GeoUtils.distanceKm(customer!.location!, retailer.location!)
            : null;

        info[doc.id] = RetailerInfo(
          id: doc.id,
          shopName: retailer.shopName,
          deliveryCharge: deliveryChargeFor(distanceKm),
          distanceKm: distanceKm,
        );
      }
    }

    // Retailers that no longer exist still need a placeholder so their lines
    // stay visible (and removable) in the cart.
    for (final id in retailerIds) {
      info.putIfAbsent(
        id,
        () => RetailerInfo(
          id: id,
          shopName: 'Unknown Retailer',
          deliveryCharge: baseDeliveryCharge,
        ),
      );
    }

    return info;
  }

  /// Base fee plus a per-km rate, capped. A null [distanceKm] (either party
  /// has no saved location) falls back to the base fee alone.
  static double deliveryChargeFor(double? distanceKm) {
    if (distanceKm == null) return baseDeliveryCharge;
    final charge = baseDeliveryCharge + (distanceKm * deliveryChargePerKm);
    return charge > maxDeliveryCharge ? maxDeliveryCharge : charge.roundToDouble();
  }

  Future<ColorOption> _getOption(String productId, int optionId) async {
    final snap = await _db.collection(_products).doc(productId).get();
    if (!snap.exists) {
      throw const CartServiceException('This product is no longer available.');
    }

    final product = Product.fromJson(snap.data()!, id: snap.id);
    final option = product.colorOptions
        .cast<ColorOption?>()
        .firstWhere((o) => o?.optionId == optionId, orElse: () => null);

    if (option == null) {
      throw const CartServiceException(
        'This colour option is no longer available.',
      );
    }

    return option;
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findLine(
    String customerId,
    String productId,
    int optionId,
  ) async {
    final snap = await _db
        .collection(_cartItems)
        .where('customerId', isEqualTo: customerId)
        .where('productId', isEqualTo: productId)
        .where('optionId', isEqualTo: optionId)
        .limit(1)
        .get();

    return snap.docs.isEmpty ? null : snap.docs.first;
  }

  /// Firestore `whereIn` accepts at most 30 values per query.
  Iterable<List<String>> _chunk(List<String> ids, int size) sync* {
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../models/sub_order.dart';

/// Thrown by [CheckoutService] with a user-friendly message so callers
/// can surface `e.message` directly without knowing Firestore error codes.
class CheckoutServiceException implements Exception {
  const CheckoutServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Lightweight payload used by [CheckoutService.createOrderItems].
class OrderItemInput {
  final String productId;
  final int optionId;
  final int quantity;

  const OrderItemInput({
    required this.productId,
    required this.optionId,
    required this.quantity,
  });
}

/// Full order aggregate returned by [CheckoutService.getOrderDetails].
class OrderDetails {
  final Order order;
  final List<SubOrder> subOrders;

  /// Items keyed by subOrderId.
  final Map<String, List<OrderItem>> itemsBySubOrder;

  const OrderDetails({
    required this.order,
    required this.subOrders,
    required this.itemsBySubOrder,
  });
}

/// Wraps all Firestore operations for the cart & checkout flow.
///
/// Collections touched: `Products`, `Orders`, `Sub-orders`,
/// `Order-Items`, `Payments`.
class CheckoutService {
  CheckoutService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _products   = 'Products';
  static const _orders     = 'Orders';
  static const _subOrders  = 'Sub-orders';
  static const _orderItems = 'Order-Items';
  static const _payments   = 'Payments';

  // ── getProductDetails ──────────────────────────────────────────────────────

  /// Fetches a single [Product] by [productId].
  Future<Product> getProductDetails(String productId) async {
    try {
      final snap = await _db.collection(_products).doc(productId).get();

      if (!snap.exists) {
        throw CheckoutServiceException('Product "$productId" not found.');
      }

      return Product.fromJson({...snap.data()!, 'id': snap.id});
    } on CheckoutServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw CheckoutServiceException(
        'Failed to fetch product: ${e.message ?? e.code}',
      );
    }
  }

  // ── getProductsByRetailer ──────────────────────────────────────────────────

  /// Returns all [Product]s that belong to [retailerId].
  Future<List<Product>> getProductsByRetailer(String retailerId) async {
    try {
      final snap = await _db
          .collection(_products)
          .where('retailerId', isEqualTo: retailerId)
          .get();

      return snap.docs
          .map((d) => Product.fromJson({...d.data(), 'id': d.id}))
          .toList();
    } on FirebaseException catch (e) {
      throw CheckoutServiceException(
        'Failed to fetch retailer products: ${e.message ?? e.code}',
      );
    }
  }

  // ── checkStock ─────────────────────────────────────────────────────────────

  /// Validates that [productId] / [optionId] has at least [quantity] units in
  /// stock.
  ///
  /// Returns `true` when stock is sufficient, `false` otherwise.
  /// Throws [CheckoutServiceException] when the product or option is not found.
  Future<bool> checkStock(
    String productId,
    int optionId,
    int quantity,
  ) async {
    try {
      final product = await getProductDetails(productId);

      final option = product.colorOptions.cast<ColorOption?>().firstWhere(
            (o) => o?.optionId == optionId,
            orElse: () => null,
          );

      if (option == null) {
        throw CheckoutServiceException(
          'Option $optionId not found on product "$productId".',
        );
      }

      return option.stock >= quantity;
    } on CheckoutServiceException {
      rethrow;
    }
  }

  // ── createOrder ────────────────────────────────────────────────────────────

  /// Creates a parent `Orders` document for [customerId].
  ///
  /// [data] may contain any extra fields (e.g. `tailorSelectionDeadline`).
  /// `customerId`, `orderDate`, and `status` are always set by this method.
  ///
  /// Returns the saved [Order].
  Future<Order> createOrder(
    String customerId,
    Map<String, dynamic> data,
  ) async {
    try {
      final now = Timestamp.now();
      final payload = Map<String, dynamic>.from(data)
        ..['customerId'] = customerId
        ..['orderDate']  = now
        ..['status']     = OrderStatus.awaitingConfirmation.toValue;

      final ref  = await _db.collection(_orders).add(payload);
      final snap = await ref.get();

      return _orderFromSnap(snap);
    } on FirebaseException catch (e) {
      throw CheckoutServiceException(
        'Failed to create order: ${e.message ?? e.code}',
      );
    }
  }

  // ── createSubOrder ─────────────────────────────────────────────────────────

  /// Creates a `Sub-orders` document linked to [orderId] for [retailerId].
  ///
  /// [data] must include fields such as `itemsSubtotal`, `deliveryCharge`,
  /// `deliveryDestination`, etc. `orderId` and `retailerId` are always
  /// injected by this method.
  ///
  /// Returns the saved [SubOrder].
  Future<SubOrder> createSubOrder(
    String orderId,
    String retailerId,
    Map<String, dynamic> data,
  ) async {
    try {
      final payload = Map<String, dynamic>.from(data)
        ..['orderId']    = orderId
        ..['retailerId'] = retailerId
        ..['status']     = data['status'] ?? SubOrderStatus.preparing.name;

      final ref  = await _db.collection(_subOrders).add(payload);
      final snap = await ref.get();

      return _subOrderFromSnap(snap);
    } on FirebaseException catch (e) {
      throw CheckoutServiceException(
        'Failed to create sub-order: ${e.message ?? e.code}',
      );
    }
  }

  // ── createOrderItems ───────────────────────────────────────────────────────

  /// Batch-inserts all [items] under [subOrderId] in a single Firestore
  /// batch write and returns the saved [OrderItem] list.
  Future<List<OrderItem>> createOrderItems(
    String subOrderId,
    List<OrderItemInput> items,
  ) async {
    if (items.isEmpty) return [];

    try {
      final batch = _db.batch();
      final refs  = <DocumentReference>[];

      for (final item in items) {
        final ref = _db.collection(_orderItems).doc();
        batch.set(ref, {
          'subOrderId': subOrderId,
          'productId':  item.productId,
          'optionId':   item.optionId,
          'quantity':   item.quantity,
        });
        refs.add(ref);
      }

      await batch.commit();

      // Fetch saved docs to return hydrated models.
      final snaps = await Future.wait(refs.map((r) => r.get()));
      return snaps
          .map((s) => OrderItem.fromJson({...s.data()! as Map<String, dynamic>, 'id': s.id}))
          .toList();
    } on FirebaseException catch (e) {
      throw CheckoutServiceException(
        'Failed to create order items: ${e.message ?? e.code}',
      );
    }
  }

  // ── recordPayment ──────────────────────────────────────────────────────────

  /// Saves a payment record to the `Payments` collection for [orderId].
  ///
  /// [paymentData] must include: `method`, `amount`, `targetType`, `targetId`,
  /// and optionally `transactionId`, `itemsAmount`, `deliveryAmount`.
  /// `orderId`, `date`, and `status` are always written by this method.
  ///
  /// Returns the saved [Payment].
  Future<Payment> recordPayment(
    String orderId,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final payload = Map<String, dynamic>.from(paymentData)
        ..['orderId'] = orderId
        ..['date']    = Timestamp.now()
        ..['status']  = paymentData['status'] ?? PaymentStatus.pending.toValue;

      final ref  = await _db.collection(_payments).add(payload);
      final snap = await ref.get();

      return _paymentFromSnap(snap);
    } on FirebaseException catch (e) {
      throw CheckoutServiceException(
        'Failed to record payment: ${e.message ?? e.code}',
      );
    }
  }

  // ── getPaymentStatus ───────────────────────────────────────────────────────

  /// Returns all [Payment] records linked to [orderId].
  ///
  /// Most orders have a single payment; multiple entries may exist for
  /// partial payments or retries.
  Future<List<Payment>> getPaymentStatus(String orderId) async {
    try {
      final snap = await _db
          .collection(_payments)
          .where('orderId', isEqualTo: orderId)
          .get();

      return snap.docs.map(_paymentFromSnap).toList();
    } on FirebaseException catch (e) {
      throw CheckoutServiceException(
        'Failed to fetch payment status: ${e.message ?? e.code}',
      );
    }
  }

  // ── getOrderDetails ────────────────────────────────────────────────────────

  /// Fetches the full order aggregate for [orderId]:
  ///   - the parent [Order]
  ///   - all [SubOrder]s
  ///   - all [OrderItem]s grouped by sub-order id
  ///
  /// Sub-orders and items are fetched in parallel for efficiency.
  Future<OrderDetails> getOrderDetails(String orderId) async {
    try {
      // Fetch order + sub-orders in parallel.
      final orderSnapFuture = _db.collection(_orders).doc(orderId).get();
      final subSnapFuture   = _db
          .collection(_subOrders)
          .where('orderId', isEqualTo: orderId)
          .get();

      final results    = await Future.wait([orderSnapFuture, subSnapFuture]);
      final orderSnap  = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final subSnap    = results[1] as QuerySnapshot<Map<String, dynamic>>;

      if (!orderSnap.exists) {
        throw CheckoutServiceException('Order "$orderId" not found.');
      }

      final order     = _orderFromSnap(orderSnap);
      final subOrders = subSnap.docs.map(_subOrderFromSnap).toList();

      // Fetch all order-items for each sub-order in parallel.
      final itemsBySubOrder = <String, List<OrderItem>>{};
      if (subOrders.isNotEmpty) {
        final subOrderIds = subOrders.map((s) => s.id).toList();

        // Firestore 'whereIn' supports up to 30 values per query.
        final chunks = <List<String>>[];
        for (var i = 0; i < subOrderIds.length; i += 30) {
          chunks.add(subOrderIds.sublist(
            i,
            i + 30 > subOrderIds.length ? subOrderIds.length : i + 30,
          ));
        }

        final itemSnaps = await Future.wait(
          chunks.map(
            (chunk) => _db
                .collection(_orderItems)
                .where('subOrderId', whereIn: chunk)
                .get(),
          ),
        );

        for (final snap in itemSnaps) {
          for (final doc in snap.docs) {
            final item = OrderItem.fromJson({...doc.data(), 'id': doc.id});
            itemsBySubOrder
                .putIfAbsent(item.subOrderId, () => [])
                .add(item);
          }
        }
      }

      return OrderDetails(
        order: order,
        subOrders: subOrders,
        itemsBySubOrder: itemsBySubOrder,
      );
    } on CheckoutServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw CheckoutServiceException(
        'Failed to fetch order details: ${e.message ?? e.code}',
      );
    }
  }

  // ── cancelOrder ────────────────────────────────────────────────────────────

  /// Sets the `Orders` document status to `cancelled` and marks any
  /// `pending` payment records for this order as `failed`.
  ///
  /// Both writes are performed in a single batch for atomicity.
  ///
  /// Returns the updated [Order].
  Future<Order> cancelOrder(String orderId) async {
    try {
      // Fetch pending payments to update alongside the order.
      final paymentsSnap = await _db
          .collection(_payments)
          .where('orderId', isEqualTo: orderId)
          .where('status', isEqualTo: PaymentStatus.pending.toValue)
          .get();

      final orderRef = _db.collection(_orders).doc(orderId);
      final batch    = _db.batch();

      batch.update(orderRef, {'status': OrderStatus.cancelled.toValue});

      for (final payDoc in paymentsSnap.docs) {
        batch.update(payDoc.reference, {
          'status': PaymentStatus.failed.toValue,
        });
      }

      await batch.commit();

      final snap = await orderRef.get();
      if (!snap.exists) {
        throw CheckoutServiceException('Order "$orderId" not found.');
      }

      return _orderFromSnap(snap);
    } on CheckoutServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw CheckoutServiceException(
        'Failed to cancel order: ${e.message ?? e.code}',
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Order _orderFromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    // Normalise Firestore Timestamp → ISO string for fromJson.
    if (data['orderDate'] is Timestamp) {
      data['orderDate'] =
          (data['orderDate'] as Timestamp).toDate().toIso8601String();
    }
    if (data['tailorSelectionDeadline'] is Timestamp) {
      data['tailorSelectionDeadline'] =
          (data['tailorSelectionDeadline'] as Timestamp)
              .toDate()
              .toIso8601String();
    }
    return Order.fromJson({...data, 'id': snap.id});
  }

  SubOrder _subOrderFromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    if (data['deliveryDate'] is Timestamp) {
      data['deliveryDate'] =
          (data['deliveryDate'] as Timestamp).toDate().toIso8601String();
    }
    if (data['autoReleaseAt'] is Timestamp) {
      data['autoReleaseAt'] =
          (data['autoReleaseAt'] as Timestamp).toDate().toIso8601String();
    }
    return SubOrder.fromJson({...data, 'id': snap.id});
  }

  Payment _paymentFromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    if (data['date'] is Timestamp) {
      data['date'] =
          (data['date'] as Timestamp).toDate().toIso8601String();
    }
    return Payment.fromJson({...data, 'id': snap.id});
  }
}

import 'package:flutter/foundation.dart' show kDebugMode;
import '../../models/sub_order.dart';

/// One customer order. Per the DB schema, `Tailor-jobs` has an `orderId`
/// field but NO `subOrderId` field — a tailor job is created once per
/// ORDER and covers every sub-order in it. There is no per-sub-order
/// tailor selection; the customer picks ONE tailor for the whole order.
class OrderRecord {
  final String orderId;
  final DateTime orderDate;
  String orderStatus; // Orders.status
  DateTime? tailorSelectionDeadline;

  // The sub-orders (one per retailer) this order was created with.
  // Captured once at startOrder() time since the cart is cleared right
  // after checkout and can't be relied on to reconstruct this later.
  List<SubOrder> subOrders = [];

  // At most ONE tailor job for the whole order — matches Tailor-jobs
  // schema (orderId field, no subOrderId field).
  TailorJobRecord? tailorJob;

  OrderRecord({
    required this.orderId,
    required this.orderDate,
    this.orderStatus = 'awaiting_confirmation',
  });

  /// Whether this order still needs a decision from the customer.
  ///
  /// IMPORTANT: 'processing' (tailoring skipped, or tailor-search window
  /// expired with no job) and 'completed' (tailor paid) are TERMINAL
  /// states — there is nothing left for the customer to do, so they must
  /// NOT be treated as active. Including 'processing' here was the bug
  /// that made skipped orders keep showing "Continue Your Order".
  bool get isActive =>
      orderStatus == 'awaiting_confirmation' ||
      orderStatus == 'awaiting_tailor_search' ||
      orderStatus == 'tailor_pending';
}

/// Mirrors the `Tailor-jobs` collection: one job per order, one tailor,
/// covering every sub-order in that order.
class TailorJobRecord {
  final String tailorJobId;
  final String orderId;
  final String tailorId;
  final String measurementId;
  final List<String> designIds;
  final String specialInstructions;

  String status; // pending | quoted | confirmed | rejected | expired | cancelled
  final DateTime requestedAt;
  DateTime? confirmedAt;

  double? quoteAmount;
  double? deliverCharge; // field name matches schema spelling
  DateTime? estimatedDeliveryDate;
  String? rejectionReason;

  String quoteStatus; // notSent | sent | accepted | declined
  String tailorPaymentStatus; // unpaid | paid

  TailorJobRecord({
    required this.tailorJobId,
    required this.orderId,
    required this.tailorId,
    required this.requestedAt,
    this.measurementId = '',
    this.designIds = const [],
    this.specialInstructions = '',
    this.status = 'pending',
    this.confirmedAt,
    this.quoteAmount,
    this.deliverCharge,
    this.estimatedDeliveryDate,
    this.rejectionReason,
    this.quoteStatus = 'notSent',
    this.tailorPaymentStatus = 'unpaid',
  });

  double? get totalAmount =>
      quoteAmount == null ? null : quoteAmount! + (deliverCharge ?? 0);
}

class OrderStore {
  OrderStore._() {
    // Auto-seeds dummy orders the first time this singleton is created —
    // i.e. the first time anything touches OrderStore.instance. Debug-only,
    // so it never runs in a release build, and it only ever runs once per
    // app process since the constructor only fires on first access.
    if (kDebugMode) _seedDebugData();
  }
  static final OrderStore instance = OrderStore._();

  final Map<String, OrderRecord> _orders = {};

  // Monotonic counter appended to generated IDs. millisecondsSinceEpoch
  // alone collides when multiple orders/jobs are created synchronously
  // (e.g. back-to-back in _seedDebugData()) — two calls landing in the
  // same millisecond produced the same orderId, and since _orders is
  // keyed by orderId, the second silently overwrote the first in the
  // map. That's what caused activeOrders to undercount after seeding.
  int _idCounter = 0;
  String _nextId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  /// Orders that still need a customer decision (tailor selection,
  /// confirm/reject, or payment). Shown in the "Running Orders" screen.
  List<OrderRecord> get activeOrders =>
      _orders.values.where((o) => o.isActive).toList();

  /// Orders that are done from the customer's side (skipped, expired-to-
  /// direct-delivery, or fully paid). Not shown as "running".
  List<OrderRecord> get finishedOrders =>
      _orders.values.where((o) => !o.isActive).toList();

  OrderRecord? get(String orderId) => _orders[orderId];

  /// Starts a brand-new order from the given sub-orders (captured at
  /// checkout time, before the cart gets cleared).
  OrderRecord startOrder(List<SubOrder> subOrders) {
    final order = OrderRecord(
      orderId: _nextId('ORDER'),
      orderDate: DateTime.now(),
    );
    order.subOrders =
        subOrders.map((s) => s.copyWith(orderId: order.orderId)).toList();
    _orders[order.orderId] = order;
    return order;
  }

  void setSkippedTailoring(String orderId) {
    final o = _orders[orderId];
    if (o == null) return;
    o.orderStatus = 'processing'; // terminal — see OrderRecord.isActive
  }

  void setAwaitingTailorSearch(String orderId, DateTime deadline) {
    final o = _orders[orderId];
    if (o == null) return;
    o.orderStatus = 'awaiting_tailor_search';
    o.tailorSelectionDeadline = deadline;
  }

  /// Creates the ONE tailor job for this order, covering every sub-order
  /// in it. Matches Tailor-jobs schema — no subOrderId, orderId only.
  TailorJobRecord createTailorJob({
    required String orderId,
    required String tailorId,
    String measurementId = '',
    List<String> designIds = const [],
    String specialInstructions = '',
  }) {
    final job = TailorJobRecord(
      tailorJobId: _nextId('JOB'),
      orderId: orderId,
      tailorId: tailorId,
      requestedAt: DateTime.now(),
      measurementId: measurementId,
      designIds: designIds,
      specialInstructions: specialInstructions,
    );
    final o = _orders[orderId]!;
    o.tailorJob = job;
    o.orderStatus = 'tailor_pending';
    return job;
  }

  /// Confirms the order's tailor job. `quoteAmount` and
  /// `estimatedDeliveryDate` are BOTH required — a job cannot be marked
  /// confirmed without a price and a delivery estimate from the tailor.
  /// `deliverCharge` defaults to 0 if the tailor doesn't charge separately
  /// for delivery.
  void confirmTailorJob(
    String orderId, {
    required double quoteAmount,
    required DateTime estimatedDeliveryDate,
    double deliverCharge = 0,
  }) {
    final job = _orders[orderId]?.tailorJob;
    if (job == null) return;
    job.status = 'confirmed';
    job.confirmedAt = DateTime.now();
    job.quoteAmount = quoteAmount;
    job.estimatedDeliveryDate = estimatedDeliveryDate;
    job.deliverCharge = deliverCharge;
  }

  void rejectTailorJob(String orderId, String reason) {
    final job = _orders[orderId]?.tailorJob;
    if (job == null) return;
    job.status = 'rejected';
    job.rejectionReason = reason;
  }

  /// Whether the order's tailor job (if any) is resolved: confirmed +
  /// paid, or expired. Orders with no tailor job at all are resolved only
  /// via setSkippedTailoring (handled separately, not through this path).
  bool _isTailorJobResolved(OrderRecord o) {
    final job = o.tailorJob;
    if (job == null) return false;
    final resolvedViaTailor =
        job.status == 'confirmed' && job.tailorPaymentStatus == 'paid';
    final resolvedViaExpiry = job.status == 'expired';
    return resolvedViaTailor || resolvedViaExpiry;
  }

  /// Marks the order's tailor job as paid, then completes the ORDER if
  /// the job is now resolved (confirmed + paid).
  void payTailorJob(String orderId) {
    final o = _orders[orderId];
    if (o == null) return;
    final job = o.tailorJob;
    if (job == null) return;

    job.tailorPaymentStatus = 'paid';

    if (_isTailorJobResolved(o)) {
      o.orderStatus = 'completed';
    }
  }

  void completeOrder(String orderId) {
    final o = _orders[orderId];
    if (o == null) return;
    o.orderStatus = 'completed'; // terminal — see OrderRecord.isActive
  }

  /// Marks the order's tailor job (if any) as expired and the order as
  /// terminal ('processing' — falls back to direct delivery). Call this
  /// from onTailorSearchExpired instead of leaving the order stuck in
  /// 'awaiting_tailor_search' forever.
  ///
  /// Unconditional: expiry means the order's tailor-selection WINDOW
  /// closed, so the order falls back to direct delivery right then,
  /// regardless of whether a job existed or what state it was in.
  void expireTailorSearch(String orderId) {
    final o = _orders[orderId];
    if (o == null) return;
    o.tailorJob?.status = 'expired';
    o.orderStatus = 'processing';
  }

  /// Removes an order from the store entirely (e.g. after the customer
  /// acknowledges the "Order Confirmed" dialog and it's no longer needed
  /// for resume/display purposes). Optional — finished orders are already
  /// excluded from activeOrders, so calling this is not required to fix
  /// the "Continue Your Order" bug, only to free memory.
  void remove(String orderId) => _orders.remove(orderId);

  /// Debug-only seed: one order per UI state, so every card/status in
  /// TailoringSetupScreen and RunningOrdersScreen can be exercised without
  /// manually clicking through the whole flow. Runs once, automatically,
  /// the first time OrderStore.instance is created.
  void _seedDebugData() {
    // 1. Awaiting tailor search — no job yet, deadline still open.
    final o1 = startOrder([
      SubOrder(
        id: 'RET001',
        orderId: '',
        retailerId: 'RET001',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 1980,
        deliveryCharge: 80,
      ),
    ]);
    setAwaitingTailorSearch(o1.orderId, DateTime.now().add(const Duration(hours: 60)));

    // 2. Pending tailor job — request sent, awaiting tailor response.
    // Two sub-orders, ONE job covers both.
    final o2 = startOrder([
      SubOrder(
        id: 'RET001',
        orderId: '',
        retailerId: 'RET001',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 900,
        deliveryCharge: 60,
      ),
      SubOrder(
        id: 'RET002',
        orderId: '',
        retailerId: 'RET002',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 1800,
        deliveryCharge: 120,
      ),
    ]);
    setAwaitingTailorSearch(o2.orderId, DateTime.now().add(const Duration(hours: 40)));
    createTailorJob(orderId: o2.orderId, tailorId: 'TAILOR_A');

    // 3. Confirmed, unpaid tailor job — customer still needs to pay.
    // Quote + delivery date supplied together via confirmTailorJob.
    final o3 = startOrder([
      SubOrder(
        id: 'RET001',
        orderId: '',
        retailerId: 'RET001',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 1300,
        deliveryCharge: 80,
      ),
    ]);
    setAwaitingTailorSearch(o3.orderId, DateTime.now().add(const Duration(hours: 20)));
    createTailorJob(orderId: o3.orderId, tailorId: 'TAILOR_B');
    confirmTailorJob(
      o3.orderId,
      quoteAmount: 4500,
      estimatedDeliveryDate: DateTime.now().add(const Duration(days: 10)),
      deliverCharge: 150,
    );

    // 4. Rejected tailor job — customer needs to pick another tailor.
    final o4 = startOrder([
      SubOrder(
        id: 'RET002',
        orderId: '',
        retailerId: 'RET002',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 900,
        deliveryCharge: 120,
      ),
    ]);
    setAwaitingTailorSearch(o4.orderId, DateTime.now().add(const Duration(hours: 10)));
    createTailorJob(orderId: o4.orderId, tailorId: 'TAILOR_C');
    rejectTailorJob(o4.orderId, 'Fully booked this week.');

    // 5. Skipped tailoring — TERMINAL, must NOT show in Running Orders.
    final o5 = startOrder([
      SubOrder(
        id: 'RET001',
        orderId: '',
        retailerId: 'RET001',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 2000,
        deliveryCharge: 80,
      ),
    ]);
    setSkippedTailoring(o5.orderId);

    // 6. Deadline expired, no job ever created — TERMINAL.
    final o6 = startOrder([
      SubOrder(
        id: 'RET002',
        orderId: '',
        retailerId: 'RET002',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 700,
        deliveryCharge: 120,
      ),
    ]);
    setAwaitingTailorSearch(o6.orderId, DateTime.now().subtract(const Duration(hours: 1)));
    expireTailorSearch(o6.orderId);

    // 7. Fully completed order — confirmed tailor job, paid — TERMINAL.
    final o7 = startOrder([
      SubOrder(
        id: 'RET001',
        orderId: '',
        retailerId: 'RET001',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 1500,
        deliveryCharge: 80,
      ),
    ]);
    setAwaitingTailorSearch(o7.orderId, DateTime.now().add(const Duration(hours: 30)));
    createTailorJob(orderId: o7.orderId, tailorId: 'TAILOR_D');
    confirmTailorJob(
      o7.orderId,
      quoteAmount: 3000,
      estimatedDeliveryDate: DateTime.now().add(const Duration(days: 7)),
      deliverCharge: 80,
    );
    payTailorJob(o7.orderId); // marks paid + completes since job is resolved

    assert(
      activeOrders.length == 4,
      'Expected 4 active orders after seeding, got ${activeOrders.length}. '
      'isActive logic may have regressed.',
    );
  }
}
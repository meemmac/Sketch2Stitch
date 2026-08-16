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

  String status; // pending | quoted | confirmed | rejected | tailor_declined | expired | cancelled
  final DateTime requestedAt;
  DateTime? confirmedAt;

  double? quoteAmount;
  double? deliverCharge;
  DateTime? estimatedDeliveryDate;

  // Set only by tailorDeclinesJob() — the tailor's reason for declining
  // outright, before ever sending a quote. NOT used for customer
  // rejection of a quote, which stays reason-less by design.
  String? rejectionReason;

  String quoteStatus;
  String tailorPaymentStatus;

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
  ///
  /// [orderId] / [orderDate] should be passed once the order has been
  /// written to Firestore, so this local record shares the real `Orders`
  /// document id. Everything downstream (tailor jobs, notifications, the
  /// Running Orders screen) keys off this id, so a locally-generated one
  /// would leave the Firestore order orphaned. They fall back to a
  /// generated id for the seeded demo orders below.
  OrderRecord startOrder(
    List<SubOrder> subOrders, {
    String? orderId,
    DateTime? orderDate,
  }) {
    final order = OrderRecord(
      orderId: orderId ?? _nextId('ORDER'),
      orderDate: orderDate ?? DateTime.now(),
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
  /// Status starts at 'pending' — the tailor hasn't responded yet, so
  /// there's nothing for the customer to confirm/reject until the tailor
  /// sends a quote via submitTailorQuote().
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

  /// TAILOR-SIDE ACTION: the tailor sends back their price, delivery
  /// charge, and estimated delivery date for a pending job. Moves the
  /// job from 'pending' to 'quoted' — this is what makes Confirm/Reject
  /// meaningful on the customer's screen. Before this is called, there
  /// is nothing for the customer to act on.
  void submitTailorQuote(
    String orderId, {
    required double quoteAmount,
    required DateTime estimatedDeliveryDate,
    double deliverCharge = 0,
  }) {
    final job = _orders[orderId]?.tailorJob;
    if (job == null) return;
    job.status = 'quoted';
    job.quoteAmount = quoteAmount;
    job.estimatedDeliveryDate = estimatedDeliveryDate;
    job.deliverCharge = deliverCharge;
    job.quoteStatus = 'sent';
  }

  /// TAILOR-SIDE ACTION: the tailor declines the job outright, before
  /// ever sending a quote. Only valid from 'pending' — once a quote has
  /// gone out, declining is the customer's call via rejectTailorJob(),
  /// not the tailor's.
  void tailorDeclinesJob(String orderId, {String? reason}) {
    final job = _orders[orderId]?.tailorJob;
    if (job == null || job.status != 'pending') return;
    job.status = 'tailor_declined';
    job.rejectionReason = reason;
    // orderStatus stays 'tailor_pending' — the order is still active,
    // the customer just needs to browse another tailor or skip.
  }

  /// Customer accepts the tailor's already-submitted quote as-is AND
  /// pays in the same action — confirm and pay are atomic in the
  /// current flow, there is no confirmed-but-unpaid in-between state.
  /// Both quoteAmount and estimatedDeliveryDate must already be present
  /// on the job (i.e. the job must be 'quoted').
  void confirmTailorJob(String orderId) {
    final o = _orders[orderId];
    final job = o?.tailorJob;
    if (o == null ||
        job == null ||
        job.quoteAmount == null ||
        job.estimatedDeliveryDate == null) {
      return;
    }
    job.status = 'confirmed';
    job.confirmedAt = DateTime.now();
    job.quoteStatus = 'accepted';
    job.tailorPaymentStatus = 'paid';
    o.orderStatus = 'completed'; // terminal — resolved the instant it's confirmed
  }

  /// Customer declines the tailor's quote. No reason required — this is
  /// the customer's simple "no thanks", not a justified decision.
  void rejectTailorJob(String orderId) {
    final job = _orders[orderId]?.tailorJob;
    if (job == null) return;
    job.status = 'rejected';
    job.quoteStatus = 'declined';
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

  /// Debug-only seed: exactly ONE order per distinct UI state that
  /// TailoringSetupScreen can render, no redundant duplicates. Runs once,
  /// automatically, the first time OrderStore.instance is created.
  ///
  /// Active states (5) — shown in Running Orders, customer still has
  /// something to do:
  ///   1. No tailor job yet               → _buildNoTailorCard
  ///   2. Job pending (no quote yet)       → _buildPendingCard
  ///   3. Job quoted                       → _buildQuotedCard
  ///   4. Job rejected by customer         → _buildRejectedCard
  ///   5. Job declined by tailor           → _buildTailorDeclinedCard
  ///
  /// Terminal states (3) — NOT in Running Orders, nothing left to do:
  ///   6. Skipped tailoring                → order.isActive == false
  ///   7. Tailor-selection window expired   → order.isActive == false
  ///   8. Confirmed + paid (atomic now)     → order.isActive == false
  void _seedDebugData() {
    // 1. No tailor job yet — deadline still open.
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

    // 2. Job pending — request sent, tailor hasn't responded yet.
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

    // 3. Job quoted — tailor responded with a price, customer still
    // needs to Confirm/Reject.
    final o3 = startOrder([
      SubOrder(
        id: 'RET001',
        orderId: '',
        retailerId: 'RET001',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 1100,
        deliveryCharge: 70,
      ),
    ]);
    setAwaitingTailorSearch(o3.orderId, DateTime.now().add(const Duration(hours: 36)));
    createTailorJob(orderId: o3.orderId, tailorId: 'TAILOR_B');
    submitTailorQuote(
      o3.orderId,
      quoteAmount: 3800,
      estimatedDeliveryDate: DateTime.now().add(const Duration(days: 9)),
      deliverCharge: 100,
    );

    // 4. Job rejected by customer — customer needs to pick another tailor.
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
    submitTailorQuote(
      o4.orderId,
      quoteAmount: 5200,
      estimatedDeliveryDate: DateTime.now().add(const Duration(days: 12)),
      deliverCharge: 90,
    );
    rejectTailorJob(o4.orderId);

    // 5. Job declined by tailor outright — no quote ever sent.
    final o5 = startOrder([
      SubOrder(
        id: 'RET001',
        orderId: '',
        retailerId: 'RET001',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 1200,
        deliveryCharge: 90,
      ),
    ]);
    setAwaitingTailorSearch(o5.orderId, DateTime.now().add(const Duration(hours: 15)));
    createTailorJob(orderId: o5.orderId, tailorId: 'TAILOR_F');
    tailorDeclinesJob(o5.orderId, reason: "Fully booked this week");

    // 6. Skipped tailoring — TERMINAL, must NOT show in Running Orders.
    final o6 = startOrder([
      SubOrder(
        id: 'RET001',
        orderId: '',
        retailerId: 'RET001',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 2000,
        deliveryCharge: 80,
      ),
    ]);
    setSkippedTailoring(o6.orderId);

    // 7. Tailor-selection window expired, no job ever confirmed — TERMINAL.
    final o7 = startOrder([
      SubOrder(
        id: 'RET002',
        orderId: '',
        retailerId: 'RET002',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 700,
        deliveryCharge: 120,
      ),
    ]);
    setAwaitingTailorSearch(o7.orderId, DateTime.now().subtract(const Duration(hours: 1)));
    expireTailorSearch(o7.orderId);

    // 8. Confirmed + paid — TERMINAL. Confirm and pay are atomic now, so
    // this is the only "successfully arranged" end state; there is no
    // confirmed-but-unpaid state to seed separately.
    final o8 = startOrder([
      SubOrder(
        id: 'RET001',
        orderId: '',
        retailerId: 'RET001',
        status: SubOrderStatus.preparing,
        itemsSubtotal: 1500,
        deliveryCharge: 80,
      ),
    ]);
    setAwaitingTailorSearch(o8.orderId, DateTime.now().add(const Duration(hours: 30)));
    createTailorJob(orderId: o8.orderId, tailorId: 'TAILOR_D');
    submitTailorQuote(
      o8.orderId,
      quoteAmount: 3000,
      estimatedDeliveryDate: DateTime.now().add(const Duration(days: 7)),
      deliverCharge: 80,
    );
    confirmTailorJob(o8.orderId); // now sets paid + completed atomically

    assert(
      activeOrders.length == 5,
      'Expected 5 active orders after seeding, got ${activeOrders.length}. '
      'isActive logic may have regressed.',
    );
  }
}
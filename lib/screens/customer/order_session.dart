import '../../models/measurement.dart';

/// Enum values mirror Orders.status / Tailor-jobs.status exactly, so this
/// maps 1:1 onto real backend docs later — swapping this singleton for
/// real Firestore reads/writes shouldn't require touching any UI code.
class OrderSession {
  OrderSession._();
  static final OrderSession instance = OrderSession._();

  // Orders fields
  String? orderId;
  String orderStatus = 'awaiting_confirmation'; // Orders.status
  DateTime? orderDate;
  DateTime? tailorSelectionDeadline;

  // Tailor-jobs fields (0-or-1 per order, per schema)
  String? tailorJobId;
  String? tailorId;
  String tailorJobStatus = 'pending'; // Tailor-jobs.status
  DateTime? tailorJobRequestedAt;
  double? quoteAmount;
  DateTime? estimatedDeliveryDate;
  String? rejectionReason;

  bool get hasActiveOrder => orderId != null && orderStatus != 'completed' && orderStatus != 'cancelled';

  /// Called once checkout payment completes. Simulates the Orders doc
  /// getting created — from here on, `hasActiveOrder` is true and
  /// re-entering checkout should skip payment.
  void startOrder() {
    orderId = 'ORDER_${DateTime.now().millisecondsSinceEpoch}';
    orderDate = DateTime.now();
    orderStatus = 'awaiting_confirmation';
    tailorJobId = null;
    tailorId = null;
    tailorJobStatus = 'pending';
    tailorSelectionDeadline = null;
    quoteAmount = null;
    estimatedDeliveryDate = null;
    rejectionReason = null;
  }

  void setSkippedTailoring() {
    orderStatus = 'processing';
  }

  void setAwaitingTailorSearch(DateTime deadline) {
    orderStatus = 'awaiting_tailor_search';
    tailorSelectionDeadline = deadline;
  }

  void createTailorJob({required String tailorId}) {
    tailorJobId = 'JOB_${DateTime.now().millisecondsSinceEpoch}';
    this.tailorId = tailorId;
    tailorJobStatus = 'pending';
    tailorJobRequestedAt = DateTime.now();
    orderStatus = 'tailor_pending';
  }

  void setTailorConfirmed({required double amount, required DateTime estimatedDelivery}) {
    tailorJobStatus = 'confirmed';
    quoteAmount = amount;
    estimatedDeliveryDate = estimatedDelivery;
  }

  void setTailorRejected(String reason) {
    tailorJobStatus = 'rejected';
    rejectionReason = reason;
  }

  void setTailorSearchExpired() {
    tailorJobStatus = 'expired';
    orderStatus = 'processing';
  }

  void completeOrder() {
    orderStatus = 'completed';
  }

  void cancelTailorJob() {
    tailorJobId = null;
    tailorId = null;
    tailorJobStatus = 'pending';
    quoteAmount = null;
    estimatedDeliveryDate = null;
    rejectionReason = null;
  }

  /// Fully clears session state — call after an order reaches a terminal
  /// state and the customer has acknowledged it (e.g. closes the "Order
  /// Confirmed" dialog), so the next checkout starts a brand-new order.
  void reset() {
    orderId = null;
    orderStatus = 'awaiting_confirmation';
    orderDate = null;
    tailorSelectionDeadline = null;
    tailorJobId = null;
    tailorId = null;
    tailorJobStatus = 'pending';
    tailorJobRequestedAt = null;
    quoteAmount = null;
    estimatedDeliveryDate = null;
    rejectionReason = null;
  }
}
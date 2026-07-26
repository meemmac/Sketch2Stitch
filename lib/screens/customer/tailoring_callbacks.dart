import 'order_session.dart';
import 'tailoring_setup_screen.dart';

/// Builds the backend-sync callbacks for a specific order. Every callback
/// closes over `orderId`, so `TailoringSetupScreen` never needs to know
/// about `OrderStore` directly — it only reports what happened.
///
/// One tailor job per ORDER (not per sub-order) — matches the Tailor-jobs
/// schema, which has an orderId field but no subOrderId field.
TailoringSetupCallbacks buildTailoringCallbacks(String orderId) {
  final store = OrderStore.instance;

  return TailoringSetupCallbacks(
    onSkipTailoring: () async {
      store.setSkippedTailoring(orderId);
    },
    onContinueToTailor: (deadline) async {
      store.setAwaitingTailorSearch(orderId, deadline);
    },
    onCreateTailorJob: ({
      required String measurementId,
      required List<String> designIds,
      required String tailorId,
      required String instructions,
    }) async {
      final job = store.createTailorJob(
        orderId: orderId,
        tailorId: tailorId,
        measurementId: measurementId,
        designIds: designIds,
        specialInstructions: instructions,
      );
      return job.tailorJobId;
    },
    onConfirmTailorJob: ({
      required double quoteAmount,
      required DateTime estimatedDeliveryDate,
      double deliverCharge = 0,
    }) async {
      // Both quoteAmount and estimatedDeliveryDate are required params on
      // the store method itself, so this can't be called without a real
      // price and delivery estimate — see order_session.dart.
      store.confirmTailorJob(
        orderId,
        quoteAmount: quoteAmount,
        estimatedDeliveryDate: estimatedDeliveryDate,
        deliverCharge: deliverCharge,
      );
    },
    onRejectTailorJob: (reason) async {
      // NOTE: previously the screen mutated local state directly on
      // rejection with no backend call at all — this callback closes
      // that gap so a reject actually reaches the store.
      store.rejectTailorJob(orderId, reason);
    },
    onPayTailor: () async {
      // No tailorJobId param needed — there's exactly one job per order
      // now, so the store already knows which job this order's payment
      // applies to.
      store.payTailorJob(orderId);
    },
    onTailorSearchExpired: () async {
      store.expireTailorSearch(orderId);
    },
    onFetchResumeState: () async {
      final order = store.get(orderId);
      if (order == null) return null;
      final job = order.tailorJob;

      return OrderResumeState(
        tailorSelectionDeadline: order.tailorSelectionDeadline,
        tailorJobId: job?.tailorJobId,
        tailorId: job?.tailorId,
        status: job?.status,
        requestedAt: job?.requestedAt,
        quoteAmount: job?.quoteAmount,
        deliverCharge: job?.deliverCharge,
        estimatedDeliveryDate: job?.estimatedDeliveryDate,
        rejectionReason: job?.rejectionReason,
      );
    },
  );
}
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
    onConfirmTailorJob: () async {
      // No values passed in — the customer is accepting whatever the
      // tailor already quoted via submitTailorQuote(), not supplying
      // their own numbers. The store reads quoteAmount /
      // estimatedDeliveryDate straight off the existing job.
      store.confirmTailorJob(orderId);
    },
    onRejectTailorJob: () async {
      // No reason required — the customer can simply decline a quote
      // without justifying it.
      store.rejectTailorJob(orderId);
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
        // rejectionReason removed — no longer collected.
      );
    },
  );
}
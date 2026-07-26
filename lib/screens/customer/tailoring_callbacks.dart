import 'order_session.dart';
import 'tailoring_setup_screen.dart';

/// Builds the backend-sync callbacks for a specific order. Every callback
/// closes over `orderId`, so `TailoringSetupScreen` never needs to know
/// about `OrderStore` directly — it only reports what happened.
///
/// One tailor job per ORDER (not per sub-order) — matches the Tailor-jobs
/// schema, which has an orderId field but no subOrderId field.
///
/// Matches the "tailor submits quote" workflow: the TAILOR calls
/// OrderStore.submitTailorQuote() from their own screen to set
/// quoteAmount / estimatedDeliveryDate / deliverCharge on the job. The
/// CUSTOMER only ever accepts or declines what's already there — neither
/// onConfirmTailorJob nor onRejectTailorJob takes any values from the
/// customer anymore.
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
      // No values passed in — the tailor already submitted quoteAmount /
      // estimatedDeliveryDate / deliverCharge via submitTailorQuote() on
      // their own screen. The customer is only locking in what's already
      // on the job; confirmTailorJob(orderId) reads it straight off.
      store.confirmTailorJob(orderId);
    },
    onRejectTailorJob: () async {
      // No reason required — the customer can simply decline the
      // tailor's quote without justifying it.
      store.rejectTailorJob(orderId);
    },
   onPayTailor: () async {
      // No-op now — OrderStore.confirmTailorJob() sets payment to 'paid'
      // and completes the order atomically. This callback stays wired
      // in case any code path still calls it, but there's nothing left
      // for it to do against the store.
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
        tailorPaymentStatus: job?.tailorPaymentStatus, // NEW
      );
    },
  );
}



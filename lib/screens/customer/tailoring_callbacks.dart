import '../../services/tailoring_service.dart';
import '../../services/user_session.dart';
import 'tailoring_setup_screen.dart';

/// Builds the backend-sync callbacks for a specific order. Every callback
/// closes over `orderId`, so `TailoringSetupScreen` never needs to know
/// about Firestore directly — it only reports what happened.
///
/// One tailor job per ORDER (not per sub-order) — matches the Tailor-jobs
/// schema, which has an orderId field but no subOrderId field.
///
/// Matches the "tailor submits quote" workflow: the TAILOR calls
/// TailorService.submitQuote() from their own screen to set
/// quoteAmount / estimatedDeliveryDate / deliveryCharge on the job. The
/// CUSTOMER only ever accepts or declines what's already there — neither
/// onConfirmTailorJob nor onRejectTailorJob takes any values from the
/// customer.
TailoringSetupCallbacks buildTailoringCallbacks(
  String orderId, {
  TailoringService? service,
}) {
  final backend = service ?? TailoringService();

  return TailoringSetupCallbacks(
    onSkipTailoring: () => backend.skipTailoring(orderId),

    onContinueToTailor: (deadline) =>
        backend.startTailorSearch(orderId, deadline),

    onCreateTailorJob: ({
      required String measurementId,
      required List<String> designIds,
      required String tailorId,
      required String instructions,
    }) async {
      // The screen hands over on-device file paths, not ids — gallery picks
      // and sketch-board exports are both just files at this point. They
      // have to reach Cloudinary and get `Design` documents before the
      // tailor, on a different device, can open any of them.
      final customerId = UserSession.instance.uid;
      final uploadedIds = customerId == null || designIds.isEmpty
          ? <String>[]
          : await backend.uploadDesigns(
              customerId: customerId,
              localPaths: designIds,
              description: instructions,
            );

      return backend.createTailorJob(
        orderId: orderId,
        tailorId: tailorId,
        measurementId: measurementId,
        designIds: uploadedIds,
        instructions: instructions,
      );
    },

    // No values passed in — the tailor already submitted quoteAmount /
    // estimatedDeliveryDate / deliveryCharge via submitQuote() on their
    // own screen. The customer is only locking in what's already on the
    // job, and confirmTailorJob re-reads it inside a transaction so a
    // withdrawn or never-quoted job can't be accepted from stale state.
    onConfirmTailorJob: () => backend.confirmTailorJob(orderId),

    // No reason required — the customer can simply decline the tailor's
    // quote without justifying it.
    onRejectTailorJob: () => backend.rejectTailorJob(orderId),

    // No-op — confirmTailorJob() marks the job paid and writes the
    // tailor's Payments row atomically with the confirmation, since the
    // bKash charge has already cleared by the time either runs. This
    // callback stays wired because the screen still calls it.
    onPayTailor: () async {},

    onTailorSearchExpired: () => backend.expireTailorSearch(orderId),

    onFetchResumeState: () async {
      final state = await backend.fetchResumeState(orderId);
      if (state == null) return null;

      return OrderResumeState(
        tailorSelectionDeadline: state['tailorSelectionDeadline'],
        tailorJobId: state['tailorJobId'],
        tailorId: state['tailorId'],
        status: state['status'],
        requestedAt: state['requestedAt'],
        quoteAmount: state['quoteAmount'],
        deliverCharge: state['deliverCharge'],
        estimatedDeliveryDate: state['estimatedDeliveryDate'],
        rejectionReason: state['rejectionReason'],
        tailorPaymentStatus: state['tailorPaymentStatus'],
      );
    },
  );
}

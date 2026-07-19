import 'order_session.dart';
import 'tailoring_setup_screen.dart';

TailoringSetupCallbacks buildTailoringCallbacks() {
  final session = OrderSession.instance;

  return TailoringSetupCallbacks(
    onSkipTailoring: () async {
      session.setSkippedTailoring();
    },
    onContinueToTailor: (deadline) async {
      session.setAwaitingTailorSearch(deadline);
    },
    onCreateTailorJob: ({
      required measurementId,
      required designIds,
      required tailorId,
    }) async {
      session.createTailorJob(tailorId: tailorId);
      return session.tailorJobId!;
    },
    onPayTailor: (tailorJobId) async {
      session.completeOrder();
    },
    onTailorSearchExpired: () async {
      session.setTailorSearchExpired();
    },
    onFetchResumeState: () async {
      if (session.orderId == null) return null;
      if (session.tailorJobId == null) return null; // no job yet — let screen start at step 0/local progress
      return OrderResumeState(
        tailorSelectionDeadline: session.tailorSelectionDeadline,
        tailorJobId: session.tailorJobId,
        tailorId: session.tailorId,
        status: session.tailorJobStatus,
        requestedAt: session.tailorJobRequestedAt,
        quoteAmount: session.quoteAmount,
        estimatedDeliveryDate: session.estimatedDeliveryDate,
        rejectionReason: session.rejectionReason,
      );
    },
  );
}
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';

/// Thrown by [VirtualTrialService] with a user-friendly message so callers
/// can surface `e.message` directly without knowing Firestore error codes.
class VirtualTrialServiceException implements Exception {
  const VirtualTrialServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Result returned by [VirtualTrialService.checkVTEligibility].
class VTEligibilityResult {
  /// Whether the customer may run another virtual trial right now.
  final bool eligible;

  /// How many trials remain in the current month.
  final int remaining;

  /// Total monthly allowance (mirrors [kVirtualTrialMonthlyLimit]).
  final int limit;

  /// How many trials have been used this month.
  final int used;

  const VTEligibilityResult({
    required this.eligible,
    required this.remaining,
    required this.limit,
    required this.used,
  });
}

/// Wraps all Firestore operations needed by the Virtual Trial feature.
///
/// Collections touched:
///   - `Customer`  — `vtUsed`, `vtResetDate` fields.
class VirtualTrialService {
  VirtualTrialService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _customers = 'Customer';

  // ── getVirtualTrialUsage ───────────────────────────────────────────────────

  /// Returns the current VT usage snapshot for [customerId].
  ///
  /// The returned [Customer] contains the up-to-date `vtUsed` and
  /// `vtResetDate` fields. Use [Customer.vtRemaining] and
  /// [Customer.vtLimitReached] for derived state.
  Future<Customer> getVirtualTrialUsage(String customerId) async {
    try {
      final snap = await _db.collection(_customers).doc(customerId).get();

      if (!snap.exists) {
        throw VirtualTrialServiceException(
          'Customer "$customerId" not found.',
        );
      }

      return Customer.fromJson({...snap.data()!, 'id': snap.id});
    } on VirtualTrialServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw VirtualTrialServiceException(
        'Failed to fetch virtual trial usage: ${e.message ?? e.code}',
      );
    }
  }

  // ── checkVTEligibility ─────────────────────────────────────────────────────

  /// Checks whether [customerId] is allowed to run another virtual trial.
  ///
  /// Eligibility is granted when `vtUsed < kVirtualTrialMonthlyLimit`.
  /// The monthly window is tracked via `vtResetDate`; if that date is in the
  /// past the counter is treated as 0 for the purpose of this read-only check
  /// (call [resetVTUsageIfExpired] to actually persist the reset).
  Future<VTEligibilityResult> checkVTEligibility(String customerId) async {
    try {
      final customer = await getVirtualTrialUsage(customerId);

      // If the reset date has passed, treat the counter as 0 for this check.
      final now = DateTime.now();
      final effectiveUsed =
          (customer.vtResetDate != null && customer.vtResetDate!.isBefore(now))
              ? 0
              : customer.vtUsed;

      final remaining =
          (kVirtualTrialMonthlyLimit - effectiveUsed)
              .clamp(0, kVirtualTrialMonthlyLimit);

      return VTEligibilityResult(
        eligible: effectiveUsed < kVirtualTrialMonthlyLimit,
        remaining: remaining,
        limit: kVirtualTrialMonthlyLimit,
        used: effectiveUsed,
      );
    } on VirtualTrialServiceException {
      rethrow;
    }
  }

  // ── incrementVTUsage ───────────────────────────────────────────────────────

  /// Atomically increments `vtUsed` by 1 for [customerId].
  ///
  /// Also initialises `vtResetDate` to one month from now if it is not already
  /// set, so the first use starts the monthly window.
  ///
  /// Returns the updated [Customer].
  Future<Customer> incrementVTUsage(String customerId) async {
    try {
      final ref = _db.collection(_customers).doc(customerId);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);

        if (!snap.exists) {
          throw VirtualTrialServiceException(
            'Customer "$customerId" not found.',
          );
        }

        final existingReset = snap.data()?['vtResetDate'] as Timestamp?;
        final now = DateTime.now();

        final updates = <String, dynamic>{};

        if (existingReset == null) {
          // Very first use — start the monthly window.
          updates['vtUsed'] = FieldValue.increment(1);
          updates['vtResetDate'] =
              Timestamp.fromDate(now.add(const Duration(days: 30)));
        } else if (existingReset.toDate().isBefore(now)) {
          // The window lapsed between the eligibility check and here (it can
          // lapse while the screen is open). checkVTEligibility already treats
          // the counter as 0 in that case, so rolling it over here is what
          // keeps the two from disagreeing — incrementing the stale count
          // would push vtUsed past the limit on a trial that was allowed.
          updates['vtUsed'] = 1;
          updates['vtResetDate'] =
              Timestamp.fromDate(now.add(const Duration(days: 30)));
        } else {
          updates['vtUsed'] = FieldValue.increment(1);
        }

        tx.update(ref, updates);
      });

      final snap = await ref.get();
      return Customer.fromJson({...snap.data()!, 'id': snap.id});
    } on VirtualTrialServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw VirtualTrialServiceException(
        'Failed to increment virtual trial usage: ${e.message ?? e.code}',
      );
    }
  }

  // ── resetVTUsageIfExpired ──────────────────────────────────────────────────

  /// Resets `vtUsed` to 0 and advances `vtResetDate` by 30 days **only if**
  /// the current `vtResetDate` is in the past (i.e. the monthly window has
  /// elapsed). Does nothing if the window is still active.
  ///
  /// Returns the (potentially updated) [Customer].
  Future<Customer> resetVTUsageIfExpired(String customerId) async {
    try {
      final ref = _db.collection(_customers).doc(customerId);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);

        if (!snap.exists) {
          throw VirtualTrialServiceException(
            'Customer "$customerId" not found.',
          );
        }

        final resetTs = snap.data()?['vtResetDate'];
        if (resetTs == null) return; // No window started yet — nothing to reset.

        final resetDate = (resetTs as Timestamp).toDate();
        if (!resetDate.isBefore(DateTime.now())) return; // Window still active.

        tx.update(ref, {
          'vtUsed': 0,
          'vtResetDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
        });
      });

      final snap = await ref.get();
      return Customer.fromJson({...snap.data()!, 'id': snap.id});
    } on VirtualTrialServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw VirtualTrialServiceException(
        'Failed to reset virtual trial usage: ${e.message ?? e.code}',
      );
    }
  }
}

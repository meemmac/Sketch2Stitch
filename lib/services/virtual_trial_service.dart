import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';
import '../models/product.dart';

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

/// Result returned by [VirtualTrialService.getProductForVirtualTrial].
class VTProductResult {
  /// The requested product.
  final Product product;

  /// The specific colour/variant option requested for the trial.
  /// `null` when the [optionId] was not found among the product's options.
  final ColorOption? selectedOption;

  const VTProductResult({required this.product, this.selectedOption});
}

/// Wraps all Firestore operations needed by the Virtual Trial feature.
///
/// Collections touched:
///   - `Customer`  — `vtUsed`, `vtResetDate` fields.
///   - `Products`  — product data + colour options.
class VirtualTrialService {
  VirtualTrialService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _customers = 'Customer';
  static const _products = 'Products';

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

        final existingReset = snap.data()?['vtResetDate'];

        final updates = <String, dynamic>{
          'vtUsed': FieldValue.increment(1),
        };

        // Initialise the reset date on the very first use.
        if (existingReset == null) {
          final nextMonth = DateTime.now().add(const Duration(days: 30));
          updates['vtResetDate'] = Timestamp.fromDate(nextMonth);
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

  // ── getProductForVirtualTrial ──────────────────────────────────────────────

  /// Fetches the [Product] by [productId] and resolves the specific
  /// [ColorOption] matching [optionId].
  ///
  /// The returned [VTProductResult.selectedOption] is `null` when [optionId]
  /// does not match any option on the product (caller should validate before
  /// launching the trial).
  Future<VTProductResult> getProductForVirtualTrial(
    String productId,
    int optionId,
  ) async {
    try {
      final snap = await _db.collection(_products).doc(productId).get();

      if (!snap.exists) {
        throw VirtualTrialServiceException(
          'Product "$productId" not found.',
        );
      }

      final product = Product.fromJson({...snap.data()!, 'id': snap.id});

      final selectedOption = product.colorOptions
          .cast<ColorOption?>()
          .firstWhere(
            (o) => o?.optionId == optionId,
            orElse: () => null,
          );

      return VTProductResult(product: product, selectedOption: selectedOption);
    } on VirtualTrialServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw VirtualTrialServiceException(
        'Failed to fetch product for virtual trial: ${e.message ?? e.code}',
      );
    }
  }
}

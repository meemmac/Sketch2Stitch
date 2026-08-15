import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/design.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/sub_order.dart';
import '../models/tailor_job.dart';
import 'Cloudinary_service.dart';

class TailoringServiceException implements Exception {
  final String message;
  const TailoringServiceException(this.message);
  @override
  String toString() => message;
}

/// Backend for the post-checkout tailoring stage (`TailoringSetupScreen`).
///
/// Owns every write that moves an order through the tailoring funnel:
/// skip → awaiting_tailor_search → tailor_pending → completed, plus the
/// single `Tailor-jobs` document that covers the whole order (the schema
/// has `orderId` but no `subOrderId` — one tailor per order, not one per
/// retailer).
///
/// This replaces the in-memory `OrderStore` singleton that
/// `buildTailoringCallbacks` used to close over: that store lost every
/// order on app restart and was invisible to the tailor's own screens,
/// so a job the customer created could never actually be quoted.
class TailoringService {
  TailoringService({FirebaseFirestore? firestore, CloudinaryService? cloudinary})
      : _db = firestore ?? FirebaseFirestore.instance,
        _cloudinary = cloudinary ?? CloudinaryService();

  final FirebaseFirestore _db;
  final CloudinaryService _cloudinary;

  static const _orders = 'Orders';
  static const _subOrders = 'Sub-orders';
  static const _tailorJobs = 'Tailor-jobs';
  static const _payments = 'Payments';
  static const _designs = 'Design';

  // ─── Reads ──────────────────────────────────────────────────────────

  /// The one tailor job for this order, or null if none has been created.
  ///
  /// Ordered by `requestedAt` so that if a customer was rejected/declined
  /// and requested a second tailor, the most recent job wins. Kept as a
  /// query rather than a doc-id lookup because `Tailor-jobs` ids are
  /// Firestore-generated, not derived from the order id.
  Future<DocumentSnapshot<Map<String, dynamic>>?> _latestJobSnap(
    String orderId,
  ) async {
    final snap = await _db
        .collection(_tailorJobs)
        .where('orderId', isEqualTo: orderId)
        .get();
    if (snap.docs.isEmpty) return null;

    final docs = [...snap.docs]..sort((a, b) {
        final ad = _toDate(a.data()['requestedAt']);
        final bd = _toDate(b.data()['requestedAt']);
        if (ad == null || bd == null) return 0;
        return bd.compareTo(ad);
      });
    return docs.first;
  }

  /// Rehydrates `TailoringSetupScreen` after the customer leaves and comes
  /// back — the deadline from `Orders` plus whatever state the tailor has
  /// since put on the job (a quote, a decline).
  Future<Map<String, dynamic>?> fetchResumeState(String orderId) async {
    try {
      final orderSnap = await _db.collection(_orders).doc(orderId).get();
      if (!orderSnap.exists) return null;

      final jobSnap = await _latestJobSnap(orderId);
      final job = jobSnap?.data();

      return {
        'tailorSelectionDeadline':
            _toDate(orderSnap.data()?['tailorSelectionDeadline']),
        'tailorJobId': jobSnap?.id,
        'tailorId': job?['tailorId'] as String?,
        'status': job?['status'] as String?,
        'requestedAt': _toDate(job?['requestedAt']),
        'quoteAmount': (job?['quoteAmount'] as num?)?.toDouble(),
        'deliverCharge': (job?['deliveryCharge'] as num?)?.toDouble(),
        'estimatedDeliveryDate': _toDate(job?['estimatedDeliveryDate']),
        'rejectionReason': job?['rejectionReason'] as String?,
        'tailorPaymentStatus': job?['tailorPaymentStatus'] as String?,
      };
    } catch (e) {
      debugPrint('[TailoringService] fetchResumeState failed: $e');
      rethrow;
    }
  }

  // ─── Step 1: tailoring yes/no ───────────────────────────────────────

  /// Customer wants the fabric shipped straight to them — no tailor.
  /// Terminal: `processing` means every sub-order goes direct-to-customer.
  Future<void> skipTailoring(String orderId) async {
    final batch = _db.batch();
    batch.update(_db.collection(_orders).doc(orderId), {
      'status': OrderStatus.processing.toValue,
    });
    await _applyDeliveryDestination(
      batch,
      orderId,
      SubOrderDeliveryDestination.customer,
    );
    await _commit(batch, 'skipTailoring');
  }

  /// Customer wants a tailor — opens the 72h selection window that
  /// `TailoringSetupScreen` counts down against.
  Future<void> startTailorSearch(String orderId, DateTime deadline) async {
    await _update(orderId, {
      'status': OrderStatus.awaitingTailorSearch.toValue,
      'tailorSelectionDeadline': Timestamp.fromDate(deadline),
    }, 'startTailorSearch');
  }

  /// The selection window closed with nothing confirmed — fall back to
  /// direct delivery and mark any dangling job expired.
  Future<void> expireTailorSearch(String orderId) async {
    final batch = _db.batch();
    batch.update(_db.collection(_orders).doc(orderId), {
      'status': OrderStatus.processing.toValue,
    });

    final job = await _latestJobSnap(orderId);
    if (job != null) {
      batch.update(job.reference, {
        'status': TailorJobStatus.expired.toValue,
        'quoteStatus': QuoteStatus.expired.toValue,
      });
    }
    await _applyDeliveryDestination(
      batch,
      orderId,
      SubOrderDeliveryDestination.customer,
    );
    await _commit(batch, 'expireTailorSearch');
  }

  // ─── Step 4: the tailor job ─────────────────────────────────────────

  /// Uploads locally-captured design images (gallery picks and sketch-board
  /// exports are both just files on disk by this point) to Cloudinary and
  /// writes one `Design` document per image.
  ///
  /// Returns the created design ids, which go onto the tailor job. Without
  /// this the job would carry raw on-device file paths that mean nothing to
  /// the tailor's device.
  Future<List<String>> uploadDesigns({
    required String customerId,
    required List<String> localPaths,
    String description = '',
  }) async {
    final ids = <String>[];
    for (final path in localPaths) {
      final file = File(path);
      if (!file.existsSync()) {
        debugPrint('[TailoringService] skipping missing design file: $path');
        continue;
      }

      final url = await _cloudinary.uploadImage(file, folder: 'designs');
      if (url == null) {
        throw const TailoringServiceException(
          'Could not upload your design images. Please try again.',
        );
      }

      final ref = _db.collection(_designs).doc();
      await ref.set(
        Design(
          id: ref.id,
          customerId: customerId,
          designFile: url,
          description: description,
        ).toJson(),
      );
      ids.add(ref.id);
    }
    return ids;
  }

  /// Creates the ONE job for this order and flips the order to
  /// `tailor_pending`. Starts at `pending`/`not_sent` — there is nothing
  /// for the customer to confirm until the tailor calls
  /// `TailorService.submitQuote`.
  Future<String> createTailorJob({
    required String orderId,
    required String tailorId,
    required String measurementId,
    List<String> designIds = const [],
    String instructions = '',
  }) async {
    try {
      final ref = _db.collection(_tailorJobs).doc();
      final job = TailorJob(
        id: ref.id,
        orderId: orderId,
        tailorId: tailorId,
        measurementId: measurementId,
        designIds: designIds,
        specialInstructions: instructions,
        status: TailorJobStatus.pending,
        requestedAt: DateTime.now(),
        createdAt: DateTime.now(),
        quoteStatus: QuoteStatus.notSent,
        tailorPaymentStatus: TailorPaymentStatus.unpaid,
      );

      final batch = _db.batch();
      batch.set(ref, job.toJson());
      batch.update(_db.collection(_orders).doc(orderId), {
        'status': OrderStatus.tailorPending.toValue,
      });
      // The fabric now ships to the tailor, not the customer — this is the
      // decision Sub-orders.deliveryDestination was left 'pending' for at
      // checkout time.
      await _applyDeliveryDestination(
        batch,
        orderId,
        SubOrderDeliveryDestination.tailor,
      );
      await _commit(batch, 'createTailorJob');

      return ref.id;
    } on TailoringServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[TailoringService] createTailorJob failed: $e');
      throw const TailoringServiceException(
        'Could not send your request to this tailor. Please try again.',
      );
    }
  }

  /// Customer accepts the tailor's quote. Confirm and pay are atomic in
  /// this flow — the bKash charge has already gone through on the screen
  /// by the time this runs, so the job goes straight to confirmed + paid,
  /// the order completes, and the tailor's `Payments` row is written in
  /// the same transaction.
  ///
  /// Runs as a transaction so a job that the tailor withdrew, or that was
  /// never actually quoted, can't be confirmed against stale screen state.
  Future<void> confirmTailorJob(
    String orderId, {
    String? transactionId,
  }) async {
    final jobSnap = await _latestJobSnap(orderId);
    if (jobSnap == null) {
      throw const TailoringServiceException('This order has no tailor job.');
    }

    try {
      await _db.runTransaction((tx) async {
        final fresh = await tx.get(jobSnap.reference);
        final data = fresh.data();
        if (data == null) {
          throw const TailoringServiceException('This tailor job no longer exists.');
        }

        final quoteAmount = (data['quoteAmount'] as num?)?.toDouble();
        final deliveryCharge = (data['deliveryCharge'] as num?)?.toDouble() ?? 0;
        final eta = _toDate(data['estimatedDeliveryDate']);
        if (quoteAmount == null || eta == null) {
          throw const TailoringServiceException(
            'This tailor has not sent a quote yet.',
          );
        }

        final status = TailorJobStatus.fromValue(data['status'] as String? ?? '');
        if (status != TailorJobStatus.quoted) {
          throw TailoringServiceException(
            'This quote can no longer be accepted (${TailorJob.fromJson({...data, 'status': status.toValue}).statusText}).',
          );
        }

        tx.update(jobSnap.reference, {
          'status': TailorJobStatus.confirmed.toValue,
          'quoteStatus': QuoteStatus.accepted.toValue,
          'tailorPaymentStatus': TailorPaymentStatus.paid.toValue,
          'confirmedAt': Timestamp.now(),
        });

        tx.update(_db.collection(_orders).doc(orderId), {
          'status': OrderStatus.completed.toValue,
        });

        // Payments.targetType admits 'retailer' or 'tailor'; the retailer
        // rows were written at checkout, this is the tailor's.
        tx.set(_db.collection(_payments).doc(), {
          'orderId': orderId,
          'method': PaymentMethod.mobileBanking.toValue,
          'amount': quoteAmount + deliveryCharge,
          'itemsAmount': quoteAmount,
          'deliveryAmount': deliveryCharge,
          'targetType': PaymentTargetType.tailor.toValue,
          'targetId': data['tailorId'],
          'transactionId': transactionId,
          'date': Timestamp.now(),
          'status': PaymentStatus.completed.toValue,
        });
      });
    } on TailoringServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[TailoringService] confirmTailorJob failed: $e');
      throw const TailoringServiceException(
        'Could not confirm the tailor. Please try again.',
      );
    }
  }

  /// Customer declines the quote. No reason is collected — this is a plain
  /// "no thanks", not a justified decision. The order stays active in
  /// `tailor_pending` so they can browse another tailor before the
  /// selection deadline runs out.
  Future<void> rejectTailorJob(String orderId) async {
    final jobSnap = await _latestJobSnap(orderId);
    if (jobSnap == null) return;
    try {
      await jobSnap.reference.update({
        'status': TailorJobStatus.rejected.toValue,
      });
    } catch (e) {
      debugPrint('[TailoringService] rejectTailorJob failed: $e');
      throw const TailoringServiceException(
        'Could not decline this quote. Please try again.',
      );
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  /// Points every sub-order in this order at its final destination. Left
  /// as 'pending' by `CheckoutService.placeOrder`, because at payment time
  /// nobody knows yet whether a tailor is involved.
  Future<void> _applyDeliveryDestination(
    WriteBatch batch,
    String orderId,
    SubOrderDeliveryDestination destination,
  ) async {
    final subs = await _db
        .collection(_subOrders)
        .where('orderId', isEqualTo: orderId)
        .get();
    for (final doc in subs.docs) {
      batch.update(doc.reference, {'deliveryDestination': destination.name});
    }
  }

  Future<void> _update(
    String orderId,
    Map<String, dynamic> data,
    String op,
  ) async {
    try {
      await _db.collection(_orders).doc(orderId).update(data);
    } catch (e) {
      debugPrint('[TailoringService] $op failed: $e');
      throw const TailoringServiceException(
        'Could not update your order. Please try again.',
      );
    }
  }

  Future<void> _commit(WriteBatch batch, String op) async {
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('[TailoringService] $op failed: $e');
      throw const TailoringServiceException(
        'Could not update your order. Please try again.',
      );
    }
  }

  /// `Tailor-jobs` holds dates in two shapes: `TailorJob.toJson` writes ISO
  /// strings, while `TailorService.submitQuote` writes a `Timestamp`. Reads
  /// here have to survive both.
  static DateTime? _toDate(Object? v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

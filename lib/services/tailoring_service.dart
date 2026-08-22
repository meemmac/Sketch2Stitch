import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/design.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/sub_order.dart';
import '../models/tailor_job.dart';
import 'Cloudinary_service.dart';
import '../utils/geo_utils.dart';
import 'browse_service.dart';
import 'notification_service.dart';

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

  /// How long the customer gets, from the moment the order is placed, to
  /// end up with a confirmed-and-paid tailor. When it runs out the order
  /// falls back to direct retailer → customer delivery, whatever stage the
  /// tailoring decision had reached. Written onto
  /// `Orders.tailorSelectionDeadline` by `CheckoutService.placeOrder`.
  static const Duration tailorSelectionWindow = Duration(hours: 72);

  /// How long a tailor gets to answer a request with a quote. Written onto
  /// `Tailor-jobs.quoteResponseDeadline` when the job is created. Running
  /// out frees the customer to hire someone else — it does NOT end their
  /// [tailorSelectionWindow], which keeps running underneath.
  static const Duration tailorQuoteWindow = Duration(hours: 12);

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
        // The screen needs the ORDER status too: a job can read 'expired'
        // for two different reasons — the tailor let the 12h quote window
        // lapse (order back to awaiting_tailor_search, customer picks
        // someone else) or the 72h selection window closed (order moved to
        // processing, direct delivery). Only the order tells them apart.
        'orderStatus': orderSnap.data()?['status'] as String?,
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
        'quoteResponseDeadline': _toDate(job?['quoteResponseDeadline']),
      };
    } catch (e) {
      debugPrint('[TailoringService] fetchResumeState failed: $e');
      rethrow;
    }
  }

  /// Live version of [fetchResumeState].
  ///
  /// `TailoringSetupScreen` used to re-run the fetch on a 20-second timer,
  /// which meant a quote could sit unseen for most of a minute while the
  /// screen burned two reads per tick doing nothing. Both documents it
  /// depends on are ordinary Firestore documents, so a snapshot listener
  /// costs no more and delivers the moment the tailor writes.
  ///
  /// Two sources have to be merged: the quote lands on `Tailor-jobs`, the
  /// deadline and order status on `Orders`. Either changing re-reads the
  /// pair — a couple of reads per actual change, versus per tick.
  Stream<Map<String, dynamic>?> streamResumeState(String orderId) {
    final controller = StreamController<Map<String, dynamic>?>();
    StreamSubscription? orderSub;
    StreamSubscription? jobSub;
    var inFlight = false;
    var again = false;

    Future<void> emit() async {
      // Collapse overlapping refreshes: the two listeners usually fire back
      // to back for the same write (a batch touches both documents).
      if (inFlight) {
        again = true;
        return;
      }
      inFlight = true;
      try {
        do {
          again = false;
          final state = await fetchResumeState(orderId);
          if (controller.isClosed) return;
          controller.add(state);
        } while (again);
      } catch (e) {
        debugPrint('[TailoringService] streamResumeState refresh failed: $e');
      } finally {
        inFlight = false;
      }
    }

    controller.onListen = () {
      orderSub =
          _db.collection(_orders).doc(orderId).snapshots().listen((_) => emit());
      jobSub = _db
          .collection(_tailorJobs)
          .where('orderId', isEqualTo: orderId)
          .snapshots()
          .listen((_) => emit());
    };
    controller.onCancel = () async {
      await orderSub?.cancel();
      await jobSub?.cancel();
    };

    return controller.stream;
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

  /// The tailor let their 12h response window lapse without quoting.
  ///
  /// Unlike [expireTailorSearch] this does NOT end the customer's tailoring
  /// attempt: the job dies, the fabric stops being routed to that tailor,
  /// and the order goes back to `awaiting_tailor_search` so another tailor
  /// can be hired inside whatever is left of the 72h selection window.
  /// Same shape as a tailor declining outright — because that is what a
  /// silent tailor amounts to.
  Future<void> expireQuoteRequest(String orderId) async {
    final job = await _latestJobSnap(orderId);
    if (job == null) return;

    final batch = _db.batch();
    batch.update(job.reference, {
      'status': TailorJobStatus.expired.toValue,
      'quoteStatus': QuoteStatus.expired.toValue,
      'rejectionReason': 'The tailor did not respond in time.',
    });
    batch.update(_db.collection(_orders).doc(orderId), {
      'status': OrderStatus.awaitingTailorSearch.toValue,
    });
    await _applyDeliveryDestination(
      batch,
      orderId,
      SubOrderDeliveryDestination.pending,
    );
    await _commit(batch, 'expireQuoteRequest');
  }

  /// True if [job] is a `pending` request whose 12h quote window has closed.
  static bool _quoteWindowLapsed(Map<String, dynamic>? job) {
    if (job == null) return false;
    if (TailorJobStatus.fromValue(job['status'] as String? ?? '') !=
        TailorJobStatus.pending) {
      return false;
    }
    // Jobs created before quoteResponseDeadline existed fall back to the
    // request time, so they age out on the same rule rather than never.
    final deadline = _toDate(job['quoteResponseDeadline']) ??
        _toDate(job['requestedAt'])?.add(tailorQuoteWindow);
    return deadline != null && DateTime.now().isAfter(deadline);
  }

  /// Settles every selection window of [customerId]'s that closed while the
  /// app was not running. Returns how many orders it expired.
  ///
  /// The countdown in `TailoringSetupScreen` only calls [expireTailorSearch]
  /// while that screen is open, and on the free tier there are no Cloud
  /// Functions to run a scheduled sweep behind it. So a window that ran out
  /// overnight left its order stuck in `awaiting_tailor_search` forever — and
  /// since `Sub-orders.deliveryDestination` stays 'pending' until the
  /// tailoring decision is made, that order's retailers never learned where
  /// to ship either. Running this on app start makes the customer's own
  /// device the scheduler.
  ///
  /// Deliberately scoped to one customer's orders: that is all a customer is
  /// allowed to read, and it keeps the sweep to a single query.
  Future<int> sweepDueTailorSearches(String customerId) async {
    if (customerId.isEmpty) return 0;

    try {
      // Only `customerId` is filtered server-side. Adding the status filter
      // to the query would need a composite index deployed alongside it, and
      // a customer has few enough orders that filtering here is cheaper than
      // the index would be.
      final snap = await _db
          .collection(_orders)
          .where('customerId', isEqualTo: customerId)
          .get();

      // 'awaiting_confirmation' belongs here too: an order sits in it from
      // the moment it is placed until the customer opens the tailoring
      // screen, and until they do nothing else can move — Sub-orders keep a
      // 'pending' destination, so the retailers cannot even ship. The 72h
      // window has to be able to settle that case, not just the ones where
      // the customer already started looking for a tailor.
      const openStatuses = {
        'awaiting_confirmation',
        'awaiting_tailor_search',
        'tailor_pending',
      };

      final now = DateTime.now();
      var expired = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        if (!openStatuses.contains(data['status'])) continue;

        final jobSnap = await _latestJobSnap(doc.id);
        final job = jobSnap?.data();

        // A job the customer already paid for is settled — neither window
        // applies to it any more.
        final jobStatus =
            TailorJobStatus.fromValue(job?['status'] as String? ?? '');
        if (job != null &&
            (jobStatus == TailorJobStatus.confirmed ||
                jobStatus == TailorJobStatus.inProgress ||
                jobStatus == TailorJobStatus.jobCompleted)) {
          continue;
        }

        // 72h selection window first — it is the terminal one. A quote the
        // customer never answered is NOT exempt: the banner promises that an
        // order with no confirmed tailor ships direct, and exempting
        // 'quoted' left exactly those orders frozen in tailor_pending with
        // no way out.
        final deadline = _toDate(data['tailorSelectionDeadline']);
        if (deadline != null && now.isAfter(deadline)) {
          await expireTailorSearch(doc.id);
          expired++;
          continue;
        }

        // Still inside the 72h window, but this tailor has gone quiet past
        // their 12h — release the customer to hire someone else.
        if (_quoteWindowLapsed(job)) {
          await expireQuoteRequest(doc.id);
          expired++;
        }
      }

      return expired;
    } catch (e) {
      // Never worth blocking a screen load over — the next launch, or opening
      // the order itself, tries again.
      debugPrint('[TailoringService] sweepDueTailorSearches failed: $e');
      return 0;
    }
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
      // Capacity guard. The browse screens already hide tailors who are at
      // their maxOrder, but the customer may be acting on a stale list — or
      // two customers may go for the same last slot at once — so re-check
      // against live data before writing the job.
      await _assertTailorHasCapacity(tailorId);

      // Distance tailor → customer, captured now. The tailor's Accept button
      // prices delivery with CartService.deliveryChargeFor(deliveryDistanceKm),
      // but nothing had ever written that field, so every tailored order fell
      // back to the flat base fee no matter how far apart the two parties were.
      final delivery = await _tailorDeliveryFor(orderId, tailorId);

      final ref = _db.collection(_tailorJobs).doc();
      final requestedAt = DateTime.now();
      final job = TailorJob(
        id: ref.id,
        orderId: orderId,
        tailorId: tailorId,
        measurementId: measurementId,
        designIds: designIds,
        specialInstructions: instructions,
        status: TailorJobStatus.pending,
        requestedAt: requestedAt,
        createdAt: requestedAt,
        // The tailor has [tailorQuoteWindow] to answer with a quote. The
        // field existed on the model from the start but nothing ever set
        // it, so a tailor who simply never opened the app held the
        // customer's order hostage for the whole 72h selection window.
        quoteResponseDeadline: requestedAt.add(tailorQuoteWindow),
        deliveryDistanceKm: delivery.$1,
        deliveryPoint: delivery.$2,
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

      // Best-effort: the tailor has no other way to learn a job is waiting,
      // and the retailers need to know the fabric is now going to a tailor
      // rather than to the customer.
      await _notifyJobRequested(orderId: orderId, tailorId: tailorId);

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
          throw const TailoringServiceException(
            'This quote can no longer be accepted.',
          );
        }

        tx.update(jobSnap.reference, {
          'status': TailorJobStatus.confirmed.toValue,
          'quoteStatus': QuoteStatus.accepted.toValue,
          'tailorPaymentStatus': TailorPaymentStatus.paid.toValue,
          'confirmedAt': Timestamp.now(),
        });

        // The tailor has been paid, but nothing has been stitched yet, so
        // the ORDER is not finished — it moves into 'processing' and only
        // reaches 'completed' when the tailor marks the work done
        // (OrderService.updateWorkProgress). Writing 'completed' here made a
        // brand-new job read as finished, and then go backwards to
        // 'processing' the moment the tailor actually started.
        tx.update(_db.collection(_orders).doc(orderId), {
          'status': OrderStatus.processing.toValue,
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

      // The tailor's screen flips the job from "Pending Customer" to
      // "Ready to Start" on its own stream, but nothing ever told them it
      // had happened — they had to keep the app open to notice they'd been
      // paid and could begin work.
      await _notifyTailorJobConfirmed(
        orderId: orderId,
        tailorId: jobSnap.data()?['tailorId'] as String?,
      );
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
  /// "no thanks", not a justified decision. The order goes back to
  /// `awaiting_tailor_search` so they can browse another tailor before the
  /// selection deadline runs out.
  Future<void> rejectTailorJob(String orderId) async {
    final jobSnap = await _latestJobSnap(orderId);
    if (jobSnap == null) return;
    try {
      final batch = _db.batch();
      batch.update(jobSnap.reference, {
        'status': TailorJobStatus.rejected.toValue,
        'quoteStatus': QuoteStatus.expired.toValue,
      });

      // Symmetry with declineTailorJob(): whoever says no, the fabric stops
      // being bound for that tailor. Leaving it at 'tailor' kept telling
      // every retailer on the order to ship to a tailor whose quote had
      // just been turned down, and leaving the order at 'tailor_pending'
      // implied a decision was still owed to a job that is now dead.
      batch.update(_db.collection(_orders).doc(orderId), {
        'status': OrderStatus.awaitingTailorSearch.toValue,
      });
      await _applyDeliveryDestination(
        batch,
        orderId,
        SubOrderDeliveryDestination.pending,
      );
      await _commit(batch, 'rejectTailorJob');

      // The tailor quoted and is waiting on an answer — tell them it was a
      // no, otherwise the job just goes quiet on their screen forever.
      final tailorId = jobSnap.data()?['tailorId'] as String?;
      if (tailorId != null) {
        await _notifyQuoteRejected(orderId: orderId, tailorId: tailorId);
      }
    } catch (e) {
      debugPrint('[TailoringService] rejectTailorJob failed: $e');
      throw const TailoringServiceException(
        'Could not decline this quote. Please try again.',
      );
    }
  }

  // ─── Notifications ──────────────────────────────────────────────────

  /// Customer's display name, or a neutral fallback. Notification copy only,
  /// so a missing document must not throw.
  Future<String> _customerNameForOrder(String orderId) async {
    try {
      final orderSnap = await _db.collection(_orders).doc(orderId).get();
      final customerId = orderSnap.data()?['customerId'] as String?;
      if (customerId == null) return 'A customer';
      final snap = await _db.collection('Customer').doc(customerId).get();
      final name = (snap.data()?['name'] as String?)?.trim();
      return (name == null || name.isEmpty) ? 'A customer' : name;
    } catch (_) {
      return 'A customer';
    }
  }

  /// Tells the chosen tailor a request is waiting, and tells every retailer
  /// on the order that its fabric is now bound for that tailor.
  ///
  /// Best-effort throughout: the job is already written by the time this
  /// runs, so a notification failure must not fail the request.
  Future<void> _notifyJobRequested({
    required String orderId,
    required String tailorId,
  }) async {
    try {
      final notifications = NotificationService();
      final customerName = await _customerNameForOrder(orderId);

      await notifications.notifyTailorNewOrder(
        tailorId,
        orderId,
        customerName,
        'a custom stitching job',
      );

      final tailorSnap = await _db.collection('Tailor').doc(tailorId).get();
      final tailorName =
          (tailorSnap.data()?['name'] as String?)?.trim().isNotEmpty == true
              ? tailorSnap.data()!['name'] as String
              : 'a tailor';

      final subs = await _db
          .collection(_subOrders)
          .where('orderId', isEqualTo: orderId)
          .get();
      for (final doc in subs.docs) {
        final retailerId = doc.data()['retailerId'] as String?;
        if (retailerId == null) continue;
        await notifications.notifyRetailerTailorAssigned(
          retailerId,
          orderId,
          customerName,
          tailorName,
          DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[TailoringService] job-requested notifications failed: $e');
    }
  }

  /// Tells the tailor their quote was accepted and paid.
  Future<void> _notifyTailorJobConfirmed({
    required String orderId,
    required String? tailorId,
  }) async {
    if (tailorId == null) return;
    try {
      final customerName = await _customerNameForOrder(orderId);
      await NotificationService()
          .notifyTailorJobConfirmed(tailorId, orderId, customerName);
    } catch (e) {
      debugPrint('[TailoringService] job-confirmed notification failed: $e');
    }
  }

  /// Tells the tailor the customer turned their quote down.
  Future<void> _notifyQuoteRejected({
    required String orderId,
    required String tailorId,
  }) async {
    try {
      final customerName = await _customerNameForOrder(orderId);
      await NotificationService().notifyTailorOrderCancelled(
        tailorId,
        orderId,
        customerName,
        'a custom stitching job',
        'The customer declined your quote.',
      );
    } catch (e) {
      debugPrint('[TailoringService] quote-rejected notification failed: $e');
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  /// Throws if [tailorId] has already filled every slot their `maxOrder`
  /// allows. A null `maxOrder` is "Not Set" — unlimited.
  Future<void> _assertTailorHasCapacity(String tailorId) async {
    final snap = await _db.collection('Tailor').doc(tailorId).get();
    final capacity = (snap.data()?['maxOrder'] as num?)?.toInt();
    if (capacity == null) return;

    if (capacity <= 0) {
      throw const TailoringServiceException(
        'This tailor is not accepting new orders right now.',
      );
    }

    final running = await _db
        .collection(_tailorJobs)
        .where('tailorId', isEqualTo: tailorId)
        .where('status', whereIn: BrowseService.runningJobStatuses)
        .get();

    if (running.docs.length >= capacity) {
      throw const TailoringServiceException(
        'This tailor is fully booked right now. Please choose another one.',
      );
    }
  }

  /// Distance from [tailorId] to the customer on [orderId], plus the
  /// customer's coordinates — the finished garment travels tailor →
  /// customer, so that is the leg the delivery charge is priced on.
  ///
  /// Returns `(null, null)` when either party has no pinned location;
  /// `CartService.deliveryChargeFor` already treats a null distance as
  /// "charge the base fee", which is the old behaviour.
  Future<(double?, GeoPoint?)> _tailorDeliveryFor(
    String orderId,
    String tailorId,
  ) async {
    try {
      final orderSnap = await _db.collection(_orders).doc(orderId).get();
      final customerId = orderSnap.data()?['customerId'] as String?;
      if (customerId == null) return (null, null);

      final results = await Future.wait([
        _db.collection('Customer').doc(customerId).get(),
        _db.collection('Tailor').doc(tailorId).get(),
      ]);

      final customerPoint = results[0].data()?['location'];
      final tailorPoint = results[1].data()?['location'];
      if (customerPoint is! GeoPoint) return (null, null);
      if (tailorPoint is! GeoPoint) return (null, customerPoint);

      return (GeoUtils.distanceKm(tailorPoint, customerPoint), customerPoint);
    } catch (e) {
      // Pricing falls back to the base fee — not worth failing the request.
      debugPrint('[TailoringService] delivery distance lookup failed: $e');
      return (null, null);
    }
  }

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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../models/user_role.dart';


class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;


  final FirebaseFirestore _db;
  static const String _collection = 'Notifications';


  // ─── Core Functions ────────────────────────────────────────────────────────


  /// Streams real-time notifications for a specific user.
  Stream<List<AppNotification>> streamNotifications(String uid) {
    final cleanUid = uid.trim();
    
    if (cleanUid.isEmpty) {
      return Stream.value([]);
    }

    // Use a query that finds the ID even if there's a trailing space in the DB
    // Wrapped in a stream to handle database delays on first load
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: cleanUid)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        return AppNotification.fromJson(doc.data(), doc.id);
      }).toList();
      // Sort newest-first client-side. Doing it here rather than with an
      // orderBy avoids requiring a composite index on (userId, createdAt),
      // which the equality filter above would otherwise force.
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  /// Fetches the Cloudinary profile picture URL of the *counterparty* on a
  /// notification — the other party the notification is about, as seen by
  /// [viewerRole].
  ///
  /// Returns null whenever the counterparty is a Customer: the `Customer`
  /// schema has no `profilePicture` field (only `Tailor` and `Retailer` do), so
  /// those notifications fall back to an initials avatar in the UI.
  Future<String?> getCounterpartyProfilePicture(
    AppNotification n,
    UserRole viewerRole,
  ) async {
    try {
      switch (viewerRole) {
        case UserRole.customer:
          // A customer's counterparty is the Retailer handling the sub-order,
          // or the Tailor handling the tailor job. Which one depends on the
          // notification *type* — a tailor-related notification can also carry
          // a subOrderId, so preferring subOrderId blindly would show the
          // retailer's picture on a tailor notification.
          if (_isAboutTailor(n.type)) {
            if (n.tailorJobId != null && n.tailorJobId!.isNotEmpty) {
              return await _tailorPictureFromJob(n.tailorJobId!);
            }
            return null;
          }
          if (n.subOrderId != null && n.subOrderId!.isNotEmpty) {
            return await _retailerPictureFromSubOrder(n.subOrderId!);
          }
          if (n.tailorJobId != null && n.tailorJobId!.isNotEmpty) {
            return await _tailorPictureFromJob(n.tailorJobId!);
          }
          return null;

        case UserRole.retailer:
          // Only 'Tailor Assigned' is about another business party. Every other
          // retailer notification originates from the Customer (or is a system
          // stock alert), so it keeps its own category styling / initials.
          if (n.type == NotificationDbType.jobConfirmed) {
            if (n.tailorJobId != null && n.tailorJobId!.isNotEmpty) {
              return await _tailorPictureFromJob(n.tailorJobId!);
            }
            // Fall back to locating the job by order when the notification
            // predates the tailorJobId field being written.
            if (n.orderId.isNotEmpty) {
              final jobQuery = await _db
                  .collection('Tailor-jobs')
                  .where('orderId', isEqualTo: n.orderId)
                  .limit(1)
                  .get();
              if (jobQuery.docs.isNotEmpty) {
                return await _tailorPicture(jobQuery.docs.first.data()['tailorId']);
              }
            }
          }
          return null;

        case UserRole.tailor:
          // Every tailor notification originates from the Customer, who has no
          // profile picture in the schema.
          return null;
      }
    } catch (e) {
      debugPrint('Error fetching counterparty profile picture: $e');
    }
    return null;
  }

  /// Customer-facing notification types raised by the Tailor side of an order.
  /// Everything else a customer receives is about the Retailer / the order.
  static bool _isAboutTailor(NotificationDbType type) {
    switch (type) {
      case NotificationDbType.jobRejected:
      case NotificationDbType.jobConfirmed:
      case NotificationDbType.quoteReceived:
      case NotificationDbType.quoteExpired:
      case NotificationDbType.garmentCompleted:
      case NotificationDbType.tailorSearchPrompt:
        return true;
      default:
        return false;
    }
  }

  /// The counterparty's display name, used for the initials avatar when no
  /// profile picture exists. Mirrors [getCounterpartyProfilePicture]: for a
  /// Customer viewer this is the Retailer/Tailor, for the other roles it is
  /// the Customer (resolved in [getResolvedNotificationData]).
  Future<String?> getCounterpartyName(
    AppNotification n,
    UserRole viewerRole,
  ) async {
    if (viewerRole != UserRole.customer) return null;
    try {
      if (_isAboutTailor(n.type)) {
        if (n.tailorJobId != null && n.tailorJobId!.isNotEmpty) {
          final jobDoc =
              await _db.collection('Tailor-jobs').doc(n.tailorJobId).get();
          final tailorId = jobDoc.data()?['tailorId'];
          if (tailorId is String && tailorId.isNotEmpty) {
            final doc = await _db.collection('Tailor').doc(tailorId).get();
            return _nonEmpty(doc.data()?['name']);
          }
        }
        return null;
      }
      if (n.subOrderId != null && n.subOrderId!.isNotEmpty) {
        final subOrderDoc =
            await _db.collection('Sub-orders').doc(n.subOrderId).get();
        final retailerId = subOrderDoc.data()?['retailerId'];
        if (retailerId is String && retailerId.isNotEmpty) {
          final doc = await _db.collection('Retailer').doc(retailerId).get();
          return _nonEmpty(doc.data()?['shopName']) ??
              _nonEmpty(doc.data()?['name']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching counterparty name: $e');
    }
    return null;
  }

  /// Sub-orders/{id}.retailerId -> Retailer/{retailerId}.profilePicture
  Future<String?> _retailerPictureFromSubOrder(String subOrderId) async {
    final subOrderDoc = await _db.collection('Sub-orders').doc(subOrderId).get();
    if (!subOrderDoc.exists) return null;
    final retailerId = subOrderDoc.data()?['retailerId'];
    if (retailerId == null || retailerId is! String || retailerId.isEmpty) return null;
    final retailerDoc = await _db.collection('Retailer').doc(retailerId).get();
    return _nonEmpty(retailerDoc.data()?['profilePicture']);
  }

  /// Tailor-jobs/{id}.tailorId -> Tailor/{tailorId}.profilePicture
  Future<String?> _tailorPictureFromJob(String tailorJobId) async {
    final jobDoc = await _db.collection('Tailor-jobs').doc(tailorJobId).get();
    if (!jobDoc.exists) return null;
    return _tailorPicture(jobDoc.data()?['tailorId']);
  }

  Future<String?> _tailorPicture(dynamic tailorId) async {
    if (tailorId == null || tailorId is! String || tailorId.isEmpty) return null;
    final tailorDoc = await _db.collection('Tailor').doc(tailorId).get();
    return _nonEmpty(tailorDoc.data()?['profilePicture']);
  }

  /// Treats an empty/blank stored URL the same as a missing one, so the UI
  /// falls back to initials instead of handing NetworkImage an invalid URL.
  static String? _nonEmpty(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  /// Deep lookup to find a Customer's name and the actual Order ID starting from a TailorJob or Sub-Order.
  ///
  /// The `orderId` lookup (step 1) is the critical part callers need — it must survive even if the
  /// secondary lookups (customer name, rejection reason) fail, e.g. due to Firestore rules blocking a
  /// tailor from reading the `Orders`/`Customer` collections directly. Each secondary lookup is
  /// therefore isolated in its own try/catch so a permission error there can't wipe out an already
  /// resolved orderId.
  Future<Map<String, String?>?> getResolvedNotificationData(AppNotification n) async {
    String? orderId = n.orderId;

    // 1. Find the Order ID first if it's missing in the notification document
    try {
      if (orderId.isEmpty || orderId == 'N/A') {
        if (n.subOrderId != null && n.subOrderId!.isNotEmpty) {
          final doc = await _db.collection('Sub-orders').doc(n.subOrderId).get();
          orderId = doc.data()?['orderId'];
        } else if (n.tailorJobId != null && n.tailorJobId!.isNotEmpty) {
          final doc = await _db.collection('Tailor-jobs').doc(n.tailorJobId).get();
          orderId = doc.data()?['orderId'];
        }
      }
    } catch (e) {
      debugPrint('Error resolving orderId for notification: $e');
    }

    if (orderId == null || orderId.isEmpty) return null;

    // 2. Find the Customer's name from the Order (best-effort — orderId above is already secured)
    String? customerName;
    try {
      final orderDoc = await _db.collection('Orders').doc(orderId).get();
      if (orderDoc.exists) {
        final customerId = orderDoc.data()?['customerId'];
        if (customerId != null) {
          final customerDoc = await _db.collection('Customer').doc(customerId).get();
          customerName = customerDoc.data()?['name'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Error resolving customer name for notification: $e');
    }

    // 3. If it's a cancellation, try to find the rejection reason from Tailor-jobs (also best-effort)
    String? rejectionReason;
    if (n.type == NotificationDbType.jobRejected) {
      try {
        if (n.tailorJobId != null && n.tailorJobId!.isNotEmpty) {
          final jobDoc = await _db.collection('Tailor-jobs').doc(n.tailorJobId).get();
          rejectionReason = jobDoc.data()?['rejectionReason'];
        } else {
          final jobQuery = await _db
              .collection('Tailor-jobs')
              .where('orderId', isEqualTo: orderId)
              .limit(1)
              .get();
          if (jobQuery.docs.isNotEmpty) {
            rejectionReason = jobQuery.docs.first.data()['rejectionReason'];
          }
        }
      } catch (e) {
        debugPrint('Error resolving rejection reason for notification: $e');
      }
    }

    return {
      'orderId': orderId,
      'customerName': customerName,
      'rejectionReason': rejectionReason,
    };
  }


  /// Marks a specific notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.collection(_collection).doc(notificationId).update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }


  /// Alias for [markAsRead].
  Future<void> markNotificationRead(String notificationId) => markAsRead(notificationId);


  /// Deletes a specific notification.
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection(_collection).doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }


  /// Fetches a paginated list of notifications.
  /// [lastDoc] is used for Firestore cursor-based pagination.
  Future<List<AppNotification>> getNotifications(
      String userId, {
        int limit = 20,
        DocumentSnapshot? lastDoc,
      }) async {
    try {
      final cleanUserId = userId.trim();

      if (cleanUserId.isEmpty) {
        return [];
      }

      Query query = _db
          .collection(_collection)
          .where('userId', isEqualTo: cleanUserId)
          .orderBy('createdAt', descending: true)
          .limit(limit);


      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }


      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AppNotification.fromJson({
          ...data,
          'id': doc.id,
        });
      }).toList();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }


  /// Marks all notifications for a user as read.
  Future<void> markAllNotificationsRead(String userId) async {
    try {
      final cleanUserId = userId.trim();

      if (cleanUserId.isEmpty) {
        return;
      }

      final batch = _db.batch();
      final unread = await _db
          .collection(_collection)
          .where('userId', isEqualTo: cleanUserId)
          .where('isRead', isEqualTo: false)
          .get();


      for (var doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all read: $e');
    }
  }


  /// Deletes all notifications for a specific user.
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final cleanUserId = userId.trim();

      if (cleanUserId.isEmpty) {
        return;
      }

      final batch = _db.batch();
      final snapshots = await _db
          .collection(_collection)
          .where('userId', isEqualTo: cleanUserId)
          .get();


      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting notifications: $e');
    }
  }


  /// Returns the count of unread notifications for a user.
  Stream<int> getUnreadNotificationCount(String userId) {
    final cleanUserId = userId.trim();

    if (cleanUserId.isEmpty) {
      return Stream.value(0);
    }

    return _db
        .collection(_collection)
        .where('userId', isEqualTo: cleanUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }






// ─── Customer Notifications ────────────────────────────────────────────────




  Future<void> _sendNotification({
    required String userId,
    required UserRole userRole,
    required NotificationDbType type,
    required String message,
    required String orderId,
    String? subOrderId,
  }) async {
    final docRef = _db.collection(_collection).doc();
    final notification = AppNotification(
      id: docRef.id,
      userId: userId,
      userRole: userRole,
      type: type,
      message: message,
      createdAt: DateTime.now(),
      orderId: orderId,
      subOrderId: subOrderId,
      isRead: false,
    );
    await docRef.set(notification.toJson());
  }


  Future<void> notifyCustomerOrderDelivered(
      String customerId,
      String orderId,
      String partyName,
      String partyRole,
      ) async {
    await _sendNotification(
      userId: customerId,
      userRole: UserRole.customer,
      type: NotificationDbType.orderCompleted,
      message: 'Your order #$orderId has been delivered by $partyName.',
      orderId: orderId,
    );
  }


  Future<void> notifyCustomerOrderConfirmed(
      String customerId,
      String orderId,
      String partyName,
      String partyRole,
      ) async {
    await _sendNotification(
      userId: customerId,
      userRole: UserRole.customer,
      type: NotificationDbType.orderConfirmed,
      message: 'Your order #$orderId has been confirmed by $partyName.',
      orderId: orderId,
    );
  }




  Future<void> notifyCustomerOrderCancelled(
      String customerId,
      String orderId,
      String partyName,
      String partyRole,
      String cancelReason,
      ) async {
    await _sendNotification(
      userId: customerId,
      userRole: UserRole.customer,
      type: NotificationDbType.jobRejected,
      message: 'Order #$orderId was cancelled by $partyName. Reason: $cancelReason',
      orderId: orderId,
    );
  }


  // ─── Tailor Notifications ──────────────────────────────────────────────────




  Future<void> notifyTailorNewOrder(
      String tailorId,
      String orderId,
      String customerName,
      String itemName,
      ) async {
    await _sendNotification(
      userId: tailorId,
      userRole: UserRole.tailor,
      type: NotificationDbType.jobRequested,
      message: 'New stitching request from $customerName for $itemName. Order #$orderId',
      orderId: orderId,
    );
  }




  /// The customer accepted this tailor's quote and paid for it — the job is
  /// theirs to start. Nothing used to tell the tailor this had happened, so
  /// they only found out by leaving their orders screen open.
  Future<void> notifyTailorJobConfirmed(
      String tailorId,
      String orderId,
      String customerName,
      ) async {
    await _sendNotification(
      userId: tailorId,
      userRole: UserRole.tailor,
      type: NotificationDbType.jobConfirmed,
      message:
          '$customerName accepted your quote and paid. You can start stitching.',
      orderId: orderId,
    );
  }




  Future<void> notifyTailorConfirmOrder(
      String tailorId,
      String orderId,
      String customerName,
      String itemName,
      ) async {
    await _sendNotification(
      userId: tailorId,
      userRole: UserRole.tailor,
      type: NotificationDbType.selectionDeadlineReminder,
      message: 'Reminder: Please confirm the stitching request for $customerName ($itemName).',
      orderId: orderId,
    );
  }




  /// Reminds the tailor that a job they have taken is due.
  ///
  /// Sent at most once per job: with no Cloud Functions the reminder is
  /// raised by a device noticing the date has come round, and that check
  /// runs again on every app launch — without this guard the tailor would
  /// collect a fresh copy of the same reminder each time they opened the
  /// app until they delivered.
  Future<void> notifyTailorDeliveryDeadline(
      String tailorId,
      String orderId,
      String customerName,
      DateTime deadlineDate,
      ) async {
    if (await _alreadySent(
      userId: tailorId,
      type: NotificationDbType.jobDeliveryDeadline,
      orderId: orderId,
    )) {
      return;
    }

    await _sendNotification(
      userId: tailorId,
      userRole: UserRole.tailor,
      type: NotificationDbType.jobDeliveryDeadline,
      message: 'Delivery deadline approaching for $customerName\'s order #$orderId.',
      orderId: orderId,
    );
  }

  /// True if [userId] already holds a notification of [type] for [orderId].
  /// Fails open — a lookup error means we'd rather send a duplicate than
  /// swallow the reminder entirely.
  Future<bool> _alreadySent({
    required String userId,
    required NotificationDbType type,
    required String orderId,
  }) async {
    try {
      final snap = await _db
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type.name)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('[NotificationService] dedupe lookup failed: $e');
      return false;
    }
  }




  Future<void> notifyTailorOrderCancelled(
      String tailorId,
      String orderId,
      String customerName,
      String itemName,
      String cancelReason,
      ) async {
    await _sendNotification(
      userId: tailorId,
      userRole: UserRole.tailor,
      type: NotificationDbType.jobRejected,
      message: '$customerName cancelled their order for $itemName. Reason: $cancelReason',
      orderId: orderId,
    );
  }






// ─── Retailer Notifications ────────────────────────────────────────────────




  Future<void> notifyRetailerNewOrder(
      String retailerId,
      String orderId,
      String customerName,
      String itemName,
      ) async {
    await _sendNotification(
      userId: retailerId,
      userRole: UserRole.retailer,
      type: NotificationDbType.suborderPlaced,
      message: 'New material order from $customerName for $itemName. Order #$orderId',
      orderId: orderId,
    );
  }




  Future<void> notifyRetailerStockAlert(
      String retailerId,
      String productId,
      String productName,
      String colorName,
      int stock,
      ) async {
    await _sendNotification(
      userId: retailerId,
      userRole: UserRole.retailer,
      type: NotificationDbType.deliveryReminder, // Best fit for stock alert
      message: 'Low stock alert: $productName ($colorName) has only $stock units left.',
      // The Notifications schema has no dedicated productId field, so the
      // productId is carried in orderId — the "Product ID" footer label on the
      // retailer card (see notification_screen.dart) reads it from there.
      orderId: productId,
    );
  }




  Future<void> notifyRetailerTailorAssigned(
      String retailerId,
      String orderId,
      String customerName,
      String tailorName,
      DateTime deadlineDate,
      ) async {
    await _sendNotification(
      userId: retailerId,
      userRole: UserRole.retailer,
      type: NotificationDbType.jobConfirmed,
      message: 'A tailor ($tailorName) has been assigned to $customerName\'s order #$orderId.',
      orderId: orderId,
    );
  }




}




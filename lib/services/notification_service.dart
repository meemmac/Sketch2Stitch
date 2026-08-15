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
    debugPrint('[NotificationService] Streaming for UID: "$cleanUid"');
    
    if (cleanUid.isEmpty) {
      debugPrint('[NotificationService] Warning: Empty UID provided');
      return Stream.value([]);
    }

    // Use a query that finds the ID even if there's a trailing space in the DB
    // Wrapped in a stream to handle database delays on first load
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: cleanUid)
        .snapshots()
        .map((snapshot) {
      debugPrint('[NotificationService] Snapshot received with ${snapshot.docs.length} docs');
      return snapshot.docs.map((doc) {
        return AppNotification.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Fetches the profile picture URL of the person who sent the notification.
  /// Used for Customer notifications to show Tailor/Retailer photos.
  Future<String?> getSenderProfilePicture(AppNotification n) async {
    try {
      // 1. If it's a retailer notification (based on subOrderId)
      if (n.subOrderId != null && n.subOrderId!.isNotEmpty) {
        final subOrderDoc = await _db.collection('Sub-orders').doc(n.subOrderId).get();
        if (subOrderDoc.exists) {
          final retailerId = subOrderDoc.data()?['retailerId'];
          if (retailerId != null) {
            final retailerDoc = await _db.collection('Retailer').doc(retailerId).get();
            return retailerDoc.data()?['profilePicture'] as String?;
          }
        }
      }

      // 2. If it's a tailor notification (based on tailorJobId)
      if (n.tailorJobId != null && n.tailorJobId!.isNotEmpty) {
        final tailorJobDoc = await _db.collection('Tailor-jobs').doc(n.tailorJobId).get();
        if (tailorJobDoc.exists) {
          final tailorId = tailorJobDoc.data()?['tailorId'];
          if (tailorId != null) {
            final tailorDoc = await _db.collection('Tailor').doc(tailorId).get();
            return tailorDoc.data()?['profilePicture'] as String?;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching sender profile picture: $e');
    }
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
        debugPrint('[NotificationService] Warning: Empty UID provided for getNotifications');
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
        debugPrint('[NotificationService] Warning: Empty UID provided for markAllNotificationsRead');
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
        debugPrint('[NotificationService] Warning: Empty UID provided for deleteAllNotifications');
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
      debugPrint('[NotificationService] All notifications deleted for UID: $cleanUserId');
    } catch (e) {
      debugPrint('Error deleting notifications: $e');
    }
  }


  /// Returns the count of unread notifications for a user.
  Stream<int> getUnreadNotificationCount(String userId) {
    final cleanUserId = userId.trim();
    debugPrint('[NotificationService] Getting unread count for UID: "$cleanUserId"');

    if (cleanUserId.isEmpty) {
      debugPrint('[NotificationService] Warning: Empty UID provided for notification count');
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




  Future<void> notifyTailorDeliveryDeadline(
      String tailorId,
      String orderId,
      String customerName,
      DateTime deadlineDate,
      ) async {
    await _sendNotification(
      userId: tailorId,
      userRole: UserRole.tailor,
      type: NotificationDbType.jobDeliveryDeadline,
      message: 'Delivery deadline approaching for $customerName\'s order #$orderId.',
      orderId: orderId,
    );
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
      orderId: 'N/A',
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




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
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return AppNotification.fromJson({
                ...data,
                'id': doc.id,
              });
            }).toList());
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
      Query query = _db
          .collection(_collection)
          .where('userId', isEqualTo: userId)
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
      final batch = _db.batch();
      final unread = await _db
          .collection(_collection)
          .where('userId', isEqualTo: userId)
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

  /// Returns the count of unread notifications for a user.
  Stream<int> getUnreadNotificationCount(String userId) {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

}

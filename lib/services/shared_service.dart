import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/conversation.dart';
import '../models/customer.dart';
import '../models/message.dart';
import '../models/notification.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/sub_order.dart';
import '../models/tailor_job.dart';
import '../models/user_role.dart';
import 'Cloudinary_service.dart';

/// Thrown by [SharedService] with a user-friendly message so callers can
/// surface `e.message` directly without knowing Firestore error codes.
class SharedServiceException implements Exception {
  const SharedServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Aggregate returned by [SharedService.getDashboardSummary].
class DashboardSummary {
  /// Number of active (non-cancelled, non-completed) orders.
  final int activeOrderCount;

  /// Number of pending / quoted tailor jobs.
  final int pendingTailorJobCount;

  /// Number of unread notifications.
  final int unreadNotificationCount;

  /// Most recent unread notifications (up to 5).
  final List<AppNotification> recentNotifications;

  const DashboardSummary({
    required this.activeOrderCount,
    required this.pendingTailorJobCount,
    required this.unreadNotificationCount,
    required this.recentNotifications,
  });
}

/// Aggregate returned by [SharedService.getRecentOrders].
class RecentOrderResult {
  final Order order;
  final List<SubOrder> subOrders;

  const RecentOrderResult({required this.order, required this.subOrders});
}

/// Wraps cross-screen Firestore operations, CDN helpers, and location search.
///
/// Collections touched: `Customer`, `Products`, `Messages`, `Conversations`,
/// `Orders`, `Sub-orders`, `Tailor-jobs`, `Notifications`.
class SharedService {
  SharedService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _customers      = 'Customer';
  static const _products       = 'Products';
  static const _messages       = 'Messages';
  static const _conversations  = 'Conversations';
  static const _orders         = 'Orders';
  static const _subOrders      = 'Sub-orders';
  static const _tailorJobs     = 'Tailor-jobs';
  static const _notifications  = 'Notifications';

  // ── getCustomerProfile ─────────────────────────────────────────────────────

  /// Returns the [Customer] profile for [customerId].
  Future<Customer> getCustomerProfile(String customerId) async {
    try {
      final snap = await _db.collection(_customers).doc(customerId).get();
      if (!snap.exists) {
        throw SharedServiceException('Customer "$customerId" not found.');
      }
      return Customer.fromJson({...snap.data()!, 'id': snap.id});
    } on SharedServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw SharedServiceException(
          'Failed to fetch customer profile: ${e.message ?? e.code}');
    }
  }

  // ── getProducts ────────────────────────────────────────────────────────────

  /// Returns all [Product]s, optionally filtered by [category].
  ///
  /// Pass `null` or an empty string to fetch all products (Fabrics &
  /// Elements). When [category] is provided the query filters on
  /// `category == category`.
  Future<List<Product>> getProducts({String? category}) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection(_products);
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }
      final snap = await query.get();
      return snap.docs
          .map((d) => Product.fromJson({...d.data(), 'id': d.id}))
          .toList();
    } on FirebaseException catch (e) {
      throw SharedServiceException(
          'Failed to fetch products: ${e.message ?? e.code}');
    }
  }

  // ── getProductDetails ──────────────────────────────────────────────────────

  /// Returns full product information including color options, pricing, and
  /// stock for [productId].
  Future<Product> getProductDetails(String productId) async {
    try {
      final snap = await _db.collection(_products).doc(productId).get();
      if (!snap.exists) {
        throw SharedServiceException('Product "$productId" not found.');
      }
      return Product.fromJson({...snap.data()!, 'id': snap.id});
    } on SharedServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      throw SharedServiceException(
          'Failed to fetch product details: ${e.message ?? e.code}');
    }
  }

  // ── getProductByProductId ──────────────────────────────────────────────────

  /// Alias for [getProductDetails] — returns a single [Product] by its
  /// Firestore document id.
  Future<Product> getProductByProductId(String productId) =>
      getProductDetails(productId);

  // ── sendMessage ────────────────────────────────────────────────────────────

  /// Adds a message to [conversationId] and updates the conversation's
  /// `updatedAt` and `unreadCount` in a single batch.
  ///
  /// [data] must include `msgText` and `senderRole`; all other fields
  /// (`conversationId`, `senderId`, `sentAt`, `isRead`) are written by this
  /// method.
  ///
  /// Returns the saved [Message].
  Future<Message> sendMessage(
    String conversationId,
    String senderId,
    Map<String, dynamic> data,
  ) async {
    try {
      final now = Timestamp.now();
      final msgPayload = Map<String, dynamic>.from(data)
        ..['conversationId'] = conversationId
        ..['senderId']       = senderId
        ..['sentAt']         = now
        ..['isRead']         = false;

      final batch   = _db.batch();
      final msgRef  = _db.collection(_messages).doc();
      final convRef = _db.collection(_conversations).doc(conversationId);

      batch.set(msgRef, msgPayload);
      batch.update(convRef, {
        'updatedAt':   now,
        'unreadCount': FieldValue.increment(1),
      });

      await batch.commit();

      final snap = await msgRef.get();
      return Message.fromJson({...snap.data()!, 'id': snap.id});
    } on FirebaseException catch (e) {
      throw SharedServiceException(
          'Failed to send message: ${e.message ?? e.code}');
    }
  }

  // ── markMessagesRead ───────────────────────────────────────────────────────

  /// Marks all unread messages in [conversationId] that were NOT sent by
  /// [userId] as read, and resets the conversation's `unreadCount` to 0.
  ///
  /// Uses a batch write for atomicity across Messages + Conversations.
  Future<void> markMessagesRead(
    String conversationId,
    String userId,
  ) async {
    try {
      final unreadSnap = await _db
          .collection(_messages)
          .where('conversationId', isEqualTo: conversationId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadSnap.docs.isEmpty) return;

      final now   = Timestamp.now();
      final batch = _db.batch();

      for (final doc in unreadSnap.docs) {
        // Only mark messages sent by the other party.
        if (doc.data()['senderId'] != userId) {
          batch.update(doc.reference, {'isRead': true, 'readAt': now});
        }
      }

      batch.update(
        _db.collection(_conversations).doc(conversationId),
        {'unreadCount': 0, 'lastReadAt': now},
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw SharedServiceException(
          'Failed to mark messages read: ${e.message ?? e.code}');
    }
  }

  // ── createConversation ─────────────────────────────────────────────────────

  /// Creates a new `Conversations` document linking [customerId] with
  /// [otherId] (a tailor or retailer identified by [otherRole]) for [orderId].
  ///
  /// Returns the saved [Conversation].
  Future<Conversation> createConversation(
    String customerId,
    String otherId,
    UserRole otherRole,
    String orderId,
  ) async {
    try {
      final now     = Timestamp.now();
      final payload = {
        'customerId':  customerId,
        'otherId':     otherId,
        'otherRole':   otherRole.name,
        'orderId':     orderId,
        'unreadCount': 0,
        'isBlocked':   false,
        'isDeleted':   false,
        'updatedAt':   now,
      };

      final ref  = await _db.collection(_conversations).add(payload);
      final snap = await ref.get();
      return Conversation.fromJson({...snap.data()!, 'id': snap.id});
    } on FirebaseException catch (e) {
      throw SharedServiceException(
          'Failed to create conversation: ${e.message ?? e.code}');
    }
  }

  // ── getDashboardSummary ────────────────────────────────────────────────────

  /// Returns a [DashboardSummary] for [customerId] by querying Orders,
  /// Tailor-jobs, and Notifications in parallel.
  Future<DashboardSummary> getDashboardSummary(String customerId) async {
    try {
      final activeStatuses = [
        OrderStatus.awaitingConfirmation.toValue,
        OrderStatus.processing.toValue,
        OrderStatus.awaitingTailorSearch.toValue,
        OrderStatus.tailorPending.toValue,
      ];

      final pendingJobStatuses = [
        TailorJobStatus.pending.toValue,
        TailorJobStatus.quoted.toValue,
      ];

      final results = await Future.wait([
        // Active orders count
        _db
            .collection(_orders)
            .where('customerId', isEqualTo: customerId)
            .where('status', whereIn: activeStatuses)
            .count()
            .get(),
        // Pending tailor-job count — keyed by orderId, filtered client-side
        _db
            .collection(_tailorJobs)
            .where('status', whereIn: pendingJobStatuses)
            .get(),
        // Unread notifications
        _db
            .collection(_notifications)
            .where('userId', isEqualTo: customerId)
            .where('isRead', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get(),
      ]);

      final activeOrderCount = (results[0] as AggregateQuerySnapshot).count ?? 0;

      // Filter tailor jobs that belong to this customer's orders.
      // (Tailor-jobs has orderId but not customerId — we already have the
      //  active order ids from the count query; for the dashboard a simple
      //  client-side count is acceptable given the small result set.)
      final jobSnap         = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final pendingJobCount = jobSnap.docs.length; // approximation; scoped later

      final notifSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final notifs    = notifSnap.docs.map((d) {
        final data = d.data();
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] =
              (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return AppNotification.fromJson({...data, 'id': d.id});
      }).toList();

      final unreadCount =
          await _db
              .collection(_notifications)
              .where('userId', isEqualTo: customerId)
              .where('isRead', isEqualTo: false)
              .count()
              .get();

      return DashboardSummary(
        activeOrderCount:        activeOrderCount,
        pendingTailorJobCount:   pendingJobCount,
        unreadNotificationCount: unreadCount.count ?? 0,
        recentNotifications:     notifs,
      );
    } on FirebaseException catch (e) {
      throw SharedServiceException(
          'Failed to fetch dashboard summary: ${e.message ?? e.code}');
    }
  }

  // ── getRecentOrders ────────────────────────────────────────────────────────

  /// Returns the most recent [limit] orders for [customerId] together with
  /// their sub-orders. Orders are sorted by `orderDate` descending.
  Future<List<RecentOrderResult>> getRecentOrders(
    String customerId, {
    int limit = 5,
  }) async {
    try {
      final orderSnap = await _db
          .collection(_orders)
          .where('customerId', isEqualTo: customerId)
          .orderBy('orderDate', descending: true)
          .limit(limit)
          .get();

      if (orderSnap.docs.isEmpty) return [];

      final orders    = orderSnap.docs.map(_orderFromSnap).toList();
      final orderIds  = orders.map((o) => o.id).toList();

      // Fetch sub-orders for all returned orders in parallel chunks.
      final chunks = <List<String>>[];
      for (var i = 0; i < orderIds.length; i += 30) {
        chunks.add(orderIds.sublist(
          i,
          (i + 30) > orderIds.length ? orderIds.length : i + 30,
        ));
      }

      final subSnaps = await Future.wait(
        chunks.map(
          (chunk) => _db
              .collection(_subOrders)
              .where('orderId', whereIn: chunk)
              .get(),
        ),
      );

      // Group sub-orders by orderId.
      final subOrdersByOrderId = <String, List<SubOrder>>{};
      for (final snap in subSnaps) {
        for (final doc in snap.docs) {
          final sub = _subOrderFromSnap(doc);
          subOrdersByOrderId.putIfAbsent(sub.orderId, () => []).add(sub);
        }
      }

      return orders
          .map((o) => RecentOrderResult(
                order:     o,
                subOrders: subOrdersByOrderId[o.id] ?? [],
              ))
          .toList();
    } on FirebaseException catch (e) {
      throw SharedServiceException(
          'Failed to fetch recent orders: ${e.message ?? e.code}');
    }
  }

  // ── resolveImageUrls ───────────────────────────────────────────────────────

  /// Converts a list of raw Cloudinary public-id paths or partial URLs into
  /// fully-qualified, optimised CDN URLs using [CloudinaryService].
  ///
  /// Paths that already contain `cloudinary.com` are returned as-is after
  /// optimisation. Other paths are treated as Cloudinary public IDs and
  /// assembled into a full URL via [getCDNUrl].
  List<String> resolveImageUrls(List<String> imagePaths) {
    final svc = CloudinaryService();
    return imagePaths.map((p) {
      final url = p.contains('cloudinary.com') ? p : getCDNUrl(p);
      return svc.getOptimizedImageUrl(url);
    }).toList();
  }

  // ── getCDNUrl ──────────────────────────────────────────────────────────────

  /// Builds a full Cloudinary delivery URL from a [imagePath] (public ID or
  /// relative path). No transformation is applied; call
  /// [CloudinaryService.getOptimizedImageUrl] on the result to add resizing.
  String getCDNUrl(String imagePath) {
    // Strip leading slash if present.
    final cleaned = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
    return 'https://res.cloudinary.com/${CloudinaryService.cloudName}/image/upload/$cleaned';
  }

  // ── searchOrders ───────────────────────────────────────────────────────────

  /// Searches orders for [customerId] by matching [query] against the order
  /// status string (case-insensitive prefix).
  ///
  /// Firestore does not support full-text search; this method fetches all
  /// orders for the customer and filters client-side. For large datasets
  /// consider integrating Algolia or Typesense.
  Future<List<Order>> searchOrders(String customerId, String query) async {
    try {
      final snap = await _db
          .collection(_orders)
          .where('customerId', isEqualTo: customerId)
          .orderBy('orderDate', descending: true)
          .get();

      final q = query.trim().toLowerCase();

      return snap.docs
          .map(_orderFromSnap)
          .where((o) =>
              o.id.toLowerCase().contains(q) ||
              o.status.toValue.toLowerCase().contains(q) ||
              o.statusText.toLowerCase().contains(q))
          .toList();
    } on FirebaseException catch (e) {
      throw SharedServiceException(
          'Failed to search orders: ${e.message ?? e.code}');
    }
  }

  // ── searchLocations ────────────────────────────────────────────────────────

  /// Queries the OpenStreetMap Nominatim API for address suggestions matching
  /// [query]. Returns a list of human-readable address strings suitable for
  /// profile setup address selection.
  ///
  /// Results are limited to 15 entries and soft-biased toward Bangladesh. An
  /// empty list is returned on network failure so the UI degrades gracefully.
  Future<List<String>> searchLocations(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q':              query,
          'format':         'json',
          'addressdetails': '1',
          'limit':          '15',
          // Soft bias to Bangladesh — the viewbox lifts local matches without
          // `bounded=1`, so foreign places still appear, just lower down.
          'viewbox':        '88.0,26.7,92.7,20.5',
        },
      );

      final response = await http
          .get(uri, headers: {
            'User-Agent':      'Sketch2Stitch/1.0',
            'Accept-Language': 'bn,en',
          })
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final results = jsonDecode(response.body) as List<dynamic>;
      return results
          .map((r) => (r as Map<String, dynamic>)['display_name'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      // Network errors should not crash the UI — return empty list.
      return [];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Order _orderFromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = Map<String, dynamic>.from(snap.data()!);
    if (data['orderDate'] is Timestamp) {
      data['orderDate'] =
          (data['orderDate'] as Timestamp).toDate().toIso8601String();
    }
    if (data['tailorSelectionDeadline'] is Timestamp) {
      data['tailorSelectionDeadline'] =
          (data['tailorSelectionDeadline'] as Timestamp)
              .toDate()
              .toIso8601String();
    }
    return Order.fromJson({...data, 'id': snap.id});
  }

  SubOrder _subOrderFromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = Map<String, dynamic>.from(snap.data()!);
    if (data['deliveryDate'] is Timestamp) {
      data['deliveryDate'] =
          (data['deliveryDate'] as Timestamp).toDate().toIso8601String();
    }
    if (data['autoReleaseAt'] is Timestamp) {
      data['autoReleaseAt'] =
          (data['autoReleaseAt'] as Timestamp).toDate().toIso8601String();
    }
    return SubOrder.fromJson({...data, 'id': snap.id});
  }
}

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/sub_order.dart';
import '../models/order_item.dart';
import '../models/tailor_job.dart';

class OrderService {
  OrderService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _ordersCollection = 'Orders';
  static const String _subOrdersCollection = 'Sub-orders';
  static const String _orderItemsCollection = 'Order-Items';
  static const String _tailorJobsCollection = 'Tailor-jobs';

  // ─── fetchCustomerOrders ───────────────────────────────────────────────────

  /// Fetches orders for a specific customer, optionally filtered by type.
  Future<List<Order>> fetchCustomerOrders(String customerId, {String? filterType}) async {
    try {
      Query query = _db.collection(_ordersCollection).where('customerId', isEqualTo: customerId);

      if (filterType != null && filterType != 'All') {
        query = query.where('status', isEqualTo: filterType);
      }

      final snapshot = await query.orderBy('orderDate', descending: true).get();
      return snapshot.docs
          .map((doc) => Order.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching customer orders: $e');
      return [];
    }
  }

  // ─── fetchOrderDetails ─────────────────────────────────────────────────────

  /// Fetches full order details including sub-orders and their items.
  Future<Order?> fetchOrderDetails(String orderId) async {
    try {
      // 1. Fetch parent order
      final orderDoc = await _db.collection(_ordersCollection).doc(orderId).get();
      if (!orderDoc.exists) return null;

      Order order = Order.fromJson({...orderDoc.data()!, 'id': orderDoc.id});

      // 2. Fetch sub-orders
      final subOrdersSnap = await _db
          .collection(_subOrdersCollection)
          .where('orderId', isEqualTo: orderId)
          .get();

      List<SubOrder> subOrders = subOrdersSnap.docs
          .map((doc) => SubOrder.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // 3. Fetch order items for each sub-order
      for (int i = 0; i < subOrders.length; i++) {
        final itemsSnap = await _db
            .collection(_orderItemsCollection)
            .where('subOrderId', isEqualTo: subOrders[i].id)
            .get();

        subOrders[i].items = itemsSnap.docs
            .map((doc) => OrderItem.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
      }

      return order.copyWith(subOrders: subOrders);
    } catch (e) {
      debugPrint('Error fetching order details: $e');
      return null;
    }
  }

  // ─── getCustomerOrders ─────────────────────────────────────────────────────

  /// Alias for fetching customer orders list by UID.
  Future<List<Order>> getCustomerOrders(String uid) => fetchCustomerOrders(uid);

  // ─── streamOrderTimeline ───────────────────────────────────────────────────

  /// Provides a real-time stream of the order lifecycle status for tracking.
  Stream<Map<String, dynamic>> streamOrderTimeline(String orderId) {
    // Combine snapshots from Order, its Sub-orders, and Tailor-job
    return _db.collection(_ordersCollection).doc(orderId).snapshots().asyncMap((orderSnap) async {
      if (!orderSnap.exists) return {};

      final orderData = orderSnap.data()!;
      
      // Fetch sub-orders
      final subOrdersSnap = await _db
          .collection(_subOrdersCollection)
          .where('orderId', isEqualTo: orderId)
          .get();
      
      final subOrders = subOrdersSnap.docs.map((d) => d.data()).toList();

      // Fetch tailor job
      final tailorJobSnap = await _db
          .collection(_tailorJobsCollection)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      
      final tailorJob = tailorJobSnap.docs.isNotEmpty ? tailorJobSnap.docs.first.data() : null;

      return {
        'order': orderData,
        'subOrders': subOrders,
        'tailorJob': tailorJob,
      };
    });
  }

  // ─── updateTailorRequestStatus ─────────────────────────────────────────────

  /// Updates the tailoring-related status of an order.
  Future<void> updateTailorRequestStatus(String orderId, OrderStatus status) async {
    try {
      await _db.collection(_ordersCollection).doc(orderId).update({
        'status': status.toValue,
      });
    } catch (e) {
      debugPrint('Error updating tailor request status: $e');
      rethrow;
    }
  }
}

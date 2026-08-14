import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/sub_order.dart';
import '../models/order_item.dart';
import '../models/tailor_job.dart';
import '../models/review.dart';
import 'Cloudinary_service.dart';

class OrderService {
  OrderService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const String _ordersCollection = 'Orders';
  static const String _subOrdersCollection = 'Sub-orders';
  static const String _orderItemsCollection = 'Order-Items';
  static const String _tailorJobsCollection = 'Tailor-jobs';
  static const String _reviewsCollection = 'Reviews';
  static const String _paymentsCollection = 'Payments';

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

  // ─── submitReview ─────────────────────────────────────────────────────────

  /// Submits a review for an order recipient (tailor or retailer).
  Future<void> submitReview({
    required String orderId,
    required String recipientId,
    required double rating,
    required String comment,
    required ReviewTargetRole type,
    String? customerId,
  }) async {
    try {
      String actualCustomerId = customerId ?? '';
      
      // If customerId not provided, fetch from Order
      if (actualCustomerId.isEmpty) {
        final orderDoc = await _db.collection(_ordersCollection).doc(orderId).get();
        if (orderDoc.exists) {
          actualCustomerId = orderDoc.data()?['customerId'] ?? '';
        }
      }

      if (actualCustomerId.isEmpty) {
        throw Exception('Customer ID is required to submit a review');
      }

      final data = {
        'orderId': orderId,
        'customerId': actualCustomerId,
        'targetId': recipientId,
        'rating': rating,
        'comment': comment,
        'targetRole': type.name,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _db.collection(_reviewsCollection).add(data);
    } catch (e) {
      debugPrint('Error submitting review: $e');
      rethrow;
    }
  }

  // ─── getOrderDetails ──────────────────────────────────────────────────────

  /// Alias for fetching full order details.
  Future<Order?> getOrderDetails(String orderId) => fetchOrderDetails(orderId);

  // ─── cancelOrder ──────────────────────────────────────────────────────────

  /// Cancels an order and marks associated payments as refunded/failed.
  Future<void> cancelOrder(String orderId) async {
    try {
      final batch = _db.batch();

      // 1. Update Order status
      batch.update(_db.collection(_ordersCollection).doc(orderId), {
        'status': OrderStatus.cancelled.toValue,
      });

      // 2. Handle Payments
      final paymentsSnap = await _db
          .collection(_paymentsCollection)
          .where('orderId', isEqualTo: orderId)
          .get();

      for (var doc in paymentsSnap.docs) {
        final status = doc.data()['status'];
        if (status == PaymentStatus.pending.toValue) {
          batch.update(doc.reference, {'status': PaymentStatus.failed.toValue});
        } else if (status == PaymentStatus.completed.toValue) {
          batch.update(doc.reference, {'status': PaymentStatus.refunded.toValue});
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      rethrow;
    }
  }

  // ─── Retailer Order Functions ─────────────────────────────────────────────

  /// Fetches sub-orders for a specific retailer, optionally filtered by category.
  Future<List<SubOrder>> fetchRetailerOrders(String retailerId, {String? statusCategory}) async {
    try {
      Query query = _db.collection(_subOrdersCollection).where('retailerId', isEqualTo: retailerId);

      if (statusCategory != null && statusCategory != 'All') {
        query = query.where('status', isEqualTo: statusCategory.toLowerCase());
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => SubOrder.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching retailer orders: $e');
      return [];
    }
  }

  /// Streams sub-orders for a specific retailer for real-time updates.
  Stream<List<SubOrder>> streamRetailerOrders(String retailerId) {
    return _db
        .collection(_subOrdersCollection)
        .where('retailerId', isEqualTo: retailerId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SubOrder.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Streams sub-orders with full details (customer, products, items) for a retailer.
  Stream<List<Map<String, dynamic>>> streamDetailedRetailerOrders(String retailerId) {
    return _db
        .collection(_subOrdersCollection)
        .where('retailerId', isEqualTo: retailerId)
        .snapshots()
        .asyncMap((subOrdersSnap) async {
      List<Map<String, dynamic>> detailedOrders = [];

      for (var subOrderDoc in subOrdersSnap.docs) {
        final subOrderData = subOrderDoc.data();
        final String subOrderId = subOrderDoc.id;
        final String orderId = subOrderData['orderId'];

        // Fetch parent order
        final orderDoc = await _db.collection(_ordersCollection).doc(orderId).get();
        if (!orderDoc.exists) continue;
        final orderData = orderDoc.data()!;

        // Fetch customer
        final String customerId = orderData['customerId'];
        final customerDoc = await _db.collection('Customer').doc(customerId).get();
        if (!customerDoc.exists) continue;
        final customerData = customerDoc.data()!;

        // Fetch items
        final itemsSnap = await _db
            .collection(_orderItemsCollection)
            .where('subOrderId', isEqualTo: subOrderId)
            .get();

        List<Map<String, dynamic>> itemsList = [];
        for (var itemDoc in itemsSnap.docs) {
          final itemData = itemDoc.data();
          final String productId = itemData['productId'];
          final int optionId = itemData['optionId'];

          // Fetch product
          final productDoc = await _db.collection('Products').doc(productId).get();
          if (productDoc.exists) {
            final productData = productDoc.data()!;
            final List<dynamic> colorOptions = productData['colorOptions'] ?? [];
            final option = colorOptions.firstWhere(
              (o) => o['optionId'] == optionId,
              orElse: () => null,
            );

            final rawImages = (option?['image'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final resolvedImages = resolveImageUrls(rawImages);

            itemsList.add({
              'name': productData['productName'] ?? 'Unknown Product',
              'quantity': itemData['quantity'] ?? 1,
              'price': (option?['price'] ?? 0).toDouble(),
              'imagePath': resolvedImages.isNotEmpty ? resolvedImages.first : '',
              'color': option?['color'] ?? 'N/A',
              'description': productData['description'] ?? '',
              'careSymbol': productData['careSymbol'] ?? [],
            });
          }
        }

        // Fetch tailor if applicable
        String? tailorName;
        if (subOrderData['deliveryDestination'] == 'tailor') {
          final tailorJobSnap = await _db
              .collection(_tailorJobsCollection)
              .where('orderId', isEqualTo: orderId)
              .limit(1)
              .get();
          if (tailorJobSnap.docs.isNotEmpty) {
            final tId = tailorJobSnap.docs.first.data()['tailorId'];
            final tailorDoc = await _db.collection('Tailor').doc(tId).get();
            if (tailorDoc.exists) {
              tailorName = tailorDoc.data()?['name'];
            }
          }
        }

        if (itemsList.isEmpty) {
          debugPrint("OrderService: Skipping sub-order $subOrderId because no items were found.");
          continue;
        }

        detailedOrders.add({
          'subOrder': {...subOrderData, 'id': subOrderId},
          'order': {...orderData, 'id': orderId},
          'customer': customerData,
          'items': itemsList,
          'tailorName': tailorName,
        });
      }
      return detailedOrders;
    });
  }

  /// Updates the status of a sub-order.
  Future<void> updateOrderStatus(String subOrderId, String newStatus) async {
    try {
      await _db.collection(_subOrdersCollection).doc(subOrderId).update({
        'status': newStatus.toLowerCase(),
      });
    } catch (e) {
      debugPrint('Error updating order status: $e');
      rethrow;
    }
  }

  /// Calculates analytics for a retailer's sub-orders.
  Future<Map<String, dynamic>> getOrderAnalytics(String retailerId) async {
    try {
      final subOrders = await fetchRetailerOrders(retailerId);
      
      double totalRevenue = 0;
      int pendingCount = 0;
      int packedCount = 0;
      int deliveredCount = 0;

      for (var so in subOrders) {
        totalRevenue += so.itemsSubtotal;
        switch (so.status) {
          case SubOrderStatus.preparing:
            pendingCount++;
            break;
          case SubOrderStatus.packed:
            packedCount++;
            break;
          case SubOrderStatus.delivered:
            deliveredCount++;
            break;
        }
      }

      return {
        'totalOrders': subOrders.length,
        'totalRevenue': totalRevenue,
        'pendingOrders': pendingCount,
        'packedOrders': packedCount,
        'deliveredOrders': deliveredCount,
      };
    } catch (e) {
      debugPrint('Error getting order analytics: $e');
      return {};
    }
  }

  /// Searches a retailer's sub-orders by ID or order ID.
  Future<List<SubOrder>> searchRetailerOrders(String retailerId, String query) async {
    try {
      final all = await fetchRetailerOrders(retailerId);
      final q = query.toLowerCase();
      return all.where((so) => 
        so.id.toLowerCase().contains(q) || 
        so.orderId.toLowerCase().contains(q)
      ).toList();
    } catch (e) {
      debugPrint('Error searching retailer orders: $e');
      return [];
    }
  }

  /// Validates if a product option has sufficient stock.
  Future<bool> checkStock(String productId, int optionId, int quantity) async {
    try {
      final doc = await _db.collection('Products').doc(productId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final List<dynamic> options = data['colorOptions'] ?? [];
      
      final option = options.firstWhere(
        (opt) => opt['optionId'] == optionId,
        orElse: () => null,
      );

      if (option == null) return false;
      return (option['stock'] ?? 0) >= quantity;
    } catch (e) {
      debugPrint('Error checking stock: $e');
      return false;
    }
  }

  // ─── Tailor Order Functions ─────────────────────────────────────────────

  /// Fetches jobs/orders assigned to a specific tailor.
  Future<List<TailorJob>> fetchTailorOrders(String tailorId) async {
    try {
      final snapshot = await _db
          .collection(_tailorJobsCollection)
          .where('tailorId', isEqualTo: tailorId)
          .get();

      return snapshot.docs
          .map((doc) => TailorJob.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching tailor orders: $e');
      return [];
    }
  }

  /// Streams tailor jobs for a specific tailor for real-time updates.
  Stream<List<TailorJob>> streamTailorOrders(String tailorId) {
    return _db
        .collection(_tailorJobsCollection)
        .where('tailorId', isEqualTo: tailorId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TailorJob.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Accepts a tailor job request and sets initial terms.
  Future<void> acceptTailorJob(
    String orderId,
    double servicePrice,
    DateTime estimatedDate, {
    double? deliveryCharge,
  }) async {
    try {
      final snap = await _db
          .collection(_tailorJobsCollection)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) throw Exception('Tailor job not found');

      await snap.docs.first.reference.update({
        'status': TailorJobStatus.confirmed.toValue,
        'quoteAmount': servicePrice,
        if (deliveryCharge != null) 'deliveryCharge': deliveryCharge,
        'estimatedDeliveryDate': estimatedDate.toIso8601String(),
        'confirmedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error accepting tailor job: $e');
      rethrow;
    }
  }

  /// Declines a tailor job request.
  Future<void> declineTailorJob(String orderId, String reason) async {
    try {
      final snap = await _db
          .collection(_tailorJobsCollection)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) throw Exception('Tailor job not found');

      await snap.docs.first.reference.update({
        'status': TailorJobStatus.tailorDeclined.toValue,
        'rejectionReason': reason,
      });
    } catch (e) {
      debugPrint('Error declining tailor job: $e');
      rethrow;
    }
  }

  /// Updates work progress for a tailor job.
  Future<void> updateWorkProgress(String orderId, String status) async {
    try {
      final snap = await _db
          .collection(_tailorJobsCollection)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) throw Exception('Tailor job not found');

      await snap.docs.first.reference.update({
        'status': status.toLowerCase(),
      });
    } catch (e) {
      debugPrint('Error updating work progress: $e');
      rethrow;
    }
  }

  /// Updates pricing or delivery terms for a job.
  Future<void> editStitchingTerms(String orderId, double newPrice, DateTime newDate) async {
    try {
      final snap = await _db
          .collection(_tailorJobsCollection)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) throw Exception('Tailor job not found');

      await snap.docs.first.reference.update({
        'quoteAmount': newPrice,
        'estimatedDeliveryDate': newDate.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error editing stitching terms: $e');
      rethrow;
    }
  }

  /// Gets analytical stats for a tailor.
  Future<Map<String, dynamic>> getTailorJobStats(String tailorId) async {
    try {
      final jobs = await fetchTailorOrders(tailorId);
      
      double totalEarnings = 0;
      int activeJobs = 0;
      int pendingRequests = 0;

      for (var job in jobs) {
        if (job.status == TailorJobStatus.confirmed) {
          activeJobs++;
          if (job.tailorPaymentStatus == TailorPaymentStatus.paid) {
            totalEarnings += job.quoteAmount ?? 0;
          }
        } else if (job.status == TailorJobStatus.pending || job.status == TailorJobStatus.quoted) {
          pendingRequests++;
        }
      }

      return {
        'totalJobs': jobs.length,
        'activeJobs': activeJobs,
        'pendingRequests': pendingRequests,
        'totalEarnings': totalEarnings,
      };
    } catch (e) {
      debugPrint('Error getting tailor job stats: $e');
      return {};
    }
  }

  // ─── Order Form - Tailor Job Functions ───────────────────────────────────

  /// Creates a new tailor job record.
  Future<String> createTailorJob(String orderId, String tailorId, Map<String, dynamic> data) async {
    try {
      final docData = {
        ...data,
        'orderId': orderId,
        'tailorId': tailorId,
        'status': TailorJobStatus.pending.toValue,
        'quoteStatus': QuoteStatus.notSent.toValue,
        'tailorPaymentStatus': TailorPaymentStatus.unpaid.toValue,
        'createdAt': FieldValue.serverTimestamp(),
        'requestedAt': FieldValue.serverTimestamp(),
      };

      final ref = await _db.collection(_tailorJobsCollection).add(docData);
      return ref.id;
    } catch (e) {
      debugPrint('Error creating tailor job: $e');
      rethrow;
    }
  }

  /// Fetches a specific tailor job by ID.
  Future<TailorJob?> getTailorJob(String tailorJobId) async {
    try {
      final doc = await _db.collection(_tailorJobsCollection).doc(tailorJobId).get();
      if (!doc.exists || doc.data() == null) return null;
      return TailorJob.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      debugPrint('Error getting tailor job: $e');
      return null;
    }
  }

  /// Fetches all tailor jobs associated with a specific order.
  Future<List<TailorJob>> getTailorJobsByOrder(String orderId) async {
    try {
      final snapshot = await _db
          .collection(_tailorJobsCollection)
          .where('orderId', isEqualTo: orderId)
          .get();

      return snapshot.docs
          .map((doc) => TailorJob.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error getting tailor jobs by order: $e');
      return [];
    }
  }

  /// Updates the status of a tailor job.
  Future<void> updateTailorJobStatus(String tailorJobId, TailorJobStatus status) async {
    try {
      await _db.collection(_tailorJobsCollection).doc(tailorJobId).update({
        'status': status.toValue,
      });
    } catch (e) {
      debugPrint('Error updating tailor job status: $e');
      rethrow;
    }
  }

  /// Submits a price quote for a tailor job.
  Future<void> submitQuote(String tailorJobId, double quoteAmount, String? quoteNote) async {
    try {
      await _db.collection(_tailorJobsCollection).doc(tailorJobId).update({
        'quoteAmount': quoteAmount,
        'quoteNote': quoteNote,
        'quoteStatus': QuoteStatus.sent.toValue,
        'status': TailorJobStatus.quoted.toValue,
      });
    } catch (e) {
      debugPrint('Error submitting quote: $e');
      rethrow;
    }
  }

  /// Records a customer's response to a tailor's quote.
  Future<void> respondToQuote(String tailorJobId, QuoteStatus response) async {
    try {
      final status = response == QuoteStatus.accepted 
          ? TailorJobStatus.confirmed 
          : TailorJobStatus.rejected;
          
      await _db.collection(_tailorJobsCollection).doc(tailorJobId).update({
        'quoteStatus': response.toValue,
        'status': status.toValue,
        if (response == QuoteStatus.accepted) 'confirmedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error responding to quote: $e');
      rethrow;
    }
  }

  /// Updates the payment status of a tailor job.
  Future<void> updateTailorPaymentStatus(String tailorJobId, TailorPaymentStatus status) async {
    try {
      await _db.collection(_tailorJobsCollection).doc(tailorJobId).update({
        'tailorPaymentStatus': status.toValue,
      });
    } catch (e) {
      debugPrint('Error updating tailor payment status: $e');
      rethrow;
    }
  }

  /// Sets the deadline for tailor selection on an order.
  Future<void> setTailorSelectionDeadline(String orderId, DateTime deadline) async {
    try {
      await _db.collection(_ordersCollection).doc(orderId).update({
        'tailorSelectionDeadline': deadline.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error setting tailor selection deadline: $e');
      rethrow;
    }
  }

  /// Appends a design reference to a tailor job.
  Future<void> addDesignToTailorJob(String tailorJobId, String designId) async {
    try {
      await _db.collection(_tailorJobsCollection).doc(tailorJobId).update({
        'designIds': FieldValue.arrayUnion([designId]),
      });
    } catch (e) {
      debugPrint('Error adding design to tailor job: $e');
      rethrow;
    }
  }

  // ─── Shared Order Functions ──────────────────────────────────────────────

  /// Converts a list of raw Cloudinary public-id paths or partial URLs into
  /// fully-qualified, optimised CDN URLs.
  List<String> resolveImageUrls(List<String> imagePaths) {
    final svc = CloudinaryService();
    return imagePaths.map((p) {
      final url = p.contains('cloudinary.com') ? p : getCDNUrl(p);
      return svc.getOptimizedImageUrl(url);
    }).toList();
  }

  /// Builds a full Cloudinary delivery URL from a public ID or relative path.
  String getCDNUrl(String imagePath) {
    if (imagePath.startsWith('http')) return imagePath;
    // Strip leading slash if present.
    final cleaned = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
    return 'https://res.cloudinary.com/${CloudinaryService.cloudName}/image/upload/$cleaned';
  }

  /// Verifies if the current logged-in user matches the tailor ID.
  bool tailorAuthCheck(String tailorId) {
    final user = _auth.currentUser;
    return user != null && user.uid == tailorId;
  }

  /// Verifies if the current logged-in user matches the retailer ID.
  bool verifyRetailerAccess(String retailerId) {
    final user = _auth.currentUser;
    return user != null && user.uid == retailerId;
  }
}

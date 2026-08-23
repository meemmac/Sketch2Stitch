import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/sub_order.dart';
import '../models/order_item.dart';
import '../models/tailor_job.dart';
import '../models/customer.dart';
import '../models/review.dart';
import '../models/measurement.dart';
import '../models/payment.dart';
import 'Cloudinary_service.dart';
import 'notification_service.dart';

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

  // ─── streamActiveCustomerOrders ────────────────────────────────────────────

  /// The `Orders.status` values that still need a decision from the customer
  /// — the same set as `OrderRecord.isActive`. 'processing' (tailoring
  /// skipped / search window expired) and 'completed' are terminal and must
  /// stay out of this list.
  static const List<String> activeOrderStatuses = [
    'awaiting_confirmation',
    'awaiting_tailor_search',
    'tailor_pending',
  ];

  /// Real-time stream of the customer's still-actionable orders, each with
  /// its `Sub-orders` attached (the Running Orders screen shows a per-order
  /// retailer count and total, so the sub-orders have to come along).
  ///
  /// Order items are deliberately NOT fetched — the card only needs
  /// itemsSubtotal/deliveryCharge, and pulling `Order-Items` for every
  /// sub-order on every snapshot would be a large read amplification for
  /// data nothing on this screen renders.
  ///
  /// Sorted newest-first client-side: combining `whereIn` on status with an
  /// `orderBy` would require a composite index for no real benefit at this
  /// list's size.
  Stream<List<Order>> streamActiveCustomerOrders(String customerId) {
    return _db
        .collection(_ordersCollection)
        .where('customerId', isEqualTo: customerId)
        .where('status', whereIn: activeOrderStatuses)
        .snapshots()
        .asyncMap((snap) async {
      final orders = await Future.wait(snap.docs.map((doc) async {
        final order = _orderFromSnap(doc);
        final subSnap = await _db
            .collection(_subOrdersCollection)
            .where('orderId', isEqualTo: doc.id)
            .get();
        return order.copyWith(
          subOrders: subSnap.docs.map(_subOrderFromSnap).toList(),
        );
      }));

      orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      return orders;
    });
  }

  /// Count of the customer's active orders, for the Running Orders badge.
  /// Kept separate from [streamActiveCustomerOrders] so the badge doesn't
  /// pay for a sub-order fetch per order just to render a number.
  Stream<int> streamActiveOrderCount(String customerId) {
    return _db
        .collection(_ordersCollection)
        .where('customerId', isEqualTo: customerId)
        .where('status', whereIn: activeOrderStatuses)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Firestore writes `orderDate` / `tailorSelectionDeadline` as Timestamps
  /// (see CheckoutService), but [Order.fromJson] parses ISO strings, so they
  /// have to be normalised before handing the map over.
  Order _orderFromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = Map<String, dynamic>.from(snap.data()!);
    for (final key in ['orderDate', 'tailorSelectionDeadline']) {
      final value = data[key];
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      }
    }
    return Order.fromJson({...data, 'id': snap.id});
  }

  SubOrder _subOrderFromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = Map<String, dynamic>.from(snap.data()!);
    for (final key in ['deliveryDate', 'autoReleaseAt']) {
      final value = data[key];
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      }
    }
    return SubOrder.fromJson({...data, 'id': snap.id});
  }

  /// Provides a high-level reactive data stream that consolidates all information
  /// related to a customer’s journey into a single source of truth.
  /// Retrieve related entities in parallel to minimize latency.
  Stream<List<Map<String, dynamic>>> streamDetailedCustomerOrders(String customerId) {
    return _db
        .collection(_ordersCollection)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) return <Map<String, dynamic>>[];

      // Internal memory cache for entities to eliminate redundant requests.
      final Map<String, Future<Map<String, dynamic>>> retailerCache = {};
      final Map<String, Future<Map<String, dynamic>>> productCache = {};
      final Map<String, Future<Map<String, dynamic>>> tailorCache = {};

      Future<Map<String, dynamic>> getRetailer(String id) {
        if (id.isEmpty) return Future.value({'shopName': 'Retailer'});
        return retailerCache.putIfAbsent(id, () async {
          try {
            final doc = await _db.collection('Retailer').doc(id).get();
            return doc.data() ?? {'shopName': 'Retailer'};
          } catch (e) {
            debugPrint('OrderService: Error fetching retailer $id: $e');
            return {'shopName': 'Retailer'};
          }
        });
      }

      Future<Map<String, dynamic>> getProduct(String id) {
        if (id.isEmpty) return Future.value({});
        return productCache.putIfAbsent(id, () async {
          try {
            final doc = await _db.collection('Products').doc(id).get();
            return doc.data() ?? {};
          } catch (e) {
            debugPrint('OrderService: Error fetching product $id: $e');
            return {};
          }
        });
      }

      Future<Map<String, dynamic>> getTailor(String id) {
        if (id.isEmpty) return Future.value({'name': 'Tailor'});
        return tailorCache.putIfAbsent(id, () async {
          try {
            final doc = await _db.collection('Tailor').doc(id).get();
            return doc.data() ?? {'name': 'Tailor'};
          } catch (e) {
            debugPrint('OrderService: Error fetching tailor $id: $e');
            return {'name': 'Tailor'};
          }
        });
      }

      try {
        final List<Map<String, dynamic>> results = await Future.wait(snap.docs.map((doc) async {
          try {
            final order = _orderFromSnap(doc);
            final orderId = doc.id;

            // 1. Concurrent fetching of Sub-orders, Tailor-jobs, and Reviews.
            final futures = await Future.wait([
              _db.collection(_subOrdersCollection).where('orderId', isEqualTo: orderId).get(),
              _db.collection(_tailorJobsCollection).where('orderId', isEqualTo: orderId).get(),
              _db.collection(_reviewsCollection).where('orderId', isEqualTo: orderId).get(),
            ]);

            final subSnap = futures[0] as QuerySnapshot<Map<String, dynamic>>;
            final tailorSnap = futures[1] as QuerySnapshot<Map<String, dynamic>>;
            final reviewSnap = futures[2] as QuerySnapshot<Map<String, dynamic>>;

            // 2. Process Sub-orders and items in parallel.
            final subOrdersWithDetails = await Future.wait(subSnap.docs.map((sDoc) async {
              try {
                var so = _subOrderFromSnap(sDoc);
                final retailerId = so.retailerId;

                // Resolve Supplier metadata (using cache).
                final retailerData = await getRetailer(retailerId);

                // Fetch items for this sub-order.
                final iSnap = await _db
                    .collection(_orderItemsCollection)
                    .where('subOrderId', isEqualTo: sDoc.id)
                    .get();
                
                // Pre-fetch Product specifications for all items in parallel.
                final itemsWithProducts = await Future.wait(iSnap.docs.map((iDoc) async {
                  try {
                    final item = OrderItem.fromJson({...iDoc.data(), 'id': iDoc.id});
                    final productData = await getProduct(item.productId);
                    
                    return {
                      'item': item,
                      'product': productData,
                    };
                  } catch (e) {
                    debugPrint('OrderService: Error processing item ${iDoc.id}: $e');
                    return null;
                  }
                }));

                return {
                  'subOrder': so,
                  'retailer': retailerData,
                  'items': itemsWithProducts.whereType<Map<String, dynamic>>().toList(),
                };
              } catch (e) {
                debugPrint('OrderService: Error processing suborder ${sDoc.id}: $e');
                return null;
              }
            }));

            // 3. Process Artisans (Tailor) assignments in parallel.
            final tailorJobsWithDetails = await Future.wait(tailorSnap.docs.map((tDoc) async {
              try {
                var tj = TailorJob.fromJson({...tDoc.data(), 'id': tDoc.id});
                final tailorId = tj.tailorId;

                // Resolve Artisan name (using cache).
                final tailorData = await getTailor(tailorId);

                // Access body measurements linked to the service request.
                Measurement? meas;
                if (tj.measurementId.isNotEmpty) {
                  final mDoc = await _db.collection('Measurement').doc(tj.measurementId).get();
                  if (mDoc.exists) {
                    meas = Measurement.fromJson({...mDoc.data()!, 'id': mDoc.id});
                  }
                }

                return {
                  'job': tj,
                  'tailor': tailorData,
                  'measurement': meas,
                  // `designIds` holds Design document ids, not image URLs.
                  // The tailor's stream already resolved these; the customer's
                  // did not, so the customer could never see the reference
                  // images they themselves had uploaded.
                  'designUrls': await _resolveDesignUrls(tj.designIds),
                };
              } catch (e) {
                debugPrint('OrderService: Error processing tailorjob ${tDoc.id}: $e');
                return null;
              }
            }));

            final reviews = reviewSnap.docs.map((rDoc) {
              try {
                return Review.fromJson({...rDoc.data(), 'id': rDoc.id});
              } catch (e) {
                debugPrint('OrderService: Error parsing review ${rDoc.id}: $e');
                return null;
              }
            }).whereType<Review>().toList();

            final validTailorJobs = tailorJobsWithDetails.whereType<Map<String, dynamic>>().toList();

            // Newest first. An order gets a SECOND Tailor-job whenever a
            // tailor declines or a quote is turned down and the customer
            // hires someone else, and Firestore returns them in no
            // particular order — so `.first` here (and `Order.tailorJobs
            // .first` in statusText) could just as easily be the dead job,
            // showing the rejected tailor's name and status on a live order.
            validTailorJobs.sort((a, b) {
              final aDate = (a['job'] as TailorJob).requestedAt;
              final bDate = (b['job'] as TailorJob).requestedAt;
              if (aDate == null || bDate == null) return 0;
              return bDate.compareTo(aDate);
            });

            // Convenience link for Artisan name.
            if (validTailorJobs.isNotEmpty) {
              final firstJob = validTailorJobs.first;
              final tData = firstJob['tailor'] as Map<String, dynamic>?;
              order.tailorName = tData?['name'];
            }

            return {
              'order': order,
              'subOrders': subOrdersWithDetails.whereType<Map<String, dynamic>>().toList(),
              'tailorJobs': validTailorJobs,
              'reviews': reviews,
            };
          } catch (e) {
            debugPrint('OrderService: Critical error processing order ${doc.id}: $e');
            return <String, dynamic>{};
          }
        }));

        final validResults = results.where((r) => r.isNotEmpty).toList();
        validResults.sort((a, b) {
          try {
            final orderA = a['order'] as Order;
            final orderB = b['order'] as Order;
            return orderB.orderDate.compareTo(orderA.orderDate);
          } catch (e) {
            return 0;
          }
        });
        return validResults;
      } catch (e) {
        debugPrint('OrderService: Global error in streamDetailedCustomerOrders: $e');
        return <Map<String, dynamic>>[];
      }
    });
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


  /// Streams real-time orders for a specific customer.
  Stream<List<Order>> streamCustomerOrders(String customerId) {
    final cleanId = customerId.trim();


    return _db
        .collection(_ordersCollection)
        .where('customerId', isEqualTo: cleanId)
        // No orderBy: combining it with the equality filter would need a
        // composite index, and the list is sorted in memory below anyway.
        .snapshots()
        .asyncMap((snapshot) async {
      final List<Order> orders = [];
      
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          Order order = Order.fromJson({...data, 'id': doc.id});
          
          // Deep fetch details...
          final subOrdersSnap = await _db
              .collection(_subOrdersCollection)
              .where('orderId', isEqualTo: order.id)
              .get();
          
          List<SubOrder> subOrders = subOrdersSnap.docs
              .map((d) => SubOrder.fromJson({...d.data(), 'id': d.id}))
              .toList();


          final tailorJobSnap = await _db
              .collection(_tailorJobsCollection)
              .where('orderId', isEqualTo: order.id)
              .get();
          
          List<TailorJob> tailorJobs = tailorJobSnap.docs
              .map((d) => TailorJob.fromJson({...d.data(), 'id': d.id}))
              .toList();

          // Newest first — `Order.statusText` and the tailor-name lookup
          // below both read `.first`, and a re-hired order has more than
          // one job with no guaranteed Firestore ordering.
          tailorJobs.sort((a, b) {
            final aDate = a.requestedAt;
            final bDate = b.requestedAt;
            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate);
          });


          String? tailorName;
          if (tailorJobs.isNotEmpty) {
            final tDoc = await _db.collection('Tailor').doc(tailorJobs.first.tailorId).get();
            if (tDoc.exists) {
              tailorName = tDoc.data()?['name'] as String?;
            }
          }


          orders.add(order.copyWith(
            subOrders: subOrders, 
            tailorJobs: tailorJobs,
            tailorName: tailorName,
          ));
        } catch (e) {
          debugPrint('Error parsing order ${doc.id}: $e');
        }
      }


      // Sort in memory instead of database to avoid index errors
      orders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      
      return orders;
    });
  }


  // ─── streamOrderTimeline ───────────────────────────────────────────────────


  /// Provides a real-time stream of the order lifecycle status for tracking.
  Stream<Map<String, dynamic>> streamOrderTimeline(String orderId) {
    // Combine snapshots from Order, its Sub-orders, and Tailor-job
    return _db.collection(_ordersCollection).doc(orderId).snapshots().asyncMap((orderSnap) async {
      if (!orderSnap.exists) return {};


      final order = Order.fromJson({...orderSnap.data()!, 'id': orderSnap.id});
      
      // Fetch customer profile
      final customerDoc = await _db.collection('Customer').doc(order.customerId).get();
      final customerProfile = customerDoc.exists 
          ? Customer.fromJson({...customerDoc.data()!, 'id': customerDoc.id}) 
          : null;


      // Fetch sub-orders
      final subOrdersSnap = await _db
          .collection(_subOrdersCollection)
          .where('orderId', isEqualTo: orderId)
          .get();
      
      final List<SubOrder> subOrders = [];
      final Map<String, String> productNames = {};
      final Map<String, String> partyNames = {};


      for (var doc in subOrdersSnap.docs) {
        final so = SubOrder.fromJson({...doc.data(), 'id': doc.id});
        
        // Fetch order items for this sub-order to get product names
        final itemsSnap = await _db
            .collection(_orderItemsCollection)
            .where('subOrderId', isEqualTo: so.id)
            .get();
        
        final List<OrderItem> items = [];
        for (var itemDoc in itemsSnap.docs) {
          final item = OrderItem.fromJson({...itemDoc.data(), 'id': itemDoc.id});
          items.add(item);
          
          if (!productNames.containsKey(item.productId)) {
            final pDoc = await _db.collection('Products').doc(item.productId).get();
            if (pDoc.exists) {
              productNames[item.productId] = pDoc.data()?['productName'] ?? 'Product';
            }
          }
        }
        so.items = items;
        subOrders.add(so);


        // Fetch retailer name
        if (!partyNames.containsKey(so.retailerId)) {
          final rDoc = await _db.collection('Retailer').doc(so.retailerId).get();
          if (rDoc.exists) {
            partyNames[so.retailerId] = rDoc.data()?['shopName'] ?? 'Retailer';
          }
        }
      }


      // Fetch tailor job — NEWEST first. `.limit(1)` with no ordering let
      // Firestore hand back whichever job it liked, so a re-hired order
      // could render the declined tailor's name and status on its timeline.
      final tailorJobSnap = await _db
          .collection(_tailorJobsCollection)
          .where('orderId', isEqualTo: orderId)
          .get();

      final tailorJobs = tailorJobSnap.docs
          .map((d) => TailorJob.fromJson({...d.data(), 'id': d.id}))
          .toList()
        ..sort((a, b) {
          final ad = a.requestedAt;
          final bd = b.requestedAt;
          if (ad == null || bd == null) return 0;
          return bd.compareTo(ad);
        });

      final tailorJob = tailorJobs.isNotEmpty ? tailorJobs.first : null;


      if (tailorJob != null) {
        if (!partyNames.containsKey(tailorJob.tailorId)) {
          final tDoc = await _db.collection('Tailor').doc(tailorJob.tailorId).get();
          if (tDoc.exists) {
            partyNames[tailorJob.tailorId] = tDoc.data()?['name'] ?? 'Tailor';
          }
        }
      }


      return {
        'order': order,
        'subOrders': subOrders,
        'tailorJob': tailorJob,
        'partyNames': partyNames,
        'productNames': productNames,
        'customer': customerProfile,
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
    /* 
    // PREVIOUS SEQUENTIAL VERSION (Slower)
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

        if (itemsList.isEmpty) continue;

        detailedOrders.add({
          'subOrder': {...subOrderData, 'id': subOrderId},
          'order': {...orderData, 'id': orderId},
          'customer': customerData,
          'items': itemsList,
        });
      }
      return detailedOrders;
    });
    */

    // OPTIMIZED PARALLEL VERSION
    return _db
        .collection(_subOrdersCollection)
        .where('retailerId', isEqualTo: retailerId)
        .snapshots()
        .asyncMap((subOrdersSnap) async {
      // Internal caches to avoid redundant fetches within the same snapshot update
      final Map<String, Map<String, dynamic>> orderCache = {};
      final Map<String, Map<String, dynamic>> customerCache = {};
      final Map<String, Map<String, dynamic>> productCache = {};
      final Map<String, String?> tailorNameCache = {};
      final Map<String, String?> tailorAddressCache = {}; // #6: tailor's physical address
      // #23: cache reviews keyed by "orderId_retailerId" to avoid re-fetching
      final Map<String, Map<String, dynamic>?> reviewCache = {};

      // Process all sub-orders in parallel
      final List<Map<String, dynamic>?> results = await Future.wait(
        subOrdersSnap.docs.map((subOrderDoc) async {
          try {
            final subOrderData = subOrderDoc.data();
            final String subOrderId = subOrderDoc.id;
            final String orderId = subOrderData['orderId'];

            // 1. Fetch parent order (with cache)
            if (!orderCache.containsKey(orderId)) {
              final doc = await _db.collection(_ordersCollection).doc(orderId).get();
              if (doc.exists) orderCache[orderId] = doc.data()!;
            }
            final orderData = orderCache[orderId];
            if (orderData == null) return null;

            final String customerId = orderData['customerId'];

            // 2. Fetch customer and order items in parallel
            final futures = await Future.wait([
              // Fetch customer (with cache)
              (() async {
                if (!customerCache.containsKey(customerId)) {
                  final doc = await _db.collection('Customer').doc(customerId).get();
                  if (doc.exists) customerCache[customerId] = doc.data()!;
                }
                return customerCache[customerId];
              })(),
              // Fetch items query
              _db.collection(_orderItemsCollection).where('subOrderId', isEqualTo: subOrderId).get(),
              // Fetch tailor name if needed (with cache)
              (() async {
                if (subOrderData['deliveryDestination'] == 'tailor') {
                  if (!tailorNameCache.containsKey(orderId)) {
                    final jobSnap = await _db.collection(_tailorJobsCollection)
                        .where('orderId', isEqualTo: orderId).limit(1).get();
                    if (jobSnap.docs.isNotEmpty) {
                      final tId = jobSnap.docs.first.data()['tailorId'];
                      final tDoc = await _db.collection('Tailor').doc(tId).get();
                      tailorNameCache[orderId] = tDoc.data()?['name'];
                      // #6: capture address at the same time — zero extra reads
                      tailorAddressCache[orderId] = tDoc.data()?['address'];
                    } else {
                      tailorNameCache[orderId] = null;
                      tailorAddressCache[orderId] = null;
                    }
                  }
                  return tailorNameCache[orderId];
                }
                return null;
              })(),
            ]);

            final customerData = futures[0] as Map<String, dynamic>?;
            final itemsSnap = futures[1] as QuerySnapshot<Map<String, dynamic>>;
            final tailorName = futures[2] as String?;

            if (customerData == null || itemsSnap.docs.isEmpty) return null;

            // 3. Fetch all products for items in parallel
            final List<Map<String, dynamic>> itemsList = await Future.wait(
              itemsSnap.docs.map((itemDoc) async {
                final itemData = itemDoc.data();
                final String productId = itemData['productId'];
                final int optionId = itemData['optionId'];

                if (!productCache.containsKey(productId)) {
                  final doc = await _db.collection('Products').doc(productId).get();
                  if (doc.exists) productCache[productId] = doc.data()!;
                }
                
                final productData = productCache[productId];
                if (productData == null) return null;

                final List<dynamic> colorOptions = productData['colorOptions'] ?? [];
                final option = colorOptions.firstWhere(
                  (o) => o['optionId'] == optionId,
                  orElse: () => null,
                );

                final rawImages = (option?['image'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final resolvedImages = resolveImageUrls(rawImages);

                return {
                  'name': productData['productName'] ?? 'Unknown Product',
                  'quantity': itemData['quantity'] ?? 1,
                  'price': (option?['price'] ?? 0).toDouble(),
                  'imagePath': resolvedImages.isNotEmpty ? resolvedImages.first : '',
                  'color': option?['color'] ?? 'N/A',
                  'description': productData['description'] ?? '',
                  'careSymbol': productData['careSymbol'] ?? [],
                };
              }),
            ).then((list) => list.whereType<Map<String, dynamic>>().toList());

            if (itemsList.isEmpty) return null;

            // #23: for delivered orders, look up the customer's review so
            // the retailer card can show the star rating.
            Map<String, dynamic>? reviewData;
            if ((subOrderData['status'] ?? '') == 'delivered') {
              final cacheKey = '${orderId}_$retailerId';
              if (!reviewCache.containsKey(cacheKey)) {
                final reviewSnap = await _db
                    .collection('Reviews')
                    .where('targetId', isEqualTo: retailerId)
                    .where('targetRole', isEqualTo: 'retailer')
                    .where('orderId', isEqualTo: orderId)
                    .limit(1)
                    .get();
                reviewCache[cacheKey] = reviewSnap.docs.isNotEmpty
                    ? reviewSnap.docs.first.data()
                    : null;
              }
              reviewData = reviewCache[cacheKey];
            }

            return {
              'subOrder': {...subOrderData, 'id': subOrderId},
              'order': {...orderData, 'id': orderId},
              'customer': customerData,
              'items': itemsList,
              'tailorName': tailorName,
              // #6: include tailor's address so the screen can display it
              // when deliveryDestination == 'tailor'
              'tailorAddress': tailorAddressCache[orderId],
              // #23: customer's review for this retailer on this order
              'reviewRating': reviewData?['rating'],
              'reviewComment': reviewData?['comment'],
            };
          } catch (e) {
            debugPrint("OrderService: Error processing sub-order: $e");
            return null;
          }
        }),
      );

      return results.whereType<Map<String, dynamic>>().toList();
    });
  }

  /// Updates the status of a sub-order and synchronizes it with the parent order based on business rules.
  Future<void> updateOrderStatus(String subOrderId, String newStatus, {String? parentOrderId}) async {
    try {
      final statusLower = newStatus.toLowerCase();
      
      // Fetch sub-order metadata to check destination
      final subOrderDoc = await _db.collection(_subOrdersCollection).doc(subOrderId).get();
      if (!subOrderDoc.exists) throw Exception("Sub-order $subOrderId not found");
      
      final subOrderData = subOrderDoc.data()!;
      final String orderId = parentOrderId ?? subOrderData['orderId'];
      final String destination = (subOrderData['deliveryDestination'] ?? 'customer').toString().toLowerCase();

      final batch = _db.batch();
      
      // 1. Prepare updates for sub-order
      final Map<String, dynamic> subOrderUpdates = {
        'status': statusLower,
      };
      if (statusLower == 'delivered') {
        // Timestamp, not an ISO string — `orderDate` and the rest of the
        // Sub-order dates are Timestamps, and mixing the two shapes in one
        // field means every reader has to guess.
        subOrderUpdates['deliveryDate'] = Timestamp.now();
      }
      batch.update(_db.collection(_subOrdersCollection).doc(subOrderId), subOrderUpdates);
      
      // 2. Parent Order status.
      //
      // An order fans out into one sub-order per retailer, so it is only
      // finished once EVERY one of them has reached the customer. Deciding
      // this from the single sub-order being written marked a half-shipped
      // two-retailer order 'completed' as soon as the first retailer
      // delivered — and the second retailer's next status write then
      // dragged it back to 'processing'.
      //
      // Sub-orders routed to a tailor never complete the order here at all:
      // that order finishes when the tailor marks the work done, in
      // updateWorkProgress().
      final orderRef = _db.collection(_ordersCollection).doc(orderId);
      final orderSnap = await orderRef.get();
      final currentOrderStatus = orderSnap.data()?['status'] as String?;

      // 'completed' and 'cancelled' are terminal — never walk them back.
      //
      // The three tailoring statuses are owned by the customer's tailoring
      // flow (TailoringService), NOT by the retailer. Overwriting them here
      // with 'processing' dropped the order out of activeOrderStatuses and
      // therefore off Running Orders, so a retailer marking 'Preparing' or
      // 'Packed' before the customer had chosen tailor-or-skip left that
      // order unreachable: the customer could no longer make the choice, and
      // because deliveryDestination stayed 'pending' the retailer could
      // never mark it Delivered either.
      const tailoringOwnedStatuses = {
        'awaiting_confirmation',
        'awaiting_tailor_search',
        'tailor_pending',
      };

      if (currentOrderStatus != OrderStatus.completed.toValue &&
          currentOrderStatus != OrderStatus.cancelled.toValue &&
          !tailoringOwnedStatuses.contains(currentOrderStatus)) {
        final siblings = await _db
            .collection(_subOrdersCollection)
            .where('orderId', isEqualTo: orderId)
            .get();

        final allDeliveredToCustomer = siblings.docs.isNotEmpty &&
            siblings.docs.every((doc) {
              final data = doc.data();
              // This sub-order's own write is still sitting in the batch, so
              // read the pending value for it rather than the stale stored one.
              final siblingStatus = doc.id == subOrderId
                  ? statusLower
                  : (data['status'] ?? '').toString().toLowerCase();
              final siblingDestination =
                  (data['deliveryDestination'] ?? 'customer')
                      .toString()
                      .toLowerCase();
              return siblingStatus == 'delivered' &&
                  siblingDestination == 'customer';
            });

        batch.update(orderRef, {
          'status': allDeliveredToCustomer
              ? OrderStatus.completed.toValue
              : OrderStatus.processing.toValue,
        });
      }

      await batch.commit();

      // Only the customer's own delivery is worth telling them about; a
      // sub-order handed to the tailor is an internal hop.
      if (statusLower == 'delivered' && destination == 'customer') {
        await _notifyCustomerOfDelivery(
          orderId: orderId,
          retailerId: subOrderData['retailerId'] as String?,
        );
      }

      // A tailor-bound hop is internal to the customer, but it is the whole
      // story for the tailor: they cannot start until the last sub-order
      // lands, and nothing used to tell them it had.
      if (statusLower == 'delivered' && destination == 'tailor') {
        await _notifyTailorMaterialsArrived(orderId: orderId);
      }
    } catch (e) {
      debugPrint('Error updating order status for $subOrderId: $e');
      rethrow;
    }
  }

  /// Best-effort "your order was delivered" notification. The status write
  /// has already committed, so failures here are logged and swallowed.
  Future<void> _notifyCustomerOfDelivery({
    required String orderId,
    required String? retailerId,
  }) async {
    try {
      final orderSnap =
          await _db.collection(_ordersCollection).doc(orderId).get();
      final customerId = orderSnap.data()?['customerId'] as String?;
      if (customerId == null) return;

      String shopName = 'the shop';
      if (retailerId != null) {
        final snap = await _db.collection('Retailer').doc(retailerId).get();
        final name = (snap.data()?['shopName'] as String?)?.trim();
        if (name != null && name.isNotEmpty) shopName = name;
      }

      await NotificationService().notifyCustomerOrderDelivered(
        customerId,
        orderId,
        shopName,
        'retailer',
      );
    } catch (e) {
      debugPrint('Error sending delivery notification: $e');
    }
  }

  /// Best-effort "all your materials are here" notification, raised only once
  /// every tailor-bound sub-order on the order reads 'delivered' — the same
  /// condition the tailor's own `materialsReceived` flag is computed from.
  /// The service dedupes per job, so a re-run after the last arrival is safe.
  Future<void> _notifyTailorMaterialsArrived({required String orderId}) async {
    try {
      final subs = await _db
          .collection(_subOrdersCollection)
          .where('orderId', isEqualTo: orderId)
          .get();

      final allArrived = subs.docs.isNotEmpty &&
          subs.docs.every((d) {
            final data = d.data();
            return (data['status'] ?? '').toString().toLowerCase() ==
                    'delivered' &&
                (data['deliveryDestination'] ?? '').toString().toLowerCase() ==
                    'tailor';
          });
      if (!allArrived) return;

      final jobSnap = await _db
          .collection(_tailorJobsCollection)
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();
      final tailorId = jobSnap.docs.isEmpty
          ? null
          : jobSnap.docs.first.data()['tailorId'] as String?;
      if (tailorId == null) return;

      final orderSnap =
          await _db.collection(_ordersCollection).doc(orderId).get();
      final customerId = orderSnap.data()?['customerId'] as String?;

      String customerName = 'the customer';
      if (customerId != null) {
        final snap = await _db.collection('Customer').doc(customerId).get();
        final name = (snap.data()?['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) customerName = name;
      }

      await NotificationService()
          .notifyTailorMaterialsArrived(tailorId, orderId, customerName);
    } catch (e) {
      debugPrint('Error sending materials-arrived notification: $e');
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
    String tailorJobId,
    double servicePrice,
    DateTime estimatedDate, {
    double? deliveryCharge,
  }) async {
    try {
      final jobDoc = await _db.collection(_tailorJobsCollection).doc(tailorJobId).get();
      if (!jobDoc.exists) throw Exception('Tailor job not found');
      final jobData = jobDoc.data()!;
      final orderId = jobData['orderId'];

      // The customer's device is the only scheduler this project has, so a
      // lapsed 12h window may not have been swept yet. Enforce it here too,
      // otherwise a tailor who opens the app two days late can still quote
      // an order the customer has already moved on from.
      final quoteDeadline = _parseDate(jobData['quoteResponseDeadline']);
      final currentStatus =
          TailorJobStatus.fromValue(jobData['status'] as String? ?? '');
      if (currentStatus == TailorJobStatus.pending &&
          quoteDeadline != null &&
          DateTime.now().isAfter(quoteDeadline)) {
        throw Exception(
          'The 12-hour window to respond to this request has closed.',
        );
      }

      final batch = _db.batch();
      
      // 1. Update Tailor Job — the tailor is QUOTING, not confirming. The
      // job only reaches 'confirmed' once the customer accepts the quote and
      // pays, in TailoringService.confirmTailorJob(). Writing 'confirmed'
      // here used to skip the customer's confirm-and-pay step entirely, so
      // the tailor was never actually paid.
      batch.update(_db.collection(_tailorJobsCollection).doc(tailorJobId), {
        'status': TailorJobStatus.quoted.toValue,
        'quoteStatus': QuoteStatus.sent.toValue,
        'quoteAmount': servicePrice,
        if (deliveryCharge != null) 'deliveryCharge': deliveryCharge,
        'estimatedDeliveryDate': estimatedDate.toIso8601String(),
      });

      // 2. Parent Order stays 'tailor_pending' — the customer still has a
      // decision to make, so it must keep showing up as an active order.
      if (orderId != null) {
        batch.update(_db.collection(_ordersCollection).doc(orderId), {
          'status': OrderStatus.tailorPending.toValue,
        });
      }

      await batch.commit();

      // The customer has no other signal that a quote arrived — the
      // tailoring screen only re-reads the job when it is reopened.
      if (orderId != null) {
        await _notifyCustomerAboutTailor(
          orderId: orderId,
          tailorId: jobData['tailorId'] as String?,
          accepted: true,
        );
      }
    } catch (e) {
      debugPrint('Error accepting tailor job: $e');
      rethrow;
    }
  }

  /// Declines a tailor job request.
  Future<void> declineTailorJob(String tailorJobId, String reason) async {
    try {
      final jobDoc = await _db.collection(_tailorJobsCollection).doc(tailorJobId).get();
      if (!jobDoc.exists) throw Exception('Tailor job not found');
      final orderId = jobDoc.data()?['orderId'];

      final batch = _db.batch();

      // 1. Update Tailor Job
      batch.update(_db.collection(_tailorJobsCollection).doc(tailorJobId), {
        'status': TailorJobStatus.tailorDeclined.toValue,
        'rejectionReason': reason,
      });

      // 2. Hand the order back to the customer so they can pick someone
      // else. 'processing' is TERMINAL — it drops the order out of
      // OrderService.activeOrderStatuses and therefore off the Running
      // Orders screen, so one tailor declining used to permanently destroy
      // the customer's ability to hire ANY tailor for that order. They are
      // back to choosing a tailor, which is exactly 'awaiting_tailor_search'.
      if (orderId != null) {
        batch.update(_db.collection(_ordersCollection).doc(orderId), {
          'status': OrderStatus.awaitingTailorSearch.toValue,
        });

        // The fabric was pointed at this tailor when the job was created.
        // They said no, so it has no destination again until the customer
        // either picks another tailor or opts for direct delivery —
        // otherwise retailers keep being told to ship to a tailor who
        // declined the work.
        final subs = await _db
            .collection(_subOrdersCollection)
            .where('orderId', isEqualTo: orderId)
            .get();
        for (final doc in subs.docs) {
          batch.update(doc.reference, {
            'deliveryDestination': SubOrderDeliveryDestination.pending.name,
          });
        }
      }

      await batch.commit();

      if (orderId != null) {
        await _notifyCustomerAboutTailor(
          orderId: orderId,
          tailorId: jobDoc.data()?['tailorId'] as String?,
          accepted: false,
          reason: reason,
        );
      }
    } catch (e) {
      debugPrint('Error declining tailor job: $e');
      rethrow;
    }
  }

  /// Tells the customer that a tailor accepted (quoted) or declined their
  /// job. Best-effort: the status change is already committed, so a failed
  /// notification must not fail the tailor's action.
  Future<void> _notifyCustomerAboutTailor({
    required String orderId,
    required String? tailorId,
    required bool accepted,
    String reason = '',
  }) async {
    try {
      final orderSnap =
          await _db.collection(_ordersCollection).doc(orderId).get();
      final customerId = orderSnap.data()?['customerId'] as String?;
      if (customerId == null) return;

      String tailorName = 'the tailor';
      if (tailorId != null) {
        final snap = await _db.collection('Tailor').doc(tailorId).get();
        final name = (snap.data()?['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) tailorName = name;
      }

      final notifications = NotificationService();
      if (accepted) {
        // A quote is an offer, not a confirmation: the customer still has to
        // accept and pay. Sending "your order is confirmed" here hid the very
        // action they had to take.
        await notifications.notifyCustomerQuoteReceived(
          customerId,
          orderId,
          tailorName,
        );
      } else {
        await notifications.notifyCustomerOrderCancelled(
          customerId,
          orderId,
          tailorName,
          'tailor',
          reason.trim().isEmpty ? 'No reason given.' : reason.trim(),
        );
      }
    } catch (e) {
      debugPrint('Error sending tailor-decision notification: $e');
    }
  }

  /// Updates work progress for a tailor job.
  Future<void> updateWorkProgress(String tailorJobId, TailorJobStatus status) async {
    try {
      final jobDoc = await _db.collection(_tailorJobsCollection).doc(tailorJobId).get();
      if (!jobDoc.exists) throw Exception('Tailor job not found');
      final orderId = jobDoc.data()?['orderId'];

      final batch = _db.batch();

      // 1. Update Tailor Job — written through the enum so the value
      // round-trips via TailorJobStatus.fromValue everywhere else (e.g. the
      // customer's order-tracking screen), instead of a raw string that
      // isn't recognized there and silently falls back to 'pending'.
      batch.update(_db.collection(_tailorJobsCollection).doc(tailorJobId), {
        'status': status.toValue,
        // Nothing recorded when the work actually finished, so the tailor's
        // completed list fell back to `confirmedAt` — the date the customer
        // paid, not the date the job was done.
        if (status == TailorJobStatus.jobCompleted)
          'completedAt': DateTime.now().toIso8601String(),
      });

      // 2. Update parent Order
      if (orderId != null) {
        batch.update(_db.collection(_ordersCollection).doc(orderId), {
          'status': status == TailorJobStatus.jobCompleted
              ? OrderStatus.completed.toValue
              : OrderStatus.processing.toValue,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error updating work progress: $e');
      rethrow;
    }
  }

  /// Revises a job's price and/or estimated delivery date after the initial
  /// quote was sent.
  ///
  /// Both are optional because the two have different lifetimes: the PRICE
  /// is only negotiable while the customer has not yet accepted and paid
  /// (job still 'quoted'), whereas the DATE can be corrected right up until
  /// the work is marked finished. Passing null leaves that field alone.
  ///
  /// Guarded server-side rather than trusting the screen: a stale sheet must
  /// not be able to re-price a job the customer has already paid for.
  Future<void> editStitchingTerms(
    String tailorJobId, {
    double? newPrice,
    DateTime? newDate,
  }) async {
    if (newPrice == null && newDate == null) return;
    try {
      final ref = _db.collection(_tailorJobsCollection).doc(tailorJobId);
      final snap = await ref.get();
      if (!snap.exists) throw Exception('Tailor job not found');

      final status =
          TailorJobStatus.fromValue(snap.data()?['status'] as String? ?? '');

      if (newPrice != null && status != TailorJobStatus.quoted) {
        throw Exception(
          'The price can only be changed until the customer confirms and pays.',
        );
      }
      if (newDate != null &&
          (status == TailorJobStatus.jobCompleted ||
              Order.deadJobStatuses.contains(status))) {
        throw Exception('This job is finished — its date can no longer change.');
      }

      await ref.update({
        if (newPrice != null) 'quoteAmount': newPrice,
        if (newDate != null) 'estimatedDeliveryDate': newDate.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error editing stitching terms: $e');
      rethrow;
    }
  }

  /// `Tailor-jobs` carries dates as ISO strings from `TailorJob.toJson` and
  /// as Timestamps from the quote writes, so reads have to survive both.
  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
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
      final jobDoc = await _db.collection(_tailorJobsCollection).doc(tailorJobId).get();
      if (!jobDoc.exists) throw Exception('Tailor job not found');
      final orderId = jobDoc.data()?['orderId'];

      final batch = _db.batch();

      // 1. Update Tailor Job
      batch.update(_db.collection(_tailorJobsCollection).doc(tailorJobId), {
        'status': status.toValue,
      });

      // 2. Update Parent Order
      if (orderId != null) {
        batch.update(_db.collection(_ordersCollection).doc(orderId), {
          'status': _mapTailorJobToOrderStatus(status.toValue).toValue,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error updating tailor job status: $e');
      rethrow;
    }
  }

  OrderStatus _mapTailorJobToOrderStatus(String tailorJobStatus) {
    if (tailorJobStatus.toLowerCase() == 'completed') {
      return OrderStatus.completed;
    }
    return OrderStatus.processing;
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
      final jobDoc = await _db.collection(_tailorJobsCollection).doc(tailorJobId).get();
      if (!jobDoc.exists) throw Exception('Tailor job not found');
      final orderId = jobDoc.data()?['orderId'];

      final status = response == QuoteStatus.accepted 
          ? TailorJobStatus.confirmed 
          : TailorJobStatus.rejected;
          
      final batch = _db.batch();

      // 1. Update Tailor Job
      batch.update(_db.collection(_tailorJobsCollection).doc(tailorJobId), {
        'quoteStatus': response.toValue,
        'status': status.toValue,
        if (response == QuoteStatus.accepted) 'confirmedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Parent Order
      if (orderId != null) {
        batch.update(_db.collection(_ordersCollection).doc(orderId), {
          'status': _mapTailorJobToOrderStatus(status.toValue).toValue,
        });
      }

      await batch.commit();
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

  /// Streams detailed jobs for a specific tailor.
  /// Maps `Design` document ids to their uploaded `designFile` URLs,
  /// dropping any id that no longer resolves to a readable image.
  Future<List<String>> _resolveDesignUrls(List<String> designIds) async {
    if (designIds.isEmpty) return const [];
    try {
      final docs = await Future.wait(
        designIds.map((id) => _db.collection('Design').doc(id).get()),
      );
      return docs
          .map((d) => d.data()?['designFile'] as String?)
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('OrderService: Error resolving design urls: $e');
      return const [];
    }
  }

  Stream<List<Map<String, dynamic>>> streamDetailedTailorOrders(String tailorId) {
    return _db
        .collection(_tailorJobsCollection)
        .where('tailorId', isEqualTo: tailorId)
        .snapshots()
        .asyncMap((jobsSnap) async {
      final Map<String, Map<String, dynamic>> orderCache = {};
      final Map<String, Map<String, dynamic>> customerCache = {};
      final Map<String, Map<String, dynamic>> productCache = {};
      final Map<String, Map<String, dynamic>> measurementCache = {};
      // Reviews the customer left for THIS tailor, keyed by orderId — same
      // pattern as streamDetailedRetailerOrders, which the retailer screen
      // already uses to show star ratings on delivered cards.
      final Map<String, Map<String, dynamic>?> reviewCache = {};

      final List<Map<String, dynamic>?> results = await Future.wait(
        jobsSnap.docs.map((jobDoc) async {
          try {
            final jobData = jobDoc.data();
            final String orderId = jobData['orderId'];
            final String customerId = jobData['customerId'] ?? ''; // Might be in Order doc instead
            final String measurementId = jobData['measurementId'] ?? '';

            // 1. Fetch parent order
            if (!orderCache.containsKey(orderId)) {
              final doc = await _db.collection(_ordersCollection).doc(orderId).get();
              if (doc.exists) orderCache[orderId] = doc.data()!;
            }
            final orderData = orderCache[orderId];
            if (orderData == null) return null;

            final actualCustomerId = customerId.isNotEmpty ? customerId : orderData['customerId'];

            // 2. Fetch customer, measurement and sub-orders in parallel
            final futures = await Future.wait([
              // Fetch customer
              (() async {
                if (!customerCache.containsKey(actualCustomerId)) {
                  final doc = await _db.collection('Customer').doc(actualCustomerId).get();
                  if (doc.exists) customerCache[actualCustomerId] = doc.data()!;
                }
                return customerCache[actualCustomerId];
              })(),
              // Fetch measurement
              (() async {
                if (measurementId.isNotEmpty && !measurementCache.containsKey(measurementId)) {
                  final doc = await _db.collection('Measurement').doc(measurementId).get();
                  if (doc.exists) measurementCache[measurementId] = doc.data()!;
                }
                return measurementCache[measurementId];
              })(),
              // Fetch sub-orders for this main order
              _db.collection(_subOrdersCollection).where('orderId', isEqualTo: orderId).get(),
            ]);

            final customerData = futures[0] as Map<String, dynamic>?;
            final measurementData = futures[1] as Map<String, dynamic>?;
            final subOrdersSnap = futures[2] as QuerySnapshot<Map<String, dynamic>>;

            if (customerData == null) return null;

            // 3. Fetch all items for all sub-orders in parallel
            final List<Map<String, dynamic>> allItemsList = [];
            
            final subOrderResults = await Future.wait(
              subOrdersSnap.docs.map((soDoc) async {
                final soId = soDoc.id;
                final itemsSnap = await _db
                    .collection(_orderItemsCollection)
                    .where('subOrderId', isEqualTo: soId)
                    .get();
                
                return Future.wait(itemsSnap.docs.map((itemDoc) async {
                  final itemData = itemDoc.data();
                  final String productId = itemData['productId'];
                  final int optionId = itemData['optionId'];

                  if (!productCache.containsKey(productId)) {
                    final doc = await _db.collection('Products').doc(productId).get();
                    if (doc.exists) productCache[productId] = doc.data()!;
                  }
                  
                  final productData = productCache[productId];
                  if (productData == null) return null;

                  final List<dynamic> colorOptions = productData['colorOptions'] ?? [];
                  final option = colorOptions.firstWhere(
                    (o) => o['optionId'] == optionId,
                    orElse: () => null,
                  );

                  final rawImages = (option?['image'] as List?)?.map((e) => e.toString()).toList() ?? [];
                  final resolvedImages = resolveImageUrls(rawImages);

                  return {
                    'name': productData['productName'] ?? 'Unknown Product',
                    'quantity': itemData['quantity'] ?? 1,
                    'price': (option?['price'] ?? 0).toDouble(),
                    'imagePath': resolvedImages.isNotEmpty ? resolvedImages.first : '',
                    'color': option?['color'] ?? 'N/A',
                    'description': productData['description'] ?? '',
                    'careSymbol': productData['careSymbol'] ?? [],
                    'instructions': jobData['specialInstructions'] ?? '',
                  };
                }));
              })
            );

            for (var list in subOrderResults) {
              allItemsList.addAll(list.whereType<Map<String, dynamic>>());
            }

            if (allItemsList.isEmpty) {
              return null;
            }

            // `Tailor-jobs.designIds` holds Design document ids, not image
            // URLs — resolve them here so the tailor's screen has something
            // it can actually render.
            final designUrls = await _resolveDesignUrls(
              List<String>.from(jobData['designIds'] ?? []),
            );

            // Once the work is done the customer can rate the tailor. The
            // tailor's screen has a "Customer Feedback" block for exactly
            // this, but nothing ever fetched the review, so it never showed.
            Map<String, dynamic>? reviewData;
            if ((jobData['status'] ?? '') == 'completed') {
              if (!reviewCache.containsKey(orderId)) {
                final reviewSnap = await _db
                    .collection(_reviewsCollection)
                    .where('targetId', isEqualTo: tailorId)
                    .where('targetRole', isEqualTo: 'tailor')
                    .where('orderId', isEqualTo: orderId)
                    .limit(1)
                    .get();
                reviewCache[orderId] = reviewSnap.docs.isNotEmpty
                    ? reviewSnap.docs.first.data()
                    : null;
              }
              reviewData = reviewCache[orderId];
            }

            // Has the fabric physically reached the tailor? Every sub-order
            // on this order is routed to them, so the work can only start
            // once all of them read 'delivered'. Without this the tailor
            // could mark a job in progress — and then finished, which
            // completes the whole order — before a single retailer had
            // shipped anything.
            final materialsReceived = subOrdersSnap.docs.isNotEmpty &&
                subOrdersSnap.docs.every((d) {
                  final data = d.data();
                  final status =
                      (data['status'] ?? '').toString().toLowerCase();
                  final destination =
                      (data['deliveryDestination'] ?? '').toString().toLowerCase();
                  return status == 'delivered' && destination == 'tailor';
                });

            return {
              'job': {...jobData, 'id': jobDoc.id},
              'order': {...orderData, 'id': orderId},
              'customer': customerData,
              'measurement': measurementData,
              'items': allItemsList,
              'designUrls': designUrls,
              'materialsReceived': materialsReceived,
              'reviewRating': reviewData?['rating'],
              'reviewComment': reviewData?['comment'],
            };
          } catch (e) {
            debugPrint("OrderService: Error processing tailor job: $e");
            return null;
          }
        }),
      );

      return results.whereType<Map<String, dynamic>>().toList();
    });
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

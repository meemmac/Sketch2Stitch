import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order.dart';
import '../models/sub_order.dart';
import '../models/tailor_job.dart';
import '../models/user_role.dart';


class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;


  final FirebaseFirestore _db;


  // ─── Order Tracking ────────────────────────────────────────────────────────


  /// Streams a single order document.
  Stream<Order?> streamOrder(String orderId) {
    return _db.collection('Orders').doc(orderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      
      // Convert Timestamps to ISO strings for the Model
      if (data['orderDate'] is Timestamp) {
        data['orderDate'] = (data['orderDate'] as Timestamp).toDate().toIso8601String();
      }
      if (data['tailorSelectionDeadline'] is Timestamp) {
        data['tailorSelectionDeadline'] = (data['tailorSelectionDeadline'] as Timestamp).toDate().toIso8601String();
      }
      
      return Order.fromJson({...data, 'id': doc.id});
    });
  }

  /// Streams all sub-orders associated with an order.
  Stream<List<SubOrder>> streamSubOrders(String orderId) {
    return _db
        .collection('Sub-orders')
        .where('orderId', isEqualTo: orderId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              
              // Convert Timestamps for the Model
              if (data['deliveryDate'] is Timestamp) {
                data['deliveryDate'] = (data['deliveryDate'] as Timestamp).toDate().toIso8601String();
              }
              if (data['autoReleaseAt'] is Timestamp) {
                data['autoReleaseAt'] = (data['autoReleaseAt'] as Timestamp).toDate().toIso8601String();
              }
              
              return SubOrder.fromJson({...data, 'id': doc.id});
            }).toList());
  }

  /// Streams the tailor job associated with an order.
  Stream<TailorJob?> streamTailorJob(String orderId) {
    return _db
        .collection('Tailor-jobs')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      
      // Convert Timestamps and map 'deliverCharge' (DB) to 'deliveryCharge' (Model)
      final modelData = Map<String, dynamic>.from(data);
      
      _convertTailorJobDates(modelData);
      if (modelData['deliverCharge'] != null) {
        modelData['deliveryCharge'] = modelData['deliverCharge'];
      }
      
      return TailorJob.fromJson({...modelData, 'id': doc.id});
    });
  }

  void _convertTailorJobDates(Map<String, dynamic> data) {
    const dateFields = [
      'confirmedAt', 'createdAt', 'requestedAt', 'estimatedDeliveryDate',
      'quoteResponseDeadline', 'autoReleaseAt'
    ];
    for (var field in dateFields) {
      if (data[field] is Timestamp) {
        data[field] = (data[field] as Timestamp).toDate().toIso8601String();
      }
    }
  }


  /// Combined stream for the entire order timeline.
  /// This can be used to build the complex timeline UI in Track Order.
  Stream<Map<String, dynamic>> streamOrderTimeline(String orderId) {
    return streamOrder(orderId).asyncMap((order) async {
      final subOrders = await streamSubOrders(orderId).first;
      final tailorJob = await streamTailorJob(orderId).first;


      return {
        'order': order,
        'subOrders': subOrders,
        'tailorJob': tailorJob,
      };
    });
  }


  // ─── General Order Management ─────────────────────────────────────────────


  /// Fetches orders for a specific user role.
  Stream<List<Order>> getOrdersByRole(String uid, UserRole role) {
    switch (role) {
      case UserRole.customer:
        return _db
            .collection('Orders')
            .where('customerId', isEqualTo: uid)
            .orderBy('orderDate', descending: true)
            .snapshots()
            .map((s) => s.docs.map((d) {
          final data = d.data();
          if (data['orderDate'] is Timestamp) {
            data['orderDate'] = (data['orderDate'] as Timestamp).toDate().toIso8601String();
          }
          return Order.fromJson({...data, 'id': d.id});
        }).toList());


      case UserRole.tailor:
        return _db
            .collection('Tailor-jobs')
            .where('tailorId', isEqualTo: uid)
            .snapshots()
            .asyncMap((snapshot) async {
          final orderIds =
          snapshot.docs.map((doc) => doc['orderId'] as String).toList();
          if (orderIds.isEmpty) return [];
          final ordersSnap = await _db
              .collection('Orders')
              .where(FieldPath.documentId, whereIn: orderIds)
              .get();
          return ordersSnap.docs.map((d) {
            final data = d.data();
            if (data['orderDate'] is Timestamp) {
              data['orderDate'] = (data['orderDate'] as Timestamp).toDate().toIso8601String();
            }
            return Order.fromJson({...data, 'id': d.id});
          }).toList();
        });


      case UserRole.retailer:
        return _db
            .collection('Sub-orders')
            .where('retailerId', isEqualTo: uid)
            .snapshots()
            .asyncMap((snapshot) async {
          final orderIds =
          snapshot.docs.map((doc) => doc['orderId'] as String).toList();
          if (orderIds.isEmpty) return [];
          final ordersSnap = await _db
              .collection('Orders')
              .where(FieldPath.documentId, whereIn: orderIds)
              .get();
          return ordersSnap.docs.map((d) {
            final data = d.data();
            if (data['orderDate'] is Timestamp) {
              data['orderDate'] = (data['orderDate'] as Timestamp).toDate().toIso8601String();
            }
            return Order.fromJson({...data, 'id': d.id});
          }).toList();
        });
    }
  }
}



import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/tailor.dart';
import '../models/retailer.dart';
import '../models/product.dart';
import '../models/favorite.dart';

/// Service class for customer-specific Firestore operations.
class CustomerService {
  CustomerService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ─── Service Providers ─────────────────────────────────────────────────────

  /// Fetches all tailors from the 'Tailors' collection.
  Stream<List<Tailor>> getTailors() {
    return _firestore.collection('Tailors').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Tailor.fromJson(doc.data())).toList();
    });
  }

  /// Fetches all retailers from the 'Retailers' collection.
  Stream<List<Retailer>> getRetailers() {
    return _firestore.collection('Retailers').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Retailer.fromJson(doc.data())).toList();
    });
  }


}

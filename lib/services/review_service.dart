import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/review.dart';
import 'Cloudinary_service.dart';

class ReviewService {
  ReviewService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _reviewsCollection = 'Reviews';

  // ─── Customer Review Functions ───────────────────────────────────────────

  /// Fetches all reviews submitted by a specific customer.
  Future<List<Review>> fetchMyReviewHistory(String customerId) async {
    try {
      final snapshot = await _db
          .collection(_reviewsCollection)
          .where('customerId', isEqualTo: customerId)
          .get();

      final reviews = snapshot.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    } catch (e) {
      debugPrint('Error fetching review history: $e');
      return [];
    }
  }

  /// Calculates summary statistics for a customer's review history.
  Future<Map<String, dynamic>> getReviewSummaryStats(String customerId) async {
    try {
      final reviews = await fetchMyReviewHistory(customerId);
      if (reviews.isEmpty) {
        return {
          'totalReviews': 0,
          'averageRating': 0.0,
          'tailorReviews': 0,
          'retailerReviews': 0,
          'productReviews': 0,
        };
      }

      final total = reviews.length;
      final avg = reviews.fold(0.0, (sum, r) => sum + r.rating) / total;
      final tailorCount = reviews.where((r) => r.targetRole == ReviewTargetRole.tailor).length;
      final retailerCount = reviews.where((r) => r.targetRole == ReviewTargetRole.retailer).length;
      final productCount = reviews.where((r) => r.targetRole == ReviewTargetRole.product).length;

      return {
        'totalReviews': total,
        'averageRating': avg,
        'tailorReviews': tailorCount,
        'retailerReviews': retailerCount,
        'productReviews': productCount,
      };
    } catch (e) {
      debugPrint('Error getting review summary stats: $e');
      return {};
    }
  }

  /// Filters a customer's reviews by recipient type (tailor, retailer, product).
  Future<List<Review>> filterReviews(String customerId, ReviewTargetRole recipientType) async {
    try {
      final snapshot = await _db
          .collection(_reviewsCollection)
          .where('customerId', isEqualTo: customerId)
          .where('targetRole', isEqualTo: recipientType.name)
          .get();

      final reviews = snapshot.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    } catch (e) {
      debugPrint('Error filtering reviews: $e');
      return [];
    }
  }

  /// Streams real-time reviews for a specific customer with joined details.
  /// Uses memory cache and parallel fetching to optimize performance.
  Stream<List<Map<String, dynamic>>> streamDetailedCustomerReviews(String customerId) {
    return _db
        .collection(_reviewsCollection)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .asyncMap((snap) async {
      final Map<String, Future<Map<String, dynamic>>> retailerCache = {};
      final Map<String, Future<Map<String, dynamic>>> tailorCache = {};
      final Map<String, Future<Map<String, dynamic>>> productCache = {};

      Future<Map<String, dynamic>> getRetailer(String id) {
        return retailerCache.putIfAbsent(id, () async {
          final doc = await _db.collection('Retailer').doc(id).get();
          return doc.data() ?? {'shopName': 'Supplier'};
        });
      }

      Future<Map<String, dynamic>> getTailor(String id) {
        return tailorCache.putIfAbsent(id, () async {
          final doc = await _db.collection('Tailor').doc(id).get();
          return doc.data() ?? {'name': 'Artisan'};
        });
      }

      Future<Map<String, dynamic>> getProduct(String id) {
        return productCache.putIfAbsent(id, () async {
          final doc = await _db.collection('Products').doc(id).get();
          return doc.data() ?? {};
        });
      }

      final List<Map<String, dynamic>> results = await Future.wait(snap.docs.map((doc) async {
        final data = doc.data();
        final String targetId = data['targetId'] ?? '';
        final String targetRole = data['targetRole'] ?? '';
        final String? orderId = data['orderId'];

        String recipientName = 'Recipient';
        if (targetRole == ReviewTargetRole.retailer.name) {
          final rData = await getRetailer(targetId);
          recipientName = rData['shopName'] ?? 'Supplier';
        } else if (targetRole == ReviewTargetRole.tailor.name) {
          final tData = await getTailor(targetId);
          recipientName = tData['name'] ?? 'Artisan';
        }

        List<Map<String, dynamic>> products = [];
        if (orderId != null && targetRole == ReviewTargetRole.retailer.name) {
          // Fetch products associated with this supplier in this order.
          final subSnap = await _db.collection('Sub-orders')
              .where('orderId', isEqualTo: orderId)
              .where('retailerId', isEqualTo: targetId)
              .get();
          
          for (var sDoc in subSnap.docs) {
            final iSnap = await _db.collection('Order-Items')
                .where('subOrderId', isEqualTo: sDoc.id)
                .get();
            
            final List<Map<String, dynamic>?> subOrderProducts = await Future.wait(iSnap.docs.map((iDoc) async {
              final productId = iDoc.data()['productId'];
              final optionId = iDoc.data()['optionId'];
              
              final pData = await getProduct(productId);
              if (pData.isEmpty) return null;

              final options = pData['colorOptions'] as List?;
              final option = options?.firstWhere((o) => o['optionId'] == optionId, orElse: () => null);
              
              final rawImages = (option?['image'] as List?)?.map((e) => e.toString()).toList() ?? [];
              final resolvedImages = _resolveImageUrls(rawImages);

              return {
                'name': pData['productName'] ?? 'Product',
                'image': resolvedImages.isNotEmpty ? resolvedImages.first : '',
                'price': (option?['price'] ?? 0).toDouble(),
              };
            }).toList());
            
            products.addAll(subOrderProducts.whereType<Map<String, dynamic>>());
          }
        }

        return {
          'review': Review.fromJson({...data, 'id': doc.id}),
          'recipientName': recipientName,
          'products': products,
        };
      }));

      results.sort((a, b) => (b['review'] as Review).createdAt.compareTo((a['review'] as Review).createdAt));
      return results;
    });
  }

  /// Submits a general review for an order recipient.
  Future<void> submitReview({
    required String orderId,
    required String customerId,
    required String recipientId,
    required double rating,
    required String comment,
    required ReviewTargetRole type,
  }) async {
    try {
      final data = {
        'orderId': orderId,
        'customerId': customerId,
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

  /// Specific helper to submit a tailor review.
  Future<void> submitTailorReview(
    String customerId,
    String tailorId,
    String orderId,
    double rating,
    String comment,
  ) async {
    await submitReview(
      orderId: orderId,
      customerId: customerId,
      recipientId: tailorId,
      rating: rating,
      comment: comment,
      type: ReviewTargetRole.tailor,
    );
  }

  // ─── Retailer Review Functions ───────────────────────────────────────────

  /// Streams reviews for a specific retailer shop.
  Stream<List<Review>> streamShopReviews(String retailerId) {
    return _db
        .collection(_reviewsCollection)
        .where('targetId', isEqualTo: retailerId)
        .where('targetRole', isEqualTo: ReviewTargetRole.retailer.name)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Streams detailed reviews for a retailer shop (includes customer and product info).
  Stream<List<Map<String, dynamic>>> streamDetailedShopReviews(String retailerId) {
    /* 
    // PREVIOUS SEQUENTIAL VERSION (Slower)
    return _db
        .collection(_reviewsCollection)
        .where('targetId', isEqualTo: retailerId)
        .where('targetRole', isEqualTo: ReviewTargetRole.retailer.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> detailedReviews = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String customerId = data['customerId'];
        final String? orderId = data['orderId'];

        // Fetch customer name
        final customerDoc = await _db.collection('Customer').doc(customerId).get();
        final customerName = customerDoc.exists ? (customerDoc.data()?['name'] ?? 'Anonymous') : 'Anonymous';

        // Fetch products from the sub-order for this retailer
        List<Map<String, dynamic>> products = [];
        if (orderId != null) {
          final subOrderSnap = await _db
              .collection('Sub-orders')
              .where('orderId', isEqualTo: orderId)
              .where('retailerId', isEqualTo: retailerId)
              .limit(1)
              .get();

          if (subOrderSnap.docs.isNotEmpty) {
            final subOrderId = subOrderSnap.docs.first.id;
            final itemsSnap = await _db
                .collection('Order-Items')
                .where('subOrderId', isEqualTo: subOrderId)
                .get();

            for (var itemDoc in itemsSnap.docs) {
              final itemData = itemDoc.data();
              final productId = itemData['productId'];
              final optionId = itemData['optionId'];

              final productDoc = await _db.collection('Products').doc(productId).get();
              if (productDoc.exists) {
                final productData = productDoc.data()!;
                final List<dynamic> colorOptions = productData['colorOptions'] ?? [];
                final option = colorOptions.firstWhere(
                  (o) => o['optionId'] == optionId,
                  orElse: () => null,
                );

                final rawImages = (option?['image'] as List?)?.map((e) => e.toString()).toList() ?? [];
                final resolvedImages = _resolveImageUrls(rawImages);

                products.add({
                  'name': productData['productName'] ?? 'Unknown Product',
                  'image': resolvedImages.isNotEmpty ? resolvedImages.first : '',
                  'price': (option?['price'] ?? 0).toDouble(),
                });
              }
            }
          }
        }

        detailedReviews.add({
          'review': {...data, 'id': doc.id},
          'userName': customerName,
          'products': products,
        });
      }
      return detailedReviews;
    });
    */

    // OPTIMIZED PARALLEL VERSION
    return _db
        .collection(_reviewsCollection)
        .where('targetId', isEqualTo: retailerId)
        .where('targetRole', isEqualTo: ReviewTargetRole.retailer.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      // Local caches to avoid redundant fetches
      final Map<String, String> customerNameCache = {};
      final Map<String, List<Map<String, dynamic>>> subOrderProductsCache = {};

      final List<Map<String, dynamic>?> results = await Future.wait(
        snapshot.docs.map((doc) async {
          try {
            final data = doc.data();
            final String customerId = data['customerId'];
            final String? orderId = data['orderId'];

            // 1. Fetch customer name (parallelized/cached)
            if (!customerNameCache.containsKey(customerId)) {
              final customerDoc = await _db.collection('Customer').doc(customerId).get();
              customerNameCache[customerId] = customerDoc.exists ? (customerDoc.data()?['name'] ?? 'Anonymous') : 'Anonymous';
            }
            final customerName = customerNameCache[customerId]!;

            // 2. Fetch products from the sub-order for this retailer
            List<Map<String, dynamic>> products = [];
            if (orderId != null) {
              final cacheKey = "${orderId}_$retailerId";
              if (!subOrderProductsCache.containsKey(cacheKey)) {
                final subOrderSnap = await _db
                    .collection('Sub-orders')
                    .where('orderId', isEqualTo: orderId)
                    .where('retailerId', isEqualTo: retailerId)
                    .limit(1)
                    .get();

                if (subOrderSnap.docs.isNotEmpty) {
                  final subOrderId = subOrderSnap.docs.first.id;
                  final itemsSnap = await _db
                      .collection('Order-Items')
                      .where('subOrderId', isEqualTo: subOrderId)
                      .get();

                  // Fetch all product details for this sub-order in parallel
                  final subOrderProducts = await Future.wait(
                    itemsSnap.docs.map((itemDoc) async {
                      final itemData = itemDoc.data();
                      final productId = itemData['productId'];
                      final optionId = itemData['optionId'];

                      final productDoc = await _db.collection('Products').doc(productId).get();
                      if (productDoc.exists) {
                        final productData = productDoc.data()!;
                        final List<dynamic> colorOptions = productData['colorOptions'] ?? [];
                        final option = colorOptions.firstWhere(
                          (o) => o['optionId'] == optionId,
                          orElse: () => null,
                        );

                        final rawImages = (option?['image'] as List?)?.map((e) => e.toString()).toList() ?? [];
                        final resolvedImages = _resolveImageUrls(rawImages);

                        return {
                          'name': productData['productName'] ?? 'Unknown Product',
                          'image': resolvedImages.isNotEmpty ? resolvedImages.first : '',
                          'price': (option?['price'] ?? 0).toDouble(),
                        };
                      }
                      return null;
                    }),
                  ).then((list) => list.whereType<Map<String, dynamic>>().toList());
                  
                  subOrderProductsCache[cacheKey] = subOrderProducts;
                } else {
                  subOrderProductsCache[cacheKey] = [];
                }
              }
              products = subOrderProductsCache[cacheKey]!;
            }

            return {
              'review': {...data, 'id': doc.id},
              'userName': customerName,
              'products': products,
            };
          } catch (e) {
            debugPrint("ReviewService: Error processing review: $e");
            return null;
          }
        }),
      );

      final validResults = results.whereType<Map<String, dynamic>>().toList();
      validResults.sort((a, b) {
        final dateA = (a['review'] as Map<String, dynamic>)['createdAt']?.toString() ?? '';
        final dateB = (b['review'] as Map<String, dynamic>)['createdAt']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });
      return validResults;
    });
  }

  /// Streams review statistics for a retailer shop.
  Stream<Map<String, dynamic>> streamShopReviewStats(String retailerId) {
    return _db
        .collection(_reviewsCollection)
        .where('targetId', isEqualTo: retailerId)
        .where('targetRole', isEqualTo: ReviewTargetRole.retailer.name)
        .snapshots()
        .map((snap) {
      final reviews = snap.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      if (reviews.isEmpty) {
        return {
          'total': 0,
          'average': 0.0,
          'distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
        };
      }

      final total = reviews.length;
      final avg = reviews.fold(0.0, (sum, r) => sum + r.rating) / total;
      final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (var r in reviews) {
        int star = r.rating.floor().clamp(1, 5);
        distribution[star] = (distribution[star] ?? 0) + 1;
      }

      return {
        'total': total,
        'average': avg,
        'distribution': distribution,
      };
    });
  }

  /// Gets review statistics for a retailer shop.
  Future<Map<String, dynamic>> getShopReviewStats(String retailerId) async {
    try {
      // We fetch all reviews to calculate stats. For very large numbers, 
      // this should be moved to a Cloud Function that updates a stats doc.
      final snapshot = await _db
          .collection(_reviewsCollection)
          .where('targetId', isEqualTo: retailerId)
          .where('targetRole', isEqualTo: ReviewTargetRole.retailer.name)
          .get();

      final reviews = snapshot.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      if (reviews.isEmpty) return {'total': 0, 'average': 0.0, 'distribution': {1:0, 2:0, 3:0, 4:0, 5:0}};

      final total = reviews.length;
      final avg = reviews.fold(0.0, (sum, r) => sum + r.rating) / total;
      
      final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (var r in reviews) {
        int star = r.rating.floor().clamp(1, 5);
        distribution[star] = (distribution[star] ?? 0) + 1;
      }

      return {
        'total': total,
        'average': avg,
        'distribution': distribution,
      };
    } catch (e) {
      debugPrint('Error getting shop review stats: $e');
      return {};
    }
  }

  /// Fetches all reviews associated with a specific order.
  Future<List<Review>> fetchReviewRelatedItems(String orderId) async {
    try {
      final snapshot = await _db
          .collection(_reviewsCollection)
          .where('orderId', isEqualTo: orderId)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error fetching review related items: $e');
      return [];
    }
  }

  /// Responds to a review (Retailer functionality).
  Future<void> respondToReview(String reviewId, String retailerComment) async {
    try {
      await _db.collection(_reviewsCollection).doc(reviewId).update({
        'retailerResponse': retailerComment,
        'respondedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error responding to review: $e');
      rethrow;
    }
  }

  // ─── Tailor Review Functions ─────────────────────────────────────────────

  /// Fetches reviews for a specific tailor with optional filtering and sorting.
  Future<List<Review>> fetchTailorReviews(
    String tailorId, {
    int? ratingFilter,
    String sortBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      Query query = _db
          .collection(_reviewsCollection)
          .where('targetId', isEqualTo: tailorId)
          .where('targetRole', isEqualTo: ReviewTargetRole.tailor.name);

      if (ratingFilter != null) {
        query = query.where('rating', isGreaterThanOrEqualTo: ratingFilter.toDouble());
      }

      final snapshot = await query.get();
      final reviews = snapshot.docs
          .map((doc) => Review.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
          
      reviews.sort((a, b) {
        if (sortBy == 'rating') {
           return descending ? b.rating.compareTo(a.rating) : a.rating.compareTo(b.rating);
        }
        return descending ? b.createdAt.compareTo(a.createdAt) : a.createdAt.compareTo(b.createdAt);
      });
      return reviews;
    } catch (e) {
      debugPrint('Error fetching tailor reviews: $e');
      return [];
    }
  }

  /// Gets reputation summary for a tailor.
  Future<Map<String, dynamic>> getTailorReputationSummary(String tailorId) async {
    try {
      final reviews = await fetchTailorReviews(tailorId);
      if (reviews.isEmpty) return {'total': 0, 'average': 0.0};

      final total = reviews.length;
      final avg = reviews.fold(0.0, (sum, r) => sum + r.rating) / total;

      return {
        'total': total,
        'average': avg,
      };
    } catch (e) {
      debugPrint('Error getting tailor reputation summary: $e');
      return {};
    }
  }

  /// Fetches a single review's detailed metadata.
  Future<Review?> fetchReviewMetadata(String reviewId) async {
    try {
      final doc = await _db.collection(_reviewsCollection).doc(reviewId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Review.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      debugPrint('Error fetching review metadata: $e');
      return null;
    }
  }

  /// General fetch for reviews by target (any role).
  Future<List<Review>> getReviewsByTargetId(
    String targetId, 
    ReviewTargetRole targetRole, {
    int? filter, 
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _db
          .collection(_reviewsCollection)
          .where('targetId', isEqualTo: targetId)
          .where('targetRole', isEqualTo: targetRole.name);

      if (filter != null) {
        query = query.where('rating', isGreaterThanOrEqualTo: filter.toDouble());
      }

      final snapshot = await query.get();
      final reviews = snapshot.docs
          .map((doc) => Review.fromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
          
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews.take(limit).toList();
    } catch (e) {
      debugPrint('Error fetching reviews by target: $e');
      return [];
    }
  }

  /// Streams reviews for a specific tailor.
  Stream<List<Review>> streamTailorReviews(String tailorId) {
    return _db
        .collection(_reviewsCollection)
        .where('targetId', isEqualTo: tailorId)
        .where('targetRole', isEqualTo: ReviewTargetRole.tailor.name)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Streams detailed reviews for a tailor (includes customer info).
  Stream<List<Map<String, dynamic>>> streamDetailedTailorReviews(String tailorId) {
    return _db
        .collection(_reviewsCollection)
        .where('targetId', isEqualTo: tailorId)
        .where('targetRole', isEqualTo: ReviewTargetRole.tailor.name)
        .snapshots()
        .asyncMap((snapshot) async {
      final Map<String, String> customerNameCache = {};

      final List<Map<String, dynamic>?> results = await Future.wait(
        snapshot.docs.map((doc) async {
          try {
            final data = doc.data();
            final String customerId = data['customerId'];

            if (!customerNameCache.containsKey(customerId)) {
              final customerDoc = await _db.collection('Customer').doc(customerId).get();
              customerNameCache[customerId] = customerDoc.exists ? (customerDoc.data()?['name'] ?? 'Anonymous') : 'Anonymous';
            }
            final customerName = customerNameCache[customerId]!;

            return {
              'review': {...data, 'id': doc.id},
              'userName': customerName,
            };
          } catch (e) {
            debugPrint("ReviewService: Error processing tailor review: $e");
            return null;
          }
        }),
      );

      final validResults = results.whereType<Map<String, dynamic>>().toList();
      validResults.sort((a, b) {
        final dateA = (a['review'] as Map<String, dynamic>)['createdAt']?.toString() ?? '';
        final dateB = (b['review'] as Map<String, dynamic>)['createdAt']?.toString() ?? '';
        return dateB.compareTo(dateA);
      });
      return validResults;
    });
  }

  /// Streams review statistics for a tailor.
  Stream<Map<String, dynamic>> streamTailorReviewStats(String tailorId) {
    return _db
        .collection(_reviewsCollection)
        .where('targetId', isEqualTo: tailorId)
        .where('targetRole', isEqualTo: ReviewTargetRole.tailor.name)
        .snapshots()
        .map((snap) {
      final reviews = snap.docs
          .map((doc) => Review.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      if (reviews.isEmpty) {
        return {
          'total': 0,
          'average': 0.0,
          'distribution': {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
        };
      }

      final total = reviews.length;
      final avg = reviews.fold(0.0, (sum, r) => sum + r.rating) / total;
      final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (var r in reviews) {
        int star = r.rating.floor().clamp(1, 5);
        distribution[star] = (distribution[star] ?? 0) + 1;
      }

      return {
        'total': total,
        'average': avg,
        'distribution': distribution,
      };
    });
  }

  // ─── Image Helpers ──────────────────────────────────────────────────────

  List<String> _resolveImageUrls(List<String> imagePaths) {
    final svc = CloudinaryService();
    return imagePaths.map((p) {
      final url = p.contains('cloudinary.com') ? p : _getCDNUrl(p);
      return svc.getOptimizedImageUrl(url);
    }).toList();
  }

  String _getCDNUrl(String imagePath) {
    if (imagePath.startsWith('http')) return imagePath;
    final cleaned = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
    return 'https://res.cloudinary.com/${CloudinaryService.cloudName}/image/upload/$cleaned';
  }
}

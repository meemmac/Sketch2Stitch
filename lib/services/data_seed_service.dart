// lib/services/data_seed_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DataSeedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> seedAllData() async {
    try {
      print('🌱 Starting data seeding...');
      
      await _seedReviews();
      
      print('✅ Data seeding completed successfully!');
    } catch (e) {
      print('❌ Error seeding data: $e');
      rethrow;
    }
  }

  Future<void> _seedReviews() async {
    final reviews = [
      // ─── Tailor Reviews ──────────────────────────────────────────────
      {
        'id': 'review1',
        'customerId': 'customer1',
        'targetId': 'tailor1',
        'targetRole': 'tailor',
        'orderId': 'order1',
        'rating': 5.0,
        'comment': 'Excellent work! The suit fit perfectly and the quality was outstanding.',
        'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'id': 'review2',
        'customerId': 'customer2',
        'targetId': 'tailor1',
        'targetRole': 'tailor',
        'orderId': 'order2',
        'rating': 4.5,
        'comment': 'Very professional and timely delivery. Would recommend to friends.',
        'createdAt': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      },
      {
        'id': 'review3',
        'customerId': 'customer3',
        'targetId': 'tailor1',
        'targetRole': 'tailor',
        'orderId': 'order3',
        'rating': 4.0,
        'comment': 'Good quality work but delivery was a bit delayed.',
        'createdAt': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
      },
      {
        'id': 'review4',
        'customerId': 'customer4',
        'targetId': 'tailor2',
        'targetRole': 'tailor',
        'orderId': 'order4',
        'rating': 5.0,
        'comment': 'Amazing attention to detail. Will definitely come back!',
        'createdAt': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      },
      {
        'id': 'review5',
        'customerId': 'customer5',
        'targetId': 'tailor2',
        'targetRole': 'tailor',
        'orderId': 'order5',
        'rating': 4.5,
        'comment': 'Great craftsmanship and very friendly service.',
        'createdAt': DateTime.now().subtract(const Duration(days: 14)).toIso8601String(),
      },
      {
        'id': 'review6',
        'customerId': 'customer6',
        'targetId': 'tailor2',
        'targetRole': 'tailor',
        'orderId': 'order6',
        'rating': 3.5,
        'comment': 'The stitching was good but the fitting could be improved.',
        'createdAt': DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
      },
      {
        'id': 'review7',
        'customerId': 'customer7',
        'targetId': 'tailor3',
        'targetRole': 'tailor',
        'orderId': 'order7',
        'rating': 4.8,
        'comment': 'Exceptional work on the traditional outfit! Highly recommended.',
        'createdAt': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
      {
        'id': 'review8',
        'customerId': 'customer8',
        'targetId': 'tailor3',
        'targetRole': 'tailor',
        'orderId': 'order8',
        'rating': 4.0,
        'comment': 'Good quality work, delivered on time.',
        'createdAt': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
      },
      {
        'id': 'review9',
        'customerId': 'customer9',
        'targetId': 'tailor3',
        'targetRole': 'tailor',
        'orderId': 'order9',
        'rating': 5.0,
        'comment': 'Perfect fit and finish! Will definitely order again.',
        'createdAt': DateTime.now().subtract(const Duration(days: 12)).toIso8601String(),
      },
      {
        'id': 'review10',
        'customerId': 'customer10',
        'targetId': 'tailor1',
        'targetRole': 'tailor',
        'orderId': 'order10',
        'rating': 4.5,
        'comment': 'Great service and quality. The suit looks amazing!',
        'createdAt': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
      },

      // ─── Retailer Reviews ────────────────────────────────────────────
      {
        'id': 'review11',
        'customerId': 'customer1',
        'targetId': 'retailer1',
        'targetRole': 'retailer',
        'orderId': 'order11',
        'rating': 5.0,
        'comment': 'Great quality products! Everything matched the description perfectly.',
        'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'id': 'review12',
        'customerId': 'customer2',
        'targetId': 'retailer1',
        'targetRole': 'retailer',
        'orderId': 'order12',
        'rating': 4.5,
        'comment': 'Quick delivery and excellent packaging. Will order again.',
        'createdAt': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      },
      {
        'id': 'review13',
        'customerId': 'customer3',
        'targetId': 'retailer1',
        'targetRole': 'retailer',
        'orderId': 'order13',
        'rating': 4.0,
        'comment': 'Good products but shipping was a bit delayed.',
        'createdAt': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
      },
      {
        'id': 'review14',
        'customerId': 'customer4',
        'targetId': 'retailer2',
        'targetRole': 'retailer',
        'orderId': 'order14',
        'rating': 4.5,
        'comment': 'Great quality and fast delivery. Very satisfied!',
        'createdAt': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      },
      {
        'id': 'review15',
        'customerId': 'customer5',
        'targetId': 'retailer2',
        'targetRole': 'retailer',
        'orderId': 'order15',
        'rating': 3.5,
        'comment': 'Good product but packaging could be better.',
        'createdAt': DateTime.now().subtract(const Duration(days: 12)).toIso8601String(),
      },
      {
        'id': 'review16',
        'customerId': 'customer6',
        'targetId': 'retailer2',
        'targetRole': 'retailer',
        'orderId': 'order16',
        'rating': 5.0,
        'comment': 'Excellent quality! The fabric is exactly what I was looking for.',
        'createdAt': DateTime.now().subtract(const Duration(days: 18)).toIso8601String(),
      },
      {
        'id': 'review17',
        'customerId': 'customer7',
        'targetId': 'retailer3',
        'targetRole': 'retailer',
        'orderId': 'order17',
        'rating': 4.8,
        'comment': 'Beautiful silk! The quality is outstanding.',
        'createdAt': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
      {
        'id': 'review18',
        'customerId': 'customer8',
        'targetId': 'retailer3',
        'targetRole': 'retailer',
        'orderId': 'order18',
        'rating': 4.0,
        'comment': 'Good quality but delivery took longer than expected.',
        'createdAt': DateTime.now().subtract(const Duration(days: 9)).toIso8601String(),
      },
      {
        'id': 'review19',
        'customerId': 'customer9',
        'targetId': 'retailer3',
        'targetRole': 'retailer',
        'orderId': 'order19',
        'rating': 5.0,
        'comment': 'Absolutely love the lace! Will definitely order more.',
        'createdAt': DateTime.now().subtract(const Duration(days: 14)).toIso8601String(),
      },
      {
        'id': 'review20',
        'customerId': 'customer10',
        'targetId': 'retailer1',
        'targetRole': 'retailer',
        'orderId': 'order20',
        'rating': 4.0,
        'comment': 'Good quality fabric. The colors are exactly as shown.',
        'createdAt': DateTime.now().subtract(const Duration(days: 16)).toIso8601String(),
      },

      // ─── Product Reviews ─────────────────────────────────────────────
      {
        'id': 'review21',
        'customerId': 'customer1',
        'targetId': 'prod1',
        'targetRole': 'product',
        'orderId': 'order21',
        'rating': 5.0,
        'comment': 'The cotton is so soft and breathable! Perfect for summer.',
        'createdAt': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      },
      {
        'id': 'review22',
        'customerId': 'customer2',
        'targetId': 'prod2',
        'targetRole': 'product',
        'orderId': 'order22',
        'rating': 4.5,
        'comment': 'Luxurious silk! The sheen is beautiful.',
        'createdAt': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(),
      },
      {
        'id': 'review23',
        'customerId': 'customer3',
        'targetId': 'prod3',
        'targetRole': 'product',
        'orderId': 'order23',
        'rating': 4.0,
        'comment': 'Good wool blend. Keeps me warm in winter.',
        'createdAt': DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
      },
      {
        'id': 'review24',
        'customerId': 'customer4',
        'targetId': 'prod4',
        'targetRole': 'product',
        'orderId': 'order24',
        'rating': 5.0,
        'comment': 'Beautiful linen! Perfect for shirts.',
        'createdAt': DateTime.now().subtract(const Duration(days: 11)).toIso8601String(),
      },
      {
        'id': 'review25',
        'customerId': 'customer5',
        'targetId': 'prod5',
        'targetRole': 'product',
        'orderId': 'order25',
        'rating': 4.5,
        'comment': 'Delicate and beautiful lace. Worked perfectly for my project.',
        'createdAt': DateTime.now().subtract(const Duration(days: 13)).toIso8601String(),
      },
      {
        'id': 'review26',
        'customerId': 'customer6',
        'targetId': 'element1',
        'targetRole': 'product',
        'orderId': 'order26',
        'rating': 4.5,
        'comment': 'Beautiful buttons! Great variety of sizes.',
        'createdAt': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
      },
      {
        'id': 'review27',
        'customerId': 'customer7',
        'targetId': 'element2',
        'targetRole': 'product',
        'orderId': 'order27',
        'rating': 5.0,
        'comment': 'High quality thread. No breakage while sewing.',
        'createdAt': DateTime.now().subtract(const Duration(days: 17)).toIso8601String(),
      },
      {
        'id': 'review28',
        'customerId': 'customer8',
        'targetId': 'element3',
        'targetRole': 'product',
        'orderId': 'order28',
        'rating': 4.0,
        'comment': 'Pretty pearls! Used them for bridal work.',
        'createdAt': DateTime.now().subtract(const Duration(days: 19)).toIso8601String(),
      },
      {
        'id': 'review29',
        'customerId': 'customer9',
        'targetId': 'element4',
        'targetRole': 'product',
        'orderId': 'order29',
        'rating': 4.8,
        'comment': 'Lovely lace trim. Added a beautiful finish to my project.',
        'createdAt': DateTime.now().subtract(const Duration(days: 21)).toIso8601String(),
      },
      {
        'id': 'review30',
        'customerId': 'customer10',
        'targetId': 'element5',
        'targetRole': 'product',
        'orderId': 'order30',
        'rating': 4.5,
        'comment': 'Versatile ribbons! Great for gift wrapping and crafts.',
        'createdAt': DateTime.now().subtract(const Duration(days: 23)).toIso8601String(),
      },
    ];

    for (final review in reviews) {
      final id = review['id'] as String;
      review.remove('id');
      await _db.collection('Reviews').doc(id).set(review);
      print('✅ Seeded review: $id');
    }
  }

  Future<void> clearAllData() async {
    try {
      print('🗑️ Clearing all data...');
      
      final collections = ['Reviews'];
      for (final collection in collections) {
        final snapshot = await _db.collection(collection).get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
        print('✅ Cleared $collection');
      }
      
      print('✅ All data cleared successfully!');
    } catch (e) {
      print('❌ Error clearing data: $e');
      rethrow;
    }
  }
}
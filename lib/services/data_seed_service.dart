// lib/services/data_seed_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DataSeedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> seedAllData() async {
    try {
      print('🌱 Starting data seeding...');
      
      await _seedRetailers();
      await _seedTailors();
      await _seedFabrics();
      await _seedElements();
      
      print('✅ Data seeding completed successfully!');
      print('📊 Seeded: 3 Retailers, 3 Tailors, 5 Fabrics, 6 Elements');
    } catch (e) {
      print('❌ Error seeding data: $e');
      rethrow;
    }
  }

  Future<void> _seedRetailers() async {
    final retailers = [
      {
        'id': 'retailer1',
        'shopName': 'Dhaka Fabric House',
        'email': 'dhakafabric@example.com',
        'phone': '+8801712345678',
        'address': 'Gulshan 1, Dhaka',
        'rating': 4.8,
        'profilePicture': 'https://picsum.photos/seed/retailer1/200/200',
        'about': 'Premium fabric retailer since 1995',
        'location': const GeoPoint(23.8103, 90.4125),
      },
      {
        'id': 'retailer2',
        'shopName': 'Chowdhury Textiles',
        'email': 'chowdhurytextiles@example.com',
        'phone': '+8801812345678',
        'address': 'Mirpur 10, Dhaka',
        'rating': 4.5,
        'profilePicture': 'https://picsum.photos/seed/retailer2/200/200',
        'about': 'Quality textiles for over 20 years',
        'location': const GeoPoint(23.8069, 90.3682),
      },
      {
        'id': 'retailer3',
        'shopName': 'Silk & Lace Emporium',
        'email': 'silkandlace@example.com',
        'phone': '+8801912345678',
        'address': 'Banani, Dhaka',
        'rating': 4.9,
        'profilePicture': 'https://picsum.photos/seed/retailer3/200/200',
        'about': 'Luxury silk and lace specialists',
        'location': const GeoPoint(23.7944, 90.4074),
      },
    ];

    for (final retailer in retailers) {
      final id = retailer['id'] as String;
      retailer.remove('id');
      await _db.collection('Retailer').doc(id).set(retailer);
      print('✅ Seeded retailer: ${retailer['shopName']}');
    }
  }

  Future<void> _seedTailors() async {
    final tailors = [
      {
        'id': 'tailor1',
        'name': 'Rahul Ahmed',
        'email': 'rahul.tailor@example.com',
        'phone': '+8801612345678',
        'address': 'Dhanmondi, Dhaka',
        'rating': 4.9,
        'profilePicture': 'https://picsum.photos/seed/tailor1/200/200',
        'about': 'Expert tailor with 15 years experience in bridal wear',
        'location': const GeoPoint(23.7500, 90.3800),
      },
      {
        'id': 'tailor2',
        'name': 'Sadia Rahman',
        'email': 'sadia.tailor@example.com',
        'phone': '+8801712345679',
        'address': 'Uttara, Dhaka',
        'rating': 4.7,
        'profilePicture': 'https://picsum.photos/seed/tailor2/200/200',
        'about': 'Specializing in men\'s formal wear and suits',
        'location': const GeoPoint(23.8750, 90.3800),
      },
      {
        'id': 'tailor3',
        'name': 'Kamal Hossain',
        'email': 'kamal.tailor@example.com',
        'phone': '+8801812345679',
        'address': 'Old Dhaka, Dhaka',
        'rating': 4.8,
        'profilePicture': 'https://picsum.photos/seed/tailor3/200/200',
        'about': 'Traditional craftsmanship passed down 3 generations',
        'location': const GeoPoint(23.7200, 90.4100),
      },
    ];

    for (final tailor in tailors) {
      final id = tailor['id'] as String;
      tailor.remove('id');
      await _db.collection('Tailor').doc(id).set(tailor);
      print('✅ Seeded tailor: ${tailor['name']}');
    }
  }

  Future<void> _seedFabrics() async {
    final fabrics = [
      {
        'id': 'fabric1',
        'retailerId': 'retailer1',
        'productName': 'Premium Egyptian Cotton',
        'productCode': 'COTTON-001',
        'category': 'Cotton',
        'description': 'Soft, breathable Egyptian cotton perfect for shirts and casual wear.',
        'materialType': [
          {'type': 'Cotton', 'blend': 100},
        ],
        'careSymbol': ['Machine wash cold', 'Do not bleach', 'Tumble dry low', 'Iron medium'],
        'colorOptions': [
          {
            'optionId': 1,
            'color': 'White',
            'image': 'https://picsum.photos/seed/cotton_white/400/400',
            'video': '',
            'price': 650,
            'stock': 40,
          },
          {
            'optionId': 2,
            'color': 'Beige',
            'image': 'https://picsum.photos/seed/cotton_beige/400/400',
            'video': '',
            'price': 650,
            'stock': 25,
          },
          {
            'optionId': 3,
            'color': 'Blue',
            'image': 'https://picsum.photos/seed/cotton_blue/400/400',
            'video': '',
            'price': 700,
            'stock': 15,
          },
          {
            'optionId': 4,
            'color': 'Black',
            'image': 'https://picsum.photos/seed/cotton_black/400/400',
            'video': '',
            'price': 700,
            'stock': 0,
          },
        ],
      },
      {
        'id': 'fabric2',
        'retailerId': 'retailer3',
        'productName': 'Pure Mulberry Silk',
        'productCode': 'SILK-001',
        'category': 'Silk',
        'description': 'Luxurious mulberry silk with a natural sheen.',
        'materialType': [
          {'type': 'Silk', 'blend': 70},
          {'type': 'Viscose', 'blend': 30},
        ],
        'careSymbol': ['Dry clean only', 'Iron on low heat'],
        'colorOptions': [
          {
            'optionId': 1,
            'color': 'Gold',
            'image': 'https://picsum.photos/seed/silk_gold/400/400',
            'video': '',
            'price': 1800,
            'stock': 10,
          },
          {
            'optionId': 2,
            'color': 'Pink',
            'image': 'https://picsum.photos/seed/silk_pink/400/400',
            'video': '',
            'price': 1750,
            'stock': 8,
          },
          {
            'optionId': 3,
            'color': 'Green',
            'image': 'https://picsum.photos/seed/silk_green/400/400',
            'video': '',
            'price': 1750,
            'stock': 5,
          },
          {
            'optionId': 4,
            'color': 'White',
            'image': 'https://picsum.photos/seed/silk_white/400/400',
            'video': '',
            'price': 1700,
            'stock': 12,
          },
        ],
      },
      {
        'id': 'fabric3',
        'retailerId': 'retailer2',
        'productName': 'Merino Wool Blend',
        'productCode': 'WOOL-001',
        'category': 'Wool',
        'description': 'Warm merino wool blend suited for winter jackets and blazers.',
        'materialType': [
          {'type': 'Wool', 'blend': 85},
          {'type': 'Nylon', 'blend': 15},
        ],
        'careSymbol': ['Hand wash cold', 'Dry flat'],
        'colorOptions': [
          {
            'optionId': 1,
            'color': 'Brown',
            'image': 'https://picsum.photos/seed/wool_brown/400/400',
            'video': '',
            'price': 950,
            'stock': 18,
          },
          {
            'optionId': 2,
            'color': 'Black',
            'image': 'https://picsum.photos/seed/wool_black/400/400',
            'video': '',
            'price': 950,
            'stock': 20,
          },
          {
            'optionId': 3,
            'color': 'Beige',
            'image': 'https://picsum.photos/seed/wool_beige/400/400',
            'video': '',
            'price': 900,
            'stock': 0,
          },
        ],
      },
      {
        'id': 'fabric4',
        'retailerId': 'retailer1',
        'productName': 'Irish Linen Weave',
        'productCode': 'LINEN-001',
        'category': 'Linen',
        'description': 'Classic Irish linen with a crisp hand-feel.',
        'materialType': [
          {'type': 'Linen', 'blend': 100},
        ],
        'careSymbol': ['Machine wash cold', 'Iron while damp'],
        'colorOptions': [
          {
            'optionId': 1,
            'color': 'White',
            'image': 'https://picsum.photos/seed/linen_white/400/400',
            'video': '',
            'price': 780,
            'stock': 30,
          },
          {
            'optionId': 2,
            'color': 'Beige',
            'image': 'https://picsum.photos/seed/linen_beige/400/400',
            'video': '',
            'price': 780,
            'stock': 22,
          },
          {
            'optionId': 3,
            'color': 'Blue',
            'image': 'https://picsum.photos/seed/linen_blue/400/400',
            'video': '',
            'price': 820,
            'stock': 14,
          },
        ],
      },
      {
        'id': 'fabric5',
        'retailerId': 'retailer3',
        'productName': 'French Chantilly Lace',
        'productCode': 'LACE-001',
        'category': 'Lace',
        'description': 'Delicate floral Chantilly lace, hand-finished scalloped edges.',
        'materialType': [
          {'type': 'Polyester', 'blend': 100},
        ],
        'careSymbol': ['Dry clean only', 'Do not bleach'],
        'colorOptions': [
          {
            'optionId': 1,
            'color': 'White',
            'image': 'https://picsum.photos/seed/lace_white/400/400',
            'video': '',
            'price': 1200,
            'stock': 6,
          },
          {
            'optionId': 2,
            'color': 'Black',
            'image': 'https://picsum.photos/seed/lace_black/400/400',
            'video': '',
            'price': 1200,
            'stock': 4,
          },
          {
            'optionId': 3,
            'color': 'Pink',
            'image': 'https://picsum.photos/seed/lace_pink/400/400',
            'video': '',
            'price': 1250,
            'stock': 0,
          },
        ],
      },
    ];

    for (final fabric in fabrics) {
      final id = fabric['id'] as String;
      fabric.remove('id');
      await _db.collection('Products').doc(id).set(fabric);
      print('✅ Seeded fabric: ${fabric['productName']}');
    }
  }

  Future<void> _seedElements() async {
    final elements = [
      {
        'id': 'element1',
        'retailerId': 'retailer1',
        'productName': 'Decorative Buttons Set',
        'productCode': 'BTN-001',
        'category': 'Buttons',
        'description': 'Elegant button sets in various sizes and finishes.',
        'materialType': [], // Elements don't have materialType
        'careSymbol': [], // Elements don't have careSymbol
        'colorOptions': [
          {
            'optionId': 1,
            'color': 'White',
            'image': 'https://picsum.photos/seed/buttons_white/400/400',
            'video': '',
            'price': 80,
            'stock': 200,
          },
          {
            'optionId': 2,
            'color': 'Black',
            'image': 'https://picsum.photos/seed/buttons_black/400/400',
            'video': '',
            'price': 80,
            'stock': 150,
          },
          {
            'optionId': 3,
            'color': 'Gold',
            'image': 'https://picsum.photos/seed/buttons_gold/400/400',
            'video': '',
            'price': 100,
            'stock': 100,
          },
        ],
      },
      {
        'id': 'element2',
        'retailerId': 'retailer2',
        'productName': 'Sewing Thread Collection',
        'productCode': 'THD-001',
        'category': 'Threads',
        'description': 'Premium quality sewing thread in essential colors.',
        'materialType': [],
        'careSymbol': [],
        'colorOptions': [
          {
            'optionId': 1,
            'color': 'White',
            'image': 'https://picsum.photos/seed/thread_white/400/400',
            'video': '',
            'price': 45,
            'stock': 300,
          },
          {
            'optionId': 2,
            'color': 'Black',
            'image': 'https://picsum.photos/seed/thread_black/400/400',
            'video': '',
            'price': 45,
            'stock': 250,
          },
          {
            'optionId': 3,
            'color': 'Beige',
            'image': 'https://picsum.photos/seed/thread_beige/400/400',
            'video': '',
            'price': 45,
            'stock': 200,
          },
        ],
      },
      {
        'id': 'element3',
        'retailerId': 'retailer3',
        'productName': 'Pearl Embellishments',
        'productCode': 'PRL-001',
        'category': 'Embellishments',
        'description': 'Beautiful pearl embellishments for bridal and formal wear.',
        'materialType': [],
        'careSymbol': [],
        'colorOptions': [
          {
            'optionId': 1,
            'color': 'White',
            'image': 'https://picsum.photos/seed/pearls_white/400/400',
            'video': '',
            'price': 200,
            'stock': 80,
          },
          {
            'optionId': 2,
            'color': 'Pink',
            'image': 'https://picsum.photos/seed/pearls_pink/400/400',
            'video': '',
            'price': 220,
            'stock': 60,
          },
        ],
      },
      {
        'id': 'element4',
        'retailerId': 'retailer2',
        'productName': 'Lace Trim',
        'productCode': 'LCT-001',
        'category': 'Trims',
        'description': 'Fine lace trim with delicate patterns.',
        'materialType': [],
        'careSymbol': [],
        'colorOptions': [
          {
            'optionId': 1,
            'color': 'White',
            'image': 'https://picsum.photos/seed/trims_white/400/400',
            'video': '',
            'price': 180,
            'stock': 40,
          },
          {
            'optionId': 2,
            'color': 'Black',
            'image': 'https://picsum.photos/seed/trims_black/400/400',
            'video': '',
            'price': 180,
            'stock': 35,
          },
        ],
      },
      {
        'id': 'element5',
        'retailerId': 'retailer1',
        'productName': 'Ribbon Collection',
        'productCode': 'RBN-001',
        'category': 'Ribbons',
        'description': 'Versatile satin ribbons in various colors and widths.',
        'materialType': [],
        'careSymbol': [],
        'colorOptions': [
          {
            'optionId': 1,
            'color': 'White',
            'image': 'https://picsum.photos/seed/ribbon_white/400/400',
            'video': '',
            'price': 60,
            'stock': 150,
          },
          {
            'optionId': 2,
            'color': 'Gold',
            'image': 'https://picsum.photos/seed/ribbon_gold/400/400',
            'video': '',
            'price': 70,
            'stock': 120,
          },
          {
            'optionId': 3,
            'color': 'Blue',
            'image': 'https://picsum.photos/seed/ribbon_blue/400/400',
            'video': '',
            'price': 65,
            'stock': 100,
          },
        ],
      },
      {
        'id': 'element6',
        'retailerId': 'retailer3',
        'productName': 'Zipper Fastener Set',
        'productCode': 'ZIP-001',
        'category': 'Fasteners',
        'description': 'High-quality zipper fasteners for various garment types.',
        'materialType': [],
        'careSymbol': [],
        'colorOptions': [
          {
            'optionId': 1,
            'color': 'Silver',
            'image': 'https://picsum.photos/seed/zipper_silver/400/400',
            'video': '',
            'price': 120,
            'stock': 50,
          },
          {
            'optionId': 2,
            'color': 'Gold',
            'image': 'https://picsum.photos/seed/zipper_gold/400/400',
            'video': '',
            'price': 140,
            'stock': 30,
          },
        ],
      },
    ];

    for (final element in elements) {
      final id = element['id'] as String;
      element.remove('id');
      await _db.collection('Products').doc(id).set(element);
      print('✅ Seeded element: ${element['productName']}');
    }
  }

  Future<void> clearAllData() async {
    try {
      print('🗑️ Clearing all data...');
      
      final collections = ['Products', 'Tailor', 'Retailer'];
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
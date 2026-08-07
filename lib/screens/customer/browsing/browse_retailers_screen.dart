import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/user_role.dart';
import 'package:sketch2stitch/screens/customer/browsing/retailer_detail_screen.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';
import 'package:sketch2stitch/screens/customer/browsing/filter_data.dart';

// Helper to create ColorOption more concisely in hardcoded data
ColorOption _co(int id, String color, String image, {double price = 0, int stock = 100}) {
  return ColorOption(
    optionId: id,
    color: color,
    images: [image],
    videos: [],
    price: price,
    stock: stock,
  );
}

// ─── Hardcoded Retailers ─────────────────────────────────────────────

final List<Retailer> kHardcodedRetailers = [
  Retailer(
    id: 'r1',
    shopName: 'Dhaka Fabric House',
    email: 'dhaka@fabrics.com',
    address: 'Elephant Road, Dhaka',
    phone: '01711223344',
    rating: 4.8,
    profilePicture: 'assets/images/fab.jpg',
    about: 'Leading retailer of premium cotton and traditional fabrics in Dhaka.',
    products: [
      Product(
        id: 'p1',
        retailerId: 'r1',
        productName: 'Egyptian Cotton',
        category: 'Cotton',
        productCode: 'COT-DHK-01',
        materialType: [MaterialBlend(type: 'Cotton', blend: 100)],
        colorOptions: [
          _co(1, 'White', 'assets/images/fab.jpg', price: 650),
          _co(2, 'Beige', 'assets/images/fab2.jpg', price: 650),
        ],
        description: 'Premium cotton',
        careSymbol: [],
      ),
      Product(
        id: 'p2',
        retailerId: 'r1',
        productName: 'Mulberry Silk',
        category: 'Silk',
        productCode: 'SLK-DHK-01',
        materialType: [MaterialBlend(type: 'Silk', blend: 100)],
        colorOptions: [
          _co(1, 'Gold', 'assets/images/silk.jpg', price: 1800),
        ],
        description: 'Pure silk',
        careSymbol: [],
      ),
    ],
  ),
  Retailer(
    id: 'r2',
    shopName: 'Chowdhury Textiles',
    email: 'chowdhury@textiles.com',
    address: 'Banani, Dhaka',
    phone: '01822334455',
    rating: 4.6,
    profilePicture: 'assets/images/textile.jpg',
    about: 'Specialized in high-quality wool blends and winter collections.',
    products: [
      Product(
        id: 'p3',
        retailerId: 'r2',
        productName: 'Merino Wool',
        category: 'Wool',
        productCode: 'WOL-CHW-01',
        materialType: [MaterialBlend(type: 'Wool', blend: 100)],
        colorOptions: [
          _co(1, 'Brown', 'assets/images/drawing_fabric.jpg', price: 950),
        ],
        description: 'Wool blend',
        careSymbol: [],
      ),
    ],
  ),
  Retailer(
    id: 'r3',
    shopName: 'Silk & Lace Emporium',
    email: 'silk@lace.com',
    address: 'Dhanmondi, Dhaka',
    phone: '01933445566',
    rating: 4.9,
    profilePicture: 'assets/images/lace.jpg',
    about: 'Exclusive collection of fine silk, lace and intricate embroidery.',
    products: [
      Product(
        id: 'p5',
        retailerId: 'r3',
        productName: 'French Lace',
        category: 'Lace',
        productCode: 'LAC-SLE-01',
        materialType: [MaterialBlend(type: 'Polyester', blend: 100)],
        colorOptions: [
          _co(1, 'White', 'assets/images/lace.jpg', price: 1200),
        ],
        description: 'Lace fabric',
        careSymbol: [],
      ),
    ],
  ),
  Retailer(
    id: 'r4',
    shopName: 'Bengal Cotton Co.',
    email: 'bengal@cotton.com',
    address: 'Uttara, Dhaka',
    phone: '01644556677',
    rating: 4.5,
    profilePicture: 'assets/images/fab2.jpg',
    about: 'Quality handloom and powerloom cotton at affordable prices.',
    products: [],
  ),
  Retailer(
    id: 'r5',
    shopName: 'Heritage Weaves',
    email: 'heritage@weaves.com',
    address: 'Gulshan, Dhaka',
    phone: '01555667788',
    rating: 4.7,
    profilePicture: 'assets/images/gorgeous.jpg',
    about: 'Preserving tradition with handwoven Jamdani and Khadi fabrics.',
    products: [],
  ),
];

class RetailersPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;
  final ProductFilterData filterData;
  final UserRole userRole;

  const RetailersPageBody({
    super.key,
    required this.searchQuery,
    required this.filterData,
    this.userRole = UserRole.customer,
  });

  @override
  State<RetailersPageBody> createState() => _RetailersPageBodyState();
}

class _RetailersPageBodyState extends State<RetailersPageBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<Retailer> _retailers = kHardcodedRetailers;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, searchQuery, _) {
        final filteredRetailers = _retailers.where((retailer) {
          final matchesSearch = retailer.shopName
              .toLowerCase()
              .contains(searchQuery.toLowerCase());
          
          final matchesRating = retailer.rating >= widget.filterData.minRating;
          
          return matchesSearch && matchesRating;
        }).toList();

        if (widget.filterData.sortBy == 'rating') {
          filteredRetailers.sort((a, b) => b.rating.compareTo(a.rating));
        }

        return Column(
          children: [
            _buildHeroSection(),
            Expanded(
              child: _buildRetailerGrid(filteredRetailers),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kSageDark, kSage],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Discover Retailers',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Connect with the best fabric shops in town',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetailerGrid(List<Retailer> retailers) {
    if (retailers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No retailers found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: retailers.length,
      itemBuilder: (context, index) {
        final retailer = retailers[index];
        return _buildRetailerCard(retailer);
      },
    );
  }

  Widget _buildRetailerCard(Retailer retailer) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RetailerDetailScreen(
              retailer: retailer,
              userRole: widget.userRole,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                height: 120,
                width: double.infinity,
                color: Colors.grey[100],
                child: retailer.profilePicture != null
                    ? Image.asset(
                        retailer.profilePicture!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.store, size: 40, color: Colors.grey),
                      )
                    : const Icon(Icons.store, size: 40, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    retailer.shopName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      RatingStars(rating: retailer.rating, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        '${retailer.rating}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 10, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          retailer.address,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

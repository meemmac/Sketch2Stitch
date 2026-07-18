import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';
import 'package:sketch2stitch/screens/customer/browsing/filter_data.dart';
import 'package:sketch2stitch/screens/customer/browsing/retailer_detail_screen.dart';

// ─── Sample Color Options ──────────────────────────────────────────────────

ColorOption _createColorOption(int id, String color, String? image, double price, int stock) {
  return ColorOption(
    optionId: id,
    color: color,
    image: image,
    price: price,
    stock: stock,
  );
}

// ─── Sample Products ───────────────────────────────────────────────────────

final List<Product> _sampleProducts = [
  // Products for Dhaka Fabric House (r1)
  Product(
    id: 'p1',
    retailerId: 'r1',
    productName: 'Premium Cotton Fabric',
    category: 'Cotton',
    materialType: 'Cotton',
    colorOptions: [
      _createColorOption(1, 'Red', 'assets/images/fab.jpg', 1200, 10),
      _createColorOption(2, 'Blue', 'assets/images/textile.jpg', 1300, 8),
      _createColorOption(3, 'Green', 'assets/images/silk.jpg', 1100, 15),
    ],
    description: 'High quality premium cotton fabric perfect for summer wear.',
    careSymbol: ['Machine Wash', 'Do Not Bleach'],
  ),
  Product(
    id: 'p2',
    retailerId: 'r1',
    productName: 'Silk Blend Saree',
    category: 'Silk',
    materialType: 'Silk',
    colorOptions: [
      _createColorOption(1, 'Gold', 'assets/images/silk.jpg', 2500, 5),
      _createColorOption(2, 'Red', 'assets/images/fab2.jpg', 2800, 3),
    ],
    description: 'Beautiful silk blend saree with intricate embroidery.',
    careSymbol: ['Dry Clean Only'],
  ),
  Product(
    id: 'p3',
    retailerId: 'r1',
    productName: 'Linen Shirt Fabric',
    category: 'Linen',
    materialType: 'Linen',
    colorOptions: [
      _createColorOption(1, 'White', 'assets/images/fab.jpg', 800, 20),
      _createColorOption(2, 'Beige', 'assets/images/textile.jpg', 850, 18),
    ],
    description: 'Premium linen fabric perfect for formal shirts.',
    careSymbol: ['Machine Wash', 'Iron Medium'],
  ),
  Product(
    id: 'p4',
    retailerId: 'r1',
    productName: 'Printed Cotton Dress',
    category: 'Cotton',
    materialType: 'Cotton',
    colorOptions: [
      _createColorOption(1, 'Pink', 'assets/images/fab2.jpg', 950, 12),
      _createColorOption(2, 'Purple', 'assets/images/fab.jpg', 1000, 10),
    ],
    description: 'Beautiful printed cotton fabric for dresses and tops.',
    careSymbol: ['Machine Wash', 'Do Not Bleach'],
  ),
  
  // Products for Chowdhury Textiles (r2)
  Product(
    id: 'p5',
    retailerId: 'r2',
    productName: 'Traditional Jamdani',
    category: 'Cotton',
    materialType: 'Cotton',
    colorOptions: [
      _createColorOption(1, 'White', 'assets/images/textile.jpg', 1500, 7),
      _createColorOption(2, 'Cream', 'assets/images/fab2.jpg', 1600, 5),
    ],
    description: 'Authentic Jamdani fabric with traditional patterns.',
    careSymbol: ['Hand Wash', 'Do Not Bleach'],
  ),
  Product(
    id: 'p6',
    retailerId: 'r2',
    productName: 'Georgette Chiffon',
    category: 'Polyester',
    materialType: 'Polyester',
    colorOptions: [
      _createColorOption(1, 'Pink', 'assets/images/fab2.jpg', 950, 12),
      _createColorOption(2, 'Purple', 'assets/images/silk.jpg', 1000, 8),
    ],
    description: 'Light weight georgette chiffon for elegant drapes.',
    careSymbol: ['Dry Clean Only'],
  ),
  
  // Products for Silk & Lace Emporium (r3)
  Product(
    id: 'p7',
    retailerId: 'r3',
    productName: 'Raw Silk',
    category: 'Silk',
    materialType: 'Silk',
    colorOptions: [
      _createColorOption(1, 'Gold', 'assets/images/silk.jpg', 3200, 4),
      _createColorOption(2, 'Silver', 'assets/images/lace.jpg', 3500, 3),
    ],
    description: 'Luxurious raw silk with a natural sheen.',
    careSymbol: ['Dry Clean Only'],
  ),
  Product(
    id: 'p8',
    retailerId: 'r3',
    productName: 'Lace Trim Fabric',
    category: 'Lace',
    materialType: 'Lace',
    colorOptions: [
      _createColorOption(1, 'White', 'assets/images/lace.jpg', 1800, 6),
      _createColorOption(2, 'Cream', 'assets/images/silk.jpg', 1900, 5),
    ],
    description: 'Beautiful lace fabric with intricate floral patterns.',
    careSymbol: ['Hand Wash', 'Do Not Wring'],
  ),
  Product(
    id: 'p9',
    retailerId: 'r3',
    productName: 'Velvet Evening Fabric',
    category: 'Velvet',
    materialType: 'Velvet',
    colorOptions: [
      _createColorOption(1, 'Red', 'assets/images/fab.jpg', 2200, 7),
      _createColorOption(2, 'Blue', 'assets/images/textile.jpg', 2300, 5),
      _createColorOption(3, 'Green', 'assets/images/silk.jpg', 2400, 4),
    ],
    description: 'Luxurious velvet fabric for evening wear.',
    careSymbol: ['Dry Clean Only'],
  ),
  
  // Products for Bengal Cotton Co. (r4)
  Product(
    id: 'p10',
    retailerId: 'r4',
    productName: 'Cotton Khadi',
    category: 'Cotton',
    materialType: 'Cotton',
    colorOptions: [
      _createColorOption(1, 'Natural', 'assets/images/fab2.jpg', 700, 25),
      _createColorOption(2, 'Brown', 'assets/images/fab.jpg', 750, 20),
    ],
    description: 'Hand-spun khadi cotton fabric with a rustic feel.',
    careSymbol: ['Machine Wash'],
  ),
  Product(
    id: 'p11',
    retailerId: 'r4',
    productName: 'Denim Fabric',
    category: 'Denim',
    materialType: 'Denim',
    colorOptions: [
      _createColorOption(1, 'Blue', 'assets/images/textile.jpg', 850, 15),
      _createColorOption(2, 'Black', 'assets/images/fab2.jpg', 900, 12),
    ],
    description: 'Premium denim fabric for jeans and jackets.',
    careSymbol: ['Machine Wash', 'Do Not Bleach'],
  ),
  
  // Products for Heritage Weaves (r5)
  Product(
    id: 'p12',
    retailerId: 'r5',
    productName: 'Embroidery Fabric',
    category: 'Embroidery',
    materialType: 'Embroidery',
    colorOptions: [
      _createColorOption(1, 'Green', 'assets/images/lace.jpg', 2100, 8),
      _createColorOption(2, 'Gold', 'assets/images/silk.jpg', 2300, 6),
    ],
    description: 'Hand-embroidered fabric with traditional motifs.',
    careSymbol: ['Dry Clean Only'],
  ),
  Product(
    id: 'p13',
    retailerId: 'r5',
    productName: 'Tussar Silk',
    category: 'Silk',
    materialType: 'Silk',
    colorOptions: [
      _createColorOption(1, 'Copper', 'assets/images/textile.jpg', 2800, 4),
      _createColorOption(2, 'Gold', 'assets/images/silk.jpg', 3000, 3),
    ],
    description: 'Beautiful tussar silk with a textured finish.',
    careSymbol: ['Dry Clean Only'],
  ),
  Product(
    id: 'p14',
    retailerId: 'r5',
    productName: 'Satin Bridal Fabric',
    category: 'Satin',
    materialType: 'Satin',
    colorOptions: [
      _createColorOption(1, 'Pink', 'assets/images/fab.jpg', 1200, 10),
      _createColorOption(2, 'White', 'assets/images/lace.jpg', 1300, 8),
    ],
    description: 'Smooth satin fabric for bridal and formal wear.',
    careSymbol: ['Dry Clean Only'],
  ),
];

// ─── Helper to get products by retailer ID ──────────────────────────────────

List<Product> _getProductsForRetailer(String retailerId) {
  return _sampleProducts.where((p) => p.retailerId == retailerId).toList();
}

/// Hardcoded sample retailers with products.
final List<Retailer> kHardcodedRetailers = [
  Retailer(
    id: 'r1',
    shopName: 'Dhaka Fabric House',
    email: 'contact@dhakafabric.com',
    phone: '01711000001',
    address: '12 New Market Road, Dhanmondi, Dhaka',
    rating: 4.8,
    profilePicture: 'assets/images/fab.jpg',
    products: _getProductsForRetailer('r1'),
  ),
  Retailer(
    id: 'r2',
    shopName: 'Chowdhury Textiles',
    email: 'info@chowdhurytextiles.com',
    phone: '01711000002',
    address: '45 Islampur Road, Islampur, Dhaka',
    rating: 4.6,
    profilePicture: 'assets/images/textile.jpg',
    products: _getProductsForRetailer('r2'),
  ),
  Retailer(
    id: 'r3',
    shopName: 'Silk & Lace Emporium',
    email: 'hello@silklace.com',
    phone: '01711000003',
    address: '7 Gausia Market, Elephant Road, Dhaka',
    rating: 4.9,
    profilePicture: 'assets/images/silk.jpg',
    products: _getProductsForRetailer('r3'),
  ),
  Retailer(
    id: 'r4',
    shopName: 'Bengal Cotton Co.',
    email: 'sales@bengalcotton.com',
    phone: '01711000004',
    address: '89 Karwan Bazar, Tejgaon, Dhaka',
    rating: 4.3,
    profilePicture: 'assets/images/fab2.jpg',
    products: _getProductsForRetailer('r4'),
  ),
  Retailer(
    id: 'r5',
    shopName: 'Heritage Weaves',
    email: 'support@heritageweaves.com',
    phone: '01711000005',
    address: '3 Mirpur Road, Mohammadpur, Dhaka',
    rating: 4.7,
    profilePicture: 'assets/images/lace.jpg',
    products: _getProductsForRetailer('r5'),
  ),
];

/// The actual retailers tab content, rendered as one page inside the
/// shared [BrowseShell] PageView.
class RetailersPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;
  final RetailersFilterData filterData;

  const RetailersPageBody({
    super.key,
    required this.searchQuery,
    required this.filterData,
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
        final filteredRetailers = _retailers.where((r) {
          final matchesSearch = r.shopName.toLowerCase().contains(searchQuery.toLowerCase());
          
          // Rating filter from shell
          final matchesRating = r.rating >= widget.filterData.minRating;
          
          // Location filter from shell
          final matchesLocation = widget.filterData.location == 'All' ||
              r.address.toLowerCase().contains(widget.filterData.location.toLowerCase());
          
          return matchesSearch && matchesRating && matchesLocation;
        }).toList();

        return Column(
          children: [
            _buildHeroSection(),
            Expanded(child: _buildRetailersGrid(filteredRetailers)),
          ],
        );
      },
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16, vertical: 8),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
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
          Text(
            'Trusted Retailers',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Verified retailers with quality fabrics',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildHeroChip(Icons.verified, 'Authentic', isSmallScreen),
              const SizedBox(width: 8),
              _buildHeroChip(Icons.price_check, 'Best Prices', isSmallScreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 12, vertical: isSmall ? 4 : 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: isSmall ? 12 : 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Retailers Grid ──────────────────────────────────────────────────────

  Widget _buildRetailersGrid(List<Retailer> retailers) {
    if (retailers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No retailers found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search terms',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    final isSmallScreen = screenWidth < 400;
    final spacing = isSmallScreen ? 10.0 : 12.0;
    final cardAspectRatio = screenHeight < 700 ? 0.72 : 0.78;

    return GridView.builder(
      padding: EdgeInsets.all(spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: cardAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: retailers.length,
      itemBuilder: (context, index) => _buildRetailerCard(retailers[index], isSmallScreen),
    );
  }

  Widget _buildRetailerCard(Retailer retailer, bool isSmall) {
    final bool isTopRated = retailer.rating >= 4.8;

    // Get image from profilePicture or use fallback
    String imageUrl = retailer.profilePicture ?? 'assets/images/fab.jpg';

    return GestureDetector(
      onTap: () {
        // Navigate to retailer detail
        _navigateToRetailerDetail(retailer);
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image section with badges
            Flexible(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.asset(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: kSage.withValues(alpha: 0.12),
                          child: Icon(Icons.store, size: isSmall ? 36 : 40, color: kSageDark),
                        ),
                      ),
                    ),
                  ),
                  // Top Rated Badge
                  if (isTopRated)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 8 : 10,
                          vertical: isSmall ? 4 : 5,
                        ),
                        decoration: BoxDecoration(
                          color: kSage,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.3,
                          ),
                        ),
                        child: Text(
                          '⭐ Top Rated',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Rating Badge - Bottom Right
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 6 : 8,
                        vertical: isSmall ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: isSmall ? 10 : 12,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            retailer.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content section
            Flexible(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isSmall ? 10 : 12,
                  isSmall ? 8 : 10,
                  isSmall ? 10 : 12,
                  isSmall ? 10 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      retailer.shopName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmall ? 4 : 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: isSmall ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            retailer.generalArea,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    // Show product count if available
                    if (retailer.products != null && retailer.products!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: isSmall ? 2 : 4),
                        child: Text(
                          '${retailer.products!.length} products',
                          style: TextStyle(
                            fontSize: 10,
                            color: kSage,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Navigation Method ──────────────────────────────────────────────────

  void _navigateToRetailerDetail(Retailer retailer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RetailerDetailScreen(
          retailer: retailer,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/review.dart';
import 'package:sketch2stitch/models/portfolio.dart';
import 'package:sketch2stitch/screens/customer/browsing/product_detail_overlay.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_shell.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_palette.dart';

/// Entry point kept for backward compatibility with existing navigation
/// calls (e.g. `Navigator.push(... BrowseFabricsScreen())`). It now opens
/// the shared [BrowseShell] on the Fabrics tab, so the user can swipe or
/// tap between Fabrics / Tailors / Retailers from anywhere.
class BrowseFabricsScreen extends StatelessWidget {
  const BrowseFabricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BrowseShell(initialIndex: 0);
  }
}

/// The actual fabrics tab content, rendered as one page inside the
/// shared [BrowseShell] PageView. Header and navigation row live in the
/// shell; this widget only owns the hero, category chips, and grid.
class FabricsPageBody extends StatefulWidget {
  final ValueNotifier<String> searchQuery;

  const FabricsPageBody({super.key, required this.searchQuery});

  @override
  State<FabricsPageBody> createState() => _FabricsPageBodyState();
}

class _FabricsPageBodyState extends State<FabricsPageBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedCategory = 'All';

  final List<Retailer> _retailers = [];
  final List<Product> _products = [];
  final List<Tailor> _tailors = [];
  final List<String> _categories = [
    'All',
    'Cotton',
    'Silk',
    'Wool',
    'Linen',
    'Lace',
    'Embroidery'
  ];

  @override
  void initState() {
    super.initState();
    _loadHardcodedData();
  }

  void _loadHardcodedData() {
    final sampleReviews = [
      Review(
        id: 'r1',
        customerId: 'c1',
        targetId: 'r1',
        targetRole: ReviewTargetRole.retailer,
        rating: 5.0,
        comment: 'Excellent quality fabrics!',
      ),
    ];

    final samplePortfolios = [
      Portfolio(
        id: 'pf1',
        tailorId: 't1',
        image: 'assets/images/portfolio1.jpg',
        description: 'Bridal gown',
      ),
    ];

    _retailers.addAll([
      Retailer(
        id: 'r1',
        shopName: 'Premium Fabrics',
        email: 'premium@shop.com',
        phone: '+8801712345681',
        address: 'Gulshan, Dhaka',
        licenses: ['License #123'],
        rating: 4.8,
      ),
      Retailer(
        id: 'r2',
        shopName: 'Cotton Blend',
        email: 'cotton@shop.com',
        phone: '+8801712345682',
        address: 'Banani, Dhaka',
        licenses: [],
        rating: 4.5,
        
      ),
    ]);

    _products.addAll([
      Product(
        id: 'p1',
        retailerId: 'r1',
        productName: 'Premium Cotton Fabric',
        category: 'Cotton',
        materialType: '100% Cotton',
        colorOptions: ['White', 'Pink', 'Blue'],
        description:
            'High-quality cotton fabric perfect for all your tailoring needs. This premium fabric offers excellent durability, comfort, and a luxurious feel.',
        
      ),
      Product(
        id: 'p2',
        retailerId: 'r1',
        productName: 'Cotton Blend Fabric',
        category: 'Cotton',
        materialType: 'Cotton Blend',
        colorOptions: ['White', 'Beige', 'Blue'],
        description:
            'Premium cotton blend fabric with excellent durability and softness.',
       
      ),
      Product(
        id: 'p3',
        retailerId: 'r1',
        productName: 'Cotton Casual Fabric',
        category: 'Cotton',
        materialType: '100% Cotton',
        colorOptions: ['White', 'Blue', 'Green'],
        description:
            'Casual cotton fabric for everyday wear. Lightweight and breathable.',
      
      ),
      Product(
        id: 'p4',
        retailerId: 'r1',
        productName: 'Premium Linen Fabric',
        category: 'Linen',
        materialType: '100% Linen',
        colorOptions: ['White', 'Pink', 'Blue'],
        description: 'High-quality linen fabric perfect for summer wear.',
        
      ),
      Product(
        id: 'p5',
        retailerId: 'r2',
        productName: 'Silk Blend Fabric',
        category: 'Silk',
        materialType: 'Silk Blend',
        colorOptions: ['White', 'Beige', 'Blue'],
        description: 'Luxurious silk blend fabric with beautiful drape and sheen.',
       
      ),
      Product(
        id: 'p6',
        retailerId: 'r2',
        productName: 'Lace Fabric',
        category: 'Lace',
        materialType: 'Cotton Lace',
        colorOptions: ['White', 'Blue', 'Green'],
        description:
            'Beautiful lace fabric for elegant designs and special occasions.',
        
      ),
      Product(
        id: 'p7',
        retailerId: 'r2',
        productName: 'Premium Silk Fabric',
        category: 'Silk',
        materialType: '100% Silk',
        colorOptions: ['White', 'Gold', 'Pink'],
        description:
            'Luxurious silk fabric for special occasions and formal wear.',
       
      ),
      Product(
        id: 'p8',
        retailerId: 'r1',
        productName: 'Wool Blend Fabric',
        category: 'Wool',
        materialType: 'Wool Blend',
        colorOptions: ['White', 'Brown', 'Blue'],
        description: 'Warm wool blend fabric perfect for winter wear.',
       
      ),
      Product(
        id: 'p9',
        retailerId: 'r2',
        productName: 'Embroidery Fabric',
        category: 'Embroidery',
        materialType: 'Cotton Blend',
        colorOptions: ['White', 'Gold', 'Blue'],
        description:
            'Exquisite embroidery fabric for traditional and modern designs.',
        
      ),
      Product(
        id: 'p10',
        retailerId: 'r1',
        productName: 'Linen Blend Fabric',
        category: 'Linen',
        materialType: 'Linen Blend',
        colorOptions: ['White', 'Beige', 'Green'],
        description:
            'Breathable linen blend fabric for comfortable everyday wear.',
       
      ),
    ]);

    _tailors.addAll([
      Tailor(
        id: 't1',
        name: 'Master Stitch Tailors',
        email: 'master@tailor.com',
        phone: '+8801712345679',
        address: 'Dhanmondi, Dhaka',
        licenses: ['License #12345'],
        rating: 4.5,
        reviewCount: 214,
        profileImage: 'assets/images/tailor1.jpg',
        description: 'Expert tailoring services with 10+ years experience.',
        portfolio: samplePortfolios,
        
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<String>(
      valueListenable: widget.searchQuery,
      builder: (context, searchQuery, _) {
        final filteredProducts = _products.where((p) {
          final matchesCategory =
              _selectedCategory == 'All' || p.category == _selectedCategory;
          final matchesSearch = p.productName
              .toLowerCase()
              .contains(searchQuery.toLowerCase());
          return matchesCategory && matchesSearch;
        }).toList();

        return Column(
          children: [
            _buildHeroSection(),
            _buildCategoryChips(),
            Expanded(child: _buildProductGrid(filteredProducts)),
          ],
        );
      },
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kSageDark, kSage],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Premium Fabrics for Your Style',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose from our wide selection of high-quality fabrics',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeroChip(Icons.local_shipping, 'Free Delivery on Tk 500+'),
              const SizedBox(width: 8),
              _buildHeroChip(Icons.verified, 'Quality Assured'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Category Chips ──────────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categories.map((category) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildChip(
              category,
              _selectedCategory == category,
              () => setState(() => _selectedCategory = category),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kSage : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kSage : kBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ─── Product Grid ──────────────────────────────────────────────────────

  Widget _buildProductGrid(List<Product> products) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'No products found',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return GestureDetector(
          onTap: () => _showProductDetailOverlay(context, product),
          child: Container(
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.asset(
                      product.imageUrl ?? 'assets/images/placeholder.jpg',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported,
                              size: 50, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.productName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Color(0xFFFDE807), size: 14),
                            const SizedBox(width: 2),
                            Text(
                              '${product.rating} (${product.reviewCount})',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tk ${product.price}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: kSageDark,
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
      },
    );
  }

  void _showProductDetailOverlay(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailOverlay(product: product),
    );
  }
}
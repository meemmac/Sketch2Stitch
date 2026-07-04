import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/review.dart';
import 'package:sketch2stitch/models/portfolio.dart';
import 'package:sketch2stitch/screens/customer/browsing/product_detail_overlay.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_tailors_screen.dart';
import 'package:sketch2stitch/screens/customer/browsing/browse_retailers_screen.dart';

class BrowseFabricsScreen extends StatefulWidget {
  const BrowseFabricsScreen({super.key});

  @override
  State<BrowseFabricsScreen> createState() => _BrowseFabricsScreenState();
}

class _BrowseFabricsScreenState extends State<BrowseFabricsScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _showFilters = false;

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
    // Sample Reviews
    final sampleReviews = [
      Review(
        id: 'r1',
        customerId: 'c1',
        targetId: 'r1',
        targetRole: ReviewTargetRole.retailer,
        rating: 5.0,
        comment: 'Excellent quality fabrics!',
        createdAt: DateTime.now(),
      ),
    ];

    // Sample Portfolios
    final samplePortfolios = [
      Portfolio(
        id: 'pf1',
        tailorId: 't1',
        image: 'assets/images/portfolio1.jpg',
        description: 'Bridal gown',
      ),
    ];

    // Retailers
    _retailers.addAll([
      Retailer(
        id: 'r1',
        shopName: 'Premium Fabrics',
        email: 'premium@shop.com',
        phone: '+8801712345681',
        address: 'Gulshan, Dhaka',
        licenses: ['License #123'],
        rating: 4.8,
        reviewCount: 214,
        logoUrl: 'assets/images/retailer1.png',
        description: 'Premium quality fabrics for your style',
        reviews: sampleReviews,
      ),
      Retailer(
        id: 'r2',
        shopName: 'Cotton Blend',
        email: 'cotton@shop.com',
        phone: '+8801712345682',
        address: 'Banani, Dhaka',
        licenses: [],
        rating: 4.5,
        reviewCount: 104,
        logoUrl: 'assets/images/retailer2.png',
        description: 'Best cotton blend fabrics',
        reviews: [],
      ),
    ]);

    // Products with local images
    _products.addAll([
      Product(
        id: 'p1',
        retailerId: 'r1',
        productName: 'Premium Cotton Fabric',
        category: 'Cotton',
        materialType: '100% Cotton',
        colorOptions: ['White', 'Pink', 'Blue'],
        description: 'High-quality cotton fabric perfect for all your tailoring needs. This premium fabric offers excellent durability, comfort, and a luxurious feel.',
        price: 230,
        rating: 4.5,
        reviewCount: 234,
        imageUrl: 'assets/images/fab.jpg',
        stock: 50,
      ),
      Product(
        id: 'p2',
        retailerId: 'r1',
        productName: 'Cotton Blend Fabric',
        category: 'Cotton',
        materialType: 'Cotton Blend',
        colorOptions: ['White', 'Beige', 'Blue'],
        description: 'Premium cotton blend fabric with excellent durability and softness.',
        price: 330,
        rating: 4.7,
        reviewCount: 234,
        imageUrl: 'assets/images/fab2.jpg',
        stock: 30,
      ),
      Product(
        id: 'p3',
        retailerId: 'r1',
        productName: 'Cotton Casual Fabric',
        category: 'Cotton',
        materialType: '100% Cotton',
        colorOptions: ['White', 'Blue', 'Green'],
        description: 'Casual cotton fabric for everyday wear. Lightweight and breathable.',
        price: 130,
        rating: 3.5,
        reviewCount: 200,
        imageUrl: 'assets/images/fabric_waves.jpg',
        stock: 40,
      ),
      Product(
        id: 'p4',
        retailerId: 'r1',
        productName: 'Premium Linen Fabric',
        category: 'Linen',
        materialType: '100% Linen',
        colorOptions: ['White', 'Pink', 'Blue'],
        description: 'High-quality linen fabric perfect for summer wear.',
        price: 280,
        rating: 4.5,
        reviewCount: 234,
        imageUrl: 'assets/images/fabrics_rolled.jpg',
        stock: 50,
      ),
      Product(
        id: 'p5',
        retailerId: 'r2',
        productName: 'Silk Blend Fabric',
        category: 'Silk',
        materialType: 'Silk Blend',
        colorOptions: ['White', 'Beige', 'Blue'],
        description: 'Luxurious silk blend fabric with beautiful drape and sheen.',
        price: 380,
        rating: 4.7,
        reviewCount: 234,
        imageUrl: 'assets/images/silk.jpg',
        stock: 30,
      ),
      Product(
        id: 'p6',
        retailerId: 'r2',
        productName: 'Lace Fabric',
        category: 'Lace',
        materialType: 'Cotton Lace',
        colorOptions: ['White', 'Blue', 'Green'],
        description: 'Beautiful lace fabric for elegant designs and special occasions.',
        price: 450,
        rating: 3.5,
        reviewCount: 200,
        imageUrl: 'assets/images/lace.jpg',
        stock: 40,
      ),
      Product(
        id: 'p7',
        retailerId: 'r2',
        productName: 'Premium Silk Fabric',
        category: 'Silk',
        materialType: '100% Silk',
        colorOptions: ['White', 'Gold', 'Pink'],
        description: 'Luxurious silk fabric for special occasions and formal wear.',
        price: 550,
        rating: 4.7,
        reviewCount: 156,
        imageUrl: 'assets/images/lace2.jpg',
        stock: 20,
      ),
      Product(
        id: 'p8',
        retailerId: 'r1',
        productName: 'Wool Blend Fabric',
        category: 'Wool',
        materialType: 'Wool Blend',
        colorOptions: ['White', 'Brown', 'Blue'],
        description: 'Warm wool blend fabric perfect for winter wear.',
        price: 420,
        rating: 4.8,
        reviewCount: 189,
        imageUrl: 'assets/images/gorgeous.jpg',
        stock: 25,
      ),
      Product(
        id: 'p9',
        retailerId: 'r2',
        productName: 'Embroidery Fabric',
        category: 'Embroidery',
        materialType: 'Cotton Blend',
        colorOptions: ['White', 'Gold', 'Blue'],
        description: 'Exquisite embroidery fabric for traditional and modern designs.',
        price: 600,
        rating: 4.9,
        reviewCount: 312,
        imageUrl: 'assets/images/embroidery.jpg',
        stock: 15,
      ),
      Product(
        id: 'p10',
        retailerId: 'r1',
        productName: 'Linen Blend Fabric',
        category: 'Linen',
        materialType: 'Linen Blend',
        colorOptions: ['White', 'Beige', 'Green'],
        description: 'Breathable linen blend fabric for comfortable everyday wear.',
        price: 260,
        rating: 4.3,
        reviewCount: 167,
        imageUrl: 'assets/images/tassel.jpg',
        stock: 35,
      ),
    ]);

    // Tailors
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
        reviews: sampleReviews,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((p) {
      final matchesCategory = _selectedCategory == 'All' ||
          p.category == _selectedCategory;
      final matchesSearch = p.productName
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          _buildHeroSection(),
          _buildNavigationRow(),
          _buildCategoryChips(),
          Expanded(
            child: _buildProductGrid(filteredProducts),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          // Dashboard/Menu Icon
          IconButton(
            onPressed: () {
              // Open drawer later
            },
            icon: const Icon(
              Icons.menu,
              color: Color(0xFF224F34),
            ),
          ),
          const SizedBox(width: 8),
          // Logo
          Image.asset(
            'assets/images/transparent_logo.png',
            height: 45,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 45,
                width: 45,
                decoration: const BoxDecoration(
                  color: Color(0xFF224F34),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'S2S',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),

          // Search Bar
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Search fabrics...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Cart
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: Color(0xFF224F34),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Navigation Row ──────────────────────────────────────────────────────

  Widget _buildNavigationRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Browse Clothing and Elements',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF224F34),
              ),
            ),
            const SizedBox(width: 30),

            TextButton(
              onPressed: () {
                // Navigate to Browse Tailors Screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BrowseTailorsScreen(),
                  ),
                );
              },
              child: const Text(
                'Browse Tailors',
                style: TextStyle(
                  color: Color(0xFF224F34),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),

            const SizedBox(width: 8),

           TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BrowseRetailersScreen(),
      ),
    );
  },
  child: const Text(
    'Browse Retailers',
    style: TextStyle(
      color: Color(0xFF224F34),
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
  ),
),

            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF64CD57), Color(0xFF224F34)],
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
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
              () {
                setState(() => _selectedCategory = category);
              },
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
          color: selected ? const Color(0xFF224F34) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF224F34) : Colors.grey[300]!,
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
          onTap: () {
            _showProductDetailOverlay(context, product);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
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
                // Product Image
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.asset(
                      product.imageUrl ?? 'assets/images/placeholder.jpg',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Product Info
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFDE807),
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${product.rating} (${product.reviewCount})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tk ${product.price}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16423C),
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

  // ─── Show Product Detail as Overlay ─────────────────────────────────────

  void _showProductDetailOverlay(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailOverlay(product: product),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/review.dart';
import 'package:sketch2stitch/models/portfolio.dart';
import 'package:sketch2stitch/widgets/product_card.dart';
import 'package:sketch2stitch/widgets/tailor_card.dart';
import 'package:sketch2stitch/widgets/retailer_card.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';
import 'package:sketch2stitch/screens/customer/browsing/product_detail_overlay.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _showFilters = false;

  final List<Retailer> _retailers = [];
  final List<Product> _products = [];
  final List<Tailor> _tailors = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      Review(
        id: 'r4',
        customerId: 'c1',
        targetId: 't1',
        targetRole: ReviewTargetRole.tailor,
        rating: 5.0,
        comment: 'Amazing work!',
        createdAt: DateTime.now(),
      ),
    ];

    // Sample Portfolios
    final samplePortfolios = [
      Portfolio(
        id: 'pf1',
        tailorId: 't1',
        image: 'https://picsum.photos/seed/portfolio1/400/500',
        description: 'Bridal gown',
      ),
      Portfolio(
        id: 'pf2',
        tailorId: 't1',
        image: 'https://picsum.photos/seed/portfolio2/400/500',
        description: 'Wedding dress',
      ),
      Portfolio(
        id: 'pf3',
        tailorId: 't2',
        image: 'https://picsum.photos/seed/classic1/400/500',
        description: 'Classic suit',
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
        logoUrl: 'https://picsum.photos/seed/premiumfabrics/200/200',
        description: 'Premium quality fabrics for your style',
        reviews: sampleReviews.where((r) => r.targetId == 'r1').toList(),
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
        logoUrl: 'https://picsum.photos/seed/cottonblend/200/200',
        description: 'Best cotton blend fabrics',
        reviews: [],
      ),
    ]);

    // Products
    _products.addAll([
      Product(
        id: 'p1',
        retailerId: 'r1',
        productName: 'Premium Cotton Fabric',
        category: 'Cotton',
        materialType: '100% Cotton',
        colorOptions: ['White', 'Pink', 'Blue'],
        description: 'High-quality cotton fabric perfect for all your tailoring needs. This premium fabric offers excellent durability, comfort, and a luxurious feel. Ideal for both casual and formal wear.',
        price: 230,
        rating: 4.5,
        reviewCount: 234,
        imageUrl: 'https://picsum.photos/seed/cotton1/300/400',
        stock: 50,
      ),
      Product(
        id: 'p2',
        retailerId: 'r1',
        productName: 'Cotton Blend Fabric',
        category: 'Cotton',
        materialType: 'Cotton Blend',
        colorOptions: ['White', 'Beige', 'Blue'],
        description: 'Premium cotton blend fabric with excellent durability.',
        price: 180,
        rating: 4.0,
        reviewCount: 89,
        imageUrl: 'https://picsum.photos/seed/cottonblend1/300/400',
        stock: 30,
      ),
      Product(
        id: 'p3',
        retailerId: 'r2',
        productName: 'Silk Blend Fabric',
        category: 'Silk',
        materialType: 'Silk Blend',
        colorOptions: ['White', 'Gold', 'Pink'],
        description: 'Luxurious silk blend for special occasions.',
        price: 350,
        rating: 4.7,
        reviewCount: 156,
        imageUrl: 'https://picsum.photos/seed/silk1/300/400',
        stock: 20,
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
        profileImage: 'https://picsum.photos/seed/masterstitch/200/200',
        description: 'Expert tailoring services with 10+ years experience.',
        portfolio: samplePortfolios.where((p) => p.tailorId == 't1').toList(),
        reviews: sampleReviews.where((r) => r.targetId == 't1').toList(),
      ),
      Tailor(
        id: 't2',
        name: 'Quick Stitch Express',
        email: 'quick@tailor.com',
        phone: '+8801712345680',
        address: 'Gulshan, Dhaka',
        licenses: [],
        rating: 3.5,
        reviewCount: 104,
        profileImage: 'https://picsum.photos/seed/quickstitch/200/200',
        description: 'Fast and reliable tailoring services.',
        portfolio: samplePortfolios.where((p) => p.tailorId == 't2').toList(),
        reviews: [],
      ),
      Tailor(
        id: 't3',
        name: 'Royal Stitch Express',
        email: 'royal@tailor.com',
        phone: '+8801712345684',
        address: 'Banani, Dhaka',
        licenses: ['License #22222'],
        rating: 4.5,
        reviewCount: 214,
        profileImage: 'https://picsum.photos/seed/royalstitch/200/200',
        description: 'Premium tailoring with royal touch.',
        portfolio: [],
        reviews: [],
      ),
      Tailor(
        id: 't4',
        name: 'Stitch Tailors',
        email: 'stitch@tailor.com',
        phone: '+8801712345685',
        address: 'Uttara, Dhaka',
        licenses: [],
        rating: 4.5,
        reviewCount: 174,
        profileImage: 'https://picsum.photos/seed/stitchtailors/200/200',
        description: 'Professional tailoring services.',
        portfolio: [],
        reviews: [],
      ),
      Tailor(
        id: 't5',
        name: 'Modern Fit Tailors',
        email: 'modern@tailor.com',
        phone: '+8801712345686',
        address: 'Dhanmondi, Dhaka',
        licenses: ['License #33333'],
        rating: 4.5,
        reviewCount: 214,
        profileImage: 'https://picsum.photos/seed/modernfit/200/200',
        description: 'Modern and contemporary tailoring.',
        portfolio: [],
        reviews: [],
      ),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          _buildHeroSection(),
          _buildCategoryTabs(),
          _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHomeTab(),
                _buildRetailersTab(),
                _buildTailorsTab(),
              ],
            ),
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
          const Text(
            'Sketch2Stitch',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: Color(0xFF224F34),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF224F34)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF224F34)),
            onPressed: () {},
          ),
        ],
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
          colors: [Color(0xFF64CD57), Color(0xFF81D875)],
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
          const SizedBox(height: 8),
          Text(
            'Choose from our wide selection of high-quality fabrics',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildCategoryChip(Icons.style, 'Cotton'),
              const SizedBox(width: 8),
              _buildCategoryChip(Icons.dry_cleaning, 'Silk'),
              const SizedBox(width: 8),
              _buildCategoryChip(Icons.accessibility_new, 'Wool'),
              const SizedBox(width: 8),
              _buildCategoryChip(Icons.agriculture, 'Linen'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Category Tabs ────────────────────────────────────────────────────────

  Widget _buildCategoryTabs() {
    final categories = ['All', 'Cotton', 'Silk', 'Wool', 'Linen', 'Lace', 'Embroidery'];
    
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: categories.map((category) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildCategoryTab(
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

  Widget _buildCategoryTab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF224F34) : Colors.transparent,
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

  // ─── Search Bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search fabrics...',
                  hintStyle: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab Bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF224F34),
        indicatorWeight: 3,
        labelColor: const Color(0xFF224F34),
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'Home'),
          Tab(text: 'Retailers'),
          Tab(text: 'Tailors'),
        ],
      ),
    );
  }

  // ─── Home Tab ─────────────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    final filteredProducts = _products.where((p) {
      final matchesCategory = _selectedCategory == 'All' ||
          p.category == _selectedCategory;
      final matchesSearch = p.productName
          .toLowerCase()
          .contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Browse Tailors Section
          _buildSectionHeader('Browse Tailors', 'See All'),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tailors.length,
              itemBuilder: (context, index) {
                final tailor = _tailors[index];
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(
                          tailor.profileImage ?? 'https://picsum.photos/seed/${tailor.id}/100/100',
                        ),
                        onBackgroundImageError: (_, __) {},
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tailor.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${tailor.rating}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Featured Products
          _buildSectionHeader('Featured Fabrics', 'See All'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredProducts.length > 4 ? 4 : filteredProducts.length,
            itemBuilder: (context, index) {
              return ProductCard(
                product: filteredProducts[index],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailScreen(
                        product: filteredProducts[index],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () {
            if (title.contains('Tailors')) {
              _tabController.animateTo(2);
            } else {
              _tabController.animateTo(1);
            }
          },
          child: Text(
            action,
            style: const TextStyle(
              color: Color(0xFF224F34),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Retailers Tab ──────────────────────────────────────────────────────

  Widget _buildRetailersTab() {
    final filtered = _retailers.where((r) {
      final matchesSearch = r.shopName
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No retailers found'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return RetailerCard(
          retailer: filtered[index],
          onTap: () {
            // Show retailer details
          },
        );
      },
    );
  }

  // ─── Tailors Tab ─────────────────────────────────────────────────────────

  Widget _buildTailorsTab() {
    final filtered = _tailors.where((t) {
      final matchesSearch = t.name
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No tailors found'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final tailor = filtered[index];
        return GestureDetector(
          onTap: () {
            _showTailorDetail(context, tailor);
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          image: DecorationImage(
                            image: NetworkImage(
                              tailor.profileImage ??
                                  'https://picsum.photos/seed/${tailor.id}/200/200',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (tailor.hasLicense)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '✓ Licensed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Top Rated',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tailor.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${tailor.rating} (${tailor.reviewCount})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Fast Service',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
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
      },
    );
  }

  void _showTailorDetail(BuildContext context, Tailor tailor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          tailor.profileImage ??
                              'https://picsum.photos/seed/${tailor.id}/100/100',
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 80,
                              width: 80,
                              color: Colors.grey[200],
                              child: const Icon(Icons.person, size: 40),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tailor.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                RatingStars(rating: tailor.rating),
                                const SizedBox(width: 8),
                                Text(
                                  '(${tailor.reviewCount} reviews)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  tailor.generalArea,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            if (tailor.hasLicense)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '✓ Licensed Professional',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (tailor.description != null) ...[
                    Text(
                      tailor.description!,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Divider(),
                  const Text(
                    'Portfolio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (tailor.portfolio.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No portfolio items yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: GridView.builder(
                        controller: scrollController,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: tailor.portfolio.length,
                        itemBuilder: (context, index) {
                          final item = tailor.portfolio[index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              item.image ?? 'https://picsum.photos/seed/${item.id}/400/500',
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
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.favorite_border),
                          label: const Text('Favorite'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF224F34),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF224F34)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.chat),
                          label: const Text('Message'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF224F34),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
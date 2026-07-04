import 'package:flutter/material.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/review.dart';
import 'package:sketch2stitch/widgets/rating_stars.dart';

class BrowseRetailersScreen extends StatefulWidget {
  const BrowseRetailersScreen({super.key});

  @override
  State<BrowseRetailersScreen> createState() => _BrowseRetailersScreenState();
}

class _BrowseRetailersScreenState extends State<BrowseRetailersScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<Retailer> _retailers = [];
  final List<String> _filters = ['All', 'Top Rated', 'Premium', 'Fast Service'];
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
        rating: 4.5,
        comment: 'Great quality fabrics!',
        createdAt: DateTime.now(),
      ),
      Review(
        id: 'r2',
        customerId: 'c2',
        targetId: 'r2',
        targetRole: ReviewTargetRole.retailer,
        rating: 4.5,
        comment: 'Excellent service!',
        createdAt: DateTime.now(),
      ),
    ];

    _retailers.addAll([
      Retailer(
        id: 'r1',
        shopName: 'Fabric Paradise',
        email: 'paradise@shop.com',
        phone: '+8801712345681',
        address: 'Gulshan, Dhaka',
        licenses: ['License #123'],
        rating: 4.5,
        reviewCount: 234,
        logoUrl: 'assets/images/fabric_waves.jpg',
        description: 'Multi-brand Fabric Store with premium quality fabrics',
        reviews: sampleReviews.where((r) => r.targetId == 'r1').toList(),
      ),
      Retailer(
        id: 'r2',
        shopName: 'Cotton Corner',
        email: 'cotton@corner.com',
        phone: '+8801712345682',
        address: 'Banani, Dhaka',
        licenses: ['License #456'],
        rating: 4.5,
        reviewCount: 234,
        logoUrl: 'https://picsum.photos/seed/cottoncorner/200/200',
        description: 'Cotton Specialist with 100% pure cotton fabrics',
        reviews: sampleReviews.where((r) => r.targetId == 'r2').toList(),
      ),
      Retailer(
        id: 'r3',
        shopName: 'Silk Emporium',
        email: 'silk@emporium.com',
        phone: '+8801712345683',
        address: 'Dhanmondi, Dhaka',
        licenses: ['License #789'],
        rating: 4.8,
        reviewCount: 312,
        logoUrl: 'https://picsum.photos/seed/silkemporium/200/200',
        description: 'Luxury silk fabrics for special occasions',
        reviews: [],
      ),
      Retailer(
        id: 'r4',
        shopName: 'Linen World',
        email: 'linen@world.com',
        phone: '+8801712345684',
        address: 'Uttara, Dhaka',
        licenses: [],
        rating: 4.2,
        reviewCount: 167,
        logoUrl: 'https://picsum.photos/seed/linenworld/200/200',
        description: 'Premium linen fabrics for all seasons',
        reviews: [],
      ),
      Retailer(
        id: 'r5',
        shopName: 'Wool House',
        email: 'wool@house.com',
        phone: '+8801712345685',
        address: 'Mirpur, Dhaka',
        licenses: ['License #101'],
        rating: 4.6,
        reviewCount: 198,
        logoUrl: 'https://picsum.photos/seed/woolhouse/200/200',
        description: 'Specialist in wool and winter fabrics',
        reviews: [],
      ),
      Retailer(
        id: 'r6',
        shopName: 'Fabric Paradise',
        email: 'paradise2@shop.com',
        phone: '+8801712345686',
        address: 'Gulshan, Dhaka',
        licenses: ['License #123'],
        rating: 4.5,
        reviewCount: 234,
        logoUrl: 'https://picsum.photos/seed/fabricparadise2/200/200',
        description: 'Multi-brand Fabric Store with premium quality fabrics',
        reviews: [],
      ),
      Retailer(
        id: 'r7',
        shopName: 'Cotton Corner',
        email: 'cotton2@corner.com',
        phone: '+8801712345687',
        address: 'Banani, Dhaka',
        licenses: ['License #456'],
        rating: 4.5,
        reviewCount: 234,
        logoUrl: 'https://picsum.photos/seed/cottoncorner2/200/200',
        description: 'Cotton Specialist with 100% pure cotton fabrics',
        reviews: [],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final filteredRetailers = _retailers.where((r) {
      final matchesFilter = _selectedFilter == 'All' ||
          (_selectedFilter == 'Top Rated' && r.rating >= 4.5) ||
          (_selectedFilter == 'Premium' && r.hasLicense) ||
          (_selectedFilter == 'Fast Service' && r.reviewCount > 200);
      
      final matchesSearch = r.shopName
          .toLowerCase()
          .contains(_searchQuery.toLowerCase()) ||
          (r.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      return matchesFilter && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          _buildHeroSection(),
          _buildNavigationRow(),
          _buildFilterChips(), // Added this back
          _buildCategoryChips(),
          Expanded(
            child: _buildRetailersGrid(filteredRetailers),
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
                  hintText: 'Search retailers...',
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
              'Browse Clothing and elements',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF224F34),
              ),
            ),
            const SizedBox(width: 30),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
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
            const Text('|', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Browse Retailers',
                style: TextStyle(
                  color: Color(0xFF224F34),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
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
            'Trusted Fabric Retailers',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Shop from verified retailers with the best quality fabrics',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeroChip(Icons.verified, 'Authentic Products'),
              const SizedBox(width: 8),
              _buildHeroChip(Icons.price_check, 'Best Prices'),
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

  // ─── Filter Chips ──────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _filters.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildChip(
              filter,
              _selectedFilter == filter,
              () {
                setState(() => _selectedFilter = filter);
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
            child: _buildCategoryChip(
              category,
              false,
              () {
                // Handle category selection
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool selected, VoidCallback onTap) {
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

  // ─── Retailers Grid ──────────────────────────────────────────────────────

  Widget _buildRetailersGrid(List<Retailer> retailers) {
    if (retailers.isEmpty) {
      return const Center(
        child: Text(
          'No retailers found',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
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
      itemCount: retailers.length,
      itemBuilder: (context, index) {
        final retailer = retailers[index];
        return _buildRetailerCard(retailer);
      },
    );
  }

  Widget _buildRetailerCard(Retailer retailer) {
    final bool showTopRated = retailer.rating >= 4.8;

    return GestureDetector(
      onTap: () {
        // Navigate to retailer detail
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
            // Logo Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.network(
                      retailer.logoUrl ??
                          'https://picsum.photos/seed/${retailer.id}/200/200',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.store,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                  if (showTopRated)
                    Positioned(
                      top: 8,
                      right: 8,
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
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (retailer.hasLicense)
                    Positioned(
                      top: 8,
                      left: 8,
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
                          'Licensed',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          retailer.shopName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          retailer.description?.split(' ').take(3).join(' ') ?? 'Fabric Store',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            RatingStars(rating: retailer.rating, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${retailer.rating}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                retailer.generalArea,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
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
}
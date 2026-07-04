import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sketch2stitch/models/retailer.dart';
import 'package:sketch2stitch/models/tailor.dart';
import 'package:sketch2stitch/models/product.dart';
import 'package:sketch2stitch/models/review.dart';
import 'package:sketch2stitch/models/portfolio.dart';
import 'package:sketch2stitch/screens/customer/retailer_detail_screen.dart';
import 'package:sketch2stitch/screens/customer/tailor_detail_screen.dart';
import 'package:sketch2stitch/widgets/filter_bar.dart';
import 'package:sketch2stitch/widgets/product_card.dart';
import 'package:sketch2stitch/widgets/tailor_card.dart';
import 'package:sketch2stitch/widgets/retailer_card.dart';

class BrowseClothingPage extends StatefulWidget {
  const BrowseClothingPage({super.key});

  @override
  State<BrowseClothingPage> createState() => _BrowseClothingPageState();
}

class _BrowseClothingPageState extends State<BrowseClothingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';
  String _selectedMaterial = 'All';
  double _maxPrice = 1000;
  double _minRating = 0;
  String _searchQuery = '';
  bool _showFilters = false;

  // Filter state
  final Map<String, dynamic> _filters = {
    'category': 'All',
    'materialType': 'All',
    'minPrice': 0,
    'maxPrice': 1000,
    'minRating': 0,
    'location': 'All',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          _buildSearchBar(),
          _buildFilterChips(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRetailersTab(),
                _buildProductsTab(),
                _buildTailorsTab(),
              ],
            ),
          ),
          if (_showFilters) _buildFilterDrawer(),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF64CD57), Color(0xFF81D875), Color(0xFFD8F0D5)],
          stops: [0.0, 0.25, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
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
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: Color(0xFF224F34),
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF224F34)),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
    );
  }

  // ─── Search Bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF0E8E8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF6A9C89)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFF6A9C89), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search retailers, fabrics, or tailors...',
                  hintStyle: TextStyle(
                    color: Color(0xFF6A9C89),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Filter Chips ─────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildChip('All', _selectedCategory == 'All', () {
            setState(() => _selectedCategory = 'All');
          }),
          const SizedBox(width: 8),
          _buildChip('Cotton', _selectedCategory == 'Cotton', () {
            setState(() => _selectedCategory = 'Cotton');
          }),
          const SizedBox(width: 8),
          _buildChip('Silk', _selectedCategory == 'Silk', () {
            setState(() => _selectedCategory = 'Silk');
          }),
          const SizedBox(width: 8),
          _buildChip('Wool', _selectedCategory == 'Wool', () {
            setState(() => _selectedCategory = 'Wool');
          }),
          const SizedBox(width: 8),
          _buildChip('Linen', _selectedCategory == 'Linen', () {
            setState(() => _selectedCategory = 'Linen');
          }),
          const SizedBox(width: 8),
          _buildChip('Lace', _selectedCategory == 'Lace', () {
            setState(() => _selectedCategory = 'Lace');
          }),
          const SizedBox(width: 8),
          _buildChip('Embroidery', _selectedCategory == 'Embroidery', () {
            setState(() => _selectedCategory = 'Embroidery');
          }),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF64CD57) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6A9C89)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.black : Colors.black87,
          ),
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
          Tab(text: 'Retailers'),
          Tab(text: 'Fabrics'),
          Tab(text: 'Tailors'),
        ],
      ),
    );
  }

  // ─── Retailers Tab ──────────────────────────────────────────────────────

  Widget _buildRetailersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('retailers')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final retailers = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Retailer(
            id: doc.id,
            shopName: data['shopName'] ?? '',
            email: data['email'] ?? '',
            phone: data['phone'] ?? '',
            address: data['address'] ?? '',
            licenses: List<String>.from(data['licenses'] ?? []),
            rating: (data['rating'] ?? 0).toDouble(),
            reviewCount: data['reviewCount'] ?? 0,
            logoUrl: data['logoUrl'],
            description: data['description'],
            products: [],
            reviews: [],
          );
        }).toList();

        // Apply filters
        final filtered = retailers.where((r) {
          final matchesSearch = r.shopName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
              r.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false;
          final matchesRating = r.rating >= _filters['minRating'];
          final matchesLocation = _filters['location'] == 'All' ||
              r.address.contains(_filters['location']);
          return matchesSearch && matchesRating && matchesLocation;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'No retailers found',
              style: TextStyle(color: Colors.grey, fontSize: 14),
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
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return RetailerCard(
              retailer: filtered[index],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RetailerDetailScreen(
                      retailerId: filtered[index].id,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Products Tab ─────────────────────────────────────────────────────────

  Widget _buildProductsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('isAvailable', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Product(
            id: doc.id,
            retailerId: data['retailerId'] ?? '',
            productName: data['productName'] ?? '',
            category: data['category'] ?? '',
            materialType: data['materialType'] ?? '',
            colorOptions: List<String>.from(data['colorOptions'] ?? []),
            description: data['description'] ?? '',
            price: (data['price'] ?? 0).toDouble(),
            rating: (data['rating'] ?? 0).toDouble(),
            reviewCount: data['reviewCount'] ?? 0,
            imageUrl: data['imageUrl'],
            stock: data['stock'] ?? 0,
          );
        }).toList();

        // Apply filters
        final filtered = products.where((p) {
          final matchesCategory = _selectedCategory == 'All' ||
              p.category == _selectedCategory;
          final matchesMaterial = _filters['materialType'] == 'All' ||
              p.materialType == _filters['materialType'];
          final matchesPrice = p.price >= _filters['minPrice'] &&
              p.price <= _filters['maxPrice'];
          final matchesRating = p.rating >= _filters['minRating'];
          final matchesSearch = p.productName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
              p.description.toLowerCase().contains(_searchQuery.toLowerCase());
          return matchesCategory &&
              matchesMaterial &&
              matchesPrice &&
              matchesRating &&
              matchesSearch;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'No products found',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return ProductCard(
              product: filtered[index],
              onTap: () {
                // Navigate to product detail or retailer detail
                _showProductDialog(context, filtered[index]);
              },
            );
          },
        );
      },
    );
  }

  // ─── Tailors Tab ─────────────────────────────────────────────────────────

  Widget _buildTailorsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tailors')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tailors = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Tailor(
            id: doc.id,
            name: data['name'] ?? '',
            email: data['email'] ?? '',
            phone: data['phone'] ?? '',
            address: data['address'] ?? '',
            licenses: List<String>.from(data['licenses'] ?? []),
            rating: (data['rating'] ?? 0).toDouble(),
            reviewCount: data['reviewCount'] ?? 0,
            profileImage: data['profileImage'],
            description: data['description'],
            portfolio: [],
            reviews: [],
            isFavorite: false,
          );
        }).toList();

        // Apply filters
        final filtered = tailors.where((t) {
          final matchesSearch = t.name
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
              t.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                  false;
          final matchesRating = t.rating >= _filters['minRating'];
          final matchesLocation = _filters['location'] == 'All' ||
              t.address.contains(_filters['location']);
          return matchesSearch && matchesRating && matchesLocation;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'No tailors found',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return TailorCard(
              tailor: filtered[index],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TailorDetailScreen(
                      tailorId: filtered[index].id,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Filter Drawer ──────────────────────────────────────────────────────

  Widget _buildFilterDrawer() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Reset',
                  style: TextStyle(
                    color: Color(0xFF224F34),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(
                    title: 'Price Range',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildPriceInput('Min', _filters['minPrice']),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildPriceInput('Max', _filters['maxPrice']),
                            ),
                          ],
                        ),
                        Slider(
                          value: _filters['maxPrice'],
                          min: 0,
                          max: 1000,
                          divisions: 100,
                          label: 'Tk ${_filters['maxPrice'].toInt()}',
                          onChanged: (value) {
                            setState(() {
                              _filters['maxPrice'] = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFilterSection(
                    title: 'Minimum Rating',
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: _filters['minRating'],
                            min: 0,
                            max: 5,
                            divisions: 10,
                            label: _filters['minRating'].toStringAsFixed(1),
                            onChanged: (value) {
                              setState(() {
                                _filters['minRating'] = value;
                              });
                            },
                          ),
                        ),
                        Text(
                          _filters['minRating'].toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFilterSection(
                    title: 'Location',
                    child: DropdownButtonFormField<String>(
                      value: _filters['location'],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Locations')),
                        DropdownMenuItem(value: 'Gulshan', child: Text('Gulshan')),
                        DropdownMenuItem(value: 'Banani', child: Text('Banani')),
                        DropdownMenuItem(value: 'Dhanmondi', child: Text('Dhanmondi')),
                        DropdownMenuItem(value: 'Uttara', child: Text('Uttara')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filters['location'] = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFilterSection(
                    title: 'Material Type',
                    child: DropdownButtonFormField<String>(
                      value: _filters['materialType'],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Materials')),
                        DropdownMenuItem(value: '100% Cotton', child: Text('100% Cotton')),
                        DropdownMenuItem(value: 'Silk Blend', child: Text('Silk Blend')),
                        DropdownMenuItem(value: '100% Linen', child: Text('100% Linen')),
                        DropdownMenuItem(value: 'Wool Blend', child: Text('Wool Blend')),
                        DropdownMenuItem(value: 'Satin Silk', child: Text('Satin Silk')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filters['materialType'] = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showFilters = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF224F34),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF224F34),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildPriceInput(String label, double value) {
    return TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      controller: TextEditingController(text: value.toInt().toString()),
      onChanged: (text) {
        final newValue = double.tryParse(text) ?? 0;
        setState(() {
          if (label == 'Min') {
            _filters['minPrice'] = newValue;
          } else {
            _filters['maxPrice'] = newValue;
          }
        });
      },
    );
  }

  // ─── Product Dialog ──────────────────────────────────────────────────────

  void _showProductDialog(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  product.imageUrl ?? 'https://picsum.photos/seed/${product.id}/400/400',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 50),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                product.productName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${product.rating} (${product.reviewCount} reviews)',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    'Tk ${product.price}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF224F34),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                product.description,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: product.colorOptions.map((color) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      color,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Add to cart logic
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to cart!'),
                        backgroundColor: Color(0xFF64CD57),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF224F34),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}